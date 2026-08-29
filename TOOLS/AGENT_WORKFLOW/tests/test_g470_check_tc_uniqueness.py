"""Tests pour le gate G470_check_tc_uniqueness.py."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

from G470_check_tc_uniqueness import main  # noqa: E402


def test_g470_report_mode_ok_on_real_matrix() -> None:
    """Mode informatif (défaut) : exit 0 même avec recouvrements connus."""
    assert main([]) == 0


def test_g470_strict_fails_on_overlap(tmp_path: Path) -> None:
    """--strict : exit 2 dès qu'un ID TC est déclaré par 2 clés non-variantes."""
    matrix = {
        "domains": {
            "AF-99": {
                "file": "x.md",
                "functions": {},
                "validation_points": {
                    "TC-P99-001": {"intention": "a"},
                    "TC-P99-001, TC-P99-002": {"intention": "b"},
                },
            }
        }
    }
    f = tmp_path / "matrix.yaml"
    f.write_text(yaml.safe_dump(matrix, allow_unicode=True), encoding="utf-8")
    assert main(["--matrix", str(f)]) == 0  # informatif
    assert main(["--matrix", str(f), "--strict"]) == 2  # bloquant


def test_g470_strict_ok_on_clean_matrix(tmp_path: Path) -> None:
    """--strict : exit 0 quand le catalogue est propre (1 clé = 1 ID)."""
    matrix = {
        "domains": {
            "AF-99": {
                "file": "x.md",
                "functions": {},
                "validation_points": {
                    "TC-P99-001": {"intention": "a"},
                    "TC-P99-002": {"intention": "b"},
                    "TC-P99-002.1": {"intention": "c"},  # famille volontaire
                },
            }
        }
    }
    f = tmp_path / "matrix.yaml"
    f.write_text(yaml.safe_dump(matrix, allow_unicode=True), encoding="utf-8")
    assert main(["--matrix", str(f), "--strict"]) == 0
