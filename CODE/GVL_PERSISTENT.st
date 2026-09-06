(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine
   ⚠️ Survivent aux coupures, Reset Warm/Cold et Downloads.
   🔒 Données critiques de calibration et mise en service.
   ═══════════════════════════════════════════════════════════
    📄 Docs : DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md
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
    _WinchSpeedConfig : ST_fbWinchLoadEstimator_SpeedCfg := (
        MaxMeasuredSpeedMps    := 2.0,
        SpeedBandMaxMps        := [0.4, 0.8, 1.2, 1.6, 2.0],
        SpeedBandHysteresisMps := 0.05
    );
    _WinchLoadEstimateTable : ST_fbWinchLoadEstimator_Table;
    _WinchSymmetryCfgPersist : ST_fbWinch_Symmetry_Cfg; // Seuils initiaux à confirmer sur site
    _WinchSymmetryDataPersist : ST_fbWinch_Symmetry_Data; // Dernières/max mesures de symétrie

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
        CfgCableLimitDescent_M := -20.0
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M1)
    _WinchM2CfgPersist : ST_WinchCfg := (
        CfgTopSensorPos_M := 8.5, // Capteur physique réel à 8.5m
        CfgHomingTarget_M := 0.0,
        CfgRampAccelRate := 10.0,
        CfgRampDecelNormalRate := 150.0,
        CfgRampDecelFastRate := 400.0,
        CfgCableLimitDescent_M := -20.0
    ); // 🌉 Pont FB_CfgPersistBridge_WinchCfg (M2)

    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _SyncCfgPersist : ST_SyncCfg := (CfgSyncTolerance_M := 3.0, CfgSyncCriticalTolerance_M := 6.0); // 🌉 Pont FB_CfgPersistBridge_SyncCfg — seuils projet Warn 3.0m / Fault 6.0m
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
            CoherenceLimitM  := 1.0,
            // Anticipations d'inertie + zone de ralentissement jog — réglables IHM
            // (méca dynamique évolutive). Le point d'arrêt jog unitaire M2 et
            // l'acceptation d'état ouvert/fermé sont à Offset ± Anticipation ;
            // palier 1 forcé dans les JogSlowdownZoneM derniers mètres.
            CloseAnticipationM := 1.0,
            OpenAnticipationM  := 1.3,
            JogSlowdownZoneM   := 1.0
        ),
        CfgTimeoutDuration := T#60s
    ); // 🌉 Pont FB_CfgPersistBridge_BucketCfg
    _BucketState : ST_fbBucket_State; // État mécanique mémorisé (ouvert/fermé)

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
    _TranslationSetFreq_Hz          : REAL := 40.0;  // 🚦 Consigne fréquence manuelle opérateur (Hz) — 40.0 = défaut MES 2026-09-04, recopie continue (PRG_07_Supervision)

    // 📏 Positions calibrées repère Translation M3 (mètres)
    // ✅ Convention : 0 m = Trémie (Extrême gauche), 30 m = Maintenance (Extrême droite).
    // Distances NON-linéaires : Trémie(0)→PV(5)=5 m, PV(5)→P2(15)=10 m, P2(15)→P1(20)=5 m,
    // P1(20)→Maintenance(30)=10 m.
    _TranslationPosTremie_M         : REAL := 0.0;   // Position Trémie (Extrême gauche, origine)
    _TranslationPosPV_M             : REAL := 5.0;   // Position PV (Pré-ralentissement)
    _TranslationPosP2_M             : REAL := 15.0;  // Position P2
    _TranslationPosP1_M             : REAL := 20.0;  // Position P1
    _TranslationPosMaintenance_M    : REAL := 30.0;  // Position Maintenance (Extrême droite)
    _TranslationGainMetersPerHzSec  : REAL := 0.008333; // Ratio m/s par Hz (ex: 50 Hz = 0.416 m/s)
    // Reprise odométrie après reboot — recopie continue (PRG_05_Translation).
    _TranslationPosEstimated_M          : REAL := 0.0;   // Dernière position estimée connue (m)
    _TranslationPosEstimatedInitialized : BOOL := FALSE;  // TRUE dès la première calibration sur capteur

    // 🕹️ JOYSTICK
    _JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    _JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)
    _JoystickAccelRate_Pct : REAL := 50.0; // Accélération rampe (%/s)
    _JoystickDecelRate_Pct : REAL := 150.0; // Décélération rampe (%/s)
    // Réglages regroupés FB_Joystick (entrée Cfg). Remplace l'ancien _JoystickDeadbandRaw.
    // Pont persistant/IHM (FB_CfgPersistBridge_JoystickCfg) à câbler en Lot 2.
    _JoystickCfgPersist : ST_fbJoystick_Cfg := (DeadbandRaw := 300); // reste des champs = defaults ST_fbJoystick_Cfg

    // 🔄 CYCLE (dragage semi-automatique)
    _CycleCfgPersist : ST_CycleCfg := (SetDepth_M := -12.5, DepthStopMode := E_CycleDepthStopMode.KOBOLD_OR_SETPOINT, RaiseOffBottom_M := 0.5, CtrlAscentMaxStep := 1); // 🌉 Pont FB_CfgPersistBridge_CycleCfg

    // 🎯 CYCLE REFERENCEMENT MACHINE (homing) — reglage mise en service
    _CycleMachineHomingCfgPersist : ST_CycleMachineHomingCfg := (ForceStepTarget := 0); // 🌉 Pont FB_CfgPersistBridge_CycleMachineHomingCfg

    // 📏 RÉGLEMENTATION / LÉGAL
    _CommunCfgPersist : ST_CommunCfg := (
        LimitLegalDepthMinAllowed_M := -19.0,
        LimitLegalEnabled := TRUE,
        SelHomingApproachEnable := FALSE,
        WinchMaxStepDescent := 4,
        WinchMaxStepAscent := 5,
        WinchSlowdownDistanceTop_M := 0.5,
        WinchSlowdownDistanceBottom_M := 1.0,
        WinchSlowdownMaxStep := 1,
        CfgCableLimitAscent_M := 7.5
    ); // 🌉 Pont FB_CfgPersistBridge_CommunCfg

    // 🚦 SYSTÈME / IHM
    _BlinkTimeOn  : TIME := T#1s;    // Durée allumé horloge clignotement système (voyants IHM/diag)
    _BlinkTimeOff : TIME := T#800ms; // Durée éteint — asymétrique par défaut

    // 🔄 CYCLE SEMI-AUTO
    _CycleSampleCount : INT := 0;    // Compteur de prélèvements — RETAIN, survit à la coupure ; reset MAINT only

    // 🧪 SIMULATION (Banc de test uniquement)
    _SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    _SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

    // ⚙️ CONFIGURATION TECHNOLOGIQUE CODEUR COMMUNE M1/M2
    _EncoderCfgPersist : ST_fbEncoder_Cfg; // 🌉 Pont FB_CfgPersistBridge_fbEncoder_Cfg

    // 💾 APPRENTISSAGE VITESSE PAR PALIER — collecteur passif FB_WinchSpeedLearning
    _WinchSpeedLearnTable : ST_fbWinchSpeedLearning_Table; // Table RETAIN {axe x sens x charge/vide x palier}
    // Enveloppes de plausibilité par palier (bornes min/max de vitesse apprise, m/s) + seuil
    // d'échantillons. Valeurs initiales cohérentes avec _WinchSpeedConfig.SpeedBandMaxMps
    // [0.4, 0.8, 1.2, 1.6, 2.0] et _WinchSpeedStepTable.StepThreshold_Pct [20..100] — à
    // confirmer sur site (mise en service). RETAIN : données de calibration.
    _WinchSpeedLearnCfg : ST_fbWinchSpeedLearning_Cfg := (
        MinSpeedMps := [0.0, 0.3, 0.5, 0.8, 1.0],
        MaxSpeedMps := [0.5, 1.0, 1.5, 2.0, 2.5],
        MinSamples  := 3
    );

    // 🧭 RE-HOMING OBLIGATOIRE PAR AXE (AF-05 §4bis) — AJOUTÉ EN FIN DE LISTE
    // (mapping RETAIN positionnel : jamais d'insertion au milieu — NAMING_CONVENTION §pont persistant)
    // Armé dès qu'un override/bypass de position est EFFECTIF, quelle que soit la suite du cycle
    // (armement immédiat : aucune perte possible sur coupure / download en cours de maintenance).
    // Tant que vrai : SEMI_AUTO interdit pour l'axe (FB_Modes bascule en MAINT_N1).
    // Ne retombe QUE sur cycle de homing complet réussi (HomingLifecycle.Done ET Homed ET NON HomingSuspect).
    // ⚠️ Producteur unique de la décision : FB_Modes (PRG_03) ; cette GVL n'est que le miroir persistant.
    _MaintM1HomingRequired : BOOL := FALSE;  // 🧭 M1 : re-homing requis avant tout SEMI_AUTO
    _MaintM2HomingRequired : BOOL := FALSE;  // 🧭 M2 : re-homing requis avant tout SEMI_AUTO

END_VAR
