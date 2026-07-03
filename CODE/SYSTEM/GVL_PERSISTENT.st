(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine (PERSISTENT RETAIN)
   ───────────────────────────────────────────────────────────────
   ⚠️ Ces variables survivent aux : coupures secteur, Reset Warm/Cold,
      ET aux téléchargements de programme (Download). Elles ne sont
      réinitialisées QUE par "Reset Origin" ou modification de structure.
   🔒 Toute valeur ici est un réglage de mise en service ou une calibration
      physique. Sa perte entraînerait un risque de casse matérielle ou
      de danger humain (position erronée, vitesse non régulée, etc.)
   📐 Convention de nommage : PascalCase strict + suffixe d'unité si REAL
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL PERSISTENT RETAIN

    // ═══════════════════════════════════════════════════════════
    // 🧲 CODEURS ABSOLUS — Données de homing (survit au Download)
    // ═══════════════════════════════════════════════════════════
    CalibM1 : ST_EncoderCalib; // 💾 Calibration treuil M1 : Homed, HomingRefRaw, LastKnownRawPos
    CalibM2 : ST_EncoderCalib; // 💾 Calibration treuil M2 : Homed, HomingRefRaw, LastKnownRawPos

    // Position du capteur de fin de course haut (réglée sur site)
    HomingTargetM1_M : REAL := 12.5; // 💾 Hauteur cible homing M1 (mètres) — ⚠️ perte = homing invalide
    HomingTargetM2_M : REAL := 12.5; // 💾 Hauteur cible homing M2 (mètres) — ⚠️ perte = homing invalide

    // ═══════════════════════════════════════════════════════════
    // 🕹️ JOYSTICK — Points neutres calibrés
    // ═══════════════════════════════════════════════════════════
    JoystickNeutralX : INT := 5000; // 💾 Point neutre axe X (valeur brute 0..10000)
    JoystickNeutralY : INT := 5000; // 💾 Point neutre axe Y (valeur brute 0..10000)

    // ═══════════════════════════════════════════════════════════
    // 🪜 TREUILS M1/M2 — Tables de paliers de vitesse
    //    Réglées sur site selon le câblage réel des 4 contacteurs
    //    ⚠️ Perte = paliers invalides → surintensité ou vitesse non régulée
    // ═══════════════════════════════════════════════════════════
    WinchM1SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );
    WinchM2SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // Limitation du palier en descente (1..5) — ⚠️ perte = descente trop rapide possible
    WinchM1MaxStepDescente : INT := 2; // 💾 Palier max descente M1
    WinchM2MaxStepDescente : INT := 2; // 💾 Palier max descente M2

    // Rampes de vitesse treuils — ⚠️ perte = SafeStop non calibré → risque de choc mécanique
    WinchM1RampAccelRate_Pct    : REAL := 50.0;  // 💾 Accélération M1 (%/s)
    WinchM1RampDecelNormal_Pct  : REAL := 150.0; // 💾 Décélération normale M1 (%/s)
    WinchM1RampDecelFast_Pct    : REAL := 400.0; // 💾 Décélération SafeStop M1 (%/s) — CRITIQUE
    WinchM2RampAccelRate_Pct    : REAL := 50.0;  // 💾 Accélération M2 (%/s)
    WinchM2RampDecelNormal_Pct  : REAL := 150.0; // 💾 Décélération normale M2 (%/s)
    WinchM2RampDecelFast_Pct    : REAL := 400.0; // 💾 Décélération SafeStop M2 (%/s) — CRITIQUE

    // 📐 PARAMÈTRES DE LIMITES DE DESCENTE ET DE RALENTISSEMENT SUR BORDURE (Nouveau 2026-07-03)
    WinchM1CableLimitDescent_M  : REAL := 20.0;  // 💾 Profondeur max / longueur de câble autorisée M1 (m)
    WinchM1SlowdownDistance_M   : REAL := 1.0;   // 💾 Distance de ralentissement M1 (m)
    WinchM1SlowSpeedPct         : REAL := 15.0;  // 💾 Vitesse lente dans la zone de ralentissement M1 (%)
    WinchM2CableLimitDescent_M  : REAL := 20.0;  // 💾 Profondeur max / longueur de câble autorisée M2 (m)
    WinchM2SlowdownDistance_M   : REAL := 1.0;   // 💾 Distance de ralentissement M2 (m)
    WinchM2SlowSpeedPct         : REAL := 15.0;  // 💾 Vitesse lente dans la zone de ralentissement M2 (%)

    // 📏 LIMITE LÉGALE DE DRAGAGE (Nouveau 2026-07-03)
    LimitLegal                  : ST_LimitLegal; // 💾 Configuration de la limite légale de profondeur

    // ═══════════════════════════════════════════════════════════
    // ⚖️ SYNCHRONISATION — Tolérance d'écart M1/M2
    // ═══════════════════════════════════════════════════════════
    WinchSyncTolerance_M : REAL := 0.10; // 💾 Écart max toléré entre M1/M2 (mètres) — réglé selon jeu mécanique

    // ═══════════════════════════════════════════════════════════
    // 🪣 GRAPPIN — Offsets de position et état mécanique mémorisé
    //    ⚠️ Perte OffsetCloseM → retour à 0 = grappin ne se ferme plus
    // ═══════════════════════════════════════════════════════════
    GrappinConfig : ST_GrappinConfig := (
        OffsetOpenM      := 0.0,   // 💾 Position d'ouverture relative (m)
        OffsetCloseM     := -1.5,  // 💾 Position de fermeture relative (m) — CRITIQUE
        CoherenceLimitM  := 0.05   // 💾 Tolérance cohérence grappin (m)
    );
    GrappinState : ST_GrappinState; // 💾 État mécanique mémorisé du grappin (ouvert/fermé)

    // ═══════════════════════════════════════════════════════════
    // 🏗️ PARAMÈTRES HISTORIQUES (hérités de PV, renommés aux normes)
    //    ⚠️ Perte = protections de fin de course perdues
    // ═══════════════════════════════════════════════════════════
    CableSafetyLimit_Pts   : UDINT; // 💾 Valeur max codeur pour sécurité longueur câble — CRITIQUE
    MotorAccelDuration_Ms  : WORD;  // 💾 Durée rampe accélération moteur (ms)
    AnalogInMin_Pts        : WORD;  // 💾 Calibrage borne min entrée analogique
    AnalogInMax_Pts        : WORD;  // 💾 Calibrage borne max entrée analogique
    AnalogOutMin_Pts       : WORD;  // 💾 Calibrage borne min sortie analogique
    AnalogOutMax_Pts       : WORD;  // 💾 Calibrage borne max sortie analogique

END_VAR
