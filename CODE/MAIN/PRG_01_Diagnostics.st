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
    instSimJoystick  : FB_Sim_Joystick;      // 🧪 Simulation joystick (Lot 3 — voir CODE/SIMULATION/)
    instIhmHeartbeat : FB_IhmHeartbeat;      // 💓 Surveillance IHM↔PLC, consommée par PRG_03_Safety
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_01_Diagnostics) ===

// 🧪 0. Simulation Joystick (Lot 3, priorité — voir CODE/SIMULATION/FB_Sim_Joystick.st) : appelée
// AVANT FB_Joystick_0 pour que ses sorties soient à jour au même cycle. Remplace l'ancien bypass
// homme-mort codé en dur dans FB_Joystick (GVL_DEBUG.DBG_DeadmanBypass_TEST) : quand
// NOT BusJoystickSignalIsReal, ses sorties remplacent les entrées brutes ci-dessous ; le homme-mort
// réel de FB_Joystick n'est plus jamais contourné.
// 🆕 REX 2026-07-08 : gardé désormais par BusJoystickSignalIsReal (PAS BusJoystickIsReal, qui ne
// couvre que le bus CANopen ci-dessous) — granularité séparée demandée par l'utilisateur : tester
// le signal joystick réel sans dépendre du diagnostic bus/nœud CANopen (encore simulé sain).
instSimJoystick(
    Enable          := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusJoystickSignalIsReal,
    NeutralRaw      := GVL_Simulation.TstJoystickForceNeutralRaw,
    MaxRaw          := GVL_Simulation.TstJoystickForceMaxRaw,
    // 🆕 REX 2026-07-19 : pilotage programmatique par la suite PLC_TESTS (SUITE_MODES)
    TestOverrideActive    := GVL_PLC_Tests.OverrideJoystickActive,
    TestOverrideRawX      := GVL_PLC_Tests.OverrideJoystickRawX,
    TestOverrideRawY      := GVL_PLC_Tests.OverrideJoystickRawY,
    TestOverrideRawButton := GVL_PLC_Tests.OverrideJoystickRawButton
);

// 1. Diagnostics CANopen — 🆕 REX 2026-07-08 : gardé par BusJoystickIsReal UNIQUEMENT (bus/nœud),
// indépendant de BusJoystickSignalIsReal (signal brut ci-dessus) — granularité séparée.
// 🆕 REX 2026-07-22 : bypass DÉCOUPLÉ de SimulationModeActive — BusJoystickIsReal seul pilote
// désormais ce bypass diag, pour rester actif même simulation globale coupée (banc sans bus
// CANopen câblé). Repasser BusJoystickIsReal := TRUE au câblage réel du bus/nœud CANopen.
instDiagCanOpen(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,
    CANbusOnline := (CANbus.GetBusState() = 1) OR (NOT GVL_Simulation.BusJoystickIsReal) OR GVL_IHM.Network.Bypass.Global, // 1 = ACTIVE (ou bypass)
    DeviceJoystickOnline := (JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() = DEVICE_STATE.RUNNING) OR (NOT GVL_Simulation.BusJoystickIsReal) OR GVL_IHM.Network.Bypass.Global
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
// 🆕 REX 2026-07-22 : bypass DÉCOUPLÉ de SimulationModeActive — Bus<Device>IsReal seul pilote
// désormais ce bypass diag par device, pour rester actif même simulation globale coupée (banc
// sans bus EtherCAT câblé). Repasser chaque Bus<Device>IsReal := TRUE au câblage réel.
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,          // 🔑 Bouton général machine
    DeviceVariateurOnline := (AC600_ECAT_Drive.GetDeviceState() = DEVICE_STATE.RUNNING) OR (NOT GVL_Simulation.BusVariateurM3IsReal) OR GVL_IHM.Network.Bypass.Global,
    DeviceVariateurState := SEL((NOT GVL_Simulation.BusVariateurM3IsReal) OR (AC600_ECAT_Drive.GetDeviceState() = DEVICE_STATE.RUNNING) OR GVL_IHM.Network.Bypass.Global, 0, 8),
    DeviceEncoderM1Online := (COD1_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING) OR (NOT GVL_Simulation.BusEncoderM1IsReal) OR GVL_IHM.Network.Bypass.Global,
    DeviceEncoderM1State := SEL((NOT GVL_Simulation.BusEncoderM1IsReal) OR (COD1_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING) OR GVL_IHM.Network.Bypass.Global, 0, 8),
    DeviceEncoderM2Online := (COD2_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING) OR (NOT GVL_Simulation.BusEncoderM2IsReal) OR GVL_IHM.Network.Bypass.Global,
    DeviceEncoderM2State := SEL((NOT GVL_Simulation.BusEncoderM2IsReal) OR (COD2_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING) OR GVL_IHM.Network.Bypass.Global, 0, 8)
);

// 💓 2bis. Heartbeat IHM↔PLC — appelé avant PRG_03_Safety pour fournir le statut même cycle.
// 🆕 REX 2026-07-22 : bypass DÉCOUPLÉ de SimulationModeActive — BusIhmHeartbeatIsReal seul
// pilote désormais ce bypass, pour rester actif même simulation globale coupée (IHM réelle pas
// encore câblée niveau visu). Sans IHM réelle sur banc, BlinkClock fournit un toggle sain ;
// mettre BusIhmHeartbeatIsReal := TRUE dès que la visu toggle réellement TglHeartbeatIhm.
instIhmHeartbeat(
    Enable := TRUE,
    TglHeartbeatIhm := SEL(GVL_PLC_Tests.OverrideIhmHeartbeatActive,
                              SEL(NOT GVL_Simulation.BusIhmHeartbeatIsReal,
                                  GVL_IHM.Commun.TglHeartbeatIhm,
                                  GVL_Global.BlinkClock),
                              GVL_PLC_Tests.OverrideIhmHeartbeatToggle),
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
    RawX                := SEL(instSimJoystick.Enable, JoyXRaw_ANA1, instSimJoystick.RawX),
    RawY                := SEL(instSimJoystick.Enable, JoyYRaw_ANA2, instSimJoystick.RawY),
    RawButton           := SEL(instSimJoystick.Enable, JoyBtnRaw, instSimJoystick.RawButton),
    BtnCalibrate           := GVL_IHM.JOY1Joystick.BtnCalibrate,
    InvertX             := _JoystickInvertX,       // 🔧 REX 2026-07-21 : depuis GVL_PERSISTENT
    InvertY             := _JoystickInvertY,       // 🔧 idem
    Deadband            := _JoystickDeadband_Pct,  // 🔧 REX 2026-07-21 : depuis GVL_PERSISTENT
    FilterTime          := _JoystickFilterTime,    // 🔧 idem
    AccelRate           := _JoystickAccelRate_Pct, // 🔧 idem
    DecelRate           := _JoystickDecelRate_Pct, // 🔧 idem
    // 🛡️ Délais de sécurité Homme-Mort : temporisations courtes (10s/500ms) si joystick réel, longues (5min/1s) si simulé
    DeadmanRearmTimeout := SEL(NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.BusJoystickSignalIsReal, T#5M, T#10S),
    NeutralHoldTime     := SEL(NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.BusJoystickSignalIsReal, T#1S, T#500MS)
);
