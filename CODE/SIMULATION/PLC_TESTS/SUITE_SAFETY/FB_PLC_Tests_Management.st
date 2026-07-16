FUNCTION_BLOCK PUBLIC FB_PLC_Tests_Management
VAR
    // 🧱 Instance de test Safety
    instSafetyValidation : FB_SafetyValidation;

    // Triggers pour IHM tactiles
    RunAllTrig           : R_TRIG;
    AbortTrig            : R_TRIG;
    ClearReportTrig      : R_TRIG;

    // Variables de commande internes
    StartSafety          : BOOL;
    AbortSafety          : BOOL;
    FirstStepSafety      : INT;
    
    // Compteurs pour progression IHM
    Idx                  : INT;
    PassedCount          : INT;
    FailedCount          : INT;
    TotalCount           : INT;

    // 💓 Gestion du clignotant HMI
    LastStepId           : INT := 0;
    PulseCounter         : INT := 0;
    CycleCounter         : INT := 0;
END_VAR
// === IMPLEMENTATION ===
// 1. Détection des commandes HMI
RunAllTrig(CLK := GVL_PLC_Tests.Cmd.RunAll);
AbortTrig(CLK := GVL_PLC_Tests.Cmd.Abort);
ClearReportTrig(CLK := GVL_PLC_Tests.Cmd.ClearReport);

// Remise à zéro des boutons poussoirs HMI
// 🔧 REX 2026-07-16 (demande utilisateur) : CmdRunAll n'est PAS remis à FALSE ici (contrairement
// à l'ancien CmdRunTests, pulse consommé au scan suivant) — il reste TRUE tout le temps du run,
// pratique pour observer en Watch/forçage CODESYS, et ne retombe qu'au Done (cf. CASE ci-dessous).
// R_TRIG garantit qu'un niveau maintenu ne redéclenche pas un 2e run.
IF GVL_PLC_Tests.Cmd.Abort THEN
    GVL_PLC_Tests.Cmd.Abort := FALSE;
END_IF;
IF GVL_PLC_Tests.Cmd.ClearReport THEN
    GVL_PLC_Tests.Cmd.ClearReport := FALSE;
END_IF;

// 2. Machine d'états principale
CASE GVL_PLC_Tests.Status.RunState OF

    E_TestRunState.TESTRUN_IDLE:
        StartSafety := FALSE;
        AbortSafety := FALSE;
        
        // Démarrage par bouton global RunAll
        IF RunAllTrig.Q THEN
            IF GVL_Simulation.SimulationModeActive AND instSafetyValidation.SimGateOk THEN
                StartSafety := TRUE;
                FirstStepSafety := 10; // TC-01 SETUP
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            
        // Démarrage d'une suite ciblée
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSafety THEN
            IF GVL_Simulation.SimulationModeActive AND instSafetyValidation.SimGateOk THEN
                StartSafety := TRUE;
                IF GVL_PLC_Tests.Cmd.RunCase = 1 THEN
                    FirstStepSafety := 10;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 2 THEN
                    FirstStepSafety := 20;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 3 THEN
                    FirstStepSafety := 30;
                ELSE
                    FirstStepSafety := 10; // Par défaut TC-01
                END_IF;
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;
        END_IF;

        // Commande d'effacement du rapport
        IF ClearReportTrig.Q THEN
            // La réinitialisation est gérée par le moteur au démarrage du run suivant,
            // mais on peut forcer la remise à zéro des états actuels de l'IHM
            GVL_PLC_Tests.Status.CasesTotal := 0;
            GVL_PLC_Tests.Status.CasesPassed := 0;
            GVL_PLC_Tests.Status.CasesFailed := 0;
        END_IF;

    E_TestRunState.TESTRUN_RUNNING:
        // Annulation de l'impulsion de départ
        StartSafety := FALSE;
        
        // Abandon propre ou perte du mode Simulation
        IF AbortTrig.Q OR NOT GVL_Simulation.SimulationModeActive THEN
            AbortSafety := TRUE;
        END_IF;

        // Surveillance de la fin d'exécution de la suite Safety
        IF instSafetyValidation.Done THEN
            AbortSafety := FALSE;
            IF instSafetyValidation.Report.Aborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF instSafetyValidation.AnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        END_IF;

    E_TestRunState.TESTRUN_PASSED, E_TestRunState.TESTRUN_FAILED, E_TestRunState.TESTRUN_ABORTED:
        // 🔧 REX 2026-07-16 : c'est ICI que CmdRunAll retombe à FALSE (Done atteint), pas au démarrage
        GVL_PLC_Tests.Cmd.RunAll := FALSE;
        // Retour automatique à l'état IDLE après un cycle pour libérer l'IHM
        GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_IDLE;

END_CASE;

