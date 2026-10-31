(* T417 D2 — boucle fermee de preuve, composants de production composes dans l'ordre PRG02→PRG03/05→PRG06.
   Le cycle utilise ses entrees publiques. StepForceTgt ne sert qu'a fixer le point de depart AX14;
   les gestes, les transitions AX15A/B/C/18/2 et les demandes M3 restent emis par les vrais FB.
   M1/M2, benne, mode arbitre, IHM, reseaux et AU sont des faits de banc declares, pas couverts ici. *)
FUNCTION_BLOCK PUBLIC FB_TestHarnessT417_M3
VAR_INPUT
    Enable                  : BOOL;
    StepForceTgt            : INT := -1;
    JoystickLeft            : BOOL;
    JoystickRight           : BOOL;
    JoystickPush            : BOOL;
    JoystickPull            : BOOL;
    RepositionRequest       : BOOL;
    BenneDone               : BOOL;
    BenneIsOpen             : BOOL;
    SimM3Slope_Mps2         : REAL;
END_VAR
VAR_IN_OUT
    RawPosM1                : UDINT;
    RawPosM2                : UDINT;
END_VAR
VAR_OUTPUT
    CycleStep               : E_AutoCycleStep;
    CycleError              : BOOL;
    CycleReqStart            : BOOL;
    CyclePositionTgt          : INT;
    ArbitrationReqTremie      : BOOL;
    ArbitrationReqMaintenance : BOOL;
    ArbitrationRunRequest     : BOOL;
    TranslationSafetyError  : BOOL;
    TranslationMotionError  : BOOL;
    FinalInterlockError     : BOOL;
    M3ReqTremie              : BOOL;
    M3ReqMaintenance         : BOOL;
    M3DriveControlWord       : WORD;
    M3DriveFreqCmd_Hz        : REAL;
    M3DriveActualFreq_Hz     : REAL;
    M3BrakeReleaseRequest    : BOOL;
    M3BrakeFinalCmd          : BOOL;
    M3BrakeContactOpen       : BOOL;
    M3SensorsWord            : BYTE;
    M3AtTremie               : BOOL;
    M3AtP1                   : BOOL;
    M3PositionTrue_M         : REAL;
    M3PositionEstimated_M    : REAL;
    M3PositionError_M        : REAL;
    M3OvershootLast_M        : REAL;
    M3OvershootSensorId      : INT;
    P1ArrivalCaptured        : BOOL;
    P1ArrivalPosition_M       : REAL;
    P1ArrivalSensorsWord      : BYTE;
    P1ArrivalDriveControlWord : WORD;
    P1ArrivalFrequency_Hz     : REAL;
    P1ArrivalBrakeOpen        : BOOL;
    M3CartFree               : BOOL;
    M3FreeRollLast_M         : REAL;
END_VAR
VAR
    instCycle                : FB_CycleSemiAuto;
    instArbitration          : FB_TranslationCmdArbitrationM3;
    instSafety               : FB_Safety_Translation;
    instTranslation          : FB_Translation;
    instOutputInterlock      : FB_TranslationOutputInterlock;
    instPositionDecoder      : FB_Translation_PositionDecoder;
    instPositionEstimator    : FB_Translation_PositionEstimator;
    instSimBench             : FB_SimBench;
    TranslationCfg           : ST_fbTranslation_Cfg;
    Joystick                 : ST_AcquisitionJoystickQualified;
    ModesAuth                : ST_Modes_Autorisations;
    CycleTranslationRequest  : ST_ProgramTranslationRequest;
    ArbitrationIHM           : ST_fbTranslationCmdArbitration_IHM;
    ArbitrationContext       : ST_fbTranslationCmdArbitration_Context;
    ArbitrationCfg           : ST_fbTranslationCmdArbitration_Cfg;
    TargetCodeSel            : INT;
    SensorsWordPrev          : BYTE;
    SensorsWordChanged       : BOOL;
    PositionSensorTarget     : BOOL;
    AtTremieStable           : BOOL;
    AtPVStable               : BOOL;
    AtP2Stable               : BOOL;
    AtP1Stable               : BOOL;
    AtMaintenanceStable      : BOOL;
    AtPositionBootRestored   : BOOL;
    BootSensorsStable        : TON;
    SimReqTremieN1           : BOOL;
    SimReqMaintenanceN1      : BOOL;
    SimSpeedPctN1            : REAL;
    SimBrakeCmdN1            : BOOL;
    M3HeightInterlockOk      : BOOL;
    PermitTremie             : BOOL;
    PermitMaintenance        : BOOL;
    P1ArrivalCapturedLocal    : BOOL;
