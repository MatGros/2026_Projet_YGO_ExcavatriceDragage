(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_TREUILS_CFC — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 6.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   📄 Docs : DOC/AF_Partie-10_Fonction_Winch_v2.0.md ; DOC/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_TREUILS_CFC
VAR_OUTPUT
    // 🛡️ Demandes brutes explicites : consommées par PRG_10_Outputs_LD.
    // PRG_06 ne produit jamais les Q ni les commandes finales autorisées.
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    KoboldContactorCmdArbitrated : BOOL; // Commande Kobold arbitrée, consommée par PRG_10
END_VAR
VAR
    // Stubs
    StubMachineEnableN1 : BOOL := TRUE;

    // Instances
    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;
    instDiveSearch : FB_DiveSearch;
    instExtractionSequence : FB_ExtractionSequence;

    // 🪨 Intention commune maintenance, construite UNE fois avant les assistants.
    // Les assistants ne lisent jamais directement joystick/IHM et ne créent aucune source parallèle.
    MaintenanceMotionRequestActive : BOOL;
    MaintenanceMotionDirection     : INT;
    MaintenanceMotionSpeed_Pct     : REAL;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;

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

// === IMPLEMENTATION (corps du PROGRAM PRG_TREUILS_CFC) ===

// ── 0. INTENTION MAINTENANCE + ASSISTANTS PRÉLÈVEMENT ──────────────────
// 🎯 Source unique : joystick OU boutons IHM. En mode boutons, seule la commande
// commune Both est compatible avec une assistance qui exige les deux treuils synchronisés.
IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    MaintenanceMotionDirection := PRG_01_Diagnostics.instJoystick.AxisCmdY.Direction;
    MaintenanceMotionRequestActive := PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop
                                     AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                     AND (PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 3);
    MaintenanceMotionSpeed_Pct := ABS(PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef);
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        MaintenanceMotionDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        MaintenanceMotionDirection := -1;
    ELSE
        MaintenanceMotionDirection := 0;
    END_IF;
    MaintenanceMotionRequestActive := (MaintenanceMotionDirection <> 0)
                                     AND PRG_01_Diagnostics.instJoystick.DeadmanArmed;
    MaintenanceMotionSpeed_Pct := 100.0;
END_IF;

// 🪨 L'attestation manuelle est une preuve temporaire, distincte du Kobold.
// Elle est consommée à l'entrée extraction et annulée dès qu'un mouvement la rend caduque.
IF NOT (PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N1 OR PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_01_Inputs_LD.PowerContactorEngaged
   OR PRG_SUPERVISION_CFC.FaultMachineReset_IHM
   OR (MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1))
   OR _BucketState.IsOpen THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

instDiveSearch(
    Enable := (PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N1 OR PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode := PRG_MODES_CFC.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BucketIsOpen := _BucketState.IsOpen,
    KoboldImmersed := PRG_01_Inputs_LD.KoboldContactFond,
    M1Position_M := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2Position_M := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    PositionsValid := PRG_02_Encoders.instHomingM1.Homed AND PRG_02_Encoders.instHomingM2.Homed
                      AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M
);

// Deux preuves HOMOGÈNES et nommées de la même précondition extraction : Kobold ou attestation opérateur.
BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed;
instExtractionSequence(
    Enable := (PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N1 OR PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode := PRG_MODES_CFC.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := _BucketState.IsClosed,
    BucketBusy := instBucket.Busy,
    BucketError := instBucket.Error,
    WinchSyncError := instWinchSync.Error,
    M1Position_M := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2Position_M := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    M1MeasuredSpeedValid := PRG_02_Encoders.M1SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Encoders.M2SpeedValid,
    PositionsValid := PRG_02_Encoders.instHomingM1.Homed AND PRG_02_Encoders.instHomingM2.Homed
                      AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);
IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

// Un seul arbitre de fermeture : SEMI_AUTO > assistant extraction > demande IHM manuelle.
IF PRG_MODES_CFC.Auth.Mode = E_Mode.SEMI_AUTO THEN
    CmdBucketCloseArbitrated := PRG_05_Cycle.instCycle.BucketCmd.Close;
ELSIF instExtractionSequence.BucketCloseRequest THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
END_IF;

// Un seul producteur logique de commande Kobold : cycle auto OU assistant maintenance.
IF PRG_MODES_CFC.Auth.Mode = E_Mode.SEMI_AUTO THEN
    KoboldContactorCmdArbitrated := PRG_05_Cycle.instCycle.BucketCmd.KoboldContactorCmd;
ELSE
    KoboldContactorCmdArbitrated := instDiveSearch.KoboldMeasureEnable;
END_IF;

// ── 1. COMMANDE DU BENNE (Séquence lente) ─────────────────────────────
// 🔧 REX 2026-07-08 : appelé EN PREMIER (avant l'arbitrage M1/M2 ci-dessous) — audit sécurité :
// l'ancien ordre (Benne appelé après l'arbitrage) faisait que M1_StartStop_Active lisait
// instBucket.Busy du scan PRÉCÉDENT, créant une fenêtre d'1 scan où M1 pouvait recevoir une
// commande manuelle au moment exact où le benne démarre. instBucket.M1_Busy/M2_Busy (ci-dessous)
// lisent en retour instWinchM1/M2.Busy du scan précédent (ces FB sont appelés plus loin, §6/§7) —
// acceptable : ça ne retarde que l'ACCEPTATION d'une nouvelle demande de ~1 scan (10ms), sans
// aucun impact sécurité (contrairement au cas inverse, qui pouvait faire bouger M1 pendant Busy).
instBucket(
    Enable              := NOT PRG_MODES_CFC.Auth.InhibitM2
                           AND PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable
                           AND PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable, // 🆕 Sécurisé : nécessite les deux codeurs valides et M2 non-inhibé
    Reset               := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged     := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode                := PRG_MODES_CFC.Auth.Mode,
    CmdOpen_IHM         := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen OR PRG_05_Cycle.instCycle.BucketCmd.Open,
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection     := MaintenanceMotionDirection,
    CablePosM1          := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2          := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1             := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2             := PRG_02_Encoders.instHomingM2.Homed,
    M1_Busy             := instWinchM1.Busy,   // 🆕 REX 2026-07-08
    M2_Busy             := instWinchM2.Busy,   // 🆕 REX 2026-07-08
    ConfirmOpenPosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos, // 🆕 REX 2026-07-08 — bouton IHM référencement benne ouvert
    ConfirmClosePosition:= GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos, // 🆕 REX 2026-07-08 — bouton IHM référencement benne fermé
    Config              := _BucketCfgPersist.Config,
    CfgTimeoutDuration     := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_MODES_CFC.Auth.InhibitM1, // 🆕 REX 2026-07-08
    InhibitM2           := PRG_MODES_CFC.Auth.InhibitM2,  // 🆕 REX 2026-07-08
    BypassGlobal        := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global      // 🌐 Bypass benne (RETAIN)
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
EffectiveMaxStepAscent   := _CommunCfgPersist.WinchMaxStepAscent;
EffectiveMaxStepDescente := _CommunCfgPersist.WinchMaxStepDescente;

// ── 2. ARBITRAGE DES CONSIGNES M1 (Joystick vs Cycle Automatique) ────────
IF PRG_MODES_CFC.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche (bug trouvé en
    // review code), le cycle auto pouvait aggraver un écart mineur sans aucune protection quand
    // SyncSoftStopEnable=TRUE. Ajouté ici, symétrique à la branche manuelle ci-dessous.
    M1_Direction_Active := PRG_05_Cycle.instCycle.WinchM1Cmd.Direction;
    // 🛡️ SEMI_AUTO reste conditionné par l'homme-mort : relâchement = arrêt,
    // nouvelle sollicitation valide = reprise à l'étape courante.
    M1_StartStop_Active := PRG_05_Cycle.instCycle.WinchM1Cmd.StartStop
                            AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                            AND PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
    M1_SpeedRef_Active  := MIN(PRG_05_Cycle.instCycle.WinchM1Cmd.SpeedPct,
                               ABS(PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef));
ELSE
    // 🔧 REX 2026-07-19 : suppression IHM_MANU — MAINT_N1/MAINT_N2. 🆕 REX (session WINCH-BTN-01,
    // réouverture documentée T40) : le joystick n'est plus la SEULE source —
    // GVL_IHM.Modes.Cmd.TglJoystickMaster bascule vers les boutons IHM maintenus (BtnUp/BtnDown),
    // homme-mort joystick réel TOUJOURS exigé en parallèle (même leçon que le précédent bug
    // Translation M3, AF_Partie-11 §6bis (ex-AF_Partie-11 v1.9) — jamais implicite). Voir
    // ARCHIVES/Doc/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md.
    // 🆕 Sélection treuil (TASK-0001, MAINT_N2 uniquement, voir FB_Modes.JoystickWinchSelectArbitrated) :
    // 1=M1 seul, 2=M2 seul, 3=Couplé — forcé à 3 (Couplé) hors MAINT_N2, IDENTIQUE quelle que
    // soit la source (joystick ou boutons) — pas de duplication de la logique de sélection.
    // 🔧 REX 2026-07-08 : + AND DeadmanArmed — NOT Busy seul insuffisant (rampe joystick met du
    // temps à redescendre à 0 après désarmement homme-mort ⇒ StartStop reste TRUE le temps de la
    // décél, M1 bougeait/frein décollait à la fin d'un cycle benne). DeadmanArmed reste FALSE
    // en continu jusqu'au repassage neutre + réappui, sans dépendre du temps de rampe.
    // 🔧 REX 2026-07-08 (5) : Direction assignée AVANT StartStop (nécessaire pour le gate directionnel ci-dessous).
    IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        // Source = joystick (comportement historique, inchangé)
        M1_Direction_Active := PRG_01_Diagnostics.instJoystick.AxisCmdY.Direction;
        M1_StartStop_Active := PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop AND NOT instBucket.Busy
                                AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                AND (PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 1
                                     OR PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 3)
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1))); // 🔧 REX 2026-07-08 (5)
        M1_SpeedRef_Active  := PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef;
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
                                AND (PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                     OR GVL_IHM.M1TreuilRetenue.Bypass.Global)
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
        M1_SpeedRef_Active  := 100.0;
    END_IF;
END_IF;

// ── 3. ARBITRAGE DES CONSIGNES M2 (Benne vs Cycle Automatique vs Joystick) ──
IF instBucket.Busy THEN
    M2_StartStop_Active := instBucket.M2_StartStop;
    M2_Direction_Active := instBucket.M2_Direction;
    M2_SpeedRef_Active  := 15.0; // Vitesse lente forcée pour fermeture benne
ELSE
    IF PRG_MODES_CFC.Auth.Mode = E_Mode.SEMI_AUTO THEN
        // 🔧 REX 2026-07-08 (7) — review : gate directionnel absent de cette branche, ajouté
        // symétrique à la branche manuelle ci-dessous (signe M2, voir note ci-dessous).
        M2_Direction_Active := PRG_05_Cycle.instCycle.WinchM2Cmd.Direction;
        // 🛡️ Même garde homme-mort que M1 : le cycle ne poursuit jamais un mouvement
        // après relâchement du joystick.
        M2_StartStop_Active := PRG_05_Cycle.instCycle.WinchM2Cmd.StartStop
                                AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                AND PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
        M2_SpeedRef_Active  := MIN(PRG_05_Cycle.instCycle.WinchM2Cmd.SpeedPct,
                                   ABS(PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef));
    ELSE
        // 🔧 REX 2026-07-19 : suppression IHM_MANU — MAINT_N1/MAINT_N2. 🆕 REX (session WINCH-BTN-01) :
        // idem M1 (voir bandeau branche M1 ci-dessus) — GVL_IHM.Modes.Cmd.TglJoystickMaster bascule la
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
        IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
            M2_Direction_Active := PRG_01_Diagnostics.instJoystick.AxisCmdY.Direction;
            M2_StartStop_Active := PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop
                                    AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                    AND (PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 2
                                         OR PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 3)
                                    AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                         OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1))); // 🔧 REX 2026-07-08 (7)
            M2_SpeedRef_Active := PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef;
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
                                    AND (PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                         OR GVL_IHM.M2TreuilBenne.Bypass.Global)
                                    AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                         OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
            M2_SpeedRef_Active := 100.0;
        END_IF;
    END_IF;
