// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationStepExecutor — Exécution étape/check Translation M3
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : faire progresser UNE suite de tests
//    Translation, étape par étape (Dwell → Checks → Timeout/MinPT →
//    verdict → étape suivante), en respectant le cantonnement à un
//    seul cas (CaseId 1..6) ou à l'enchaînement complet (CaseId=0).
//    N'écrit AUCUNE variable GVL, ne construit AUCUNE table (voir
//    FB_TranslationTestPlan) et n'assemble AUCUN rapport (voir
//    FB_TranslationReportFinalizer, qui consomme StepVerdict/Verdict*).
// 🆕 Tranche verticale NEUVE Translation (2026-07-22) — n'instancie NI
//    FB_TestSequencer NI FB_TestCheck/FB_Timeout (anciennes BRICKS) :
//    logique de check réécrite ici, restreinte aux 3 Kind / 2 Mode
//    réellement utilisés par les 6 TC Translation (voir FB_TranslationTestPlan).
// 🔒 Cantonnement de cas (remplace le FirstStepId manipulé par le
//    manager, audit v1.0 C2) : CaseId est résolu en 1er step via
//    CaseTable UNIQUEMENT ici (jamais exposé par FB_TranslationValidation).
//    Toute étape suivante qui change de CaseId alors qu'un cas est
//    ciblé (CaseId<>0) termine proprement le run (NextStepId:=0).
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationStepExecutor
VAR_INPUT
    Start   : BOOL; // Front : résout CaseId -> 1er step (CaseTable) et démarre
    Abort   : BOOL; // Niveau : arrêt immédiat propre
    CaseId  : INT;  // 0 = toutes les cases (1..6) ; 1..6 = case ciblée uniquement
END_VAR
VAR_IN_OUT
    StepTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
    ProbeBool  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool]  OF BOOL;
    ProbeDint  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint]  OF DINT;
    ProbeReal  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal]  OF REAL;
END_VAR
VAR_OUTPUT
    Busy                : BOOL;
    RunDone              : BOOL;  // Fin de run (niveau, tenu jusqu'au prochain Start)
    AnyFailed            : BOOL;
    ConfigError          : BOOL;  // 🛡️ Garde-fou runtime (Plan valide déjà statiquement)
    ConfigErrorStepId    : INT;
    CurrentStepId        : INT;
    CurrentCaseId        : INT;
    ActiveStimulusId     : INT;   // 0 GARANTI sur tout chemin terminal (Done/Abort/ConfigError)
    StepElapsed          : TIME;
    TerminalState        : E_TestTerminalState;
    // 🧾 Verdict d'étape — pulse 1 scan, consommé par FB_TranslationReportFinalizer
    StepVerdict          : BOOL;
    VerdictStepId        : INT;
    VerdictCaseId        : INT;
    VerdictPassed         : BOOL;
    VerdictFailReason     : E_TestFailReason;
    VerdictFailedCheckIdx : INT;
    VerdictDuration       : TIME;
    VerdictObservedBool   : BOOL;
    VerdictObservedDint   : DINT;
    VerdictObservedReal   : REAL;
END_VAR
VAR
    StartTrig       : R_TRIG;
    StepStarted     : BOOL;
    DwellTimer      : TON;
    StepTimer       : TON;
    StableTimers    : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF TON;
    CheckPassed     : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF BOOL;
    CheckFailed     : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF BOOL;
    InstantEvaluated: ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF BOOL;
    ObsBoolArr      : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF BOOL;
    ObsDintArr      : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF DINT;
    ObsRealArr      : ARRAY[1..GVL_PLC_Tests_Const.MaxChecksPerStep] OF REAL;

    Jdx, Kdx        : INT;
    ProbeIdx        : INT;
    Cond            : BOOL;
    AllChecksLatched: BOOL;
    AnyCheckFailedLocal : BOOL;
    FailedCheckIdxLocal : INT;
    FailedCheckSlotLocal : INT; // Slot RÉEL (Jdx, 1..MaxChecksPerStep) du check fautif

    // Verdict de l'étape (émis au plus une fois par scan)
    VerdictReached      : BOOL;
    VerdictPassedLocal   : BOOL;
    VerdictReasonLocal   : E_TestFailReason;
    VerdictCheckIdxLocal : INT;
    VerdictObsBoolLocal  : BOOL;
    VerdictObsDintLocal  : DINT;
    VerdictObsRealLocal  : REAL;

    NextCandidate    : INT;
    TransitionCount  : INT; // Garde anti-cycle runtime, bornée par MaxSteps
