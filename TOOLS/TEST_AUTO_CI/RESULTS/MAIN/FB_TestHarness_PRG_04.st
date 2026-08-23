(* =======================================================================
   🧱 FB_TestHarness_PRG_04 : Banc d'essai unitaire pour PRG_04_Treuils_Benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_04, consomme les bus de données de PRG_02 (Joystick,
             mesures câbles) et PRG_03 (Modes/Autorisations), exécute
             les treuils M1/M2, sécurités, synchro et benne, et publie ST_WinchInterPrg.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_04
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_02 (Acquisition) ===
    AcqData                 : ST_AcquisitionInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_03 (Modes) ===
    ModesAuth               : ST_Modes_Autorisations;
    
    // === 🛡️ Sécurités & Hardware Machine ===
    PowerContactorEngaged   : BOOL := TRUE;
    EmergencyChainClosed    : BOOL := TRUE;
    M1_ContactorsReleased   : BOOL := TRUE;
    M2_ContactorsReleased   : BOOL := TRUE;
    M1_BrakeFeedbackOpen    : BOOL := FALSE;
    M2_BrakeFeedbackOpen    : BOOL := FALSE;
    
    // === 🎛️ Commandes IHM Directes ===
    BtnReset                : BOOL := FALSE;
    BtnBucketOpen           : BOOL := FALSE;
    BtnBucketClose          : BOOL := FALSE;
    BtnWinchM1Up            : BOOL := FALSE;
    BtnWinchM1Down          : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Inter-PRG produit vers PRG_02/03/06/07 ===
    Data                    : ST_WinchInterPrg;
END_VAR

VAR
    instWinchSync           : FB_WinchSync;
    instBucket              : FB_Bucket;
    instSafetyWinchM1       : FB_Safety_Winch;
    instSafetyWinchM2       : FB_Safety_Winch;
    instWinchM1             : FB_Winch;
    instWinchM2             : FB_Winch;
    
    speedCfg                : ST_WinchSpeedConfig;
    bucketCfg               : ST_BucketConfig;
    m1StartStop             : BOOL;
    m1Direction             : INT;
    m1SpeedRef              : REAL;
    stepTable               : ST_SpeedStepTable;
END_VAR

{region "Corps d'exécution PRG_04 encapsulé"}
// 1. Initialisation configurations de référence
stepTable.StepThreshold_Pct[1] := 10.0;
stepTable.StepThreshold_Pct[2] := 30.0;
stepTable.StepThreshold_Pct[3] := 50.0;
stepTable.StepThreshold_Pct[4] := 70.0;
stepTable.StepThreshold_Pct[5] := 90.0;
stepTable.P1R1 := TRUE;
stepTable.P2R1 := TRUE;
stepTable.P3R1 := TRUE;
stepTable.P4R1 := TRUE;
stepTable.P5R1 := TRUE;
bucketCfg.OffsetOpenM := 0.0;
bucketCfg.OffsetCloseM := 15.0;
bucketCfg.CoherenceLimitM := 1.0;




