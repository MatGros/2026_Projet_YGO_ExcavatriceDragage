(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_06_WinchControl — Commande des Treuils M1/M2, Synchro et Grappin
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
    instGrappin   : FB_Grappin;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;

    // Variables de commande M1 après arbitrage Manuel/Auto
    M1_StartStop_Active     : BOOL;
    M1_Direction_Active     : INT;
    M1_SpeedRef_Active      : REAL;

    // Variables de commande M2 après arbitrage Grappin/Manuel/Auto
    M2_StartStop_Active     : BOOL;
    M2_Direction_Active     : INT;
    M2_SpeedRef_Active      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    // Bornage et limites
    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;

    // 🔧 REX 2026-07-07 : couplage croisé M1/M2 des arrêts, UNIQUEMENT si SyncActive (mouvement
    // coherent voulu). Hors synchro (Grappin.Busy ou SyncEnable=FALSE MAINT_N2) : chaque treuil réagit
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
    // grappin (contrairement au désarmement homme-mort côté FB_Joystick, qui a 1 scan de retard
    // structurel — PRG_01 s'exécute avant PRG_06). Corrige un bref "blip" de commande (RelayFwd/Rev
    // + BrakeCmd clignotant) observé sur M1 à l'arrivée en position grappin.
    GrappinBusyFallEdge     : F_TRIG;

    // 🆕 REX 2026-07-08 (4) : instWinchSync appelé APRÈS l'arbitrage M1/M2 (§3, plus bas) — lu ici
    // avec 1 scan de retard (~10ms), négligeable vu que DeltaPosM évolue progressivement, pas
    // par à-coup (même raisonnement que M1_Busy/M2_Busy sur instGrappin, voir §0).
    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;   // 🆕 REX 2026-07-08 (5) : bit0 latché ET écart actuel aggravé par la montée
    SyncMinorDeviationBlocksDown : BOOL;   // 🆕 REX 2026-07-08 (5) : bit0 latché ET écart actuel aggravé par la descente
    M2_LimitShift                : REAL;   // 🆕 REX 2026-07-08 : décalage dynamique de la butée haute de M2
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_06_WinchControl) ===

// ── 0. COMMANDE DU GRAPPIN (Séquence lente) ─────────────────────────────
// 🔧 REX 2026-07-08 : appelé EN PREMIER (avant l'arbitrage M1/M2 ci-dessous) — audit sécurité :
// l'ancien ordre (Grappin appelé après l'arbitrage) faisait que M1_StartStop_Active lisait
// instGrappin.Busy du scan PRÉCÉDENT, créant une fenêtre d'1 scan où M1 pouvait recevoir une
// commande manuelle au moment exact où le grappin démarre. instGrappin.M1_Busy/M2_Busy (ci-dessous)
// lisent en retour instWinchM1/M2.Busy du scan précédent (ces FB sont appelés plus loin, §6/§7) —
// acceptable : ça ne retarde que l'ACCEPTATION d'une nouvelle demande de ~1 scan (10ms), sans
// aucun impact sécurité (contrairement au cas inverse, qui pouvait faire bouger M1 pendant Busy).
instGrappin(
    Enable              := NOT PRG_04_Modes.instModes.InhibitM2
                           AND PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable
                           AND PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable, // 🆕 Sécurisé : nécessite les deux codeurs valides et M2 non-inhibé
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    CmdOpen_IHM         := GVL_IHM.Grappin.CmdOpen OR PRG_05_Cycle.instCycle.CmdGrappin_Open,
    CmdClose_IHM        := GVL_IHM.Grappin.CmdClose OR PRG_05_Cycle.instCycle.CmdGrappin_Close,
    JoystickY_StartStop := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop,
    JoystickY_Direction := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction,
    CablePosM1          := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2          := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1             := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2             := PRG_02_Encoders.instHomingM2.Homed,
    M1_Busy             := instWinchM1.Busy,   // 🆕 REX 2026-07-08
    M2_Busy             := instWinchM2.Busy,   // 🆕 REX 2026-07-08
    ConfirmOpenPosition := GVL_IHM.Grappin.CmdConfirmOpenPosition, // 🆕 REX 2026-07-08 — bouton IHM référencement grappin ouvert
    ConfirmClosePosition:= GVL_IHM.Grappin.CmdConfirmClosePosition, // 🆕 REX 2026-07-08 — bouton IHM référencement grappin fermé
    Config              := GVL_PERSISTENT.GrappinConfig,
    TimeoutDuration     := GVL_IHM.Grappin.TimeoutDuration,
    GrappinState        := GVL_PERSISTENT.GrappinState,
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
SyncMinorDeviationBlocksUp   := GVL_PERSISTENT.SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0);
SyncMinorDeviationBlocksDown := GVL_PERSISTENT.SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0);

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
ELSE
    // 🔧 REX 2026-07-08 : + AND DeadmanArmed — NOT Busy seul insuffisant (rampe joystick met du
    // temps à redescendre à 0 après désarmement homme-mort ⇒ StartStop reste TRUE le temps de la
    // décél, M1 bougeait/frein décollait à la fin d'un cycle grappin). DeadmanArmed reste FALSE
    // en continu jusqu'au repassage neutre + réappui, sans dépendre du temps de rampe.
    // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (nécessaire pour le gate directionnel ci-dessous).
    M1_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
    M1_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop AND NOT instGrappin.Busy
                            AND PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1))); // 🔧 REX 2026-07-08 (5)
    M1_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
