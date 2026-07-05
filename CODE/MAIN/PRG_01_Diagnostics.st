(* ═══════════════════════════════════════════════════════════════
   📡 PRG_01_Diagnostics — États bus de terrain et Joystick (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_01_Diagnostics
VAR
    instDiagCanOpen  : FB_DiagCanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_DiagEthercat;      // Diagnostic EtherCAT (3 devices)
    FB_Joystick_0    : FB_Joystick;          // Traitement joystick (calib/filtre/rampe)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_01_Diagnostics) ===

// 1. Diagnostics CANopen
instDiagCanOpen(
    Enable := TRUE,
    Reset := PRG_09_Supervision.MachineReset_IHM,
    CanOnline := (CANbus.GetBusState() = 1) OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, // 1 = ACTIVE (ou bypass test banc)
    CanOperational := (JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() = DEVICE_STATE.RUNNING) OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_09_Supervision.MachineReset_IHM,          // 🔑 Bouton général machine
    VariateurWcState := (AC600_ECAT_Drive.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    VariateurSlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (AC600_ECAT_Drive.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM1WcState := (COD1_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    EncoderM1SlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (COD1_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM2WcState := (COD2_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    EncoderM2SlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (COD2_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8)
);

// 3. Acquisition Joystick
FB_Joystick_0(
    Enable          := GVL_DEBUG.DBG_True,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    Reset           := PRG_09_Supervision.MachineReset_IHM,
    NeutralXMem     := GVL_PERSISTENT.JoystickNeutralX,
    NeutralYMem     := GVL_PERSISTENT.JoystickNeutralY,
    BusCanOpenOP    := instDiagCanOpen.busCanOpen,
    JoystickOP      := instDiagCanOpen.Joystick,
    RawX            := JoyXRaw_ANA1,
    RawY            := JoyYRaw_ANA2,
    RawButton       := JoyBtnRaw,
    Calibrate       := GVL_IHM.Joystick.Calibrate,
    InvertX         := FALSE,
    InvertY         := FALSE,
    Deadband        := 10.0,
    FilterTime      := TIME#100ms,
    AccelRate       := 50.0,
    DecelRate       := 150.0
);
