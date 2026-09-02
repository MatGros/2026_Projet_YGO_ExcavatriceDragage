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
    COD1_PosValue         : UDINT := 1008192;
    COD2_PosValue         : UDINT := 1008192;
    
    // === ↔️ Capteurs Translation M3 ===
    M3_PosTremie_DI       : BOOL;
    M3_PosPV_DI           : BOOL;
    M3_PosPVP2_DI         : BOOL;
    M3_PosP1_DI           : BOOL;
    M3_PosMaintenance_DI  : BOOL;
    
    // === 🛡️ Sécurités / Machine ===
    PowerContactorEngaged : BOOL := TRUE;
    EmergencyChainClosed  : BOOL := TRUE;
    PhaseRotationOk       : BOOL := TRUE;
    BrakeThermalOk        : BOOL := TRUE;
    M1_ContactorsReleased : BOOL := TRUE;
    M2_ContactorsReleased : BOOL := TRUE;
    M1_ThermalOk          : BOOL := TRUE;
    M2_ThermalOk          : BOOL := TRUE;
    
    // === 🔌 Diagnostics Réseau Simulés ===
    CanBusOperational     : BOOL := TRUE;
    JoyOperational        : BOOL := TRUE;
    EcatOperational       : BOOL := TRUE;
    
    // === 🔄 Retours Aval des Autres PRG (Rétroactions Simulation / Acquittement) ===
    BtnReset_IHM          : BOOL := FALSE; // Depuis PRG_07 (Acquittement IHM)
    M1_RelayFwd           : BOOL := FALSE; // Depuis PRG_06
    M1_RelayRev           : BOOL := FALSE; // Depuis PRG_06
    M1_BrakeCmd           : BOOL := FALSE; // Depuis PRG_06
    M2_RelayFwd           : BOOL := FALSE; // Depuis PRG_06
    M2_RelayRev           : BOOL := FALSE; // Depuis PRG_06
    M2_BrakeCmd           : BOOL := FALSE; // Depuis PRG_06
    M3_BrakeCmd           : BOOL := FALSE; // Depuis PRG_06
    
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
    
    diagCanDev            : ST_Diag_Device;
    diagEcatDev           : ST_Diag_Device;
    calibM1               : ST_Encoder_Calib;
    calibM2               : ST_Encoder_Calib;
    HwInM1                : ST_fbEncoder_HwIn;
    HwInM2                : ST_fbEncoder_HwIn;
    encoderCfg            : ST_fbEncoder_Cfg;
    joyCfg                : ST_fbJoystick_Cfg;
    nxMem                 : INT := 5000;
    nyMem                 : INT := 5000;
    calibInit             : BOOL := FALSE;
END_VAR

{region "Corps d'exécution PRG_02 encapsulé"}
IF NOT calibInit THEN
    joyCfg.NeutralHoldTime := T#50ms;
    joyCfg.DeadmanArmHoldTime := T#50ms;
    joyCfg.DeadmanArmGraceTime := T#3s;
    joyCfg.DeadbandRaw := 300;
    calibM1.Homed := TRUE;
    calibM1.HomingRefRaw := 1000000;
    calibM1.LastKnownRawPos := 1008192;
    calibM1.RestartCoherenceTolerancePts := 10000;
    calibM2.Homed := TRUE;
    calibM2.HomingRefRaw := 1000000;
    calibM2.LastKnownRawPos := 1008192;
    calibM2.RestartCoherenceTolerancePts := 10000;
    calibInit := TRUE;
END_IF;

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
    Reset := BtnReset_IHM,
    ArmingPermit := TRUE,
    BusCanOpenOp := diagCanDev,
    JoystickOp := diagCanDev,
    RawX := JoyRawX,
    RawY := JoyRawY,
    RawButton := JoyBtnRaw,
    Cfg := joyCfg,
    NeutralXMem := nxMem,
    NeutralYMem := nyMem
);


Data.Joystick.DeadmanArmed := instJoystick.DeadmanArmed;
// Miroir fidèle de PRG_02_Acquisition : PRG_03/PRG_04 consomment l'axe Y
// structuré pour arbitrer le sens et la vitesse des treuils.
Data.Joystick.AxisY          := instJoystick.AxisCmdY;


Data.Joystick.AxisX := instJoystick.AxisCmdX;


// Publication réseau : miroir de PRG_02_Acquisition. PRG_04/FB_Safety_Winch
// consomment Data.Network.Joystick ; ne pas laisser ce bus à sa valeur par défaut.
Data.Network.CanOpenMaster  := diagCanDev;
Data.Network.Joystick       := diagCanDev;
Data.Network.EthercatMaster := diagEcatDev;


