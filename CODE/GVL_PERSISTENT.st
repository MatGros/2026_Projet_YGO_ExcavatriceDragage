(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine
   ⚠️ Survivent aux coupures, Reset Warm/Cold et Downloads.
   🔒 Données critiques de calibration et mise en service.
   ═══════════════════════════════════════════════════════════
    📄 Docs : DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md
*)

// {attribute 'qualified_only'} — Force l'accès via GVL_PERSISTENT.Variable (évite les conflits)
VAR_GLOBAL PERSISTENT RETAIN

    // 🏗️ TREUILS (M1, M2)
    _CalibM1 : ST_Encoder_Calib; // Calibration treuil M1
    _CalibM2 : ST_Encoder_Calib; // Calibration treuil M2

    _WinchSpeedStepTable : ST_SpeedStepTable := (
        P1R1 := FALSE, P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := FALSE, P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := FALSE, P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := FALSE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    ); // Table paliers commune (fusion M1/M2)
    // Caractérisation vitesse réelle ; valeurs initiales provisoires à mesurer.
    _WinchSpeedConfig : ST_WinchSpeedConfig := (
        MaxMeasuredSpeedMps    := 2.0,
        SpeedBandMaxMps        := [0.4, 0.8, 1.2, 1.6, 2.0],
        SpeedBandHysteresisMps := 0.05
    );
    _WinchLoadEstimateTable : ST_WinchLoadEstimateTable;
    _WinchSymmetryCfgPersist : ST_Winch_SymmetryCfg; // Seuils initiaux à confirmer sur site
    _WinchSymmetryDataPersist : ST_Winch_SymmetryData; // Dernières/max mesures de symétrie

    // 📐 Configuration treuil M1 — positions et rampes :
    //   • CfgTopSensorPos_M : position que le homing inscrit au déclenchement du capteur haut.
    //     Un écart ici décale TOUTES les positions machine (limites câble, légale, synchro).
    //   • CfgCableLimitAscent_M : limite logicielle de montée, maintenue SOUS le capteur physique
    //     (garde-fou ultime).
    //   • CfgRampAccelRate : rampe d'accélération des treuils (démarrage adouci).
    _WinchM1CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5, // Capteur physique réel à 8.5m
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 6.75 // Limite logicielle de montée (m)
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M1)
    _WinchM2CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5, // Capteur physique réel à 8.5m
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 6.75 // Limite logicielle de montée (m)
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M2)

    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _SyncCfgPersist : ST_SyncCfg := (CfgSyncTolerance_M := 0.8); // 🌉 Pont FB_CfgPersistBridge_SyncCfg (Zone 2: dégradation Palier 1 dès 0.8m)
    _WinchCriticalSyncTolerance_M : REAL := 2.5; // Méca E : écart critique (Zone 3: SafeStop dès 2.5m)
    _SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)

    // 🪣 BENNE
    // Offset M1/M2 en fermeture benne (m) — valeur à reconfirmer au premier essai benne en charge.
    _BucketCfgPersist : ST_BucketCfg := (
        Config := (
            OffsetOpenM      := 0.0,
            OffsetCloseM     := 15.0,
            // Avec l'anticipation inertie, un écart résiduel après arrêt est normal :
            // le seuil de cohérence tolère cet écart résiduel.
            CoherenceLimitM  := 1.0
        ),
        CfgTimeoutDuration := T#60s
    ); // 🌉 Pont FB_CfgPersistBridge_BucketCfg
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)

    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz          : REAL := 50.0; // Fréquence max absolue M3 (Hz) — source unique
    // ST_TranslationCfg — configuration des 3 vitesses de ralentissement de la translation,
    // pontée vers l'IHM (FB_CfgPersistBridge_TranslationCfg).
    _TranslationCfgPersist : ST_TranslationCfg; // 🌉 Pont FB_CfgPersistBridge_TranslationCfg
    // Hauteur mini M1/M2 requise pour autoriser la translation — actuellement 6,0 m
    // (≈ CfgTopSensorPos_M 8,0 m - 2,0 m de marge), réglage indépendant de la calibration homing :
    // à revoir si CfgTopSensorPos_M change.
    _TranslationMinHeightM1M2_M     : REAL := 6.0;   // Hauteur mini M1 ET M2 pour autoriser translation (m)
    _TranslationRampAccelRate_Pct   : REAL := 40.0;  // Accélération translation (%/s) — défaut usine 40%
    _TranslationRampDecelNormal_Pct : REAL := 50.0;  // Décélération normale (%/s) — défaut usine 50%
    _TranslationRampDecelFast_Pct   : REAL := 100.0; // Décélération rapide SafeStop (%/s)
    _TranslationAutoSpeedCap_Pct    : REAL := 40.0;  // Plafond vitesse SEMI_AUTO (%)
    _TranslationSetFreq_Hz          : REAL := 20.0;  // 🚦 Consigne fréquence manuelle opérateur (Hz) — 20.0 = défaut usine (mise en service), recopie continue (PRG_07_Supervision)

    // 📏 Positions calibrées repère Translation M3 (mètres)
    _TranslationPosMaintenance_M    : REAL := 0.0;   // Position origine (Maintenance)
    _TranslationPosP1_M             : REAL := 6.0;   // Position P1
    _TranslationPosP2_M             : REAL := 14.0;  // Position P2
    _TranslationPosPV_M             : REAL := 21.0;  // Position PV (Pré-ralentissement)
    _TranslationPosTremie_M         : REAL := 25.0;  // Position Trémie (Extrême gauche)
    _TranslationGainMetersPerHzSec  : REAL := 0.008333; // Ratio m/s par Hz (ex: 50 Hz = 0.416 m/s)
    // Reprise odométrie après reboot — recopie continue (PRG_05_Translation).
    _TranslationPosEstimated_M          : REAL := 0.0;   // Dernière position estimée connue (m)
    _TranslationPosEstimatedInitialized : BOOL := FALSE;  // TRUE dès la première calibration sur capteur

    // 🕹️ JOYSTICK
    _JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    _JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)
    _JoystickDeadbandRaw : INT := 300; // Zone morte joystick, compte brut ADC (0..10000) — bruit neutre observé ±200 → réglage direct en compte brut, 300 (marge ~1.5x le bruit mesuré)
    _JoystickFilterTime : TIME := T#0ms; // Constante de temps filtre PT1 — 0ms = pass-through exact (voir FB_Filter_PT1.st "Si TimeConst=0, sortie=entrée")
    _JoystickAccelRate_Pct : REAL := 50.0; // Accélération rampe (%/s)
    _JoystickDecelRate_Pct : REAL := 150.0; // Décélération rampe (%/s)
    _JoystickInvertX : BOOL := FALSE; // Inversion axe X
    _JoystickInvertY : BOOL := FALSE; // Inversion axe Y

    // 🔄 CYCLE (dragage semi-automatique)
    _CycleCfgPersist : ST_CycleCfg := (SetDepth_M := -12.5, SetOffset_M := 1.5); // 🌉 Pont FB_CfgPersistBridge_CycleCfg

    // 🪨 ASSISTANCE PRÉLÈVEMENT MAINTENANCE
    _DredgingAssistCfgPersist : ST_DredgingAssistCfg := (
        DiveStartMin_M := 1.0,
        ImmersionUpper_M := 0.5,
        ImmersionLower_M := -0.5,
        ExtractionControlDistance_M := 2.0,
        TglEnableDiveSearch := FALSE,
        TglEnableExtractionSequence := FALSE,
        TglEnableDumpAtTremie := FALSE
    ); // 🌉 Pont FB_CfgPersistBridge_DredgingAssistCfg

    // 📏 RÉGLEMENTATION / LÉGAL
    _CommunCfgPersist : ST_CommunCfg := (
        LimitLegalDepthMinAllowed_M := -15.0,
        LimitLegalEnabled := TRUE,
        SelHomingApproachEnable := FALSE,
        WinchMaxStepDescente := 3,
        WinchMaxStepAscent := 5,
        WinchSlowdownDistance_M := 1.0,
        WinchSlowdownMaxStep := 1
    ); // 🌉 Pont FB_CfgPersistBridge_CommunCfg

    // 🚦 SYSTÈME / IHM
    _BlinkTimeOn  : TIME := T#1s;    // Durée allumé horloge clignotement système (voyants IHM/diag)
    _BlinkTimeOff : TIME := T#800ms; // Durée éteint — asymétrique par défaut

    // 🔄 CYCLE SEMI-AUTO
    _CycleSampleCount : INT := 0;    // Compteur de prélèvements — RETAIN, survit à la coupure ; reset MAINT only

    // 🧪 SIMULATION (Banc de test uniquement)
    _SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    _SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

END_VAR