END_IF;

// ── 2. ARBITRAGE DES CONSIGNES M2 (Grappin vs Cycle Automatique vs Joystick) ──
IF instGrappin.Busy THEN
    M2_StartStop_Active := instGrappin.M2_StartStop;
    M2_Direction_Active := instGrappin.M2_Direction;
    M2_SpeedRef_Active  := 15.0; // Vitesse lente forcée pour fermeture grappin
ELSE
    IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
        // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche, ajouté
        // symétrique à la branche manuelle ci-dessous (signe M2, voir note ci-dessous).
        M2_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM2_Direction;
        M2_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM2_StartStop
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
        M2_SpeedRef_Active  := PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct;
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

// ── 2bis. COUPURE IMMÉDIATE M1/M2 AU SCAN EXACT DE FIN DE CYCLE GRAPPIN ─────
// 🆕 REX 2026-07-08 : instGrappin est appelé en premier (§0), donc son Busy est frais dans CE scan
// (voir §1/§2 ci-dessus) — mais AxisCmdY.StartStop/Direction viennent de FB_Joystick_0 (PRG_01),
// calculé AVANT ce scan de PRG_06. Le désarmement homme-mort sur front descendant de Grappin.Busy
// (FB_Joystick §4ter-ter) ne prend donc effet qu'au scan SUIVANT (~10ms de retard structurel). Si
// l'opérateur tient encore le manche poussé au moment exact où le grappin termine, M1 ET M2
// recevaient pendant ce scan la commande manche brute (RelayFwd/Rev + BrakeCmd qui s'engage puis se
// coupe aussitôt = "clignotement" du frein, constaté sur site). On force ici l'arrêt immédiat,
// sans attendre le désarmement (qui reste nécessaire pour la suite : repassage au neutre exigé).
GrappinBusyFallEdge(CLK := instGrappin.Busy);
IF GrappinBusyFallEdge.Q THEN
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
    // treuils est en butée (Ascent OU Descent), même principe que la suppression pendant GrappinBusy
    // déjà existante. Lu avec 1 scan de retard (ForbidAscent/DescentMx_Active calculés plus bas dans
    // ce fichier) — acceptable, même raisonnement que SyncMinorDeviation ci-dessous.
    Enable          := PRG_04_Modes.instModes.SyncEnable AND NOT instGrappin.Busy
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
    SyncToleranceM  := GVL_PERSISTENT.WinchSyncTolerance_M,
    ActiveOffsetM   := instGrappin.ActiveOffsetM,
    
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
// vitesse lente requise pour le grappin — REX 2026-07-08 : l'ancienne version mettait
// TOUS les contacteurs à FALSE pour tous les paliers, y compris le palier 1 lui-même, ce qui
// donnait un mouvement à vitesse quasi nulle/insuffisante (résistance rotorique maximale, aucun
// contacteur de vitesse engagé). Le palier 1 réel (`WinchSpeedStepTable.P1Rx`) engage déjà le
// contacteur le plus lent prévu pour un fonctionnement normal — on le duplique sur les 5 paliers
// pour que M2 reste TOUJOURS à cette vitesse pendant le grappin, quelle que soit l'amplitude
// joystick (peu importe le palier sélectionné par l'hystérésis, le résultat est identique).
IF instGrappin.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := GVL_PERSISTENT.WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P1R2 := GVL_PERSISTENT.WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P1R3 := GVL_PERSISTENT.WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P1R4 := GVL_PERSISTENT.WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P2R1 := GVL_PERSISTENT.WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P2R2 := GVL_PERSISTENT.WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P2R3 := GVL_PERSISTENT.WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P2R4 := GVL_PERSISTENT.WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P3R1 := GVL_PERSISTENT.WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P3R2 := GVL_PERSISTENT.WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P3R3 := GVL_PERSISTENT.WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P3R4 := GVL_PERSISTENT.WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P4R1 := GVL_PERSISTENT.WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P4R2 := GVL_PERSISTENT.WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P4R3 := GVL_PERSISTENT.WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P4R4 := GVL_PERSISTENT.WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P5R1 := GVL_PERSISTENT.WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P5R2 := GVL_PERSISTENT.WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P5R3 := GVL_PERSISTENT.WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P5R4 := GVL_PERSISTENT.WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.StepThreshold_Pct := GVL_PERSISTENT.WinchSpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := GVL_PERSISTENT.WinchSpeedStepTable;
END_IF;