// 3. Traitement Codeurs Treuils M1 / M2
HwInM1.RawPosIn := COD1_PosValue;
HwInM1.SlaveOperational := EcatOperational;
instEncoderM1(
    Enable := TRUE,
    Reset := BtnReset_IHM,
    HomingPermit := TRUE,
    TopPositionSensor := TRUE,
    HwIn := HwInM1,
    PointsPerRev := 8192,
    CableM_PerRev := 2.0,
    BypassGlobal := FALSE,
    Cfg := encoderCfg,
    Calib := calibM1
);
Data.EncoderM1.Measurement := instEncoderM1.Measurement;
Data.EncoderM1.Fault := instEncoderM1.Fault;
Data.EncoderM1.HomedAndReliable := instEncoderM1.HomedAndReliable;
Data.EncoderM1.Homed := instEncoderM1.Homed;
Data.EncoderM1.HomingSuspect := instEncoderM1.HomingSuspect;

HwInM2.RawPosIn := COD2_PosValue;
HwInM2.SlaveOperational := EcatOperational;
instEncoderM2(
    Enable := TRUE,
    Reset := BtnReset_IHM,
    HomingPermit := TRUE,
    TopPositionSensor := TRUE,
    HwIn := HwInM2,
    PointsPerRev := 8192,
    CableM_PerRev := 2.0,
    BypassGlobal := FALSE,
    Cfg := encoderCfg,
    Calib := calibM2
);

Data.EncoderM2.Measurement := instEncoderM2.Measurement;
Data.EncoderM2.Fault := instEncoderM2.Fault;
Data.EncoderM2.HomedAndReliable := instEncoderM2.HomedAndReliable;
Data.EncoderM2.Homed := instEncoderM2.Homed;
Data.EncoderM2.HomingSuspect := instEncoderM2.HomingSuspect;

// 4. Diagnostics Cartes DI
Data.InputModules.LocalDigitalIoOk := TRUE;
Data.InputModules.Vh0800EndOk := TRUE;
Data.InputModules.Vh0808EtpOk := TRUE;
Data.InputModules.Fault := FALSE;

// 5. Renseignement de l'Image Matérielle HwIn (Structure Complète)
HwIn.Winch.M1_ContactorsReleased_DI := M1_ContactorsReleased;
HwIn.Winch.M1_ThermalOk_DI          := M1_ThermalOk;
HwIn.Winch.M1_BrakeIsOpen_DI        := M1_BrakeCmd;
HwIn.Winch.M2_ContactorsReleased_DI := M2_ContactorsReleased;
HwIn.Winch.M2_ThermalOk_DI          := M2_ThermalOk;
HwIn.Winch.M2_BrakeIsOpen_DI        := M2_BrakeCmd;
HwIn.Winch.M1M2_TopPositionFree_DI  := TRUE;
HwIn.Winch.M2_TensionedCable_DI     := TRUE;
HwIn.Winch.COD1_PosValue            := COD1_PosValue;
HwIn.Winch.COD2_PosValue            := COD2_PosValue;

HwIn.Translation.M3_PosTremie_DI      := M3_PosTremie_DI;
HwIn.Translation.M3_PosPV_DI          := M3_PosPV_DI;
HwIn.Translation.M3_PosPVP2_DI        := M3_PosPVP2_DI;
HwIn.Translation.M3_PosP1_DI          := M3_PosP1_DI;
HwIn.Translation.M3_PosMaintenance_DI := M3_PosMaintenance_DI;
HwIn.Translation.M3_BrakeIsOpen_DI    := M3_BrakeCmd;
HwIn.Translation.M3_ThermalOK_DI      := TRUE;

HwIn.Operator.JoyXRaw_ANA1      := JoyRawX;
HwIn.Operator.JoyYRaw_ANA2      := JoyRawY;
HwIn.Operator.JoyBtnRaw         := JoyBtnRaw;

HwIn.Machine.PowerContactorEngaged_DI   := PowerContactorEngaged;
HwIn.Machine.EmergencyChainClosed_DI    := EmergencyChainClosed;
HwIn.Machine.PhaseRotationOk_DI         := PhaseRotationOk;
HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI := BrakeThermalOk;
HwIn.Machine.HydraulicThermalOk_DI      := TRUE;
HwIn.Machine.ConveyorInfeedReady_DI     := TRUE;
{endregion}
END_FUNCTION_BLOCK
