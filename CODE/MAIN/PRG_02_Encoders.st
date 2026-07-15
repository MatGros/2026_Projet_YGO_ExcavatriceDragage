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

    M1_SimSpeedPct      : REAL;
    M2_SimSpeedPct      : REAL;
    M1_IsReal           : BOOL;         // ⚡ Indique si le treuil M1 est configuré comme réel
    M2_IsReal           : BOOL;         // ⚡ Indique si le treuil M2 est configuré comme réel
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_02_Encoders) ===

// 🆕 Détermination de la réalité des treuils (Conditional Bypass Doctrine)
M1_IsReal := NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.EncoderM1_IsReal OR GVL_Simulation.ContactorFeedbackM1_IsReal OR GVL_Simulation.ThermalM1_IsReal;
M2_IsReal := NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.EncoderM2_IsReal OR GVL_Simulation.ContactorFeedbackM2_IsReal OR GVL_Simulation.ThermalM2_IsReal;

// 🔧 REX 2026-07-15 (4) — CORRECTIF COMPILATION : ex-SEL(ManuActive, ...) référençait
// PRG_10_Outputs.SpeedRefPct, supprimé lors du passage de Manu sur FB_Winch (REX 2026-07-15 (2)).
// Plus besoin de distinguer Auto/Manu ici : instWinchM1/M2.SpeedRamp.Current est désormais LA
// vitesse rampée réelle dans les DEUX cas (FB_Winch pilote M1/M2 qu'on soit en Auto ou en Manu).
M1_SimSpeedPct := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current;
M2_SimSpeedPct := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current;

