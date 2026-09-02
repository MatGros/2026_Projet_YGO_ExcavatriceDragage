(* =======================================================================
   🧱 FB_TestHarness_PRG_05 : Banc d'essai unitaire pour PRG_05_Translation
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_05, consomme les bus de données de PRG_02 (Position,
             capteurs, joystick X), PRG_03 (Modes/Autorisations) et PRG_04 (Hauteur treuils),
             exécute FB_Translation et FB_Safety_Translation, et publie ST_TranslationInterPrg.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_05
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_02 (Acquisition) ===
    AcqData                 : ST_AcquisitionInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_03 (Modes) ===
    ModesAuth               : ST_Modes_Autorisations;
    
    // === 📥 Bus d'Entrée issus de PRG_04 (Treuils / Hauteur câble) ===
    WinchM1CablePosM        : REAL := 5.0;
    WinchM2CablePosM        : REAL := 5.0;
    
    // === 🛡️ Sécurités & Hardware Machine ===
    PowerContactorEngaged   : BOOL := TRUE;
    EmergencyChainClosed    : BOOL := TRUE;
    BrakeFeedbackOpen       : BOOL := FALSE;
    DriveOnline             : BOOL := TRUE;
    DriveOperational        : BOOL := TRUE;
    
    // === 🎛️ Commandes IHM Directes ===
    BtnReset                : BOOL := FALSE;
    BtnTranslationFwd       : BOOL := FALSE;
    BtnTranslationRev       : BOOL := FALSE;

    // === 🧩 Capteurs position M3 ===
    M3_PosTremie_DI         : BOOL := FALSE;
    M3_PosPV_DI             : BOOL := FALSE;
    M3_PosPVP2_DI           : BOOL := FALSE;
    M3_PosP1_DI             : BOOL := FALSE;
    M3_PosMaintenance_DI    : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Inter-PRG produit vers PRG_03/06/07 ===
    Data                    : ST_TranslationInterPrg;
END_VAR

VAR
    instTranslationM3       : FB_Translation;
    instSafetyTranslationM3 : FB_Safety_Translation;
    instPosDecoderM3        : FB_Translation_PositionDecoder;
    
    m3Cfg                   : ST_fbTranslation_Cfg;
    m3RunRequest            : BOOL;
    m3ReqTremie             : BOOL;
    m3ReqMaintenance        : BOOL;
    m3Direction             : INT;
    m3SpeedTgt              : REAL;
    m3HeightOk              : BOOL;
    initDone                : BOOL := FALSE;
END_VAR

{region "Corps d'exécution PRG_05 encapsulé"}
IF NOT initDone THEN
    m3Cfg.CfgRampAccelRate := 1000.0;
    m3Cfg.CfgRampDecelNormalRate := 1000.0;
    m3Cfg.CfgRampDecelFastRate := 2000.0;
    m3Cfg.DriveFreqScaleMaxHz := 50.0;
    initDone := TRUE;
END_IF;

// 0. Décodage position M3
instPosDecoderM3(
    SensorTremie      := M3_PosTremie_DI,
    SensorPV          := M3_PosPV_DI,
    SensorP2          := M3_PosPVP2_DI,
    SensorP1          := M3_PosP1_DI,
    SensorMaintenance := M3_PosMaintenance_DI
);

// 1. Interlock Hauteur Treuils
m3HeightOk := (WinchM1CablePosM >= 2.0) AND (WinchM2CablePosM >= 2.0);

// 2. Arbitrage Commande Translation
IF BtnTranslationFwd THEN
    m3ReqTremie      := TRUE;
    m3ReqMaintenance := FALSE;
    m3RunRequest     := TRUE;
    m3Direction      := 1;
    m3SpeedTgt       := 50.0;
ELSIF BtnTranslationRev THEN
    m3ReqTremie      := FALSE;
    m3ReqMaintenance := TRUE;
    m3RunRequest     := TRUE;
    m3Direction      := -1;
    m3SpeedTgt       := 50.0;
ELSIF AcqData.Joystick.DeadmanArmed AND (AcqData.Joystick.AxisX.Direction <> 0) AND m3HeightOk THEN
    m3ReqTremie      := (AcqData.Joystick.AxisX.Direction = 1);
    m3ReqMaintenance := (AcqData.Joystick.AxisX.Direction = -1);
    m3RunRequest     := TRUE;
    m3Direction      := AcqData.Joystick.AxisX.Direction;
    m3SpeedTgt       := ABS(AcqData.Joystick.AxisX.SpeedTgt);
ELSE
    m3ReqTremie      := FALSE;
    m3ReqMaintenance := FALSE;
    m3RunRequest     := FALSE;
    m3Direction      := 0;
    m3SpeedTgt       := 0.0;
END_IF;

// 3. Sécurité Translation M3
instSafetyTranslationM3(
    Enable                  := (ModesAuth.Mode <> E_Mode.DISABLE),
    Reset                   := BtnReset,
    PowerContactorEngaged   := PowerContactorEngaged,
    Mode                    := ModesAuth.Mode,
    JoystickOnline          := TRUE,
    JoystickOperational     := TRUE,
    HeartbeatIhmOk          := TRUE,
    PhaseRotationOk         := TRUE,
    BrakeThermalFeedback    := FALSE,
    DriveOnline             := DriveOnline,
    DriveOperational        := DriveOperational,
    DriveStatusWord         := 16#0000,
    DriveActualFreqHz       := 0.0,
    BrakeFeedback           := BrakeFeedbackOpen,
    BrakeCmd                := FALSE,
    RunRequest              := m3RunRequest,
    ReqTremie               := m3ReqTremie,
    ReqMaintenance          := m3ReqMaintenance,
    LimitSwitchTremie       := instPosDecoderM3.LimitSwitchTremie,
    LimitSwitchMaintenance  := instPosDecoderM3.LimitSwitchMaintenance,
    SensorWordIncoherent    := instPosDecoderM3.Incoherent
);

Data.TranslationSafety.SafeStop    := instSafetyTranslationM3.SafeStop;
Data.TranslationSafety.PowerCutOff := instSafetyTranslationM3.PowerCutOff;

// 4. Pilotage M3
instTranslationM3(
    Enable                     := (ModesAuth.Mode <> E_Mode.DISABLE),
    Reset                      := BtnReset,
    PowerContactorEngaged      := PowerContactorEngaged,
    Mode                       := ModesAuth.Mode,
    RunRequest                 := m3RunRequest,
    SafeStop                   := Data.TranslationSafety.SafeStop,
    ReqTremie                  := m3ReqTremie,
    ReqMaintenance             := m3ReqMaintenance,
    SpeedTgt_Pct               := m3SpeedTgt,
    PositionSensorTarget       := FALSE,
    SlowdownSensorTremie       := instPosDecoderM3.TranslationPosPV,
    SlowdownSensorMaintenance  := instPosDecoderM3.TranslationPosP1,
    SlowdownSensorP1           := instPosDecoderM3.TranslationPosP2,
    LimitSwitchTremie          := instPosDecoderM3.LimitSwitchTremie,
    LimitSwitchMaintenance     := instPosDecoderM3.LimitSwitchMaintenance,
    EffectivePermitM3_Tremie   := instSafetyTranslationM3.TremieLimitClear,
    EffectivePermitM3_Maintenance := instSafetyTranslationM3.MaintenanceLimitClear,
    DriveStatusWord            := 16#0081,
    DriveActualFreqHz          := 0.0,
    BrakeFeedback              := BrakeFeedbackOpen,
    Cfg                        := m3Cfg
);

// 5. Remplissage Bus Sortie Data
Data.TranslationFinalInterlockRequest.Enable                    := instTranslationM3.Enable;
Data.TranslationFinalInterlockRequest.Reset                     := BtnReset;
Data.TranslationFinalInterlockRequest.PowerContactorEngaged     := PowerContactorEngaged;
Data.TranslationFinalInterlockRequest.SafeStop                  := Data.TranslationSafety.SafeStop;
Data.TranslationFinalInterlockRequest.PowerCutOff               := Data.TranslationSafety.PowerCutOff;
Data.TranslationFinalInterlockRequest.BrakeReleaseRequest       := instTranslationM3.BrakeReleaseRequest;
Data.TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz      := instTranslationM3.RequestedDriveFreqHz;

Data.TranslationState.ActiveTremie := (m3Direction = 1);
Data.TranslationState.ActiveMaintenance := (m3Direction = -1);
Data.TranslationState.SpeedCmd_Pct                             := m3SpeedTgt;
Data.TranslationState.Busy                                     := (instTranslationM3.RequestedDriveControlWord <> 0);
Data.TranslationState.Ready                                    := instTranslationM3.Ready;
{endregion}
END_FUNCTION_BLOCK

