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
    VariateurM3_IsReal         : BOOL := FALSE; // AC600 EtherCAT (translation M3)
    EncoderM1_IsReal           : BOOL := FALSE; // COD1 EtherCAT
    EncoderM2_IsReal           : BOOL := FALSE; // COD2 EtherCAT
    Joystick_IsReal            : BOOL := FALSE; // CANopen JOY1 — bus/nœud (CanOnline/CanOperational)
    // 🆕 REX 2026-07-08 (demande utilisateur) : granularité séparée du bus ci-dessus — permet de
    // câbler le joystick réel (signal analogique/CAN brut RawX/RawY/RawButton) tout en laissant le
    // bus/nœud CANopen (Joystick_IsReal) simulé sain, pour tester le joystick physique avant que le
    // diagnostic CANopen/EtherCAT ne soit fiabilisé (sans faux défaut CAN pendant ce test).
    JoystickSignal_IsReal      : BOOL := FALSE; // Signal joystick brut (RawX/RawY/RawButton uniquement)

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
    ContactorFeedbackM3_IsReal: BOOL := FALSE; // Retour contacteur (sens + frein) translation M3
    TranslationPosition_IsReal     : BOOL := FALSE; // Capteurs Fosse1/Fosse2/Maintenance/Trémie

    // ── Utilitaires banc d'essai (sans préfixe DBG_) ───────────────────────────
    JoystickForceNeutralRaw    : INT := 5000;   // Simule le retour au centre (RawX/RawY)
    JoystickForceMaxRaw        : INT := 10000;  // Simule une consigne à fond

    // 🔧 REX 2026-07-07 : confort de test banc — accélère le déplacement des codeurs simulés
    // (FB_Sim_Encoder). 1.0 = comportement d'origine. Réglable à chaud, sans recompiler.
    // Sans rapport avec une calibration réelle — reste à 1.0 hors essais bancs.
    EncoderSimSpeedFactor      : REAL := 3.0;

    // 🆕 REX 2026-07-08 (4) — test banc : injecte un VRAI saut de position dans le compteur codeur
    // simulé (front montant), comme un glissement mécanique réel — pas un offset artificiel figé.
    // Permet de tester Concept 1 (arrêt rampe normale, écart mineur), Méca E (écart critique) ET
    // le rattrapage au joystick (SyncEnable=FALSE → bouger le treuil décalé → SyncEnable=TRUE),
    // puisque c'est une vraie position simulée, pas un overlay — le rattrapage la résorbe réellement.
    InjectSyncDeviationM1      : BOOL := FALSE; // Front montant = applique le saut sur M1
    InjectSyncDeviationM2      : BOOL := FALSE; // Front montant = applique le saut sur M2
    SyncDeviationOffsetM       : REAL := 0.5;   // Amplitude du saut (m) — > WinchSyncTolerance_M (0.25) 🔧 REX 2026-07-08 (5)
                                                  // pour tester Concept 1 ; > WinchCriticalSyncTolerance_M
                                                  // (2.0) pour tester Méca E
    
    // 🧪 Intégration Tests de validation
    CmdRunTests                : BOOL := FALSE; // 🔑 Lancement des tests de validation automate (FB_PLC_Tests_Management)
    TestInProgress             : BOOL;          // Test en cours d'exécution
    AllTestsPassed             : BOOL;          // Succès global : tous les scénarios validés 🟢
    TestFailed                 : BOOL;          // Échec détecté 🔴
    TC01_NominalArming_Ok      : BOOL;          // Statut TC-01 (Armement nominal & AU)
    TC02_RedundancyFault_Ok    : BOOL;          // Statut TC-02 (Contacteur collé)
    TC03_Lockout_Ok            : BOOL;          // Statut TC-03 (Lockout 5s)
    FailedTestCase             : INT;           // Index du scénario en échec
    
    // Signaux de surcharge internes (pilotés par le validateur de test)
    OverrideChainTrue          : BOOL;          // Force la boucle AU à TRUE
    OverrideChainFalse         : BOOL;          // Force la boucle AU à FALSE
    OverrideContactorFalse     : BOOL;          // Force le retour contacteur à FALSE
END_VAR
