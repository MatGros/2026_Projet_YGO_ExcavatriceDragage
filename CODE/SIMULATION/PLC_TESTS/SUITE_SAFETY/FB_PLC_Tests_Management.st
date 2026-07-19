FUNCTION_BLOCK PUBLIC FB_PLC_Tests_Management
VAR_INPUT
    instBucket                : REFERENCE TO FB_Bucket;     // 🆕 Instance benne (pour FB_BucketValidation)
    instWinchM2               : REFERENCE TO FB_Winch;      // 🆕 Instance treuil M2 (pour FB_BucketValidation)
END_VAR
VAR
    // 🧱 Instances de test (1 par suite — ajouter une suite = 1 instance + 1 branche CASE,
    // voir AF_Partie-14 §7.3.4)
    instSafetyValidation      : FB_SafetyValidation;
    instTranslationValidation : FB_TranslationValidation;
    instBucketValidation      : FB_BucketValidation;
    instEncoderValidation     : FB_EncoderValidation;
    instModesValidation       : FB_ModesValidation;


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
    StartBucket           : BOOL;
    AbortBucket           : BOOL;
    FirstStepBucket       : INT;
    StartEncoder          : BOOL;
    AbortEncoder          : BOOL;
    FirstStepEncoder      : INT;
    StartModes            : BOOL;
    AbortModes            : BOOL;
    FirstStepModes        : INT;

    // 🔗 Enchaînement multi-suites (CmdRunAll) — 2026-07-16 : ajout Translation puis Bucket
    ChainMode            : BOOL;  // TRUE = run déclenché par RunAll, enchaîne Safety PUIS Translation PUIS Bucket
    CurrentSuiteIdx      : INT;   // Suite active/dernière active (GVL_PLC_Tests_Const.SuiteSafety/SuiteTranslation/SuiteBucket)
    FinalAborted         : BOOL;
    FinalAnyFailed       : BOOL;
    SuiteElapsed         : TIME;
    SuiteWatchdogExpired : BOOL;
    LastLoggedSafetyRun  : UDINT;
    LastLoggedTranslationRun : UDINT;
    LastLoggedBucketRun  : UDINT;
    EventIdx             : INT;

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

    // 🔧 REX 2026-07-16 (demande utilisateur) : PASSED/FAILED/ABORTED sont FIGÉS ici (pattern
    // StateAtError, P3 §4) — sans ça, l'état ne durait qu'1 scan (10ms) avant de retomber tout
    // seul à IDLE, invisible en Watch CODESYS. On ne quitte cet état que sur nouveau Start
    // (relance direct un run) ou CmdClearReport (acquittement explicite → retour IDLE).
    E_TestRunState.TESTRUN_IDLE, E_TestRunState.TESTRUN_PASSED, E_TestRunState.TESTRUN_FAILED, E_TestRunState.TESTRUN_ABORTED:
        StartSafety := FALSE;
        AbortSafety := FALSE;
        StartTranslation := FALSE;
        AbortTranslation := FALSE;
        StartBucket := FALSE;
        AbortBucket := FALSE;
        StartEncoder := FALSE;
        AbortEncoder := FALSE;
        StartModes := FALSE;
        AbortModes := FALSE;
        SuiteElapsed := T#0s;
        SuiteWatchdogExpired := FALSE;

        // Normalisation des commandes unitaires vers l'interface historique RunSuite.
        // Une seule commande est consommée ; RunAll reste volontairement ignoré.
        IF GVL_PLC_Tests.Cmd.RunSafety THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteSafety;
            GVL_PLC_Tests.Cmd.RunSafety := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunTranslation THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteTranslation;
            GVL_PLC_Tests.Cmd.RunTranslation := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunBucket THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteBucket;
            GVL_PLC_Tests.Cmd.RunBucket := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunEncoder THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteEncoder;
            GVL_PLC_Tests.Cmd.RunEncoder := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunModes THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteModes;
            GVL_PLC_Tests.Cmd.RunModes := FALSE;
        END_IF;
        GVL_PLC_Tests.Cmd.RunAll := FALSE;

        // RunAll est désactivé : chaque suite est lancée manuellement.
        // Démarrage d'une suite ciblée (Safety)
        IF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSafety THEN
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
                GVL_PLC_Tests.Status.FailureSummary := ''; // 🔄 RAZ à chaque nouveau run
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
                GVL_PLC_Tests.Status.FailureSummary := ''; // 🔄 RAZ à chaque nouveau run
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage d'une suite ciblée (Bucket)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteBucket THEN
            IF GVL_Simulation.SimulationModeActive AND instBucketValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteBucket;
                StartBucket := TRUE;
                IF GVL_PLC_Tests.Cmd.RunCase = 1 THEN
                    FirstStepBucket := 10;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 2 THEN
                    FirstStepBucket := 20;
                ELSIF GVL_PLC_Tests.Cmd.RunCase = 3 THEN
                    FirstStepBucket := 30;
                ELSE
                    FirstStepBucket := 10; // Par défaut TC-B1
                END_IF;
                GVL_PLC_Tests.Status.FailureSummary := ''; // 🔄 RAZ à chaque nouveau run
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage d'une suite ciblée (Codeurs/Homing nominal)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteEncoder THEN
            IF GVL_Simulation.SimulationModeActive AND instEncoderValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteEncoder;
                StartEncoder := TRUE;
                IF GVL_PLC_Tests.Cmd.RunCase = 2 THEN
                    FirstStepEncoder := 20;
                ELSE
                    FirstStepEncoder := 10;
                END_IF;
                GVL_PLC_Tests.Status.FailureSummary := '';
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage d'une suite ciblée (Modes/Homme-mort, post-suppression IHM_MANU)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteModes THEN
            IF GVL_Simulation.SimulationModeActive AND instModesValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteModes;
                StartModes := TRUE;
                FirstStepModes := 10;
                GVL_PLC_Tests.Status.FailureSummary := '';
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;
        END_IF;

        // Commande d'effacement du rapport — acquittement explicite, retour à IDLE
        IF ClearReportTrig.Q THEN
            // La réinitialisation des rapports Steps[]/Cases[] est gérée par le moteur
            // au démarrage du run suivant ; ici on remet juste les compteurs IHM et on
            // libère l'état figé PASSED/FAILED/ABORTED.
            GVL_PLC_Tests.Status.CasesTotal := 0;
            GVL_PLC_Tests.Status.CasesPassed := 0;
            GVL_PLC_Tests.Status.CasesFailed := 0;
            GVL_PLC_Tests.Status.FailureSummary := '';
            GVL_PLC_Tests.EventCount := 0;
            GVL_PLC_Tests.EventSequence := 0;
            GVL_PLC_Tests.EventOverflow := FALSE;
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_IDLE;
        END_IF;

    E_TestRunState.TESTRUN_RUNNING:
        // Annulation des impulsions de départ
        StartSafety := FALSE;
        StartTranslation := FALSE;
        StartBucket := FALSE;

        // 🛡️ Aucun orchestrateur ne doit attendre Done indéfiniment.
        SuiteElapsed := SuiteElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
        GVL_PLC_Tests.Status.SuiteElapsed := SuiteElapsed;
        IF SuiteElapsed >= DINT_TO_TIME(GVL_PLC_Tests_Const.MaxSuiteDurationMs) THEN
            SuiteWatchdogExpired := TRUE;
            GVL_PLC_Tests.Status.SuiteWatchdogExpired := TRUE;
            IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSafety THEN
                AbortSafety := TRUE;
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation THEN
                AbortTranslation := TRUE;
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder THEN
                AbortEncoder := TRUE;
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes THEN
                AbortModes := TRUE;
            ELSE
                AbortBucket := TRUE;
            END_IF;
        END_IF;

        // Abandon propre ou perte du mode Simulation — coupe la suite active
        IF AbortTrig.Q OR NOT GVL_Simulation.SimulationModeActive THEN
            AbortSafety := TRUE;
            AbortTranslation := TRUE;
            AbortBucket := TRUE;
        END_IF;

        // Surveillance de la fin d'exécution — Safety d'abord
        IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSafety AND instSafetyValidation.Done THEN
            AbortSafety := FALSE;
            IF instSafetyValidation.TerminalState <> E_TestTerminalState.TEST_TERMINAL_DONE AND instSafetyValidation.Report.RunCounter <> LastLoggedSafetyRun THEN
                LastLoggedSafetyRun := instSafetyValidation.Report.RunCounter;
                GVL_PLC_Tests.EventSequence := GVL_PLC_Tests.EventSequence + 1;
                IF GVL_PLC_Tests.EventCount < GVL_PLC_Tests_Const.MaxTestEvents THEN
                    GVL_PLC_Tests.EventCount := GVL_PLC_Tests.EventCount + 1;
                ELSE
                    GVL_PLC_Tests.EventOverflow := TRUE;
                END_IF;
                EventIdx := UDINT_TO_INT(GVL_PLC_Tests.EventSequence MOD INT_TO_UDINT(GVL_PLC_Tests_Const.MaxTestEvents)) + 1;
                GVL_PLC_Tests.EventLog[EventIdx].Sequence := GVL_PLC_Tests.EventSequence;
                GVL_PLC_Tests.EventLog[EventIdx].Severity := E_TestEventSeverity.TEST_EVENT_ERROR;
                GVL_PLC_Tests.EventLog[EventIdx].SuiteId := GVL_PLC_Tests_Const.SuiteSafety;
                GVL_PLC_Tests.EventLog[EventIdx].CaseId := instSafetyValidation.Report.CurrentCaseId;
                GVL_PLC_Tests.EventLog[EventIdx].StepId := instSafetyValidation.Report.CurrentStepId;
                GVL_PLC_Tests.EventLog[EventIdx].Code := instSafetyValidation.ErrorCode;
                GVL_PLC_Tests.EventLog[EventIdx].Message := instSafetyValidation.ErrorMessage;
            END_IF;
            IF ChainMode AND (NOT instSafetyValidation.Report.Aborted OR SuiteWatchdogExpired) AND instTranslationValidation.SimGateOk THEN
                // 🔗 Enchaîne vers Translation (continue même si Safety a échoué — logique
                // FAIL_CONTINUE déjà appliquée au niveau des cases/steps, voir §7.3.4)
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteTranslation;
                StartTranslation := TRUE;
                FirstStepTranslation := 10;
            ELSIF ChainMode AND NOT instSafetyValidation.Report.Aborted AND NOT instTranslationValidation.SimGateOk THEN
                // 🔧 REX 2026-07-16 : bug trouvé — le chaînage sautait la vérification SimGateOk
                // (le démarrage ciblé Cmd.RunSuite=2 la faisait, pas celui-ci). Sans ce garde-fou,
                // Translation démarrait quand même avec FB_Safety_Translation.Enable=FALSE
                // (ManuActive actif) → 3 timeouts silencieux, aucun défaut jamais détectable.
                GVL_PLC_Tests.Cmd.RunAll := FALSE;
                ChainMode := FALSE; // 🔒 Évite d'agréger un rapport Translation périmé (suite jamais lancée ce run)
                IF instSafetyValidation.Report.FailureSummary = '' THEN
                    GVL_PLC_Tests.Status.FailureSummary := 'Translation NON TESTEE (SimGateOk=FALSE — vérifier SimulationModeActive et les E/S M3 non réelles)';
                ELSE
                    GVL_PLC_Tests.Status.FailureSummary := CONCAT(instSafetyValidation.Report.FailureSummary, ' || Translation NON TESTEE (SimGateOk=FALSE — vérifier SimulationModeActive et les E/S M3 non réelles)');
                END_IF;
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSE
                FinalAborted := instSafetyValidation.Report.Aborted;
                FinalAnyFailed := instSafetyValidation.AnyFailed;
                GVL_PLC_Tests.Cmd.RunAll := FALSE; // 🔧 Retombe ICI (Done atteint), pas au démarrage
                GVL_PLC_Tests.Status.FailureSummary := instSafetyValidation.Report.FailureSummary;
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
            IF instTranslationValidation.TerminalState <> E_TestTerminalState.TEST_TERMINAL_DONE AND instTranslationValidation.Report.RunCounter <> LastLoggedTranslationRun THEN
                LastLoggedTranslationRun := instTranslationValidation.Report.RunCounter;
                GVL_PLC_Tests.EventSequence := GVL_PLC_Tests.EventSequence + 1;
                IF GVL_PLC_Tests.EventCount < GVL_PLC_Tests_Const.MaxTestEvents THEN
                    GVL_PLC_Tests.EventCount := GVL_PLC_Tests.EventCount + 1;
                ELSE
                    GVL_PLC_Tests.EventOverflow := TRUE;
                END_IF;
                EventIdx := UDINT_TO_INT(GVL_PLC_Tests.EventSequence MOD INT_TO_UDINT(GVL_PLC_Tests_Const.MaxTestEvents)) + 1;
                GVL_PLC_Tests.EventLog[EventIdx].Sequence := GVL_PLC_Tests.EventSequence;
                GVL_PLC_Tests.EventLog[EventIdx].Severity := E_TestEventSeverity.TEST_EVENT_ERROR;
                GVL_PLC_Tests.EventLog[EventIdx].SuiteId := GVL_PLC_Tests_Const.SuiteTranslation;
                GVL_PLC_Tests.EventLog[EventIdx].CaseId := instTranslationValidation.Report.CurrentCaseId;
                GVL_PLC_Tests.EventLog[EventIdx].StepId := instTranslationValidation.Report.CurrentStepId;
                GVL_PLC_Tests.EventLog[EventIdx].Code := instTranslationValidation.ErrorCode;
                GVL_PLC_Tests.EventLog[EventIdx].Message := instTranslationValidation.ErrorMessage;
            END_IF;
            IF ChainMode AND (NOT instTranslationValidation.Report.Aborted OR SuiteWatchdogExpired) AND instBucketValidation.SimGateOk THEN
                // 🔗 Enchaîne vers Bucket (2026-07-16 : 3e maillon Safety→Translation→Bucket)
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteBucket;
                StartBucket := TRUE;
                FirstStepBucket := 10;
            ELSIF ChainMode AND NOT instTranslationValidation.Report.Aborted AND NOT instBucketValidation.SimGateOk THEN
                // Même garde-fou que Safety→Translation : Bucket ne doit jamais démarrer sans son
                // SimGateOk (refuse si M1/M2 en simulation réelle, voir FB_BucketValidation §1).
                GVL_PLC_Tests.Cmd.RunAll := FALSE;
                ChainMode := FALSE; // 🔒 Évite d'agréger un rapport Bucket périmé (suite jamais lancée ce run)
                IF instSafetyValidation.Report.FailureSummary = '' AND instTranslationValidation.Report.FailureSummary = '' THEN
                    GVL_PLC_Tests.Status.FailureSummary := 'Bucket NON TESTEE (SimGateOk=FALSE — verifier simulation reelle M1/M2)';
                ELSIF instTranslationValidation.Report.FailureSummary = '' THEN
                    GVL_PLC_Tests.Status.FailureSummary := CONCAT(instSafetyValidation.Report.FailureSummary, ' || Bucket NON TESTEE (SimGateOk=FALSE — verifier simulation reelle M1/M2)');
                ELSE
                    GVL_PLC_Tests.Status.FailureSummary := CONCAT(instTranslationValidation.Report.FailureSummary, ' || Bucket NON TESTEE (SimGateOk=FALSE — verifier simulation reelle M1/M2)');
                END_IF;
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSE
                // Soit run ciblé (pas de chaînage), soit chaînage interrompu (Translation.Aborted)
                IF ChainMode THEN
                    FinalAborted := instSafetyValidation.Report.Aborted OR instTranslationValidation.Report.Aborted;
                    FinalAnyFailed := instSafetyValidation.AnyFailed OR instTranslationValidation.AnyFailed;
                    IF instSafetyValidation.Report.FailureSummary <> '' AND instTranslationValidation.Report.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := CONCAT(instSafetyValidation.Report.FailureSummary, CONCAT(' || ', instTranslationValidation.Report.FailureSummary));
                    ELSIF instSafetyValidation.Report.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := instSafetyValidation.Report.FailureSummary;
                    ELSE
                        GVL_PLC_Tests.Status.FailureSummary := instTranslationValidation.Report.FailureSummary;
                    END_IF;
                ELSE
                    FinalAborted := instTranslationValidation.Report.Aborted;
                    FinalAnyFailed := instTranslationValidation.AnyFailed;
                    GVL_PLC_Tests.Status.FailureSummary := instTranslationValidation.Report.FailureSummary;
                END_IF;
                GVL_PLC_Tests.Cmd.RunAll := FALSE; // 🔧 Retombe ICI (Done atteint), pas au démarrage
                IF FinalAborted THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
                ELSIF FinalAnyFailed THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
                ELSE
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
                END_IF;
            END_IF;

        // Surveillance de la fin d'exécution — Bucket (ciblée, ou dernier maillon de la chaîne)
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteBucket AND instBucketValidation.Done THEN
            AbortBucket := FALSE;
            IF instBucketValidation.TerminalState <> E_TestTerminalState.TEST_TERMINAL_DONE AND instBucketValidation.Report.RunCounter <> LastLoggedBucketRun THEN
                LastLoggedBucketRun := instBucketValidation.Report.RunCounter;
                GVL_PLC_Tests.EventSequence := GVL_PLC_Tests.EventSequence + 1;
                IF GVL_PLC_Tests.EventCount < GVL_PLC_Tests_Const.MaxTestEvents THEN
                    GVL_PLC_Tests.EventCount := GVL_PLC_Tests.EventCount + 1;
                ELSE
                    GVL_PLC_Tests.EventOverflow := TRUE;
                END_IF;
                EventIdx := UDINT_TO_INT(GVL_PLC_Tests.EventSequence MOD INT_TO_UDINT(GVL_PLC_Tests_Const.MaxTestEvents)) + 1;
                GVL_PLC_Tests.EventLog[EventIdx].Sequence := GVL_PLC_Tests.EventSequence;
                GVL_PLC_Tests.EventLog[EventIdx].Severity := E_TestEventSeverity.TEST_EVENT_ERROR;
                GVL_PLC_Tests.EventLog[EventIdx].SuiteId := GVL_PLC_Tests_Const.SuiteBucket;
                GVL_PLC_Tests.EventLog[EventIdx].CaseId := instBucketValidation.Report.CurrentCaseId;
                GVL_PLC_Tests.EventLog[EventIdx].StepId := instBucketValidation.Report.CurrentStepId;
                GVL_PLC_Tests.EventLog[EventIdx].Code := instBucketValidation.ErrorCode;
                GVL_PLC_Tests.EventLog[EventIdx].Message := instBucketValidation.ErrorMessage;
            END_IF;
            IF ChainMode THEN
                FinalAborted := instSafetyValidation.Report.Aborted OR instTranslationValidation.Report.Aborted OR instBucketValidation.Report.Aborted;
                FinalAnyFailed := instSafetyValidation.AnyFailed OR instTranslationValidation.AnyFailed OR instBucketValidation.AnyFailed;
                // 🏷️ Combine jusqu'à 3 résumés (Safety, Translation, Bucket — seul cas où les 3 ont tourné)
                GVL_PLC_Tests.Status.FailureSummary := '';
                IF instSafetyValidation.Report.FailureSummary <> '' THEN
                    GVL_PLC_Tests.Status.FailureSummary := instSafetyValidation.Report.FailureSummary;
                END_IF;
                IF instTranslationValidation.Report.FailureSummary <> '' THEN
                    IF GVL_PLC_Tests.Status.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := CONCAT(GVL_PLC_Tests.Status.FailureSummary, CONCAT(' || ', instTranslationValidation.Report.FailureSummary));
                    ELSE
                        GVL_PLC_Tests.Status.FailureSummary := instTranslationValidation.Report.FailureSummary;
                    END_IF;
                END_IF;
                IF instBucketValidation.Report.FailureSummary <> '' THEN
                    IF GVL_PLC_Tests.Status.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := CONCAT(GVL_PLC_Tests.Status.FailureSummary, CONCAT(' || ', instBucketValidation.Report.FailureSummary));
                    ELSE
                        GVL_PLC_Tests.Status.FailureSummary := instBucketValidation.Report.FailureSummary;
                    END_IF;
                END_IF;
            ELSE
                FinalAborted := instBucketValidation.Report.Aborted;
                FinalAnyFailed := instBucketValidation.AnyFailed;
                GVL_PLC_Tests.Status.FailureSummary := instBucketValidation.Report.FailureSummary;
            END_IF;
        GVL_PLC_Tests.Cmd.RunAll := FALSE; // 🔧 Retombe ICI (Done atteint), pas au démarrage
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder AND instEncoderValidation.Done THEN
            AbortEncoder := FALSE;
            FinalAborted := instEncoderValidation.Report.Aborted;
            FinalAnyFailed := instEncoderValidation.AnyFailed;
            GVL_PLC_Tests.Status.FailureSummary := instEncoderValidation.Report.FailureSummary;
            IF SuiteWatchdogExpired THEN
                GVL_PLC_Tests.Status.FailureSummary := 'Watchdog suite Encoder/Homing expire';
                FinalAborted := FALSE;
                FinalAnyFailed := TRUE;
            END_IF;
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes AND instModesValidation.Done THEN
            AbortModes := FALSE;
            FinalAborted := instModesValidation.Report.Aborted;
            FinalAnyFailed := instModesValidation.AnyFailed;
            GVL_PLC_Tests.Status.FailureSummary := instModesValidation.Report.FailureSummary;
            IF SuiteWatchdogExpired THEN
                GVL_PLC_Tests.Status.FailureSummary := 'Watchdog suite Modes/Homme-mort expire';
                FinalAborted := FALSE;
                FinalAnyFailed := TRUE;
            END_IF;
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        END_IF;

