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
    SimBypassActive := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusJoystickIsReal,
    NetworkBypassActive := GVL_IHM.Network.Bypass.Global
);

// 2. Diagnostics EtherCAT (variateur + 2 codeurs)
instDiagEthercat(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,          // 🔑 Bouton général machine
    DeviceVariateurStateRaw := RawVariateurState,
    DeviceVariateurSimBypass := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusVariateurM3IsReal,
    DeviceEncoderM1StateRaw := RawEncoderM1State,
    DeviceEncoderM1SimBypass := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusEncoderM1IsReal,
    DeviceEncoderM2StateRaw := RawEncoderM2State,
    DeviceEncoderM2SimBypass := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusEncoderM2IsReal,
    NetworkBypassActive := GVL_IHM.Network.Bypass.Global
);

// 💓 2bis. Heartbeat IHM↔PLC — appelé avant PRG_03_Safety pour fournir le statut même cycle.
// 🔧 REX 2026-07-24 (demande utilisateur, mise en service) : RE-COUPLÉ à SimulationModeActive
// (annule le découplage REX 2026-07-22, même raison qu'au §1/§2 ci-dessus). Bypass actif
// UNIQUEMENT si SimulationModeActive=TRUE ET BusIhmHeartbeatIsReal=FALSE. Sans IHM réelle sur
// banc (simulation active), BlinkClock fournit un toggle sain ; mettre BusIhmHeartbeatIsReal :=
// TRUE dès que la visu toggle réellement TglHeartbeatIhm.
instIhmHeartbeat(
    Enable := TRUE,
    TglHeartbeatIhm := SEL(GVL_PLC_Tests.OverrideIhmHeartbeatActive,
                              SEL(GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.BusIhmHeartbeatIsReal,
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
    BtnCalibrate           := GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate,
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
