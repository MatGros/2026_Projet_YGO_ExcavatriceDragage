(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine
   ⚠️ Survivent aux coupures, Reset Warm/Cold et Downloads.
   🔒 Données critiques de calibration et mise en service.
   ═══════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v3.1.md
*)

// {attribute 'qualified_only'} (removed to allow direct access via prefix _) // Force l'accès via GVL_PERSISTENT.Variable (évite les conflits)
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
    ); // Table paliers commune (REX 2026-07-08 : fusion M1/M2)
    // 🪜 T45 — caractérisation vitesse réelle ; valeurs initiales provisoires à mesurer.
    _WinchSpeedConfig : ST_WinchSpeedConfig := (
        MaxMeasuredSpeedMps    := 2.0,
        SpeedBandMaxMps        := [0.4, 0.8, 1.2, 1.6, 2.0],
        SpeedBandHysteresisMps := 0.05
    );
    _WinchLoadEstimateTable : ST_WinchLoadEstimateTable;
    _WinchSymmetryCfgPersist : ST_Winch_SymmetryCfg; // 🩺 D1 : seuils initiaux à confirmer sur site
    _WinchSymmetryDataPersist : ST_Winch_SymmetryData; // 🩺 D1 : dernières/max mesures MES-008

    // 📐 🆕 REX 2026-07-27 — valeurs alignées sur les relevés terrain (REGISTRE_Suivi_MiseEnService) :
    //   • CfgTopSensorPos_M 8.5 → 8.0  (MES-009 : déclenchement physique du capteur haut mesuré à 8,0 m).
    //     ⚠️ Ce n'est PAS un simple réglage : c'est la position que le homing inscrit au déclenchement
    //     du capteur. Un écart ici décale TOUTES les positions machine (limites câble, légale, synchro).
    //   • CfgCableLimitAscent_M 8.0 → 7.5 (MES-009 : arrêt réel observé ≈ 7,5 m — la limite logicielle
    //     doit rester SOUS le capteur physique, qui reste le garde-fou ultime).
    //   • CfgRampAccelRate 50.0 → 10.0 (MES-007 / T78 : adoucir le démarrage des treuils).
    _WinchM1CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.0,
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 7.5
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M1)
    _WinchM2CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.0,
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 7.5
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M2)

    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _SyncCfgPersist : ST_SyncCfg := (CfgSyncTolerance_M := 0.25); // 🌉 Pont FB_CfgPersistBridge_SyncCfg
    _WinchCriticalSyncTolerance_M : REAL := 2.0; // Méca E : écart critique
    _SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)

    // 🪣 BENNE
    // 🆕 REX 2026-07-27 — OffsetCloseM 10.0 → 15.0 : offset M1/M2 en fermeture benne mesuré à
    // ≈ 15 m sur site (MES-010). ⚠️ Le registre note la mesure comme "non encore analysée" :
    // valeur à reconfirmer au premier essai benne en charge.
    _BucketCfgPersist : ST_BucketCfg := (
        Config := (
            OffsetOpenM      := 0.0,
            OffsetCloseM     := 15.0,
            CoherenceLimitM  := 0.05
        ),
        CfgTimeoutDuration := T#30s
    ); // 🌉 Pont FB_CfgPersistBridge_BucketCfg
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)

    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz          : REAL := 50.0; // Fréquence max absolue M3 (Hz) — source unique
    _TranslationApproachSpeed_Hz    : REAL := 10.0; // Vitesse de ralentissement PV en Hz (approche Trémie)
    _TranslationRampAccelRate_Pct   : REAL := 20.0;  // Accélération translation (%/s)
    _TranslationRampDecelNormal_Pct : REAL := 40.0;  // Décélération normale (%/s)
    _TranslationRampDecelFast_Pct   : REAL := 100.0; // Décélération rapide SafeStop (%/s)
    _TranslationAutoSpeedCap_Pct    : REAL := 40.0;  // Plafond vitesse SEMI_AUTO (%)
    _TranslationSetFreq_Hz          : REAL := 0.0;   // 🚦 Consigne fréquence manuelle opérateur (Hz) — protégée depuis Lot 4

    // 📏 Positions calibrées repère Translation M3 (mètres)
    _TranslationPosMaintenance_M    : REAL := 0.0;   // Position origine (Maintenance)
    _TranslationPosP1_M             : REAL := 6.0;   // Position P1
    _TranslationPosP2_M             : REAL := 14.0;  // Position P2
    _TranslationPosPV_M             : REAL := 21.0;  // Position PV (Pré-ralentissement)
    _TranslationPosTremie_M         : REAL := 25.0;  // Position Trémie (Extrême gauche)
    _TranslationGainMetersPerHzSec  : REAL := 0.008333; // Ratio m/s par Hz (ex: 50 Hz = 0.416 m/s)

    // 🕹️ JOYSTICK
    _JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    _JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)
    _JoystickDeadband_Pct : REAL := 10.0; // Zone morte joystick (%) — REX 2026-07-02 : 5.0→10.0
    _JoystickFilterTime : TIME := T#100ms; // Constante de temps filtre PT1
    _JoystickAccelRate_Pct : REAL := 50.0; // Accélération rampe (%/s)
    _JoystickDecelRate_Pct : REAL := 150.0; // Décélération rampe (%/s)
    _JoystickInvertX : BOOL := FALSE; // Inversion axe X
    _JoystickInvertY : BOOL := FALSE; // Inversion axe Y

    // 🔄 CYCLE (dragage semi-automatique)
    _CycleCfgPersist : ST_CycleCfg := (SetDepth_M := -12.5, SetOffset_M := 1.5); // 🌉 Pont FB_CfgPersistBridge_CycleCfg (T66)

    // 🪨 ASSISTANCE PRÉLÈVEMENT MAINTENANCE — T81/T82
    _DredgingAssistCfgPersist : ST_DredgingAssistCfg := (
        DiveStartMin_M := 1.0,
        ImmersionUpper_M := 0.5,
        ImmersionLower_M := -0.5,
        ExtractionControlDistance_M := 2.0
    ); // 🌉 Pont FB_CfgPersistBridge_DredgingAssistCfg

    // 📏 RÉGLEMENTATION / LÉGAL
    _CommunCfgPersist : ST_CommunCfg := (
        LimitLegalDepthMinAllowed_M := -15.0,
        LimitLegalEnabled := TRUE,
        SelHomingApproachEnable := FALSE,
        WinchMaxStepDescente := 3,
        WinchMaxStepAscent := 5,
        WinchSlowdownDistance_M := 1.0,
        WinchSlowSpeed_Pct := 15.0
    ); // 🌉 Pont FB_CfgPersistBridge_CommunCfg (+ champs Winch communs M1/M2 rapatriés 2026-07-24)

    // 🚦 SYSTÈME / IHM
    _BlinkTimeOn  : TIME := T#1s;    // Durée allumé horloge clignotement système (voyants IHM/diag)
    _BlinkTimeOff : TIME := T#800ms; // Durée éteint — asymétrique par défaut (REX 2026-07-16)

    // 🧪 SIMULATION (Banc de test uniquement)
    _SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    _SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

END_VAR
