(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_03_Modes_Cycle — Gestion, Modes Machine et Séquenceur de Cycle
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après PRG_02_Acquisition).
   📄 Docs : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
            DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   🎯 Rôle unique : Instancier FB_Modes, distribuer le bus ST_fbModes_Autorisations,
      et instancier les 2 séquenceurs de cycle (maintenance + semi-auto).
   ⚠️ Retard d'un scan : FB_Cycle (rang 03) lit les feedbacks de PRG_04/05
      (rangs 04/05) du scan PRÉCÉDENT — documenté, cohérent avec la pratique
      existante (PRG_04 « lag 1 scan »). Les demandes produites sont consommées
      par PRG_04/05 dans le MÊME scan (producteur avant consommateur).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Modes_Cycle

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA GVL_IHM & PRG_02) ===
END_VAR

VAR_OUTPUT
    // === 🎚️ BUS D'AUTORISATIONS & DEMANDES DE CYCLE ===
    Data              : ST_ModesCycleInterPrg;  // <-- [BUS] Structure publique unique du programme de modes et cycle
END_VAR

VAR
    // === 🧩 SOUS-INSTANCES FB INTERNES ===
    instModes         : FB_Modes; // * [INST] Arbitrage des modes machine et calcul autorisations
    instCycleSemiAuto : FB_Cycle; // * [INST] Séquenceur de cycle semi-automatique (privé)
END_VAR

// === 🔀 §1 ARBITRAGE DES MODES MACHINE ===

instModes(
    Enable                  := TRUE,
    Reset                   := GVL_IHM.Modes.Cmd.BtnModeReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    SelMode                 := GVL_IHM.Modes.Cmd.SelMode,
    SelSyncEnable           := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable,
    InhibitM1Request        := GVL_IHM.M1TreuilRetenue.Cmd.BtnInhibit,
    InhibitM2Request        := GVL_IHM.M2TreuilBenne.Cmd.BtnInhibit,
    SelHomingApproachEnable := GVL_IHM.Commun.Cfg.SelHomingApproachEnable,
    EncoderFaultPresent     := (PRG_02_Acquisition.HwIn.Winch.COD1_DeviceState <> DEVICE_STATE.RUNNING) OR (PRG_02_Acquisition.HwIn.Winch.COD2_DeviceState <> DEVICE_STATE.RUNNING),
    JoystickWinchSelectRequest := GVL_IHM.Modes.Cmd.SelJoystickWinch,
    SelMaintenanceZoneAccess := GVL_IHM.TranslationM3.Cmd.TglMaintenanceZoneAccess
);


// === 🔄 §2 SÉQUENCEUR DE CYCLE SEMI-AUTOMATIQUE ===
// 🕹️ CycleMotionPermit = manche défléchi (non centré) — D2
// ⚠️ Entrées sans source définie câblées en fail-safe documenté :
//    - SpeedMismatchThresholdMps := 0 / SpeedMismatchTimeout := T#0ms (contrôle désactivé)
//    - Benne_IsRoughlyClosed := Benne_IsClosed (fallback sûr : exige fermé)
//    - HomingRequest := bouton homing IHM (BtnHome M1 OU M2)

