(* ═══════════════════════════════════════════════════════════════
   📡 PRG_01_Diagnostics — États bus de terrain et Joystick (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v3.0.md ; DOC/AF_Partie-08_Fonction_Joystick_v2.0.md
*)

PROGRAM PRG_01_Diagnostics
VAR
    instDiagCanOpen  : FB_Diag_CanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_Diag_Ethercat;      // Diagnostic EtherCAT (3 devices)
    instJoystick    : FB_Joystick;          // Traitement joystick (calib/filtre/rampe)
    instIhmHeartbeat : FB_Diag_IhmHeartbeat;      // 💓 Surveillance IHM↔PLC, consommée par PRG_SAFETY_CFC

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
// depuis l'image matérielle HwIn produite par PRG_ACQUISITION_CFC.
// C'est FB_Diag_CanOpen/FB_Diag_Ethercat qui décident désormais seuls Online/Operational/State
// (distinction INIT normal / SIMULATED bypass / READY réel / ERROR — voir en-tête de ces FB).
RawCanBusState    := PRG_ACQUISITION_CFC.HwIn.Operator.CanBusState;
RawJoystickState  := PRG_ACQUISITION_CFC.HwIn.Operator.JOY1_DeviceState;
RawVariateurState := PRG_ACQUISITION_CFC.HwIn.Translation.AC600_DeviceState;
RawEncoderM1State := PRG_ACQUISITION_CFC.HwIn.Winch.COD1_DeviceState;
RawEncoderM2State := PRG_ACQUISITION_CFC.HwIn.Winch.COD2_DeviceState;

// 1. Diagnostics CANopen — 🆕 REX 2026-07-08 : gardé par BusJoystickIsReal UNIQUEMENT (bus/nœud),
// indépendant de BusJoystickSignalIsReal (signal brut ci-dessus) — granularité séparée.
instDiagCanOpen(
    Enable := TRUE,
    Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    CANbusStateRaw := RawCanBusState,
    DeviceJoystickStateRaw := RawJoystickState,
    SimBypassActive := FALSE,
    NetworkBypassActive := GVL_IHM.Network.Bypass.Global
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,          // 🔑 Bouton général machine
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

// 3. Acquisition Joystick — RawX/RawY/RawButton lus depuis PRG_ACQUISITION_CFC.HwIn.Operator
instJoystick(
    Enable              := TRUE,
    PowerContactorEngaged     := PRG_INPUTS_LD.PowerContactorEngaged,
    Reset               := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    Mode                := PRG_MODES_CFC.Auth.Mode,  // 🆕 REX 2026-07-08 : désarme le homme-mort au changement de mode
    BenneBusy         := PRG_TREUILS_CFC.instBucket.Busy,
    PreserveArmingAfterBucket := PRG_TREUILS_CFC.instExtractionSequence.Busy
                                  AND (PRG_TREUILS_CFC.instExtractionSequence.ExtractionState = E_ExtractionSequenceState.CLOSING_BUCKET),
    NeutralXMem         := _JoystickNeutralX,
    NeutralYMem         := _JoystickNeutralY,
    BusCanOpenOP        := instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP          := instDiagCanOpen.DeviceJoystick,
    RawX                := PRG_ACQUISITION_CFC.HwIn.Operator.JoyXRaw_ANA1,
    RawY                := PRG_ACQUISITION_CFC.HwIn.Operator.JoyYRaw_ANA2,
    RawButton           := PRG_ACQUISITION_CFC.HwIn.Operator.JoyBtnRaw,
    BtnCalibrate           := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
    InvertX             := _JoystickInvertX,       // depuis GVL_PERSISTENT
    InvertY             := _JoystickInvertY,       // idem
    Deadband            := _JoystickDeadband_Pct,  // depuis GVL_PERSISTENT
    FilterTime          := _JoystickFilterTime,    // idem
    // 🛡️ Délais de sécurité Homme-Mort : réordonnés aux valeurs réelles de production (10s / 500ms)
    DeadmanRearmTimeout := T#10S,
    NeutralHoldTime     := T#500MS
);
