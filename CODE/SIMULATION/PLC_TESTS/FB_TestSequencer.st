FUNCTION_BLOCK FB_TestSequencer
VAR_INPUT
    Start       : BOOL;              // Front : lance à FirstStepId
    Abort       : BOOL;              // Niveau : arrêt immédiat propre
    FirstStepId : INT;               // Run all = 1er SETUP ; run one = FirstStep du case visé
END_VAR
VAR_IN_OUT                           // 🔗 zéro copie
    StepTable      : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable     : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable      : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
    InvariantTable : ARRAY[1..GVL_PLC_Tests_Const.MaxInvariants] OF ST_TestInvariantConfig;
    ProbeBool      : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool]  OF BOOL;
    ProbeDint      : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint]  OF DINT;
    ProbeReal      : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal]  OF REAL;
    Report         : ST_TestSuiteReport;
END_VAR
VAR_OUTPUT
    Busy                : BOOL;
    Done                : BOOL;
    AnyFailed           : BOOL;
    ConfigError         : BOOL;      // 🔒 Table invalide -> refus de lancer
    ConfigErrorStepId   : INT;
    ConfigErrorCheckIdx : INT;
    CurrentStepId       : INT;
    ActiveStimulusId    : INT;       // ⚡ consommé par le domaine
    StepElapsed         : TIME;      // Pour l'IHM
END_VAR
VAR
    StartTrig           : R_TRIG;
    StepTimer           : TON;
    DwellTimer          : TON;
    Checks              : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF FB_TestCheck;
    InvChecks           : ARRAY[1..GVL_PLC_Tests_Const.MaxInvariants]    OF FB_TestCheck;
    InvArmed            : ARRAY[1..GVL_PLC_Tests_Const.MaxInvariants]    OF BOOL;
    
    // Variables de contrôle internes
    StepStarted         : BOOL;
    CurrentCaseId       : INT;
    Idx                 : INT;
    Jdx                 : INT;
    Kdx                 : INT;
    Valid               : BOOL;

    // 🔧 REX : locaux remontés depuis des blocs VAR imbriqués dans le corps
    AllChecksPassed     : BOOL;
    AnyCheckFailed      : BOOL;
    FailedCheckIdxLocal : INT;
    FailReasonLocal     : E_TestFailReason;
    ObsBoolLocal        : BOOL;
    ObsDintLocal        : DINT;
    ObsRealLocal        : REAL;
    NeverDuringPassed   : BOOL;
    SuiteAllPassed      : BOOL;
    FirstFailedCase     : INT;
    CaseIdx             : INT;
    CaseStartStep       : INT;
    CaseStep            : INT;
    CaseOk              : BOOL;
    CaseExecuted        : BOOL;
    CaseFailedStep      : INT;
    CaseDuration        : TIME;
    CaseFailReason      : E_TestFailReason;

    // 🏷️ Construction de Report.FailureSummary (1 ligne lisible, tous les cas en échec)
    ReasonText          : STRING(20);
    EntryText           : STRING(80);
END_VAR
// === IMPLEMENTATION ===
StartTrig(CLK := Start);

// 1. Validation de la configuration sur front de Start
IF StartTrig.Q THEN
    ConfigError := FALSE;
    ConfigErrorStepId := 0;
    ConfigErrorCheckIdx := 0;
    
    // Validation des étapes
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
        IF StepTable[Idx].CaseId > 0 THEN
            // Vérification des NextOn
            IF StepTable[Idx].NextOnPass < 0 OR StepTable[Idx].NextOnPass > GVL_PLC_Tests_Const.MaxSteps THEN
                ConfigError := TRUE;
                ConfigErrorStepId := Idx;
            ELSIF StepTable[Idx].NextOnFail < 0 OR StepTable[Idx].NextOnFail > GVL_PLC_Tests_Const.MaxSteps THEN
                ConfigError := TRUE;
                ConfigErrorStepId := Idx;
            END_IF;
            
            // Vérification du Timeout
            IF StepTable[Idx].TimeoutPT <= T#0s THEN
                // Sauf si tous les checks de cette étape sont NEVER_DURING, mais restons stricts : TimeoutPT requis
                ConfigError := TRUE;
                ConfigErrorStepId := Idx;
            END_IF;
            
            // Vérification des Checks indexés par l'étape
            FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
                Kdx := StepTable[Idx].CheckIdx[Jdx];
                IF Kdx > 0 THEN
                    IF Kdx > GVL_PLC_Tests_Const.MaxChecks THEN
                        ConfigError := TRUE;
                        ConfigErrorStepId := Idx;
                        ConfigErrorCheckIdx := Kdx;
                    ELSE
                        // Validation de la sonde associée au check
                        CASE CheckTable[Kdx].Kind OF
                            E_TestCheckKind.BOOL_EQUAL, E_TestCheckKind.BOOL_RISING, E_TestCheckKind.BOOL_FALLING:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeBool THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                END_IF;
                            E_TestCheckKind.DINT_EQUAL, E_TestCheckKind.DINT_NOT_EQUAL, E_TestCheckKind.DINT_IN_RANGE,
                            E_TestCheckKind.WORD_MASK_ALL, E_TestCheckKind.WORD_MASK_ANY, E_TestCheckKind.WORD_MASK_NONE:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeDint THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                END_IF;
                            E_TestCheckKind.REAL_IN_RANGE:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeReal THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                END_IF;
                        END_CASE;
                    END_IF;
                END_IF;
            END_FOR;
        END_IF;
    END_FOR;
    
    // Si erreur de config, on bloque le démarrage
    IF ConfigError THEN
        RETURN;
    END_IF;
