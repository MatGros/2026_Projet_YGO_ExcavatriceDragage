from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_g390_keeps_its_scratch_out_of_project_root() -> None:
    source = (ROOT / "TOOLS/AGENT_WORKFLOW/scripts/G390_check_bundle_freshness.py").read_text(encoding="utf-8")
    assert 'root / "TOOLS" / "AGENT_WORKFLOW" / ".tmp"' in source
    assert "shutil.rmtree" not in source
    assert "nettoyage manuel requis" in source


def test_ci_runner_keeps_its_scratch_under_test_auto_ci() -> None:
    source = (ROOT / "TOOLS/TEST_AUTO_CI/scripts/run_tests.py").read_text(encoding="utf-8")
    assert 'TEST_AUTO_CI / ".scratch" / safe_name / uuid4().hex[:12]' in source
    assert "TemporaryDirectory" not in source
    assert "tempfile.mkdtemp" not in source
    assert "[NETTOYAGE MANUEL REQUIS]" in source
    assert 'if args.cleanup_scratch:' in source
    assert 'if n_fail:' in source
    assert '[SCRATCHS CONSERVES]' in source
