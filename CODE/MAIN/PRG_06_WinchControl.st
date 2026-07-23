(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_06_WinchControl — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 6.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   📄 Docs : DOC/AF_Partie-09_Fonction_Winch_v1.11.md ; DOC/AF_Partie-12_Fonction_Benne_v1.4.md
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
    // 🛡️ T47 — désactivé jusqu'à validation des seuils et essais terrain.
    SpeedGuardEnableM1 : BOOL := FALSE;
    SpeedGuardEnableM2 : BOOL := FALSE;

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

    // 🆕 REX 2026-07-19 : palier max Ascension/Descente — même valeur en Auto ET Manuel
    // (ex-plafond IHM_MANU "essais progressifs" retiré avec la suppression d'IHM_MANU, voir
    // ARCHIVES/Doc/IHM_MANU_Journal_Modifications.md).
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
    CmdOpen_IHM         := GVL_IHM.M2Benne.BtnOpen OR PRG_05_Cycle.instCycle.CmdBucket_Open,
    CmdClose_IHM        := GVL_IHM.M2Benne.BtnClose OR PRG_05_Cycle.instCycle.CmdBucket_Close,
    JoystickY_StartStop := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop,
    JoystickY_Direction := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction,
    CablePosM1          := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2          := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1             := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2             := PRG_02_Encoders.instHomingM2.Homed,
    M1_Busy             := instWinchM1.Busy,   // 🆕 REX 2026-07-08
    M2_Busy             := instWinchM2.Busy,   // 🆕 REX 2026-07-08
    ConfirmOpenPosition := GVL_IHM.M2Benne.BtnConfirmOpenPos, // 🆕 REX 2026-07-08 — bouton IHM référencement benne ouvert
    ConfirmClosePosition:= GVL_IHM.M2Benne.BtnConfirmClosePos, // 🆕 REX 2026-07-08 — bouton IHM référencement benne fermé
    Config              := _BucketConfig,
    CfgTimeoutDuration     := GVL_IHM.M2Benne.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08
    InhibitM2           := PRG_04_Modes.instModes.InhibitM2,  // 🆕 REX 2026-07-08
    BypassGlobal        := GVL_IHM.M2Benne.BypassGlobal      // 🌐 Bypass benne (RETAIN)
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

// 🔧 REX 2026-07-19 : palier max — même valeur Auto ET Manuel depuis la suppression d'IHM_MANU
// (ex-plafond "essais progressifs" IHM_MANU, explicitement marqué TEMPORAIRE, retiré).
EffectiveMaxStepAscent   := _WinchMaxStepAscent;
EffectiveMaxStepDescente := _WinchMaxStepDescent;

// ── 1. ARBITRAGE DES CONSIGNES M1 (Joystick vs Cycle Automatique) ────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche (bug trouvé en
    // review code), le cycle auto pouvait aggraver un écart mineur sans aucune protection quand
    // SyncSoftStopEnable=TRUE. Ajouté ici, symétrique à la branche manuelle ci-dessous.
    M1_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM1_Direction;
    // 🛡️ SEMI_AUTO reste conditionné par l'homme-mort : relâchement = arrêt,
    // nouvelle sollicitation valide = reprise à l'étape courante.
    M1_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM1_StartStop
                            AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                            AND PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
    M1_SpeedRef_Active  := MIN(PRG_05_Cycle.instCycle.CmdWinchM1_SpeedPct,
                               ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef));