END_VAR

IF NOT Enable THEN
    CycleStep := E_AutoCycleStep.AX0_REPOS;
    RETURN;
END_IF;

(* La simulation est PRG02 : elle consomme les sorties finales mémorisées du scan N-1. *)
instSimBench(
    Enable := TRUE,
    OperatorSourceActive := TRUE,
    M3_ReqTremie := SimReqTremieN1,
    M3_ReqMaintenance := SimReqMaintenanceN1,
    M3_SpeedCmd_Pct := SimSpeedPctN1,
    M3_PosTremie_M := 0.0,
    M3_PosPV_M := 1.5,
    M3_PosP2_M := 3.5,
    M3_PosP1_M := 5.0,
    M3_PosMaintenance_M := 10.0,
    M3_OdometryGain := 0.02,
    M3_EstimatedPos_M := instPositionEstimator.PositionEstimatedM,
    M3_BrakeCmd := SimBrakeCmdN1,
    PowerKeepAlive_A := TRUE,
    PowerKeepAlive_B := TRUE,
    SimChainOkBit := TRUE,
    SimPhaseRotationOkBit := TRUE,
    SimM3SpeedFactor := 1.0,
    SimM3SensorIntermittenceActive := FALSE,
    SimM3SensorCamDropoutActive := FALSE,
    SimM3BrakePhysicalActive := TRUE,
    SimM3CartFreeActive := TRUE,
    SimM3LoadMassRatio := 0.5,
    SimM3RollingFriction_Mps2 := 0.1,
    SimM3Slope_Mps2 := SimM3Slope_Mps2,
    RawPosM1 := RawPosM1,
    RawPosM2 := RawPosM2
);

instPositionDecoder(
    SensorTremie := instSimBench.Translation.M3_PosTremie_DI,
    SensorPV := instSimBench.Translation.M3_PosPV_DI,
    SensorP2 := instSimBench.Translation.M3_PosPVP2_DI,
    SensorP1 := instSimBench.Translation.M3_PosP1_DI,
    SensorMaintenance := instSimBench.Translation.M3_PosMaintenance_DI
);

instPositionEstimator(
    Enable := TRUE,
    Reset := FALSE,
    DriveActualFreqHz := UINT_TO_REAL(instSimBench.Translation.M3_ActualFrequencyHz) / 100.0,
    ReqTremie := SimReqTremieN1,
    ReqMaintenance := SimReqMaintenanceN1,
    SensorMaintenance := instPositionDecoder.TranslationPosMaintenance,
    SensorP1 := instPositionDecoder.TranslationPosP1,
    SensorP2 := instPositionDecoder.TranslationPosP2,
    SensorPV := instPositionDecoder.TranslationPosPV,
    SensorTremie := instPositionDecoder.TranslationPosTremie,
    PosMaintenanceM := 10.0,
    PosP1M := 5.0,
    PosP2M := 3.5,
    PosPVM := 1.5,
    PosTremieM := 0.0,
    GainMetersPerHzSec := 0.02,
    PersistedPositionM := 0.0,
    PersistedInitialized := FALSE
);

