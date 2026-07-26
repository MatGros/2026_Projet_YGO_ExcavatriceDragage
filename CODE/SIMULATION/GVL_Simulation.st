(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation — Bit maître + granularité par device (remplace GVL_DEBUG)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.4.md
   🎯 Rôle : le matériel réel (bus EtherCAT/CANopen, capteurs, contacteurs) n'étant
      pas disponible pour les essais, toute la machine doit pouvoir tourner en
      simulation CODESYS. Modèle hiérarchique :
        - `SimulationModeActive` = bit maître. `FALSE` (défaut depuis REX 2026-07-22) =
          machine réelle par défaut ; `TRUE` = TOUS les devices simulés d'un coup
          (bascule globale banc d'essai, plus l'état courant par défaut).
        - Un booléen `Bus<Device>IsReal`/`Sensor<Device>IsReal` par device/capteur permet
          de sortir CE device précis de la simulation un par un, au fur et à mesure du
          recâblage réel en mise en service — SANS modifier le code.
      État effectif "ce device est simulé" = `SimulationModeActive AND NOT <Device>IsReal`.
   🔧 REMPLACE `GVL_DEBUG.st` (6 flags indépendants ajoutés au coup par coup).
   🆕 REX 2026-07-22 : `BusJoystickIsReal`, `BusVariateurM3IsReal`, `BusEncoderM1/M2IsReal`
      et `BusIhmHeartbeatIsReal` pilotent maintenant SEULS le bypass diagnostic (Online/
      Operational/heartbeat) dans PRG_01_Diagnostics.st — DÉCOUPLÉS de `SimulationModeActive`.
      Objectif : garder ces bus/communication bypassables un par un même simulation
      globale coupée (banc sans IHM/CANopen/EtherCAT câblés). Les AUTRES devices
      (position codeur simulée, signaux joystick, capteurs, contacteurs, chaîne AU…)
      restent gardés par le bit maître comme avant.
   ⚠️ TOUJOURS repasser chaque `Bus*IsReal` diag (Joystick/VariateurM3/EncoderM1/EncoderM2/
      IhmHeartbeat) à `TRUE` au fur et à mesure du recâblage réel — ils ne suivent plus
      `SimulationModeActive`. Pour le reste des devices, `SimulationModeActive := FALSE`
      bascule tout d'un coup (ou `*IsReal` un par un, sans toucher au bit maître).
   📛 Convention nommage (session Bypass, voir DOC/NAMING_CONVENTION.md) :
      `Bus` = device bus de terrain, `Sensor` = capteur/retour câblé, `Sim` = valeur simulée
      calculée, `Tst` = outil/commande de test banc.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    SimulationModeActive       : BOOL := FALSE; // 🔑 Bit maître — 🆕 REX 2026-07-22 : défaut FALSE (machine réelle) ; TRUE = tout simulé d'un coup

    // ── Devices bus de terrain (EtherCAT/CANopen) — 1:1 avec les devices réels ──
    BusVariateurM3IsReal         : BOOL := FALSE; // AC600 EtherCAT (translation M3)
    BusEncoderM1IsReal           : BOOL := FALSE; // COD1 EtherCAT
    BusEncoderM2IsReal           : BOOL := FALSE; // COD2 EtherCAT
    BusJoystickIsReal            : BOOL := FALSE; // CANopen JOY1 — bus/nœud (CanOnline/CanOperational)
    // 🆕 REX 2026-07-08 (demande utilisateur) : granularité séparée du bus ci-dessus — permet de
    // câbler le joystick réel (signal analogique/CAN brut RawX/RawY/RawButton) tout en laissant le
    // bus/nœud CANopen (BusJoystickIsReal) simulé sain, pour tester le joystick physique avant que le
    // diagnostic CANopen/EtherCAT ne soit fiabilisé (sans faux défaut CAN pendant ce test).
    BusJoystickSignalIsReal      : BOOL := FALSE; // Signal joystick brut (RawX/RawY/RawButton uniquement)
    BusIhmHeartbeatIsReal        : BOOL := FALSE; // Heartbeat IHM Ethernet : FALSE = heartbeat simulé par GVL_Global.BlinkClock

    // ── Capteurs/retours câblés (I/O discrètes, indépendantes du bus) ──────────
    SensorEmergencyStopChainIsReal  : BOOL := FALSE; // Chaîne AU câblée (EmergencyStopOk_DI)
    SensorTopPositionIsReal   : BOOL := FALSE; // Fin de course haut commun M1/M2
    SensorSlackCableIsReal    : BOOL := FALSE; // Mou de câble M2
    SensorPhaseRotationIsReal     : BOOL := FALSE; // Contrôle rotation phases
    SensorM1ThermalIsReal           : BOOL := FALSE; // Thermique moteur M1
    SensorM2ThermalIsReal           : BOOL := FALSE; // Thermique moteur M2
    SensorBrakeThermalIsReal        : BOOL := FALSE; // 🆕 REX 2026-07-08 : thermique frein COMMUN M1/M2/M3 (1 seul fil)
    SensorM1ContactorFeedbackIsReal: BOOL := FALSE; // Retours contacteurs (sens + frein) treuil M1
    SensorM2ContactorFeedbackIsReal: BOOL := FALSE; // Retours contacteurs (sens + frein) treuil M2
    SensorM3ContactorFeedbackIsReal: BOOL := FALSE; // Retour contacteur (sens + frein) translation M3
    SensorTranslationPositionIsReal     : BOOL := FALSE; // Capteurs Trémie/PV/P2/P1/Maintenance
    SensorKoboldContactFondIsReal       : BOOL := FALSE; // Retour contact fond Kobold (%IX0.5)
    SensorHydraulicThermalIsReal        : BOOL := FALSE; // 🆕 REX 2026-07-18 : thermique centrale hydraulique (PRG_08_AuxiliaryControl)

    // ── Utilitaires banc d'essai (sans préfixe DBG_) ───────────────────────────
    TstJoystickForceNeutralRaw    : INT := 5000;   // Simule le retour au centre (RawX/RawY)
    TstJoystickForceMaxRaw        : INT := 10000;  // Simule une consigne à fond
    SimKoboldContactFondValue : BOOL := FALSE; // Simulation du contact fond Kobold

    // 🔧 REX 2026-07-07 : confort de test banc — accélère le déplacement des codeurs simulés
    // (FB_Sim_Encoder). 1.0 = comportement d'origine. Réglable à chaud, sans recompiler.
    // Sans rapport avec une calibration réelle — reste à 1.0 hors essais bancs.
    TstEncoderSpeedFactor      : REAL := 3.0;

    // 🆕 REX 2026-07-08 (4) — test banc : injecte un VRAI saut de position dans le compteur codeur
    // simulé (front montant), comme un glissement mécanique réel — pas un offset artificiel figé.
    // Permet de tester Concept 1 (arrêt rampe normale, écart mineur), Méca E (écart critique) ET
    // le rattrapage au joystick (SyncEnable=FALSE → bouger le treuil décalé → SyncEnable=TRUE),
    // puisque c'est une vraie position simulée, pas un overlay — le rattrapage la résorbe réellement.
    TstInjectSyncDeviationM1      : BOOL := FALSE; // Front montant = applique le saut sur M1
    TstInjectSyncDeviationM2      : BOOL := FALSE; // Front montant = applique le saut sur M2
    TstSyncDeviationOffsetM       : REAL := 0.5;   // Amplitude du saut (m) — > WinchSyncTolerance_M (0.25) 🔧 REX 2026-07-08 (5)
                                                  // pour tester Concept 1 ; > WinchCriticalSyncTolerance_M
                                                  // (2.0) pour tester Méca E
END_VAR
