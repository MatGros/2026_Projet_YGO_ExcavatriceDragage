// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestFailAction — Actions à mener en cas d'échec
// ═══════════════════════════════════════════════════════════════

TYPE E_TestFailAction :
(
    FAIL_CONTINUE    := 0,  // Marque l'échec, branche NextOnFail (teardown -> case suivant)
    FAIL_ABORT_SUITE := 1   // Non-récupérable : teardown puis fin de suite
);
END_TYPE
