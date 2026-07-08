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
    instSimJoystick  : FB_Sim_Joystick;      // 🧪 Simulation joystick (Lot 3 — voir CODE/SIMULATION/)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_01_Diagnostics) ===

// 🧪 0. Simulation Joystick (Lot 3, priorité — voir CODE/SIMULATION/FB_Sim_Joystick.st) : appelée
// AVANT FB_Joystick_0 pour que ses sorties soient à jour au même cycle. Remplace l'ancien bypass
// homme-mort codé en dur dans FB_Joystick (GVL_DEBUG.DBG_DeadmanBypass_TEST) : quand
// NOT Joystick_IsReal, ses sorties remplacent les entrées brutes ci-dessous ; le homme-mort réel
// de FB_Joystick n'est plus jamais contourné.
instSimJoystick(
    Enable          := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.Joystick_IsReal,
    NeutralRaw      := GVL_Simulation.JoystickForceNeutralRaw,
    MaxRaw          := GVL_Simulation.JoystickForceMaxRaw
);

// 1. Diagnostics CANopen
instDiagCanOpen(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,
    CanOnline := (CANbus.GetBusState() = 1) OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.Joystick_IsReal), // 1 = ACTIVE (ou simulation)
    CanOperational := (JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() = DEVICE_STATE.RUNNING) OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.Joystick_IsReal)
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,          // 🔑 Bouton général machine
    VariateurWcState := (AC600_ECAT_Drive.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.VariateurM3_IsReal),
    VariateurSlaveState := SEL((GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.VariateurM3_IsReal) OR (AC600_ECAT_Drive.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM1WcState := (COD1_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal),
    EncoderM1SlaveState := SEL((GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM1_IsReal) OR (COD1_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM2WcState := (COD2_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM2_IsReal),
    EncoderM2SlaveState := SEL((GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EncoderM2_IsReal) OR (COD2_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8)
);

// 3. Acquisition Joystick — RawX/RawY/RawButton simulés (instSimJoystick) quand NOT Joystick_IsReal
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
    // 🆕 REX 2026-07-08 : PRG_01 (position 1) s'exécute AVANT PRG_06 (position 6) — GrappinBusy lu
    // ici reflète donc le Busy du scan PRÉCÉDENT (retard d'1 scan, ~10ms, sur la détection du front
    // descendant). Sans impact pratique : très inférieur aux temps de réponse frein/contacteurs
    // (100-300ms, voir FB_Brake) — la commande n'a pas le temps de produire un mouvement réel.
    GrappinBusy         := PRG_06_WinchControl.instGrappin.Busy,
    NeutralXMem         := GVL_PERSISTENT.JoystickNeutralX,
    NeutralYMem         := GVL_PERSISTENT.JoystickNeutralY,
    BusCanOpenOP        := instDiagCanOpen.busCanOpen,
    JoystickOP          := instDiagCanOpen.Joystick,
    RawX                := SEL(instSimJoystick.Enable, JoyXRaw_ANA1, instSimJoystick.RawX),
    RawY                := SEL(instSimJoystick.Enable, JoyYRaw_ANA2, instSimJoystick.RawY),
    RawButton           := SEL(instSimJoystick.Enable, JoyBtnRaw, instSimJoystick.RawButton),
    Calibrate           := GVL_IHM.Joystick.Calibrate,
    InvertX             := FALSE,
    InvertY             := FALSE,
    Deadband            := 10.0,
    FilterTime          := TIME#100ms,
    AccelRate           := 50.0,
    DecelRate           := 150.0,
    DeadmanRearmTimeout := T#5M,    // 🔴 TEST BANC — défaut sûr T#10S, voir bandeau ci-dessus
    NeutralHoldTime     := T#1S     // 🔴 TEST BANC — défaut sûr T#500MS, voir bandeau ci-dessus
);
