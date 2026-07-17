(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_06_WinchControl — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 6.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_WinchControl
VAR
    // Stubs
    StubMachineEnableN1 : BOOL := TRUE;

    // Instances
    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;

    // Variables de commande M1 après arbitrage Manuel/Auto
    M1_StartStop_Active     : BOOL;
    M1_Direction_Active     : INT;
    M1_SpeedRef_Active      : REAL;

    // Variables de commande M2 après arbitrage Benne/Manuel/Auto
    M2_StartStop_Active     : BOOL;
    M2_Direction_Active     : INT;
    M2_SpeedRef_Active      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    // Bornage et limites
    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;
    // 🆕 REX 2026-07-15 (8) — miroir IHM dédié CableLimitAscentM1/2_M (demande utilisateur, symétrique
    // à CableLimitDescentReached) : indique PRÉCISÉMENT que la nouvelle limite haute d'exploitation
    // normale est atteinte (hors capteur physique bit5, hors Homing) — voir §5 plus bas.
    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    // 🔧 REX 2026-07-07 : couplage croisé M1/M2 des arrêts, UNIQUEMENT si SyncActive (mouvement
    // coherent voulu). Hors synchro (Benne.Busy ou SyncEnable=FALSE MAINT_N2) : chaque treuil réagit
    // à SA PROPRE limite/défaut uniquement — commande indépendante voulue dans ce cas.
    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    ForbidDescentM1_Raw     : BOOL;
    ForbidDescentM2_Raw     : BOOL;
    ForbidAscentM1_Raw      : BOOL;
    ForbidAscentM2_Raw      : BOOL;
    ForbidAscentM1_Active   : BOOL;
    ForbidAscentM2_Active   : BOOL;

    // 🆕 REX 2026-07-08 : voir §2bis — coupure immédiate M1/M2 au même scan que la fin du cycle
    // benne (contrairement au désarmement homme-mort côté FB_Joystick, qui a 1 scan de retard
    // structurel — PRG_01 s'exécute avant PRG_06). Corrige un bref "blip" de commande (RelayFwd/Rev
    // + BrakeCmd clignotant) observé sur M1 à l'arrivée en position benne.
    BenneBusyFallEdge     : F_TRIG;

    // 🆕 REX 2026-07-08 (4) : instWinchSync appelé APRÈS l'arbitrage M1/M2 (§3, plus bas) — lu ici
    // avec 1 scan de retard (~10ms), négligeable vu que DeltaPosM évolue progressivement, pas
    // par à-coup (même raisonnement que M1_Busy/M2_Busy sur instBucket, voir §0).
    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;   // 🆕 REX 2026-07-08 (5) : bit0 latché ET écart actuel aggravé par la montée
    SyncMinorDeviationBlocksDown : BOOL;   // 🆕 REX 2026-07-08 (5) : bit0 latché ET écart actuel aggravé par la descente
    M2_LimitShift                : REAL;   // 🆕 REX 2026-07-08 : décalage dynamique de la butée haute de M2

    // 🆕 REX 2026-07-15 (3) — demande utilisateur : les fins de course virtuelles benne
    // (FdcBucketOpen/CloseActive) doivent bloquer le mouvement AUSSI en pilotage COUPLÉ IHM_MANU
    // (M1+M2 simultané), pas seulement en pilotage individuel M2 — sinon un opérateur qui pousse le
    // couplage alors que le benne est déjà en butée virtuelle n'est protégé que par la butée
    // mécanique passive. Masque calculé UNE FOIS ici, consommé par M1 ET M2 (§1/§2 ci-dessous) pour
    // que les deux treuils s'arrêtent ENSEMBLE (pas de désynchro M1/M2 en cas de blocage partiel).
    CoupledFwdBucketOk          : BOOL;   // Couplage montée autorisé (pas de butée fermeture benne)
    CoupledRevBucketOk          : BOOL;   // Couplage descente autorisé (pas de butée ouverture benne)

    // 🆕 REX 2026-07-15 (9) — plafond palier IHM_MANU "essais progressifs" (demande utilisateur,
    // TEMPORAIRE tant que les vitesses définitives ne sont pas figées, à retirer ensuite) : commun
    // aux 2 treuils (GVL_IHM.IHM_MANU.WinchMaxStepFwd/Rev, structure figée, un seul réglage pour M1
    // ET M2). Actif UNIQUEMENT si ManuActive — Auto garde son comportement inchangé (5 en montée,
    // WinchMaxStepDescente en descente). En Manu, le plafond descente est le MIN avec
    // WinchMaxStepDescente (jamais moins protecteur qu'Auto, juste potentiellement plus prudent).
    ManuMaxStepFwd            : INT;
    ManuMaxStepRev            : INT;
    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescente  : INT;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_06_WinchControl) ===

