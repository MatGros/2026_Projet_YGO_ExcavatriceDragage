(* ═══════════════════════════════════════════════════════════════
   🛡️ PRG_03_Safety — Centralisation des surveillances et blocs Safety
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md ; DOC/AF_Partie-03_Template_FB_Commun_v1.3.md
*)

PROGRAM PRG_03_Safety
VAR
    instSafetyWinchM1   : FB_Safety_Winch;
    instSafetyWinchM2   : FB_Safety_Winch;
    instSpeedMonitorM1  : FB_Encoder_SpeedMonitor;
    instSpeedMonitorM2  : FB_Encoder_SpeedMonitor;
    instLoadEstimatorM1 : FB_WinchLoadEstimator;
    instLoadEstimatorM2 : FB_WinchLoadEstimator;
    instSafetyTranslationM3 : FB_Safety_Translation;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_03_Safety) ===

// 1. Sécurité Treuil M1
instSafetyWinchM1(
    // 🔧 REX 2026-07-15 (2) — SIMPLIFICATION : IHM_MANU pilote désormais M1 via FB_Winch
    // (PRG_06_WinchControl), qui a BESOIN d'un SafeStop/ForbidAscent/ForbidDescent réels pour
    // rampé/ralentir proprement (ex-doctrine "Conditional Bypass" devenue obsolète et RETIRÉE
    // ici : chaque capteur/retour a DÉJÀ sa propre granularité réel/simulé — GVL_Simulation.
    // BusEncoderM1IsReal, SensorM1ContactorFeedbackIsReal, SensorM1ThermalIsReal, SensorTopPositionIsReal,
    // SensorSlackCableIsReal — un composant simulé est déjà forcé "sain" en amont (PRG_00_Inputs/
    // PRG_02_Encoders), donc Enable n'a plus besoin de bypasser tout le domaine : un vrai défaut
    // sur un composant RÉEL protège, un composant SIMULÉ ne fait jamais défaut de lui-même).
    Enable              := NOT PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08 : Inhibit (MAINT_N2) uniquement
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    SyncEnable          := PRG_04_Modes.instModes.SyncEnable,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk,
    EncoderAvailable    := PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable,
    EncoderFaultBypass  := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    ThermalFeedback     := NOT PRG_00_Inputs.M1ThermalFeedback,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    SlackCableDetected  := NOT PRG_00_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_00_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_02_Encoders.instHomingM1.Busy,
    CablePosM           := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    Direction           := PRG_06_WinchControl.M1_Direction_Active,
    MovementCommanded   := PRG_06_WinchControl.instWinchM1.RelayFwd OR PRG_06_WinchControl.instWinchM1.RelayRev,
    Homed               := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect       := PRG_02_Encoders.instHomingM1.HomingSuspect,
    TopLimitM           := _WinchM1CfgPersist.CfgTopSensorPos_M,
    // 🔧 REX 2026-07-07 — Méca A/B/C (voir FB_Safety_Winch bandeau en-tête)
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff,
    BrakeFeedback          := PRG_00_Inputs.M1BrakeFeedback,
    // 🔧 REX 2026-07-19 : suppression IHM_MANU — le joystick est désormais la SEULE source de
    // mouvement manuel (plus de boutons HMI bruts en parallèle) : le check bouton ajouté en
    // 2026-07-15 (7) pour compenser ce 2ᵉ chemin de commande est devenu sans objet, retiré.
    JoystickYNeutral       := (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1),
    BenneHoldStillActive := PRG_06_WinchControl.instBucket.Busy, // Méca C — M1 doit rester immobile pendant le
                                                                     // benne ; 1 cycle de retard accepté (PRG_03
                                                                     // avant PRG_06 dans l'ordre de tâche), négligeable
    // 🆕 REX 2026-07-08 (4) — Méca E : M2 corrigé de l'offset benne actif (0 si benne absent/ouvert),
    // ramené dans le référentiel M1 — comparaison valable quel que soit l'état du benne
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM,
    BenneBusy            := PRG_06_WinchControl.instBucket.Busy,
    CriticalSyncToleranceM := _WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM2, // 🆕 REX 2026-07-08 (7)
    MeasuredSpeedMps       := PRG_02_Encoders.M1MeasuredSpeed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Encoders.M1MeasuredSpeedSigned_Mps,
    MeasuredSpeedValid     := PRG_02_Encoders.M1SpeedValid,
    // 🌐 Bypass Global M1 (GVL_IHM.M1TreuilRetenue.Bypass.Global)
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal,
    BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.MecaE,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.Process,
    BypassTopLimitSwitch   := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch,
    BypassCableLimitSwitch := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch
);

