(* ═══════════════════════════════════════════════════════════════
   💓 FB_HeartbeatValidation — Suite table-driven Heartbeat IHM↔PLC
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-14_PLC_Tests_Validation_v1.2.md §7
   🎯 Simulation uniquement. Stimuli amont : toggle IHM, demande SEMI_AUTO,
      retours contacteurs/frein M1/M2, frein M3. Jamais d'écriture dans
      SafeStop/PowerCutOff/HeartbeatOk calculés.
   🧪 TC-H1 sain ; TC-H2 perte 2 s ; TC-H3 reprise sans redémarrage ;
      TC-H4 reset conscient ; TC-H5 escalade Méca B M3.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_HeartbeatValidation
VAR_INPUT
    Start       : BOOL;
    Abort       : BOOL;
    CaseId      : INT; // 0=tous ; 1..5=cas ciblé
END_VAR
VAR_OUTPUT
    Busy                    : BOOL;
    Done                    : BOOL;
    AnyFailed               : BOOL;
    SimGateOk               : BOOL;
    ActiveStimulusId        : INT;
    StepElapsed             : TIME;
    Report                  : ST_TestSuiteReport;
    TerminalState           : E_TestTerminalState;
    ConfigError             : BOOL;
    ConfigErrorStepId       : INT;
    ConfigErrorCheckIdx     : INT;
    ErrorCode               : INT;
    ErrorMessage            : STRING(160);
END_VAR
VAR CONSTANT
    // ── Sondes ──
    SigHeartbeatIhmOk       : INT := 1;
    SigHeartbeatIhmTimeout  : INT := 2;
    SigSafetyM1ErrorId      : INT := 3;
    SigSafetyM2ErrorId      : INT := 4;
    SigSafetyM3ErrorId      : INT := 5;
    SigCycleErrorId         : INT := 6;
    SigM1FwdRevSpeedFbOff   : INT := 7;
    SigM1BrakeFeedback      : INT := 8;
    SigM2FwdRevSpeedFbOff   : INT := 9;
    SigM2BrakeFeedback      : INT := 10;
    SigM3BrakeFeedback      : INT := 11;
    SigM3DriveActualFreqHz  : INT := 12;
    SigM3DriveStatusWord    : INT := 13;
    SigPowerCutOffActive    : INT := 14;
    // ── Étapes ──
    StepTcH1Setup           : INT := 10;
    StepTcH1WaitToggle      : INT := 11;
    StepTcH1Assert          : INT := 12;
    StepTcH1Teardown        : INT := 19;
    StepTcH2Setup           : INT := 20;
    StepTcH2Freeze          : INT := 21;
    StepTcH2Assert          : INT := 22;
    StepTcH2Teardown        : INT := 29;
    StepTcH3Setup           : INT := 30;
    StepTcH3Resume          : INT := 31;
    StepTcH3Assert          : INT := 32;
    StepTcH3Teardown        : INT := 39;
    StepTcH4Setup           : INT := 40;
    StepTcH4Reset           : INT := 41;
    StepTcH4Assert          : INT := 42;
    StepTcH4Teardown        : INT := 49;
    StepTcH5Setup           : INT := 50;
    StepTcH5MecaB           : INT := 51;
    StepTcH5Assert          : INT := 52;
    StepTcH5Teardown        : INT := 59;
END_VAR
VAR
    // Moteur
    Sequencer               : FB_TestSequencer;
    // Tables
    StepTable               : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable              : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable               : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
    InvariantTable          : ARRAY[1..GVL_PLC_Tests_Const.MaxInvariants] OF ST_TestInvariantConfig;
    // Sondes
    ProbeBool               : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool]  OF BOOL;
    ProbeDint               : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint]  OF DINT;
    ProbeReal               : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal]  OF REAL;
    TableReady              : BOOL := FALSE;
    StartPrev               : BOOL;
    // Stimuli locaux
    StimToggleTimer         : TON;
    StimModeRequest         : E_Mode;
    StimResetPulseTimer     : TON;
