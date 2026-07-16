// ═══════════════════════════════════════════════════════════════
// 🧪 ST_PlcTestsHMI — Structure d'interface IHM pour les tests
// ═══════════════════════════════════════════════════════════════

TYPE ST_PlcTestsHMI :
STRUCT
    // 🎮 Commandes (boutons tactiles consommés par le manager)
    CmdRunAll        : BOOL;
    CmdRunSuite      : INT;   // >0 : suite N seule (auto-remis à 0)
    CmdRunCase       : INT;   // >0 avec CmdRunSuite : 1 cas (entrée = FirstStep/SETUP)
    CmdAbort         : BOOL;  // Abandon propre
    CmdClearReport   : BOOL;

    // 🚦 Progression (Lecture seule)
    RunState         : E_TestRunState;
    SimulationActive : BOOL;  // Miroir de la gate simulation (sinon boutons grisés)
    ActiveSuiteId    : INT;
    ActiveCaseId     : INT;
    ActiveStepId     : INT;
    ActiveSuiteName  : STRING(32);
    ActiveCaseName   : STRING(32);
    ActiveStepName   : STRING(32);
    StepElapsed      : TIME;  // Progression
    StepTimeoutPT    : TIME;  // Limite de l'étape courante
    CasesTotal       : INT;
    CasesPassed      : INT;
    CasesFailed      : INT;

    // 📊 Dernier run (Rapports par suite)
    Suites           : ARRAY[1..GVL_PLC_Tests_Const.MaxSuites] OF ST_TestSuiteReport;

    // 💓 Clignotant d'activité (Heartbeat actif en cours de run)
    Heartbeat        : BOOL;
END_STRUCT
END_TYPE
