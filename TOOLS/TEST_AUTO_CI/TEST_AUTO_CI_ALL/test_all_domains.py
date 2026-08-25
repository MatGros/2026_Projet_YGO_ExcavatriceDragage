"""Test Pytest global : exécution de tous les blocs fonctionnels du projet en parallèle."""

import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
RUN_TESTS_PY = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "run_tests.py"


@pytest.mark.ci_fb
@pytest.mark.all_domains
def test_ALL_DOMAINS():
    """Exécute l'intégralité des 28 blocs fonctionnels du projet en parallèle sur 12 cœurs CPU."""
    cmd = [sys.executable, str(RUN_TESTS_PY), "--all", "--fast", "-j", "12"]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=str(REPO_ROOT),
    )
    if proc.stdout:
        try:
            print(proc.stdout)
        except UnicodeEncodeError:
            print(proc.stdout.encode("ascii", errors="replace").decode("ascii"))
    if proc.stderr:
        try:
            print(proc.stderr, file=sys.stderr)
        except UnicodeEncodeError:
            print(proc.stderr.encode("ascii", errors="replace").decode("ascii"), file=sys.stderr)

    if proc.returncode != 0:
        error_msg = f"Échec de l'exécution globale (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-2500:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0