// ── 0. COMMANDE DU BENNE (Séquence lente) ─────────────────────────────
// 🔧 REX 2026-07-08 : appelé EN PREMIER (avant l'arbitrage M1/M2 ci-dessous) — audit sécurité :
// l'ancien ordre (Benne appelé après l'arbitrage) faisait que M1_StartStop_Active lisait
// instBucket.Busy du scan PRÉCÉDENT, créant une fenêtre d'1 scan où M1 pouvait recevoir une
// commande manuelle au moment exact où le benne démarre. instBucket.M1_Busy/M2_Busy (ci-dessous)
// lisent en retour instWinchM1/M2.Busy du scan précédent (ces FB sont appelés plus loin, §6/§7) —
// acceptable : ça ne retarde que l'ACCEPTATION d'une nouvelle demande de ~1 scan (10ms), sans
// aucun impact sécurité (contrairement au cas inverse, qui pouvait faire bouger M1 pendant Busy).
instBucket(
    Enable              := NOT PRG_04_Modes.instModes.InhibitM2
                           AND PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable
                           AND PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable, // 🆕 Sécurisé : nécessite les deux codeurs valides et M2 non-inhibé
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    CmdOpen_IHM         := GVL_IHM.Bucket.CmdOpen OR PRG_05_Cycle.instCycle.CmdBucket_Open,
    CmdClose_IHM        := GVL_IHM.Bucket.CmdClose OR PRG_05_Cycle.instCycle.CmdBucket_Close,
    JoystickY_StartStop := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop,
    JoystickY_Direction := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction,
    CablePosM1          := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2          := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1             := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2             := PRG_02_Encoders.instHomingM2.Homed,
    M1_Busy             := instWinchM1.Busy,   // 🆕 REX 2026-07-08
    M2_Busy             := instWinchM2.Busy,   // 🆕 REX 2026-07-08
    ConfirmOpenPosition := GVL_IHM.Bucket.CmdConfirmOpenPosition, // 🆕 REX 2026-07-08 — bouton IHM référencement benne ouvert
    ConfirmClosePosition:= GVL_IHM.Bucket.CmdConfirmClosePosition, // 🆕 REX 2026-07-08 — bouton IHM référencement benne fermé
    Config              := _BucketConfig,
    TimeoutDuration     := GVL_IHM.Bucket.TimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08
    InhibitM2           := PRG_04_Modes.instModes.InhibitM2  // 🆕 REX 2026-07-08
);

// 🆕 REX 2026-07-08 (4) — Concept 1 (écart synchro mineur) : bit0 seul (écart position, hors
// incohérence commande bit1) ne fait plus de SafeStop (fast) — bloque StartStop → rampe de décél
// NORMALE. Recalage : voir SyncEnable=FALSE (MAINT_N2), procédure déjà existante (mou de câble).
SyncMinorDeviation := (instWinchSync.ErrorId AND 16#0001) <> 16#0000;

// 🔧 REX 2026-07-08 (5) — audit sécurité : ne bloque plus StartStop dans les 2 sens (déblocage
// impossible sans Reset+MAINT_N2, régression terrain constatée, écart mécanique transitoire
// normal à l'arrêt). SignedDeltaPosM > 0 = M1 plus "haut" que M2 : la montée (Direction=+1)
// aggrave cet écart, la descente (-1) le réduit — et inversement si < 0. Seul le sens aggravant
// reste bloqué ; Méca E (FB_Safety_Winch, écart critique 2.0m) et bit1 (incohérence commande)
// restent le filet réel si l'écart continue de dériver malgré cette autorisation directionnelle.
// 🆕 REX 2026-07-08 (6) : gate global SyncSoftStopEnable — FALSE (défaut) = ces 2 sorties
// restent FALSE en permanence (bit0 déjà géré en SafeStop fast classique ci-dessus, §5bis) ;
// TRUE = active le blocage directionnel (nouvelle fonctionnalité, opt-in).
SyncMinorDeviationBlocksUp   := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0);
SyncMinorDeviationBlocksDown := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0);

