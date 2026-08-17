"""Tests de non-regression du gate de style CODE."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G100_check_code_style.py"
SPEC = importlib.util.spec_from_file_location("G100_check_code_style", SCRIPT)

check_code_style = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_code_style
SPEC.loader.exec_module(check_code_style)


def test_simulation_allowlist_limitee_aux_trois_frontieres_justifiees() -> None:
    expected_paths = {
        "CODE/M_MAIN/PRG_02_Acquisition.st",
        "CODE/M_MAIN/PRG_05_Translation.st",
        "CODE/M_MAIN/PRG_07_Supervision.st",
        "CODE/K_DEPANNAGE/FB_TroubleshootingView.st",
    }

    assert set(check_code_style.SIMULATION_ALLOWED_PATHS) == expected_paths
    for path in expected_paths:
        allowance = check_code_style.SIMULATION_ALLOWED_PATHS[path]
        assert allowance.executable_usage
        assert allowance.decision
        assert allowance.removal_condition
        assert check_code_style.simulation_reference_allowed(Path(path))

    assert not check_code_style.simulation_reference_allowed(
        Path("CODE/M_MAIN/PRG_SAFETY_CFC.st")
    )
