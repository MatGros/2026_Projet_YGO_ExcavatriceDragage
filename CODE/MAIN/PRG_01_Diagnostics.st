(* ═══════════════════════════════════════════════════════════════
   📡 PRG_01_Diagnostics — États bus de terrain et Joystick (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v2.12.md ; DOC/AF_Partie-08_Fonction_Joystick_v1.3.md
*)

PROGRAM PRG_01_Diagnostics
VAR
    instDiagCanOpen  : FB_DiagCanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_DiagEthercat;      // Diagnostic EtherCAT (3 devices)
    FB_Joystick_0    : FB_Joystick;          // Traitement joystick (calib/filtre/rampe)
    instIhmHeartbeat : FB_IhmHeartbeat;      // 💓 Surveillance IHM↔PLC, consommée par PRG_03_Safety

    // 🆕 REX 2026-07-24 (demande utilisateur, mise en service) : capture UNIQUE par cycle des
    // valeurs brutes bus (évite d'appeler GetBusState()/GetDeviceState() deux fois par device).
    // 📄 Lot L5 : données remises dans HwIn par PRG_00 §0.
    RawCanBusState    : INT;          // CANbus.GetBusState() brut
    RawJoystickState  : DEVICE_STATE; // JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() brut
    RawVariateurState : DEVICE_STATE; // AC600_ECAT_Drive.GetDeviceState() brut
    RawEncoderM1State : DEVICE_STATE; // COD1_CODEUR.GetDeviceState() brut
    RawEncoderM2State : DEVICE_STATE; // COD2_CODEUR.GetDeviceState() brut
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_01_Diagnostics) ===


// 🔧 REX 2026-07-24 (demande utilisateur, mise en service) : REFONTE — PRG_01 lit les valeurs brutes bus
// depuis l'image matérielle HwIn transmise par PRG_00_Inputs.
// C'est FB_DiagCanOpen/FB_DiagEthercat qui décident désormais seuls Online/Operational/State
// (distinction INIT normal / SIMULATED bypass / READY réel / ERROR — voir en-tête de ces FB).
RawCanBusState    := PRG_00_Inputs.HwIn.Operator.CanBusState;
RawJoystickState  := PRG_00_Inputs.HwIn.Operator.JOY1_DeviceState;
RawVariateurState := PRG_00_Inputs.HwIn.Translation.AC600_DeviceState;
RawEncoderM1State := PRG_00_Inputs.HwIn.Winch.COD1_DeviceState;
RawEncoderM2State := PRG_00_Inputs.HwIn.Winch.COD2_DeviceState;

// 1. Diagnostics CANopen — 🆕 REX 2026-07-08 : gardé par BusJoystickIsReal UNIQUEMENT (bus/nœud),
// indépendant de BusJoystickSignalIsReal (signal brut ci-dessus) — granularité séparée.
instDiagCanOpen(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,
    CANbusStateRaw := RawCanBusState,
    DeviceJoystickStateRaw := RawJoystickState,
    SimBypassActive := FALSE,
    NetworkBypassActive := GVL_IHM.Network.Bypass.Global
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,          // 🔑 Bouton général machine
    DeviceVariateurStateRaw := RawVariateurState,
    DeviceVariateurSimBypass := FALSE,
    DeviceEncoderM1StateRaw := RawEncoderM1State,
    DeviceEncoderM1SimBypass := FALSE,
    DeviceEncoderM2StateRaw := RawEncoderM2State,
    DeviceEncoderM2SimBypass := FALSE,
    NetworkBypassActive := GVL_IHM.Network.Bypass.Global
);

// 💓 2bis. Heartbeat IHM↔PLC (Fix CK6 : secours BlinkClock si IhmHeartbeat bypassé ou pas d'IHM)
instIhmHeartbeat(
    Enable := TRUE,
    TglHeartbeatIhm := SEL(GVL_IHM.Network.Bypass.IhmHeartbeat OR GVL_IHM.Network.Bypass.Global,
                           GVL_IHM.Commun.TglHeartbeatIhm,
                           GVL_Global.BlinkClock),
    IhmTimeout := T#2s,
    PlcTogglePeriod := T#500ms
);

// 3. Acquisition Joystick — RawX/RawY/RawButton lus depuis PRG_00_Inputs.HwIn.Operator
FB_Joystick_0(
    Enable              := TRUE,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    Mode                := PRG_04_Modes.instModes.Mode,  // 🆕 REX 2026-07-08 : désarme le homme-mort au changement de mode
    BenneBusy         := PRG_06_WinchControl.instBucket.Busy,
    NeutralXMem         := _JoystickNeutralX,
    NeutralYMem         := _JoystickNeutralY,
    BusCanOpenOP        := instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP          := instDiagCanOpen.DeviceJoystick,
    RawX                := PRG_00_Inputs.HwIn.Operator.JoyXRaw_ANA1,
    RawY                := PRG_00_Inputs.HwIn.Operator.JoyYRaw_ANA2,
    RawButton           := PRG_00_Inputs.HwIn.Operator.JoyBtnRaw,
    BtnCalibrate           := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
    InvertX             := _JoystickInvertX,       // 🔧 REX 2026-07-21 : depuis GVL_PERSISTENT
    InvertY             := _JoystickInvertY,       // 🔧 idem
    Deadband            := _JoystickDeadband_Pct,  // 🔧 REX 2026-07-21 : depuis GVL_PERSISTENT
    FilterTime          := _JoystickFilterTime,    // 🔧 idem
    AccelRate           := _JoystickAccelRate_Pct, // 🔧 idem
    DecelRate           := _JoystickDecelRate_Pct, // 🔧 idem
    // 🛡️ Délais de sécurité Homme-Mort : réordonnés aux valeurs réelles de production (10s / 500ms)
    DeadmanRearmTimeout := T#10S,
    NeutralHoldTime     := T#500MS
);
