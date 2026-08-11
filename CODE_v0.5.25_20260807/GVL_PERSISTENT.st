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
        CfgTopSensorPos_M := 8.5, // 🔧 REX 2026-08-07 (24bis) : correction, capteur physique réel à 8.5m
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 6.75 // 🔧 REX 2026-08-07 (25) : 7.5 -> 7.0 -> 6.75 (demande client)
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M1)
    _WinchM2CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5, // 🔧 REX 2026-08-07 (24bis) : correction, capteur physique réel à 8.5m
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0,
        CfgCableLimitAscent_M := 6.75 // 🔧 REX 2026-08-07 (25) : 7.5 -> 7.0 -> 6.75 (demande client)
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
            // 🔧 REX 2026-08-07 (23/23bis) : 0.05 -> 0.5 -> 1.0 -- avec l'anticipation inertie
            // (correctif 20/21bis), un écart résiduel après arrêt est normal, l'ancien seuil ne
            // matchait quasiment plus jamais.
            CoherenceLimitM  := 1.0
        ),
        CfgTimeoutDuration := T#30s
    ); // 🌉 Pont FB_CfgPersistBridge_BucketCfg
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)

    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz          : REAL := 50.0; // Fréquence max absolue M3 (Hz) — source unique
    // 🆕 2026-08-06 : ST_TranslationCfg — Translation n'avait pas de slot Cfg (contrairement à
    // ST_WinchHMI), les 3 vitesses de ralentissement n'étaient réglables qu'en dur ici (constat
    // terrain). Pont FB_CfgPersistBridge_TranslationCfg (Hmi := GVL_IHM.TranslationM3.Cfg).
    _TranslationCfgPersist : ST_TranslationCfg; // 🌉 Pont FB_CfgPersistBridge_TranslationCfg
    // 🆕 2026-08-06 (retour terrain, risque collision) : hauteur mini M1/M2 requise pour
    // autoriser la translation — actuellement 6,0 m (≈ CfgTopSensorPos_M 8,0 m - 2,0 m de marge),
    // réglage indépendant de la calibration homing : à revoir si CfgTopSensorPos_M change.
    _TranslationMinHeightM1M2_M     : REAL := 6.0;   // Hauteur mini M1 ET M2 pour autoriser translation (m)
    _TranslationRampAccelRate_Pct   : REAL := 40.0;  // Accélération translation (%/s) — défaut usine 40%
    _TranslationRampDecelNormal_Pct : REAL := 50.0;  // Décélération normale (%/s) — défaut usine 50%
    _TranslationRampDecelFast_Pct   : REAL := 100.0; // Décélération rapide SafeStop (%/s)
    _TranslationAutoSpeedCap_Pct    : REAL := 40.0;  // Plafond vitesse SEMI_AUTO (%)
    _TranslationSetFreq_Hz          : REAL := 20.0;  // 🚦 Consigne fréquence manuelle opérateur (Hz) — 20.0 = défaut usine (mise en service), recopie continue depuis 2026-08-06 (PRG_07_Supervision)

    // 📏 Positions calibrées repère Translation M3 (mètres)
    _TranslationPosMaintenance_M    : REAL := 0.0;   // Position origine (Maintenance)
    _TranslationPosP1_M             : REAL := 6.0;   // Position P1
    _TranslationPosP2_M             : REAL := 14.0;  // Position P2
    _TranslationPosPV_M             : REAL := 21.0;  // Position PV (Pré-ralentissement)
    _TranslationPosTremie_M         : REAL := 25.0;  // Position Trémie (Extrême gauche)
    _TranslationGainMetersPerHzSec  : REAL := 0.008333; // Ratio m/s par Hz (ex: 50 Hz = 0.416 m/s)
    // 🆕 2026-08-06 : reprise odométrie après reboot — recopie continue (PRG_05_Translation),
    // pas de bridge dédié (même doctrine que _TranslationSetFreq_Hz ci-dessus).
    _TranslationPosEstimated_M          : REAL := 0.0;   // Dernière position estimée connue (m)
    _TranslationPosEstimatedInitialized : BOOL := FALSE;  // TRUE dès la première calibration sur capteur

    // 🕹️ JOYSTICK
    _JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    _JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)
    _JoystickDeadbandRaw : INT := 300; // Zone morte joystick, compte brut ADC (0..10000) — REX 2026-07-02 : 5.0%→10.0% (250→500 raw) ; 🔧 2026-08-07 (demande client, mesure terrain) : bruit neutre observé ±200 → remplace le % par un réglage direct en compte brut, 300 (marge ~1.5x le bruit mesuré)
    _JoystickFilterTime : TIME := T#0ms; // Constante de temps filtre PT1 — 🔧 2026-08-07 (demande client) : filtrage supprimé (0ms = pass-through exact, voir FB_Filter_PT1.st "Si TimeConst=0, sortie=entrée"). Historique : 100ms initial → 50ms (2026-08-06, délai ressenti persistant) → 0ms (2026-08-07, suppression complète demandée)
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
        ExtractionControlDistance_M := 2.0,
        TglEnableDiveSearch := TRUE,
        TglEnableExtractionSequence := TRUE,
        TglEnableDumpAtTremie := TRUE
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
    ); // 🌉 Pont FB_CfgPersistBridge_CommunCfg (+ champs Winch communs M1/M2 rapatriés 2026-07-24)

    // 🚦 SYSTÈME / IHM
    _BlinkTimeOn  : TIME := T#1s;    // Durée allumé horloge clignotement système (voyants IHM/diag)
    _BlinkTimeOff : TIME := T#800ms; // Durée éteint — asymétrique par défaut (REX 2026-07-16)

    // 🧪 SIMULATION (Banc de test uniquement)
    _SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    _SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

END_VAR