END_IF;

// ── 3bis. ASSISTANCE MAINTENANCE : priorité après arbitre manuel, avant les treuils ─
// DiveSearch garde la main sur toute sa phase active : une pause homme-mort arrête
// normalement les deux treuils sans laisser le manuel contourner la séquence Kobold.
IF (PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N1 OR PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2) THEN
    IF instDiveSearch.Busy THEN
        M1_Direction_Active := -1;
        M2_Direction_Active := -1;
        M1_StartStop_Active := instDiveSearch.DescendPermit
                               AND NOT SyncMinorDeviationBlocksDown;
        M2_StartStop_Active := instDiveSearch.DescendPermit
                               AND NOT SyncMinorDeviationBlocksDown;
        M1_SpeedRef_Active := MaintenanceMotionSpeed_Pct;
        M2_SpeedRef_Active := MaintenanceMotionSpeed_Pct;
    ELSIF instExtractionSequence.Busy AND NOT instBucket.Busy THEN
        M1_Direction_Active := 1;
        M2_Direction_Active := 1;
        M1_StartStop_Active := instExtractionSequence.AscentPermit
                               AND NOT SyncMinorDeviationBlocksUp;
        M2_StartStop_Active := instExtractionSequence.AscentPermit
                               AND NOT SyncMinorDeviationBlocksUp;
        M1_SpeedRef_Active := MaintenanceMotionSpeed_Pct;
        M2_SpeedRef_Active := MaintenanceMotionSpeed_Pct;
    END_IF;