// 🆕 REX 2026-07-15 (3) — voir déclaration VAR ci-dessus : couplé masqué par les mêmes fins de
// course benne que l'individuel M2, appliqué à M1 ET M2 (§1/§2) pour arrêter les DEUX treuils
// ensemble plutôt que de désynchroniser M1/M2 en ne bloquant que la moitié du couplage.
CoupledFwdBucketOk := NOT GVL_IHM.IHM_MANU.FdcBucketCloseActive;
CoupledRevBucketOk := NOT GVL_IHM.IHM_MANU.FdcBucketOpenActive;

// 🆕 REX 2026-07-15 (9) — plafond palier IHM_MANU "essais progressifs" (voir déclaration VAR
// ci-dessus). Bornage identique à l'ex-logique PRG_10_Outputs retirée lors du passage sur FB_Winch.
ManuMaxStepFwd := GVL_IHM.IHM_MANU.WinchMaxStepFwd;
IF (ManuMaxStepFwd < 1) OR (ManuMaxStepFwd > 5) THEN
    ManuMaxStepFwd := 5; // Pleine vitesse par défaut si non initialisé/invalide
END_IF;
ManuMaxStepRev := GVL_IHM.IHM_MANU.WinchMaxStepRev;
IF (ManuMaxStepRev < 1) OR (ManuMaxStepRev > 5) THEN
    ManuMaxStepRev := 2; // Palier 2 max par défaut en descente (conforme AF) si non initialisé/invalide
END_IF;
EffectiveMaxStepAscent   := SEL(PRG_10_Outputs.ManuActive, 5, ManuMaxStepFwd);
EffectiveMaxStepDescente := SEL(PRG_10_Outputs.ManuActive, _WinchMaxStepDescent, MIN(_WinchMaxStepDescent, ManuMaxStepRev));

// ── 1. ARBITRAGE DES CONSIGNES M1 (Joystick vs Cycle Automatique) ────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche (bug trouvé en
    // review code), le cycle auto pouvait aggraver un écart mineur sans aucune protection quand
    // SyncSoftStopEnable=TRUE. Ajouté ici, symétrique à la branche manuelle ci-dessous.
    M1_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM1_Direction;
    M1_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM1_StartStop
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
    M1_SpeedRef_Active  := PRG_05_Cycle.instCycle.CmdWinchM1_SpeedPct;
ELSIF PRG_10_Outputs.ManuActive THEN
    // 🆕 REX 2026-07-15 (2) — IHM_MANU pilote désormais M1 via FB_Winch (au lieu de l'ex-bypass
    // direct dans PRG_10_Outputs) : récupère gratuitement la rampe accel/décel + le ralentissement
    // en zone d'approche de bordure + le maintien du relais pendant la décél (mêmes paramètres
    // persistants qu'en Auto, voir instWinchM1 plus bas §6). Demande (boutons IHM ou joystick, déjà
    // arbitrée par PRG_10_Outputs : M1Fwd_Demand/M1Rev_Demand/CoupledFwd_Demand/CoupledRev_Demand)
    // lue avec 1 scan de retard (~10ms, PRG_10 position 10 > PRG_06 position 6) — même principe
    // déjà accepté ailleurs dans ce fichier (Benne.Busy, SyncMinorDeviation).
    // 🔧 REX 2026-07-15 (5) — trouvé en revue croisée (agent Haiku + relecture manuelle) : M1
    // INDIVIDUEL (bouton M1_RelayFwd/Rev, indépendant de M2) n'était masqué par AUCUNE butée
    // benne — delta = CablePosM1 - CablePosM2, donc bouger M1 seul aggrave la MÊME sur-contrainte
    // mécanique que le couplé (déjà corrigé ci-dessous) : M1 Fwd augmente le delta (aggrave
    // FdcBucketOpenActive, delta déjà >= 0) ; M1 Rev diminue le delta (aggrave
    // FdcBucketCloseActive, delta déjà <= -10). Sens INVERSÉ par rapport à M2 (M2Fwd↔Close,
    // M2Rev↔Open) car M1 et M2 ont un effet opposé sur le même delta. Couplé masqué par
    // CoupledFwdBucketOk/CoupledRevBucketOk (REX 2026-07-15 (3)) — M1 s'arrête EN MÊME TEMPS que
    // M2 si le couplage OU son propre individuel violerait une butée benne.
    IF (PRG_10_Outputs.M1Fwd_Demand AND NOT GVL_IHM.IHM_MANU.FdcBucketOpenActive) OR (PRG_10_Outputs.CoupledFwd_Demand AND CoupledFwdBucketOk) THEN
        M1_Direction_Active := 1;
    ELSIF (PRG_10_Outputs.M1Rev_Demand AND NOT GVL_IHM.IHM_MANU.FdcBucketCloseActive) OR (PRG_10_Outputs.CoupledRev_Demand AND CoupledRevBucketOk) THEN
        M1_Direction_Active := -1;
    ELSE
        M1_Direction_Active := 0;
    END_IF;
    M1_StartStop_Active := (M1_Direction_Active <> 0);
    // 🎯 Joystick = vitesse proportionnelle à la déflexion (comme en Auto) ; boutons HMI = cible 100%
    // (FB_Winch rampe déjà en interne, plus besoin de la rampe HMI locale ex-PRG_10_Outputs).
    M1_SpeedRef_Active  := SEL(GVL_IHM.IHM_MANU.JoystickSelect, 100.0, ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef));