// 2. Sécurité Treuil M2
instSafetyWinchM2(
    // 🔧 REX 2026-07-15 (2) — même simplification que M1 ci-dessus (voir bandeau instSafetyWinchM1).
    Enable              := NOT PRG_04_Modes.instModes.InhibitM2, // 🆕 REX 2026-07-08 : Inhibit (MAINT_N2) uniquement
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    SyncEnable          := PRG_04_Modes.instModes.SyncEnable,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk,
    EncoderAvailable    := PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable,
    EncoderFaultBypass  := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault,
    ThermalFeedback     := NOT PRG_00_Inputs.M2ThermalFeedback,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    SlackCableDetected  := NOT PRG_00_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_00_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_02_Encoders.instHomingM2.Busy,
    CablePosM           := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    Direction           := PRG_06_WinchControl.M2_Direction_Active,
    MovementCommanded   := PRG_06_WinchControl.instWinchM2.RelayFwd OR PRG_06_WinchControl.instWinchM2.RelayRev,
    Homed               := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect       := PRG_02_Encoders.instHomingM2.HomingSuspect,
    TopLimitM           := _WinchM2CfgPersist.CfgTopSensorPos_M,
    // 🔧 REX 2026-07-07 — Méca A/B (voir FB_Safety_Winch bandeau en-tête) — Méca C NON applicable
    // à M2 (c'est M2 qui bouge pendant le benne, BenneHoldStillActive reste FALSE)
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff,
    BrakeFeedback          := PRG_00_Inputs.M2BrakeFeedback,
    // 🔧 REX 2026-07-19 : idem M1 (voir bandeau instSafetyWinchM1 ci-dessus) — suppression IHM_MANU.
    JoystickYNeutral       := (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1),
    BenneHoldStillActive := FALSE,
    // 🔧 REX 2026-07-08 (5) : BUG CORRIGÉ — oublié côté M2 lors de l'ajout initial Méca E.
    // ExpectedOtherWinchPosM valait 0.0 par défaut (non câblé) → Méca E comparait CablePosM2
    // à 0 au lieu de M1, déclenchement permanent dès que M2 > CriticalSyncToleranceM (2.0m)
    // du zéro codeur. M1 corrigé de l'offset benne actif, ramené dans le référentiel M2.
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM1.CablePosM + PRG_06_WinchControl.instBucket.ActiveOffsetM,
    BenneBusy            := PRG_06_WinchControl.instBucket.Busy,
    CriticalSyncToleranceM := _WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08 (7)
    MeasuredSpeedMps       := PRG_02_Encoders.M2MeasuredSpeed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Encoders.M2MeasuredSpeedSigned_Mps,
    MeasuredSpeedValid     := PRG_02_Encoders.M2SpeedValid,
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassOperatorComm     := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.BrakeThermal,
    BypassMecaA            := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.MecaE,
    BypassSafety           := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.Safety,
    BypassProcess          := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.Process,
    BypassTopLimitSwitch   := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.TopLimitSwitch,
    BypassCableLimitSwitch := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.CableLimitSwitch
);

// 2bis. Moniteurs vitesse — diagnostic seul ; seuils désactivés jusqu'à T45.
instSpeedMonitorM1(
    Enable                     := NOT PRG_04_Modes.instModes.InhibitM1 AND PRG_02_Encoders.M1SpeedValid,
    Reset                      := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk            := PRG_00_Inputs.EmergencyStopOk,
    Mode                       := PRG_04_Modes.instModes.Mode,
    SpeedMps                   := PRG_02_Encoders.M1MeasuredSpeed_Mps,
    SpeedVariationThresholdMps := 0.0,
    SpeedVariationTimeout      := T#0ms,
    SpeedStabilityTimeout      := T#0ms
);
instSpeedMonitorM2(
    Enable                     := NOT PRG_04_Modes.instModes.InhibitM2 AND PRG_02_Encoders.M2SpeedValid,
    Reset                      := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk            := PRG_00_Inputs.EmergencyStopOk,
    Mode                       := PRG_04_Modes.instModes.Mode,
    SpeedMps                   := PRG_02_Encoders.M2MeasuredSpeed_Mps,
    SpeedVariationThresholdMps := 0.0,
    SpeedVariationTimeout      := T#0ms,
    SpeedStabilityTimeout      := T#0ms
);

