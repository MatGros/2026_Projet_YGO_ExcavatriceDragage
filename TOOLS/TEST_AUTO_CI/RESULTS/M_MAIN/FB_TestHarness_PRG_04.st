(*====================================================================
   FB_TestHarness_PRG_04 : Banc d'essai unitaire pour PRG_04_Treuils_Benne
   ==================================================================== *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_04
VAR_IN_OUT
    BucketMech              : ST_fbBucket_State;
END_VAR

VAR_INPUT
    AcqData                : ST_AcquisitionInterPrg;
    ModesAuth               : ST_Modes_Autorisations;
    BtnWinchM1Up            : BOOL := FALSE;
    BtnWinchM1Down          : BOOL := FALSE;
    BtnWinchM2Up            : BOOL := FALSE;
    BtnWinchM2Down          : BOOL := FALSE;
    BtnWinchBothUp          : BOOL := FALSE;
    BtnWinchBothDown        : BOOL := FALSE;
    BucketBtnOpen           : BOOL := FALSE;
    BucketBtnClose          : BOOL := FALSE;
    PowerContactorEngaged   : BOOL := TRUE;
    M1_ContactorsReleased   : BOOL := TRUE;
    M2_ContactorsReleased   : BOOL := TRUE;
    M1_BrakeFeedbackOpen    : BOOL := TRUE;
    M2_BrakeFeedbackOpen    : BOOL := TRUE;
    M1_ThermalOk            : BOOL := TRUE;
    M2_ThermalOk            : BOOL := TRUE;
    BrakeThermalOk          : BOOL := TRUE;
    M1_TensionedCable       : BOOL := TRUE;
    M2_TensionedCable       : BOOL := TRUE;
    PhaseRotationOk         : BOOL := TRUE;
    TopPositionFreeDI       : BOOL := TRUE;
    FaultMachineResetIHM    : BOOL := FALSE;
    CfgCableLimitAscentM    : REAL := 7.5;
    CfgCableLimitDescentM1  : REAL := -30.0;
    CfgCableLimitDescentM2  : REAL := -30.0;
    WinchSlowdownDistanceM  : REAL := 1.0;
    WinchSlowdownMaxStep    : INT  := 1;
    SpeedStepTable          : ST_SpeedStepTable;
    BucketPersistConfig     : ST_fbBucket_Config;
END_VAR

VAR_OUTPUT
    Data                    : ST_WinchInterPrg;
END_VAR

VAR
    instWinchSync           : FB_WinchSync;
    instBucket              : FB_Bucket;
    instSafetyWinchM1       : FB_Safety_Winch;
    instSafetyWinchM2       : FB_Safety_Winch;
    instWinchM1             : FB_Winch;
    instWinchM2             : FB_Winch;
    ReqM1Winch              : ST_fbWinch_Req;
    ReqM2Winch              : ST_fbWinch_Req;
    M1WinchSensors          : ST_fbWinch_Sensors;
    M2WinchSensors          : ST_fbWinch_Sensors;
    M1WinchCfg              : ST_fbWinch_Cfg;
    M2WinchCfg              : ST_fbWinch_Cfg;
    M1LogicRunRequest       : BOOL;
    M1LogicReqAscent        : BOOL;
    M1LogicReqDescend       : BOOL;
    M1LogicRequestStepTgt   : INT;
    M1LogicRequestSpeedCmd_Pct : REAL;
    M2LogicRunRequest       : BOOL;
    M2LogicReqAscent        : BOOL;
    M2LogicReqDescend       : BOOL;
    M2LogicRequestStepTgt   : INT;
    M2LogicRequestSpeedCmd_Pct : REAL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    EffectivePermitM1_Ascent : BOOL;
    EffectivePermitM1_Descend : BOOL;
    EffectivePermitM2_Ascent : BOOL;
    EffectivePermitM2_Descend : BOOL;
END_VAR

M1LogicReqAscent := BtnWinchM1Up OR (ModesAuth.JoystickWinchSelectArbitrated = 1 AND AcqData.Joystick.DeadmanArmed AND NOT AcqData.Joystick.AtNeutralXY AND (AcqData.Joystick.AxisY.Direction = 1));
M1LogicReqDescend := BtnWinchM1Down OR (ModesAuth.JoystickWinchSelectArbitrated = 1 AND AcqData.Joystick.DeadmanArmed AND NOT AcqData.Joystick.AtNeutralXY AND (AcqData.Joystick.AxisY.Direction = -1));
M1LogicRunRequest := M1LogicReqAscent OR M1LogicReqDescend;
M1LogicRequestStepTgt := SEL(M1LogicRunRequest, 0, 1);
M1LogicRequestSpeedCmd_Pct := SEL(M1LogicRunRequest, 0.0, 20.0);

M2LogicReqAscent := BtnWinchM2Up OR (ModesAuth.JoystickWinchSelectArbitrated = 2 AND AcqData.Joystick.DeadmanArmed AND NOT AcqData.Joystick.AtNeutralXY AND (AcqData.Joystick.AxisY.Direction = 1));
M2LogicReqDescend := BtnWinchM2Down OR (ModesAuth.JoystickWinchSelectArbitrated = 2 AND AcqData.Joystick.DeadmanArmed AND NOT AcqData.Joystick.AtNeutralXY AND (AcqData.Joystick.AxisY.Direction = -1));
M2LogicRunRequest := M2LogicReqAscent OR M2LogicReqDescend;
M2LogicRequestStepTgt := SEL(M2LogicRunRequest, 0, 1);
M2LogicRequestSpeedCmd_Pct := SEL(M2LogicRunRequest, 0.0, 20.0);

instSafetyWinchM1(
    Enable                  := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM1,
    Reset                   := FaultMachineResetIHM,
    Mode                    := ModesAuth.Mode,
    SyncEnable              := ModesAuth.SyncEnable,
    ReqAscent               := M1LogicReqAscent,
    ReqDescend              := M1LogicReqDescend,
    MovementCommanded       := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    PowerContactorEngaged   := PowerContactorEngaged,
    JoystickOnline          := TRUE,
    JoystickOperational     := TRUE,
    HeartbeatIhmOk          := TRUE,
    EncoderAvailable        := AcqData.EncoderM1.Measurement.EncoderAvailable,
    ThermalFeedback         := NOT M1_ThermalOk,
    BrakeThermalFeedback    := NOT BrakeThermalOk,
    BypassOperatorComm      := TRUE,
    SlackCableDetected      := NOT M1_TensionedCable,
    PhaseRotationOk         := PhaseRotationOk,
    TopPositionSensor       := TopPositionFreeDI,
    FwdRevSpeedFeedbackOff  := M1_ContactorsReleased,
    BrakeFeedback           := M1_BrakeFeedbackOpen,
    JoystickYNeutral        := AcqData.Joystick.AtNeutralXY,
    CablePosM               := AcqData.EncoderM1.Measurement.CablePosM,
    CfgCableLimitDescentM   := CfgCableLimitDescentM1,
    TopLimitM               := CfgCableLimitAscentM,
    Homed                   := AcqData.EncoderM1.Homed,
    HomingSuspect           := AcqData.EncoderM1.HomingSuspect,
    MeasuredSpeedMps        := AcqData.EncoderM1.Measurement.Speed_Mps,
    MeasuredSpeedSignedMps  := AcqData.EncoderM1.Measurement.SignedSpeed_Mps,
    MeasuredSpeedValid      := AcqData.EncoderM1.Measurement.SpeedValid
);

SafeStopM1_Active := instSafetyWinchM1.SafeStop;
EffectivePermitM1_Ascent := instSafetyWinchM1.AscentPermit AND NOT SafeStopM1_Active;
EffectivePermitM1_Descend := instSafetyWinchM1.DescendPermit AND NOT SafeStopM1_Active;

ReqM1Winch.RunRequest := M1LogicRunRequest;
ReqM1Winch.ReqAscent := M1LogicReqAscent;
ReqM1Winch.ReqDescend := M1LogicReqDescend;
ReqM1Winch.SpeedStepReq := M1LogicRequestStepTgt;
ReqM1Winch.MaxStepUp := 5;
ReqM1Winch.MaxStepDown := 3;

M1WinchSensors.CablePosM := AcqData.EncoderM1.Measurement.CablePosM;
M1WinchSensors.Homed := AcqData.EncoderM1.Homed;
M1WinchSensors.HomingSuspect := AcqData.EncoderM1.HomingSuspect;
M1WinchSensors.ContactorsAllOff := M1_ContactorsReleased;

M1WinchCfg.SpeedStepTable := SpeedStepTable;
M1WinchCfg.SlowdownDistanceBottom_M := WinchSlowdownDistanceM;
M1WinchCfg.SlowdownMaxStep := WinchSlowdownMaxStep;

instWinchM1(
    Enable                  := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM1,
    Reset                   := FaultMachineResetIHM,
    PowerContactorEngaged   := PowerContactorEngaged,
    SafeStop                := SafeStopM1_Active,
    DescendPermit           := EffectivePermitM1_Descend,
    AscentPermit            := EffectivePermitM1_Ascent,
    WinchRequest            := ReqM1Winch,
    Sensors                 := M1WinchSensors,
    Config                  := M1WinchCfg
);

Data.WinchM1FinalInterlockRequest.Enable := TRUE;
Data.WinchM1FinalInterlockRequest.Reset := FaultMachineResetIHM;
Data.WinchM1FinalInterlockRequest.PowerContactorEngaged := PowerContactorEngaged;
Data.WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
Data.WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;
Data.WinchM1FinalInterlockRequest.AscentPermit := EffectivePermitM1_Ascent;
Data.WinchM1FinalInterlockRequest.DescendPermit := EffectivePermitM1_Descend;
Data.WinchM1FinalInterlockRequest.BrakeFeedback := M1_BrakeFeedbackOpen;
Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := M1_ContactorsReleased;
Data.WinchM1FinalInterlockRequest.RequestedRelayFwd := M1LogicReqAscent AND NOT SafeStopM1_Active;
Data.WinchM1FinalInterlockRequest.RequestedRelayRev := M1LogicReqDescend AND NOT SafeStopM1_Active;
Data.WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
Data.WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;

Data.WinchM1Safety.SafeStop := SafeStopM1_Active;
Data.WinchM1Safety.PowerCutOff := instSafetyWinchM1.PowerCutOff;
Data.WinchM1Safety.AscentPermit := EffectivePermitM1_Ascent;
Data.WinchM1Safety.DescendPermit := EffectivePermitM1_Descend;

Data.WinchM1State.RelayFwd := M1LogicReqAscent AND NOT SafeStopM1_Active;
Data.WinchM1State.RelayRev := M1LogicReqDescend AND NOT SafeStopM1_Active;
Data.WinchM1State.StepNumber := instWinchM1.StepNumber;

Data.M1LogicRequestSpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct;

END_FUNCTION_BLOCK
