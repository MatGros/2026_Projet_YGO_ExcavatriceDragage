"""Garde-fous des pages CFC XML staging : pas de squelette ni logique inline."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "check_cfc_wiring.py"


def test_staging_cfc_pages_pass_wiring_guard() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(ROOT)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "CFC wiring check: PASS" in result.stdout


def test_wiring_guard_contains_staging_skeleton_and_inline_checks() -> None:
    source = SCRIPT.read_text(encoding="utf-8")
    assert "[W5]" in source  # bloc sans entrée
    assert "[W6]" in source  # NOT/OR/AND/ABS dans une page CFC
    assert "[W7]" in source  # publication publique sans fil
