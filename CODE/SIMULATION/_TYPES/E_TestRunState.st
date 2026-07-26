// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestRunState — États d'exécution d'un test
// ═══════════════════════════════════════════════════════════════

TYPE E_TestRunState :
(
    TESTRUN_IDLE    := 0,
    TESTRUN_RUNNING := 1,
    TESTRUN_PASSED  := 2,
    TESTRUN_FAILED  := 3,
    TESTRUN_ABORTED := 4
);
END_TYPE
