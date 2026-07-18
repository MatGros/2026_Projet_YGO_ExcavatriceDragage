(* ============================================================================
   🧪 FB_ModesValidation — Suite PLC Modes / Homme-mort (post-suppression IHM_MANU)
   ============================================================================
   🎯 Rôle : valide que le pilotage manuel passe désormais EXCLUSIVEMENT par
      MAINT_N1/MAINT_N2 + joystick homme-mort (plus de bypass IHM_MANU), et que
      les sécurités/l'autorisation de mode restent actives dans tous les cas.
   📄 Couvre (mission suppression IHM_MANU, 2026-07-19) :
      TC-M1 : MAINT_N1 + homme-mort → mouvement M1 autorisé
      TC-M2 : MAINT_N2 + homme-mort → mouvement M1 autorisé
              (+ relâchement=arrêt, + reprise sur nouvelle sollicitation valide,
              testés dans TC-M1/TC-M2 eux-mêmes, pas des cas séparés)
      TC-M3 : SEMI_AUTO atteignable sans dépendance IHM_MANU
      TC-M4 : Simulation fonctionnelle sans dépendance IHM_MANU
      TC-M5 : Sécurité active + aucun mouvement sans autorisation de mode
              (perte EmergencyStopOk → Mode=DISABLE + FB_Winch neutralisé,
              quel que soit le mode précédent)
      TC-M6 : Séquenceur (FB_Cycle) ne bloque jamais — une tentative réelle de
              démarrage (`GVL_IHM.Cycle.CmdStart`) hors SEMI_AUTO reste sans effet
              (Busy reste FALSE) au lieu d'attendre indéfiniment
      🔎 Homing nominal sans IHM_MANU : déjà couvert par SUITE_ENCODER (TC-E1/E2).
   🧩 Même moteur allégé (CASE direct) que FB_EncoderValidation — pas le cadre
      StepTable/CheckTable déclaratif (inutile ici, peu d'étapes par cas).
   ============================================================================ *)

FUNCTION_BLOCK PUBLIC FB_ModesValidation
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
    Step            : INT;
    CaseId          : INT;
    StepStarted     : BOOL;
    StepTimer       : TON;
    StepLimit       : TIME;
    StepFailed      : BOOL;
    StepPassed      : BOOL;
    Index           : INT;
    NeutralHoldTimer : TON; // Tient le neutre >1s avant un nouvel appui (reprise), voir FB_Joystick §NeutralHoldTime
END_VAR

// Gate simulation : nécessite le joystick simulé (override programmatique) et M1 simulé.
SimGateOk := GVL_Simulation.SimulationModeActive
          AND NOT GVL_Simulation.JoystickSignal_IsReal
          AND NOT GVL_Simulation.EncoderM1_IsReal
          AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal;

ActiveStimulusId := 0;

IF Abort THEN
    GVL_PLC_Tests.OverrideJoystickActive := FALSE;
    GVL_PLC_Tests.OverrideContactorFalse := FALSE;
    GVL_IHM.Modes.FaultMachineReset := FALSE;
    GVL_IHM.Cycle.CmdStart := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.Aborted := TRUE;
    Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState;
    Report.FailureSummary := 'Modes/Homme-mort : ABORTED';
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
    Step := FirstStepId;
    IF (Step <> 10) AND (Step <> 20) AND (Step <> 30) AND (Step <> 40) AND (Step <> 50) AND (Step <> 60) THEN
        Step := 10;
    END_IF;
    Report.Name := 'Modes / Homme-mort Validation';
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
    GVL_PLC_Tests.OverrideJoystickActive := TRUE;
    GVL_PLC_Tests.OverrideJoystickRawX := 5000;
    GVL_PLC_Tests.OverrideJoystickRawY := 5000;
    GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
ELSIF NOT Start THEN
    StartPrev := FALSE;
END_IF;

IF NOT Busy THEN
    RETURN;
END_IF;

StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.CurrentStepId := Step;
CaseId := (Step / 10);
Report.CurrentCaseId := CaseId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    CASE Step OF
        10, 20: StepLimit := T#3s;   // Mode appliqué + neutre initial
        11, 21: StepLimit := T#5s;   // Armement + départ mouvement
        12: StepLimit := T#5s;       // TC-M1 uniquement : relâchement → arrêt
        13: StepLimit := T#3s;       // TC-M1 uniquement : neutre tenu >1s (NeutralHoldTime)
        14: StepLimit := T#5s;       // TC-M1 uniquement : reprise → mouvement repart
        30: StepLimit := T#5s;       // SEMI_AUTO atteint
        40: StepLimit := T#3s;       // Simulation OK sans IHM_MANU
        50: StepLimit := T#3s;       // Perte EmergencyStopOk → Mode DISABLE
        51: StepLimit := T#3s;       // FB_Winch neutralisé (State DISABLED)
        52: StepLimit := T#5s;       // Récupération après restauration EmergencyStopOk
        60: StepLimit := T#3s;       // Tentative réelle de démarrage hors SEMI_AUTO (pas de blocage)
    ELSE
        ConfigError := TRUE;
        ConfigErrorStepId := Step;
        ErrorCode := 4001;
        ErrorMessage := 'Modes/Homme-mort étape inconnue';
        StepLimit := T#0s;
    END_CASE;
END_IF;

StepTimer(IN := TRUE, PT := StepLimit);
NeutralHoldTimer(IN := (Step = 13) AND (ABS(GVL_PLC_Tests.OverrideJoystickRawY - 5000) < 500), PT := T#1200MS);

CASE Step OF
    // ─────────── TC-M1 : MAINT_N1 + homme-mort (+ arrêt + reprise) ───────────
    10:
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
        GVL_PLC_Tests.OverrideJoystickRawY := 5000; // neutre
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        IF SimGateOk AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N1) THEN
            StepPassed := TRUE;
            Step := 11;
            StepStarted := FALSE;
        END_IF;

    11:
        // Armement (bouton pressé AU NEUTRE) puis débattement Fwd — homme-mort réel de FB_Joystick.
        GVL_PLC_Tests.OverrideJoystickRawButton := TRUE;
        GVL_PLC_Tests.OverrideJoystickRawY := 10000; // plein débattement montée
        IF PRG_06_WinchControl.instWinchM1.RelayFwd THEN
            StepPassed := TRUE;
            Step := 12;
            StepStarted := FALSE;
        END_IF;

    12:
        // Relâchement du bouton homme-mort → le mouvement doit s'arrêter (item "relâchement=arrêt").
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        IF NOT PRG_06_WinchControl.instWinchM1.RelayFwd THEN
            StepPassed := TRUE;
            Step := 13;
            StepStarted := FALSE;
        END_IF;

    13:
        // Retour + maintien au neutre >NeutralHoldTime (1s en simulation) pour un réarmement propre.
        GVL_PLC_Tests.OverrideJoystickRawY := 5000;
        IF NeutralHoldTimer.Q THEN
            StepPassed := TRUE;
            Step := 14;
            StepStarted := FALSE;
        END_IF;

    14:
        // Reprise : nouvel appui AU NEUTRE puis débattement → mouvement doit repartir.
        GVL_PLC_Tests.OverrideJoystickRawButton := TRUE;
        GVL_PLC_Tests.OverrideJoystickRawY := 10000;
        IF PRG_06_WinchControl.instWinchM1.RelayFwd THEN
            StepPassed := TRUE;
            Step := 20; // Enchaîne directement sur TC-M2 (teardown commun ci-dessous)
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M2 : MAINT_N2 + homme-mort ───────────
    20:
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        GVL_PLC_Tests.OverrideJoystickRawY := 5000;
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N2;
        IF SimGateOk AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2) THEN
            StepPassed := TRUE;
            Step := 21;
            StepStarted := FALSE;
        END_IF;

    21:
        GVL_PLC_Tests.OverrideJoystickRawButton := TRUE;
        GVL_PLC_Tests.OverrideJoystickRawY := 10000;
        IF PRG_06_WinchControl.instWinchM1.RelayFwd THEN
            StepPassed := TRUE;
            Step := 30;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M3 : SEMI_AUTO atteignable sans IHM_MANU ───────────
    30:
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        GVL_PLC_Tests.OverrideJoystickRawY := 5000;
        GVL_IHM.Modes.ModeRequest := E_Mode.SEMI_AUTO;
        IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
            StepPassed := TRUE;
            Step := 40;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M4 : Simulation fonctionnelle sans IHM_MANU ───────────
    40:
        IF GVL_Simulation.SimulationModeActive AND SimGateOk THEN
            StepPassed := TRUE;
            Step := 50;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M5 : Sécurité active + aucun mouvement sans autorisation de mode ───────────
    50:
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
        GVL_PLC_Tests.OverrideContactorFalse := TRUE; // Force EmergencyStopOk := FALSE (voir PRG_00_Inputs)
        IF PRG_04_Modes.instModes.Mode = E_Mode.DISABLE THEN
            StepPassed := TRUE;
            Step := 51;
            StepStarted := FALSE;
        END_IF;

    51:
        IF PRG_06_WinchControl.instWinchM1.State = E_State.DISABLED
           AND NOT PRG_06_WinchControl.instWinchM1.Ready THEN
            StepPassed := TRUE;
            Step := 52;
            StepStarted := FALSE;
        END_IF;

    52:
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        GVL_IHM.Modes.FaultMachineReset := TRUE;
        IF PRG_04_Modes.instModes.Mode <> E_Mode.DISABLE THEN
            GVL_IHM.Modes.FaultMachineReset := FALSE;
            StepPassed := TRUE;
            Step := 60;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M6 : Séquenceur (FB_Cycle) ne bloque jamais ───────────
    60:
        // 🔧 REX 2026-07-19 (revue mission IHM_MANU, finding B) : tentative RÉELLE de
        // démarrage (GVL_IHM.Cycle.CmdStart, ré-assertée chaque scan pour couvrir l'ordre
        // des tâches) pendant >200 ms hors SEMI_AUTO — instCycle.Enable=FALSE doit la rendre
        // sans effet (Busy reste FALSE), pas un simple instantané qui ne prouverait rien.
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
        GVL_IHM.Cycle.CmdStart := TRUE;
        IF (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N1) AND (StepElapsed >= T#200MS) THEN
            GVL_IHM.Cycle.CmdStart := FALSE;
            IF NOT PRG_05_Cycle.instCycle.Busy THEN
                StepPassed := TRUE;
            ELSE
                StepFailed := TRUE;
            END_IF;
            Step := 0;
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
        Step := 0; // Échec ou timeout = fin immédiate, pas d'attente supplémentaire.
    END_IF;
    StepPassed := FALSE;
    StepFailed := FALSE;
    StepTimer(IN := FALSE, PT := StepLimit);
    StepElapsed := T#0s;
    IF Step = 0 THEN
        GVL_PLC_Tests.OverrideJoystickActive := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        Busy := FALSE;
        Done := TRUE;
        Report.InProgress := FALSE;
        Report.AnyFailed := AnyFailed;
        Report.AllPassed := NOT AnyFailed;
        Report.TerminalState := SEL(AnyFailed, E_TestTerminalState.TEST_TERMINAL_DONE, E_TestTerminalState.TEST_TERMINAL_FAILED);
        TerminalState := Report.TerminalState;
        Report.Cases[1].Name := 'TC-M1..M6 Modes+HommeMort'; // ✂️ Tronqué pour tenir dans STRING(32)
        Report.Cases[1].Executed := TRUE;
        Report.Cases[1].Ok := NOT AnyFailed;
        Report.Cases[1].FailedStepId := 0;
        Report.Cases[1].FailReason := E_TestFailReason.FAIL_NONE;
        IF AnyFailed THEN
            Report.Cases[1].FailedStepId := Report.CurrentStepId;
            Report.Cases[1].FailReason := E_TestFailReason.FAIL_CHECK;
            Report.FailureSummary := CONCAT('Modes/Homme-mort : échec étape ', INT_TO_STRING(Report.CurrentStepId));
        END_IF;
        Report.Cases[1].Duration := Report.Duration;
    ELSE
        StepStarted := FALSE;
    END_IF;
END_IF;

// Limite globale de sécurité de la suite : 60 s maximum.
IF Report.Duration >= T#60s AND Busy THEN
    GVL_PLC_Tests.OverrideJoystickActive := FALSE;
    GVL_PLC_Tests.OverrideContactorFalse := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_WATCHDOG_TIMEOUT;
    Report.InProgress := FALSE;
    Report.AnyFailed := TRUE;
    Report.AllPassed := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 4002;
    Report.ErrorMessage := 'Watchdog Modes/Homme-mort expire';
    Report.FailureSummary := Report.ErrorMessage;
END_IF;
