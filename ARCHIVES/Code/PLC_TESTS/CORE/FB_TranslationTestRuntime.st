// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationTestRuntime — Cycle de vie protégé Translation M3
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : posséder le lifecycle atomique du run :
//    IDLE → RUN → CLEANUP → WAIT_NEUTRAL → VERIFY → TERMINAL.
// 🔒 Aucun terminal n'est publié avant neutralité confirmée.
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationTestRuntime
VAR_INPUT
    Start   : BOOL;
    Abort   : BOOL;
    CaseId  : INT;
    PlanConfigError         : BOOL;
    PlanConfigErrorStepId   : INT;
    PlanConfigErrorCheckIdx : INT;
    PlanConfigErrorMessage  : STRING(160);
    SimulationModeActive    : BOOL;
    SimGateOk               : BOOL;
    NeutralConfirmed        : BOOL; // Neutralité réellement appliquée au scan précédent
    WatchdogLimitMs         : DINT := 180000; // Paramétrable pour autotest du framework
    CleanupTimeoutScans     : INT := 20;      // Délai max de confirmation du neutre
END_VAR
VAR_IN_OUT
    StepTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
    ProbeBool  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool]  OF BOOL;
    ProbeDint  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint]  OF DINT;
    ProbeReal  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal]  OF REAL;
    Report     : ST_TestSuiteReport;
    Result     : ST_TranslationTestResult;
END_VAR
VAR_OUTPUT
    Busy                : BOOL;
    Done                : BOOL;
    AnyFailed           : BOOL;
    ActiveStimulusId    : INT;
    StepElapsed         : TIME;
    TerminalState       : E_TestTerminalState;
    ConfigError         : BOOL;
    ConfigErrorStepId   : INT;
    ConfigErrorCheckIdx : INT;
    ErrorCode           : INT;
    ErrorMessage        : STRING(160);
    StartRejected       : BOOL; // Impulsion : Start reçu hors IDLE/TERMINAL
    CleanupRequest      : BOOL; // Niveau : imposer le vecteur neutre complet
END_VAR
VAR CONSTANT
    RuntimeIdle        : INT := 0;
    RuntimeRun         : INT := 10;
    RuntimeCleanup     : INT := 20;
    RuntimeWaitNeutral : INT := 30;
    RuntimeVerify      : INT := 40;
    RuntimeTerminal    : INT := 50;
END_VAR
VAR
    instFixture   : FB_TranslationTestFixture;
    instExecutor  : FB_TranslationStepExecutor;
    instFinalizer : FB_TranslationReportFinalizer;
    StartTrig     : R_TRIG;
    RuntimeState  : INT := 0;
    ExecutorStart : BOOL;
    ExecutorAbort : BOOL;
    RunStartPulse : BOOL;
    FinalizePulse : BOOL;
    PendingTerminalState : E_TestTerminalState;
    PendingErrorCode     : INT;
    PendingErrorMessage  : STRING(160);
    SuiteElapsed         : TIME;
    NeutralWaitScans     : INT;
    CleanupElapsedScans  : INT;
END_VAR
// === IMPLEMENTATION ===
StartTrig(CLK := Start);
StartRejected := FALSE;
ExecutorStart := FALSE;
ExecutorAbort := FALSE;
RunStartPulse := FALSE;
FinalizePulse := FALSE;
CleanupRequest := (RuntimeState = RuntimeCleanup)
               OR (RuntimeState = RuntimeWaitNeutral)
               OR (RuntimeState = RuntimeVerify);

// 🎮 Un Start pendant un run/cleanup est refusé sans modifier le run actif.
IF StartTrig.Q AND RuntimeState <> RuntimeIdle AND RuntimeState <> RuntimeTerminal THEN
    StartRejected := TRUE;
END_IF;

// 🚪 Fixture appelée CHAQUE scan : son R_TRIG interne est ainsi toujours réarmé.
instFixture(CheckRequested := StartTrig.Q,
            SimulationModeActive := SimulationModeActive,
            SimGateOk := SimGateOk);

// 🟢 Nouveau run accepté depuis IDLE ou TERMINAL.
IF StartTrig.Q AND (RuntimeState = RuntimeIdle OR RuntimeState = RuntimeTerminal) THEN
    RunStartPulse := TRUE;
    Done := FALSE;
    SuiteElapsed := T#0s;
    NeutralWaitScans := 0;
    CleanupElapsedScans := 0;
    PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    PendingErrorCode := 0;
    PendingErrorMessage := '';

    IF PlanConfigError THEN
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        PendingErrorCode := 1002;
        PendingErrorMessage := CONCAT('Table invalide : ', PlanConfigErrorMessage);
        RuntimeState := RuntimeCleanup;
    ELSIF CaseId < 0 OR CaseId > 6 THEN
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        PendingErrorCode := 1001;
        PendingErrorMessage := 'CaseId invalide (attendu 0..6)';
        RuntimeState := RuntimeCleanup;
    ELSIF instFixture.FixtureFailed THEN
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_PRECONDITION_FAILED;
        PendingErrorCode := 1010;
        PendingErrorMessage := CONCAT('PRECONDITION_FAILED : ', instFixture.FailReason);
        RuntimeState := RuntimeCleanup;
    ELSE
        ExecutorStart := TRUE;
        RuntimeState := RuntimeRun;
    END_IF;
END_IF;

