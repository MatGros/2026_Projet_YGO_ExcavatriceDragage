// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationReportFinalizer — Rapport incrémental Translation
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : enregistrer les verdicts réels et finaliser
//    un rapport borné. Aucun parcours du graphe de transitions.
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationReportFinalizer
VAR_INPUT
    RunStart        : BOOL;
    RequestedCaseId : INT;
    Busy            : BOOL;
    StepVerdict         : BOOL;
    StepId              : INT;
    StepCaseId          : INT;
    StepPassed          : BOOL;
    StepFailReason      : E_TestFailReason;
    StepFailedCheckIdx  : INT;
    StepDuration        : TIME;
    StepObservedBool    : BOOL;
    StepObservedDint    : DINT;
    StepObservedReal    : REAL;
    Finalize       : BOOL;
    TerminalState  : E_TestTerminalState;
    ErrorCode      : INT;
    ErrorMessage   : STRING(160);
END_VAR
VAR_IN_OUT
    StepTable : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]     OF ST_TestStepConfig;
    CaseTable : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases] OF ST_TestCaseConfig;
    Report    : ST_TestSuiteReport;
    Result    : ST_TranslationTestResult;
END_VAR
VAR
    Idx             : INT;
    CaseIdx         : INT;
    CasesTotalLocal : INT;
    CasesPassedLocal: INT;
    CasesFailedLocal: INT;
    FirstFailedCase : INT;
    ReasonText      : STRING(20);
    EntryText       : STRING(80);
END_VAR
// === IMPLEMENTATION ===
IF RunStart THEN
    Report.Name := 'Translation Validation';
    Report.InProgress := TRUE;
    Report.AllPassed := FALSE;
    Report.AnyFailed := FALSE;
    Report.Aborted := FALSE;
    Report.TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    Report.ErrorCode := 0;
    Report.ErrorMessage := '';
    Report.FailedTestCase := 0;
    Report.FailureSummary := '';
    Report.CurrentStepId := 0;
    Report.CurrentCaseId := 0;
    Report.Duration := T#0s;
    Report.RunCounter := Report.RunCounter + 1;
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
        Report.Steps[Idx].Executed := FALSE;
        Report.Steps[Idx].Passed := FALSE;
        Report.Steps[Idx].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Steps[Idx].FailedCheckIdx := 0;
        Report.Steps[Idx].FailedInvariantId := 0;
        Report.Steps[Idx].Duration := T#0s;
    END_FOR;
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        Report.Cases[Idx].Name := CaseTable[Idx].Name;
        Report.Cases[Idx].Executed := FALSE;
        Report.Cases[Idx].Ok := FALSE;
        Report.Cases[Idx].FailedStepId := 0;
        Report.Cases[Idx].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Cases[Idx].Duration := T#0s;
    END_FOR;
    Result.TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    Result.RequestedCaseId := RequestedCaseId;
    Result.ExecutedCaseId := 0;
    Result.AllPassed := FALSE;
    Result.AnyFailed := FALSE;
    Result.FailedCaseId := 0;
    Result.FailedCaseName := '';
    Result.FailReason := E_TestFailReason.FAIL_NONE;
    Result.ErrorCode := 0;
    Result.ErrorMessage := '';
    Result.CasesTotal := 0;
    Result.CasesPassed := 0;
    Result.CasesFailed := 0;
    Result.Duration := T#0s;
    Result.RunCounter := Report.RunCounter;
END_IF;

IF Busy THEN
    Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
END_IF;

// 🧾 Agrégation incrémentale : validation séparée avant toute indexation.
IF StepVerdict THEN
    IF StepId < 1 OR StepId > GVL_PLC_Tests_Const.MaxSteps THEN
        Report.ErrorCode := 1050;
        Report.ErrorMessage := 'Verdict StepId hors limites';
        Report.AnyFailed := TRUE;
        RETURN;
    END_IF;
    Report.Steps[StepId].Executed := TRUE;
    Report.Steps[StepId].Passed := StepPassed;
    Report.Steps[StepId].FailReason := StepFailReason;
    Report.Steps[StepId].FailedCheckIdx := StepFailedCheckIdx;
    Report.Steps[StepId].Duration := StepDuration;
    Report.Steps[StepId].ObservedBool := StepObservedBool;
    Report.Steps[StepId].ObservedDint := StepObservedDint;
    Report.Steps[StepId].ObservedReal := StepObservedReal;
    Report.CurrentStepId := StepId;
    Report.CurrentCaseId := StepCaseId;

    IF StepCaseId >= 1 THEN
        IF StepCaseId <= GVL_PLC_Tests_Const.MaxTestCases THEN
        IF NOT Report.Cases[StepCaseId].Executed THEN
            Report.Cases[StepCaseId].Executed := TRUE;
            Report.Cases[StepCaseId].Ok := TRUE;
        END_IF;
        Report.Cases[StepCaseId].Duration := Report.Cases[StepCaseId].Duration + StepDuration;
        IF NOT StepPassed THEN
            Report.Cases[StepCaseId].Ok := FALSE;
            IF Report.Cases[StepCaseId].FailedStepId = 0 THEN
                Report.Cases[StepCaseId].FailedStepId := StepId;
                Report.Cases[StepCaseId].FailReason := StepFailReason;
            END_IF;
        END_IF;
        ELSE
            Report.ErrorCode := 1051;
            Report.ErrorMessage := 'Verdict CaseId hors limites';
            Report.AnyFailed := TRUE;
        END_IF;
    ELSE
        Report.ErrorCode := 1051;
        Report.ErrorMessage := 'Verdict CaseId hors limites';
        Report.AnyFailed := TRUE;
    END_IF;
