// 🧪 État terminal explicite d'une suite ou du séquenceur
TYPE E_TestTerminalState :
(
    TEST_TERMINAL_NONE             := 0,
    TEST_TERMINAL_DONE             := 1,
    TEST_TERMINAL_FAILED           := 2,
    TEST_TERMINAL_ABORTED          := 3,
    TEST_TERMINAL_CONFIG_ERROR     := 4,
    TEST_TERMINAL_WATCHDOG_TIMEOUT := 5
);
END_TYPE
