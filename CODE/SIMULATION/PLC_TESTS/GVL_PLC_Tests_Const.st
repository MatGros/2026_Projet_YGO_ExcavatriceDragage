(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests_Const — Constantes de dimensionnement
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Définit les tailles limites des tables de tests
      pour l'orchestrateur et le moteur de tests.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL CONSTANT
    MaxTestCases     : INT := 8;    // par suite
    MaxSteps         : INT := 128;  // par suite, table PLATE ; WINCH-CORE-01 ajoute les étapes 65..111
    MaxChecks        : INT := 64;   // CheckTable par suite
    MaxChecksPerStep : INT := 10;
    MaxInvariants    : INT := 4;    // actifs en parallèle
    MaxProbeBool     : INT := 32;
    MaxProbeDint     : INT := 16;    // INT/WORD/étapes séquenceur → conversion au câblage (WORD_TO_DINT)
    MaxProbeReal     : INT := 16;    // analogiques + TIME → REAL ms
    MaxAnalogStims   : INT := 4;    // instances FB_TestStimulus par suite
    MaxSeqValues     : INT := 8;    // plus gros poste mémoire par stim
    TaskCycleMs      : INT := 10;   // MainTask — base des mesures en cycles
    MaxSuiteDurationMs : DINT := 180000; // 🛡️ garde-fou orchestrateur : 3 min maximum par suite
    MaxTestEvents    : INT := 32;   // journal circulaire des événements
    SuiteSafety      : INT := 1;    // index de suite (Cmd.RunSuite)
    SuiteTranslation : INT := 2;    // index de suite Translation M3 (Cmd.RunSuite)
    SuiteBucket      : INT := 3;    // index de suite Bucket (Cmd.RunSuite)
    SuiteEncoder     : INT := 4;    // index de suite Codeurs/Homing nominal (Cmd.RunSuite)
    SuiteModes       : INT := 5;    // index de suite Modes/Homme-mort, post-suppression IHM_MANU (Cmd.RunSuite)
    SuiteHeartbeat   : INT := 6;    // index de suite Heartbeat IHM↔PLC (Cmd.RunSuite)
END_VAR
