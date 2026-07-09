(* ═══════════════════════════════════════════════════════════════
   🧲 PRG_02_Encoders — Acquisition, Recalage (Homing) et Sécurité Codeurs
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 2.
   ✅ Expose ses défauts en VAR_OUTPUT (1 cycle de retard assumé pour instModes).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_02_Encoders
VAR_OUTPUT
    EncoderFaultPresent   : BOOL;   // OR des deux - lu par PRG_04_Modes au cycle suivant
    EncoderFaultPresentM1 : BOOL;
    EncoderFaultPresentM2 : BOOL;
END_VAR
VAR
    // 🧪 Simulation banc de test (Lot 2 — voir CODE/SIMULATION/FB_Sim_Encoder.st)
    instSimEncoderM1      : FB_Sim_Encoder;
    instSimEncoderM2      : FB_Sim_Encoder;
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

// 1. SIMULATION SUR BANC DE TEST (Lot 2, granularité indépendante M1/M2 — voir AF_Partie13)
// 🔧 REX 2026-07-08 : RawPos (VAR_IN_OUT) référence GVL_PERSISTENT.SimEncoderRawPosM1/M2 —
// survit à un reset froid comme le ferait un vrai codeur absolu physique (voir GVL_PERSISTENT.st).
instSimEncoderM1(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal,
    RelayFwd    := PRG_10_Outputs.M1RelayFwd,
    RelayRev    := PRG_10_Outputs.M1RelayRev,
    SpeedRefPct := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current,
    PresetCmd   := (COD1_PresettTrigCmd = 2),
    PresetValue := COD1_PresetValue,
    SpeedScaleFactor := GVL_Simulation.EncoderSimSpeedFactor,  // 🔧 REX 2026-07-07 : confort de test
    // 🆕 REX 2026-07-08 (4) : injection saut de test (Concept 1 / Méca E) — 4096 = PointsPerRev/CableM_PerRev (8192/2.0)
    TestOffsetCmd := GVL_Simulation.InjectSyncDeviationM1,
    TestOffsetPts := REAL_TO_DINT(GVL_Simulation.SyncDeviationOffsetM * 4096.0),
    RawPos      := GVL_PERSISTENT.SimEncoderRawPosM1
);
instSimEncoderM2(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM2_IsReal,
    RelayFwd    := PRG_10_Outputs.M2RelayFwd,
    RelayRev    := PRG_10_Outputs.M2RelayRev,
    SpeedRefPct := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current,
    PresetCmd   := (COD2_PresettTrigCmd = 2),
    PresetValue := COD2_PresetValue,
    SpeedScaleFactor := GVL_Simulation.EncoderSimSpeedFactor,  // 🔧 REX 2026-07-07 : confort de test
    // 🆕 REX 2026-07-08 (4) : injection saut de test (Concept 1 / Méca E)
    TestOffsetCmd := GVL_Simulation.InjectSyncDeviationM2,
    TestOffsetPts := REAL_TO_DINT(GVL_Simulation.SyncDeviationOffsetM * 4096.0),
    RawPos      := GVL_PERSISTENT.SimEncoderRawPosM2
);

// Aiguillage (par device — 🔧 REX 2026-07-07 : ne PAS utiliser Operational, forcé à TRUE en
// simulation par PRG_01_Diagnostics [SEL sur EncoderMx_IsReal] pour ne pas remonter de faux
// défaut bus — ça sélectionnait donc systématiquement COD1/COD2_PosValue [réel, figé à 0] au
// lieu de la position simulée, bloquant tout homing/mouvement testé en simulation.
IF GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal THEN
    M1_RawPosToUse := instSimEncoderM1.RawPosOut;
ELSE
    M1_RawPosToUse := COD1_PosValue;
END_IF;

IF GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM2_IsReal THEN
    M2_RawPosToUse := instSimEncoderM2.RawPosOut;
ELSE
    M2_RawPosToUse := COD2_PosValue;
END_IF;

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
    AlarmsIn            := SEL(instSimEncoderM1.Enable, COD1_Alarms, 0),
    WarningsIn          := SEL(instSimEncoderM1.Enable, COD1_Warnings, 0),
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.EncoderM1.Operational OR instSimEncoderM1.Enable,
    PresetRequest       := instHomingM1.PresetRequest,
    PresetValue         := instHomingM1.PresetValue
);
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instHomingM1(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM1,
    Reset                := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk      := PRG_00_Inputs.EmergencyStopOk,
    Mode                 := PRG_04_Modes.instModes.Mode,
    // ─────────  Début modification IHM_MANU  ─────────
    // 🆕 REX 2026-07-09 : OR avec HomingEncoder_M1 (mise en service urgence) — même FB, mêmes
    // conditions de sécurité (Mode MAINT_N1/N2, arrêt confirmé), aucune nouvelle dérogation.
    Home                 := GVL_IHM.WinchM1.CmdHome OR GVL_IHM.IHM_MANU.HomingEncoder_M1, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    // ─────────  Fin modification IHM_MANU  ─────────
    ConfirmCoherence     := GVL_IHM.WinchM1.ConfirmCoherence, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    TopPositionSensor    := PRG_00_Inputs.TopPositionSensor,
    TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM1_M,
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback        := PRG_00_Inputs.M1BrakeFeedback,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
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
    AlarmsIn            := SEL(instSimEncoderM2.Enable, COD2_Alarms, 0),
    WarningsIn          := SEL(instSimEncoderM2.Enable, COD2_Warnings, 0),
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.EncoderM2.Operational OR instSimEncoderM2.Enable,
    PresetRequest       := instHomingM2.PresetRequest,
    PresetValue         := instHomingM2.PresetValue
);
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instHomingM2(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM2,
    Reset                := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk      := PRG_00_Inputs.EmergencyStopOk,
    Mode                 := PRG_04_Modes.instModes.Mode,
    // ─────────  Début modification IHM_MANU  ─────────
    // 🆕 REX 2026-07-09 : OR avec HomingEncoder_M2 (mise en service urgence) — même FB, mêmes
    // conditions de sécurité (Mode MAINT_N1/N2, arrêt confirmé), aucune nouvelle dérogation.
    Home                 := GVL_IHM.WinchM2.CmdHome OR GVL_IHM.IHM_MANU.HomingEncoder_M2, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    // ─────────  Fin modification IHM_MANU  ─────────
    ConfirmCoherence     := GVL_IHM.WinchM2.ConfirmCoherence, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    TopPositionSensor    := PRG_00_Inputs.TopPositionSensor,
    TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM2_M,
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback        := PRG_00_Inputs.M2BrakeFeedback,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
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
    PositionMaxM    := 99.0
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
    PositionMaxM    := 99.0
);
EncoderFaultPresentM2 := instEncoderSafetyM2.EncoderIncoherent;

EncoderFaultPresent := EncoderFaultPresentM1 OR EncoderFaultPresentM2;
