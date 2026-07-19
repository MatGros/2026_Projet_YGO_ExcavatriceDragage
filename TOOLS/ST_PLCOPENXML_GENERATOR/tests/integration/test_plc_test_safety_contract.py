"""Contrôles statiques du contrat anti-blocage du banc PLC.

Ces tests ne remplacent pas la compilation CODESYS ; ils empêchent la
réintroduction des défauts structurels déjà rencontrés.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[4]
PLC = ROOT / "CODE" / "SIMULATION" / "PLC_TESTS"


def test_translation_step_ids_fit_the_table():
    source = (PLC / "SUITE_TRANSLATION" / "FB_TranslationValidation.st").read_text(encoding="utf-8")
    max_steps = int(re.search(r"MaxSteps\s*:\s*INT\s*:=\s*(\d+)", (PLC / "GVL_PLC_Tests_Const.st").read_text(encoding="utf-8")).group(1))
    step_ids = [int(value) for value in re.findall(r"Step\w+\s*:\s*INT\s*:=\s*(\d+)", source)]
    assert step_ids
    assert max(step_ids) <= max_steps


def test_sequencer_config_error_is_terminal():
    source = (PLC / "FB_TestSequencer.st").read_text(encoding="utf-8")
    assert "TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR" in source
    assert "Done := TRUE;" in source
    assert "Report.ErrorMessage := ErrorMessage" in source


def test_management_has_watchdog_and_event_log():
    source = (PLC / "SUITE_SAFETY" / "FB_PLC_Tests_Management.st").read_text(encoding="utf-8")
    gvl = (PLC / "GVL_PLC_Tests.st").read_text(encoding="utf-8")
    assert "MaxSuiteDurationMs" in source
    assert "SuiteWatchdogExpired" in source
    assert "GVL_PLC_Tests.EventLog[EventIdx]" in source
    assert "EventCount" in gvl and "EventOverflow" in gvl


def test_cycle_stabilization_cannot_wait_on_one_winch_forever():
    source = (ROOT / "CODE" / "CYCLE" / "FB_Cycle.st").read_text(encoding="utf-8")
    assert "StabilizationTimer" in source
    assert "CtrlAscentTimeout" in source
    assert "M1_CablePosM >= (TouchPositionM + CtrlAscentDistM)" in source
    assert "M2_CablePosM >= (TouchPositionM + CtrlAscentDistM)" in source
    assert "ABS(M1_CablePosM - M2_CablePosM)" in source
    assert "ErrorId := ErrorId OR 16#0008" in source


def test_encoder_homing_suite_is_targeted_and_has_watchdogs():
    suite = (ROOT / "CODE" / "SIMULATION" / "PLC_TESTS" / "SUITE_ENCODER" / "FB_EncoderValidation.st").read_text(encoding="utf-8")
    management = (ROOT / "CODE" / "SIMULATION" / "PLC_TESTS" / "SUITE_SAFETY" / "FB_PLC_Tests_Management.st").read_text(encoding="utf-8")
    constants = (ROOT / "CODE" / "SIMULATION" / "PLC_TESTS" / "GVL_PLC_Tests_Const.st").read_text(encoding="utf-8")
    assert "SuiteEncoder     : INT := 4" in constants
    assert "SuiteEncoder" in management
    assert "StepTimer(IN := TRUE, PT := StepLimit)" in suite
    assert "T#30s" in suite
    assert "TEST_TERMINAL_WATCHDOG_TIMEOUT" in suite
    assert "CmdHome" in suite
    assert "Busy := FALSE;" in suite and "Done := TRUE;" in suite
    assert "IF NOT StepPassed THEN" in suite
    assert "Step := 0;" in suite
    assert "CaseId := SEL(Step >= 20, 2, 1);" in suite
    assert "Report.CurrentCaseId := SEL(Step >= 20, 2, 1);" in suite
    assert "Gate simulation codeurs inactif" in suite
    assert "Report.ErrorCode := ErrorCode;" in suite


def test_encoder_homing_unitary_mode_is_selected_and_bounded():
    homing = (ROOT / "CODE" / "CODEURS" / "FB_Encoder_Homing.st").read_text(encoding="utf-8")
    encoders = (ROOT / "CODE" / "MAIN" / "PRG_02_Encoders.st").read_text(encoding="utf-8")
    hmi = (ROOT / "CODE" / "SUPERVISION" / "ST_WinchHMI.st").read_text(encoding="utf-8")
    assert "UnitaryMode          : BOOL" in homing
    assert "WinchSelected        : BOOL" in homing
    assert "HomingTargetM        : REAL" in homing
    assert "UnitaryMode AND NOT WinchSelected" in homing
    assert "TargetPositionM := HomingTargetM;" in homing
    assert "TargetPositionM := TopSensorPositionM;" in homing
    assert "TargetPositionM < -99.0" in homing and "TargetPositionM > 99.0" in homing
    assert "ErrorId := ErrorId OR 16#0010" in homing
    assert "TargetPositionM * UDINT_TO_REAL(PointsPerRev)" in homing
    assert "(TargetPositionM < -99.0) OR (TargetPositionM > 99.0)" in homing
    assert "JoystickWinchSelectArbitrated = 1" in encoders
    assert "JoystickWinchSelectArbitrated = 2" in encoders
    assert "HomingTargetM           : REAL" in hmi


def test_encoder_safety_is_integrated_and_exposed():
    safety = (ROOT / "CODE" / "CODEURS" / "FB_Encoder_Safety.st").read_text(encoding="utf-8")
    encoders = (ROOT / "CODE" / "MAIN" / "PRG_02_Encoders.st").read_text(encoding="utf-8")
    modes = (ROOT / "CODE" / "MAIN" / "PRG_04_Modes.st").read_text(encoding="utf-8")
    supervision = (ROOT / "CODE" / "MAIN" / "PRG_09_Supervision.st").read_text(encoding="utf-8")
    assert "FUNCTION_BLOCK PUBLIC FB_Encoder_Safety" in safety
    assert "instEncoderSafetyM1" in encoders and "instEncoderSafetyM2" in encoders
    assert "EncoderFaultPresent := PRG_02_Encoders.EncoderFaultPresent" in modes
    assert "instEncoderSafetyM1.Error" in supervision
    assert "instEncoderSafetyM2.Error" in supervision
    assert "EncoderIncoherent := Error" in safety


def test_winch_measured_speed_is_exposed_to_hmi():
    safety = (ROOT / "CODE" / "TREUILS" / "FB_Safety_Winch.st").read_text(encoding="utf-8")
    hmi = (ROOT / "CODE" / "SUPERVISION" / "ST_WinchHMI.st").read_text(encoding="utf-8")
    supervision = (ROOT / "CODE" / "MAIN" / "PRG_09_Supervision.st").read_text(encoding="utf-8")
    assert "MeasuredSpeedMps    : REAL" in safety
    assert "MeasuredSpeedMps        : REAL" in hmi
    assert "M1TreuilRetenue.MeasuredSpeedMps" in supervision
    assert "M2TreuilBucket.MeasuredSpeedMps" in supervision


def test_encoder_speed_monitor_has_bounded_confirmation_and_reset():
    source = (ROOT / "CODE" / "CODEURS" / "FB_Encoder_SpeedMonitor.st").read_text(encoding="utf-8")
    assert "FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMonitor" in source
    assert "SpeedVariationThresholdMps" in source
    assert "SpeedVariationTimeout" in source
    assert "SpeedStabilityTimeout" in source
    assert "VariationTimer(IN := VariationActive, PT := SpeedVariationTimeout)" in source
    assert "SpeedVariationConfirmed := VariationTimer.Q" in source
    assert "SpeedStable := StabilityTimer.Q" in source
    assert "ErrorId := ErrorId OR 16#0001" in source
    assert "ELSIF ResetEdge.Q AND NOT VariationActive THEN" in source
    assert "IF NOT Enable OR NOT EmergencyStopOk THEN" in source


def test_cycle_uses_measured_winch_speed_with_timeout_gate():
    cycle = (ROOT / "CODE" / "CYCLE" / "FB_Cycle.st").read_text(encoding="utf-8")
    caller = (ROOT / "CODE" / "MAIN" / "PRG_05_Cycle.st").read_text(encoding="utf-8")
    assert "M1_MeasuredSpeedMps" in cycle and "M2_MeasuredSpeedMps" in cycle
    assert "SpeedMismatchMps := ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps)" in cycle
    assert "AND CycleMotionPermit" in cycle
    assert "SpeedMismatchTimer(IN := SpeedMismatchActive, PT := SpeedMismatchTimeout)" in cycle
    assert "ErrorId := ErrorId OR 16#0010" in cycle
    assert "M1_MeasuredSpeedMps := PRG_03_Safety.instSafetyWinchM1.MeasuredSpeedMps" in caller
    assert "M2_MeasuredSpeedMps := PRG_03_Safety.instSafetyWinchM2.MeasuredSpeedMps" in caller


def test_speed_diagnostics_are_exposed_per_winch_and_cycle():
    winch_hmi = (ROOT / "CODE" / "SUPERVISION" / "ST_WinchHMI.st").read_text(encoding="utf-8")
    cycle_hmi = (ROOT / "CODE" / "SUPERVISION" / "ST_CycleHMI.st").read_text(encoding="utf-8")
    safety = (ROOT / "CODE" / "MAIN" / "PRG_03_Safety.st").read_text(encoding="utf-8")
    supervision = (ROOT / "CODE" / "MAIN" / "PRG_09_Supervision.st").read_text(encoding="utf-8")
    cycle = (ROOT / "CODE" / "MAIN" / "PRG_05_Cycle.st").read_text(encoding="utf-8")
    assert "SpeedVariationConfirmed" in winch_hmi
    assert "SpeedMismatchConfirmed" in cycle_hmi
    assert "instSpeedMonitorM1" in safety and "instSpeedMonitorM2" in safety
    assert "M1TreuilRetenue.SpeedMonitorError" in supervision
    assert "M2TreuilBucket.SpeedMonitorError" in supervision
    assert "GVL_IHM.Cycle.SpeedMismatchConfirmed" in cycle


def test_winch_speed_config_separates_measured_bands_from_contactors():
    config = (ROOT / "CODE" / "TREUILS" / "ST_WinchSpeedConfig.st").read_text(encoding="utf-8")
    persistent = (ROOT / "CODE" / "GVL_PERSISTENT.st").read_text(encoding="utf-8")
    assert "TYPE ST_WinchSpeedConfig" in config
    assert "SpeedBandMaxMps          : ARRAY[1..5] OF REAL" in config
    assert "MaxMeasuredSpeedMps    := 2.0" in persistent
    assert "SpeedBandMaxMps        := [0.4, 0.8, 1.2, 1.6, 2.0]" in persistent
    assert "SpeedBandHysteresisMps := 0.05" in persistent


def test_load_estimator_is_explicitly_non_safety_and_table_gated():
    estimator = (ROOT / "CODE" / "TREUILS" / "FB_WinchLoadEstimator.st").read_text(encoding="utf-8")
    table = (ROOT / "CODE" / "TREUILS" / "ST_WinchLoadEstimateTable.st").read_text(encoding="utf-8")
    safety = (ROOT / "CODE" / "MAIN" / "PRG_03_Safety.st").read_text(encoding="utf-8")
    assert "FUNCTION_BLOCK PUBLIC FB_WinchLoadEstimator" in estimator
    assert "LoadPctByStepAndSpeedBand     : ARRAY[1..5] OF ARRAY[1..5] OF REAL" in table
    assert "IF Configured AND (ActiveSpeedStep >= 1)" in estimator
    assert "EstimatedLoadPct := 0.0;" in estimator
    assert "instLoadEstimatorM1" in safety and "instLoadEstimatorM2" in safety


def test_speed_step_guard_is_disabled_by_default_and_limits_requested_step():
    speed_step = (ROOT / "CODE" / "TREUILS" / "FB_SpeedStep.st").read_text(encoding="utf-8")
    winch = (ROOT / "CODE" / "TREUILS" / "FB_Winch.st").read_text(encoding="utf-8")
    control = (ROOT / "CODE" / "MAIN" / "PRG_06_WinchControl.st").read_text(encoding="utf-8")
    assert "SpeedGuardEnable  : BOOL := FALSE" in speed_step
    assert "IF NOT SpeedGuardReady THEN" in speed_step
    assert "StepNumber := MeasuredSpeedBand" in speed_step
    assert "SpeedGuardEnable        := SpeedGuardEnableM1" in control
    assert "SpeedGuardEnable        := SpeedGuardEnableM2" in control
    assert "SpeedGuardReady         := PRG_03_Safety.instSpeedMonitorM1.SpeedStable" in control
    assert "SpeedGuardReady         := PRG_03_Safety.instSpeedMonitorM2.SpeedStable" in control
    assert "SpeedGuardLimited := SpeedStep.SpeedGuardLimited" in winch


def test_joystick_and_translation_speed_references_are_bounded():
    axis_scale = (ROOT / "CODE" / "JOYSTICK" / "FB_AxisScale.st").read_text(encoding="utf-8")
    ramp = (ROOT / "CODE" / "COMMUN" / "FB_Ramp.st").read_text(encoding="utf-8")
    translation_control = (ROOT / "CODE" / "MAIN" / "PRG_07_TranslationControl.st").read_text(encoding="utf-8")
    assert "OutPct := LIMIT(-100.0, OutPct, 100.0);" in axis_scale
    assert "TargetLimited := LIMIT(-100.0, Target, 100.0);" in ramp
    assert "Current := LIMIT(-100.0, Current, 100.0);" in ramp
    assert "M3_SpeedRef_Active := LIMIT(0.0, ABS(M3_SpeedRef_Active), 100.0);" in translation_control


def test_emergency_stop_ok_source_is_explicitly_conditioned():
    inputs = (ROOT / "CODE" / "MAIN" / "PRG_00_Inputs.st").read_text(encoding="utf-8")
    assert "instEmergencyStopOk(InputRaw := EmergencyStopOk_DI OR instSimSafety.SimContactorOk" in inputs
    assert "EmergencyStopOk := instEmergencyStopOk.State;" in inputs
    assert "OverrideContactorFalse" in inputs


def test_winch_safety_detects_opposite_direction_and_no_motion():
    safety = (ROOT / "CODE" / "TREUILS" / "FB_Safety_Winch.st").read_text(encoding="utf-8")
    wiring = (ROOT / "CODE" / "MAIN" / "PRG_03_Safety.st").read_text(encoding="utf-8")
    assert "MeasuredSpeedSignedMps" in safety
    assert "TonOppositeDirection" in safety and "16#4000" in safety
    assert "TonNoMovement" in safety and "16#8000" in safety
    assert "16#FF9F" in safety
    assert "instWinchM1.RelayFwd OR PRG_06_WinchControl.instWinchM1.RelayRev" in wiring
    assert "instWinchM2.RelayFwd OR PRG_06_WinchControl.instWinchM2.RelayRev" in wiring
