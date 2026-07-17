"""Contrôles statiques du contrat anti-blocage du banc PLC.

Ces tests ne remplacent pas la compilation CODESYS ; ils empêchent la
réintroduction des défauts structurels déjà rencontrés.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
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
