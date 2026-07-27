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
    // valeurs brutes bus (évite d'appeler GetBusState()/GetDeviceState() deux fois par device :
    // une fois pour le test logique ci-dessous, une fois pour le miroir diag brut sur les FB).
    RawCanBusState    : INT;          // CANbus.GetBusState() brut
    RawJoystickState  : DEVICE_STATE; // JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() brut
    RawVariateurState : DEVICE_STATE; // AC600_ECAT_Drive.GetDeviceState() brut
    RawEncoderM1State : DEVICE_STATE; // COD1_CODEUR.GetDeviceState() brut
    RawEncoderM2State : DEVICE_STATE; // COD2_CODEUR.GetDeviceState() brut
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_01_Diagnostics) ===


// 🔧 REX 2026-07-24 (demande utilisateur, mise en service) : REFONTE — PRG_01 ne fait plus
// qu'ACQUÉRIR les valeurs brutes bus (GetBusState()/GetDeviceState()) et les flags de simulation ;
// c'est FB_DiagCanOpen/FB_DiagEthercat qui décident désormais seuls Online/Operational/State
// (distinction INIT normal / SIMULATED bypass / READY réel / ERROR — voir en-tête de ces FB).
// Values lues UNE fois par cycle (variables déclarées en VAR ci-dessus), réutilisées ci-dessous.
RawCanBusState    := CANbus.GetBusState();
RawJoystickState  := JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState();
RawVariateurState := AC600_ECAT_Drive.GetDeviceState();
RawEncoderM1State := COD1_CODEUR.GetDeviceState();
RawEncoderM2State := COD2_CODEUR.GetDeviceState();

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

// 3. Acquisition Joystick — RawX/RawY/RawButton simulés (instSimJoystick) quand NOT BusJoystickSignalIsReal
// 🔴🔧 REX 2026-07-07 — TEST BANC UNIQUEMENT, PAS DE VALEUR PRODUCTION :
//    DeadmanRearmTimeout 10s → 5min, NeutralHoldTime 500ms → 1s (confort d'essai, moins de
//    réappuis/traversées à gérer). ⚠️ RÉDUIT RÉELLEMENT LA SÉCURITÉ HOMME-MORT — à repasser
//    impérativement à T#10S / T#500MS (ou retirer ces 2 lignes, le FB reprend ses défauts sûrs)
//    avant toute mise en service réelle avec la machine.
FB_Joystick_0(
    Enable              := TRUE,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    Mode                := PRG_04_Modes.instModes.Mode,  // 🆕 REX 2026-07-08 : désarme le homme-mort au changement de mode
    // 🆕 REX 2026-07-08 : PRG_01 (position 1) s'exécute AVANT PRG_06 (position 6) — BenneBusy lu
    // ici reflète donc le Busy du scan PRÉCÉDENT (retard d'1 scan, ~10ms, sur la détection du front
    // descendant). Sans impact pratique : très inférieur aux temps de réponse frein/contacteurs
    // (100-300ms, voir FB_Brake) — la commande n'a pas le temps de produire un mouvement réel.
    BenneBusy         := PRG_06_WinchControl.instBucket.Busy,
    NeutralXMem         := _JoystickNeutralX,
    NeutralYMem         := _JoystickNeutralY,
    BusCanOpenOP        := instDiagCanOpen.DeviceCanOpenMaster,
    JoystickOP          := instDiagCanOpen.DeviceJoystick,
    RawX                := JoyXRaw_ANA1,
    RawY                := JoyYRaw_ANA2,
    RawButton           := JoyBtnRaw,
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