END_VAR
// === IMPLEMENTATION ===
StartTrig(CLK := Start);
StepVerdict := FALSE;

// 1. 🛑 Abort — niveau, priorité absolue
IF Abort THEN
    IF Busy THEN
        StepVerdict := TRUE;
        VerdictStepId := CurrentStepId;
        VerdictCaseId := CurrentCaseId;
        VerdictPassed := FALSE;
        VerdictFailReason := E_TestFailReason.FAIL_ABORTED;
        VerdictFailedCheckIdx := 0;
        VerdictDuration := StepElapsed;
        VerdictObservedBool := FALSE;
        VerdictObservedDint := 0;
        VerdictObservedReal := 0.0;
        AnyFailed := TRUE;
        TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    END_IF;
    Busy := FALSE;
    RunDone := TRUE;
    ActiveStimulusId := 0;
    CurrentStepId := 0;
    StepStarted := FALSE;
    RETURN;
END_IF;

// 2. 🟢 Démarrage — résolution CaseId -> 1er step, JAMAIS de FirstStepId externe
IF StartTrig.Q THEN
    ConfigError := FALSE;
    ConfigErrorStepId := 0;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;

    IF CaseId < 0 OR CaseId > 6 THEN
        ConfigError := TRUE;
        ConfigErrorStepId := CaseId;
        Busy := FALSE;
        RunDone := TRUE;
        AnyFailed := TRUE;
        ActiveStimulusId := 0;
        CurrentStepId := 0;
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        RETURN;
    END_IF;

    IF CaseId = 0 THEN
        CurrentStepId := CaseTable[1].FirstStep;
    ELSE
        CurrentStepId := CaseTable[CaseId].FirstStep;
    END_IF;

    IF CurrentStepId < 1 OR CurrentStepId > GVL_PLC_Tests_Const.MaxSteps THEN
        ConfigError := TRUE;
        ConfigErrorStepId := CurrentStepId;
        Busy := FALSE;
        RunDone := TRUE;
        AnyFailed := TRUE;
        ActiveStimulusId := 0;
        CurrentStepId := 0;
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        RETURN;
    END_IF;

    Busy := TRUE;
    RunDone := FALSE;
    AnyFailed := FALSE;
    StepStarted := FALSE;
    TransitionCount := 0;
END_IF;

IF NOT Busy THEN
    RETURN;
END_IF;

// 3. 🛡️ Garde-fou runtime (défense en profondeur — Plan valide déjà statiquement)
IF CurrentStepId < 1 OR CurrentStepId > GVL_PLC_Tests_Const.MaxSteps THEN
    Busy := FALSE;
    RunDone := TRUE;
    AnyFailed := TRUE;
    ActiveStimulusId := 0;
    ConfigError := TRUE;
    ConfigErrorStepId := CurrentStepId;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
    RETURN;
END_IF;

CurrentCaseId := StepTable[CurrentStepId].CaseId;
ActiveStimulusId := StepTable[CurrentStepId].StimulusId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    DwellTimer(IN := FALSE);
    StepTimer(IN := FALSE);
    FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
        CheckPassed[Jdx] := FALSE;
        CheckFailed[Jdx] := FALSE;
        InstantEvaluated[Jdx] := FALSE;
        StableTimers[Jdx](IN := FALSE);
    END_FOR;
END_IF;

StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));

// 4. 🕐 Dwell (tempo fixe avant évaluation — T#0s = aucune, cas actuel Translation)
DwellTimer(IN := TRUE, PT := StepTable[CurrentStepId].DwellPT);
IF NOT DwellTimer.Q THEN
    RETURN;
END_IF;