END_VAR

// ═══════════════════════════════════════════════════════════════
// 1. 🛡️ GATE
// ═══════════════════════════════════════════════════════════════
IF NOT GVL_Simulation.SimulationModeActive THEN
    Sequencer(Start := FALSE, Abort := TRUE, CaseId := CaseId,
              StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable, InvariantTable := InvariantTable,
              ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal, Report := Report);
    GVL_PLC_Tests.OverrideIhmHeartbeatActive := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
    GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM1BrakeFeedback := FALSE;
    GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM2BrakeFeedback := FALSE;
    GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
    GVL_IHM.Cycle.BtnReset := FALSE;
    Busy := FALSE; Done := TRUE; AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.InProgress := FALSE; Report.Aborted := TRUE; Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState; Report.FailureSummary := 'Heartbeat : NOT SimulationModeActive';
    RETURN;
END_IF;

SimGateOk := GVL_Simulation.SimulationModeActive
          AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal
          AND NOT GVL_Simulation.SensorM2ContactorFeedbackIsReal
          AND NOT GVL_Simulation.SensorBrakeThermalIsReal
          AND NOT GVL_Simulation.SensorM3ContactorFeedbackIsReal;

IF Abort OR NOT SimGateOk THEN
    GVL_PLC_Tests.OverrideIhmHeartbeatActive := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
    GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM1BrakeFeedback := FALSE;
    GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM2BrakeFeedback := FALSE;
    GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
    GVL_IHM.Cycle.BtnReset := FALSE;
    IF Busy THEN GVL_IHM.Modes.Cmd.SelMode := StimModeRequest; END_IF;
    Busy := FALSE; Done := TRUE; AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.InProgress := FALSE; Report.Aborted := TRUE; Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState; Report.FailureSummary := 'Heartbeat : ABORTED or SimGateOk=FALSE';
    RETURN;
END_IF;

IF Start AND NOT StartPrev AND NOT Busy THEN
    StartPrev := TRUE;
    Busy := TRUE; Done := FALSE; AnyFailed := FALSE; ConfigError := FALSE;
    ErrorCode := 0; ErrorMessage := '';
    StepElapsed := T#0s;
    StimModeRequest := GVL_IHM.Modes.Cmd.SelMode;

    Report.Name := 'Heartbeat Validation';
    Report.InProgress := TRUE; Report.AllPassed := FALSE; Report.AnyFailed := FALSE; Report.Aborted := FALSE;
    Report.TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    Report.ErrorCode := 0; Report.ErrorMessage := ''; Report.FailureSummary := '';
    Report.FailedTestCase := 0; Report.Duration := T#0s;
    Report.RunCounter := Report.RunCounter + 1;
END_IF;
IF NOT Start THEN StartPrev := FALSE; END_IF;

IF NOT Busy THEN RETURN; END_IF;

