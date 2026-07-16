// ═══════════════════════════════════════════════════════════════
// 🧪 ST_TestSuiteReport — Rapport d'une suite de tests
// ═══════════════════════════════════════════════════════════════

TYPE ST_TestSuiteReport :
STRUCT
    Name           : STRING(32);       // Nom de la suite de tests
    InProgress     : BOOL;             // Exécution en cours ?
    AllPassed      : BOOL;             // Tous les tests de la suite ont réussi ?
    AnyFailed      : BOOL;             // Au moins un échec détecté ?
    Aborted        : BOOL;             // Suite abandonnée ?
    FailedTestCase : INT;              // Premier cas de test en échec (0 si aucun)
    FailureSummary : STRING(255);      // 🏷️ TOUS les cas en échec en 1 ligne lisible (ex. 'TC-01 (step 15): FAIL_CHECK | TC-03 (step 30): FAIL_TIMEOUT') — évite de parcourir Cases[] un par un
    CurrentStepId  : INT;              // Étape en cours d'exécution
    CurrentCaseId  : INT;              // Cas de test en cours d'exécution
    Duration       : TIME;             // Durée totale du run de la suite
    RunCounter     : UDINT;            // Compteur de runs depuis le démarrage
    Steps          : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]     OF ST_TestStepResult;
    Cases          : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases] OF ST_TestCaseResult;
END_STRUCT
END_TYPE