// 2. Sécurités Treuil M1
instSafetyWinchM1(
    Enable                  := (ModesAuth.Mode = E_Mode.MAINT_N1 OR ModesAuth.Mode = E_Mode.MAINT_N2 OR ModesAuth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := BtnReset,
    Mode                    := ModesAuth.Mode,
    PowerContactorEngaged   := PowerContactorEngaged,
    JoystickOnline          := TRUE,
    JoystickOperational     := TRUE,
    HeartbeatIhmOk          := TRUE,
    EncoderAvailable        := NOT AcqData.M1_EncoderFault,
    ThermalFeedback         := FALSE,
    BrakeThermalFeedback    := FALSE,
    SlackCableDetected      := FALSE,
    PhaseRotationOk         := TRUE,
    TopPositionSensor       := TRUE,

    FwdRevSpeedFeedbackOff  := M1_ContactorsReleased,
    BrakeFeedback           := M1_BrakeFeedbackOpen,
    JoystickYNeutral        := AcqData.JoystickYNeutral,
    CablePosM               := AcqData.CablePosM1,
    CfgCableLimitDescentM   := -20.0,
    TopLimitM               := 7.5,
    MeasuredSpeedMps        := AcqData.M1_Speed_Mps,
    MeasuredSpeedSignedMps  := AcqData.M1_SignedSpeed_Mps,
    MeasuredSpeedValid      := AcqData.M1_SpeedValid
);
Data.WinchM1Safety.SafeStop      := instSafetyWinchM1.SafeStop;
Data.WinchM1Safety.DescendPermit := instSafetyWinchM1.DescendPermit;
Data.WinchM1Safety.AscentPermit  := instSafetyWinchM1.AscentPermit;
Data.WinchM1Safety.PowerCutOff   := instSafetyWinchM1.PowerCutOff;

// 3. Sécurités Treuil M2
instSafetyWinchM2(
    Enable                  := (ModesAuth.Mode = E_Mode.MAINT_N1 OR ModesAuth.Mode = E_Mode.MAINT_N2 OR ModesAuth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := BtnReset,
    Mode                    := ModesAuth.Mode,
    PowerContactorEngaged   := PowerContactorEngaged,
    JoystickOnline          := TRUE,
    JoystickOperational     := TRUE,
    HeartbeatIhmOk          := TRUE,
    EncoderAvailable        := NOT AcqData.M2_EncoderFault,
    ThermalFeedback         := TRUE,
    BrakeThermalFeedback    := TRUE,
    SlackCableDetected      := FALSE,
    PhaseRotationOk         := TRUE,
    TopPositionSensor       := TRUE,
    FwdRevSpeedFeedbackOff  := M2_ContactorsReleased,

    BrakeFeedback           := M2_BrakeFeedbackOpen,
    JoystickYNeutral        := AcqData.JoystickYNeutral,
    CablePosM               := AcqData.CablePosM2,
    CfgCableLimitDescentM   := -20.0,
    TopLimitM               := 7.5,
    MeasuredSpeedMps        := AcqData.M2_Speed_Mps,
    MeasuredSpeedSignedMps  := AcqData.M2_SignedSpeed_Mps,
    MeasuredSpeedValid      := AcqData.M2_SpeedValid
);
Data.WinchM2Safety.SafeStop      := instSafetyWinchM2.SafeStop;
Data.WinchM2Safety.DescendPermit := instSafetyWinchM2.DescendPermit;
Data.WinchM2Safety.AscentPermit  := instSafetyWinchM2.AscentPermit;
Data.WinchM2Safety.PowerCutOff   := instSafetyWinchM2.PowerCutOff;


// 4. Commande Treuil M1 (arbitrage Joystick + Boutons)
m1StartStop := (AcqData.JoystickDeadmanArmed AND (AcqData.JoystickDirectionX = 0) AND NOT AcqData.JoystickYNeutral AND (ModesAuth.JoystickWinchSelectArbitrated = 1 OR ModesAuth.JoystickWinchSelectArbitrated = 0))
               OR BtnWinchM1Up OR BtnWinchM1Down;

IF BtnWinchM1Up THEN
    m1Direction := 1;
    m1SpeedRef  := 50.0;
ELSIF BtnWinchM1Down THEN
    m1Direction := -1;
    m1SpeedRef  := 50.0;
ELSIF AcqData.JoystickDeadmanArmed AND NOT AcqData.JoystickYNeutral THEN
    m1Direction := SEL(AcqData.JoystickSpeedPctX > 0.0, 1, 1); // Sens derive
    m1SpeedRef  := 60.0;
ELSE
    m1Direction := 0;
    m1SpeedRef  := 0.0;
END_IF;

instWinchM1(
    Enable                  := (ModesAuth.Mode = E_Mode.MAINT_N1 OR ModesAuth.Mode = E_Mode.MAINT_N2 OR ModesAuth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := BtnReset,
    PowerContactorEngaged   := PowerContactorEngaged,
    SafeStop                := Data.WinchM1Safety.SafeStop,
    StartStop               := m1StartStop,
    Direction               := m1Direction,
    SpeedRefPct             := m1SpeedRef,
    Mode                    := ModesAuth.Mode,
    DescendPermit           := Data.WinchM1Safety.DescendPermit,
    AscentPermit            := Data.WinchM1Safety.AscentPermit,
    CablePosM               := AcqData.CablePosM1,
    Homed                   := TRUE,
    MaxStepAscent           := 5,
    CfgMaxStepDescente      := 3,
    SpeedStepTable          := stepTable,
    FwdRevSpeedFeedbackOff  := M1_ContactorsReleased
);





// Remplissage bus de sortie Data
Data.WinchM1FinalInterlockRequest.RequestedRelayFwd          := instWinchM1.RelayFwd;
Data.WinchM1FinalInterlockRequest.RequestedRelayRev          := instWinchM1.RelayRev;
Data.WinchM1FinalInterlockRequest.RequestedContactor1        := instWinchM1.Contactor1;
Data.WinchM1FinalInterlockRequest.RequestedContactor2        := instWinchM1.Contactor2;
Data.WinchM1FinalInterlockRequest.RequestedContactor3        := instWinchM1.Contactor3;
Data.WinchM1FinalInterlockRequest.RequestedContactor4        := instWinchM1.Contactor4;
Data.WinchM1FinalInterlockRequest.RequestedStep              := instWinchM1.StepNumber;
Data.WinchM1FinalInterlockRequest.PowerCutOff               := Data.WinchM1Safety.PowerCutOff;
Data.WinchM1FinalInterlockRequest.SafeStop                  := Data.WinchM1Safety.SafeStop;

Data.M1LogicRequestSpeedRef_Pct                             := m1SpeedRef;
Data.WinchM1State.StepNumber                                := instWinchM1.StepNumber;
Data.WinchM1State.RelayFwd                                  := instWinchM1.RelayFwd;
Data.WinchM1State.RelayRev                                  := instWinchM1.RelayRev;
{endregion}
END_FUNCTION_BLOCK

