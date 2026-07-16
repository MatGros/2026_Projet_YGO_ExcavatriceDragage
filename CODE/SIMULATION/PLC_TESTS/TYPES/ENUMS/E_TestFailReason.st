// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestFailReason — Raisons d'échec du test
// ═══════════════════════════════════════════════════════════════

TYPE E_TestFailReason :
(
    FAIL_NONE           := 0,
    FAIL_TIMEOUT        := 1,  // TimeoutPT écoulé sans pass (couvre "trop tard")
    FAIL_CHECK          := 2,  // CHECK_INSTANT faux, ou NEVER_DURING violé
    FAIL_INVARIANT      := 3,  // Invariant multi-étapes violé (voir FailedInvariantId)
    FAIL_WINDOW_EARLY   := 4,  // Pass survenu AVANT MinPT (réaction trop rapide = anormale)
    FAIL_ABORTED        := 5   // Abort commandé ou gate simulation perdu
);
END_TYPE