END_CASE;

// 3. Appel des instances de suites
instSafetyValidation(Start := StartSafety, Abort := AbortSafety, FirstStepId := FirstStepSafety);
instTranslationValidation(Start := StartTranslation, Abort := AbortTranslation, FirstStepId := FirstStepTranslation);
instBucketValidation(Start := StartBucket, Abort := AbortBucket, FirstStepId := FirstStepBucket, instBucket := instBucket, instWinchM2 := instWinchM2);
instEncoderValidation(Start := StartEncoder, Abort := AbortEncoder, FirstStepId := FirstStepEncoder);
instModesValidation(Start := StartModes, Abort := AbortModes, FirstStepId := FirstStepModes);

// 4. Centralisation et recopie vers GVL_PLC_Tests
GVL_PLC_Tests.Status.SimulationActive := GVL_Simulation.SimulationModeActive;
GVL_PLC_Tests.Status.SuiteWatchdogExpired := SuiteWatchdogExpired;
GVL_PLC_Tests.SuiteSafetyValidation := instSafetyValidation.Report;
GVL_PLC_Tests.SuiteTranslationValidation := instTranslationValidation.Report;
GVL_PLC_Tests.SuiteBucketValidation := instBucketValidation.Report;
GVL_PLC_Tests.SuiteEncoderValidation := instEncoderValidation.Report;
GVL_PLC_Tests.SuiteModesValidation := instModesValidation.Report;

