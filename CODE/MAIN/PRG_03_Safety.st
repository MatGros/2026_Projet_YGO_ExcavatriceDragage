(* ═══════════════════════════════════════════════════════════════
   🛡️ PRG_03_Safety — Centralisation des surveillances et blocs Safety
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Safety
VAR
    instSafetyWinchM1   : FB_Safety_Winch;
    instSafetyWinchM2   : FB_Safety_Winch;
    instSafetyTranslationM3 : FB_Safety_Translation;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_03_Safety) ===

// 1. Sécurité Treuil M1
instSafetyWinchM1(
    // 🔧 REX 2026-07-15 (2) — SIMPLIFICATION : IHM_MANU pilote désormais M1 via FB_Winch
    // (PRG_06_WinchControl), qui a BESOIN d'un SafeStop/ForbidAscent/ForbidDescent réels pour
    // rampé/ralentir proprement (ex-doctrine "Conditional Bypass" devenue obsolète et RETIRÉE
    // ici : chaque capteur/retour a DÉJÀ sa propre granularité réel/simulé — GVL_Simulation.
    // EncoderM1_IsReal, ContactorFeedbackM1_IsReal, ThermalM1_IsReal, TopPositionSensor_IsReal,
    // SlackCableSwitch_IsReal — un composant simulé est déjà forcé "sain" en amont (PRG_00_Inputs/
    // PRG_02_Encoders), donc Enable n'a plus besoin de bypasser tout le domaine : un vrai défaut
    // sur un composant RÉEL protège, un composant SIMULÉ ne fait jamais défaut de lui-même).
    Enable              := NOT PRG_04_Modes.instModes.InhibitM1, // 🆕 REX 2026-07-08 : Inhibit (MAINT_N2) uniquement
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    SyncEnable          := PRG_04_Modes.instModes.SyncEnable,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational,
    EncoderAvailable    := PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := NOT PRG_00_Inputs.M1ThermalFeedback,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    SlackCableDetected  := NOT PRG_00_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_00_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_02_Encoders.instHomingM1.Busy,
    CablePosM           := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescentM1_M,
    Direction           := PRG_06_WinchControl.M1_Direction_Active,
    Homed               := PRG_02_Encoders.instHomingM1.Homed,
    HomingSuspect       := PRG_02_Encoders.instHomingM1.HomingSuspect,
    TopLimitM           := GVL_PERSISTENT.HomingTargetM1_M,
    // 🔧 REX 2026-07-07 — Méca A/B/C (voir FB_Safety_Winch bandeau en-tête)
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff,
    BrakeFeedback          := PRG_00_Inputs.M1BrakeFeedback,
    // 🔧 REX 2026-07-15 (7) — BUG CORRIGÉ (retour terrain, SafetyErrorId=256/bit8) : Méca B ne
    // regardait QUE le joystick CANopen pour détecter "commande opérateur" — en IHM_MANU piloté
    // par BOUTONS HMI (JoystickSelect=FALSE), le joystick reste au neutre en permanence, donc
    // MecaB_NoOperatorCmd restait TRUE en continu même pendant un mouvement légitime aux boutons
    // → SafeStop après PostRampTimeout (3s) dès qu'un mouvement HMI dépassait ce délai. Ajout des
    // boutons IHM_MANU bruts (M1 individuel + Couplé) — reste indépendant de l'arbitrage
    // PRG_06/FB_Winch (défense en profondeur intacte, lecture directe des boutons IHM comme le
    // joystick l'était déjà).
    JoystickYNeutral       := (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1)
                              AND NOT GVL_IHM.IHM_MANU.M1_RelayFwd AND NOT GVL_IHM.IHM_MANU.M1_RelayRev
                              AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayRev,
    BenneHoldStillActive := PRG_06_WinchControl.instBucket.Busy, // Méca C — M1 doit rester immobile pendant le
                                                                     // benne ; 1 cycle de retard accepté (PRG_03
                                                                     // avant PRG_06 dans l'ordre de tâche), négligeable
    // 🆕 REX 2026-07-08 (4) — Méca E : M2 corrigé de l'offset benne actif (0 si benne absent/ouvert),
    // ramené dans le référentiel M1 — comparaison valable quel que soit l'état du benne
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM,
    BenneBusy            := PRG_06_WinchControl.instBucket.Busy,
    CriticalSyncToleranceM := GVL_PERSISTENT.WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM2 // 🆕 REX 2026-07-08 (7)
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
    EncoderAvailable    := PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := NOT PRG_00_Inputs.M2ThermalFeedback,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    SlackCableDetected  := NOT PRG_00_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_00_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_02_Encoders.instHomingM2.Busy,
    CablePosM           := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescentM2_M,
    Direction           := PRG_06_WinchControl.M2_Direction_Active,
    Homed               := PRG_02_Encoders.instHomingM2.Homed,
    HomingSuspect       := PRG_02_Encoders.instHomingM2.HomingSuspect,
    TopLimitM           := GVL_PERSISTENT.HomingTargetM2_M,
    // 🔧 REX 2026-07-07 — Méca A/B (voir FB_Safety_Winch bandeau en-tête) — Méca C NON applicable
    // à M2 (c'est M2 qui bouge pendant le benne, BenneHoldStillActive reste FALSE)
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff,
    BrakeFeedback          := PRG_00_Inputs.M2BrakeFeedback,
    // 🔧 REX 2026-07-15 (7) : idem M1 (voir bandeau instSafetyWinchM1 ci-dessus).
    JoystickYNeutral       := (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1)
                              AND NOT GVL_IHM.IHM_MANU.M2_RelayFwd AND NOT GVL_IHM.IHM_MANU.M2_RelayRev
                              AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayRev,
    BenneHoldStillActive := FALSE,
    // 🔧 REX 2026-07-08 (5) : BUG CORRIGÉ — oublié côté M2 lors de l'ajout initial Méca E.
    // ExpectedOtherWinchPosM valait 0.0 par défaut (non câblé) → Méca E comparait CablePosM2
    // à 0 au lieu de M1, déclenchement permanent dès que M2 > CriticalSyncToleranceM (2.0m)
    // du zéro codeur. M1 corrigé de l'offset benne actif, ramené dans le référentiel M2.
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM1.CablePosM + PRG_06_WinchControl.instBucket.ActiveOffsetM,
    BenneBusy            := PRG_06_WinchControl.instBucket.Busy,
    CriticalSyncToleranceM := GVL_PERSISTENT.WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM1 // 🆕 REX 2026-07-08 (7)
);

// 3. Sécurité Translation M3
instSafetyTranslationM3(
    Enable              := NOT PRG_10_Outputs.ManuActive OR NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.VariateurM3_IsReal OR GVL_Simulation.ContactorFeedbackM3_IsReal OR GVL_Simulation.TranslationPosition_IsReal, // 🆕 REX 2026-07-14 : ManuActive (Conditional Bypass Doctrine)
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback, // 🆕 REX 2026-07-08 — commun M1/M2/M3
    DriveOnline         := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Online,
    DriveOperational    := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Operational,
    DriveStatusWord     := PRG_00_Inputs.M3_StatusWord_Filtered,
    DriveActualFreqHz   := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback       := PRG_00_Inputs.M3BrakeFeedback,
    BrakeCmd            := PRG_07_TranslationControl.instTranslationM3.BrakeCmd,
    Direction           := PRG_07_TranslationControl.M3_Direction_Active,
    LimitSwitchFwd      := PRG_00_Inputs.TranslationPosTremie,
    LimitSwitchRev      := PRG_00_Inputs.TranslationPosFosse1
);
