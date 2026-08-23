(* =======================================================================
   🧱 FB_Main_EndToEnd : Mega-Bloc d'Integration Chaine Totale E2E
   ───────────────────────────────────────────────────────────────
   🎯 Role : Reunit toute la cascade des composants metier en une seule boucle :
             Joystick -> Modes -> Winch/Safety -> Outputs -> SimBench
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Main_EndToEnd
VAR_INPUT
    Enable                : BOOL := TRUE;
    Reset                 : BOOL;
    
    // 🕹️ Joystick In
    JoyRawX               : INT := 5000;
    JoyRawY               : INT := 5000;
    JoyDeadman            : BOOL;
    
    // 🛡️ Securite Machine
    EmergencyChainClosed  : BOOL := TRUE;
    PowerContactorEngaged : BOOL := TRUE;
    
    // 🧭 Selection Mode
    SelMode               : E_Mode := E_Mode.MAINT_N1;
    SelJoystickWinch      : INT := 1; // 1 = M1, 2 = M2, 0 = Both
    
    // 📏 Mesures positions actuelles treuils
    M1_Position_M         : REAL := 2.0;
    M2_Position_M         : REAL := 2.0;
    M3_SensorsWord        : WORD := 16#07;
END_VAR

VAR_OUTPUT
    // 🚦 Etats Globaux
    Ready                 : BOOL;
    DeadmanArmed          : BOOL;
    CurrentMode           : E_Mode;
    
    // ⚡ Sorties Actionneurs Treuil M1
    M1_RelayFwd           : BOOL;
    M1_RelayRev           : BOOL;
    M1_BrakeCmd           : BOOL;
    M1_SpeedContactor1    : BOOL;
    M1_SpeedContactor2    : BOOL;
    M1_SpeedRefPct        : REAL;
    
    // ⚡ Sorties Actionneurs Treuil M2
    M2_RelayFwd           : BOOL;
    M2_RelayRev           : BOOL;
    M2_BrakeCmd           : BOOL;
    M2_SpeedContactor1    : BOOL;
    M2_SpeedRefPct        : REAL;
    
    // ↔️ Sorties Variateur Translation M3
    M3_DriveControlWord   : WORD;
    M3_DriveFreqRefWord   : WORD;
    M3_BrakeCmd           : BOOL;
    
    // 🚨 Securite
    PowerCutOffActive     : BOOL;
    SafeStopActive        : BOOL;
END_VAR

VAR
    // 🧩 Instances internes constituant le Mega-Bloc
    instJoystick          : FB_Joystick;
    instModes             : FB_Modes;
    instSafetyWinchM1     : FB_Safety_Winch;
    instSafetyWinchM2     : FB_Safety_Winch;
    instWinchM1           : FB_Winch;
    instWinchM2           : FB_Winch;
    instWinchOutputM1     : FB_WinchOutputInterlock;
    instWinchOutputM2     : FB_WinchOutputInterlock;
    instSafetyTrans       : FB_Safety_Translation;
    instTrans             : FB_Translation;
    instTransOutput       : FB_TranslationOutputInterlock;
    
    // Structures de liaison internes
    diagCanOk             : ST_Diag_Device;
    winchM1Safety         : ST_SafetyWinch;
    winchM2Safety         : ST_SafetyWinch;
    transSafety           : ST_SafetyTranslation;
    modesAuth             : ST_Modes_Autorisations;
    winchSpeedCfg         : ST_WinchSpeedConfig;
END_VAR

{region "Execution Mega-Bloc"}
IF NOT Enable THEN
    Ready := FALSE;
    M1_RelayFwd := FALSE;
    M1_RelayRev := FALSE;
    M1_BrakeCmd := FALSE;
    M2_RelayFwd := FALSE;
    M2_RelayRev := FALSE;
    M2_BrakeCmd := FALSE;
    M3_DriveControlWord := 0;
    M3_DriveFreqRefWord := 0;
    M3_BrakeCmd := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
diagCanOk.Online := TRUE;
diagCanOk.Operational := TRUE;
diagCanOk.State := E_Diag_State.READY;

// 1. Acquisition Joystick
instJoystick(
    Enable := TRUE,
    Reset := Reset,
    ArmingPermit := TRUE,
    BusCanOpenOp := diagCanOk,
    JoystickOp := diagCanOk,
    RawX := JoyRawX,
    RawY := JoyRawY,
    RawButton := JoyDeadman,
    NeutralHoldTime := T#50ms,
    DeadmanArmHoldTime := T#50ms,
    DeadmanArmGraceTime := T#3s,
    DeadbandRaw := 300,
    NeutralXMem := 5000,
    NeutralYMem := 5000
);
DeadmanArmed := instJoystick.DeadmanArmed;

// 2. Modes & Autorisations
instModes(
    Enable := TRUE,
    Reset := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    SelMode := SelMode,
    SelSyncEnable := FALSE,
    InhibitM1Request := FALSE,
    InhibitM2Request := FALSE,
    SelHomingApproachEnable := FALSE,
    EncoderFaultPresent := FALSE,
    JoystickWinchSelectRequest := SelJoystickWinch,
    SelMaintenanceZoneAccess := FALSE
);
modesAuth := instModes.Autorisations;
CurrentMode := modesAuth.Mode;

// 3. Securite Treuil M1
instSafetyWinchM1(
    Enable := modesAuth.M1_ManualPermit,
    Reset := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    ActualPosition_M := M1_Position_M,
    MeasuredSpeed_Mps := 0.0,
    CableLimitAscent_M := 8.0,
    CableLimitDescent_M := -20.0,
    SlowdownDistance_M := 1.0,
    SlackCablePresent := FALSE,
    TopLimitSwitchOpen := FALSE,
    ContactorWelded := FALSE,
    ContactorCutOffFailed := FALSE,
    ThermalFault := FALSE,
    BrakeThermalFault := FALSE,
    BrakeFailedToOpen := FALSE,
    BrakeFailedToClose := FALSE,
    BrakeSwitchFault := FALSE,
    EncoderFault := FALSE,
    SpeedMismatchThresholdMps := 0.0,
    SpeedMismatchTimeout := T#0ms,
    IsBottomActive := FALSE,
    BottomSlowdownDistance_M := 1.0
);
winchM1Safety := instSafetyWinchM1.Safety;

// 4. Commande Treuil M1
instWinchM1(
    Enable := modesAuth.M1_ManualPermit,
    Reset := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    SafeStop := winchM1Safety.SafeStop,
    StartStop := instJoystick.DeadmanArmed AND (instJoystick.DirectionY <> 0) AND (SelJoystickWinch = 1 OR SelJoystickWinch = 0),
    Direction := instJoystick.DirectionY,
    SpeedRef := instJoystick.AxisCmdY.SpeedRef,
    SafetyDescendPermit := winchM1Safety.DescendPermit,
    SafetyAscentPermit := winchM1Safety.AscentPermit,
    ActualPosition_M := M1_Position_M,
    MeasuredSpeed_Mps := 0.0,
    MaxStepAscent := winchM1Safety.MaxAllowedStepAscent,
    MaxStepDescent := winchM1Safety.MaxAllowedStepDescent,
    MaxAllowedStepSlowdown := 1,
    InSlowdownZoneAscent := FALSE,
    InSlowdownZoneDescent := FALSE,
    SlowdownMaxStep := 1,
    ThermalFault := FALSE,
    BrakeThermalFault := FALSE,
    BrakeFeedbackOpen := M1_BrakeCmd,
    AllContactorsReleasedFeedback := NOT (M1_RelayFwd OR M1_RelayRev),
    SpeedConfig := winchSpeedCfg
);

// 5. Barriere Sorties Treuil M1 (Outputs Interlock)
instWinchOutputM1(
    Enable := TRUE,
    PowerCutOff := winchM1Safety.PowerCutOff,
    SafeStop := winchM1Safety.SafeStop,
    AllContactorsReleasedFeedback := NOT (M1_RelayFwd OR M1_RelayRev),
    InRelayFwd := instWinchM1.RelayFwd,
    InRelayRev := instWinchM1.RelayRev,
    InSpeedContactor1 := instWinchM1.SpeedContactor1,
    InSpeedContactor2 := instWinchM1.SpeedContactor2,
    InSpeedContactor3 := instWinchM1.SpeedContactor3,
    InSpeedContactor4 := instWinchM1.SpeedContactor4,
    InBrakeCmd := instWinchM1.BrakeCmd
);

M1_RelayFwd := instWinchOutputM1.OutRelayFwd;
M1_RelayRev := instWinchOutputM1.OutRelayRev;
M1_BrakeCmd := instWinchOutputM1.OutBrakeCmd;
M1_SpeedContactor1 := instWinchOutputM1.OutSpeedContactor1;
M1_SpeedContactor2 := instWinchOutputM1.OutSpeedContactor2;
M1_SpeedRefPct := instWinchM1.SpeedRef_Pct;

// 6. Securite Translation M3
instSafetyTrans(
    Enable := modesAuth.TranslationManualPermit,
    Reset := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    ThermalFault := FALSE,
    BrakeThermalFault := FALSE,
    BrakeFailedToOpen := FALSE,
    BrakeFailedToClose := FALSE,
    BrakeSwitchFault := FALSE,
    DriveFault := FALSE,
    DriveCommFault := FALSE,
    OverFrequencyFault := FALSE,
    PositionSensorsIncoherent := FALSE,
    LimitSwitchFwdActive := FALSE,
    LimitSwitchRevActive := FALSE,
    M1_Position_M := M1_Position_M,
    M2_Position_M := M2_Position_M,
    MinHeightM1M2_M := 6.0
);
transSafety := instSafetyTrans.Safety;

// 7. Commande Translation M3
instTrans(
    Enable := modesAuth.TranslationManualPermit,
    Reset := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    SafeStop := transSafety.SafeStop,
    StartStop := instJoystick.DeadmanArmed AND (instJoystick.DirectionX <> 0),
    Direction := instJoystick.DirectionX,
    SpeedRef := instJoystick.AxisCmdX.SpeedRef,
    SafetyFwdPermit := transSafety.FwdPermit,
    SafetyRevPermit := transSafety.RevPermit,
    ThermalFault := FALSE,
    BrakeThermalFault := FALSE,
    BrakeFeedbackOpen := M3_BrakeCmd,
    DriveFault := FALSE,
    DriveReady := TRUE
);

// 8. Barriere Sorties Translation M3
instTransOutput(
    Enable := TRUE,
    PowerCutOff := transSafety.PowerCutOff,
    SafeStop := transSafety.SafeStop,
    InDriveControlWord := instTrans.DriveControlWord,
    InDriveFreqRefWord := instTrans.DriveFreqRefWord,
    InBrakeCmd := instTrans.BrakeCmd
);

M3_DriveControlWord := instTransOutput.OutDriveControlWord;
M3_DriveFreqRefWord := instTransOutput.OutDriveFreqRefWord;
M3_BrakeCmd := instTransOutput.OutBrakeCmd;

PowerCutOffActive := winchM1Safety.PowerCutOff OR transSafety.PowerCutOff;
SafeStopActive := winchM1Safety.SafeStop OR transSafety.SafeStop;
{endregion}
END_FUNCTION_BLOCK