ELSE
    // 🔧 REX 2026-07-19 : suppression IHM_MANU — MAINT_N1/MAINT_N2. 🆕 REX (session WINCH-BTN-01,
    // réouverture documentée T40) : le joystick n'est plus la SEULE source —
    // GVL_IHM.Modes.TglJoystickMaster bascule vers les boutons IHM maintenus (BtnUp/BtnDown),
    // homme-mort joystick réel TOUJOURS exigé en parallèle (même leçon que le précédent bug
    // Translation M3, AF_Partie-11 v1.9 §6bis — jamais implicite). Voir
    // DOC/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md.
    // 🆕 Sélection treuil (TASK-0001, MAINT_N2 uniquement, voir FB_Modes.JoystickWinchSelectArbitrated) :
    // 1=M1 seul, 2=M2 seul, 3=Couplé — forcé à 3 (Couplé) hors MAINT_N2, IDENTIQUE quelle que
    // soit la source (joystick ou boutons) — pas de duplication de la logique de sélection.
    // 🔧 REX 2026-07-08 : + AND DeadmanArmed — NOT Busy seul insuffisant (rampe joystick met du
    // temps à redescendre à 0 après désarmement homme-mort ⇒ StartStop reste TRUE le temps de la
    // décél, M1 bougeait/frein décollait à la fin d'un cycle benne). DeadmanArmed reste FALSE
    // en continu jusqu'au repassage neutre + réappui, sans dépendre du temps de rampe.
    // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (nécessaire pour le gate directionnel ci-dessous).
    IF GVL_IHM.Modes.TglJoystickMaster THEN
        // Source = joystick (comportement historique, inchangé)
        M1_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
        M1_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop AND NOT instBucket.Busy
                                AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                AND (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 1
                                     OR PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 3)
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1))); // 🔧 REX 2026-07-08 (5)
        M1_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
    ELSE
        // 🆕 Source = boutons IHM maintenus — pilotage direct par 6 boutons (M1 Up/Down, M2 Up/Down, Both Up/Down)
        // Remplacent l'ancien sélecteur JoystickWinchSelectArbitrated.
        // Priorité : Both > M1/M2 individuels
        IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M1TreuilRetenue.Cmd.BtnUp THEN
            M1_Direction_Active := 1;
        ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M1TreuilRetenue.Cmd.BtnDown THEN
            M1_Direction_Active := -1;
        ELSE
            M1_Direction_Active := 0;
        END_IF;
        M1_StartStop_Active := (M1_Direction_Active <> 0) AND NOT instBucket.Busy
                                AND (PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                     OR GVL_IHM.M1TreuilRetenue.Bypass.Global)
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
        M1_SpeedRef_Active  := 100.0;
    END_IF;
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
        // 🛡️ Même garde homme-mort que M1 : le cycle ne poursuit jamais un mouvement
        // après relâchement du joystick.
        M2_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM2_StartStop
                                AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                AND PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
        M2_SpeedRef_Active  := MIN(PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct,
                                   ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef));
    ELSE
        // 🔧 REX 2026-07-19 : suppression IHM_MANU — MAINT_N1/MAINT_N2. 🆕 REX (session WINCH-BTN-01) :
        // idem M1 (voir bandeau branche M1 ci-dessus) — GVL_IHM.Modes.TglJoystickMaster bascule la
        // SOURCE, JoystickWinchSelectArbitrated reste l'unique sélecteur treuil (2=M2 seul, 3=Couplé,
        // forcé à 3 hors MAINT_N2), IDENTIQUE quelle que soit la source.
        // 🔧 REX 2026-07-08 : + AND DeadmanArmed, même raison que M1 ci-dessus
        // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (gate directionnel)
        // 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (review code) : signe inversé pour M2. SignedDeltaPosM
        // (référentiel M1 : CablePosM1-CablePosM2+Offset) > 0 signifie M1 en avance — pour RATTRAPER,
        // M2 doit MONTER (+1), pas descendre. Donc BlocksUp (écart M1-en-avance) doit bloquer côté M2
        // le sens qui AGGRAVE, c-à-d Direction=-1 (descendre, M2 prend encore plus de retard) — PAS
        // Direction=+1 (monter, qui RATTRAPE). Symétrique inversé par rapport à M1 (qui utilise +1/-1
        // directement car SignedDeltaPosM est déjà dans SON référentiel). Même inversion appliquée
        // à la branche boutons IHM ci-dessous (BtnUp M2 = Direction -1, RATTRAPE si M1 en retard).
        IF GVL_IHM.Modes.TglJoystickMaster THEN
            M2_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
            M2_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop
                                    AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                    AND (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 2
                                         OR PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 3)
                                    AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                         OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1))); // 🔧 REX 2026-07-08 (7)
            M2_SpeedRef_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
        ELSE
            // 🆕 Source = boutons IHM maintenus (WINCH-BTN-01) — BtnUp M2 = enroulage/montée (+1),
            // 🆕 Source = boutons IHM maintenus — pilotage direct par 6 boutons (M1 Up/Down, M2 Up/Down, Both Up/Down)
            // Priorité : Both > M2 > M1
            IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M2TreuilBenne.Cmd.BtnUp THEN
                M2_Direction_Active := 1;
            ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M2TreuilBenne.Cmd.BtnDown THEN
                M2_Direction_Active := -1;
            ELSE
                M2_Direction_Active := 0;
            END_IF;
            M2_StartStop_Active := (M2_Direction_Active <> 0)
                                    AND (PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                                         OR GVL_IHM.M2TreuilBenne.Bypass.Global)
                                    AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                         OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
            M2_SpeedRef_Active := 100.0;
        END_IF;
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
    // constaté UNIQUEMENT à l'approche d'une butée (haute 8,0 m ici), pas pendant le pilotage normal
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
    CfgSyncToleranceM  := _WinchSyncTolerance_M,
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
    Contactor4_M2   := instWinchM2.Contactor4,
    BypassGlobal    := GVL_IHM.Sync.BypassGlobal
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

