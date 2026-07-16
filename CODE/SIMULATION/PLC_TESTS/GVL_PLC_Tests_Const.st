(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests_Const — Constantes de dimensionnement
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Définit les tailles limites des tables de tests
      pour l'orchestrateur et le moteur de tests.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL CONSTANT
    MaxSuites        : INT := 4;
    MaxTestCases     : INT := 8;    // par suite
    MaxSteps         : INT := 64;   // par suite, table PLATE
    MaxChecks        : INT := 64;   // CheckTable par suite
    MaxChecksPerStep : INT := 4;
    MaxInvariants    : INT := 4;    // actifs en parallèle
    MaxProbeBool     : INT := 32;
    MaxProbeDint     : INT := 16;    // INT/WORD/étapes séquenceur → conversion au câblage (WORD_TO_DINT)
    MaxProbeReal     : INT := 16;    // analogiques + TIME → REAL ms
    MaxAnalogStims   : INT := 4;    // instances FB_TestStimulus par suite
    MaxSeqValues     : INT := 8;    // plus gros poste mémoire par stim
    TaskCycleMs      : INT := 10;   // MainTask — base des mesures en cycles
    SuiteSafety      : INT := 1;    // index de suite
END_VAR