// 2ter. Estimation charge — information empirique, jamais une fonction safety.
instLoadEstimatorM1(
    Enable           := NOT PRG_04_Modes.instModes.InhibitM1 AND PRG_02_Encoders.M1SpeedValid,
    Reset            := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk  := PRG_00_Inputs.EmergencyStopOk,
    Mode             := PRG_04_Modes.instModes.Mode,
    ActiveSpeedStep       := PRG_06_WinchControl.instWinchM1.StepNumber,
    MeasuredSpeedMps      := PRG_02_Encoders.M1MeasuredSpeed_Mps,
    MeasuredSpeedSignedMps:= PRG_02_Encoders.M1MeasuredSpeedSigned_Mps,
    SpeedConfig      := _WinchSpeedConfig,
    LoadTable        := _WinchLoadEstimateTable
);
instLoadEstimatorM2(
    Enable           := NOT PRG_04_Modes.instModes.InhibitM2 AND PRG_02_Encoders.M2SpeedValid,
    Reset            := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk  := PRG_00_Inputs.EmergencyStopOk,
    Mode             := PRG_04_Modes.instModes.Mode,
    ActiveSpeedStep       := PRG_06_WinchControl.instWinchM2.StepNumber,
    MeasuredSpeedMps      := PRG_02_Encoders.M2MeasuredSpeed_Mps,
    MeasuredSpeedSignedMps:= PRG_02_Encoders.M2MeasuredSpeedSigned_Mps,
    SpeedConfig      := _WinchSpeedConfig,
    LoadTable        := _WinchLoadEstimateTable
);

// 3. Sécurité Translation M3
instSafetyTranslationM3(
    // 🔧 REX 2026-07-16 — SIMPLIFICATION : IHM_MANU pilote désormais M3 via FB_Translation
    // (PRG_07_TranslationControl), qui a BESOIN d'un SafeStop réel pour rampé/arrêter proprement
    // (ex-"Conditional Bypass Doctrine" RETIRÉE ici, même traitement que instSafetyWinchM1/M2 —
    // voir REX 2026-07-15 (2) plus haut). Pas d'InhibitM3 dans FB_Modes (contrairement à
    // InhibitM1/M2) : Enable inconditionnel, comme en Auto.
    Enable              := TRUE,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    DriveOnline         := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Online,
    DriveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Operational,
    DriveStatusWord     := PRG_00_Inputs.M3_StatusWord_Filtered,
    DriveActualFreqHz   := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback       := PRG_00_Inputs.M3BrakeFeedback,
    BrakeCmd            := PRG_07_TranslationControl.instTranslationM3.BrakeCmd,
    Direction           := PRG_07_TranslationControl.M3_Direction_Active,
    // 🆕 REX 2026-07-18 : limites extrêmes dérivées du décodage 5 capteurs (mot valide), plus
    // câblées directement sur un capteur brut — voir FB_Translation_PositionDecoder.
    LimitSwitchFwd      := PRG_00_Inputs.instPositionDecoder.LimitSwitchFwd,
    LimitSwitchRev      := PRG_00_Inputs.instPositionDecoder.LimitSwitchRev,
    SensorWordIncoherent := PRG_00_Inputs.instPositionDecoder.Incoherent,
    // 🔧 Bypass des surveillances (GVL_IHM.TranslationM3.Bypass - pilotés IHM)
    BypassGlobal          := GVL_IHM.TranslationM3.Bypass.Global,
    BypassOperatorComm    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.OperatorComm,
    BypassDriveComm       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.DriveComm,
    BypassPhaseRotation   := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.PhaseRotation,
    BypassBrakeThermal    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.BrakeThermal,
    BypassMecaB           := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.MecaB,
    BypassMecaA           := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.MecaA,
    BypassLimitSwitch     := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch,
    BypassSensorIncoherent:= GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.SensorIncoherent,
    BypassSafety          := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.Safety,
    BypassProcess         := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.Process
);