// 5. ✅ Évaluation des checks — verrouillage "latch and hold" par check
//    (un check WAIT_UNTIL passé le reste jusqu'à la fin de l'étape, même si
//    la sonde redevient momentanément fausse — sémantique identique à
//    l'ancien FB_TestCheck, réécrite ici sans l'instancier)
FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
    Kdx := StepTable[CurrentStepId].CheckIdx[Jdx];
    // 🔒 CODESYS n'assure pas le court-circuit : valider AVANT tout accès.
    IF Kdx < 0 OR Kdx > GVL_PLC_Tests_Const.MaxChecks THEN
        Busy := FALSE;
        RunDone := TRUE;
        AnyFailed := TRUE;
        ActiveStimulusId := 0;
        ConfigError := TRUE;
        ConfigErrorStepId := CurrentStepId;
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        RETURN;
    END_IF;
    IF Kdx > 0 THEN
        Cond := FALSE;
        ProbeIdx := CheckTable[Kdx].ProbeIdx;
        CASE CheckTable[Kdx].Kind OF
            E_TestCheckKind.BOOL_EQUAL:
                IF ProbeIdx >= 1 THEN
                    IF ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeBool THEN
                        ObsBoolArr[Jdx] := ProbeBool[ProbeIdx];
                        Cond := (ObsBoolArr[Jdx] = CheckTable[Kdx].ExpectedBool);
                    END_IF;
                END_IF;
            E_TestCheckKind.WORD_MASK_NONE:
                IF ProbeIdx >= 1 THEN
                    IF ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeDint THEN
                        ObsDintArr[Jdx] := ProbeDint[ProbeIdx];
                        Cond := ((DINT_TO_WORD(ObsDintArr[Jdx]) AND CheckTable[Kdx].Mask) = 0);
                    END_IF;
                END_IF;
            E_TestCheckKind.REAL_IN_RANGE:
                IF ProbeIdx >= 1 THEN
                    IF ProbeIdx <= GVL_PLC_Tests_Const.MaxProbeReal THEN
                        ObsRealArr[Jdx] := ProbeReal[ProbeIdx];
                        Cond := (ObsRealArr[Jdx] >= CheckTable[Kdx].RealMin AND ObsRealArr[Jdx] <= CheckTable[Kdx].RealMax);
                    END_IF;
                END_IF;
            // Kind hors périmètre (voir FB_TranslationTestPlan) -> Cond reste FALSE
        END_CASE;

        IF NOT CheckPassed[Jdx] AND NOT CheckFailed[Jdx] THEN
            CASE CheckTable[Kdx].Mode OF
                E_TestCheckMode.CHECK_INSTANT:
                    IF NOT InstantEvaluated[Jdx] THEN
                        InstantEvaluated[Jdx] := TRUE;
                        IF Cond THEN
                            CheckPassed[Jdx] := TRUE;
                        ELSE
                            CheckFailed[Jdx] := TRUE;
                        END_IF;
                    END_IF;
                E_TestCheckMode.CHECK_WAIT_UNTIL:
                    StableTimers[Jdx](IN := Cond, PT := CheckTable[Kdx].StablePT);
                    IF StableTimers[Jdx].Q THEN
                        CheckPassed[Jdx] := TRUE;
                    END_IF;
            END_CASE;
        END_IF;
    END_IF;
END_FOR;

// 6. 🧾 Agrégat des checks de l'étape
AllChecksLatched := TRUE;
AnyCheckFailedLocal := FALSE;
FailedCheckIdxLocal := 0;
FailedCheckSlotLocal := 0;
FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
    Kdx := StepTable[CurrentStepId].CheckIdx[Jdx];
    IF Kdx > 0 THEN
        IF CheckFailed[Jdx] AND NOT AnyCheckFailedLocal THEN
            AnyCheckFailedLocal := TRUE;
            FailedCheckIdxLocal := Kdx;
            FailedCheckSlotLocal := Jdx; // 🔧 REX : slot RÉEL du check fautif (pas un index figé)
        ELSIF NOT CheckPassed[Jdx] THEN
            AllChecksLatched := FALSE;
        END_IF;
    END_IF;
END_FOR;

// 7. 📸 Verdict
VerdictReached := FALSE;
IF AnyCheckFailedLocal THEN
    VerdictReached := TRUE;
    VerdictPassedLocal := FALSE;
    VerdictReasonLocal := E_TestFailReason.FAIL_CHECK;
    VerdictCheckIdxLocal := FailedCheckIdxLocal;
    // 🔒 Défense en profondeur avant indexation du snapshot fautif.
    IF FailedCheckSlotLocal >= 1 THEN
        IF FailedCheckSlotLocal <= GVL_PLC_Tests_Const.MaxChecksPerStep THEN
            VerdictObsBoolLocal := ObsBoolArr[FailedCheckSlotLocal];
            VerdictObsDintLocal := ObsDintArr[FailedCheckSlotLocal];
            VerdictObsRealLocal := ObsRealArr[FailedCheckSlotLocal];
        ELSE
            VerdictObsBoolLocal := FALSE;
            VerdictObsDintLocal := 0;
            VerdictObsRealLocal := 0.0;
        END_IF;
    ELSE
        VerdictObsBoolLocal := FALSE;
        VerdictObsDintLocal := 0;
        VerdictObsRealLocal := 0.0;
    END_IF;