instCycleSemiAuto(
    Enable                  := (instModes.Auth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := GVL_IHM.Cycle.Cmd.BtnReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := instModes.Auth.Mode,
    CycleMotionPermit       := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    DeadmanArmed            := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    StartCycle              := GVL_IHM.Cycle.Cmd.BtnStart,
    AbortCycle              := GVL_IHM.Cycle.Cmd.BtnAbort,
    SelTarget               := GVL_IHM.TranslationM3.Cmd.SelTarget,
    SetDepthM               := GVL_IHM.Cycle.Cfg.SetDepth_M,
    SetOffsetM              := GVL_IHM.Cycle.Cfg.SetOffset_M,
    KoboldContactFond       := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    LimitLegalReached       := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM        := _CommunCfgPersist.LimitLegalDepthMinAllowed_M,
    WinchSyncError          := PRG_04_Treuils_Benne.instWinchSync.Fault.Error,
    WinchSyncDeltaM         := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM,
    M1_CablePosM            := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2_CablePosM            := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    M1_MeasuredSpeedMps     := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps,
    M2_MeasuredSpeedMps     := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps,
    SpeedMismatchThresholdMps := 1.5,   // Seuil écart vitesse M1/M2 (revue : ~1-2 m/s, retenu 1.5)
    SpeedMismatchTimeout    := T#500ms, // Tempo confirmation écart vitesse (revue)
    CableLimitM1AscentM     := _CommunCfgPersist.CfgCableLimitAscent_M,
    Translation_At_P1       := PRG_05_Translation.M3_AtP1Stable,
    Translation_At_Tremie   := PRG_05_Translation.M3_AtTremieStable,
    Translation_At_Maintenance := PRG_05_Translation.M3_AtMaintenanceStable,
    Translation_Busy        := (ABS(PRG_05_Translation.instTranslationM3.RequestedDriveFreqHz) > 0.1),
    Translation_Done        := PRG_05_Translation.instTranslationM3.TargetReached,
    Benne_Busy              := PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy,
    Benne_Done              := PRG_04_Treuils_Benne.instBucket.Lifecycle.Done,
    Benne_IsOpen            := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    Benne_IsClosed          := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    Benne_IsRoughlyClosed   := PRG_04_Treuils_Benne.Data.Benne_IsRoughlyClosed,  // Tolérance matière 2m
    HomedM1                 := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2                 := PRG_02_Acquisition.Data.EncoderM2.Homed,
    TopPositionSensor       := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    HomingRequest           := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHome,
    SampleCount            := _CycleSampleCount
);


// === 📤 §3 PUBLICATION DU BUS INTER-PRG & AUTORISATIONS ===

// 1. Autorisations machine
Data.Auth := instModes.Auth;

// 2. Demandes programme et état public de séquence
IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Demandes treuils M1 / M2
    Data.ReqProgram.ReqWinchM1.ReqStartStop := instCycleSemiAuto.WinchM1Cmd.StartStop;
    Data.ReqProgram.ReqWinchM1.ReqDirection := instCycleSemiAuto.WinchM1Cmd.Direction;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := instCycleSemiAuto.WinchM1Cmd.SpeedPct;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := instCycleSemiAuto.WinchM2Cmd.StartStop;
    Data.ReqProgram.ReqWinchM2.ReqDirection := instCycleSemiAuto.WinchM2Cmd.Direction;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := instCycleSemiAuto.WinchM2Cmd.SpeedPct;

    // Demande translation M3
    Data.ReqProgram.ReqTranslation.ReqStart    := instCycleSemiAuto.TranslationCmd.Start;
    Data.ReqProgram.ReqTranslation.PositionTgt := instCycleSemiAuto.TranslationCmd.Target;

    // Demande benne
    Data.ReqProgram.ReqBucket.ReqOpen                := instCycleSemiAuto.BucketCmd.Open;
    Data.ReqProgram.ReqBucket.ReqClose               := instCycleSemiAuto.BucketCmd.Close;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable := instCycleSemiAuto.BucketCmd.KoboldContactorCmd;

    // État séquence active
    IF instCycleSemiAuto.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId := E_ProgramSequence.MAIN_CYCLE;
    ELSE
        Data.SequenceState.SequenceId := E_ProgramSequence.NONE;
    END_IF;

    Data.SequenceState.Ready                  := instCycleSemiAuto.Ready;
    Data.SequenceState.Lifecycle              := instCycleSemiAuto.Lifecycle;
    Data.SequenceState.Fault                  := instCycleSemiAuto.Fault;
    Data.SequenceState.Step                   := instCycleSemiAuto.CycleStep;
    Data.SequenceState.StepStr                := instCycleSemiAuto.CycleStateStr;
    Data.SequenceState.StepAtFault            := instCycleSemiAuto.CycleStepAtError;
    Data.SequenceState.OperatorActionId       := instCycleSemiAuto.OperatorActionId;
    Data.SequenceState.OperatorAction         := instCycleSemiAuto.OperatorAction;
    Data.SequenceState.ExpectedAxis           := instCycleSemiAuto.ExpectedAxis;
    Data.SequenceState.ExpectedDirection      := instCycleSemiAuto.ExpectedDirection;
    Data.SequenceState.WaitingForOperator     := instCycleSemiAuto.WaitingForOperator;
    Data.SequenceState.WaitingForProcess      := instCycleSemiAuto.WaitingForProcess;
    Data.SequenceState.RequestActive          := instCycleSemiAuto.RequestActive;
    Data.SequenceState.SpeedMismatchMps       := instCycleSemiAuto.SpeedMismatchMps;
    Data.SequenceState.SpeedMismatchActive    := instCycleSemiAuto.SpeedMismatchActive;
    Data.SequenceState.SpeedMismatchConfirmed := instCycleSemiAuto.SpeedMismatchConfirmed;
ELSE
    // Neutralisation déterministe hors mode SEMI_AUTO
    Data.ReqProgram.ReqWinchM1.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqTranslation.ReqStart    := FALSE;
    Data.ReqProgram.ReqTranslation.PositionTgt := 0;

    Data.ReqProgram.ReqBucket.ReqOpen                := FALSE;
    Data.ReqProgram.ReqBucket.ReqClose               := FALSE;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable := FALSE;

    Data.SequenceState.SequenceId              := E_ProgramSequence.NONE;
    Data.SequenceState.Ready                   := FALSE;
    Data.SequenceState.Lifecycle.Busy          := FALSE;
    Data.SequenceState.Lifecycle.Done          := FALSE;
    Data.SequenceState.Lifecycle.Waiting       := FALSE;
    Data.SequenceState.Fault.Error             := FALSE;
    Data.SequenceState.Fault.ErrorId           := 0;
    Data.SequenceState.Fault.Latched           := FALSE;
    Data.SequenceState.Step                    := E_CycleStep.STEP_00_INIT;
    Data.SequenceState.StepStr                 := 'INIT';
    Data.SequenceState.StepAtFault             := E_CycleStep.STEP_00_INIT;
    Data.SequenceState.OperatorActionId        := 0;
    Data.SequenceState.OperatorAction          := '';
    Data.SequenceState.ExpectedAxis            := E_OperatorAxis.NONE;
    Data.SequenceState.ExpectedDirection       := 0;
    Data.SequenceState.WaitingForOperator      := FALSE;
    Data.SequenceState.WaitingForProcess       := FALSE;
    Data.SequenceState.RequestActive           := FALSE;
    Data.SequenceState.SpeedMismatchMps        := 0.0;
    Data.SequenceState.SpeedMismatchActive     := FALSE;
    Data.SequenceState.SpeedMismatchConfirmed  := FALSE;
END_IF;

END_PROGRAM