END_IF;

// ── 3ter. COUPURE IMMÉDIATE M1/M2 AU SCAN EXACT DE FIN DE CYCLE BENNE ─────
// 🆕 REX 2026-07-08 : instBucket est appelé en premier (§0), donc son Busy est frais dans CE scan
// (voir §1/§2 ci-dessus) — mais AxisCmdY.StartStop/Direction viennent de instJoystick (PRG_01),
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
    Enable          := PRG_MODES_CFC.Auth.SyncEnable AND NOT instBucket.Busy
                        AND NOT PRG_MODES_CFC.Auth.InhibitM1 AND NOT PRG_MODES_CFC.Auth.InhibitM2
                        AND NOT (ForbidAscentM1_Active OR ForbidAscentM2_Active
                                 OR ForbidDescentM1_Active OR ForbidDescentM2_Active), // 🆕 REX 2026-07-08 (7)
    Reset           := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode            := PRG_MODES_CFC.Auth.Mode,
    CablePosM1      := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2      := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1         := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2         := PRG_02_Encoders.instHomingM2.Homed,
    SyncEnable      := PRG_MODES_CFC.Auth.SyncEnable,
    CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
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
    BypassGlobal    := GVL_IHM.M1M2Sync.Bypass.Global
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
BottomLimitM1_Active := _WinchM1CfgPersist.CfgCableLimitDescent_M;
IF _CommunCfgPersist.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(BottomLimitM1_Active, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
END_IF;

BottomLimitM2_Active := _WinchM2CfgPersist.CfgCableLimitDescent_M;
IF _CommunCfgPersist.LimitLegalEnabled THEN
    BottomLimitM2_Active := MAX(BottomLimitM2_Active, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
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
SafeStopM1_Raw      := PRG_SAFETY_CFC.instSafetyWinchM1.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT _SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000))
                       OR instBucket.M1SlipDetected;