// ═══════════════════════════════════════════════════════════════
// 2. 📋 TABLES (remplissage unique)
// ═══════════════════════════════════════════════════════════════
IF NOT TableReady THEN
    Report.Name := 'Heartbeat Validation';

    // ── Cas de tests ──
    CaseTable[1].Name := 'TC-H1 Heartbeat sain';      CaseTable[1].FirstStep := StepTcH1Setup;
    CaseTable[2].Name := 'TC-H2 Perte IHM 2s';        CaseTable[2].FirstStep := StepTcH2Setup;
    CaseTable[3].Name := 'TC-H3 Reprise sans redem';  CaseTable[3].FirstStep := StepTcH3Setup;
    CaseTable[4].Name := 'TC-H4 Reset conscient';     CaseTable[4].FirstStep := StepTcH4Setup;
    CaseTable[5].Name := 'TC-H5 Escalade Meca B M3';  CaseTable[5].FirstStep := StepTcH5Setup;

    // ── Checks (index = ligne CheckTable) ──
    // 1: HeartbeatIhmOk = TRUE
    CheckTable[1].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[1].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[1].ProbeIdx := SigHeartbeatIhmOk;        CheckTable[1].ExpectedBool := TRUE;
    // 2: bit0 Safety M1 = 0
    CheckTable[2].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[2].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[2].ProbeIdx := SigSafetyM1ErrorId;        CheckTable[2].Mask := 16#0001;
    // 3: bit0 Safety M2 = 0
    CheckTable[3].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[3].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[3].ProbeIdx := SigSafetyM2ErrorId;        CheckTable[3].Mask := 16#0001;
    // 4: bit0 Safety M3 = 0
    CheckTable[4].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[4].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[4].ProbeIdx := SigSafetyM3ErrorId;        CheckTable[4].Mask := 16#0001;
    // 5: bit5 Cycle = 0
    CheckTable[5].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[5].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[5].ProbeIdx := SigCycleErrorId;           CheckTable[5].Mask := 16#0020;

    // 6: HeartbeatIhmOk = FALSE
    CheckTable[6].Kind := E_TestCheckKind.BOOL_EQUAL;    CheckTable[6].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[6].ProbeIdx := SigHeartbeatIhmOk;         CheckTable[6].ExpectedBool := FALSE;
    // 7: HeartbeatIhmTimeout = TRUE
    CheckTable[7].Kind := E_TestCheckKind.BOOL_EQUAL;    CheckTable[7].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[7].ProbeIdx := SigHeartbeatIhmTimeout;    CheckTable[7].ExpectedBool := TRUE;
    // 8: bit0 Safety M1 = 1
    CheckTable[8].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[8].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[8].ProbeIdx := SigSafetyM1ErrorId;        CheckTable[8].Mask := 16#0001;
    // 9: bit0 Safety M2 = 1
    CheckTable[9].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[9].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[9].ProbeIdx := SigSafetyM2ErrorId;        CheckTable[9].Mask := 16#0001;
    // 10: bit0 Safety M3 = 1
    CheckTable[10].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[10].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[10].ProbeIdx := SigSafetyM3ErrorId;       CheckTable[10].Mask := 16#0001;
    // 11: bit5 Cycle = 1
    CheckTable[11].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[11].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[11].ProbeIdx := SigCycleErrorId;          CheckTable[11].Mask := 16#0020;

    // 12: SafeStop M1 (via Error)
    CheckTable[12].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[12].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[12].ProbeIdx := SigSafetyM1ErrorId;       CheckTable[12].ExpectedBool := TRUE;
    // 13: SafeStop M2
    CheckTable[13].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[13].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[13].ProbeIdx := SigSafetyM2ErrorId;       CheckTable[13].ExpectedBool := TRUE;
    // 14: SafeStop M3
    CheckTable[14].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[14].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[14].ProbeIdx := SigSafetyM3ErrorId;       CheckTable[14].ExpectedBool := TRUE;

    // 15: HeartbeatIhmOk = TRUE (reprise)
    CheckTable[15].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[15].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[15].ProbeIdx := SigHeartbeatIhmOk;        CheckTable[15].ExpectedBool := TRUE;
    // 16-19: bit0 M1/M2/M3 = 1, bit5 Cycle = 1 (mémorisation)
    CheckTable[16].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[16].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[16].ProbeIdx := SigSafetyM1ErrorId;       CheckTable[16].Mask := 16#0001;
    CheckTable[17].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[17].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[17].ProbeIdx := SigSafetyM2ErrorId;       CheckTable[17].Mask := 16#0001;
    CheckTable[18].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[18].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[18].ProbeIdx := SigSafetyM3ErrorId;       CheckTable[18].Mask := 16#0001;
    CheckTable[19].Kind := E_TestCheckKind.WORD_MASK_ANY; CheckTable[19].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[19].ProbeIdx := SigCycleErrorId;          CheckTable[19].Mask := 16#0020;

    // 20: Reset → bit0 M1/M2/M3 = 0, bit5 Cycle = 0
    CheckTable[20].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[20].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[20].ProbeIdx := SigSafetyM1ErrorId;         CheckTable[20].Mask := 16#0001;
    CheckTable[21].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[21].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[21].ProbeIdx := SigSafetyM2ErrorId;         CheckTable[21].Mask := 16#0001;
    CheckTable[22].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[22].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[22].ProbeIdx := SigSafetyM3ErrorId;         CheckTable[22].Mask := 16#0001;
    CheckTable[23].Kind := E_TestCheckKind.WORD_MASK_NONE; CheckTable[23].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[23].ProbeIdx := SigCycleErrorId;            CheckTable[23].Mask := 16#0020;

    // 24: TC-H5 Méca B M3 — PowerCutOffActive = TRUE
    CheckTable[24].Kind := E_TestCheckKind.BOOL_EQUAL;   CheckTable[24].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[24].ProbeIdx := SigPowerCutOffActive;     CheckTable[24].ExpectedBool := TRUE;

    // ── Étapes ──
    // TC-H1
    StepTable[StepTcH1Setup].Name := 'H1 Setup SEMI_AUTO + toggle sain';
    StepTable[StepTcH1Setup].CaseId := 1; StepTable[StepTcH1Setup].StimulusId := 1;
    StepTable[StepTcH1Setup].CheckIdx[1] := 1; StepTable[StepTcH1Setup].CheckIdx[2] := 2;
    StepTable[StepTcH1Setup].CheckIdx[3] := 3; StepTable[StepTcH1Setup].CheckIdx[4] := 4;
    StepTable[StepTcH1Setup].CheckIdx[5] := 5;
    StepTable[StepTcH1Setup].TimeoutPT := T#5s; StepTable[StepTcH1Setup].NextOnPass := StepTcH1WaitToggle;
    StepTable[StepTcH1Setup].NextOnFail := StepTcH1Teardown; StepTable[StepTcH1Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH1WaitToggle].Name := 'H1 Attente 1er front post-boot';
    StepTable[StepTcH1WaitToggle].CaseId := 1; StepTable[StepTcH1WaitToggle].StimulusId := 1;
    StepTable[StepTcH1WaitToggle].CheckIdx[1] := 1;
    StepTable[StepTcH1WaitToggle].TimeoutPT := T#4s; StepTable[StepTcH1WaitToggle].NextOnPass := StepTcH1Assert;
    StepTable[StepTcH1WaitToggle].NextOnFail := StepTcH1Teardown; StepTable[StepTcH1WaitToggle].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH1Assert].Name := 'H1 Assert bit0=0 & bit5=0';
    StepTable[StepTcH1Assert].CaseId := 1; StepTable[StepTcH1Assert].StimulusId := 1;
    StepTable[StepTcH1Assert].CheckIdx[1] := 2; StepTable[StepTcH1Assert].CheckIdx[2] := 3;
    StepTable[StepTcH1Assert].CheckIdx[3] := 4; StepTable[StepTcH1Assert].CheckIdx[4] := 5;
    StepTable[StepTcH1Assert].TimeoutPT := T#2s; StepTable[StepTcH1Assert].NextOnPass := StepTcH1Teardown;
    StepTable[StepTcH1Assert].NextOnFail := StepTcH1Teardown; StepTable[StepTcH1Assert].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH1Teardown].Name := 'H1 Teardown';
    StepTable[StepTcH1Teardown].CaseId := 1; StepTable[StepTcH1Teardown].StimulusId := 0;
    StepTable[StepTcH1Teardown].DwellPT := T#200ms; StepTable[StepTcH1Teardown].TimeoutPT := T#1s;
    StepTable[StepTcH1Teardown].NextOnPass := 0; StepTable[StepTcH1Teardown].NextOnFail := 0;

    // TC-H2
    StepTable[StepTcH2Setup].Name := 'H2 Setup toggle figé';
    StepTable[StepTcH2Setup].CaseId := 2; StepTable[StepTcH2Setup].StimulusId := 2;
    StepTable[StepTcH2Setup].TimeoutPT := T#1s; StepTable[StepTcH2Setup].NextOnPass := StepTcH2Freeze;
    StepTable[StepTcH2Setup].NextOnFail := StepTcH2Teardown; StepTable[StepTcH2Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH2Freeze].Name := 'H2 Figer toggle > 2s timeout';
    StepTable[StepTcH2Freeze].CaseId := 2; StepTable[StepTcH2Freeze].StimulusId := 2;
    StepTable[StepTcH2Freeze].TimeoutPT := T#3s; StepTable[StepTcH2Freeze].NextOnPass := StepTcH2Assert;
    StepTable[StepTcH2Freeze].NextOnFail := StepTcH2Teardown; StepTable[StepTcH2Freeze].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH2Assert].Name := 'H2 Assert bit0=1 & SafeStop';
    StepTable[StepTcH2Assert].CaseId := 2; StepTable[StepTcH2Assert].StimulusId := 2;
    StepTable[StepTcH2Assert].CheckIdx[1] := 6;  StepTable[StepTcH2Assert].CheckIdx[2] := 7;
    StepTable[StepTcH2Assert].CheckIdx[3] := 8;  StepTable[StepTcH2Assert].CheckIdx[4] := 9;
    StepTable[StepTcH2Assert].CheckIdx[5] := 10; StepTable[StepTcH2Assert].CheckIdx[6] := 11;
    StepTable[StepTcH2Assert].CheckIdx[7] := 12; StepTable[StepTcH2Assert].CheckIdx[8] := 13;
    StepTable[StepTcH2Assert].CheckIdx[9] := 14;
    StepTable[StepTcH2Assert].TimeoutPT := T#3s; StepTable[StepTcH2Assert].NextOnPass := StepTcH2Teardown;
    StepTable[StepTcH2Assert].NextOnFail := StepTcH2Teardown; StepTable[StepTcH2Assert].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH2Teardown].Name := 'H2 Teardown';
    StepTable[StepTcH2Teardown].CaseId := 2; StepTable[StepTcH2Teardown].StimulusId := 0;
    StepTable[StepTcH2Teardown].DwellPT := T#200ms; StepTable[StepTcH2Teardown].TimeoutPT := T#1s;
    StepTable[StepTcH2Teardown].NextOnPass := 0; StepTable[StepTcH2Teardown].NextOnFail := 0;

    // TC-H3
    StepTable[StepTcH3Setup].Name := 'H3 Setup reprise toggle';
    StepTable[StepTcH3Setup].CaseId := 3; StepTable[StepTcH3Setup].StimulusId := 3;
    StepTable[StepTcH3Setup].TimeoutPT := T#1s; StepTable[StepTcH3Setup].NextOnPass := StepTcH3Resume;
    StepTable[StepTcH3Setup].NextOnFail := StepTcH3Teardown; StepTable[StepTcH3Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH3Resume].Name := 'H3 Reprise toggle > 2s';
    StepTable[StepTcH3Resume].CaseId := 3; StepTable[StepTcH3Resume].StimulusId := 3;
    StepTable[StepTcH3Resume].TimeoutPT := T#3s; StepTable[StepTcH3Resume].NextOnPass := StepTcH3Assert;
    StepTable[StepTcH3Resume].NextOnFail := StepTcH3Teardown; StepTable[StepTcH3Resume].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH3Assert].Name := 'H3 Assert bit0=1 & bit5=1';
    StepTable[StepTcH3Assert].CaseId := 3; StepTable[StepTcH3Assert].StimulusId := 3;
    StepTable[StepTcH3Assert].CheckIdx[1] := 15; StepTable[StepTcH3Assert].CheckIdx[2] := 16;
    StepTable[StepTcH3Assert].CheckIdx[3] := 17; StepTable[StepTcH3Assert].CheckIdx[4] := 18;
    StepTable[StepTcH3Assert].CheckIdx[5] := 19;
    StepTable[StepTcH3Assert].TimeoutPT := T#3s; StepTable[StepTcH3Assert].NextOnPass := StepTcH3Teardown;
    StepTable[StepTcH3Assert].NextOnFail := StepTcH3Teardown; StepTable[StepTcH3Assert].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH3Teardown].Name := 'H3 Teardown';
    StepTable[StepTcH3Teardown].CaseId := 3; StepTable[StepTcH3Teardown].StimulusId := 0;
    StepTable[StepTcH3Teardown].DwellPT := T#200ms; StepTable[StepTcH3Teardown].TimeoutPT := T#1s;
    StepTable[StepTcH3Teardown].NextOnPass := 0; StepTable[StepTcH3Teardown].NextOnFail := 0;

    // TC-H4
    StepTable[StepTcH4Setup].Name := 'H4 Setup reset pulse';
    StepTable[StepTcH4Setup].CaseId := 4; StepTable[StepTcH4Setup].StimulusId := 4;
    StepTable[StepTcH4Setup].TimeoutPT := T#1s; StepTable[StepTcH4Setup].NextOnPass := StepTcH4Reset;
    StepTable[StepTcH4Setup].NextOnFail := StepTcH4Teardown; StepTable[StepTcH4Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH4Reset].Name := 'H4 Pulse Reset IHM & Cycle';
    StepTable[StepTcH4Reset].CaseId := 4; StepTable[StepTcH4Reset].StimulusId := 4;
    StepTable[StepTcH4Reset].TimeoutPT := T#2s; StepTable[StepTcH4Reset].NextOnPass := StepTcH4Assert;
    StepTable[StepTcH4Reset].NextOnFail := StepTcH4Teardown; StepTable[StepTcH4Reset].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH4Assert].Name := 'H4 Assert bit0=0 & bit5=0';
    StepTable[StepTcH4Assert].CaseId := 4; StepTable[StepTcH4Assert].StimulusId := 1; // retour toggle sain
    StepTable[StepTcH4Assert].CheckIdx[1] := 20; StepTable[StepTcH4Assert].CheckIdx[2] := 21;
    StepTable[StepTcH4Assert].CheckIdx[3] := 22; StepTable[StepTcH4Assert].CheckIdx[4] := 23;
    StepTable[StepTcH4Assert].TimeoutPT := T#3s; StepTable[StepTcH4Assert].NextOnPass := StepTcH4Teardown;
    StepTable[StepTcH4Assert].NextOnFail := StepTcH4Teardown; StepTable[StepTcH4Assert].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH4Teardown].Name := 'H4 Teardown';
    StepTable[StepTcH4Teardown].CaseId := 4; StepTable[StepTcH4Teardown].StimulusId := 0;
    StepTable[StepTcH4Teardown].DwellPT := T#200ms; StepTable[StepTcH4Teardown].TimeoutPT := T#1s;
    StepTable[StepTcH4Teardown].NextOnPass := 0; StepTable[StepTcH4Teardown].NextOnFail := 0;

    // TC-H5
    StepTable[StepTcH5Setup].Name := 'H5 Setup Meca B M3 frein open';
    StepTable[StepTcH5Setup].CaseId := 5; StepTable[StepTcH5Setup].StimulusId := 5;
    StepTable[StepTcH5Setup].TimeoutPT := T#1s; StepTable[StepTcH5Setup].NextOnPass := StepTcH5MecaB;
    StepTable[StepTcH5Setup].NextOnFail := StepTcH5Teardown; StepTable[StepTcH5Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH5MecaB].Name := 'H5 Perte IHM + M3 open > 3s';
    StepTable[StepTcH5MecaB].CaseId := 5; StepTable[StepTcH5MecaB].StimulusId := 5;
    StepTable[StepTcH5MecaB].TimeoutPT := T#7s; StepTable[StepTcH5MecaB].NextOnPass := StepTcH5Assert;
    StepTable[StepTcH5MecaB].NextOnFail := StepTcH5Teardown; StepTable[StepTcH5MecaB].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH5Assert].Name := 'H5 Assert PowerCutOffActive';
    StepTable[StepTcH5Assert].CaseId := 5; StepTable[StepTcH5Assert].StimulusId := 5;
    StepTable[StepTcH5Assert].CheckIdx[1] := 24;
    StepTable[StepTcH5Assert].TimeoutPT := T#3s; StepTable[StepTcH5Assert].NextOnPass := StepTcH5Teardown;
    StepTable[StepTcH5Assert].NextOnFail := StepTcH5Teardown; StepTable[StepTcH5Assert].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTcH5Teardown].Name := 'H5 Teardown';
    StepTable[StepTcH5Teardown].CaseId := 5; StepTable[StepTcH5Teardown].StimulusId := 0;
    StepTable[StepTcH5Teardown].DwellPT := T#200ms; StepTable[StepTcH5Teardown].TimeoutPT := T#1s;
    StepTable[StepTcH5Teardown].NextOnPass := 0; StepTable[StepTcH5Teardown].NextOnFail := 0;

    TableReady := TRUE;