ForbidDescentM1_Raw := (NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND PRG_03_Safety.instSafetyWinchM1.ForbidDescent)
                       OR (_LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M));
ForbidDescentM2_Raw := (NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND PRG_03_Safety.instSafetyWinchM2.ForbidDescent)
                       OR (_LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M));

// 🔧 REX 2026-07-15 (6) — demande utilisateur : arrêt réel encodeur en fonctionnement NORMAL,
// distinct du capteur physique (bit5/Méca D côté FB_Safety_Winch). Seuil = CableLimitAscentMx_M,
// limite ABSOLUE indépendante (même principe que CableLimitDescentM1/2_M côté descente) —
// ex-calcul en MARGE sous HomingTargetMx_M retiré : HomingTargetMx_M (8,5 m)
// est réservée à l'approche petite vitesse du capteur physique pendant un Homing explicite, PAS
// à l'exploitation normale, qui doit s'arrêter proprement à 8,0 m sans
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

ForbidAscentM1_Raw  := NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND (
                          PRG_03_Safety.instSafetyWinchM1.ForbidAscent
                          OR (PRG_02_Encoders.instHomingM1.Homed
                              AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                              AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _HomingTargetM1_M))
                          OR CableLimitAscentM1Reached
                       );
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

ForbidAscentM2_Raw  := NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND (
                          PRG_03_Safety.instSafetyWinchM2.ForbidAscent
                          OR (PRG_02_Encoders.instHomingM2.Homed
                              AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                              AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_HomingTargetM2_M + M2_LimitShift)))
                          OR CableLimitAscentM2Reached
                       );

SafeStopM1_Active      := SafeStopM1_Raw      OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active      := SafeStopM2_Raw      OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
ForbidDescentM1_Active := ForbidDescentM1_Raw OR (instWinchSync.SyncActive AND ForbidDescentM2_Raw);
ForbidDescentM2_Active := ForbidDescentM2_Raw OR (instWinchSync.SyncActive AND ForbidDescentM1_Raw);
ForbidAscentM1_Active  := ForbidAscentM1_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM2_Raw);
ForbidAscentM2_Active  := ForbidAscentM2_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM1_Raw);

