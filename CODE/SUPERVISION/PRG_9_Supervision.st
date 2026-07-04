(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_9_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose MachineReset_IHM pour tous les autres programmes.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_9_Supervision
VAR_OUTPUT
    MachineReset_IHM : BOOL; // 🔑 Signal d'acquittement général de la machine (OR des boutons HMI)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_9_Supervision) ===

// ── 1. ACQUISITION DES DEMANDES / BOUTONS DE L'IHM ────────────────────────
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.ModeRequest;
GVL_Modes_Stub.PasswordOk_IHM          := GVL_IHM.Modes.PasswordOk;
GVL_Modes_Stub.OverrideSyncRequest_IHM := GVL_IHM.Sync.OverrideSync;
StubChariotPositionSelect_IHM          := GVL_IHM.Chariot.SelectedTargetNum;

// Signal de reset général
MachineReset_IHM := GVL_IHM.Modes.MachineReset 
                    OR GVL_IHM.WinchM1.CmdReset 
                    OR GVL_IHM.WinchM2.CmdReset 
                    OR GVL_IHM.Grappin.CmdReset;

// Bouton Homing IHM
IF GVL_IHM.WinchM1.CmdHome THEN
    GVL_Encoder_Stub.HomingMode_IHM := 1;
    GVL_Encoder_Stub.StubHomeButton_IHM := TRUE;
ELSIF GVL_IHM.WinchM2.CmdHome THEN
    GVL_Encoder_Stub.HomingMode_IHM := 2;
    GVL_Encoder_Stub.StubHomeButton_IHM := TRUE;
ELSE
    GVL_Encoder_Stub.StubHomeButton_IHM := FALSE;
END_IF;

// Transmission de la demande de recalage Joystick
PRG_1_Diagnostics.FB_Joystick_0.Calibrate := GVL_IHM.Joystick.Calibrate;


// ── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot) ───────────────────
IF GVL_IHM.WinchM1.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM1.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM1_M;
    GVL_IHM.WinchM1.MaxStepDescente     := GVL_PERSISTENT.WinchM1MaxStepDescente;
    GVL_IHM.WinchM1.RampAccelRate       := GVL_PERSISTENT.WinchM1RampAccelRate_Pct;
    GVL_IHM.WinchM1.RampDecelNormalRate := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct;
    GVL_IHM.WinchM1.RampDecelFastRate   := GVL_PERSISTENT.WinchM1RampDecelFast_Pct;
    GVL_IHM.WinchM1.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M;
    GVL_IHM.WinchM1.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM1.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.WinchM2.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM2.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM2_M;
    GVL_IHM.WinchM2.MaxStepDescente     := GVL_PERSISTENT.WinchM2MaxStepDescente;
    GVL_IHM.WinchM2.RampAccelRate       := GVL_PERSISTENT.WinchM2RampAccelRate_Pct;
    GVL_IHM.WinchM2.RampDecelNormalRate := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct;
    GVL_IHM.WinchM2.RampDecelFastRate   := GVL_PERSISTENT.WinchM2RampDecelFast_Pct;
    GVL_IHM.WinchM2.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M;
    GVL_IHM.WinchM2.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM2.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.Sync.SyncToleranceM = 0.0 THEN
    GVL_IHM.Sync.SyncToleranceM         := GVL_PERSISTENT.WinchSyncTolerance_M;
END_IF;

IF GVL_IHM.Grappin.Config.OffsetOpenM = 0.0 AND GVL_IHM.Grappin.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.Grappin.Config := GVL_PERSISTENT.GrappinConfig;
    GVL_IHM.Grappin.TimeoutDuration := T#30s;
END_IF;

IF GVL_IHM.LimitLegalDepthMinAllowed = 0.0 THEN
    GVL_IHM.LimitLegalDepthMinAllowed := GVL_PERSISTENT.LimitLegalDepthMinAllowed;
    GVL_IHM.LimitLegalEnabled         := GVL_PERSISTENT.LimitLegalEnabled;
END_IF;

IF GVL_IHM.Modes.ModeRequest = E_Mode.DISABLE THEN
    GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
END_IF;


// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
GVL_PERSISTENT.HomingTargetM1_M           := GVL_IHM.WinchM1.TopSensorPositionM;
GVL_PERSISTENT.HomingTargetM2_M           := GVL_IHM.WinchM2.TopSensorPositionM;
GVL_PERSISTENT.WinchM1MaxStepDescente     := GVL_IHM.WinchM1.MaxStepDescente;
GVL_PERSISTENT.WinchM2MaxStepDescente     := GVL_IHM.WinchM2.MaxStepDescente;
GVL_PERSISTENT.WinchM1RampAccelRate_Pct   := GVL_IHM.WinchM1.RampAccelRate;
GVL_PERSISTENT.WinchM1RampDecelNormal_Pct := GVL_IHM.WinchM1.RampDecelNormalRate;
GVL_PERSISTENT.WinchM1RampDecelFast_Pct   := GVL_IHM.WinchM1.RampDecelFastRate;
GVL_PERSISTENT.WinchM2RampAccelRate_Pct   := GVL_IHM.WinchM2.RampAccelRate;
GVL_PERSISTENT.WinchM2RampDecelNormal_Pct := GVL_IHM.WinchM2.RampDecelNormalRate;
GVL_PERSISTENT.WinchM2RampDecelFast_Pct   := GVL_IHM.WinchM2.RampDecelFastRate;
GVL_PERSISTENT.WinchSyncTolerance_M       := GVL_IHM.Sync.SyncToleranceM;
GVL_PERSISTENT.GrappinConfig              := GVL_IHM.Grappin.Config;

IF GVL_IHM.WinchM1.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescent_M THEN
    GVL_PERSISTENT.CableLimitDescent_M := GVL_IHM.WinchM1.CableLimitDescentM;
ELSIF GVL_IHM.WinchM2.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescent_M THEN
    GVL_PERSISTENT.CableLimitDescent_M := GVL_IHM.WinchM2.CableLimitDescentM;
END_IF;
GVL_IHM.WinchM1.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescent_M;
GVL_IHM.WinchM2.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescent_M;

IF GVL_IHM.WinchM1.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM1.SlowdownDistanceM;
ELSIF GVL_IHM.WinchM2.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM2.SlowdownDistanceM;
END_IF;
GVL_IHM.WinchM1.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;
GVL_IHM.WinchM2.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;

IF GVL_IHM.WinchM1.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM1.SlowSpeedPct;
ELSIF GVL_IHM.WinchM2.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM2.SlowSpeedPct;
END_IF;
GVL_IHM.WinchM1.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;
GVL_IHM.WinchM2.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;

GVL_PERSISTENT.LimitLegalDepthMinAllowed := GVL_IHM.LimitLegalDepthMinAllowed;
GVL_PERSISTENT.LimitLegalEnabled         := GVL_IHM.LimitLegalEnabled;
GVL_IHM.LimitLegalReached                := (PRG_4_Modes.instModes.Mode = E_Mode.SEMI_AUTO) 
                                            AND GVL_PERSISTENT.LimitLegalEnabled 
                                            AND ((PRG_2_Encoders.instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed) 
                                                 OR (PRG_2_Encoders.instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));

GVL_IHM.TopPositionSensorActive          := NOT PRG_0_Inputs.TopPositionSensor;
GVL_Encoder_Stub.M1_TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM1_M;
GVL_Encoder_Stub.M2_TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM2_M;


// ── 4. BYPASS DE SIMULATION POUR L'IHM ──────────────────────────────────
GVL_IHM.WinchM1.BypassContactorFeedback := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.WinchM2.BypassContactorFeedback := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.Chariot.BypassContactorFeedback := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.WinchM1.BypassSlackCable        := GVL_DEBUG.DBG_SlackCableSwitch_TEST;
GVL_IHM.WinchM2.BypassSlackCable        := GVL_DEBUG.DBG_SlackCableSwitch_TEST;
GVL_IHM.WinchM1.BypassTopPositionSensor := GVL_DEBUG.DBG_TopPositionSensorBypass_TEST;
GVL_IHM.WinchM2.BypassTopPositionSensor := GVL_DEBUG.DBG_TopPositionSensorBypass_TEST;


// ── 5. MAPPING ÉTATS TREUIL M1 → IHM ─────────────────────────────────────
GVL_IHM.WinchM1.PositionM                := PRG_2_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.WinchM1.SpeedRefPct              := PRG_6_WinchControl.instWinchM1.SpeedRamp.Current;
GVL_IHM.WinchM1.StepNumber               := PRG_6_WinchControl.instWinchM1.StepNumber;
GVL_IHM.WinchM1.FBState                  := PRG_6_WinchControl.instWinchM1.State;
GVL_IHM.WinchM1.Ready                    := PRG_6_WinchControl.instWinchM1.Ready;
GVL_IHM.WinchM1.Busy                     := PRG_6_WinchControl.instWinchM1.Busy;
GVL_IHM.WinchM1.Done                     := PRG_6_WinchControl.instWinchM1.Done;
GVL_IHM.WinchM1.Error                    := PRG_6_WinchControl.instWinchM1.Error;
GVL_IHM.WinchM1.ErrorId                  := PRG_6_WinchControl.instWinchM1.ErrorId;
GVL_IHM.WinchM1.RelayFwd                 := PRG_6_WinchControl.instWinchM1.RelayFwd;
GVL_IHM.WinchM1.RelayRev                 := PRG_6_WinchControl.instWinchM1.RelayRev;
GVL_IHM.WinchM1.Contactor1               := PRG_6_WinchControl.instWinchM1.Contactor1;
GVL_IHM.WinchM1.Contactor2               := PRG_6_WinchControl.instWinchM1.Contactor2;
GVL_IHM.WinchM1.Contactor3               := PRG_6_WinchControl.instWinchM1.Contactor3;
GVL_IHM.WinchM1.Contactor4               := PRG_6_WinchControl.instWinchM1.Contactor4;
GVL_IHM.WinchM1.BrakeCmd                 := PRG_6_WinchControl.instWinchM1.BrakeCmd;
GVL_IHM.WinchM1.Homed                    := PRG_2_Encoders.instHomingM1.Homed;
GVL_IHM.WinchM1.SafeStopActive           := PRG_3_Safety.instSafetyWinchM1.SafeStop;
GVL_IHM.WinchM1.ForbidDescentActive      := PRG_6_WinchControl.ForbidDescentM1_Active;
GVL_IHM.WinchM1.ForbidAscentActive       := PRG_3_Safety.instSafetyWinchM1.ForbidAscent;
GVL_IHM.WinchM1.SlackCableDetected       := NOT PRG_0_Inputs.SlackCableSwitch;
GVL_IHM.WinchM1.ThermalFault             := NOT PRG_0_Inputs.M1ThermalFeedback;
GVL_IHM.WinchM1.EncoderFault             := NOT PRG_2_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_2_Encoders.instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.WinchM1.CableLimitDescentReached := (PRG_3_Safety.instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.WinchM1.FwdContactorCheck        := PRG_6_WinchControl.instWinchM1.FwdContactorCheck;
GVL_IHM.WinchM1.RevContactorCheck        := PRG_6_WinchControl.instWinchM1.RevContactorCheck;
GVL_IHM.WinchM1.BrakeContactorCheck      := PRG_6_WinchControl.instWinchM1.BrakeContactorCheck;

GVL_IHM.WinchM1.Encoder.RawPos           := PRG_2_Encoders.instEncoderAbsM1.RawPos;
GVL_IHM.WinchM1.Encoder.Alarms           := PRG_2_Encoders.instEncoderAbsM1.AlarmsIn;
GVL_IHM.WinchM1.Encoder.Warnings         := PRG_2_Encoders.instEncoderAbsM1.WarningsIn;
GVL_IHM.WinchM1.Encoder.SlaveOperational := PRG_2_Encoders.instEncoderAbsM1.SlaveOperational;
GVL_IHM.WinchM1.Encoder.PresetTriggerCmd := PRG_2_Encoders.instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.WinchM1.Encoder.PresetValueOut   := PRG_2_Encoders.instEncoderAbsM1.PresetValueOut;


// ── 6. MAPPING ÉTATS TREUIL M2 → IHM ─────────────────────────────────────
GVL_IHM.WinchM2.PositionM                := PRG_2_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.WinchM2.SpeedRefPct              := PRG_6_WinchControl.instWinchM2.SpeedRamp.Current;
GVL_IHM.WinchM2.StepNumber               := PRG_6_WinchControl.instWinchM2.StepNumber;
GVL_IHM.WinchM2.FBState                  := PRG_6_WinchControl.instWinchM2.State;
GVL_IHM.WinchM2.Ready                    := PRG_6_WinchControl.instWinchM2.Ready;
GVL_IHM.WinchM2.Busy                     := PRG_6_WinchControl.instWinchM2.Busy;
GVL_IHM.WinchM2.Done                     := PRG_6_WinchControl.instWinchM2.Done;
GVL_IHM.WinchM2.Error                    := PRG_6_WinchControl.instWinchM2.Error;
GVL_IHM.WinchM2.ErrorId                  := PRG_6_WinchControl.instWinchM2.ErrorId;
GVL_IHM.WinchM2.RelayFwd                 := PRG_6_WinchControl.instWinchM2.RelayFwd;
GVL_IHM.WinchM2.RelayRev                 := PRG_6_WinchControl.instWinchM2.RelayRev;
GVL_IHM.WinchM2.Contactor1               := PRG_6_WinchControl.instWinchM2.Contactor1;
GVL_IHM.WinchM2.Contactor2               := PRG_6_WinchControl.instWinchM2.Contactor2;
GVL_IHM.WinchM2.Contactor3               := PRG_6_WinchControl.instWinchM2.Contactor3;
GVL_IHM.WinchM2.Contactor4               := PRG_6_WinchControl.instWinchM2.Contactor4;
GVL_IHM.WinchM2.BrakeCmd                 := PRG_6_WinchControl.instWinchM2.BrakeCmd;
GVL_IHM.WinchM2.Homed                    := PRG_2_Encoders.instHomingM2.Homed;
GVL_IHM.WinchM2.SafeStopActive           := PRG_3_Safety.instSafetyWinchM2.SafeStop;
GVL_IHM.WinchM2.ForbidDescentActive      := PRG_6_WinchControl.ForbidDescentM2_Active;
GVL_IHM.WinchM2.ForbidAscentActive       := PRG_3_Safety.instSafetyWinchM2.ForbidAscent;
GVL_IHM.WinchM2.SlackCableDetected       := NOT PRG_0_Inputs.SlackCableSwitch;
GVL_IHM.WinchM2.ThermalFault             := NOT PRG_0_Inputs.M2ThermalFeedback;
GVL_IHM.WinchM2.EncoderFault             := NOT PRG_2_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_2_Encoders.instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.WinchM2.CableLimitDescentReached := (PRG_3_Safety.instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.WinchM2.FwdContactorCheck        := PRG_6_WinchControl.instWinchM2.FwdContactorCheck;
GVL_IHM.WinchM2.RevContactorCheck        := PRG_6_WinchControl.instWinchM2.RevContactorCheck;
GVL_IHM.WinchM2.BrakeContactorCheck      := PRG_6_WinchControl.instWinchM2.BrakeContactorCheck;

GVL_IHM.WinchM2.Encoder.RawPos           := PRG_2_Encoders.instEncoderAbsM2.RawPos;
GVL_IHM.WinchM2.Encoder.Alarms           := PRG_2_Encoders.instEncoderAbsM2.AlarmsIn;
GVL_IHM.WinchM2.Encoder.Warnings         := PRG_2_Encoders.instEncoderAbsM2.WarningsIn;
GVL_IHM.WinchM2.Encoder.SlaveOperational := PRG_2_Encoders.instEncoderAbsM2.SlaveOperational;
GVL_IHM.WinchM2.Encoder.PresetTriggerCmd := PRG_2_Encoders.instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.WinchM2.Encoder.PresetValueOut   := PRG_2_Encoders.instEncoderAbsM2.PresetValueOut;


// ── 7. MAPPING ÉTATS GRAPPIN → IHM ───────────────────────────────────────
GVL_IHM.Grappin.FBState          := PRG_6_WinchControl.instGrappin.State;
GVL_IHM.Grappin.ActiveOffsetM    := PRG_6_WinchControl.instGrappin.ActiveOffsetM;
GVL_IHM.Grappin.M2StartStop      := PRG_6_WinchControl.instGrappin.M2_StartStop;
GVL_IHM.Grappin.M2Direction      := PRG_6_WinchControl.instGrappin.M2_Direction;
GVL_IHM.Grappin.M2ForceSlowSpeed := PRG_6_WinchControl.instGrappin.M2_ForceSlowSpeed;
GVL_IHM.Grappin.Ready            := PRG_6_WinchControl.instGrappin.Ready;
GVL_IHM.Grappin.Busy             := PRG_6_WinchControl.instGrappin.Busy;
GVL_IHM.Grappin.Done             := PRG_6_WinchControl.instGrappin.Done;
GVL_IHM.Grappin.Error            := PRG_6_WinchControl.instGrappin.Error;
GVL_IHM.Grappin.ErrorId          := PRG_6_WinchControl.instGrappin.ErrorId;
GVL_IHM.Grappin.State            := GVL_PERSISTENT.GrappinState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.Sync.DeltaPosM  := PRG_6_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Sync.SyncActive := PRG_6_WinchControl.instWinchSync.SyncActive;
GVL_IHM.Sync.SyncWarn   := PRG_6_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.Sync.Ready      := PRG_6_WinchControl.instWinchSync.Ready;
GVL_IHM.Sync.Error      := PRG_6_WinchControl.instWinchSync.Error;
GVL_IHM.Sync.ErrorId    := PRG_6_WinchControl.instWinchSync.ErrorId;
GVL_IHM.Sync.State      := PRG_6_WinchControl.instWinchSync.State;


// ── 9. MAPPING ÉTATS CHARIOT M3 → IHM ────────────────────────────────────
GVL_IHM.Chariot.FBState              := PRG_7_ChariotControl.instChariotM3.State;
GVL_IHM.Chariot.Ready                := PRG_7_ChariotControl.instChariotM3.Ready;
GVL_IHM.Chariot.Busy                 := PRG_7_ChariotControl.instChariotM3.Busy;
GVL_IHM.Chariot.Done                 := PRG_7_ChariotControl.instChariotM3.Done;
GVL_IHM.Chariot.Error                := PRG_7_ChariotControl.instChariotM3.Error;
GVL_IHM.Chariot.ErrorId              := PRG_7_ChariotControl.instChariotM3.ErrorId;
GVL_IHM.Chariot.RelayFwd             := PRG_7_ChariotControl.instChariotM3.RelayFwd;
GVL_IHM.Chariot.RelayRev             := PRG_7_ChariotControl.instChariotM3.RelayRev;
GVL_IHM.Chariot.RelaySpeedGv         := PRG_7_ChariotControl.instChariotM3.RelaySpeedGv;
GVL_IHM.Chariot.BrakeCmd             := PRG_7_ChariotControl.instChariotM3.BrakeCmd;
GVL_IHM.Chariot.BrakeFeedback        := PRG_0_Inputs.M3BrakeFeedback;
GVL_IHM.Chariot.PositionSensorTarget := PRG_7_ChariotControl.M3_PositionSensorTarget;
GVL_IHM.Chariot.DriveStatusWord      := PRG_7_ChariotControl.instChariotM3.DriveStatusWord;
GVL_IHM.Chariot.DriveActualFreqHz    := PRG_7_ChariotControl.instChariotM3.DriveActualFreqHz;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.Joystick.RawX       := JoyXRaw_ANA1;
GVL_IHM.Joystick.RawY       := JoyYRaw_ANA2;
GVL_IHM.Joystick.RawButton  := JoyBtnRaw;
GVL_IHM.Joystick.CmdX       := PRG_1_Diagnostics.FB_Joystick_0.AxisCmdX;
GVL_IHM.Joystick.CmdY       := PRG_1_Diagnostics.FB_Joystick_0.AxisCmdY;
GVL_IHM.Joystick.Online     := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Online;
GVL_IHM.Joystick.Operational := PRG_1_Diagnostics.instDiagCanOpen.Joystick.Operational;


// ── 11. MAPPING SYSTEM / MODE → IHM ──────────────────────────────────────
GVL_IHM.Modes.CurrentMode     := PRG_4_Modes.instModes.Mode;
GVL_IHM.Modes.EmergencyStopOk := PRG_0_Inputs.EmergencyStopOk;


// ── 12. MAPPING DIAGNOSTICS BUS → IHM ────────────────────────────────────
GVL_IHM.Network.BusCanOpen  := PRG_1_Diagnostics.instDiagCanOpen.busCanOpen;
GVL_IHM.Network.Joystick    := PRG_1_Diagnostics.instDiagCanOpen.Joystick;
GVL_IHM.Network.CanError    := PRG_1_Diagnostics.instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := PRG_1_Diagnostics.instDiagCanOpen.ErrorId;

GVL_IHM.Network.BusEthercat := PRG_1_Diagnostics.instDiagEthercat.BusEthercat;
GVL_IHM.Network.EncoderM1   := PRG_1_Diagnostics.instDiagEthercat.EncoderM1;
GVL_IHM.Network.EncoderM2   := PRG_1_Diagnostics.instDiagEthercat.EncoderM2;
GVL_IHM.Network.VariateurM3 := PRG_1_Diagnostics.instDiagEthercat.Variateur;
GVL_IHM.Network.EcatError   := PRG_1_Diagnostics.instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := PRG_1_Diagnostics.instDiagEthercat.ErrorId;