END_IF;

// 2. Abort (Niveau, priorité absolue)
IF Abort THEN
    IF Busy THEN
        Report.InProgress := FALSE;
        Report.Aborted := TRUE;
        Report.AnyFailed := TRUE;
        
        // Enregistrement de l'échec de l'étape courante
        IF CurrentStepId >= 1 AND CurrentStepId <= GVL_PLC_Tests_Const.MaxSteps THEN
            Report.Steps[CurrentStepId].Executed := TRUE;
            Report.Steps[CurrentStepId].Passed := FALSE;
            Report.Steps[CurrentStepId].FailReason := E_TestFailReason.FAIL_ABORTED;
            Report.Steps[CurrentStepId].Duration := StepElapsed;
        END_IF;
        
        // Échec du cas de test en cours
        IF CurrentCaseId >= 1 AND CurrentCaseId <= GVL_PLC_Tests_Const.MaxTestCases THEN
            Report.Cases[CurrentCaseId].Ok := FALSE;
            Report.Cases[CurrentCaseId].FailReason := E_TestFailReason.FAIL_ABORTED;
        END_IF;
        
        Busy := FALSE;
        Done := TRUE;
        AnyFailed := TRUE;
    END_IF;
    ActiveStimulusId := 0;
    StepStarted := FALSE;
    RETURN;
END_IF;

// 3. Démarrage de la suite
IF StartTrig.Q AND NOT ConfigError THEN
    Busy := TRUE;
    Done := FALSE;
    AnyFailed := FALSE;
    CurrentStepId := FirstStepId;
    StepStarted := FALSE;
    
    // RAZ Rapport
    Report.InProgress := TRUE;
    Report.AllPassed := FALSE;
    Report.AnyFailed := FALSE;
    Report.Aborted := FALSE;
    Report.FailedTestCase := 0;
    Report.CurrentStepId := FirstStepId;
    IF CurrentStepId >= 1 AND CurrentStepId <= GVL_PLC_Tests_Const.MaxSteps THEN
        Report.CurrentCaseId := StepTable[CurrentStepId].CaseId;
    ELSE
        Report.CurrentCaseId := 0;
    END_IF;
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
        Report.Cases[Idx].Executed := FALSE;
        Report.Cases[Idx].Ok := FALSE;
        Report.Cases[Idx].FailedStepId := 0;
        Report.Cases[Idx].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Cases[Idx].Duration := T#0s;
    END_FOR;
    
    // RAZ Invariants
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxInvariants DO
        InvArmed[Idx] := FALSE;
    END_FOR;
END_IF;

