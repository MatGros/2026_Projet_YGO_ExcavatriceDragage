FUNCTION_BLOCK PUBLIC FB_PLC_Tests_Management
VAR
    // 🧱 Instances de test (1 par suite — ajouter une suite = 1 instance + 1 branche CASE,
    // voir AF_Partie-14 §7.3.4)
    instSafetyValidation      : FB_SafetyValidation;
    instTranslationValidation : FB_TranslationValidation;

    // Triggers pour IHM tactiles
    RunAllTrig           : R_TRIG;
    AbortTrig            : R_TRIG;
    ClearReportTrig      : R_TRIG;

    // Variables de commande internes
    StartSafety          : BOOL;
    AbortSafety          : BOOL;
    FirstStepSafety      : INT;
    StartTranslation     : BOOL;
    AbortTranslation     : BOOL;
    FirstStepTranslation : INT;

    // 🔗 Enchaînement multi-suites (CmdRunAll) — 2026-07-16 : ajout Translation
    ChainMode            : BOOL;  // TRUE = run déclenché par RunAll, enchaîne Safety PUIS Translation
    CurrentSuiteIdx      : INT;   // Suite active/dernière active (GVL_PLC_Tests_Const.SuiteSafety/SuiteTranslation)
    FinalAborted         : BOOL;
    FinalAnyFailed       : BOOL;

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
        StartTranslation := FALSE;
        AbortTranslation := FALSE;

        // Démarrage par bouton global RunAll — enchaîne Safety PUIS Translation
        IF RunAllTrig.Q THEN
            IF GVL_Simulation.SimulationModeActive AND instSafetyValidation.SimGateOk THEN
                ChainMode := TRUE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSafety;
                StartSafety := TRUE;
                FirstStepSafety := 10; // TC-01 SETUP
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;

        // Démarrage d'une suite ciblée (Safety)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSafety THEN
            IF GVL_Simulation.SimulationModeActive AND instSafetyValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSafety;
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

        // Démarrage d'une suite ciblée (Translation)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteTranslation THEN
            IF GVL_Simulation.SimulationModeActive AND instTranslationValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteTranslation;
                StartTranslation := TRUE;
                IF GVL_PLC_Tests.Cmd.RunCase = 1 THEN
                    FirstStepTranslation := 10;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 2 THEN
                    FirstStepTranslation := 20;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 3 THEN
                    FirstStepTranslation := 30;
                ELSE
                    FirstStepTranslation := 10; // Par défaut TC-T1
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
        // Annulation des impulsions de départ
        StartSafety := FALSE;
        StartTranslation := FALSE;

        // Abandon propre ou perte du mode Simulation — coupe la suite active
        IF AbortTrig.Q OR NOT GVL_Simulation.SimulationModeActive THEN
            AbortSafety := TRUE;
            AbortTranslation := TRUE;
        END_IF;

        // Surveillance de la fin d'exécution — Safety d'abord
        IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSafety AND instSafetyValidation.Done THEN
            AbortSafety := FALSE;
            IF ChainMode AND NOT instSafetyValidation.Report.Aborted THEN
                // 🔗 Enchaîne vers Translation (continue même si Safety a échoué — logique
                // FAIL_CONTINUE déjà appliquée au niveau des cases/steps, voir §7.3.4)
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteTranslation;
                StartTranslation := TRUE;
                FirstStepTranslation := 10;
            ELSE
                FinalAborted := instSafetyValidation.Report.Aborted;
                FinalAnyFailed := instSafetyValidation.AnyFailed;
                IF FinalAborted THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
                ELSIF FinalAnyFailed THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
                ELSE
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
                END_IF;
            END_IF;

        // Surveillance de la fin d'exécution — Translation (ciblée ou enchaînée après Safety)
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation AND instTranslationValidation.Done THEN
            AbortTranslation := FALSE;
            IF ChainMode THEN
                FinalAborted := instSafetyValidation.Report.Aborted OR instTranslationValidation.Report.Aborted;
                FinalAnyFailed := instSafetyValidation.AnyFailed OR instTranslationValidation.AnyFailed;
            ELSE
                FinalAborted := instTranslationValidation.Report.Aborted;
                FinalAnyFailed := instTranslationValidation.AnyFailed;
            END_IF;
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
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

// 3. Appel des instances de suites
instSafetyValidation(Start := StartSafety, Abort := AbortSafety, FirstStepId := FirstStepSafety);
instTranslationValidation(Start := StartTranslation, Abort := AbortTranslation, FirstStepId := FirstStepTranslation);

// 4. Centralisation et recopie vers GVL_PLC_Tests
GVL_PLC_Tests.Status.SimulationActive := GVL_Simulation.SimulationModeActive;
GVL_PLC_Tests.SuiteSafetyValidation := instSafetyValidation.Report;
GVL_PLC_Tests.SuiteTranslationValidation := instTranslationValidation.Report;

// 5. Mise à jour des indicateurs de progression IHM
IF GVL_PLC_Tests.Status.RunState = E_TestRunState.TESTRUN_RUNNING THEN
    GVL_PLC_Tests.Status.ActiveSuiteId := CurrentSuiteIdx;
    IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instTranslationValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instTranslationValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instTranslationValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instTranslationValidation.StepElapsed;
    ELSE
        GVL_PLC_Tests.Status.ActiveSuiteName := instSafetyValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instSafetyValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instSafetyValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instSafetyValidation.StepElapsed;
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

// Agrégation globale des compteurs de cas de tests — seules les suites réellement
// exécutées CE run comptent (ChainMode = les deux ; sinon seule CurrentSuiteIdx)
// pour ne jamais compter les restes d'un run ciblé précédent sur l'autre suite.
PassedCount := 0;
FailedCount := 0;
TotalCount := 0;

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSafety THEN
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
END_IF;

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instTranslationValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instTranslationValidation.Report.Cases[Idx].Ok THEN
                PassedCount := PassedCount + 1;
            ELSE
                FailedCount := FailedCount + 1;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

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