// ── 5. CALCUL DES LIMITES BASSES ACTIVES ET DU BLOCAGE DE DESCENTE ──────
// 🔧 REX 2026-07-07 : limite légale appliquée sur LimitLegalEnabled SEUL, plus de garde
// Mode=SEMI_AUTO — la limite légale doit stopper la descente dans TOUS les modes dès qu'elle
// est activée (constat terrain : ne s'arrêtait pas en MAINT_N1/N2 alors qu'attendu).
BottomLimitM1_Active := GVL_PERSISTENT.CableLimitDescentM1_M;
IF GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(BottomLimitM1_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

BottomLimitM2_Active := GVL_PERSISTENT.CableLimitDescentM2_M;
IF GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM2_Active := MAX(BottomLimitM2_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

// ── 5bis. COUPLAGE CROISÉ M1/M2 — REX 2026-07-07 ────────────────────────
// Hors synchro (Grappin.Busy ou SyncEnable=FALSE N2) : chaque treuil réagit à SA PROPRE limite/
// défaut uniquement (commande indépendante voulue). En synchro (SyncActive, mouvement cohérent
// voulu) : n'importe quel arrêt (SafeStop, limite câble, limite légale, fin de course haut) sur
// UN treuil coupe IMMÉDIATEMENT les deux — pas d'attente du filtre 500ms de FB_WinchSync.
// 🔧 REX 2026-07-07 : instGrappin.M1SlipDetected ajouté à M1 uniquement (Méca C couche 1) — M2
// est déjà arrêté par son propre mécanisme SevereError interne à FB_Grappin, pas besoin ici.
// 🔧 REX 2026-07-08 (4) : instWinchSync.Error (bit0+bit1) → SEUL bit1 (incohérence commande,
// grave) reste ici en SafeStop fast. Bit0 (écart mineur) → arrêt rampe normale via StartStop
// (voir SyncMinorDeviation, §1/§2 plus haut) — Concept 1, ne pas dégrader le comportement voulu.
// 🆕 REX 2026-07-08 (6) : GVL_PERSISTENT.SyncSoftStopEnable=FALSE (défaut) → comportement D'AVANT,
// bit0 réintégré ici en SafeStop fast classique comme n'importe quel autre défaut winch. TRUE →
// bit0 exclu d'ici, géré exclusivement par le gate directionnel StartStop (§1/§2).
SafeStopM1_Raw      := PRG_03_Safety.instSafetyWinchM1.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT GVL_PERSISTENT.SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000))
                       OR instGrappin.M1SlipDetected;
SafeStopM2_Raw      := PRG_03_Safety.instSafetyWinchM2.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT GVL_PERSISTENT.SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000));

ForbidDescentM1_Raw := PRG_03_Safety.instSafetyWinchM1.ForbidDescent
                       OR (GVL_PERSISTENT.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));
