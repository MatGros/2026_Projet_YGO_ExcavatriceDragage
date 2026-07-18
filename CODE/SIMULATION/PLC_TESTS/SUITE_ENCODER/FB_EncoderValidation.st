(* ============================================================================
   🧪 FB_EncoderValidation — Suite PLC Encoder/Homing nominale
   ============================================================================
   T25 : validation du flux nominal M1/M2 en simulation.
   Le Homing unitaire MAINT_N2 reste volontairement hors périmètre.

   Cette suite est ciblée par Cmd.RunSuite = SuiteEncoder. Elle n'est pas
   ajoutée à RunAll tant que le flux Homing unitaire n'est pas spécifié.
   Chaque étape possède une limite de temps locale ; aucune attente implicite.
   ============================================================================ *)

FUNCTION_BLOCK PUBLIC FB_EncoderValidation
VAR_INPUT
    Start       : BOOL;
    Abort       : BOOL;
    FirstStepId : INT;
END_VAR
VAR_OUTPUT
    Busy            : BOOL;
    Done            : BOOL;
    AnyFailed       : BOOL;
    SimGateOk       : BOOL;
    ActiveStimulusId : INT;
    StepElapsed     : TIME;
    Report          : ST_TestSuiteReport;
    TerminalState   : E_TestTerminalState;
    ConfigError     : BOOL;
    ConfigErrorStepId : INT;
    ConfigErrorCheckIdx : INT;
    ErrorCode       : INT;
    ErrorMessage    : STRING(160);
END_VAR
VAR
    StartPrev       : BOOL;
    ResetIssued     : BOOL;
    Step            : INT;
    CaseId          : INT;
    StepStarted     : BOOL;
    StepTimer       : TON;
    StepLimit       : TIME;
    StepFailed      : BOOL;
    StepPassed      : BOOL;
    M1HomePulse     : BOOL;
    M2HomePulse     : BOOL;
    Index           : INT;
END_VAR

// Gate simulation : une suite non exécutable se termine explicitement.
SimGateOk := GVL_Simulation.SimulationModeActive
          AND NOT GVL_Simulation.EncoderM1_IsReal
          AND NOT GVL_Simulation.EncoderM2_IsReal;

// Valeurs par défaut de commande : aucun front ne reste actif hors étape dédiée.
M1HomePulse := FALSE;
M2HomePulse := FALSE;
ActiveStimulusId := 0;

IF Abort THEN
    GVL_IHM.M1TreuilRetenue.CmdHome := FALSE;
    GVL_IHM.M2TreuilBucket.CmdHome := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.Aborted := TRUE;
    Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState;
    Report.FailureSummary := 'Encoder/Homing : ABORTED';
    RETURN;
END_IF;

// Démarrage sur front : rapport réinitialisé et mode de maintenance demandé.
IF Start AND NOT StartPrev AND NOT Busy THEN
    StartPrev := TRUE;
    Busy := TRUE;
    Done := FALSE;
    AnyFailed := FALSE;
    ConfigError := FALSE;
    ErrorCode := 0;
    ErrorMessage := '';
    TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    Step := FirstStepId;
    IF (Step <> 10) AND (Step <> 20) THEN Step := 10; END_IF;
    Report.Name := 'Encoder/Homing Validation';
    Report.InProgress := TRUE;
    Report.AllPassed := FALSE;
    Report.AnyFailed := FALSE;
    Report.Aborted := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 0;
    Report.ErrorMessage := '';
    Report.FailureSummary := '';
    Report.CurrentStepId := Step;
    Report.CurrentCaseId := SEL(Step >= 20, 2, 1);
    Report.Duration := T#0s;
    Report.RunCounter := Report.RunCounter + 1;
    FOR Index := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
        Report.Steps[Index].Executed := FALSE;
        Report.Steps[Index].Passed := FALSE;
        Report.Steps[Index].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Steps[Index].Duration := T#0s;
    END_FOR;
    FOR Index := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        Report.Cases[Index].Executed := FALSE;
        Report.Cases[Index].Ok := FALSE;
        Report.Cases[Index].FailedStepId := 0;
        Report.Cases[Index].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Cases[Index].Duration := T#0s;
    END_FOR;
    StepStarted := FALSE;
    ResetIssued := FALSE;
ELSIF NOT Start THEN
    StartPrev := FALSE;
END_IF;

IF NOT Busy THEN
    RETURN;
END_IF;

StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.CurrentStepId := Step;
// 🧭 Mapping rapport : étapes 10/11 = TC-E1 ; étapes 20/21/22 = TC-E2.
CaseId := SEL(Step >= 20, 2, 1);
Report.CurrentCaseId := CaseId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    CASE Step OF
        10: StepLimit := T#2s;
        11: StepLimit := T#2s;
        20: StepLimit := T#2s;
        21: StepLimit := T#2s;
        22: StepLimit := T#10s;
    ELSE
        ConfigError := TRUE;
        ConfigErrorStepId := Step;
        ErrorCode := 3001;
        ErrorMessage := 'Encoder/Homing étape inconnue';
        StepLimit := T#0s;
    END_CASE;
END_IF;

StepTimer(IN := TRUE, PT := StepLimit);

