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
    instHeartbeatValidation   : FB_HeartbeatValidation;
    instSupervisionValidation : FB_SupervisionValidation;

    // Triggers pour IHM tactiles
    RunAllTrig           : R_TRIG;
    AbortTrig            : R_TRIG;
    ClearReportTrig      : R_TRIG;

    // Variables de commande internes
    StartSafety          : BOOL;
    AbortSafety          : BOOL;
    RequestedCaseSafety  : INT;
    StartTranslation     : BOOL;
    AbortTranslation     : BOOL;
    RequestedCaseTranslation : INT; // 🆕 2026-07-22 : CaseId direct (0=toutes,1..6) — JAMAIS de FirstStepId (audit v1.0 C2)
    StartBucket           : BOOL;
    AbortBucket           : BOOL;
    RequestedCaseBucket   : INT;
    StartEncoder          : BOOL;
    AbortEncoder          : BOOL;
    RequestedCaseEncoder  : INT;
    StartModes            : BOOL;
    AbortModes            : BOOL;
    RequestedCaseModes    : INT;
    StartHeartbeat        : BOOL;
    AbortHeartbeat        : BOOL;
    RequestedCaseHeartbeat : INT;
    StartSupervision       : BOOL;
    AbortSupervision       : BOOL;
    RequestedCaseSupervision : INT;
    StartFramework        : BOOL;
    FrameworkScanCount    : INT;

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
    LastLoggedHeartbeatRun : UDINT;
    LastLoggedSupervisionRun : UDINT;
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
        StartHeartbeat := FALSE;
        AbortHeartbeat := FALSE;
        StartSupervision := FALSE;
        AbortSupervision := FALSE;
        StartFramework := FALSE;
        SuiteElapsed := T#0s;
        SuiteWatchdogExpired := FALSE;

        // 🧪 RunAll prioritaire : démarre une campagne complète depuis Safety.
        IF RunAllTrig.Q THEN
            ChainMode := TRUE;
            CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSafety;
            RequestedCaseSafety := 0;
            RequestedCaseTranslation := 0;
            RequestedCaseBucket := 0;
            RequestedCaseEncoder := 0;
            RequestedCaseModes := 0;
            RequestedCaseHeartbeat := 0;
            RequestedCaseSupervision := 0;
            FinalAborted := FALSE;
            FinalAnyFailed := FALSE;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;
            GVL_PLC_Tests.Status.FailureSummary := '';
            StartSafety := TRUE;
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
        // Normalisation des commandes unitaires vers RunSuite.
        ELSIF GVL_PLC_Tests.Cmd.RunSafety THEN
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
        ELSIF GVL_PLC_Tests.Cmd.RunHeartbeat THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteHeartbeat;
            GVL_PLC_Tests.Cmd.RunHeartbeat := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunSupervision THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteSupervision;
            GVL_PLC_Tests.Cmd.RunSupervision := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunFramework THEN
            StartFramework := TRUE;
            GVL_PLC_Tests.Cmd.RunFramework := FALSE;
        END_IF;

        // Démarrage d'une suite ciblée (Safety)
        IF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSafety THEN
            IF GVL_Simulation.SimulationModeActive AND instSafetyValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSafety;
                StartSafety := TRUE;
                RequestedCaseSafety := GVL_PLC_Tests.Cmd.RunCase;
                GVL_PLC_Tests.Status.FailureSummary := ''; // 🔄 RAZ à chaque nouveau run
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage d'une suite ciblée (Translation)
        // 🆕 2026-07-22 : CaseId transmis TEL QUEL (0=toutes,1..6) — le manager ne
        // connaît plus aucun détail interne d'étape (audit v1.0 C2). Refus de
        // gate désormais explicite PRECONDITION_FAILED, jamais silencieux (C3).
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteTranslation THEN
            // La suite possède seule sa fixture : même un refus produit un rapport neuf
            // PRECONDITION_FAILED, jamais un Status correct avec un ancien rapport.
            ChainMode := FALSE;
            CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteTranslation;
            StartTranslation := TRUE;
            RequestedCaseTranslation := GVL_PLC_Tests.Cmd.RunCase;
            GVL_PLC_Tests.Status.FailureSummary := '';
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage d'une suite ciblée (Bucket)
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteBucket THEN
            IF GVL_Simulation.SimulationModeActive AND instBucketValidation.SimGateOk THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteBucket;
                StartBucket := TRUE;
                RequestedCaseBucket := GVL_PLC_Tests.Cmd.RunCase;
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
                RequestedCaseEncoder := GVL_PLC_Tests.Cmd.RunCase;
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
                RequestedCaseModes := GVL_PLC_Tests.Cmd.RunCase;
                GVL_PLC_Tests.Status.FailureSummary := '';
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage suite Heartbeat IHM↔PLC.
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteHeartbeat THEN
            IF GVL_Simulation.SimulationModeActive
               AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal
               AND NOT GVL_Simulation.SensorM2ContactorFeedbackIsReal THEN
                ChainMode := FALSE;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteHeartbeat;
                StartHeartbeat := TRUE;
                RequestedCaseHeartbeat := GVL_PLC_Tests.Cmd.RunCase;
                GVL_PLC_Tests.Status.FailureSummary := '';
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            END_IF;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;

        // Démarrage suite Supervision/Persistance config : autonome, sans simulation matérielle.
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSupervision THEN
            ChainMode := FALSE;
            CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSupervision;
            StartSupervision := TRUE;
            RequestedCaseSupervision := GVL_PLC_Tests.Cmd.RunCase;
            GVL_PLC_Tests.Status.FailureSummary := '';
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;
        END_IF;

        // 🧪 Smoke test géré directement ici : aucune instance/table/runtime.
        IF StartFramework THEN
            ChainMode := FALSE;
            FrameworkScanCount := 0;
            GVL_PLC_Tests.FrameworkResult.InProgress := TRUE;
            GVL_PLC_Tests.FrameworkResult.AllPassed := FALSE;
            GVL_PLC_Tests.FrameworkResult.AnyFailed := FALSE;
            GVL_PLC_Tests.FrameworkResult.CurrentTestId := 1;
            GVL_PLC_Tests.FrameworkResult.FailedTestId := 0;
            GVL_PLC_Tests.FrameworkResult.TestsPassed := 0;
            GVL_PLC_Tests.FrameworkResult.TestsFailed := 0;
            GVL_PLC_Tests.FrameworkResult.ErrorMessage := '';
            GVL_PLC_Tests.FrameworkResult.RunCounter := GVL_PLC_Tests.FrameworkResult.RunCounter + 1;
            GVL_PLC_Tests.Status.FailureSummary := '';
            CurrentSuiteIdx := 7;
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
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
        StartEncoder := FALSE;
        StartModes := FALSE;
        StartHeartbeat := FALSE;
        StartSupervision := FALSE;
        StartFramework := FALSE;

        // 🧪 Smoke framework natif : 3 scans, sans appeler aucun moteur de test.
        IF CurrentSuiteIdx = 7 THEN
            FrameworkScanCount := FrameworkScanCount + 1;
            IF FrameworkScanCount >= 3 THEN
                GVL_PLC_Tests.FrameworkResult.InProgress := FALSE;
                GVL_PLC_Tests.FrameworkResult.AllPassed := TRUE;
                GVL_PLC_Tests.FrameworkResult.AnyFailed := FALSE;
                GVL_PLC_Tests.FrameworkResult.TestsPassed := 1;
                GVL_PLC_Tests.FrameworkResult.TestsFailed := 0;
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        END_IF;

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
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteHeartbeat THEN
                AbortHeartbeat := TRUE;
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
                AbortSupervision := TRUE;
            ELSE
                AbortBucket := TRUE;
            END_IF;
        END_IF;

        // Abandon propre ou perte du mode Simulation — coupe la suite active
        IF AbortTrig.Q OR ((NOT GVL_Simulation.SimulationModeActive) AND (CurrentSuiteIdx <> GVL_PLC_Tests_Const.SuiteSupervision)) THEN
            AbortSafety := TRUE;
            AbortTranslation := TRUE;
            AbortBucket := TRUE;
            AbortEncoder := TRUE;
            AbortModes := TRUE;
            AbortHeartbeat := TRUE;
            AbortSupervision := TRUE;
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
                SuiteElapsed := T#0s;
                StartTranslation := TRUE;
                RequestedCaseTranslation := 0; // Enchaînement RunAll -> toutes les cases Translation
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
                SuiteElapsed := T#0s;
                StartBucket := TRUE;
                RequestedCaseBucket := 0;
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
                // Campagne complète : Bucket terminé → Encoder.
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteEncoder;
                SuiteElapsed := T#0s;
                StartEncoder := TRUE;
                RequestedCaseEncoder := 0;
                // Conserve les verdicts précédents pour le verdict final.
                FinalAborted := FinalAborted OR instSafetyValidation.Report.Aborted OR instTranslationValidation.Report.Aborted OR instBucketValidation.Report.Aborted;
                FinalAnyFailed := FinalAnyFailed OR instSafetyValidation.AnyFailed OR instTranslationValidation.AnyFailed OR instBucketValidation.AnyFailed;
                // 🏷️ Combine jusqu'à 3 résumés intermédiaires.
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
                GVL_PLC_Tests.Cmd.RunAll := FALSE;
                IF FinalAborted THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
                ELSIF FinalAnyFailed THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
                ELSE
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
                END_IF;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteHeartbeat AND instHeartbeatValidation.Done THEN
            AbortHeartbeat := FALSE;
            FinalAborted := FinalAborted OR instHeartbeatValidation.Report.Aborted;
            FinalAnyFailed := FinalAnyFailed OR instHeartbeatValidation.AnyFailed;
            IF instHeartbeatValidation.Report.FailureSummary <> '' THEN
                IF GVL_PLC_Tests.Status.FailureSummary <> '' THEN
                    GVL_PLC_Tests.Status.FailureSummary := CONCAT(GVL_PLC_Tests.Status.FailureSummary, CONCAT(' || ', instHeartbeatValidation.Report.FailureSummary));
                ELSE
                    GVL_PLC_Tests.Status.FailureSummary := instHeartbeatValidation.Report.FailureSummary;
                END_IF;
            END_IF;
            // ChainMode reste mémorisé au terminal pour agréger toute la campagne.
            // Le prochain lancement ciblé le remet explicitement à FALSE.
            GVL_PLC_Tests.Cmd.RunAll := FALSE;
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder AND instEncoderValidation.Done THEN
            AbortEncoder := FALSE;
            IF ChainMode THEN
                FinalAborted := FinalAborted OR instEncoderValidation.Report.Aborted;
                FinalAnyFailed := FinalAnyFailed OR instEncoderValidation.AnyFailed;
                IF instEncoderValidation.Report.FailureSummary <> '' THEN
                    IF GVL_PLC_Tests.Status.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := CONCAT(GVL_PLC_Tests.Status.FailureSummary, CONCAT(' || ', instEncoderValidation.Report.FailureSummary));
                    ELSE
                        GVL_PLC_Tests.Status.FailureSummary := instEncoderValidation.Report.FailureSummary;
                    END_IF;
                END_IF;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteModes;
                SuiteElapsed := T#0s;
                StartModes := TRUE;
                RequestedCaseModes := 0;
            ELSE
                FinalAborted := instEncoderValidation.Report.Aborted;
                FinalAnyFailed := instEncoderValidation.AnyFailed;
                GVL_PLC_Tests.Status.FailureSummary := instEncoderValidation.Report.FailureSummary;
            END_IF;
            IF SuiteWatchdogExpired THEN
                GVL_PLC_Tests.Status.FailureSummary := 'Watchdog suite Encoder/Homing expire';
                FinalAborted := FALSE;
                FinalAnyFailed := TRUE;
            END_IF;
            IF NOT ChainMode THEN
                IF FinalAborted THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
                ELSIF FinalAnyFailed THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
                ELSE
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
                END_IF;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes AND instModesValidation.Done THEN
            AbortModes := FALSE;
            IF ChainMode THEN
                FinalAborted := FinalAborted OR instModesValidation.Report.Aborted;
                FinalAnyFailed := FinalAnyFailed OR instModesValidation.AnyFailed;
                IF instModesValidation.Report.FailureSummary <> '' THEN
                    IF GVL_PLC_Tests.Status.FailureSummary <> '' THEN
                        GVL_PLC_Tests.Status.FailureSummary := CONCAT(GVL_PLC_Tests.Status.FailureSummary, CONCAT(' || ', instModesValidation.Report.FailureSummary));
                    ELSE
                        GVL_PLC_Tests.Status.FailureSummary := instModesValidation.Report.FailureSummary;
                    END_IF;
                END_IF;
                CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteHeartbeat;
                SuiteElapsed := T#0s;
                StartHeartbeat := TRUE;
                RequestedCaseHeartbeat := 0;
            ELSE
                FinalAborted := instModesValidation.Report.Aborted;
                FinalAnyFailed := instModesValidation.AnyFailed;
                GVL_PLC_Tests.Status.FailureSummary := instModesValidation.Report.FailureSummary;
            END_IF;
            IF SuiteWatchdogExpired THEN
                GVL_PLC_Tests.Status.FailureSummary := 'Watchdog suite Modes/Homme-mort expire';
                FinalAborted := FALSE;
                FinalAnyFailed := TRUE;
            END_IF;
            IF NOT ChainMode THEN
                IF FinalAborted THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
                ELSIF FinalAnyFailed THEN
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
                ELSE
                    GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
                END_IF;
            END_IF;
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision AND instSupervisionValidation.Done THEN
            AbortSupervision := FALSE;
            IF instSupervisionValidation.TerminalState <> E_TestTerminalState.TEST_TERMINAL_DONE AND instSupervisionValidation.Report.RunCounter <> LastLoggedSupervisionRun THEN
                LastLoggedSupervisionRun := instSupervisionValidation.Report.RunCounter;
                GVL_PLC_Tests.EventSequence := GVL_PLC_Tests.EventSequence + 1;
                IF GVL_PLC_Tests.EventCount < GVL_PLC_Tests_Const.MaxTestEvents THEN
                    GVL_PLC_Tests.EventCount := GVL_PLC_Tests.EventCount + 1;
                ELSE
                    GVL_PLC_Tests.EventOverflow := TRUE;
                END_IF;
                EventIdx := UDINT_TO_INT(GVL_PLC_Tests.EventSequence MOD INT_TO_UDINT(GVL_PLC_Tests_Const.MaxTestEvents)) + 1;
                GVL_PLC_Tests.EventLog[EventIdx].Sequence := GVL_PLC_Tests.EventSequence;
                GVL_PLC_Tests.EventLog[EventIdx].Severity := E_TestEventSeverity.TEST_EVENT_ERROR;
                GVL_PLC_Tests.EventLog[EventIdx].SuiteId := GVL_PLC_Tests_Const.SuiteSupervision;
                GVL_PLC_Tests.EventLog[EventIdx].CaseId := instSupervisionValidation.Report.CurrentCaseId;
                GVL_PLC_Tests.EventLog[EventIdx].StepId := instSupervisionValidation.Report.CurrentStepId;
                GVL_PLC_Tests.EventLog[EventIdx].Code := instSupervisionValidation.ErrorCode;
                GVL_PLC_Tests.EventLog[EventIdx].Message := instSupervisionValidation.ErrorMessage;
            END_IF;
            FinalAborted := instSupervisionValidation.Report.Aborted;
            FinalAnyFailed := instSupervisionValidation.AnyFailed;
            GVL_PLC_Tests.Status.FailureSummary := instSupervisionValidation.Report.FailureSummary;
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
instSafetyValidation(Start := StartSafety, Abort := AbortSafety, CaseId := RequestedCaseSafety);
instTranslationValidation(Start := StartTranslation, Abort := AbortTranslation, CaseId := RequestedCaseTranslation);
instBucketValidation(Start := StartBucket, Abort := AbortBucket, CaseId := RequestedCaseBucket, instBucket := instBucket, instWinchM2 := instWinchM2);
instEncoderValidation(Start := StartEncoder, Abort := AbortEncoder, CaseId := RequestedCaseEncoder);
instModesValidation(Start := StartModes, Abort := AbortModes, CaseId := RequestedCaseModes);
instHeartbeatValidation(Start := StartHeartbeat, Abort := AbortHeartbeat, CaseId := RequestedCaseHeartbeat);
instSupervisionValidation(Start := StartSupervision, Abort := AbortSupervision, CaseId := RequestedCaseSupervision);

