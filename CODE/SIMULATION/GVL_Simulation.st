(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation — Bit maître + granularité par device (remplace GVL_DEBUG)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie13_Fonction_Simulation_v1.0.md
   🎯 Rôle : le matériel réel (bus EtherCAT/CANopen, capteurs, contacteurs) n'étant
      pas disponible pour les essais, toute la machine doit pouvoir tourner en
      simulation CODESYS. Modèle hiérarchique :
        - `SimulationModeActive` = bit maître. `TRUE` (défaut) = TOUS les devices
          sont simulés par défaut.
        - Un booléen `<Device>_IsReal` par device/capteur permet de sortir CE
          device précis de la simulation un par un, au fur et à mesure du
          recâblage réel en mise en service — SANS modifier le code.
      État effectif "ce device est simulé" = `SimulationModeActive AND NOT <Device>_IsReal`.
   🔧 REMPLACE `GVL_DEBUG.st` (6 flags indépendants ajoutés au coup par coup).
   ⚠️ TOUJOURS repasser `SimulationModeActive` à `FALSE` avant exploitation réelle
      avec la machine effectivement câblée (ou basculer chaque `_IsReal` à `TRUE`
      au fur et à mesure du recâblage, sans toucher au bit maître).
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    SimulationModeActive       : BOOL := TRUE;  // 🔑 Bit maître — FALSE = tout redevient réel d'un coup

    // ── Devices bus de terrain (EtherCAT/CANopen) — 1:1 avec les devices réels ──
    VariateurM3_IsReal         : BOOL := FALSE; // AC600 EtherCAT (chariot M3)
    EncoderM1_IsReal           : BOOL := FALSE; // COD1 EtherCAT
    EncoderM2_IsReal           : BOOL := FALSE; // COD2 EtherCAT
    Joystick_IsReal            : BOOL := FALSE; // CANopen JOY1

    // ── Capteurs/retours câblés (I/O discrètes, indépendantes du bus) ──────────
    EmergencyStopChain_IsReal  : BOOL := FALSE; // Chaîne AU câblée (EmergencyStopOk_DI)
    TopPositionSensor_IsReal   : BOOL := FALSE; // Fin de course haut commun M1/M2
    SlackCableSwitch_IsReal    : BOOL := FALSE; // Mou de câble M2
    PhaseRotationOk_IsReal     : BOOL := FALSE; // Contrôle rotation phases
    ThermalM1_IsReal           : BOOL := FALSE; // Thermique moteur M1
    ThermalM2_IsReal           : BOOL := FALSE; // Thermique moteur M2
    BrakeThermal_IsReal        : BOOL := FALSE; // 🆕 REX 2026-07-08 : thermique frein COMMUN M1/M2/M3 (1 seul fil)
    ContactorFeedbackM1_IsReal: BOOL := FALSE; // Retours contacteurs (sens + frein) treuil M1
    ContactorFeedbackM2_IsReal: BOOL := FALSE; // Retours contacteurs (sens + frein) treuil M2
    ContactorFeedbackM3_IsReal: BOOL := FALSE; // Retour contacteur (sens + frein) chariot M3
    ChariotPosition_IsReal     : BOOL := FALSE; // Capteurs Fosse1/Fosse2/Maintenance/Trémie

    // ── Utilitaires banc d'essai (sans préfixe DBG_) ───────────────────────────
    JoystickForceNeutralRaw    : INT := 5000;   // Simule le retour au centre (RawX/RawY)
    JoystickForceMaxRaw        : INT := 10000;  // Simule une consigne à fond

    // 🔧 REX 2026-07-07 : confort de test banc — accélère le déplacement des codeurs simulés
    // (FB_Sim_Encoder). 1.0 = comportement d'origine. Réglable à chaud, sans recompiler.
    // Sans rapport avec une calibration réelle — reste à 1.0 hors essais bancs.
    EncoderSimSpeedFactor      : REAL := 3.0;
END_VAR
