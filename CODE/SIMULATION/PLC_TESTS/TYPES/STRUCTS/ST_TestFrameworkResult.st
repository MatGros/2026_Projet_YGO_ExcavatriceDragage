// 🧪 Résultat plat de l'autotest indépendant du framework
TYPE ST_TestFrameworkResult :
STRUCT
    InProgress   : BOOL;
    AllPassed    : BOOL;
    AnyFailed    : BOOL;
    CurrentTestId: INT;
    FailedTestId : INT;
    TestsPassed  : INT;
    TestsFailed  : INT;
    ErrorMessage : STRING(160);
    RunCounter   : UDINT;
END_STRUCT
END_TYPE