// 4. Moteur d'exécution principal
IF Busy THEN
    // Incrément de la durée globale du run
    Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
    
    // Vérification des bornes de l'étape courante (0 est valide et désigne la fin)
    IF CurrentStepId <> 0 AND (CurrentStepId < 1 OR CurrentStepId > GVL_PLC_Tests_Const.MaxSteps) THEN
        Busy := FALSE;
        Done := TRUE;
        ActiveStimulusId := 0;
        Report.InProgress := FALSE;
        RETURN;
    END_IF;
    
    IF CurrentStepId > 0 THEN
    CurrentCaseId := StepTable[CurrentStepId].CaseId;
    ActiveStimulusId := StepTable[CurrentStepId].StimulusId;
    Report.CurrentStepId := CurrentStepId;
    Report.CurrentCaseId := CurrentCaseId;
    
    IF NOT StepStarted THEN
        StepStarted := TRUE;
        StepElapsed := T#0s;
        DwellTimer(IN := FALSE);
        StepTimer(IN := FALSE);
        
        // Gestion de l'armement/désarmement des invariants
        FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxInvariants DO
            IF InvariantTable[Idx].ArmAtStepId = CurrentStepId THEN
                InvArmed[Idx] := TRUE;
            END_IF;
            IF InvariantTable[Idx].DisarmAtStepId = CurrentStepId THEN
                InvArmed[Idx] := FALSE;
            END_IF;
        END_FOR;
    END_IF;
    
    // Incrément de la durée de l'étape courante
    StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
    
    // 4.1 Évaluation des invariants actifs
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxInvariants DO
        IF InvArmed[Idx] THEN
            InvChecks[Idx](Config := InvariantTable[Idx].Check, Evaluate := TRUE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
            IF InvChecks[Idx].Failed THEN
                // Violation d'invariant -> Transition en échec immédiat
                Report.Steps[CurrentStepId].Executed := TRUE;
                Report.Steps[CurrentStepId].Passed := FALSE;
                Report.Steps[CurrentStepId].FailReason := E_TestFailReason.FAIL_INVARIANT;
                Report.Steps[CurrentStepId].FailedInvariantId := Idx;
                Report.Steps[CurrentStepId].Duration := StepElapsed;
                Report.Steps[CurrentStepId].ObservedBool := InvChecks[Idx].ObservedBool;
                Report.Steps[CurrentStepId].ObservedDint := InvChecks[Idx].ObservedDint;
                Report.Steps[CurrentStepId].ObservedReal := InvChecks[Idx].ObservedReal;
                
                // Désactivation de l'évaluation
                InvChecks[Idx](Config := InvariantTable[Idx].Check, Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
                
                // Transition
                IF StepTable[CurrentStepId].FailAction = E_TestFailAction.FAIL_ABORT_SUITE THEN
                    Busy := FALSE;
                    Done := TRUE;
                    AnyFailed := TRUE;
                    ActiveStimulusId := 0;
                ELSE
                    CurrentStepId := StepTable[CurrentStepId].NextOnFail;
                    StepStarted := FALSE;
                END_IF;
                RETURN;
            END_IF;
        END_IF;
    END_FOR;
    
    // 4.2 Gestion de la temporisation de Dwell
    DwellTimer(IN := TRUE, PT := StepTable[CurrentStepId].DwellPT);
    IF NOT DwellTimer.Q THEN
        // En attente du Dwell, pas d'évaluation des checks d'étape
        FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
            Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
        END_FOR;
        RETURN;
    END_IF;
    
    // 4.3 Évaluation des checks d'étape
    AllChecksPassed     := TRUE;
    AnyCheckFailed      := FALSE;
    FailedCheckIdxLocal := 0;
    FailReasonLocal     := E_TestFailReason.FAIL_NONE;
    ObsBoolLocal        := FALSE;
    ObsDintLocal        := 0;
    ObsRealLocal        := 0.0;

    FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
        Kdx := StepTable[CurrentStepId].CheckIdx[Jdx];
        IF Kdx > 0 THEN
            Checks[Jdx](Config := CheckTable[Kdx], Evaluate := TRUE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
            
            IF Checks[Jdx].Failed THEN
                AnyCheckFailed := TRUE;
                FailedCheckIdxLocal := Kdx;
                FailReasonLocal := Checks[Jdx].FailReason;
                ObsBoolLocal := Checks[Jdx].ObservedBool;
                ObsDintLocal := Checks[Jdx].ObservedDint;
                ObsRealLocal := Checks[Jdx].ObservedReal;
            ELSIF Checks[Jdx].Pending THEN
                AllChecksPassed := FALSE;
            END_IF;
        END_IF;
    END_FOR;
    
    // 4.4 Prise de verdict
    IF AnyCheckFailed THEN
        // Échec sur un check d'étape
        Report.Steps[CurrentStepId].Executed := TRUE;
        Report.Steps[CurrentStepId].Passed := FALSE;
        Report.Steps[CurrentStepId].FailReason := FailReasonLocal;
        Report.Steps[CurrentStepId].FailedCheckIdx := FailedCheckIdxLocal;
        Report.Steps[CurrentStepId].Duration := StepElapsed;
        Report.Steps[CurrentStepId].ObservedBool := ObsBoolLocal;
        Report.Steps[CurrentStepId].ObservedDint := ObsDintLocal;
        Report.Steps[CurrentStepId].ObservedReal := ObsRealLocal;
        
        // Reset checks
        FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
            Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
        END_FOR;
        
        IF StepTable[CurrentStepId].FailAction = E_TestFailAction.FAIL_ABORT_SUITE THEN
            Busy := FALSE;
            Done := TRUE;
            AnyFailed := TRUE;
            ActiveStimulusId := 0;
        ELSE
            CurrentStepId := StepTable[CurrentStepId].NextOnFail;
            StepStarted := FALSE;
        END_IF;
        RETURN;
    END_IF;
    
    StepTimer(IN := TRUE, PT := StepTable[CurrentStepId].TimeoutPT);
    
    IF AllChecksPassed THEN
        // Succès précoce (vérification MinPT)
        IF StepElapsed < StepTable[CurrentStepId].MinPT THEN
            // Réaction trop rapide = Échec
            Report.Steps[CurrentStepId].Executed := TRUE;
            Report.Steps[CurrentStepId].Passed := FALSE;
            Report.Steps[CurrentStepId].FailReason := E_TestFailReason.FAIL_WINDOW_EARLY;
            Report.Steps[CurrentStepId].Duration := StepElapsed;
            
            // Reset checks
            FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
                Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
            END_FOR;
            
            IF StepTable[CurrentStepId].FailAction = E_TestFailAction.FAIL_ABORT_SUITE THEN
                Busy := FALSE;
                Done := TRUE;
                AnyFailed := TRUE;
                ActiveStimulusId := 0;
            ELSE
                CurrentStepId := StepTable[CurrentStepId].NextOnFail;
                StepStarted := FALSE;
            END_IF;
        ELSE
            // Validation étape OK
            Report.Steps[CurrentStepId].Executed := TRUE;
            Report.Steps[CurrentStepId].Passed := TRUE;
            Report.Steps[CurrentStepId].Duration := StepElapsed;
            
            // Prendre snapshot du premier check s'il existe
            IF StepTable[CurrentStepId].CheckIdx[1] > 0 THEN
                Report.Steps[CurrentStepId].ObservedBool := Checks[1].ObservedBool;
                Report.Steps[CurrentStepId].ObservedDint := Checks[1].ObservedDint;
                Report.Steps[CurrentStepId].ObservedReal := Checks[1].ObservedReal;
            END_IF;
            
            // Reset checks
            FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
                Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
            END_FOR;
            
            CurrentStepId := StepTable[CurrentStepId].NextOnPass;
            StepStarted := FALSE;
        END_IF;
        RETURN;
    END_IF;
    
    // Gestion du timeout d'étape
    IF StepTimer.Q THEN
        // Si timeout expiré, vérifions si des checks NEVER_DURING sont en attente
        NeverDuringPassed := TRUE;
        FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
            Kdx := StepTable[CurrentStepId].CheckIdx[Jdx];
            IF Kdx > 0 THEN
                IF CheckTable[Kdx].Mode = E_TestCheckMode.CHECK_NEVER_DURING THEN
                    // Jamais violé pendant toute la fenêtre
                    Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
                ELSE
                    // Les autres modes auraient dû passer avant le timeout
                    NeverDuringPassed := FALSE;
                END_IF;
            END_IF;
        END_FOR;
        
        IF NeverDuringPassed THEN
            // Succès par non-violation
            Report.Steps[CurrentStepId].Executed := TRUE;
            Report.Steps[CurrentStepId].Passed := TRUE;
            Report.Steps[CurrentStepId].Duration := StepElapsed;
            
            CurrentStepId := StepTable[CurrentStepId].NextOnPass;
            StepStarted := FALSE;
        ELSE
            // Timeout classique de l'étape
            Report.Steps[CurrentStepId].Executed := TRUE;
            Report.Steps[CurrentStepId].Passed := FALSE;
            Report.Steps[CurrentStepId].FailReason := E_TestFailReason.FAIL_TIMEOUT;
            Report.Steps[CurrentStepId].Duration := StepElapsed;
            
            IF StepTable[CurrentStepId].FailAction = E_TestFailAction.FAIL_ABORT_SUITE THEN
                Busy := FALSE;
                Done := TRUE;
                AnyFailed := TRUE;
                ActiveStimulusId := 0;
            ELSE
                CurrentStepId := StepTable[CurrentStepId].NextOnFail;
                StepStarted := FALSE;
            END_IF;
        END_IF;
        
        // Reset checks
        FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
            Checks[Jdx](Evaluate := FALSE, ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal);
        END_FOR;
    END_IF;
    END_IF;
END_IF;

// 5. Agrégation des résultats en fin de suite (CurrentStepId = 0)
IF Busy AND CurrentStepId = 0 THEN
    Busy := FALSE;
    Done := TRUE;
    ActiveStimulusId := 0;
    Report.InProgress := FALSE;
    
    // Agrégation des cas de test
    SuiteAllPassed  := TRUE;
    FirstFailedCase := 0;

    FOR CaseIdx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        CaseStartStep := CaseTable[CaseIdx].FirstStep;
        IF CaseStartStep > 0 THEN
            CaseOk := TRUE;
            CaseExecuted := FALSE;
            CaseFailedStep := 0;
            CaseDuration := T#0s;
            CaseFailReason := E_TestFailReason.FAIL_NONE;
            
            // Parcourir la chaîne d'étapes à partir de FirstStep
            CaseStep := CaseStartStep;
            WHILE CaseStep > 0 AND StepTable[CaseStep].CaseId = CaseIdx DO
                IF Report.Steps[CaseStep].Executed THEN
                    CaseExecuted := TRUE;
                    CaseDuration := CaseDuration + Report.Steps[CaseStep].Duration;
                    IF NOT Report.Steps[CaseStep].Passed THEN
                        CaseOk := FALSE;
                        CaseFailedStep := CaseStep;
                        CaseFailReason := Report.Steps[CaseStep].FailReason;
                    END_IF;
                END_IF;
                
                // Suivre NextOnPass ou NextOnFail selon l'exécution réelle
                IF Report.Steps[CaseStep].Executed AND NOT Report.Steps[CaseStep].Passed THEN
                    CaseStep := StepTable[CaseStep].NextOnFail;
                ELSE
                    CaseStep := StepTable[CaseStep].NextOnPass;
                END_IF;
            END_WHILE;
            
            Report.Cases[CaseIdx].Name := CaseTable[CaseIdx].Name; // 🏷️ Lisible directement en Watch, sans chercher l'index
            Report.Cases[CaseIdx].Executed := CaseExecuted;
            Report.Cases[CaseIdx].Ok := CaseExecuted AND CaseOk;
            Report.Cases[CaseIdx].FailedStepId := CaseFailedStep;
            Report.Cases[CaseIdx].FailReason := CaseFailReason;
            Report.Cases[CaseIdx].Duration := CaseDuration;
            
            IF CaseExecuted AND NOT CaseOk THEN
                SuiteAllPassed := FALSE;
                IF FirstFailedCase = 0 THEN
                    FirstFailedCase := CaseIdx;
                END_IF;
            END_IF;
        END_IF;
    END_FOR;
    
    Report.AllPassed := SuiteAllPassed;
    Report.AnyFailed := NOT SuiteAllPassed;
    Report.FailedTestCase := FirstFailedCase;
    AnyFailed := NOT SuiteAllPassed;

    // 🏷️ Résumé texte de TOUS les cas en échec (pas juste le premier) — évite de
    // parcourir Cases[] un par un en Watch (demande utilisateur 2026-07-16)
    Report.FailureSummary := '';
    FOR CaseIdx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF Report.Cases[CaseIdx].Executed AND NOT Report.Cases[CaseIdx].Ok THEN
            CASE Report.Cases[CaseIdx].FailReason OF
                E_TestFailReason.FAIL_TIMEOUT:      ReasonText := 'FAIL_TIMEOUT';
                E_TestFailReason.FAIL_CHECK:        ReasonText := 'FAIL_CHECK';
                E_TestFailReason.FAIL_INVARIANT:    ReasonText := 'FAIL_INVARIANT';
                E_TestFailReason.FAIL_WINDOW_EARLY: ReasonText := 'FAIL_WINDOW_EARLY';
                E_TestFailReason.FAIL_ABORTED:      ReasonText := 'FAIL_ABORTED';
            ELSE
                ReasonText := 'FAIL_NONE';
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
    END_FOR;
END_IF;
