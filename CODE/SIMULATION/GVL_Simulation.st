(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation — Variables et stimuli de simulation (Banc d'essai)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.1.md
   📄 Lot L6 : Refonte à 5 flags principaux (1 bit maître + 4 domaines)
   🎯 Polarité positive : TRUE = simulé, FALSE = réel (par défaut).
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    // 🔑 Bit maître — rien n'est simulé si FALSE (machine réelle)
    SimulationModeActive        : BOOL := FALSE;

    // 🌐 Activation par domaine (simulé si SimulationModeActive AND Sim<Domaine>Active)
    SimWinchActive              : BOOL := FALSE; // M1+M2 : codeurs, contacteurs, freins, thermiques, capteur haut, câble tendu
    SimTranslationActive        : BOOL := FALSE; // AC600 : StatusWord/fréquence, 5 capteurs, frein M3
    SimOperatorActive           : BOOL := FALSE; // Joystick : bus CANopen + RawX/RawY/Button
    SimMachineActive            : BOOL := FALSE; // Chaîne AU, contacteur puissance, réarmement, phases, thermiques freins/hydraulique, Kobold

    // 🖐️ Stimuli de banc — ENTRÉES du modèle, jamais des forçages du programme
    SimM3SensorsWordActive      : BOOL := FALSE;
    SimM3SensorsWord            : BYTE := 16#01;

    SimJoystickRawX             : INT := 5000;
    SimJoystickRawY             : INT := 5000;
    SimJoystickRawButton        : BOOL := FALSE;

    SimKoboldContactValue       : BOOL := FALSE;
    SimEncoderSpeedFactor       : REAL := 1.0;   // ⚠️ Remis à 1.0 (défaut nominal)

    SimSyncDeviationInjectM1    : BOOL := FALSE;
    SimSyncDeviationInjectM2    : BOOL := FALSE;
    SimSyncDeviationOffset_M    : REAL := 0.5;
END_VAR