ELSE
    // 🔧 REX 2026-07-08 : + AND DeadmanArmed — NOT Busy seul insuffisant (rampe joystick met du
    // temps à redescendre à 0 après désarmement homme-mort ⇒ StartStop reste TRUE le temps de la
    // décél, M1 bougeait/frein décollait à la fin d'un cycle benne). DeadmanArmed reste FALSE
    // en continu jusqu'au repassage neutre + réappui, sans dépendre du temps de rampe.
    // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (nécessaire pour le gate directionnel ci-dessous).
    M1_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
    M1_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop AND NOT instBucket.Busy
                            AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1))); // 🔧 REX 2026-07-08 (5)
    M1_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
END_IF;

// ── 2. ARBITRAGE DES CONSIGNES M2 (Benne vs Cycle Automatique vs Joystick) ──
IF instBucket.Busy THEN
    M2_StartStop_Active := instBucket.M2_StartStop;
    M2_Direction_Active := instBucket.M2_Direction;
    M2_SpeedRef_Active  := 15.0; // Vitesse lente forcée pour fermeture benne
ELSE
    IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
        // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche, ajouté
        // symétrique à la branche manuelle ci-dessous (signe M2, voir note ci-dessous).
        M2_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM2_Direction;
        M2_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM2_StartStop
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
        M2_SpeedRef_Active  := PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct;
    ELSIF PRG_10_Outputs.ManuActive THEN
        // 🔧 REX 2026-07-15 (3) — idem M1 (voir §1) : Fins de course benne (FdcBucket) appliquées
        // au pilotage INDIVIDUEL **ET** COUPLÉ de M2 désormais (demande utilisateur — "que ce soit
        // couplé ou pas couplé, il faut rester dans les butées"). Ex-comportement (couplé non
        // masqué) retiré : c'était une incohérence, pas un choix voulu.
        IF (PRG_10_Outputs.M2Fwd_Demand AND NOT GVL_IHM.IHM_MANU.FdcBucketCloseActive) OR (PRG_10_Outputs.CoupledFwd_Demand AND CoupledFwdBucketOk) THEN
            M2_Direction_Active := 1;
        ELSIF (PRG_10_Outputs.M2Rev_Demand AND NOT GVL_IHM.IHM_MANU.FdcBucketOpenActive) OR (PRG_10_Outputs.CoupledRev_Demand AND CoupledRevBucketOk) THEN
            M2_Direction_Active := -1;
        ELSE
            M2_Direction_Active := 0;
        END_IF;
        M2_StartStop_Active := (M2_Direction_Active <> 0);
        M2_SpeedRef_Active  := SEL(GVL_IHM.IHM_MANU.JoystickSelect, 100.0, ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef));
    ELSE
        // 🔧 REX 2026-07-08 : + AND DeadmanArmed, même raison que M1 ci-dessus
        // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (gate directionnel)
        // 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (review code) : signe inversé pour M2. SignedDeltaPosM
        // (référentiel M1 : CablePosM1-CablePosM2+Offset) > 0 signifie M1 en avance — pour RATTRAPER,
        // M2 doit MONTER (+1), pas descendre. Donc BlocksUp (écart M1-en-avance) doit bloquer côté M2
        // le sens qui AGGRAVE, c-à-d Direction=-1 (descendre, M2 prend encore plus de retard) — PAS
        // Direction=+1 (monter, qui RATTRAPE). Symétrique inversé par rapport à M1 (qui utilise +1/-1
        // directement car SignedDeltaPosM est déjà dans SON référentiel).
        M2_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
        M2_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop
                                AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1))); // 🔧 REX 2026-07-08 (7)
        M2_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
    END_IF;
