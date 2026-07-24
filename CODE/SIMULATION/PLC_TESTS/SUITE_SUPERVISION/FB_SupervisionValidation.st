(* ============================================================================
   🧪 FB_SupervisionValidation — Suite PLC Persistance Config (chantier ConfigPersistence)
   ============================================================================
   🎯 Rôle : valide le mécanisme générique FB_CfgPersistBridge_<Type> (restauration
      PERSISTENT->IHM au boot, sauvegarde continue IHM->PERSISTENT, alarme
      ConfigRestoredFromPersistent) en profondeur sur M1M2Sync (le plus simple), puis
      un balayage de couverture léger (lecture seule, sans risque) des 5 autres domaines
      à pont générique, puis un test dédié pour Translation (pattern manuel, pas de pont).
   📄 Couvre (TASK_CONTEXT_CONFIG-PERSIST-01.yaml, T65) :
      TC-CP1 : Restauration PERSISTENT->IHM quand Initialized=FALSE (M1M2Sync)
      TC-CP2 : Alarme ConfigRestoredFromPersistent ne s'éteint QUE sur front BtnAckConfigRestored
      TC-CP3 : Sauvegarde continue IHM->PERSISTENT stable après restauration (pas de corruption)
      TC-CP4 : Balayage de couverture (lecture seule) — Cycle/Commun/Bucket/WinchM1/WinchM2
               ont chacun Cfg.Initialized=TRUE en fonctionnement normal
      TC-CP5 : Translation.Cmd.SetFreq_Hz (pattern manuel, pas de pont générique) — même
               restauration/alarme que TC-CP1, Lot 4 requis
   ⚠️ TC-CP1/CP2/CP3/CP5 forcent des variables GVL_PERSISTENT réelles (Sync, Translation) —
      sauvegardées au démarrage du test, restaurées dans les 3 chemins de sortie (fin normale,
      Abort, watchdog). Ne JAMAIS retirer cette sauvegarde/restauration.
   🧩 Même moteur allégé (CASE direct) que FB_ModesValidation — pas de StepTable/CheckTable.
   ============================================================================ *)

FUNCTION_BLOCK PUBLIC FB_SupervisionValidation
VAR_INPUT
    Start       : BOOL;
    Abort       : BOOL;
    CaseId      : INT; // 0=tous ; 1..5=cas ciblé
END_VAR
VAR_OUTPUT
    Busy              : BOOL;
    Done              : BOOL;
    AnyFailed         : BOOL;
    StepElapsed       : TIME;
    Report            : ST_TestSuiteReport;
    TerminalState     : E_TestTerminalState;
    ConfigError       : BOOL;
    ConfigErrorStepId : INT;
    ErrorCode         : INT;
    ErrorMessage      : STRING(160);
END_VAR
VAR
    StartPrev       : BOOL;
    Step            : INT;
    CurrentCaseId   : INT;
    RequestedCaseId : INT;
    StepStarted     : BOOL;
    StepTimer       : TON;
    StepLimit       : TIME;
    StepFailed      : BOOL;
    StepPassed      : BOOL;
    Index           : INT;

    // 🛡️ Sauvegardes obligatoires (voir §0/§1) — restaurées dans les 3 chemins de sortie.
    BackupSyncTolerance          : REAL;
    BackupSyncInitialized        : BOOL;
    BackupTranslationFreq        : REAL;
    BackupTranslationInitialized : BOOL;
END_VAR

// === IMPLEMENTATION ===

IF Abort THEN
    // 🛡️ Restauration obligatoire AVANT de sortir (voir §0).
    _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
    _TranslationSetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
    GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.Aborted := TRUE;
    Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState;
    Report.FailureSummary := 'Supervision/Persistance : ABORTED';
    RETURN;
END_IF;

