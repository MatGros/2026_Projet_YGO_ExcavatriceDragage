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
    ModesAuth               : ST_fbModes_Autorisations;
    
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

    // === 🧩 Capteurs position M3 (décodage propriété PRG_05, AF-02 TBD §8 #5) ===
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
    
    m3StartStop             : BOOL;
    m3Direction             : INT;
    m3SpeedTgt              : REAL;
    m3HeightOk              : BOOL;
END_VAR

{region "Corps d'exécution PRG_05 encapsulé"}
// 0. Décodage position M3 (migré de PRG_02, AF-02 TBD §8 #5)
instPosDecoderM3(
    SensorTremie      := M3_PosTremie_DI,
    SensorPV          := M3_PosPV_DI,
    SensorP2          := M3_PosPVP2_DI,
    SensorP1          := M3_PosP1_DI,
    SensorMaintenance := M3_PosMaintenance_DI
);

// 1. Interlock Hauteur Treuils (Treuils doivent être au-dessus du seuil mini pour translater)
m3HeightOk := (WinchM1CablePosM >= 2.0) AND (WinchM2CablePosM >= 2.0);

// 2. Sécurité Translation M3
instSafetyTranslationM3(
    Enable                  := (ModesAuth.Mode = E_Mode.MAINT_N1 OR ModesAuth.Mode = E_Mode.MAINT_N2 OR ModesAuth.Mode = E_Mode.SEMI_AUTO),
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
    Direction               := m3Direction,
    LimitSwitchFwd          := instPosDecoderM3.LimitSwitchFwd,
    LimitSwitchRev          := instPosDecoderM3.LimitSwitchRev,
    SensorWordIncoherent    := instPosDecoderM3.Incoherent
);

Data.TranslationSafety.SafeStop    := instSafetyTranslationM3.SafeStop;
Data.TranslationSafety.PowerCutOff := instSafetyTranslationM3.PowerCutOff;

// 3. Arbitrage Commande Translation (Joystick X ou Boutons)
m3StartStop := (AcqData.JoystickDeadmanArmed AND (AcqData.JoystickDirectionX <> 0) AND m3HeightOk)
               OR BtnTranslationFwd OR BtnTranslationRev;

IF BtnTranslationFwd THEN
    m3Direction := 1;
    m3SpeedTgt  := 50.0;
ELSIF BtnTranslationRev THEN
    m3Direction := -1;
    m3SpeedTgt  := 50.0;
ELSIF AcqData.JoystickDeadmanArmed AND (AcqData.JoystickDirectionX <> 0) AND m3HeightOk THEN
    m3Direction := AcqData.JoystickDirectionX;
    m3SpeedTgt  := AcqData.JoystickSpeedPctX;
ELSE
    m3Direction := 0;
    m3SpeedTgt  := 0.0;
END_IF;

// 4. Pilotage M3
instTranslationM3(
    Enable                  := (ModesAuth.Mode = E_Mode.MAINT_N1 OR ModesAuth.Mode = E_Mode.MAINT_N2 OR ModesAuth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := BtnReset,
    PowerContactorEngaged   := PowerContactorEngaged,
    Mode                    := ModesAuth.Mode,
    StartStop               := m3StartStop,
    SafeStop                := Data.TranslationSafety.SafeStop,
    Direction               := m3Direction,
    SpeedTgt_Pct            := m3SpeedTgt,
    PositionSensorTarget    := FALSE,
    SlowdownSensorTremie    := instPosDecoderM3.TranslationAtPV,
    SlowdownSensorMaintenance := instPosDecoderM3.TranslationAtP1,
    SlowdownSensorP1        := instPosDecoderM3.TranslationAtP2,
    LimitSwitchFwd          := instPosDecoderM3.LimitSwitchFwd,
    LimitSwitchRev          := instPosDecoderM3.LimitSwitchRev,
    DriveStatusWord         := 16#0081,
    DriveActualFreqHz       := 0.0,
    BrakeFeedback           := BrakeFeedbackOpen,
    BrakeDelayContactClose  := T#0ms,
    BrakeDelayMagnetise     := T#0ms,
    CfgRampAccelRate        := 1000.0
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

Data.TranslationState.ActiveDirection                          := m3Direction;
Data.TranslationState.SpeedCmd_Pct                             := m3SpeedTgt;
Data.TranslationState.Busy                                     := (instTranslationM3.RequestedDriveControlWord <> 0);
Data.TranslationState.Ready                                    := instTranslationM3.Ready;
{endregion}
END_FUNCTION_BLOCK