CASE Step OF
    // TC-E1 : gate et interface IHM nominale accessibles.
    10:
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N2;
        IF NOT SimGateOk THEN
            StepFailed := TRUE;
            ErrorCode := 3003;
            ErrorMessage := 'Gate simulation codeurs inactif';
        ELSIF NOT GVL_IHM.M1TreuilRetenue.HomingError
           AND NOT GVL_IHM.M2TreuilBucket.HomingError THEN
            StepPassed := TRUE;
            Step := 11;
            StepStarted := FALSE;
        END_IF;

    // TC-E1 : vérifier que le rapport IHM des deux treuils existe avant commande.
    11:
        IF (GVL_IHM.M1TreuilRetenue.HomingState >= E_State.DISABLED)
           AND (GVL_IHM.M2TreuilBucket.HomingState >= E_State.DISABLED) THEN
            StepPassed := TRUE;
            Step := 0;
        END_IF;

    // TC-E2 : fronts CmdHome indépendants, envoyés simultanément.
    20:
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N2;
        IF NOT SimGateOk THEN
            StepFailed := TRUE;
            ErrorCode := 3003;
            ErrorMessage := 'Gate simulation codeurs inactif';
        ELSE
            StepPassed := TRUE;
            Step := 21;
            StepStarted := FALSE;
        END_IF;

    21:
        M1HomePulse := TRUE;
        M2HomePulse := TRUE;
        GVL_IHM.M1TreuilRetenue.CmdHome := M1HomePulse;
        GVL_IHM.M2TreuilBucket.CmdHome := M2HomePulse;
        StepPassed := TRUE;
        Step := 22;
        StepStarted := FALSE;

    // TC-E2 : aucune attente infinie : les deux instances doivent finir ou déclarer une erreur.
    22:
        GVL_IHM.M1TreuilRetenue.CmdHome := FALSE;
        GVL_IHM.M2TreuilBucket.CmdHome := FALSE;
        IF (GVL_IHM.M1TreuilRetenue.HomingDone OR GVL_IHM.M1TreuilRetenue.Homed)
           AND (GVL_IHM.M2TreuilBucket.HomingDone OR GVL_IHM.M2TreuilBucket.Homed) THEN
            StepPassed := TRUE;
            Step := 0;
        ELSIF GVL_IHM.M1TreuilRetenue.HomingError OR GVL_IHM.M2TreuilBucket.HomingError THEN
            StepFailed := TRUE;
        END_IF;
END_CASE;

// Verdict local de l'étape : PASS, FAIL ou TIMEOUT contrôlé.
IF StepPassed OR StepFailed OR StepTimer.Q THEN
    IF StepPassed THEN
        Report.Steps[Report.CurrentStepId].Passed := TRUE;
        Report.Steps[Report.CurrentStepId].FailReason := E_TestFailReason.FAIL_NONE;
    ELSE
        Report.Steps[Report.CurrentStepId].Passed := FALSE;
        Report.Steps[Report.CurrentStepId].FailReason := SEL(StepFailed, E_TestFailReason.FAIL_TIMEOUT, E_TestFailReason.FAIL_CHECK);
        AnyFailed := TRUE;
    END_IF;
    Report.Steps[Report.CurrentStepId].Executed := TRUE;
    Report.Steps[Report.CurrentStepId].Duration := StepElapsed;
    Report.ErrorCode := ErrorCode;
    Report.ErrorMessage := ErrorMessage;
    // Un échec ou un timeout termine immédiatement la suite : aucune étape
    // suivante ne doit laisser le banc attendre un signal devenu impossible.
    IF NOT StepPassed THEN
        Step := 0;
    END_IF;
    StepPassed := FALSE;
    StepFailed := FALSE;
    StepTimer(IN := FALSE, PT := StepLimit);
    StepElapsed := T#0s;
    IF Step = 0 THEN
        Busy := FALSE;
        Done := TRUE;
        Report.InProgress := FALSE;
        Report.AnyFailed := AnyFailed;
        Report.AllPassed := NOT AnyFailed;
        Report.TerminalState := SEL(AnyFailed, E_TestTerminalState.TEST_TERMINAL_DONE, E_TestTerminalState.TEST_TERMINAL_FAILED);
        TerminalState := Report.TerminalState;
        IF CaseId = 1 THEN
            Report.Cases[CaseId].Name := 'TC-E1 Interface Homing nominale';
        ELSE
            Report.Cases[CaseId].Name := 'TC-E2 Commandes Home M1/M2';
        END_IF;
        Report.Cases[CaseId].Executed := TRUE;
        Report.Cases[CaseId].Ok := NOT AnyFailed;
        Report.Cases[CaseId].FailedStepId := 0;
        Report.Cases[CaseId].FailReason := E_TestFailReason.FAIL_NONE;
        IF AnyFailed THEN
            Report.Cases[CaseId].FailedStepId := Report.CurrentStepId;
            Report.Cases[CaseId].FailReason := E_TestFailReason.FAIL_CHECK;
        END_IF;
        Report.Cases[CaseId].Duration := Report.Duration;
        IF AnyFailed THEN Report.FailureSummary := 'Encoder/Homing : échec ou timeout'; END_IF;
    ELSE
        StepStarted := FALSE;
    END_IF;
END_IF;

// Limite globale de sécurité de la suite : 30 s maximum.
IF Report.Duration >= T#30s AND Busy THEN
    GVL_IHM.M1TreuilRetenue.CmdHome := FALSE;
    GVL_IHM.M2TreuilBucket.CmdHome := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_WATCHDOG_TIMEOUT;
    Report.InProgress := FALSE;
    Report.AnyFailed := TRUE;
    Report.AllPassed := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 3002;
    Report.ErrorMessage := 'Watchdog Encoder/Homing expire';
    Report.FailureSummary := Report.ErrorMessage;
END_IF;
