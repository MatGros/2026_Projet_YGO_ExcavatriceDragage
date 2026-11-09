"""Unit tests for the isolated judge prompt seam (Lot C1).

Verifies prompt structure, presence of mandatory output format requirements,
and integrity of the judge instructions.
"""
from TOOLS.AGENT_SUPERVISOR.scripts.judge_prompt import OMNI_JUDGE_SYSTEM, BASELINE_OMNI_JUDGE_SYSTEM


def test_judge_prompt_structure_and_json_contract():
    assert isinstance(OMNI_JUDGE_SYSTEM, str)
    assert len(OMNI_JUDGE_SYSTEM) > 500
    # Must enforce JSON response format
    assert '{"alerts":' in OMNI_JUDGE_SYSTEM
    assert '"evidence_span"' in OMNI_JUDGE_SYSTEM
    assert '"priority":"warning|alarm"' in OMNI_JUDGE_SYSTEM


def test_baseline_prompt_is_valid_prefix():
    assert BASELINE_OMNI_JUDGE_SYSTEM in OMNI_JUDGE_SYSTEM
    assert "Tu es un juge consultatif" in BASELINE_OMNI_JUDGE_SYSTEM
