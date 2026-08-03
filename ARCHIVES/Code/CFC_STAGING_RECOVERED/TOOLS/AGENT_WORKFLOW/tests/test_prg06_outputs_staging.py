"""Guard M5: PowerCutOff staging aggregation must remain a strict four-source OR."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "CODE" / "MAIN" / "PRG_06_Outputs_Staging_LD.st"


def test_power_cutoff_staging_has_all_public_sources_and_strict_or() -> None:
    text = SOURCE.read_text(encoding="utf-8")

    match = re.search(
        r"PowerCutOffReq\s*:=\s*(.*?);\s*\n\s*// Gestionnaire d'arrêt d'urgence",
        text,
        flags=re.DOTALL,
    )
    assert match, "PowerCutOffReq aggregation must precede emergency management"

    expression = match.group(1)
    expected_sources = {
        "PowerCutOffWinchM1Request",
        "PowerCutOffWinchM2Request",
        "PowerCutOffTranslationM3Request",
        "PowerCutOffEmergencyRequest",
    }
    assert all(source in expression for source in expected_sources)
    assert expression.count(" OR ") == 3
    assert " AND " not in expression


def test_staging_does_not_override_legacy_outputs_program() -> None:
    legacy = ROOT / "CODE" / "MAIN" / "PRG_OUTPUTS_LD.st"
    assert legacy.is_file(), "legacy Outputs must stay active until atomic MainTask cutover"
    assert "PROGRAM PRG_10_Outputs_LD" in legacy.read_text(encoding="utf-8")
