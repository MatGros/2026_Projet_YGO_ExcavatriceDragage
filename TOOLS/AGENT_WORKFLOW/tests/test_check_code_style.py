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


def test_reserved_keywords_detection_in_declarations_and_params() -> None:
    """Non-regression REX 2026-08-26 : rejet des mots-clés réservés IEC/CODESYS en identifiants."""
    text_bad_decl = """FUNCTION_BLOCK FB_Test
VAR_INPUT
    Retain : BOOL;
END_VAR
"""
    m = check_code_style.DECL_VAR_RE.search(text_bad_decl)
    assert m is not None
    assert m.group(1).upper() in check_code_style.RESERVED_IEC_CODESYS_KEYWORDS

    text_bad_param = "instFB(Hmi := TRUE, Retain := FALSE);"
    params = [m.group(1).upper() for m in check_code_style.PARAM_CALL_RE.finditer(text_bad_param)]
    assert "RETAIN" in params
    assert any(p in check_code_style.RESERVED_IEC_CODESYS_KEYWORDS for p in params)

    text_good = """FUNCTION_BLOCK FB_Test
VAR_INPUT
    RetainVal : BOOL;
END_VAR
"""
    m_good = check_code_style.DECL_VAR_RE.search(text_good)
    assert m_good is not None
    assert m_good.group(1).upper() not in check_code_style.RESERVED_IEC_CODESYS_KEYWORDS

    text_good_param = "instFB(Hmi := TRUE, RetainVal := FALSE);"
    params_good = [m.group(1).upper() for m in check_code_style.PARAM_CALL_RE.finditer(text_good_param)]
    assert not any(p in check_code_style.RESERVED_IEC_CODESYS_KEYWORDS for p in params_good)