// 1. SIMULATION SUR BANC DE TEST (Lot 2, granularité indépendante M1/M2 — voir AF_Partie13)
// 🔧 REX 2026-07-08 : RawPos (VAR_IN_OUT) référence GVL_PERSISTENT.SimEncoderRawPosM1/M2 —
// survit à un reset froid comme le ferait un vrai codeur absolu physique (voir GVL_PERSISTENT.st).
instSimEncoderM1(
    Enable      := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal,
    // 🔧 REX 2026-07-15 (2) : lit directement instWinchM1 (PRG_06_WinchControl) — M1 est désormais
    // piloté par FB_Winch en Auto ET en Manu (ex-SimM1Fwd_Eff/PRG_10_Outputs retiré, obsolète) :
    // RelayFwd/RelayRev respectent déjà SafeStop/ForbidAscent/ForbidDescent nativement, plus besoin
    // de signaux Sim dédiés.
    RelayFwd    := PRG_06_WinchControl.instWinchM1.RelayFwd,
    RelayRev    := PRG_06_WinchControl.instWinchM1.RelayRev,
    SpeedRefPct := M1_SimSpeedPct,
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
    // 🔧 REX 2026-07-15 (2) : idem M1 ci-dessus, lit instWinchM2 (ex-SimM2Fwd_Eff retiré).
    RelayFwd    := PRG_06_WinchControl.instWinchM2.RelayFwd,
    RelayRev    := PRG_06_WinchControl.instWinchM2.RelayRev,
    SpeedRefPct := M2_SimSpeedPct,
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
IF (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal) THEN
    M1_RawPosToUse := instSimEncoderM1.RawPosOut;
ELSE
    M1_RawPosToUse := COD1_PosValue;
END_IF;

IF (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM2_IsReal) THEN
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
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1.Operational OR instSimEncoderM1.Enable,
    PresetRequest       := instHomingM1.PresetRequest OR (PRG_10_Outputs.ManuActive AND NOT M1_IsReal AND GVL_IHM.IHM_MANU.HomingEncoder_M1),
    PresetValue         := SEL(PRG_10_Outputs.ManuActive AND NOT M1_IsReal AND GVL_IHM.IHM_MANU.HomingEncoder_M1, instHomingM1.PresetValue, 16777216)
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
    Home                 := GVL_IHM.M1TreuilRetenue.CmdHome OR GVL_IHM.IHM_MANU.HomingEncoder_M1, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    // ─────────  Fin modification IHM_MANU  ─────────
    ConfirmCoherence     := GVL_IHM.M1TreuilRetenue.ConfirmCoherence, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
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
    SlaveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2.Operational OR instSimEncoderM2.Enable,
    PresetRequest       := instHomingM2.PresetRequest OR (PRG_10_Outputs.ManuActive AND NOT M2_IsReal AND GVL_IHM.IHM_MANU.HomingEncoder_M2),
    PresetValue         := SEL(PRG_10_Outputs.ManuActive AND NOT M2_IsReal AND GVL_IHM.IHM_MANU.HomingEncoder_M2, instHomingM2.PresetValue, 16777216)
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
    Home                 := GVL_IHM.M2TreuilBucket.CmdHome OR GVL_IHM.IHM_MANU.HomingEncoder_M2, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
    // ─────────  Fin modification IHM_MANU  ─────────
    ConfirmCoherence     := GVL_IHM.M2TreuilBucket.ConfirmCoherence, // 🔧 REX 2026-07-07 : fusion GVL_Encoder_Stub → GVL_IHM
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

// ─────────  Début modification IHM_MANU  ─────────
// 🎯 Référencement direct (bypass sécurité et modes) si HomingEncoder_M1/M2 activés en Manu (uniquement si SIMULÉ)
// Sinon, si les treuils sont réels, on utilise le homing normal sécurisé, et on réinitialise le bouton HMI dès que homing ok/erreur.
IF PRG_10_Outputs.ManuActive THEN
    IF GVL_IHM.IHM_MANU.HomingEncoder_M1 THEN
        IF NOT M1_IsReal THEN
            IF instEncoderAbsM1.PresetAck THEN
                GVL_PERSISTENT.CalibM1.HomingRefRaw := 16726016; // 16777216 - (12.5 * 8192 / 2.0)
                GVL_PERSISTENT.CalibM1.Homed := TRUE;
                GVL_PERSISTENT.CalibM1.HomingSuspect := FALSE;
                GVL_PERSISTENT.CalibM1.LastKnownRawPos := 16777216;
                GVL_IHM.IHM_MANU.HomingEncoder_M1 := FALSE; // Reset bouton HMI
            ELSIF instEncoderAbsM1.PresetNak THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M1 := FALSE;
            END_IF;
        ELSE
            IF instEncoderAbsM1.PresetAck OR instHomingM1.Homed THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M1 := FALSE;
            ELSIF instEncoderAbsM1.PresetNak OR instHomingM1.Error THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M1 := FALSE;
            END_IF;
        END_IF;
    END_IF;

    IF GVL_IHM.IHM_MANU.HomingEncoder_M2 THEN
        IF NOT M2_IsReal THEN
            IF instEncoderAbsM2.PresetAck THEN
                GVL_PERSISTENT.CalibM2.HomingRefRaw := 16726016; // 16777216 - (12.5 * 8192 / 2.0)
                GVL_PERSISTENT.CalibM2.Homed := TRUE;
                GVL_PERSISTENT.CalibM2.HomingSuspect := FALSE;
                GVL_PERSISTENT.CalibM2.LastKnownRawPos := 16777216;
                GVL_IHM.IHM_MANU.HomingEncoder_M2 := FALSE; // Reset bouton HMI
            ELSIF instEncoderAbsM2.PresetNak THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M2 := FALSE;
            END_IF;
        ELSE
            IF instEncoderAbsM2.PresetAck OR instHomingM2.Homed THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M2 := FALSE;
            ELSIF instEncoderAbsM2.PresetNak OR instHomingM2.Error THEN
                GVL_IHM.IHM_MANU.HomingEncoder_M2 := FALSE;
            END_IF;
        END_IF;
    END_IF;
END_IF;
// ─────────  Fin modification IHM_MANU  ─────────
