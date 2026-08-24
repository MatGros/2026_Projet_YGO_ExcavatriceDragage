"""Tests Pytest automatiques pour le domaine A_COMMUN."""

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
def test_A_COMMUN():
    """Test global du domaine A_COMMUN (compilation parallèle multi-cœurs)."""
    cmd = [sys.executable, str(RUN_TESTS_PY), "--domain", "A_COMMUN", "--fast", "-j", "6"]
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
        error_msg = f"Échec des tests pour le domaine A_COMMUN (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-2000:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0

@pytest.mark.ci_fb
def test_FB_CycleTime():
    """Test CI automatisé pour FB_CycleTime."""
    _run_fb_test("FB_CycleTime")

@pytest.mark.ci_fb
def test_FB_Ramp():
    """Test CI automatisé pour FB_Ramp."""
    _run_fb_test("FB_Ramp")

@pytest.mark.ci_fb
def test_FB_Acquisition_Preflight():
    """Test CI automatisé pour FB_Acquisition_Preflight."""
    _run_fb_test("FB_Acquisition_Preflight")

@pytest.mark.ci_fb
def test_FB_FbStatus():
    """Test CI automatisé pour FB_FbStatus."""
    _run_fb_test("FB_FbStatus")

@pytest.mark.ci_fb
def test_FB_Filter():
    """Test CI automatisé pour FB_Filter."""
    _run_fb_test("FB_Filter")

@pytest.mark.ci_fb
def test_FB_Brake():
    """Test CI automatisé pour FB_Brake."""
    _run_fb_test("FB_Brake")