END_IF;

// ── 2bis. COUPURE IMMÉDIATE M1/M2 AU SCAN EXACT DE FIN DE CYCLE BENNE ─────
// 🆕 REX 2026-07-08 : instBucket est appelé en premier (§0), donc son Busy est frais dans CE scan
// (voir §1/§2 ci-dessus) — mais AxisCmdY.StartStop/Direction viennent de FB_Joystick_0 (PRG_01),
// calculé AVANT ce scan de PRG_06. Le désarmement homme-mort sur front descendant de Benne.Busy
// (FB_Joystick §4ter-ter) ne prend donc effet qu'au scan SUIVANT (~10ms de retard structurel). Si
// l'opérateur tient encore le manche poussé au moment exact où le benne termine, M1 ET M2
// recevaient pendant ce scan la commande manche brute (RelayFwd/Rev + BrakeCmd qui s'engage puis se
// coupe aussitôt = "clignotement" du frein, constaté sur site). On force ici l'arrêt immédiat,
// sans attendre le désarmement (qui reste nécessaire pour la suite : repassage au neutre exigé).
BenneBusyFallEdge(CLK := instBucket.Busy);
IF BenneBusyFallEdge.Q THEN
    M1_StartStop_Active := FALSE;
    M2_StartStop_Active := FALSE;
END_IF;

// ── 3. SURVEILLANCE ÉCART DE SYNCHRONISATION ────────────────────────────
instWinchSync(
    // 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (retour terrain, simulation) : écart transitoire (~0.27m)
    // constaté UNIQUEMENT à l'approche d'une butée (haute 12m ici), pas pendant le pilotage normal
    // (précision <0.001m confirmée par l'opérateur). Cause : ForbidAscent/ForbidDescent coupent
    // M1/M2 au même scan (couplage croisé), mais leur arrêt PHYSIQUE (rampe de décél, même en
    // simulation) n'est jamais parfaitement simultané à la position exacte — écart normal et non
    // significatif à ce moment précis, pas une vraie désynchro. Suppression pendant qu'un des deux
    // treuils est en butée (Ascent OU Descent), même principe que la suppression pendant BenneBusy
    // déjà existante. Lu avec 1 scan de retard (ForbidAscent/DescentMx_Active calculés plus bas dans
    // ce fichier) — acceptable, même raisonnement que SyncMinorDeviation ci-dessous.
    Enable          := PRG_04_Modes.instModes.SyncEnable AND NOT instBucket.Busy
                        AND NOT PRG_04_Modes.instModes.InhibitM1 AND NOT PRG_04_Modes.instModes.InhibitM2
                        AND NOT (ForbidAscentM1_Active OR ForbidAscentM2_Active
                                 OR ForbidDescentM1_Active OR ForbidDescentM2_Active), // 🆕 REX 2026-07-08 (7)
    Reset           := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    Mode            := PRG_04_Modes.instModes.Mode,
    CablePosM1      := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2      := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1         := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2         := PRG_02_Encoders.instHomingM2.Homed,
    SyncEnable      := PRG_04_Modes.instModes.SyncEnable,
    SyncToleranceM  := _WinchSyncTolerance_M,
    ActiveOffsetM   := instBucket.ActiveOffsetM,
    
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4
);

// Table active M2 (verrouille TOUS les paliers sur la combinaison réelle du palier 1 si
// vitesse lente requise pour le benne — REX 2026-07-08 : l'ancienne version mettait
// TOUS les contacteurs à FALSE pour tous les paliers, y compris le palier 1 lui-même, ce qui
// donnait un mouvement à vitesse quasi nulle/insuffisante (résistance rotorique maximale, aucun
// contacteur de vitesse engagé). Le palier 1 réel (`WinchSpeedStepTable.P1Rx`) engage déjà le
// contacteur le plus lent prévu pour un fonctionnement normal — on le duplique sur les 5 paliers
// pour que M2 reste TOUJOURS à cette vitesse pendant le benne, quelle que soit l'amplitude
// joystick (peu importe le palier sélectionné par l'hystérésis, le résultat est identique).
IF instBucket.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P1R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P1R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P1R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P2R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P2R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P2R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P2R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P3R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P3R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P3R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P3R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P4R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P4R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P4R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P4R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P5R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P5R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P5R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P5R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.StepThreshold_Pct := _WinchSpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := _WinchSpeedStepTable;
END_IF;

