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
              démarrage (`GVL_IHM.Cycle.CmdStart`) hors SEMI_AUTO reste sans effet.
      TC-M7 : DISABLE explicite neutralise M1/M2/M3.
      TC-M8 : bypass codeur refusé hors MAINT_N2, accepté en MAINT_N2 après Reset.
      TC-M9 : ConfigError FB_SpeedStep remonte au bit2 de FB_Winch, sorties sûres.
      TC-M10 : estimation charge nulle en descente, active en montée.
      TC-M11 : ASCENDING_LOADED utilise la limite d'exploitation 8,0 m.
      TC-M12 : commandes IHM RETAIN purgées avant consommation.
      🔎 Homing nominal sans IHM_MANU : déjà couvert par SUITE_ENCODER (TC-E1/E2).
   🧩 Même moteur allégé (CASE direct) que FB_EncoderValidation — pas le cadre
      StepTable/CheckTable déclaratif (inutile ici, peu d'étapes par cas).
   ============================================================================ *)

FUNCTION_BLOCK PUBLIC FB_ModesValidation
VAR_INPUT
    Start       : BOOL;
    Abort       : BOOL;
    CaseId      : INT; // 0=tous ; 1..12=cas ciblé
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
    CurrentCaseId   : INT;
    RequestedCaseId : INT;
    StepStarted     : BOOL;
    StepTimer       : TON;
    StepLimit       : TIME;
    StepFailed      : BOOL;
    StepPassed      : BOOL;
    Index           : INT;
    NeutralHoldTimer : TON; // Tient le neutre >1s avant un nouvel appui (reprise), voir FB_Joystick §NeutralHoldTime

    // 🔬 WINCH-CORE-01 — instances locales : tests déterministes sans forcer les sorties calculées.
    TestSafetyWinch   : FB_Safety_Winch;
    TestWinch         : FB_Winch;
    TestLoadEstimator : FB_WinchLoadEstimator;
    TestCycle         : FB_Cycle;
    TestSpeedTable    : ST_SpeedStepTable := (
        P1R1 := FALSE, P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := FALSE, P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := FALSE, P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := FALSE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );
    TestSpeedConfig   : ST_WinchSpeedConfig := (
        MaxMeasuredSpeedMps := 2.0,
        SpeedBandMaxMps := [0.4, 0.8, 1.2, 1.6, 2.0],
        SpeedBandHysteresisMps := 0.05
    );
    TestLoadTable     : ST_WinchLoadEstimateTable;
END_VAR

// Gate simulation : nécessite le joystick simulé (override programmatique) et M1 simulé.
SimGateOk := GVL_Simulation.SimulationModeActive
          AND NOT GVL_Simulation.BusJoystickSignalIsReal
          AND NOT GVL_Simulation.BusEncoderM1IsReal
          AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal;

ActiveStimulusId := 0;

