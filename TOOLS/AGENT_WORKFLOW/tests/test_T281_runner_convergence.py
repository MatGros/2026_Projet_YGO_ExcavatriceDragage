from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_all_executable_shortcuts_target_the_canonical_runner() -> None:
    test_auto_ci = ROOT / "TOOLS/TEST_AUTO_CI"
    assert not (test_auto_ci / "run_tests.py").exists()

    domain_batches = list((test_auto_ci / "RESULTS").glob("*/tests/run.bat"))
    assert len(domain_batches) == 12
    for batch in domain_batches:
        assert r"scripts\run_tests.py" in batch.read_text(encoding="utf-8")

    launchers = [
        *sorted((ROOT / "TOOLS/LANCEURS").glob("GRP*.bat")),
        ROOT / "TOOLS/LANCEURS/LANCER_TESTS_AVEC_RAPPORTS.bat",
        ROOT / "TOOLS/LANCEURS/LANCER_TESTS_RAPIDE_SANS_RAPPORTS.bat",
    ]
    for batch in launchers:
        assert r"TOOLS\TEST_AUTO_CI\scripts\run_tests.py" in batch.read_text(encoding="utf-8")

    for shortcut in (test_auto_ci / "RESULTS").rglob("run.py"):
        assert '"scripts" / "run_tests.py"' in shortcut.read_text(encoding="utf-8")


def test_canonical_runner_keeps_t279_and_user_feedback() -> None:
    source = (ROOT / "TOOLS/TEST_AUTO_CI/scripts/run_tests.py").read_text(encoding="utf-8")
    assert 'TEST_AUTO_CI / f".tmp_{safe_name}_' in source
    assert "[NETTOYAGE MANUEL REQUIS]" in source
    assert "Scratch CI conserve" in source
    assert 'group.add_argument("--domain", nargs="+",' in source
