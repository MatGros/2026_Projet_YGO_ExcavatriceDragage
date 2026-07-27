(* ═══════════════════════════════════════════════════════════════
   🧲 PRG_02_Encoders — Acquisition, Recalage (Homing) et Sécurité Codeurs
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 2.
   ✅ Expose ses défauts en VAR_OUTPUT (1 cycle de retard assumé pour instModes).
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-10_Fonction_Encoder_Homing_v1.10.md
*)

PROGRAM PRG_02_Encoders
VAR_OUTPUT
    EncoderFaultPresent   : BOOL;   // OR des deux - lu par PRG_04_Modes au cycle suivant
    EncoderFaultPresentM1 : BOOL;
    EncoderFaultPresentM2 : BOOL;
END_VAR
VAR
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

// === IMPLEMENTATION (corps du PROGRAM PRG_02_Encoders) ===

// 🔧 REX 2026-07-16 : ex-EncoderM1_IsReal/EncoderM2_IsReal ("Conditional Bypass Doctrine") RETIRÉS — plus
// aucun consommateur une fois le bypass Homing IHM_MANU supprimé (voir fin de fichier, ex-bloc
// IF PRG_10_Outputs.ManuActive THEN ... HomingEncoder_M1/M2 ... END_IF).

M1_RawPosToUse := COD1_PosValue;
M2_RawPosToUse := COD2_PosValue;

// 2. TREUIL M1 (Abs → Homing → Scale)
// 🔧 REX 2026-07-07 : Homing appelé AVANT Scale (et non l'inverse) — Scale lit HomingRefRaw en
// entrée ; si Scale s'exécutait avant Homing, un homing réussi au cycle N ne serait répercuté
// sur CablePosM qu'au cycle N+1, alors que instHomingM1.Busy (→ InReferencingMode côté
// FB_Safety_Winch) retombe dès le cycle N — décalage d'1 cycle qui désynchronise le garde-fou
// anti-transition de Méca A (bit7) et provoque un faux déclenchement PowerCutOff au cycle N+1
// (saut de position vu hors fenêtre "référencement en cours"). Homing ne dépend d'aucune sortie
// de Scale (RawPos vient d'instEncoderAbsM1) : aucune dépendance circulaire, réordonnancement sûr.
instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    RawPosIn            := M1_RawPosToUse,
    AlarmsIn            := COD1_Alarms,
    WarningsIn          := COD1_Warnings,
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1.Operational,
    PresetRequest       := instHomingM1.PresetRequest,
    PresetValue         := instHomingM1.PresetValue
);
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instHomingM1(
    Enable               := TRUE,
    Calib                := _CalibM1,
    Reset                := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk      := PRG_00_Inputs.EmergencyStopOk,
    Mode                 := PRG_04_Modes.instModes.Mode,
    Home                 := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero,
    UnitaryMode          := (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2)
                            AND (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated <> 3),
    WinchSelected        := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 1),
    CfgHomingTargetM        := _WinchM1CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M1TreuilRetenue.Cmd.BtnConfirmCoherence,
    TopPositionSensor    := PRG_00_Inputs.TopPositionSensor,
    CfgTopSensorPosM   := SEL(GVL_IHM.M1TreuilRetenue.Cmd.BtnHomingAtZero, _WinchM1CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff,
    BrakeFeedback        := PRG_00_Inputs.M1BrakeFeedback,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

// 3. TREUIL M2 (Abs → Homing → Scale)
instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    RawPosIn            := M2_RawPosToUse,
    AlarmsIn            := COD2_Alarms,
    WarningsIn          := COD2_Warnings,
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2.Operational,
    PresetRequest       := instHomingM2.PresetRequest,
    PresetValue         := instHomingM2.PresetValue
);
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instHomingM2(
    Enable               := TRUE,
    Calib                := _CalibM2,
    Reset                := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk      := PRG_00_Inputs.EmergencyStopOk,
    Mode                 := PRG_04_Modes.instModes.Mode,
    Home                 := GVL_IHM.M2TreuilBenne.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    UnitaryMode          := (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2)
                            AND (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated <> 3),
    WinchSelected        := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 2),
    CfgHomingTargetM        := _WinchM2CfgPersist.CfgHomingTarget_M,
    BtnConfirmCoherence     := GVL_IHM.M2TreuilBenne.Cmd.BtnConfirmCoherence, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    TopPositionSensor    := PRG_00_Inputs.TopPositionSensor,
    CfgTopSensorPosM   := SEL(GVL_IHM.M2TreuilBenne.Cmd.BtnHomingAtZero, _WinchM2CfgPersist.CfgTopSensorPos_M, 0.0),
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback        := PRG_00_Inputs.M2BrakeFeedback,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0,
    BypassGlobal         := GVL_IHM.M2TreuilBenne.Bypass.Global
);

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,
    CableM_PerRev   := 2.0,
    PointsPerRev    := 8192
);

// 4. SÉCURITÉ DE BORNAGE ET INCOHÉRENCE
instEncoderSafetyM1(
    Enable          := TRUE,
    Reset           := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    Mode            := PRG_04_Modes.instModes.Mode,
    CablePosM       := instEncoderScaleM1.CablePosM,
    HomingSuspect   := instHomingM1.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0,
    BypassGlobal    := GVL_IHM.M1TreuilRetenue.Bypass.Global
);
EncoderFaultPresentM1 := instEncoderSafetyM1.EncoderIncoherent;

instEncoderSafetyM2(
    Enable          := TRUE,
    Reset           := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    Mode            := PRG_04_Modes.instModes.Mode,
    CablePosM       := instEncoderScaleM2.CablePosM,
    HomingSuspect   := instHomingM2.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0,
    BypassGlobal    := GVL_IHM.M2TreuilBenne.Bypass.Global
);
EncoderFaultPresentM2 := instEncoderSafetyM2.EncoderIncoherent;

EncoderFaultPresent := EncoderFaultPresentM1 OR EncoderFaultPresentM2;