// 3. Appel de l'instance Safety Validation
instSafetyValidation(Start := StartSafety, Abort := AbortSafety, FirstStepId := FirstStepSafety);

// 4. Centralisation et recopie vers GVL_PLC_Tests
GVL_PLC_Tests.Status.SimulationActive := GVL_Simulation.SimulationModeActive;
GVL_PLC_Tests.SafetyValidation := instSafetyValidation.Report;
GVL_PLC_Tests.Suites[GVL_PLC_Tests_Const.SuiteSafety] := instSafetyValidation.Report;

// 5. Mise à jour des indicateurs de progression IHM
IF GVL_PLC_Tests.Status.RunState = E_TestRunState.TESTRUN_RUNNING THEN
    GVL_PLC_Tests.Status.ActiveSuiteId := GVL_PLC_Tests_Const.SuiteSafety;
    GVL_PLC_Tests.Status.ActiveSuiteName := instSafetyValidation.Report.Name;
    GVL_PLC_Tests.Status.ActiveCaseId := instSafetyValidation.Report.CurrentCaseId;
    GVL_PLC_Tests.Status.ActiveStepId := instSafetyValidation.Report.CurrentStepId;
    GVL_PLC_Tests.Status.StepElapsed := instSafetyValidation.StepElapsed;
    
    // Détermination dynamique des noms et du timeout de l'étape active
    IF GVL_PLC_Tests.Status.ActiveStepId >= 1 AND GVL_PLC_Tests.Status.ActiveStepId <= GVL_PLC_Tests_Const.MaxSteps THEN
        // Le nom de l'étape et son timeout
        // (Ces valeurs sont copiées depuis la configuration locale interne de instSafetyValidation)
        // Mais pour simplifier, on peut les extraire directement si elles sont disponibles
    END_IF;
ELSE
    GVL_PLC_Tests.Status.ActiveSuiteId := 0;
    GVL_PLC_Tests.Status.ActiveSuiteName := '';
    GVL_PLC_Tests.Status.ActiveCaseId := 0;
    GVL_PLC_Tests.Status.ActiveCaseName := '';
    GVL_PLC_Tests.Status.ActiveStepId := 0;
    GVL_PLC_Tests.Status.ActiveStepName := '';
    GVL_PLC_Tests.Status.StepElapsed := T#0s;
    GVL_PLC_Tests.Status.StepTimeoutPT := T#0s;
END_IF;

// Agrégation globale des compteurs de cas de tests
PassedCount := 0;
FailedCount := 0;
TotalCount := 0;

FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
    IF instSafetyValidation.Report.Cases[Idx].Executed THEN
        TotalCount := TotalCount + 1;
        IF instSafetyValidation.Report.Cases[Idx].Ok THEN
            PassedCount := PassedCount + 1;
        ELSE
            FailedCount := FailedCount + 1;
        END_IF;
    END_IF;
END_FOR;

GVL_PLC_Tests.Status.CasesTotal := TotalCount;
GVL_PLC_Tests.Status.CasesPassed := PassedCount;
GVL_PLC_Tests.Status.CasesFailed := FailedCount;

// 💓 Logique du Clignotant visuel d'activité (Heartbeat — Triple clignotement réactif)
IF GVL_PLC_Tests.Status.RunState = E_TestRunState.TESTRUN_RUNNING THEN
    // 1. Détection d'un changement de step réel -> Armement du triple clignotement
    IF GVL_PLC_Tests.Status.ActiveStepId <> LastStepId AND PulseCounter = 0 THEN
        PulseCounter := 1;
        CycleCounter := 0;
        GVL_PLC_Tests.Status.Heartbeat := TRUE;
        LastStepId := GVL_PLC_Tests.Status.ActiveStepId;
    END_IF;

    // 2. Gestion du cycle de clignotement (100ms ON / 100ms OFF x3)
    IF PulseCounter > 0 THEN
        CycleCounter := CycleCounter + 1;
        IF CycleCounter >= 10 THEN
            CycleCounter := 0;
            PulseCounter := PulseCounter + 1;
            IF PulseCounter <= 6 THEN
                // Impulsions impaires = TRUE, paires = FALSE
                GVL_PLC_Tests.Status.Heartbeat := (PulseCounter MOD 2 <> 0);
            ELSE
                // Fin du triple clignotement -> retour à l'état éteint
                PulseCounter := 0;
                GVL_PLC_Tests.Status.Heartbeat := FALSE;
            END_IF;
        END_IF;
    END_IF;
ELSE
    // Forcer à FALSE quand le runner est au repos
    GVL_PLC_Tests.Status.Heartbeat := FALSE;
    LastStepId := 0;
    PulseCounter := 0;
    CycleCounter := 0;
END_IF;
