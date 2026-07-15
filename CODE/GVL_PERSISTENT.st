(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine
   ⚠️ Survivent aux coupures, Reset Warm/Cold et Downloads.
   🔒 Données critiques de calibration et mise en service.
   ═══════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'} // Force l'accès via GVL_PERSISTENT.Variable (évite les conflits)
VAR_GLOBAL PERSISTENT RETAIN

    // 🏗️ TREUILS (M1, M2)
    CalibM1 : ST_EncoderCalib; // Calibration treuil M1
    CalibM2 : ST_EncoderCalib; // Calibration treuil M2
    HomingTargetM1_M : REAL := 12.5; // Hauteur cible homing M1 (m)
    HomingTargetM2_M : REAL := 12.5; // Hauteur cible homing M2 (m)

    WinchSpeedStepTable : ST_SpeedStepTable := (
        P1R1 := FALSE, P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := FALSE, P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := FALSE, P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := FALSE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    ); // Table paliers commune (REX 2026-07-08 : fusion M1/M2)
    WinchMaxStepDescente : INT := 3; // Palier max descente commun M1/M2

    WinchM1RampAccelRate_Pct    : REAL := 50.0;
    WinchM1RampDecelNormal_Pct  : REAL := 150.0;
    WinchM1RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)
    WinchM2RampAccelRate_Pct    : REAL := 50.0;
    WinchM2RampDecelNormal_Pct  : REAL := 150.0;
    WinchM2RampDecelFast_Pct    : REAL := 400.0; // CRITIQUE (SafeStop)

    CableLimitDescentM1_M       : REAL := -20.0; // Limite basse physique M1 (m)
    CableLimitDescentM2_M       : REAL := -20.0; // Limite basse physique M2 (m)
    CableLimitAscentM1_M        : REAL := 12.0;  // Limite haute exploitation M1 (m) < HomingTarget (12.5)
    CableLimitAscentM2_M        : REAL := 12.0;  // Limite haute exploitation M2 (m) < HomingTarget (12.5)
    WinchSlowdownDistance_M     : REAL := 1.0;   // Distance ralentissement commune (m)
    WinchSlowSpeedPct           : REAL := 15.0;  // Vitesse lente zone ralentissement (%)

    // ⚖️ SYNCHRONISATION (M1 ↔ M2)
    WinchSyncTolerance_M : REAL := 0.25; // Tolérance écart (REX 2026-07-08 : 0.10 -> 0.25)
    WinchCriticalSyncTolerance_M : REAL := 2.0; // Méca E : écart critique
    SyncSoftStopEnable : BOOL := FALSE; // Rattrapage directionnel (Défaut: OFF)

    // 🪣 GRAPPIN
    GrappinConfig : ST_GrappinConfig := (
        OffsetOpenM      := 0.0,   // Position ouverture relative (m)
        OffsetCloseM     := 10.0,  // Position fermeture relative (m) - Valeur terrain
        CoherenceLimitM  := 0.05   // Tolérance cohérence (m)
    );
    GrappinState : ST_GrappinState; // État mécanique mémorisé (ouvert/fermé)

    // ↔️ CHARIOT (M3)
    ChariotMaxFreqHz : REAL := 50.0; // Fréquence max absolue M3 (Hz)

    // 🕹️ JOYSTICK
    JoystickNeutralX : INT := 5000; // Point neutre axe X (0..10000)
    JoystickNeutralY : INT := 5000; // Point neutre axe Y (0..10000)

    // 📏 RÉGLEMENTATION / LÉGAL
    LimitLegalDepthMinAllowed   : REAL := -15.0; // Cote min dragage autorisée (m)
    LimitLegalEnabled           : BOOL := TRUE;  // Activation limite légale

    // 🧪 SIMULATION (Banc de test uniquement)
    SimEncoderRawPosM1 : UDINT := 1000000; // Simulation : survit au reset froid
    SimEncoderRawPosM2 : UDINT := 1000000; // Simulation : survit au reset froid

END_VAR