// ── 5. CALCUL DES LIMITES BASSES ACTIVES ET DU BLOCAGE DE DESCENTE ──────
// 🔧 REX 2026-07-07 : limite légale appliquée sur LimitLegalEnabled SEUL, plus de garde
// Mode=SEMI_AUTO — la limite légale doit stopper la descente dans TOUS les modes dès qu'elle
// est activée (constat terrain : ne s'arrêtait pas en MAINT_N1/N2 alors qu'attendu).
BottomLimitM1_Active := _CableLimitM1Descent_M;
IF _LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(BottomLimitM1_Active, _LimitLegalDepthMinAllowed_M);
END_IF;

BottomLimitM2_Active := _CableLimitM2Descent_M;
IF _LimitLegalEnabled THEN
    BottomLimitM2_Active := MAX(BottomLimitM2_Active, _LimitLegalDepthMinAllowed_M);
END_IF;

// ── 5bis. COUPLAGE CROISÉ M1/M2 — REX 2026-07-07 ────────────────────────
// Hors synchro (Benne.Busy ou SyncEnable=FALSE N2) : chaque treuil réagit à SA PROPRE limite/
// défaut uniquement (commande indépendante voulue). En synchro (SyncActive, mouvement cohérent
// voulu) : n'importe quel arrêt (SafeStop, limite câble, limite légale, fin de course haut) sur
// UN treuil coupe IMMÉDIATEMENT les deux — pas d'attente du filtre 500ms de FB_WinchSync.
// 🔧 REX 2026-07-07 : instBucket.M1SlipDetected ajouté à M1 uniquement (Méca C couche 1) — M2
// est déjà arrêté par son propre mécanisme SevereError interne à FB_Bucket, pas besoin ici.
// 🔧 REX 2026-07-08 (4) : instWinchSync.Error (bit0+bit1) → SEUL bit1 (incohérence commande,
// grave) reste ici en SafeStop fast. Bit0 (écart mineur) → arrêt rampe normale via StartStop
// (voir SyncMinorDeviation, §1/§2 plus haut) — Concept 1, ne pas dégrader le comportement voulu.
// 🆕 REX 2026-07-08 (6) : _SyncSoftStopEnable=FALSE (défaut) → comportement D'AVANT,
// bit0 réintégré ici en SafeStop fast classique comme n'importe quel autre défaut winch. TRUE →
// bit0 exclu d'ici, géré exclusivement par le gate directionnel StartStop (§1/§2).
SafeStopM1_Raw      := PRG_03_Safety.instSafetyWinchM1.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT _SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000))
                       OR instBucket.M1SlipDetected;
SafeStopM2_Raw      := PRG_03_Safety.instSafetyWinchM2.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT _SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000));

ForbidDescentM1_Raw := PRG_03_Safety.instSafetyWinchM1.ForbidDescent
                       OR (_LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M));
ForbidDescentM2_Raw := PRG_03_Safety.instSafetyWinchM2.ForbidDescent
                       OR (_LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M));

// 🔧 REX 2026-07-15 (6) — demande utilisateur : arrêt réel encodeur en fonctionnement NORMAL,
// distinct du capteur physique (bit5/Méca D côté FB_Safety_Winch). Seuil = CableLimitAscentMx_M,
// limite ABSOLUE indépendante (même principe que CableLimitDescentM1/2_M côté descente) —
// ex-calcul en MARGE sous HomingTargetMx_M (WinchTopStopMarginM) RETIRÉ : HomingTargetMx_M (12.5m)
// est réservée à l'approche petite vitesse du capteur physique pendant un Homing explicite, PAS
// à l'exploitation normale, qui doit s'arrêter proprement BIEN AVANT (12.0m par défaut) sans
// jamais réveiller le capteur physique (bit5/Méca D traitent son activation hors référencement
// comme une ANOMALIE — roue libre/contacteur collé — pas un fonctionnement normal).
// Même principe que la limite légale de descente ci-dessus (condition LIVE, pas de bit
// ErrorId/Reset dédié) — passe par ForbidAscentMx_Raw pour bénéficier DU MÊME couplage croisé
// M1/M2 que le capteur physique (sinon un treuil qui atteint la limite une fraction de seconde
// avant l'autre crée un écart RelayFwdM1<>RelayFwdM2 qui déclenche à tort le défaut FB_WinchSync
// bit1 "incohérence de commande" — REX terrain 2026-07-08, testé et corrigé).
// Bypass en MAINT_N2 via `HomingApproachEnable` (FB_Modes, même pattern que SyncEnable) :
// nécessite MAINT_N2 ET une case IHM activée consciemment pour dépasser CableLimitAscentMx_M
// et aller chercher le capteur physique en petite vitesse (Homing).
// 🆕 REX 2026-07-15 (8) : flag dédié — miroir IHM (GVL_IHM.M1TreuilRetenue.CableLimitAscentReached, voir
// PRG_09_Supervision), symétrique à CableLimitDescentReached. Réutilisé ci-dessous dans ForbidAscentM1_Raw.
CableLimitAscentM1Reached := PRG_02_Encoders.instHomingM1.Homed
                             AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                             AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _CableLimitM1Ascent_M)
                             AND NOT PRG_04_Modes.instModes.HomingApproachEnable;

