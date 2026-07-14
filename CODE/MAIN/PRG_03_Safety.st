(* ═══════════════════════════════════════════════════════════════
   🛡️ PRG_03_Safety — Centralisation des surveillances et blocs Safety
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Safety
VAR
    instSafetyWinchM1   : FB_Safety_Winch;
    instSafetyWinchM2   : FB_Safety_Winch;
    instSafetyChariotM3 : FB_Safety_Chariot;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_03_Safety) ===

// 1. Sécurité Treuil M1
instSafetyWinchM1(
    Enable              := NOT PRG_04_Modes.instModes.InhibitM1 AND NOT PRG_10_Outputs.ManuActive, // 🆕 REX 2026-07-08 : inhibition mise en service (MAINT_N2) / 2026-07-14 : ManuActive
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    SyncEnable          := PRG_04_Modes.instModes.SyncEnable,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Operational,
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
    JoystickYNeutral       := ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1,
    GrappinHoldStillActive := PRG_06_WinchControl.instGrappin.Busy, // Méca C — M1 doit rester immobile pendant le
                                                                     // grappin ; 1 cycle de retard accepté (PRG_03
                                                                     // avant PRG_06 dans l'ordre de tâche), négligeable
    // 🆕 REX 2026-07-08 (4) — Méca E : M2 corrigé de l'offset grappin actif (0 si grappin absent/ouvert),
    // ramené dans le référentiel M1 — comparaison valable quel que soit l'état du grappin
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instGrappin.ActiveOffsetM,
    GrappinBusy            := PRG_06_WinchControl.instGrappin.Busy,
    CriticalSyncToleranceM := GVL_PERSISTENT.WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM2 // 🆕 REX 2026-07-08 (7)
);

// 2. Sécurité Treuil M2
instSafetyWinchM2(
    Enable              := NOT PRG_04_Modes.instModes.InhibitM2 AND NOT PRG_10_Outputs.ManuActive, // 🆕 REX 2026-07-08 : inhibition mise en service (MAINT_N2) / 2026-07-14 : ManuActive
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    SyncEnable          := PRG_04_Modes.instModes.SyncEnable,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Operational,
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
    // à M2 (c'est M2 qui bouge pendant le grappin, GrappinHoldStillActive reste FALSE)
    FwdRevSpeedFeedbackOff := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff,
    BrakeFeedback          := PRG_00_Inputs.M2BrakeFeedback,
    JoystickYNeutral       := ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 0.1,
    GrappinHoldStillActive := FALSE,
    // 🔧 REX 2026-07-08 (5) : BUG CORRIGÉ — oublié côté M2 lors de l'ajout initial Méca E.
    // ExpectedOtherWinchPosM valait 0.0 par défaut (non câblé) → Méca E comparait CablePosM2
    // à 0 au lieu de M1, déclenchement permanent dès que M2 > CriticalSyncToleranceM (2.0m)
    // du zéro codeur. M1 corrigé de l'offset grappin actif, ramené dans le référentiel M2.
    ExpectedOtherWinchPosM := PRG_02_Encoders.instEncoderScaleM1.CablePosM + PRG_06_WinchControl.instGrappin.ActiveOffsetM,
    GrappinBusy            := PRG_06_WinchControl.instGrappin.Busy,
    CriticalSyncToleranceM := GVL_PERSISTENT.WinchCriticalSyncTolerance_M,
    OtherWinchInhibited    := PRG_04_Modes.instModes.InhibitM1 // 🆕 REX 2026-07-08 (7)
);

// 3. Sécurité Chariot M3
instSafetyChariotM3(
    Enable              := NOT PRG_10_Outputs.ManuActive, // 🆕 REX 2026-07-14 : ManuActive
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    JoystickOnline      := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Operational,
    PhaseRotationOk     := PRG_00_Inputs.PhaseRotationOk,
    BrakeThermalFeedback := NOT PRG_00_Inputs.BrakeThermalFeedback // 🆕 REX 2026-07-08 — commun M1/M2/M3
);
