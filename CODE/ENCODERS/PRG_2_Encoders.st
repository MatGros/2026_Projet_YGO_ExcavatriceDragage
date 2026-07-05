(* ═══════════════════════════════════════════════════════════════
   🧲 PRG_2_Encoders — Acquisition, Recalage (Homing) et Sécurité Codeurs
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 2.
   ✅ Expose ses défauts en VAR_OUTPUT (1 cycle de retard assumé pour instModes).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_2_Encoders
VAR_OUTPUT
    EncoderFaultPresent   : BOOL;   // OR des deux - lu par PRG_4_Modes au cycle suivant
    EncoderFaultPresentM1 : BOOL;
    EncoderFaultPresentM2 : BOOL;
END_VAR
VAR
    // Simulation banc de test
    SimulatedM1Raw        : UDINT := 1000000;
    SimulatedM2Raw        : UDINT := 1000000;
    M1_RawPosToUse        : UDINT;
    M2_RawPosToUse        : UDINT;

    // Instances
    instEncoderAbsM1   : FB_Encoder_Abs;
    instEncoderScaleM1 : FB_Encoder_Scale;
    instHomingM1       : FB_Encoder_Homing;
    instEncoderAbsM2   : FB_Encoder_Abs;
    instEncoderScaleM2 : FB_Encoder_Scale;
    instHomingM2       : FB_Encoder_Homing;
    instEncoderSafetyM1 : FB_Encoder_Safety;
    instEncoderSafetyM2 : FB_Encoder_Safety;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_2_Encoders) ===

// 1. SIMULATION SUR BANC DE TEST (si DBG_ContactorFeedbackBypass_TEST = TRUE)
IF GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN
    // Treuil M1
    IF COD1_PresettTrigCmd = 2 THEN
        SimulatedM1Raw := COD1_PresetValue;
    ELSIF PRG_10_Outputs.M1RelayFwd THEN
        SimulatedM1Raw := SimulatedM1Raw + REAL_TO_UDINT(PRG_6_WinchControl.instWinchM1.SpeedRamp.Current * 0.1);
    ELSIF PRG_10_Outputs.M1RelayRev THEN
        IF SimulatedM1Raw >= REAL_TO_UDINT(PRG_6_WinchControl.instWinchM1.SpeedRamp.Current * 0.1) THEN
            SimulatedM1Raw := SimulatedM1Raw - REAL_TO_UDINT(PRG_6_WinchControl.instWinchM1.SpeedRamp.Current * 0.1);
        ELSE
            SimulatedM1Raw := 0;
        END_IF;
    END_IF;

    // Treuil M2
    IF COD2_PresettTrigCmd = 2 THEN
        SimulatedM2Raw := COD2_PresetValue;
    ELSIF PRG_10_Outputs.M2RelayFwd THEN
        SimulatedM2Raw := SimulatedM2Raw + REAL_TO_UDINT(PRG_6_WinchControl.instWinchM2.SpeedRamp.Current * 0.1);
    ELSIF PRG_10_Outputs.M2RelayRev THEN
        IF SimulatedM2Raw >= REAL_TO_UDINT(PRG_6_WinchControl.instWinchM2.SpeedRamp.Current * 0.1) THEN
            SimulatedM2Raw := SimulatedM2Raw - REAL_TO_UDINT(PRG_6_WinchControl.instWinchM2.SpeedRamp.Current * 0.1);
        ELSE
            SimulatedM2Raw := 0;
        END_IF;
    END_IF;

    // Aiguillage
    IF NOT PRG_1_Diagnostics.instDiagEthercat.EncoderM1.Operational THEN
        M1_RawPosToUse := SimulatedM1Raw;
    ELSE
        M1_RawPosToUse := COD1_PosValue;
    END_IF;

    IF NOT PRG_1_Diagnostics.instDiagEthercat.EncoderM2.Operational THEN
        M2_RawPosToUse := SimulatedM2Raw;
    ELSE
        M2_RawPosToUse := COD2_PosValue;
    END_IF;
ELSE
    M1_RawPosToUse := COD1_PosValue;
    M2_RawPosToUse := COD2_PosValue;
END_IF;

