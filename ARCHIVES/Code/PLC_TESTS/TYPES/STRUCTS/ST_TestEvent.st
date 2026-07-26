// 🧪 Événement journalisé par le banc de test
TYPE ST_TestEvent :
STRUCT
    Sequence       : UDINT;
    Severity       : E_TestEventSeverity;
    SuiteId        : INT;
    CaseId         : INT;
    StepId         : INT;
    Code           : INT;
    Message        : STRING(160);
END_STRUCT
END_TYPE