END_IF;

// ═══════════════════════════════════════════════════════════════
// 3. 📥 ACQUIRE — câblage sondes (1 ligne par signal, pas de logique)
// ═══════════════════════════════════════════════════════════════
ProbeBool[SigHeartbeatIhmOk]       := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk;
ProbeBool[SigHeartbeatIhmTimeout]  := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmTimeout;
ProbeDint[SigSafetyM1ErrorId]      := WORD_TO_DINT(PRG_03_Safety.instSafetyWinchM1.ErrorId);
ProbeDint[SigSafetyM2ErrorId]      := WORD_TO_DINT(PRG_03_Safety.instSafetyWinchM2.ErrorId);
ProbeDint[SigSafetyM3ErrorId]      := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeDint[SigCycleErrorId]         := WORD_TO_DINT(PRG_05_Cycle.instCycle.ErrorId);
ProbeBool[SigM1FwdRevSpeedFbOff]   := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff;
ProbeBool[SigM1BrakeFeedback]      := PRG_00_Inputs.M1BrakeFeedback;
ProbeBool[SigM2FwdRevSpeedFbOff]   := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff;
ProbeBool[SigM2BrakeFeedback]      := PRG_00_Inputs.M2BrakeFeedback;
ProbeBool[SigM3BrakeFeedback]      := PRG_00_Inputs.M3BrakeFeedback;
ProbeReal[SigM3DriveActualFreqHz]  := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
ProbeDint[SigM3DriveStatusWord]    := WORD_TO_DINT(PRG_00_Inputs.M3_StatusWord_Filtered);
ProbeBool[SigPowerCutOffActive]    := GVL_IHM.Modes.State.PowerCutOffActive;

