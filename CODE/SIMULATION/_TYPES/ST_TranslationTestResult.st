// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TranslationTestResult — Résultat plat de la suite Translation
// ───────────────────────────────────────────────────────────────
// 🎯 Vue synthétique lisible en 1 coup d'œil (IHM/Watch), en complément
//    du rapport détaillé existant ST_TestSuiteReport (Steps[]/Cases[]).
//    Alimenté par FB_TranslationReportFinalizer (CORE).
// ═══════════════════════════════════════════════════════════════

TYPE ST_TranslationTestResult :
STRUCT
    TerminalState    : E_TestTerminalState; // État terminal du dernier run (NONE tant qu'aucun run)
    RequestedCaseId  : INT;                 // CaseId demandé au dernier Start (0=tous, 1..6=case ciblée)
    ExecutedCaseId   : INT;                 // Dernier cas en cours/joué (0 si aucun)
    AllPassed        : BOOL;
    AnyFailed        : BOOL;
    FailedCaseId     : INT;                 // Premier cas en échec (0 = aucun)
    FailedCaseName   : STRING(32);
    FailReason       : E_TestFailReason;    // Cause du 1er cas en échec (FAIL_NONE si aucun)
    ErrorCode        : INT;
    ErrorMessage     : STRING(160);
    CasesTotal       : INT;
    CasesPassed      : INT;
    CasesFailed      : INT;
    Duration         : TIME;
    RunCounter       : UDINT;
END_STRUCT
END_TYPE