SafeStopM2_Raw      := PRG_SAFETY_CFC.instSafetyWinchM2.SafeStop
                       OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR (NOT _SyncSoftStopEnable AND ((instWinchSync.ErrorId AND 16#0001) <> 16#0000));

ForbidDescentM1_Raw := (NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND PRG_SAFETY_CFC.instSafetyWinchM1.ForbidDescent)
                       OR (_CommunCfgPersist.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
ForbidDescentM2_Raw := (NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND PRG_SAFETY_CFC.instSafetyWinchM2.ForbidDescent)
                       OR (_CommunCfgPersist.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));

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
// PRG_SUPERVISION_CFC), symétrique à CableLimitDescentReached. Réutilisé ci-dessous dans ForbidAscentM1_Raw.
CableLimitAscentM1Reached := PRG_02_Encoders.instHomingM1.Homed
                             AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                             AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _WinchM1CfgPersist.CfgCableLimitAscent_M)
                             AND NOT PRG_MODES_CFC.Auth.HomingApproachEnable;

ForbidAscentM1_Raw  := NOT GVL_IHM.M1TreuilRetenue.Bypass.Global AND (
                          PRG_SAFETY_CFC.instSafetyWinchM1.ForbidAscent
                          OR (PRG_02_Encoders.instHomingM1.Homed
                              AND NOT PRG_02_Encoders.instHomingM1.HomingSuspect
                              AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= _WinchM1CfgPersist.CfgTopSensorPos_M))
                          OR CableLimitAscentM1Reached
                       );
// 🐛 REX 2026-07-08 (7) — BUG CORRIGÉ (retour terrain) / REX 2026-07-08 (2) :
// La butée haute de M2 n'est décalée de l'OffsetCloseM QUE si le benne est fermé (IsClosed)
// ou en cours de fermeture (CloseReq). Sinon (benne ouvert/en cours d'ouverture), M2 doit
// s'arrêter à la butée normale (CableLimitAscentM2_M) pour s'arrêter proprement en même temps que M1.
M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketCfgPersist.Config.OffsetCloseM);