// 5. Mise à jour des indicateurs de progression IHM
IF GVL_PLC_Tests.Status.RunState = E_TestRunState.TESTRUN_RUNNING THEN
    GVL_PLC_Tests.Status.ActiveSuiteId := CurrentSuiteIdx;
    IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instTranslationValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instTranslationValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instTranslationValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instTranslationValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instTranslationValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instTranslationValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instTranslationValidation.ErrorMessage;
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteBucket THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instBucketValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instBucketValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instBucketValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instBucketValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instBucketValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instBucketValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instBucketValidation.ErrorMessage;
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instEncoderValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instEncoderValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instEncoderValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instEncoderValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instEncoderValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instEncoderValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instEncoderValidation.ErrorMessage;
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instModesValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instModesValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instModesValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instModesValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instModesValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instModesValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instModesValidation.ErrorMessage;
    ELSE
        GVL_PLC_Tests.Status.ActiveSuiteName := instSafetyValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instSafetyValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instSafetyValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instSafetyValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instSafetyValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instSafetyValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instSafetyValidation.ErrorMessage;
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

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteBucket THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instBucketValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instBucketValidation.Report.Cases[Idx].Ok THEN
                PassedCount := PassedCount + 1;
            ELSE
                FailedCount := FailedCount + 1;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instEncoderValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instEncoderValidation.Report.Cases[Idx].Ok THEN
                PassedCount := PassedCount + 1;
            ELSE
                FailedCount := FailedCount + 1;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

IF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instModesValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instModesValidation.Report.Cases[Idx].Ok THEN
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
