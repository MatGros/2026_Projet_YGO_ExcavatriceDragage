(* =======================================================================
   🧱 FB_TestHarness_PRG_02 : Banc d'essai unitaire pour PRG_02_Acquisition
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_02, injecte les entrées brutes physiques/simulation,
             exécute le bloc et expose les flux de données sortants du bus Data.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_02
VAR_INPUT
    // === 🕹️ Entrées Joystick Brutes ===
    JoyRawX               : INT := 5000;
    JoyRawY               : INT := 5000;
    JoyBtnRaw             : BOOL;
    
    // === 🪝 Entrées Codeurs Brutes ===
    COD1_PosValue         : UDINT := 1000000;
    COD2_PosValue         : UDINT := 1000000;
    
    // === ↔️ Capteurs Translation M3 ===
    M3_PosTremie_DI       : BOOL;
    M3_PosPV_DI           : BOOL;
    M3_PosPVP2_DI         : BOOL;
    M3_PosP1_DI           : BOOL;
    M3_PosMaintenance_DI  : BOOL;
    
    // === 🛡️ Sécurités / Machine ===
    PowerContactorEngaged : BOOL := TRUE;
    EmergencyChainClosed  : BOOL := TRUE;
    
    // === 🔌 Diagnostics Réseau Simulés ===
    CanBusOperational     : BOOL := TRUE;
    JoyOperational        : BOOL := TRUE;
    EcatOperational       : BOOL := TRUE;
    
    // === 🧪 Commande Simulation ===
    SimulationModeActive  : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus de données produit vers PRG_03/04/05/06/07 ===
    Data                  : ST_AcquisitionInterPrg;
    
    // === 🖼️ Image Qualifiée HwIn ===
    HwIn                  : ST_HardwareImage;
END_VAR

VAR
    instJoystick          : FB_Joystick;
    instDiagCanOpen       : FB_Diag_CanOpen;
    instDiagEthercat      : FB_Diag_Ethercat;
    instEncoderM1         : FB_Encoder;
    instEncoderM2         : FB_Encoder;
    instPosDecoderM3      : FB_Translation_PositionDecoder;
    
    diagCanDev            : ST_Diag_Device;
    diagEcatDev           : ST_Diag_Device;
    calibM1               : ST_Encoder_Calib;
    calibM2               : ST_Encoder_Calib;
    hwM1                  : ST_EncoderHw;
    hwM2                  : ST_EncoderHw;
    nxMem                 : INT := 5000;
    nyMem                 : INT := 5000;
END_VAR

{region "Corps d'exécution PRG_02 encapsulé"}
// 1. Diagnostics Réseau
diagCanDev.Online := CanBusOperational;
diagCanDev.Operational := CanBusOperational AND JoyOperational;
IF diagCanDev.Operational THEN
    diagCanDev.State := E_Diag_State.READY;
ELSE
    diagCanDev.State := E_Diag_State.INIT;
END_IF;

diagEcatDev.Online := EcatOperational;
diagEcatDev.Operational := EcatOperational;
IF diagEcatDev.Operational THEN
    diagEcatDev.State := E_Diag_State.READY;
ELSE
    diagEcatDev.State := E_Diag_State.INIT;
END_IF;


// 2. Traitement Joystick
instJoystick(
    Enable := TRUE,
    Reset := FALSE,
    ArmingPermit := TRUE,
    BusCanOpenOp := diagCanDev,
    JoystickOp := diagCanDev,
    RawX := JoyRawX,
    RawY := JoyRawY,
    RawButton := JoyBtnRaw,
    NeutralHoldTime := T#50ms,
    DeadmanArmHoldTime := T#50ms,
    DeadmanArmGraceTime := T#3s,
    DeadbandRaw := 300,
    NeutralXMem := nxMem,
    NeutralYMem := nyMem
);


Data.JoystickDeadmanArmed := instJoystick.DeadmanArmed;
Data.JoystickXNeutral     := instJoystick.AxisCmdX.AtNeutral;
Data.JoystickYNeutral     := instJoystick.AxisCmdY.AtNeutral;
Data.JoystickDirectionX   := instJoystick.DirectionX;
Data.JoystickSpeedPctX    := instJoystick.AxisCmdX.SpeedRef;

// 3. Traitement Codeurs Treuils M1 / M2
hwM1.RawPosIn := COD1_PosValue;
hwM1.SlaveOperational := EcatOperational;
instEncoderM1(
    Enable := TRUE,
    Reset := FALSE,
    HomingPermit := TRUE,
    TopPositionSensor := FALSE,
    Hw := hwM1,
    PointsPerRev := 8192,
    CableM_PerRev := 2.0,
    BypassGlobal := FALSE,
    Calib := calibM1
);
Data.CablePosM1            := instEncoderM1.Measurement.CablePosM;
Data.M1_Speed_Mps          := instEncoderM1.Measurement.Speed_Mps;
Data.M1_SignedSpeed_Mps    := instEncoderM1.Measurement.SignedSpeed_Mps;
Data.M1_SpeedValid         := instEncoderM1.Measurement.SpeedValid;
Data.M1_EncoderIncoherent  := instEncoderM1.Measurement.EncoderIncoherent;
Data.M1_EncoderFault       := instEncoderM1.EncoderFault;
Data.M1_HomedAndReliable   := instEncoderM1.HomedAndReliable;

hwM2.RawPosIn := COD2_PosValue;
hwM2.SlaveOperational := EcatOperational;
instEncoderM2(
    Enable := TRUE,
    Reset := FALSE,
    HomingPermit := TRUE,
    TopPositionSensor := FALSE,
    Hw := hwM2,
    PointsPerRev := 8192,
    CableM_PerRev := 2.0,
    BypassGlobal := FALSE,
    Calib := calibM2
);
Data.CablePosM2            := instEncoderM2.Measurement.CablePosM;
Data.M2_Speed_Mps          := instEncoderM2.Measurement.Speed_Mps;
Data.M2_SignedSpeed_Mps    := instEncoderM2.Measurement.SignedSpeed_Mps;
Data.M2_SpeedValid         := instEncoderM2.Measurement.SpeedValid;
Data.M2_EncoderIncoherent  := instEncoderM2.Measurement.EncoderIncoherent;
Data.M2_EncoderFault       := instEncoderM2.EncoderFault;
Data.M2_HomedAndReliable   := instEncoderM2.HomedAndReliable;

// 4. Décodage Position Translation M3
instPosDecoderM3(
    SensorTremie := M3_PosTremie_DI,
    SensorPV := M3_PosPV_DI,
    SensorP2 := M3_PosPVP2_DI,
    SensorP1 := M3_PosP1_DI,
    SensorMaintenance := M3_PosMaintenance_DI
);
Data.TranslationPosTremie      := instPosDecoderM3.TranslationPosTremie;
Data.TranslationPosPV          := instPosDecoderM3.TranslationPosPV;
Data.TranslationPosP2          := instPosDecoderM3.TranslationPosP2;
Data.TranslationPosP1          := instPosDecoderM3.TranslationPosP1;
Data.TranslationPosMaintenance := instPosDecoderM3.TranslationPosMaintenance;
Data.TranslationAtTremie       := instPosDecoderM3.TranslationAtTremie;
Data.TranslationAtPV           := instPosDecoderM3.TranslationAtPV;
Data.TranslationAtP2           := instPosDecoderM3.TranslationAtP2;
Data.TranslationAtP1           := instPosDecoderM3.TranslationAtP1;
Data.TranslationAtMaintenance  := instPosDecoderM3.TranslationAtMaintenance;
Data.M3_LimitSwitchFwd         := instPosDecoderM3.LimitSwitchFwd;
Data.M3_LimitSwitchRev         := instPosDecoderM3.LimitSwitchRev;
Data.M3_SensorWordIncoherent   := instPosDecoderM3.Incoherent;

// Diagnostics Cartes DI
Data.LocalDigitalIoOk := TRUE;
Data.Vh0800EndOk      := TRUE;
Data.Vh0808EtpOk      := TRUE;
Data.InputModuleFault := FALSE;
{endregion}
END_FUNCTION_BLOCK