ForbidAscentM1_Raw  := PRG_03_Safety.instSafetyWinchM1.ForbidAscent
                       OR (PRG_02_Encoders.instHomingM1.Homed
                           AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _HomingTargetM1_M))
                       OR CableLimitAscentM1Reached;
// 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (retour terrain) / REX 2026-07-08 (2) :
// La butée haute de M2 n'est décalée de l'OffsetCloseM QUE si le benne est fermé (IsClosed)
// ou en cours de fermeture (CloseReq). Sinon (benne ouvert/en cours d'ouverture), M2 doit
// s'arrêter à la butée normale (CableLimitAscentM2_M) pour s'arrêter proprement en même temps que M1.
M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketConfig.OffsetCloseM);

// 🆕 REX 2026-07-15 (8) : idem M1 (voir ci-dessus).
CableLimitAscentM2Reached := PRG_02_Encoders.instHomingM2.Homed
                             AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                             AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_CableLimitM2Ascent_M + M2_LimitShift))
                             AND NOT PRG_04_Modes.instModes.HomingApproachEnable;

ForbidAscentM2_Raw  := PRG_03_Safety.instSafetyWinchM2.ForbidAscent
                       OR (PRG_02_Encoders.instHomingM2.Homed
                           AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_HomingTargetM2_M + M2_LimitShift)))
                       OR CableLimitAscentM2Reached;

SafeStopM1_Active      := SafeStopM1_Raw      OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active      := SafeStopM2_Raw      OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
ForbidDescentM1_Active := ForbidDescentM1_Raw OR (instWinchSync.SyncActive AND ForbidDescentM2_Raw);
ForbidDescentM2_Active := ForbidDescentM2_Raw OR (instWinchSync.SyncActive AND ForbidDescentM1_Raw);
ForbidAscentM1_Active  := ForbidAscentM1_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM2_Raw);
ForbidAscentM2_Active  := ForbidAscentM2_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM1_Raw);

// ── 6. EXÉCUTION DU PILOTAGE DU TREUIL M1 ───────────────────────────────
instWinchM1(
    Enable                  := StubMachineEnableN1 AND NOT PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M1_StartStop_Active,
    SafeStop                := SafeStopM1_Active,
    ForbidDescent           := ForbidDescentM1_Active,
    ForbidAscent            := ForbidAscentM1_Active,
    Direction               := M1_Direction_Active,
    SpeedRefPct             := M1_SpeedRef_Active,
    SpeedStepTable          := _WinchSpeedStepTable,
    // 🔧 REX 2026-07-15 (9) : EffectiveMaxStepDescente/Ascent (voir calcul plus haut) — Auto garde
    // WinchMaxStepDescente/5 inchangés, Manu applique en plus WinchMaxStepFwd/Rev (essais progressifs).
    MaxStepDescente         := EffectiveMaxStepDescente,
    MaxStepAscent           := EffectiveMaxStepAscent,
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M1BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal,
    RampAccelRate           := _WinchM1RampAccelRate_Pct,
    RampDecelNormalRate     := _WinchM1RampDecelNormal_Pct,
    RampDecelFastRate       := _WinchM1RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM1.HomingSuspect, // 🆕 Câblage de l'incertitude M1
    CablePosM               := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    // 🔧 REX 2026-07-15 (6) : CableLimitAscentM1_M (limite ABSOLUE d'exploitation normale, ex-
    // HomingTargetM1_M) — la rampe/ralentissement de FB_Winch cible désormais la même limite que
    // ForbidAscentM1_Raw ci-dessus, pas le capteur physique (réservé au Homing).
    TopLimitM               := _CableLimitM1Ascent_M,
    BottomLimitM            := BottomLimitM1_Active,
    SlowdownDistanceM       := _WinchSlowdownDistance_M,
    SlowSpeedPct            := _WinchSlowSpeed_Pct
);

