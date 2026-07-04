(* ═══════════════════════════════════════════════════════════════
   🛡️ PRG_3_Safety — Centralisation des surveillances et blocs Safety
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_3_Safety
VAR
    instSafetyWinchM1   : FB_Safety_Winch;
    instSafetyWinchM2   : FB_Safety_Winch;
    instSafetyChariotM3 : FB_Safety_Chariot;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_3_Safety) ===

// 1. Sécurité Treuil M1
instSafetyWinchM1(
    Enable              := TRUE,
    Reset               := PRG_9_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    Mode                := PRG_4_Modes.instModes.Mode,
    OverrideSync        := PRG_4_Modes.instModes.OverrideSync,
    JoystickOnline      := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := PRG_2_Encoders.instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := NOT PRG_0_Inputs.M1ThermalFeedback,
    SlackCableDetected  := NOT PRG_0_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_0_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_0_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_2_Encoders.instHomingM1.Busy,
    CablePosM           := PRG_2_Encoders.instEncoderScaleM1.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M
);

// 2. Sécurité Treuil M2
instSafetyWinchM2(
    Enable              := TRUE,
    Reset               := PRG_9_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    Mode                := PRG_4_Modes.instModes.Mode,
    OverrideSync        := PRG_4_Modes.instModes.OverrideSync,
    JoystickOnline      := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := PRG_2_Encoders.instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := NOT PRG_0_Inputs.M2ThermalFeedback,
    SlackCableDetected  := NOT PRG_0_Inputs.SlackCableSwitch,
    PhaseRotationOk     := PRG_0_Inputs.PhaseRotationOk,
    TopPositionSensor   := PRG_0_Inputs.TopPositionSensor,
    InReferencingMode   := PRG_2_Encoders.instHomingM2.Busy,
    CablePosM           := PRG_2_Encoders.instEncoderScaleM2.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M
);

// 3. Sécurité Chariot M3
instSafetyChariotM3(
    Enable              := TRUE,
    Reset               := PRG_9_Supervision.MachineReset_IHM,
    EmergencyStopOk     := PRG_0_Inputs.EmergencyStopOk,
    Mode                := PRG_4_Modes.instModes.Mode,
    JoystickOnline      := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Online,
    JoystickOperational := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Operational,
    PhaseRotationOk     := PRG_0_Inputs.PhaseRotationOk
);
