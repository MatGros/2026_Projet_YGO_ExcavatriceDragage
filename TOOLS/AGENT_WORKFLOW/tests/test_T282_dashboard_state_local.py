from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_dashboard_state_is_outside_results() -> None:
    source = (ROOT / "TOOLS/TEST_AUTO_CI/scripts/run_tests.py").read_text(encoding="utf-8")
    assert 'TEST_AUTO_CI / ".state" / "index_state.json"' in source
    assert 'TEST_AUTO_CI / "RESULTS" / ".index_state.json"' not in source


def test_dashboard_state_is_locally_ignored() -> None:
    ignore = (ROOT / "TOOLS/TEST_AUTO_CI/.gitignore").read_text(encoding="utf-8")
    assert "/.state/" in ignore


def test_dashboard_state_serializes_path_values() -> None:
    source = (ROOT / "TOOLS/TEST_AUTO_CI/scripts/run_tests.py").read_text(encoding="utf-8")
    assert "json.dumps(saved_state, indent=2, default=str)" in source