// ═══════════════════════════════════════════════════════════════
// 4. ⚙️ MOTEUR
// ═══════════════════════════════════════════════════════════════
Sequencer(Start := Start, Abort := Abort, CaseId := CaseId,
          StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable, InvariantTable := InvariantTable,
          ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal, Report := Report,
          Busy => Busy, Done => Done, AnyFailed => AnyFailed,
          ConfigError => ConfigError, ConfigErrorStepId => ConfigErrorStepId, ConfigErrorCheckIdx => ConfigErrorCheckIdx,
          ActiveStimulusId => ActiveStimulusId, StepElapsed => StepElapsed,
          TerminalState => TerminalState, ErrorCode => ErrorCode, ErrorMessage => ErrorMessage);

// ═══════════════════════════════════════════════════════════════
// 5. ⚡ STIMULI — modèle hybride : TOR état-complet + pulse timer
// ═══════════════════════════════════════════════════════════════
// StimulusId 0 = neutre garanti (tout relâché) — sur Done/Abort par le moteur
GVL_PLC_Tests.OverrideIhmHeartbeatActive := FALSE;
GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff := FALSE;
GVL_PLC_Tests.OverrideM1BrakeFeedback := FALSE;
GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff := FALSE;
GVL_PLC_Tests.OverrideM2BrakeFeedback := FALSE;
GVL_IHM.Modes.Cmd.SelMode := StimModeRequest;
GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
GVL_IHM.Cycle.BtnReset := FALSE;