// 2. TREUIL M1 (Abs → Scale → Homing)
instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := (GVL_Encoder_Stub.M1_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    Mode                := PRG_4_Modes.instModes.Mode,
    RawPosIn            := M1_RawPosToUse,
    AlarmsIn            := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD1_Alarms, 0),
    WarningsIn          := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD1_Warnings, 0),
    SlaveOperational    := PRG_1_Diagnostics.instDiagEthercat.EncoderM1.Operational OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    PresetRequest       := instHomingM1.PresetRequest,
    PresetValue         := instHomingM1.PresetValue
);
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

instHomingM1(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM1,
    Reset                := (GVL_Encoder_Stub.M1_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk      := PRG_0_Inputs.EmergencyStopOk,
    Mode                 := PRG_4_Modes.instModes.Mode,
    Home                 := (GVL_Encoder_Stub.StubHomeButton_IHM AND ((GVL_Encoder_Stub.HomingMode_IHM = 1) OR (GVL_Encoder_Stub.HomingMode_IHM = 3))),
    ConfirmCoherence     := GVL_Encoder_Stub.M1_ConfirmCoherence_IHM,
    TopPositionSensor    := PRG_0_Inputs.TopPositionSensor,
    TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM1_M,
    ContactorFeedbackFwd := PRG_0_Inputs.M1ContactorFeedbackFwd,
    ContactorFeedbackRev := PRG_0_Inputs.M1ContactorFeedbackRev,
    BrakeFeedback        := PRG_0_Inputs.M1BrakeFeedback,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

// 3. TREUIL M2 (Abs → Scale → Homing)
instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := (GVL_Encoder_Stub.M2_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    Mode                := PRG_4_Modes.instModes.Mode,
    RawPosIn            := M2_RawPosToUse,
    AlarmsIn            := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD2_Alarms, 0),
    WarningsIn          := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD2_Warnings, 0),
    SlaveOperational    := PRG_1_Diagnostics.instDiagEthercat.EncoderM2.Operational OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    PresetRequest       := instHomingM2.PresetRequest,
    PresetValue         := instHomingM2.PresetValue
);
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

instHomingM2(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM2,
    Reset                := (GVL_Encoder_Stub.M2_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk      := PRG_0_Inputs.EmergencyStopOk,
    Mode                 := PRG_4_Modes.instModes.Mode,
    Home                 := (GVL_Encoder_Stub.StubHomeButton_IHM AND ((GVL_Encoder_Stub.HomingMode_IHM = 2) OR (GVL_Encoder_Stub.HomingMode_IHM = 3))),
    ConfirmCoherence     := GVL_Encoder_Stub.M2_ConfirmCoherence_IHM,
    TopPositionSensor    := PRG_0_Inputs.TopPositionSensor,
    TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM2_M,
    ContactorFeedbackFwd := PRG_0_Inputs.M2ContactorFeedbackFwd,
    ContactorFeedbackRev := PRG_0_Inputs.M2ContactorFeedbackRev,
    BrakeFeedback        := PRG_0_Inputs.M2BrakeFeedback,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

// 4. SÉCURITÉ DE BORNAGE ET INCOHÉRENCE
instEncoderSafetyM1(
    Enable          := TRUE,
    Reset           := (GVL_Encoder_Stub.M1_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk := PRG_0_Inputs.EmergencyStopOk,
    Mode            := PRG_4_Modes.instModes.Mode,
    CablePosM       := instEncoderScaleM1.CablePosM,
    HomingSuspect   := instHomingM1.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0
);
EncoderFaultPresentM1 := instEncoderSafetyM1.EncoderIncoherent;

instEncoderSafetyM2(
    Enable          := TRUE,
    Reset           := (GVL_Encoder_Stub.M2_Reset_IHM OR PRG_9_Supervision.MachineReset_IHM),
    EmergencyStopOk := PRG_0_Inputs.EmergencyStopOk,
    Mode            := PRG_4_Modes.instModes.Mode,
    CablePosM       := instEncoderScaleM2.CablePosM,
    HomingSuspect   := instHomingM2.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0
);
EncoderFaultPresentM2 := instEncoderSafetyM2.EncoderIncoherent;

EncoderFaultPresent := EncoderFaultPresentM1 OR EncoderFaultPresentM2;