// ── 6. EXÉCUTION DU PILOTAGE DU TREUIL M1 ───────────────────────────────
instWinchM1(
    Enable                  := StubMachineEnableN1
                               AND (PRG_04_Modes.instModes.Mode <> E_Mode.DISABLE)
                               AND NOT PRG_04_Modes.instModes.InhibitM1, // 🔧 WINCH-CORE-01 : DISABLE neutralise réellement M1
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
    CfgMaxStepDescente         := EffectiveMaxStepDescente,
    MaxStepAscent           := EffectiveMaxStepAscent,
    MeasuredSpeedBand       := PRG_03_Safety.instLoadEstimatorM1.SpeedBand,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := PRG_03_Safety.instSpeedMonitorM1.SpeedStable
                               AND NOT PRG_03_Safety.instSpeedMonitorM1.SpeedVariationConfirmed
                               AND NOT instWinchSync.Error,
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M1BrakeFeedback,
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal),
    CfgRampAccelRate           := _WinchM1RampAccelRate_Pct,
    CfgRampDecelNormalRate     := _WinchM1RampDecelNormal_Pct,
    CfgRampDecelFastRate       := _WinchM1RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM1.HomingSuspect, // 🆕 Câblage de l'incertitude M1
    CablePosM               := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    // 🔧 REX 2026-07-15 (6) : CableLimitAscentM1_M (limite ABSOLUE d'exploitation normale, ex-
    // HomingTargetM1_M) — la rampe/ralentissement de FB_Winch cible désormais la même limite que
    // ForbidAscentM1_Raw ci-dessus, pas le capteur physique (réservé au Homing).
    TopLimitM               := _CableLimitM1Ascent_M,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM       := _WinchSlowdownDistance_M,
    CfgSlowSpeedPct            := _WinchSlowSpeed_Pct,
    // 🌐 Bypass Global M1 (GVL_IHM.M1TreuilRetenue.Bypass.Global)
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

// ── 7. EXÉCUTION DU PILOTAGE DU TREUIL M2 ───────────────────────────────
instWinchM2(
    Enable                  := StubMachineEnableN1
                               AND (PRG_04_Modes.instModes.Mode <> E_Mode.DISABLE)
                               AND NOT PRG_04_Modes.instModes.InhibitM2, // 🔧 WINCH-CORE-01 : DISABLE neutralise réellement M2
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
    CfgMaxStepDescente         := EffectiveMaxStepDescente,
    MaxStepAscent           := EffectiveMaxStepAscent,
    MeasuredSpeedBand       := PRG_03_Safety.instLoadEstimatorM2.SpeedBand,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := PRG_03_Safety.instSpeedMonitorM2.SpeedStable
                               AND NOT PRG_03_Safety.instSpeedMonitorM2.SpeedVariationConfirmed
                               AND NOT instWinchSync.Error,
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M2BrakeFeedback,
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM2ContactorFeedbackIsReal),
    CfgRampAccelRate           := _WinchM2RampAccelRate_Pct,
    CfgRampDecelNormalRate     := _WinchM2RampDecelNormal_Pct,
    CfgRampDecelFastRate       := _WinchM2RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM2.HomingSuspect, // 🆕 Câblage de l'incertitude M2
    CablePosM               := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    // 🔧 REX 2026-07-15 (6) : idem M1 (voir ci-dessus), + M2_LimitShift (décalage benne fermé).
    TopLimitM               := _CableLimitM2Ascent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM       := _WinchSlowdownDistance_M,
    CfgSlowSpeedPct            := _WinchSlowSpeed_Pct,
    // 🌐 Bypass Global M2 (GVL_IHM.M2TreuilBenne.Bypass.Global)
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
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
PRG_10_Outputs.KoboldContactorCmd := PRG_05_Cycle.instCycle.KoboldContactorCmd;
PRG_10_Outputs.M2BrakeCmd        := instWinchM2.BrakeCmd;

// 🧪 Références pour tests PLC (fenêtre de passage GVL_Simulation)
// 🔧 REX 2026-07-17 : ":=" sur une REFERENCE TO fait une COPIE DE VALEUR (écrit à travers la
// référence), PAS un rebind -- sur une référence pas encore liée (1er scan), ça écrit à une
// adresse invalide -> ACCESS VIOLATION runtime CODESYS. "REF=" est l'opérateur dédié au rebind.
GVL_Simulation.LinkBucket   REF= instBucket;
GVL_Simulation.LinkWinchM2  REF= instWinchM2;