SensorsWordChanged := instPositionDecoder.SensorsWord <> SensorsWordPrev;
BootSensorsStable(IN := NOT SimReqTremieN1 AND NOT SimReqMaintenanceN1, PT := T#500ms);
IF NOT AtPositionBootRestored AND BootSensorsStable.Q THEN
    CASE instPositionDecoder.SensorsWord OF
        2#11111: AtTremieStable := instPositionDecoder.TranslationPosTremie;
        2#01111: AtPVStable := instPositionDecoder.TranslationPosPV;
        2#00111: AtP2Stable := instPositionDecoder.TranslationPosP2;
        2#00011: AtP1Stable := instPositionDecoder.TranslationPosP1;
        2#00000: AtMaintenanceStable := instPositionDecoder.TranslationPosMaintenance;
    END_CASE;
    AtPositionBootRestored := TRUE;
ELSIF AtPositionBootRestored THEN
    IF instPositionDecoder.TranslationAtTremie THEN
        AtTremieStable := TRUE; AtPVStable := FALSE; AtP2Stable := FALSE; AtP1Stable := FALSE; AtMaintenanceStable := FALSE;
    ELSIF instPositionDecoder.TranslationAtPV THEN
        AtPVStable := TRUE; AtTremieStable := FALSE; AtP2Stable := FALSE; AtP1Stable := FALSE; AtMaintenanceStable := FALSE;
    ELSIF instPositionDecoder.TranslationAtP2 THEN
        AtP2Stable := TRUE; AtTremieStable := FALSE; AtPVStable := FALSE; AtP1Stable := FALSE; AtMaintenanceStable := FALSE;
    ELSIF instPositionDecoder.TranslationAtP1 THEN
        AtP1Stable := TRUE; AtTremieStable := FALSE; AtPVStable := FALSE; AtP2Stable := FALSE; AtMaintenanceStable := FALSE;
    ELSIF instPositionDecoder.TranslationAtMaintenance THEN
        AtMaintenanceStable := TRUE; AtTremieStable := FALSE; AtPVStable := FALSE; AtP2Stable := FALSE; AtP1Stable := FALSE;
    ELSIF SensorsWordChanged THEN
        AtPVStable := FALSE; AtP2Stable := FALSE; AtP1Stable := FALSE;
    END_IF;
    IF SimReqMaintenanceN1 THEN AtTremieStable := FALSE; END_IF;
    IF SimReqTremieN1 THEN AtMaintenanceStable := FALSE; END_IF;
END_IF;
SensorsWordPrev := instPositionDecoder.SensorsWord;

Joystick.AxisX.Enable := TRUE;
Joystick.AxisX.StartStop := JoystickLeft OR JoystickRight;
Joystick.AxisX.DirectionPositive := JoystickLeft;
Joystick.AxisX.DirectionNegative := JoystickRight;
Joystick.AxisX.AtNeutral := NOT JoystickLeft AND NOT JoystickRight;
Joystick.AxisX.Direction := SEL(JoystickLeft, SEL(JoystickRight, 0, -1), 1);
Joystick.AxisX.SpeedTgt := 100.0;
Joystick.AxisY.Enable := TRUE;
Joystick.AxisY.StartStop := JoystickPush OR JoystickPull;
Joystick.AxisY.DirectionPositive := JoystickPush;
Joystick.AxisY.DirectionNegative := JoystickPull;
Joystick.AxisY.AtNeutral := NOT JoystickPush AND NOT JoystickPull;
Joystick.AxisY.Direction := SEL(JoystickPush, SEL(JoystickPull, 0, -1), 1);
Joystick.AxisY.SpeedTgt := 100.0;
Joystick.DeadmanArmed := TRUE;
Joystick.AtNeutralXY := Joystick.AxisX.AtNeutral AND Joystick.AxisY.AtNeutral;
Joystick.Ready := TRUE;
ModesAuth.Mode := E_Mode.SEMI_AUTO;
ModesAuth.MaintenanceM3TargetEnable := FALSE;
M3HeightInterlockOk := TRUE; (* entree de banc declaree : M1/M2 au-dessus du seuil de PRG05 *)

instCycle(
    Enable := TRUE,
    PowerContactorEngaged := TRUE,
    EncoderFaultPresent := FALSE,
    Mode := E_Mode.SEMI_AUTO,
    JoystickDeflected := JoystickLeft OR JoystickRight OR JoystickPush OR JoystickPull,
    JoystickPush := JoystickPush,
    JoystickPull := JoystickPull,
    JoystickRight := JoystickRight,
    JoystickLeft := JoystickLeft,
    DeadmanArmed := TRUE,
    HeartbeatIhmOk := TRUE,
    SelTarget := 0,
    SetDepthM := -5.0,
    DepthStopMode := E_CycleDepthStopMode.KOBOLD_ONLY,
    WinchSyncError := FALSE,
    WinchSyncDeltaM := 0.0,
    M1_CablePosM := 5.0,
    M2_CablePosM := 5.0,
    M1_MeasuredSpeedMps := 0.0,
    M2_MeasuredSpeedMps := 0.0,
    M1_SpeedValid := TRUE,
    M2_SpeedValid := TRUE,
    M1_ContactorsReleased := TRUE,
    M2_ContactorsReleased := TRUE,
    M1_BrakeApplied := TRUE,
    M2_BrakeApplied := TRUE,
    SpeedMismatchThresholdMps := 0.0,
    SpeedMismatchTimeout := T#0ms,
    M1TopLimitReached := TRUE,
    M2TopLimitReached := TRUE,
    Translation_At_P1 := AtP1Stable,
    Translation_At_Tremie := AtTremieStable,
    Translation_At_Maintenance := AtMaintenanceStable,
    Translation_PosP1 := instPositionDecoder.TranslationPosP1,
    Translation_PosMaintenance := instPositionDecoder.TranslationPosMaintenance,
    Translation_Busy := ABS(instTranslation.RequestedDriveFreqHz) > 0.1,
    Translation_Done := instTranslation.TargetReached,
    Benne_Done := BenneDone,
    Benne_CloseReached := NOT BenneIsOpen,
    Benne_IsOpen := BenneIsOpen,
    Benne_IsClosed := NOT BenneIsOpen,
    Benne_IsRoughlyClosed := NOT BenneIsOpen,
    M1FinalAscentStartReady := TRUE,
    HomedM1 := TRUE,
    HomedM2 := TRUE,
    InitPositionOk := TRUE,
    WinchesAtTopWindow := TRUE,
    CfgDrainTime := T#0ms,
    RepositionRequest := RepositionRequest,
    StepForceTgt := StepForceTgt
);
CycleStep := instCycle.CycleStep;
CycleError := instCycle.Fault.Error;
CycleTranslationRequest := instCycle.TranslationCmd;
CycleReqStart := CycleTranslationRequest.ReqStart;
CyclePositionTgt := CycleTranslationRequest.PositionTgt;

ArbitrationContext.HeightInterlockOk := M3HeightInterlockOk;
ArbitrationCfg.MaxFreq_Hz := 50.0;
instArbitration(
    Enable := TRUE,
    Joystick := Joystick,
    Auth := ModesAuth,
    ReqTranslation := CycleTranslationRequest,
    IHM := ArbitrationIHM,
    TglJoystickMaster := FALSE,
    Context := ArbitrationContext,
    Cfg := ArbitrationCfg
);
ArbitrationReqTremie := instArbitration.ReqTremie;
ArbitrationReqMaintenance := instArbitration.ReqMaintenance;
ArbitrationRunRequest := instArbitration.RunRequest;
(* Le selecteur de cible est consommable au scan courant : retenir la derniere valeur non nulle. *)
IF instArbitration.SelTarget >= 1 AND instArbitration.SelTarget <= 4 THEN
    TargetCodeSel := instArbitration.SelTarget;
END_IF;
IF instArbitration.SelTarget = 0 THEN
    IF instArbitration.ReqTremie THEN
        TargetCodeSel := 1;
    ELSIF instArbitration.ReqMaintenance THEN
        TargetCodeSel := SEL(ModesAuth.MaintenanceM3TargetEnable, 3, 4);
    END_IF;
END_IF;
PositionSensorTarget := FALSE;
CASE TargetCodeSel OF
    1: PositionSensorTarget := AtTremieStable;
    2: PositionSensorTarget := AtP2Stable;
    3: PositionSensorTarget := AtP1Stable;
    4: PositionSensorTarget := AtMaintenanceStable;
END_CASE;

instSafety(
    Enable := TRUE,
    Reset := FALSE,
    PowerContactorEngaged := TRUE,
    Mode := E_Mode.SEMI_AUTO,
    JoystickOnline := TRUE,
    JoystickOperational := TRUE,
    HeartbeatIhmOk := TRUE,
    PhaseRotationOk := TRUE,
    BrakeThermalFeedback := FALSE,
    DriveOnline := TRUE,
    DriveOperational := TRUE,
    DriveStatusWord := instSimBench.Translation.M3_StatusWord,
    DriveActualFreqHz := UINT_TO_REAL(instSimBench.Translation.M3_ActualFrequencyHz) / 100.0,
    BrakeFeedback := instSimBench.Translation.M3_BrakeIsOpen_DI,
    BrakeCmd := instTranslation.BrakeReleaseRequest,
    RunRequest := instArbitration.RunRequest,
    ReqTremie := instArbitration.ReqTremie,
    ReqMaintenance := instArbitration.ReqMaintenance,
    LimitSwitchTremie := instPositionDecoder.LimitSwitchTremie,
    LimitSwitchMaintenance := instPositionDecoder.LimitSwitchMaintenance,
    SensorWordIncoherent := instPositionDecoder.Incoherent
);
PermitTremie := instSafety.TremieLimitClear AND NOT instSafety.SafeStop AND NOT instSafety.PowerCutOff;
PermitMaintenance := instSafety.MaintenanceLimitClear AND NOT instSafety.SafeStop AND NOT instSafety.PowerCutOff;

TranslationCfg.CfgRampAccelRate := 40.0;
TranslationCfg.CfgRampDecelNormalRate := 50.0;
TranslationCfg.CfgRampDecelFastRate := 100.0;
TranslationCfg.DriveFreqScaleMaxHz := 50.0;
TranslationCfg.ApproachSpeedTremieHz := 20.0;
TranslationCfg.ApproachSpeedMaintenanceHz := 20.0;
TranslationCfg.ApproachSpeedP1Hz := 20.0;
instTranslation(
    Enable := TRUE,
    Reset := FALSE,
    PowerContactorEngaged := TRUE,
    Mode := E_Mode.SEMI_AUTO,
    RunRequest := instArbitration.RunRequest,
    SafeStop := instSafety.SafeStop,
    ReqTremie := instArbitration.ReqTremie,
    ReqMaintenance := instArbitration.ReqMaintenance,
    SpeedTgt_Pct := instArbitration.SpeedPct,
    PositionSensorTarget := PositionSensorTarget,
    SlowdownSensorTremie := instPositionDecoder.TranslationPosPV,
    SlowdownSensorMaintenance := instPositionDecoder.TranslationPosP1,
    SlowdownSensorP1 := (NOT instPositionDecoder.TranslationPosP2) AND instPositionDecoder.TranslationPosP1,
    LimitSwitchTremie := instPositionDecoder.LimitSwitchTremie,
    LimitSwitchMaintenance := instPositionDecoder.LimitSwitchMaintenance,
    EffectivePermitM3_Tremie := PermitTremie,
    EffectivePermitM3_Maintenance := PermitMaintenance,
    DriveStatusWord := instSimBench.Translation.M3_StatusWord,
    DriveActualFreqHz := UINT_TO_REAL(instSimBench.Translation.M3_ActualFrequencyHz) / 100.0,
    BrakeFeedback := instSimBench.Translation.M3_BrakeIsOpen_DI,
    Cfg := TranslationCfg
);

instOutputInterlock(
    Enable := TRUE,
    Reset := FALSE,
    SafeStop := instSafety.SafeStop,
    PowerContactorEngaged := TRUE,
    EffectivePermitM3_Tremie := PermitTremie,
    EffectivePermitM3_Maintenance := PermitMaintenance,
    BrakeReleaseRequest := instTranslation.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := instTranslation.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord := instTranslation.RequestedDriveControlWord,
    RequestedDriveFreqHz := instTranslation.RequestedDriveFreqHz
);

SimReqTremieN1 := instOutputInterlock.DriveControlWord = 1;
SimReqMaintenanceN1 := instOutputInterlock.DriveControlWord = 2;
SimSpeedPctN1 := (instOutputInterlock.DriveFreqCmd_Hz / 50.0) * 100.0;
SimBrakeCmdN1 := instOutputInterlock.BrakeCmd;

TranslationSafetyError := instSafety.Fault.Error;
TranslationMotionError := instTranslation.Fault.Error;
FinalInterlockError := instOutputInterlock.Fault.Error;
M3ReqTremie := SimReqTremieN1;
M3ReqMaintenance := SimReqMaintenanceN1;
M3DriveControlWord := instOutputInterlock.DriveControlWord;
M3DriveFreqCmd_Hz := instOutputInterlock.DriveFreqCmd_Hz;
M3DriveActualFreq_Hz := UINT_TO_REAL(instSimBench.Translation.M3_ActualFrequencyHz) / 100.0;
M3BrakeReleaseRequest := instTranslation.BrakeReleaseRequest;
M3BrakeFinalCmd := instOutputInterlock.BrakeCmd;
M3BrakeContactOpen := instSimBench.Translation.M3_BrakeIsOpen_DI;
M3SensorsWord := instPositionDecoder.SensorsWord;
M3AtTremie := AtTremieStable;
M3AtP1 := AtP1Stable;
M3PositionTrue_M := instSimBench.M3ObsPositionTrue_M;
M3PositionEstimated_M := instPositionEstimator.PositionEstimatedM;
M3PositionError_M := instSimBench.M3ObsPositionError_M;
M3OvershootLast_M := instSimBench.M3ObsOvershootLast_M;
M3OvershootSensorId := instSimBench.M3ObsOvershootSensorId;
IF (CycleStep = E_AutoCycleStep.AX18_DONE_SYNC) THEN
    P1ArrivalCapturedLocal := FALSE;
END_IF;
IF (CycleStep = E_AutoCycleStep.AX2_TRANSLATE_P1) AND AtP1Stable AND NOT P1ArrivalCapturedLocal THEN
    P1ArrivalCapturedLocal := TRUE;
    P1ArrivalCaptured := TRUE;
    P1ArrivalPosition_M := M3PositionTrue_M;
    P1ArrivalSensorsWord := M3SensorsWord;
    P1ArrivalDriveControlWord := M3DriveControlWord;
    P1ArrivalFrequency_Hz := M3DriveActualFreq_Hz;
    P1ArrivalBrakeOpen := M3BrakeContactOpen;
END_IF;
M3CartFree := instSimBench.M3ObsCartFree;
M3FreeRollLast_M := instSimBench.M3ObsFreeRollLast_M;
END_FUNCTION_BLOCK
