(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests_Const — Constantes de dimensionnement
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Définit les tailles limites des tables de tests
      pour l'orchestrateur et le moteur de tests.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL CONSTANT
    MaxTestCases     : INT := 8;    // par suite
    MaxSteps         : INT := 64;   // par suite, table PLATE ; tous les StepId doivent rester <= 64
    MaxChecks        : INT := 64;   // CheckTable par suite
    MaxChecksPerStep : INT := 4;
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
END_VAR
