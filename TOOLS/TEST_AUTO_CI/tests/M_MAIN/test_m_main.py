"""Tests Pytest automatiques pour le domaine M_MAIN."""

import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[4]
RUN_TESTS_PY = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "run_tests.py"


def _run_fb_test(fb_name: str):
    cmd = [sys.executable, str(RUN_TESTS_PY), "--fb", fb_name, "--fast"]
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
        error_msg = f"Échec du test pour {fb_name} (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-1500:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0


@pytest.mark.ci_fb
def test_M_MAIN():
    """Test global du domaine M_MAIN (compilation parallèle multi-cœurs)."""
    cmd = [sys.executable, str(RUN_TESTS_PY), "--domain", "M_MAIN", "--fast", "-j", "7"]
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
        error_msg = f"Échec des tests pour le domaine M_MAIN (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-2000:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0

@pytest.mark.ci_fb
def test_PRG_02_Acquisition():
    """Test CI automatisé pour PRG_02_Acquisition."""
    _run_fb_test("PRG_02_Acquisition")

@pytest.mark.ci_fb
def test_PRG_03_Modes_Cycle():
    """Test CI automatisé pour PRG_03_Modes_Cycle."""
    _run_fb_test("PRG_03_Modes_Cycle")

@pytest.mark.ci_fb
def test_PRG_04_Treuils_Benne():
    """Test CI automatisé pour PRG_04_Treuils_Benne."""
    _run_fb_test("PRG_04_Treuils_Benne")

@pytest.mark.ci_fb
def test_PRG_05_Translation():
    """Test CI automatisé pour PRG_05_Translation."""
    _run_fb_test("PRG_05_Translation")

@pytest.mark.ci_fb
def test_PRG_06_Outputs():
    """Test CI automatisé pour PRG_06_Outputs."""
    _run_fb_test("PRG_06_Outputs")

@pytest.mark.ci_fb
def test_PRG_07_Supervision():
    """Test CI automatisé pour PRG_07_Supervision."""
    _run_fb_test("PRG_07_Supervision")

@pytest.mark.ci_fb
def test_MAIN_GLOBAL():
    """Test CI automatisé pour MAIN_GLOBAL."""
    _run_fb_test("MAIN_GLOBAL")
