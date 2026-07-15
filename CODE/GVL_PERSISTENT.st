(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine
   ⚠️ Survivent aux coupures, Reset Warm/Cold et Downloads.
   🔒 Données critiques de calibration et mise en service.
   ═══════════════════════════════════════════════════════════ *)

// {attribute 'qualified_only'} (removed to allow direct access via prefix _) // Force l'accès via GVL_PERSISTENT.Variable (évite les conflits)
VAR_GLOBAL PERSISTENT RETAIN

    // 🏗️ TREUILS (M1, M2)
    _CalibM1 : ST_EncoderCalib; // Calibration treuil M1
    _CalibM2 : ST_EncoderCalib; // Calibration treuil M2
    _HomingTargetM1_M : REAL := 12.5; // Hauteur cible homing M1 (m)
    _HomingTargetM2_M : REAL := 12.5; // Hauteur cible homing M2 (m)

    _WinchSpeedStepTable : ST_SpeedStepTable := (
        P1R1 := FALSE, P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := FALSE, P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := FALSE, P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := FALSE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    ); // Table paliers commune (REX 2026-07-08 : fusion M1/M2)
    _WinchMaxStepDescent : INT := 3; // Palier max descente commun M1/M2

    _WinchM1RampAccelRate_Pct    : REAL := 50.0;
    _WinchM1RampDecelNormal_Pct  : REAL := 150.0;
    _WinchM1RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)
    _WinchM2RampAccelRate_Pct    : REAL := 50.0;
    _WinchM2RampDecelNormal_Pct  : REAL := 150.0;
    _WinchM2RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)

    _CableLimitM1Descent_M       : REAL := -20.0; // Limite basse physique M1 (m)
    _CableLimitM2Descent_M       : REAL := -20.0; // Limite basse physique M2 (m)
    _CableLimitM1Ascent_M        : REAL := 12.0;  // Limite haute exploitation M1 (m) < HomingTarget (12.5)
    _CableLimitM2Ascent_M        : REAL := 12.0;  // Limite haute exploitation M2 (m) < HomingTarget (12.5)
    _WinchSlowdownDistance_M     : REAL := 1.0;   // Distance ralentissement commune (m)
    _WinchSlowSpeed_Pct           : REAL := 15.0;  // Vitesse lente zone ralentissement (%)

    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    _WinchSyncTolerance_M : REAL := 0.25; // Tolérance écart (REX 2026-07-08 : 0.10 -> 0.25)
    _WinchCriticalSyncTolerance_M : REAL := 2.0; // Méca E : écart critique
    _SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)

    // 🪣 BENNE
    _BucketConfig : ST_BucketConfig := (
        OffsetOpenM      := 0.0,   // Position ouverture relative (m)
        OffsetCloseM     := 10.0,  // Position fermeture relative (m) - Valeur terrain
        CoherenceLimitM  := 0.05   // Tolérance cohérence (m)
    );
    _BucketState : ST_BucketState; // État mécanique mémorisé (ouvert/fermé)

    // ↔️ TRANSLATION (M3)
    _TranslationMaxFreq_Hz : REAL := 60.0; // Fréquence max absolue M3 (Hz)

    // 🕹️ JOYSTICK
    _JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    _JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)

    // 📏 RÉGLEMENTATION / LÉGAL
    _LimitLegalDepthMinAllowed_M   : REAL := -15.0; // Cote min dragage autorisée (m)
    _LimitLegalEnabled           : BOOL := TRUE;  // Activation limite légale

    // 🧪 SIMULATION (Banc de test uniquement)
    _SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    _SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

END_VAR