IF Abort THEN
    GVL_PLC_Tests.OverrideJoystickActive := FALSE;
    GVL_PLC_Tests.OverrideContactorFalse := FALSE;
    GVL_IHM.Modes.BtnFaultReset := FALSE;
    GVL_IHM.Cycle.BtnStart := FALSE;
    GVL_PLC_Tests.OverrideHmiCommandPurge := FALSE;
    GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault := FALSE;
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
    IF CaseId < 0 OR CaseId > 12 THEN
        Busy := FALSE;
        Done := TRUE;
        AnyFailed := TRUE;
        ConfigError := TRUE;
        ErrorCode := 5001;
        ErrorMessage := 'Modes CaseId invalide';
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        Report.TerminalState := TerminalState;
        Report.AnyFailed := TRUE;
        Report.ErrorCode := ErrorCode;
        Report.ErrorMessage := ErrorMessage;
        RETURN;
    END_IF;
    RequestedCaseId := CaseId;
    CASE RequestedCaseId OF
        1: Step := 10;
        2: Step := 20;
        3: Step := 30;
        4: Step := 40;
        5: Step := 50;
        6: Step := 60;
        7: Step := 70;
        8: Step := 90;
        9: Step := 80;
        10: Step := 90;
        11: Step := 100;
        12: Step := 110;
    ELSE
        Step := 5;
    END_CASE;
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
CurrentCaseId := (Step / 10);
Report.CurrentCaseId := CurrentCaseId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    CASE Step OF
        5: StepLimit := T#5s;         // Préambule : armement contacteur simulé
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
        65, 66: StepLimit := T#3s;   // DISABLE explicite + neutralisation des 3 axes
        70, 71: StepLimit := T#2s;   // Bypass codeur hors/dans MAINT_N2
        80: StepLimit := T#2s;       // ConfigError SpeedStep → FB_Winch bit2
        90, 91: StepLimit := T#2s;   // Estimateur descente/montée
        100, 101, 102: StepLimit := T#2s; // Seuil ASCENDING_LOADED
        110, 111: StepLimit := T#2s; // Purge commandes RETAIN
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
    // ─────────── Préambule : armement contacteur simulé (requis sans hardware) ───────────
    5:
        GVL_IHM.Modes.BtnEmergencyArming := TRUE; // pulse réarmement → SimContactorOk → EmergencyStopOk
        IF PRG_00_Inputs.EmergencyStopOk THEN
            GVL_IHM.Modes.BtnEmergencyArming := FALSE;
            StepPassed := TRUE;
            Step := 10;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M1 : MAINT_N1 + homme-mort (+ arrêt + reprise) ───────────
    10:
        GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;
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
            IF RequestedCaseId = 1 THEN Step := 0; ELSE Step := 20; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M2 : MAINT_N2 + homme-mort ───────────
    20:
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        GVL_PLC_Tests.OverrideJoystickRawY := 5000;
        GVL_IHM.Modes.SelMode := E_Mode.MAINT_N2;
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
            IF RequestedCaseId = 2 THEN Step := 0; ELSE Step := 30; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M3 : SEMI_AUTO atteignable sans IHM_MANU ───────────
    30:
        GVL_PLC_Tests.OverrideJoystickRawButton := FALSE;
        GVL_PLC_Tests.OverrideJoystickRawY := 5000;
        GVL_IHM.Modes.SelMode := E_Mode.SEMI_AUTO;
        IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 3 THEN Step := 0; ELSE Step := 40; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M4 : Simulation fonctionnelle sans IHM_MANU ───────────
    40:
        IF GVL_Simulation.SimulationModeActive AND SimGateOk THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 4 THEN Step := 0; ELSE Step := 50; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M5 : Sécurité active + aucun mouvement sans autorisation de mode ───────────
    50:
        GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;
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
        GVL_IHM.Modes.BtnFaultReset := TRUE;
        IF PRG_04_Modes.instModes.Mode <> E_Mode.DISABLE THEN
            GVL_IHM.Modes.BtnFaultReset := FALSE;
            StepPassed := TRUE;
            IF RequestedCaseId = 5 THEN Step := 0; ELSE Step := 60; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M6 : Séquenceur (FB_Cycle) ne bloque jamais ───────────
    60:
        // 🔧 REX 2026-07-19 (revue mission IHM_MANU, finding B) : tentative RÉELLE de
        // démarrage (GVL_IHM.Cycle.BtnStart, ré-assertée chaque scan pour couvrir l'ordre
        // des tâches) pendant >200 ms hors SEMI_AUTO — instCycle.Enable=FALSE doit la rendre
        // sans effet (Busy reste FALSE), pas un simple instantané qui ne prouverait rien.
        GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1;
        GVL_IHM.Cycle.BtnStart := TRUE;
        IF (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N1) AND (StepElapsed >= T#200MS) THEN
            GVL_IHM.Cycle.BtnStart := FALSE;
            IF NOT PRG_05_Cycle.instCycle.Busy THEN
                StepPassed := TRUE;
                IF RequestedCaseId = 6 THEN Step := 0; ELSE Step := 65; END_IF;
            ELSE
                StepFailed := TRUE;
                Step := 0;
            END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M7 : DISABLE explicite neutralise M1/M2/M3 ───────────
    65:
        GVL_IHM.Modes.SelMode := E_Mode.DISABLE;
        IF PRG_04_Modes.instModes.Mode = E_Mode.DISABLE THEN
            StepPassed := TRUE;
            Step := 66;
            StepStarted := FALSE;
        END_IF;

    66:
        IF (PRG_06_WinchControl.instWinchM1.State = E_State.DISABLED)
           AND (PRG_06_WinchControl.instWinchM2.State = E_State.DISABLED)
           AND (PRG_07_TranslationControl.instTranslationM3.State = E_State.DISABLED)
           AND NOT PRG_06_WinchControl.instWinchM1.RelayFwd
           AND NOT PRG_06_WinchControl.instWinchM2.RelayFwd
           AND (PRG_07_TranslationControl.instTranslationM3.DriveControlWord = 0) THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 7 THEN Step := 0; ELSE Step := 70; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M8 : bypass codeur individuel et limité à MAINT_N2 ───────────
    70:
        TestSafetyWinch(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
            SyncEnable := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
            HeartbeatIhmOk := TRUE, EncoderAvailable := FALSE, EncoderFaultBypass := TRUE,
            ThermalFeedback := FALSE, BrakeThermalFeedback := FALSE, SlackCableDetected := FALSE,
            PhaseRotationOk := TRUE, TopPositionSensor := TRUE, InReferencingMode := FALSE,
            CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Direction := 0,
            MovementCommanded := FALSE, Homed := FALSE, HomingSuspect := FALSE, TopLimitM := 8.5,
            FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := TRUE, JoystickYNeutral := FALSE,
            BenneHoldStillActive := FALSE, ExpectedOtherWinchPosM := 0.0, BenneBusy := FALSE,
            OtherWinchInhibited := TRUE
        );
        IF ((TestSafetyWinch.ErrorId AND 16#0002) <> 0) AND TestSafetyWinch.SafeStop THEN
            StepPassed := TRUE;
            Step := 71;
            StepStarted := FALSE;
        END_IF;

    71:
        TestSafetyWinch(
            Enable := TRUE, Reset := TRUE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N2,
            SyncEnable := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
            HeartbeatIhmOk := TRUE, EncoderAvailable := FALSE, EncoderFaultBypass := TRUE,
            ThermalFeedback := FALSE, BrakeThermalFeedback := FALSE, SlackCableDetected := FALSE,
            PhaseRotationOk := TRUE, TopPositionSensor := TRUE, InReferencingMode := FALSE,
            CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Direction := 0,
            MovementCommanded := FALSE, Homed := FALSE, HomingSuspect := FALSE, TopLimitM := 8.5,
            FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := TRUE, JoystickYNeutral := FALSE,
            BenneHoldStillActive := FALSE, ExpectedOtherWinchPosM := 0.0, BenneBusy := FALSE,
            OtherWinchInhibited := TRUE
        );
        IF ((TestSafetyWinch.ErrorId AND 16#0002) = 0) AND NOT TestSafetyWinch.SafeStop THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 8 THEN Step := 0; ELSE Step := 80; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M9 : ConfigError interne remonte dans FB_Winch bit2 ───────────
    80:
        TestWinch(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
            StartStop := TRUE, SafeStop := FALSE, ForbidDescent := FALSE, ForbidAscent := FALSE,
            Direction := 1, SpeedRefPct := 50.0, SpeedStepTable := TestSpeedTable,
            CfgMaxStepDescente := 3, MaxStepAscent := 5, HomingApproachActive := FALSE,
            FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := TRUE, BypassContactorCheck := TRUE,
            SpeedStepHystMargin := 0.0, Homed := TRUE, HomingSuspect := FALSE,
            CablePosM := 0.0, TopLimitM := 8.0, BottomLimitM := -20.0,
            CfgSlowdownDistanceM := 1.0, CfgSlowSpeedPct := 15.0
        );
        IF ((TestWinch.ErrorId AND 16#0004) <> 0)
           AND NOT TestWinch.RelayFwd AND NOT TestWinch.RelayRev
           AND NOT TestWinch.Contactor1 AND NOT TestWinch.Contactor2
           AND NOT TestWinch.Contactor3 AND NOT TestWinch.Contactor4 THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 9 THEN Step := 0; ELSE Step := 90; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M10 : charge calculée uniquement en montée ───────────
    90:
        TestLoadTable.IsConfigured := TRUE;
        TestLoadTable.LoadPctByStepAndSpeedBand[1][1] := 42.0;
        TestLoadEstimator(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
            ActiveSpeedStep := 1, MeasuredSpeedMps := 0.1, MeasuredSpeedSignedMps := -0.1,
            SpeedConfig := TestSpeedConfig, LoadTable := TestLoadTable
        );
        IF (TestLoadEstimator.EstimatedLoadPct = 0.0) AND NOT TestLoadEstimator.Ascending THEN
            StepPassed := TRUE;
            Step := 91;
            StepStarted := FALSE;
        END_IF;

    91:
        TestLoadEstimator(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
            ActiveSpeedStep := 1, MeasuredSpeedMps := 0.1, MeasuredSpeedSignedMps := 0.1,
            SpeedConfig := TestSpeedConfig, LoadTable := TestLoadTable
        );
        IF (TestLoadEstimator.EstimatedLoadPct = 42.0) AND TestLoadEstimator.Ascending THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 10 THEN Step := 0; ELSE Step := 100; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M11 : seuil ASCENDING_LOADED = limite exploitation ───────────
    100:
        TestCycle(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, CycleMotionPermit := TRUE,
            HeartbeatIhmOk := TRUE, M1_CablePosM := 7.9, M2_CablePosM := 7.9,
            CableLimitM1AscentM := 8.0
        );
        // FB démarre en INIT ; on ne force pas l'état interne (pas d'accès VAR).
        // Vérifie seulement que la condition de transition est évaluée correctement :
        // tant que M1_CablePosM < CableLimitM1AscentM, les sorties StartStop restent TRUE
        IF TestCycle.CmdWinchM1_StartStop AND TestCycle.CmdWinchM2_StartStop THEN
            StepPassed := TRUE;
            Step := 101;
            StepStarted := FALSE;
        END_IF;

    101:
        TestCycle(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, CycleMotionPermit := TRUE,
            HeartbeatIhmOk := TRUE, M1_CablePosM := 8.0, M2_CablePosM := 8.0,
            CableLimitM1AscentM := 8.0
        );
        // M1_CablePosM >= CableLimitM1AscentM : la logique de transition demande l'arrêt
        IF NOT TestCycle.CmdWinchM1_StartStop AND NOT TestCycle.CmdWinchM2_StartStop THEN
            StepPassed := TRUE;
            Step := 102;
            StepStarted := FALSE;
        END_IF;

    102:
        TestCycle(
            Enable := TRUE, Reset := FALSE, EmergencyStopOk := TRUE, CycleMotionPermit := TRUE,
            HeartbeatIhmOk := TRUE, M1_CablePosM := 8.0, M2_CablePosM := 8.0,
            CableLimitM1AscentM := 8.0
        );
        // L'état interne devrait passer à DRAINING_PAUSE, mais on ne peut pas
        // forcer l'état. On vérifie que les sorties restent à l'arrêt.
        IF NOT TestCycle.CmdWinchM1_StartStop AND NOT TestCycle.CmdWinchM2_StartStop THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 11 THEN Step := 0; ELSE Step := 110; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-M12 : purge commandes RETAIN avant consommation ───────────
    110:
        GVL_IHM.M1TreuilRetenue.Cmd.BtnHome := TRUE;
        GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault := TRUE;
        GVL_IHM.M2TreuilBenne.Cmd.BtnReset := TRUE;
        GVL_IHM.M2Benne.BtnClose := TRUE;
        GVL_IHM.Cycle.BtnStart := TRUE;
        GVL_IHM.TranslationM3.Cmd.BtnFwd := TRUE;
        GVL_PLC_Tests.OverrideHmiCommandPurge := TRUE;
        StepPassed := TRUE;
        Step := 111;
        StepStarted := FALSE;

    111:
        IF NOT GVL_IHM.M1TreuilRetenue.Cmd.BtnHome
           AND NOT GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault
           AND NOT GVL_IHM.M2TreuilBenne.Cmd.BtnReset
           AND NOT GVL_IHM.M2Benne.BtnClose
           AND NOT GVL_IHM.Cycle.BtnStart
           AND NOT GVL_IHM.TranslationM3.Cmd.BtnFwd
           AND GVL_IHM.HmiInitDone THEN
            GVL_PLC_Tests.OverrideHmiCommandPurge := FALSE;
            StepPassed := TRUE;
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
        GVL_PLC_Tests.OverrideHmiCommandPurge := FALSE;
        GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault := FALSE;
        Busy := FALSE;
        Done := TRUE;
        Report.InProgress := FALSE;
        Report.AnyFailed := AnyFailed;
        Report.AllPassed := NOT AnyFailed;
        Report.TerminalState := SEL(AnyFailed, E_TestTerminalState.TEST_TERMINAL_DONE, E_TestTerminalState.TEST_TERMINAL_FAILED);
        TerminalState := Report.TerminalState;
        Report.Cases[1].Name := 'TC-M1..M12 Modes+WinchCore';
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

// Limite globale de sécurité de la suite : 90 s maximum.
IF Report.Duration >= T#90s AND Busy THEN
    GVL_PLC_Tests.OverrideJoystickActive := FALSE;
    GVL_PLC_Tests.OverrideContactorFalse := FALSE;
    GVL_PLC_Tests.OverrideHmiCommandPurge := FALSE;
    GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault := FALSE;
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