ELSE
    StepTimer(IN := TRUE, PT := StepTable[CurrentStepId].TimeoutPT);
    IF AllChecksLatched THEN
        VerdictReached := TRUE;
        IF StepElapsed < StepTable[CurrentStepId].MinPT THEN
            VerdictPassedLocal := FALSE;
            VerdictReasonLocal := E_TestFailReason.FAIL_WINDOW_EARLY;
            VerdictCheckIdxLocal := 0;
        ELSE
            VerdictPassedLocal := TRUE;
            VerdictReasonLocal := E_TestFailReason.FAIL_NONE;
            VerdictCheckIdxLocal := 0;
        END_IF;
        VerdictObsBoolLocal := ObsBoolArr[1];
        VerdictObsDintLocal := ObsDintArr[1];
        VerdictObsRealLocal := ObsRealArr[1];
    ELSIF StepTimer.Q THEN
        VerdictReached := TRUE;
        VerdictPassedLocal := FALSE;
        VerdictReasonLocal := E_TestFailReason.FAIL_TIMEOUT;
        VerdictCheckIdxLocal := 0;
        VerdictObsBoolLocal := FALSE;
        VerdictObsDintLocal := 0;
        VerdictObsRealLocal := 0.0;
    END_IF;
END_IF;

IF NOT VerdictReached THEN
    RETURN; // ⏳ Toujours en attente, rien à publier ce scan
END_IF;

// 8. ➡️ Résolution de l'étape suivante — cantonnement de cas ICI (audit v1.0 C2)
IF VerdictPassedLocal THEN
    NextCandidate := StepTable[CurrentStepId].NextOnPass;
ELSIF StepTable[CurrentStepId].FailAction = E_TestFailAction.FAIL_ABORT_SUITE THEN
    NextCandidate := 0;
ELSE
    NextCandidate := StepTable[CurrentStepId].NextOnFail;
END_IF;

// 🔒 Aucun accès StepTable[0] : CODESYS peut évaluer tous les opérandes de AND.
IF NextCandidate <> 0 THEN
    IF NextCandidate < 1 OR NextCandidate > GVL_PLC_Tests_Const.MaxSteps THEN
        Busy := FALSE;
        RunDone := TRUE;
        AnyFailed := TRUE;
        ActiveStimulusId := 0;
        ConfigError := TRUE;
        ConfigErrorStepId := NextCandidate;
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        RETURN;
    END_IF;
    // Un cas ciblé ne déborde jamais sur le cas suivant.
    IF CaseId <> 0 THEN
        IF StepTable[NextCandidate].CaseId <> CaseId THEN
            NextCandidate := 0;
        END_IF;
    END_IF;
END_IF;

// 9. 🧾 Publication du verdict pour FB_TranslationReportFinalizer
StepVerdict := TRUE;
VerdictStepId := CurrentStepId;
VerdictCaseId := CurrentCaseId;
VerdictPassed := VerdictPassedLocal;
VerdictFailReason := VerdictReasonLocal;
VerdictFailedCheckIdx := VerdictCheckIdxLocal;
VerdictDuration := StepElapsed;
VerdictObservedBool := VerdictObsBoolLocal;
VerdictObservedDint := VerdictObsDintLocal;
VerdictObservedReal := VerdictObsRealLocal;

IF NOT VerdictPassedLocal THEN
    AnyFailed := TRUE;
END_IF;

// 10. 🔁 Transition bornée (garde runtime contre tout cycle résiduel)
TransitionCount := TransitionCount + 1;
IF TransitionCount > GVL_PLC_Tests_Const.MaxSteps THEN
    Busy := FALSE;
    RunDone := TRUE;
    AnyFailed := TRUE;
    ActiveStimulusId := 0;
    ConfigError := TRUE;
    ConfigErrorStepId := CurrentStepId;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
    RETURN;
END_IF;
CurrentStepId := NextCandidate;
StepStarted := FALSE;
IF NextCandidate = 0 THEN
    Busy := FALSE;
    RunDone := TRUE;
    ActiveStimulusId := 0; // 🛡️ Garantie structurelle — double garantie avec FB_TranslationTestCleanup
    IF AnyFailed THEN
        TerminalState := E_TestTerminalState.TEST_TERMINAL_FAILED;
    ELSE
        TerminalState := E_TestTerminalState.TEST_TERMINAL_DONE;
    END_IF;
END_IF;
