// ═══════════════════════════════════════════════════════════════
// 🧪 ST_PlcTestsStatus — États et progression des tests
// ═══════════════════════════════════════════════════════════════

TYPE ST_PlcTestsStatus :
STRUCT
    RunState         : E_TestRunState;
    SimulationActive : BOOL;       // TRUE si la simulation automate est active
    ActiveSuiteId    : INT;        // ID de la suite en cours (ex: 1)
    ActiveCaseId     : INT;        // ID du cas en cours
    ActiveStepId     : INT;        // ID de l'étape en cours
    ActiveSuiteName  : STRING(32); // Nom de la suite active
    ActiveCaseName   : STRING(32); // Nom du cas active
    ActiveStepName   : STRING(32); // Nom de l'étape active
    StepElapsed      : TIME;       // Temps écoulé dans l'étape active
    StepTimeoutPT    : TIME;       // Timeout de l'étape active
    CasesTotal       : INT;        // Nombre total de cas à jouer
    CasesPassed      : INT;        // Nombre de cas réussis
    CasesFailed      : INT;        // Nombre de cas en échec
    Heartbeat        : BOOL;       // Clignotant d'activité (3 pulses sur transition)
    FailureSummary   : STRING(255); // 🏷️ Détail des défauts du dernier run, TOUTES suites confondues (remonte Report.FailureSummary de chaque suite exécutée) — lisible sans creuser Suite*Validation
END_STRUCT
END_TYPE