IF Start AND NOT StartPrev AND NOT Busy THEN
    StartPrev := TRUE;
    Busy := TRUE;
    Done := FALSE;
    AnyFailed := FALSE;
    ConfigError := FALSE;
    ErrorCode := 0;
    ErrorMessage := '';
    TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    IF CaseId < 0 OR CaseId > 5 THEN
        Busy := FALSE;
        Done := TRUE;
        AnyFailed := TRUE;
        ConfigError := TRUE;
        ErrorCode := 6001;
        ErrorMessage := 'Supervision CaseId invalide';
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        Report.TerminalState := TerminalState;
        Report.AnyFailed := TRUE;
        Report.ErrorCode := ErrorCode;
        Report.ErrorMessage := ErrorMessage;
        RETURN;
    END_IF;
    RequestedCaseId := CaseId;

    // 🛡️ Sauvegarde obligatoire AVANT toute modification (voir §0) — toujours faite, quel que
    // soit le cas demandé, pour rester sûr quel que soit le chemin de sortie emprunté.
    BackupSyncTolerance          := _SyncCfgPersist.CfgSyncTolerance_M;
    BackupSyncInitialized        := GVL_IHM.M1M2Sync.Cfg.Initialized;
    BackupTranslationFreq        := _TranslationSetFreq_Hz;
    BackupTranslationInitialized := GVL_IHM.TranslationM3.Cmd.Initialized;

    CASE RequestedCaseId OF
        1: Step := 10;
        2: Step := 20;
        3: Step := 30;
        4: Step := 40;
        5: Step := 50;
    ELSE
        Step := 10; // run all, démarre à TC-CP1
    END_CASE;
    Report.Name := 'Supervision / Persistance Config Validation';
    Report.InProgress := TRUE;
    Report.AllPassed := FALSE;
    Report.AnyFailed := FALSE;
    Report.Aborted := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 0;
    Report.ErrorMessage := '';
    Report.FailureSummary := '';
    Report.CurrentStepId := Step;
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
ELSIF NOT Start THEN
    StartPrev := FALSE;
END_IF;

IF NOT Busy THEN
    RETURN;
END_IF;

StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.CurrentStepId := Step;
CurrentCaseId := (Step / 10);
Report.CurrentCaseId := CurrentCaseId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    CASE Step OF
        10: StepLimit := T#200MS;
        11: StepLimit := T#500MS;
        20: StepLimit := T#200MS;
        21: StepLimit := T#500MS;
        22: StepLimit := T#500MS;
        23: StepLimit := T#500MS;
        30: StepLimit := T#200MS;
        31: StepLimit := T#500MS;
        40, 41, 42, 43, 44: StepLimit := T#2S; // généreux : la vraie machine a pu booter juste avant ce test
        50: StepLimit := T#200MS;
        51: StepLimit := T#500MS;
        52: StepLimit := T#1S;
    ELSE
        ConfigError := TRUE;
        ConfigErrorStepId := Step;
        ErrorCode := 6002;
        ErrorMessage := 'Supervision étape inconnue';
        StepLimit := T#0s;
    END_CASE;
END_IF;

StepTimer(IN := TRUE, PT := StepLimit);