// 🛡️ Causes de sortie du RUN : watchdog > gate perdue > abort opérateur.
IF RuntimeState = RuntimeRun THEN
    SuiteElapsed := SuiteElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
    IF SuiteElapsed >= DINT_TO_TIME(WatchdogLimitMs) THEN
        ExecutorAbort := TRUE;
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_WATCHDOG_TIMEOUT;
        PendingErrorCode := 1020;
        PendingErrorMessage := 'Watchdog suite Translation expire';
    ELSIF NOT SimulationModeActive OR NOT SimGateOk THEN
        ExecutorAbort := TRUE;
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_PRECONDITION_FAILED;
        PendingErrorCode := 1011;
        PendingErrorMessage := 'Gate Translation perdue pendant le run';
    ELSIF Abort THEN
        ExecutorAbort := TRUE;
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
        PendingErrorCode := 1030;
        PendingErrorMessage := 'Abandon operateur';
    END_IF;
END_IF;

// 🪜 L'exécuteur ne possède que les étapes, jamais le terminal public.
instExecutor(
    Start := ExecutorStart,
    Abort := ExecutorAbort,
    CaseId := CaseId,
    StepTable := StepTable,
    CheckTable := CheckTable,
    CaseTable := CaseTable,
    ProbeBool := ProbeBool,
    ProbeDint := ProbeDint,
    ProbeReal := ProbeReal
);

IF RuntimeState = RuntimeRun AND instExecutor.RunDone THEN
    IF PendingTerminalState = E_TestTerminalState.TEST_TERMINAL_NONE THEN
        PendingTerminalState := instExecutor.TerminalState;
        IF instExecutor.ConfigError THEN
            PendingErrorCode := 1003;
            PendingErrorMessage := 'Garde-fou runtime : transition invalide';
        END_IF;
    END_IF;
    RuntimeState := RuntimeCleanup;
    NeutralWaitScans := 0;
END_IF;

// 🧹 Tous les chemins imposent au moins deux scans complets au neutre.
IF RuntimeState = RuntimeCleanup THEN
    CleanupRequest := TRUE;
    NeutralWaitScans := 0;
    CleanupElapsedScans := 0;
    RuntimeState := RuntimeWaitNeutral;
ELSIF RuntimeState = RuntimeWaitNeutral THEN
    CleanupRequest := TRUE;
    NeutralWaitScans := NeutralWaitScans + 1;
    CleanupElapsedScans := CleanupElapsedScans + 1;
    IF NeutralWaitScans >= 2 THEN
        RuntimeState := RuntimeVerify;
    END_IF;
ELSIF RuntimeState = RuntimeVerify THEN
    CleanupRequest := TRUE;
    CleanupElapsedScans := CleanupElapsedScans + 1;
    IF NeutralConfirmed THEN
        FinalizePulse := TRUE;
        RuntimeState := RuntimeTerminal;
        Done := TRUE;
    ELSIF CleanupElapsedScans >= CleanupTimeoutScans THEN
        PendingTerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        PendingErrorCode := 1040;
        PendingErrorMessage := 'Cleanup Translation non confirme';
        FinalizePulse := TRUE;
        RuntimeState := RuntimeTerminal;
        Done := TRUE;
    END_IF;
END_IF;

// 📊 Le rapport consomme directement chaque verdict, même consécutif.
instFinalizer(
    RunStart := RunStartPulse,
    RequestedCaseId := CaseId,
    Busy := (RuntimeState = RuntimeRun),
    StepVerdict := instExecutor.StepVerdict,
    StepId := instExecutor.VerdictStepId,
    StepCaseId := instExecutor.VerdictCaseId,
    StepPassed := instExecutor.VerdictPassed,
    StepFailReason := instExecutor.VerdictFailReason,
    StepFailedCheckIdx := instExecutor.VerdictFailedCheckIdx,
    StepDuration := instExecutor.VerdictDuration,
    StepObservedBool := instExecutor.VerdictObservedBool,
    StepObservedDint := instExecutor.VerdictObservedDint,
    StepObservedReal := instExecutor.VerdictObservedReal,
    Finalize := FinalizePulse,
    TerminalState := PendingTerminalState,
    ErrorCode := PendingErrorCode,
    ErrorMessage := PendingErrorMessage,
    StepTable := StepTable,
    CaseTable := CaseTable,
    Report := Report,
    Result := Result
);

// 📤 Publication : Busy inclut cleanup ; aucun stimulus métier hors RUN.
Busy := (RuntimeState = RuntimeRun)
     OR (RuntimeState = RuntimeCleanup)
     OR (RuntimeState = RuntimeWaitNeutral)
     OR (RuntimeState = RuntimeVerify);
IF RuntimeState = RuntimeRun THEN
    ActiveStimulusId := instExecutor.ActiveStimulusId;
ELSE
    ActiveStimulusId := 0;
END_IF;
StepElapsed := instExecutor.StepElapsed;
TerminalState := Result.TerminalState;
AnyFailed := Result.AnyFailed;
ConfigError := PlanConfigError OR instExecutor.ConfigError;
IF PlanConfigError THEN
    ConfigErrorStepId := PlanConfigErrorStepId;
    ConfigErrorCheckIdx := PlanConfigErrorCheckIdx;
ELSE
    ConfigErrorStepId := instExecutor.ConfigErrorStepId;
    ConfigErrorCheckIdx := 0;
END_IF;
ErrorCode := Result.ErrorCode;
ErrorMessage := Result.ErrorMessage;