ForbidDescentM2_Raw := PRG_03_Safety.instSafetyWinchM2.ForbidDescent
                       OR (GVL_PERSISTENT.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));

// 🔧 REX 2026-07-08 : arrêt réel encodeur en fonctionnement NORMAL, distinct du capteur physique
// (bit5 côté FB_Safety_Winch). Seuil = HomingTargetMx_M - WinchTopStopMarginM (RELATIF à la
// position haute de référence, pas une valeur absolue) : si HomingTargetMx_M est recalibrée sur
// site, la position d'arrêt normal suit automatiquement, toujours à la même marge du capteur.
// Même principe que la limite légale de descente ci-dessus (condition LIVE, pas de bit
// ErrorId/Reset dédié) — passe par ForbidAscentMx_Raw pour bénéficier DU MÊME couplage croisé
// M1/M2 que le capteur physique (sinon un treuil qui atteint la limite une fraction de seconde
// avant l'autre crée un écart RelayFwdM1<>RelayFwdM2 qui déclenche à tort le défaut FB_WinchSync
// bit1 "incohérence de commande" — REX terrain 2026-07-08, testé et corrigé).
// homing), sans qu'aucun bit dédié ne soit requis. Remplacé par `HomingApproachEnable` (FB_Modes,
// même pattern que SyncEnable) : nécessite MAINT_N2 ET une case IHM activée consciemment.
ForbidAscentM1_Raw  := PRG_03_Safety.instSafetyWinchM1.ForbidAscent
                       OR (PRG_02_Encoders.instHomingM1.Homed
                           AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= GVL_PERSISTENT.HomingTargetM1_M))
                       OR (PRG_02_Encoders.instHomingM1.Homed
                           AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >=
                                (GVL_PERSISTENT.HomingTargetM1_M - GVL_PERSISTENT.WinchTopStopMarginM))
                           AND NOT PRG_04_Modes.instModes.HomingApproachEnable);
// 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (retour terrain) / REX 2026-07-08 (2) :
// La butée haute de M2 n'est décalée de l'OffsetCloseM QUE si le grappin est fermé (IsClosed)
// ou en cours de fermeture (CloseReq). Sinon (grappin ouvert/en cours d'ouverture), M2 doit
// s'arrêter à la butée normale de 12.00m (HomingTargetM2_M - margin) pour s'arrêter proprement en même temps que M1.
M2_LimitShift := SEL(GVL_PERSISTENT.GrappinState.IsClosed OR instGrappin.CloseReq, 0.0, GVL_PERSISTENT.GrappinConfig.OffsetCloseM);

ForbidAscentM2_Raw  := PRG_03_Safety.instSafetyWinchM2.ForbidAscent
                       OR (PRG_02_Encoders.instHomingM2.Homed
                           AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (GVL_PERSISTENT.HomingTargetM2_M + M2_LimitShift)))
                       OR (PRG_02_Encoders.instHomingM2.Homed
                           AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >=
                                (GVL_PERSISTENT.HomingTargetM2_M + M2_LimitShift - GVL_PERSISTENT.WinchTopStopMarginM))
                           AND NOT PRG_04_Modes.instModes.HomingApproachEnable);

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
    SpeedStepTable          := GVL_PERSISTENT.WinchSpeedStepTable,
    MaxStepDescente         := GVL_PERSISTENT.WinchMaxStepDescente, // 🔧 REX 2026-07-08 : commun M1/M2
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M1BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal,
    RampAccelRate           := GVL_PERSISTENT.WinchM1RampAccelRate_Pct,
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct,
    RampDecelFastRate       := GVL_PERSISTENT.WinchM1RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM1.HomingSuspect, // 🆕 Câblage de l'incertitude M1
    CablePosM               := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM1_M,
    BottomLimitM            := BottomLimitM1_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
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
    MaxStepDescente         := GVL_PERSISTENT.WinchMaxStepDescente, // 🔧 REX 2026-07-08 : commun M1/M2
    HomingApproachActive    := PRG_04_Modes.instModes.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M2BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal,
    RampAccelRate           := GVL_PERSISTENT.WinchM2RampAccelRate_Pct,
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct,
    RampDecelFastRate       := GVL_PERSISTENT.WinchM2RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM2.HomingSuspect, // 🆕 Câblage de l'incertitude M2
    CablePosM               := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM2_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
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