// 🆕 REX 2026-07-15 (8) : idem M1 (voir ci-dessus).
CableLimitAscentM2Reached := PRG_02_Encoders.instHomingM2.Homed
                             AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                             AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift))
                             AND NOT PRG_MODES_CFC.Auth.HomingApproachEnable;

ForbidAscentM2_Raw  := NOT GVL_IHM.M2TreuilBenne.Bypass.Global AND (
                          PRG_SAFETY_CFC.instSafetyWinchM2.ForbidAscent
                          OR (PRG_02_Encoders.instHomingM2.Homed
                              AND NOT PRG_02_Encoders.instHomingM2.HomingSuspect
                              AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= (_WinchM2CfgPersist.CfgTopSensorPos_M + M2_LimitShift)))
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
                               AND (PRG_MODES_CFC.Auth.Mode <> E_Mode.DISABLE)
                               AND NOT PRG_MODES_CFC.Auth.InhibitM1, // 🔧 WINCH-CORE-01 : DISABLE neutralise réellement M1
    Reset                   := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged         := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode                    := PRG_MODES_CFC.Auth.Mode,
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
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := PRG_SAFETY_CFC.instLoadEstimatorM1.SpeedBand,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := PRG_SAFETY_CFC.instSpeedMonitorM1.SpeedStable
                               AND NOT PRG_SAFETY_CFC.instSpeedMonitorM1.SpeedVariationConfirmed
                               AND NOT instWinchSync.Error,
    HomingApproachActive    := PRG_MODES_CFC.Auth.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_01_Inputs_LD.M1BrakeFeedback,
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    CfgRampAccelRate           := _WinchM1CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate     := _WinchM1CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate       := _WinchM1CfgPersist.CfgRampDecelFastRate,
    Homed                   := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM1.HomingSuspect, // 🆕 Câblage de l'incertitude M1
    CablePosM               := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    // 🔧 REX 2026-07-15 (6) : CableLimitAscentM1_M (limite ABSOLUE d'exploitation normale, ex-
    // HomingTargetM1_M) — la rampe/ralentissement de FB_Winch cible désormais la même limite que
    // ForbidAscentM1_Raw ci-dessus, pas le capteur physique (réservé au Homing).
    TopLimitM               := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM       := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowSpeedPct            := _CommunCfgPersist.WinchSlowSpeed_Pct,
    // 🌐 Bypass Global M1 (GVL_IHM.M1TreuilRetenue.Bypass.Global)
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