// 4. Centralisation et recopie vers GVL_PLC_Tests
GVL_PLC_Tests.Status.SimulationActive := GVL_Simulation.SimulationModeActive;
GVL_PLC_Tests.Status.SuiteWatchdogExpired := SuiteWatchdogExpired;
GVL_PLC_Tests.SuiteSafetyValidation := instSafetyValidation.Report;
GVL_PLC_Tests.SuiteTranslationValidation := instTranslationValidation.Report;
GVL_PLC_Tests.SuiteTranslationResult := instTranslationValidation.Result; // 🆕 Résultat plat clair
GVL_PLC_Tests.SuiteBucketValidation := instBucketValidation.Report;
GVL_PLC_Tests.SuiteEncoderValidation := instEncoderValidation.Report;
GVL_PLC_Tests.SuiteModesValidation := instModesValidation.Report;
GVL_PLC_Tests.SuiteHeartbeatValidation := instHeartbeatValidation.Report;
GVL_PLC_Tests.SuiteSupervisionValidation := instSupervisionValidation.Report;

// 5. Mise à jour des indicateurs de progression IHM
IF GVL_PLC_Tests.Status.RunState = E_TestRunState.TESTRUN_RUNNING THEN
    GVL_PLC_Tests.Status.ActiveSuiteId := CurrentSuiteIdx;
    // 🧪 L'autotest framework a sa propre progression : ne jamais afficher
    // le rapport Safety résiduel lorsque CurrentSuiteIdx=7.
    IF CurrentSuiteIdx = 7 THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := 'Framework Validation';
        GVL_PLC_Tests.Status.ActiveCaseId := GVL_PLC_Tests.FrameworkResult.CurrentTestId;
        GVL_PLC_Tests.Status.ActiveStepId := GVL_PLC_Tests.FrameworkResult.CurrentTestId;
        GVL_PLC_Tests.Status.StepElapsed := T#0s;
        GVL_PLC_Tests.Status.TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
        GVL_PLC_Tests.Status.ErrorCode := GVL_PLC_Tests.FrameworkResult.FailedTestId;
        GVL_PLC_Tests.Status.ErrorMessage := GVL_PLC_Tests.FrameworkResult.ErrorMessage;
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteTranslation THEN
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
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteHeartbeat THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instHeartbeatValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instHeartbeatValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instHeartbeatValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instHeartbeatValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instHeartbeatValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instHeartbeatValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instHeartbeatValidation.ErrorMessage;
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instSupervisionValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instSupervisionValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instSupervisionValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instSupervisionValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instSupervisionValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instSupervisionValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instSupervisionValidation.ErrorMessage;
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

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteEncoder THEN
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

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteModes THEN
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

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteHeartbeat THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instHeartbeatValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instHeartbeatValidation.Report.Cases[Idx].Ok THEN
                PassedCount := PassedCount + 1;
            ELSE
                FailedCount := FailedCount + 1;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instSupervisionValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instSupervisionValidation.Report.Cases[Idx].Ok THEN
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