CASE Step OF
    // ─────────── TC-CP1 : Restauration PERSISTENT->IHM (M1M2Sync) ───────────
    10:
        // Arrange : valeur PERSISTENT sentinelle distincte du défaut réel (0.25), IHM au défaut
        // struct (0.0) + Initialized:=FALSE -> déclenche la restauration au prochain passage du
        // pont réel (PRG_09_Supervision.instCfgPersistBridgeSync, tourne chaque scan MainTask).
        _SyncCfgPersist.CfgSyncTolerance_M := 0.42;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := 0.0;
        GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE;
        StepPassed := TRUE;
        Step := 11;
        StepStarted := FALSE;

    11:
        // Assert : Hmi restauré depuis Persist, Initialized repassé TRUE.
        IF (GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M = 0.42) AND GVL_IHM.M1M2Sync.Cfg.Initialized THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 1 THEN Step := 0; ELSE Step := 20; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP2 : Alarme ConfigRestoredFromPersistent, doctrine reset=front ───────────
    20:
        // Arrange autonome : TC-CP2 doit aussi être exécutable seul (CaseId=2),
        // sans dépendre de la sentinelle créée par TC-CP1.
        _SyncCfgPersist.CfgSyncTolerance_M := 0.42;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := 0.0;
        GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE; // déclenche restauration + alarme
        StepPassed := TRUE;
        Step := 21;
        StepStarted := FALSE;

    21:
        IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            StepPassed := TRUE;
            Step := 22;
            StepStarted := FALSE;
        END_IF;

    22:
        // L'alarme ne doit JAMAIS s'éteindre seule (doctrine reset=front, REX 2026-07-23).
        IF StepElapsed >= T#200MS THEN
            IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
                StepPassed := TRUE;
                Step := 23;
                StepStarted := FALSE;
            ELSE
                StepFailed := TRUE; // régression doctrine reset=front
            END_IF;
        END_IF;

    23:
        // Acquittement par front opérateur.
        GVL_IHM.Commun.BtnAckConfigRestored := TRUE;
        IF NOT GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
            StepPassed := TRUE;
            IF RequestedCaseId = 2 THEN Step := 0; ELSE Step := 30; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP3 : Sauvegarde continue stable (pas de corruption) ───────────
    30:
        // Arrange autonome : TC-CP3 doit aussi être exécutable seul (CaseId=3).
        _SyncCfgPersist.CfgSyncTolerance_M := 0.42;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := 0.0;
        GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE;
        StepPassed := TRUE;
        Step := 31;
        StepStarted := FALSE;

    31:
        IF StepElapsed >= T#200MS THEN
            IF (_SyncCfgPersist.CfgSyncTolerance_M = 0.42)
               AND (GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M = 0.42)
               AND GVL_IHM.M1M2Sync.Cfg.Initialized THEN
                StepPassed := TRUE;
                IF RequestedCaseId = 3 THEN Step := 0; ELSE Step := 40; END_IF;
                StepStarted := FALSE;
            ELSE
                StepFailed := TRUE; // Persist ou Hmi a dérivé -> corruption
            END_IF;
        END_IF;

    // ─────────── TC-CP4 : Balayage de couverture (lecture seule, sans risque) ───────────
    40:
        IF GVL_IHM.Cycle.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 41; StepStarted := FALSE;
        END_IF;

    41:
        IF GVL_IHM.Commun.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 42; StepStarted := FALSE;
        END_IF;

    42:
        IF GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 43; StepStarted := FALSE;
        END_IF;

    43:
        IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 44; StepStarted := FALSE;
        END_IF;

    44:
        IF GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 4 THEN Step := 0; ELSE Step := 50; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP5 : Translation SetFreq_Hz (pattern manuel, Lot 4 requis) ───────────
    50:
        _TranslationSetFreq_Hz := 12.5; // valeur sentinelle distincte du défaut réel (0.0)
        GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := 0.0;
        GVL_IHM.TranslationM3.Cmd.Initialized := FALSE;
        StepPassed := TRUE;
        Step := 51;
        StepStarted := FALSE;

    51:
        IF (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz = 12.5) AND GVL_IHM.TranslationM3.Cmd.Initialized THEN
            StepPassed := TRUE;
            Step := 52;
            StepStarted := FALSE;
        END_IF;

    52:
        IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            GVL_IHM.Commun.BtnAckConfigRestored := TRUE;
            IF NOT GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
                GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
                StepPassed := TRUE;
                Step := 0;
                StepStarted := FALSE;
            END_IF;
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
    IF NOT StepPassed THEN
        Step := 0; // Échec ou timeout = fin immédiate.
    END_IF;
    StepPassed := FALSE;
    StepFailed := FALSE;
    StepTimer(IN := FALSE, PT := StepLimit);
    StepElapsed := T#0s;
    IF Step = 0 THEN
        // 🛡️ Restauration obligatoire AVANT de sortir (voir §0) — fin normale ou échec/timeout.
        _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
        GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
        _TranslationSetFreq_Hz := BackupTranslationFreq;
        GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
        GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
        GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
        GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
        Busy := FALSE;
        Done := TRUE;
        Report.InProgress := FALSE;
        Report.AnyFailed := AnyFailed;
        Report.AllPassed := NOT AnyFailed;
        Report.TerminalState := SEL(AnyFailed, E_TestTerminalState.TEST_TERMINAL_DONE, E_TestTerminalState.TEST_TERMINAL_FAILED);
        TerminalState := Report.TerminalState;
        Report.Cases[1].Name := 'TC-CP1..CP5 Persistance Config';
        Report.Cases[1].Executed := TRUE;
        Report.Cases[1].Ok := NOT AnyFailed;
        Report.Cases[1].FailedStepId := 0;
        Report.Cases[1].FailReason := E_TestFailReason.FAIL_NONE;
        IF AnyFailed THEN
            Report.Cases[1].FailedStepId := Report.CurrentStepId;
            Report.Cases[1].FailReason := E_TestFailReason.FAIL_CHECK;
            Report.FailureSummary := CONCAT('Supervision/Persistance : échec étape ', INT_TO_STRING(Report.CurrentStepId));
        END_IF;
        Report.Cases[1].Duration := Report.Duration;
    ELSE
        StepStarted := FALSE;
    END_IF;
END_IF;

// Limite globale de sécurité de la suite : 90 s maximum.
IF Report.Duration >= T#90s AND Busy THEN
    // 🛡️ Restauration obligatoire AVANT de sortir (voir §0) — watchdog.
    _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
    _TranslationSetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
    GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_WATCHDOG_TIMEOUT;
    Report.InProgress := FALSE;
    Report.AnyFailed := TRUE;
    Report.AllPassed := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 6003;
    Report.ErrorMessage := 'Watchdog Supervision/Persistance expiré';
    Report.FailureSummary := Report.ErrorMessage;
END_IF;