CASE ActiveStimulusId OF
    1: // TC-H1/TC-H4 : toggle sain 500 ms + SEMI_AUTO
        GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE;
        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
        // Toggle 500 ms
        StimToggleTimer(IN := TRUE, PT := T#500ms);
        IF StimToggleTimer.Q THEN
            GVL_PLC_Tests.OverrideIhmHeartbeatToggle := NOT GVL_PLC_Tests.OverrideIhmHeartbeatToggle;
            StimToggleTimer(IN := FALSE);
        END_IF;

    2: // TC-H2 : toggle figé (perte IHM)
        GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE;
        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
        // OverrideIhmHeartbeatToggle figé = pas de front

    3: // TC-H3 : reprise toggle sain
        GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE;
        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
        StimToggleTimer(IN := TRUE, PT := T#500ms);
        IF StimToggleTimer.Q THEN
            GVL_PLC_Tests.OverrideIhmHeartbeatToggle := NOT GVL_PLC_Tests.OverrideIhmHeartbeatToggle;
            StimToggleTimer(IN := FALSE);
        END_IF;

    4: // TC-H4 : pulse reset conscient
        GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE;
        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
        StimToggleTimer(IN := TRUE, PT := T#500ms);
        IF StimToggleTimer.Q THEN
            GVL_PLC_Tests.OverrideIhmHeartbeatToggle := NOT GVL_PLC_Tests.OverrideIhmHeartbeatToggle;
            StimToggleTimer(IN := FALSE);
        END_IF;
        StimResetPulseTimer(IN := TRUE, PT := T#1500ms);
        IF NOT StimResetPulseTimer.Q THEN
            GVL_IHM.Modes.Cmd.BtnFaultReset := TRUE;
            GVL_IHM.Cycle.BtnReset := TRUE;
        END_IF;

    5: // TC-H5 : perte IHM + frein M3 desserré → Méca B
        GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE;
        GVL_IHM.Modes.Cmd.SelMode := E_Mode.SEMI_AUTO;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := TRUE; // frein M3 desserré
        // Toggle figé = perte IHM
END_CASE;

// ═══════════════════════════════════════════════════════════════
// 6. 🛑 Premier échec → fin explicite, stimuli relâchés, rapport figé
// ═══════════════════════════════════════════════════════════════
IF ErrorCode <> 0 THEN
    GVL_PLC_Tests.OverrideIhmHeartbeatActive := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
    GVL_PLC_Tests.OverrideM1FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM1BrakeFeedback := FALSE;
    GVL_PLC_Tests.OverrideM2FwdRevSpeedFbOff := FALSE;
    GVL_PLC_Tests.OverrideM2BrakeFeedback := FALSE;
    GVL_IHM.Modes.Cmd.BtnFaultReset := FALSE;
    GVL_IHM.Cycle.BtnReset := FALSE;
    GVL_IHM.Modes.Cmd.SelMode := StimModeRequest;
    Busy := FALSE; Done := TRUE; AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_FAILED;
    Report.InProgress := FALSE; Report.TerminalState := TerminalState;
END_IF;