// ── 7. EXÉCUTION DU PILOTAGE DU TREUIL M2 ───────────────────────────────
instWinchM2(
    Enable                  := StubMachineEnableN1
                               AND (PRG_MODES_CFC.Auth.Mode <> E_Mode.DISABLE)
                               AND NOT PRG_MODES_CFC.Auth.InhibitM2, // 🔧 WINCH-CORE-01 : DISABLE neutralise réellement M2
    Reset                   := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    PowerContactorEngaged         := PRG_01_Inputs_LD.PowerContactorEngaged,
    Mode                    := PRG_MODES_CFC.Auth.Mode,
    StartStop               := M2_StartStop_Active,
    SafeStop                := SafeStopM2_Active,
    ForbidDescent           := ForbidDescentM2_Active,
    ForbidAscent            := ForbidAscentM2_Active,
    Direction               := M2_Direction_Active,
    SpeedRefPct             := M2_SpeedRef_Active,
    SpeedStepTable          := M2_SpeedStepTableActive,
    // 🔧 REX 2026-07-15 (9) : idem M1 (voir §6 ci-dessus).
    CfgMaxStepDescente         := EffectiveMaxStepDescente,
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := PRG_SAFETY_CFC.instLoadEstimatorM2.SpeedBand,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := PRG_SAFETY_CFC.instSpeedMonitorM2.SpeedStable
                               AND NOT PRG_SAFETY_CFC.instSpeedMonitorM2.SpeedVariationConfirmed
                               AND NOT instWinchSync.Error,
    HomingApproachActive    := PRG_MODES_CFC.Auth.HomingApproachEnable, // 🆕 REX 2026-07-08 : vitesse lente en approche
    FwdRevSpeedFeedbackOff  := PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_01_Inputs_LD.M2BrakeFeedback,
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global,
    CfgRampAccelRate           := _WinchM2CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate     := _WinchM2CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate       := _WinchM2CfgPersist.CfgRampDecelFastRate,
    Homed                   := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect           := PRG_02_Encoders.instHomingM2.HomingSuspect, // 🆕 Câblage de l'incertitude M2
    CablePosM               := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    // 🔧 REX 2026-07-15 (6) : idem M1 (voir ci-dessus), + M2_LimitShift (décalage benne fermé).
    TopLimitM               := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM       := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowSpeedPct            := _CommunCfgPersist.WinchSlowSpeed_Pct,
    // 🌐 Bypass Global M2 (GVL_IHM.M2TreuilBenne.Bypass.Global)
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
);

// ── 8. PUBLICATION DES DEMANDES BRUTES VERS PRG_10_Outputs_LD ───────────
// 🛡️ Ordre MainTask requis : PRG_06 est exécuté avant PRG_10. Les structures
// VAR_OUTPUT sont la frontière explicite producteur/consommateur ; aucune Q et
// aucune commande autorisée ne sont produites dans ce programme.
WinchM1FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM1FinalInterlockRequest.Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
WinchM1FinalInterlockRequest.BrakeReleaseRequest := instWinchM1.BrakeCmd;
WinchM1FinalInterlockRequest.BrakeCommandOpenConfirmed := PRG_01_Inputs_LD.M1BrakeCommandOpenConfirmed;
WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff;
WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd;
WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev;
WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;

WinchM2FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM2FinalInterlockRequest.Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM;
WinchM2FinalInterlockRequest.PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged;
WinchM2FinalInterlockRequest.SafeStop := SafeStopM2_Active;
WinchM2FinalInterlockRequest.BrakeReleaseRequest := instWinchM2.BrakeCmd;
WinchM2FinalInterlockRequest.BrakeCommandOpenConfirmed := PRG_01_Inputs_LD.M2BrakeCommandOpenConfirmed;
WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff;
WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;
WinchM2FinalInterlockRequest.RequestedRelayRev := instWinchM2.RelayRev;
WinchM2FinalInterlockRequest.RequestedContactor1 := instWinchM2.Contactor1;
WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;