END_IF;

IF Finalize THEN
    Report.InProgress := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := ErrorCode;
    Report.ErrorMessage := ErrorMessage;
    Report.Aborted := (TerminalState = E_TestTerminalState.TEST_TERMINAL_ABORTED);
    CasesTotalLocal := 0;
    CasesPassedLocal := 0;
    CasesFailedLocal := 0;
    FirstFailedCase := 0;
    Report.FailureSummary := '';

    FOR CaseIdx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF Report.Cases[CaseIdx].Executed THEN
            CasesTotalLocal := CasesTotalLocal + 1;
            IF Report.Cases[CaseIdx].Ok THEN
                CasesPassedLocal := CasesPassedLocal + 1;
            ELSE
                CasesFailedLocal := CasesFailedLocal + 1;
                IF FirstFailedCase = 0 THEN FirstFailedCase := CaseIdx; END_IF;
                CASE Report.Cases[CaseIdx].FailReason OF
                    E_TestFailReason.FAIL_TIMEOUT: ReasonText := 'FAIL_TIMEOUT';
                    E_TestFailReason.FAIL_CHECK: ReasonText := 'FAIL_CHECK';
                    E_TestFailReason.FAIL_INVARIANT: ReasonText := 'FAIL_INVARIANT';
                    E_TestFailReason.FAIL_WINDOW_EARLY: ReasonText := 'FAIL_WINDOW_EARLY';
                    E_TestFailReason.FAIL_ABORTED: ReasonText := 'FAIL_ABORTED';
                ELSE ReasonText := 'FAIL_NONE';
                END_CASE;
                EntryText := CONCAT(Report.Cases[CaseIdx].Name, ' (step ');
                EntryText := CONCAT(EntryText, INT_TO_STRING(Report.Cases[CaseIdx].FailedStepId));
                EntryText := CONCAT(EntryText, '): ');
                EntryText := CONCAT(EntryText, ReasonText);
                IF Report.FailureSummary = '' THEN
                    Report.FailureSummary := EntryText;
                ELSE
                    Report.FailureSummary := CONCAT(Report.FailureSummary, ' | ');
                    Report.FailureSummary := CONCAT(Report.FailureSummary, EntryText);
                END_IF;
            END_IF;
        END_IF;
    END_FOR;

    Report.AllPassed := (TerminalState = E_TestTerminalState.TEST_TERMINAL_DONE)
                     AND (CasesTotalLocal > 0)
                     AND (CasesFailedLocal = 0);
    Report.AnyFailed := NOT Report.AllPassed;
    Report.FailedTestCase := FirstFailedCase;

    Result.TerminalState := TerminalState;
    Result.RequestedCaseId := RequestedCaseId;
    Result.ExecutedCaseId := Report.CurrentCaseId;
    Result.AllPassed := Report.AllPassed;
    Result.AnyFailed := Report.AnyFailed;
    Result.FailedCaseId := FirstFailedCase;
    IF FirstFailedCase > 0 THEN
        Result.FailedCaseName := Report.Cases[FirstFailedCase].Name;
        Result.FailReason := Report.Cases[FirstFailedCase].FailReason;
    ELSE
        Result.FailedCaseName := '';
        Result.FailReason := E_TestFailReason.FAIL_NONE;
    END_IF;
    Result.ErrorCode := ErrorCode;
    Result.ErrorMessage := ErrorMessage;
    Result.CasesTotal := CasesTotalLocal;
    Result.CasesPassed := CasesPassedLocal;
    Result.CasesFailed := CasesFailedLocal;
    Result.Duration := Report.Duration;
    Result.RunCounter := Report.RunCounter;
END_IF;