// ── 7. EXÉCUTION DU PILOTAGE DU TREUIL M2 ───────────────────────────────
instWinchM2(
    Enable                  := StubMachineEnableN1 AND NOT PRG_04_Modes.instModes.InhibitM2, // 🆕 REX 2026-07-08
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M2_StartStop_Active,
    SafeStop                := SafeStopM2_Active,
    ForbidDescent           := ForbidDescentM2_Active,
    ForbidAscent            := ForbidAscentM2_Active,
    Direction               := M2_Direction_Active,
    SpeedRefPct             := M2_SpeedRef_Active,
    SpeedStepTable          := M2_SpeedStepTableActive,
    // 🔧 REX 2026-07-15 (9) : idem M1 (voir §6 ci-dessus).
    MaxStepDescente         := EffectiveMaxStepDescente,
    MaxStepAscent           := EffectiveMaxStepAscent,
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M2BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal,
    RampAccelRate           := _WinchM2RampAccelRate_Pct,
    RampDecelNormalRate     := _WinchM2RampDecelNormal_Pct,
    RampDecelFastRate       := _WinchM2RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM2.HomingSuspect, // 🆕 Câblage de l'incertitude M2
    CablePosM               := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    // 🔧 REX 2026-07-15 (6) : idem M1 (voir ci-dessus), + M2_LimitShift (décalage benne fermé).
    TopLimitM               := _CableLimitM2Ascent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    SlowdownDistanceM       := _WinchSlowdownDistance_M,
    SlowSpeedPct            := _WinchSlowSpeed_Pct
);

// ── 8. ALIMENTATION PRG_10_Outputs (sorties physiques) ──────────────────
// 🔴🔧 REX 2026-07-07 : PRG_10_Outputs est une tâche indépendante (MainTask, PouList),
// jamais appelée avec paramètres — ses VAR_INPUT restaient à FALSE en permanence, y compris
// sur machine réelle (aucun relais/contacteur/frein ne s'activait jamais). Alimentation directe
// ici, AVANT PRG_10_Outputs dans l'ordre de tâche (position 6 < 10, même cycle API).
PRG_10_Outputs.M1RelayFwd        := instWinchM1.RelayFwd;
PRG_10_Outputs.M1RelayRev        := instWinchM1.RelayRev;
PRG_10_Outputs.M1SpeedContactor1 := instWinchM1.Contactor1;
PRG_10_Outputs.M1SpeedContactor2 := instWinchM1.Contactor2;
PRG_10_Outputs.M1SpeedContactor3 := instWinchM1.Contactor3;
PRG_10_Outputs.M1SpeedContactor4 := instWinchM1.Contactor4;
PRG_10_Outputs.M1BrakeCmd        := instWinchM1.BrakeCmd;

PRG_10_Outputs.M2RelayFwd        := instWinchM2.RelayFwd;
PRG_10_Outputs.M2RelayRev        := instWinchM2.RelayRev;
PRG_10_Outputs.M2SpeedContactor1 := instWinchM2.Contactor1;
PRG_10_Outputs.M2SpeedContactor2 := instWinchM2.Contactor2;
PRG_10_Outputs.M2SpeedContactor3 := instWinchM2.Contactor3;
PRG_10_Outputs.M2SpeedContactor4 := instWinchM2.Contactor4;
PRG_10_Outputs.M2BrakeCmd        := instWinchM2.BrakeCmd;

// 🧪 Références pour tests PLC (fenêtre de passage GVL_Simulation)
// 🔧 REX 2026-07-17 : ":=" sur une REFERENCE TO fait une COPIE DE VALEUR (écrit à travers la
// référence), PAS un rebind -- sur une référence pas encore liée (1er scan), ça écrit à une
// adresse invalide -> ACCESS VIOLATION runtime CODESYS. "REF=" est l'opérateur dédié au rebind.
GVL_Simulation.refBucket   REF= instBucket;
GVL_Simulation.refWinchM2  REF= instWinchM2;
