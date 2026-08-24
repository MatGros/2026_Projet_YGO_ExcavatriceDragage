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
    # Affichage du rapport complet dans la console VS Code Testing
    if proc.stdout:
        print(proc.stdout)
    if proc.stderr:
        print(proc.stderr, file=sys.stderr)

    if proc.returncode != 0:
        error_msg = f"Échec des tests CI pour {fb_name} (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-1500:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0


@pytest.mark.ci_fb
def test_FB_CycleTime():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_CycleTime."""
    _run_fb_test("FB_CycleTime")

@pytest.mark.ci_fb
def test_FB_Ramp():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_Ramp."""
    _run_fb_test("FB_Ramp")

@pytest.mark.ci_fb
def test_FB_Acquisition_Preflight():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_Acquisition_Preflight."""
    _run_fb_test("FB_Acquisition_Preflight")

@pytest.mark.ci_fb
def test_FB_FbStatus():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_FbStatus."""
    _run_fb_test("FB_FbStatus")

@pytest.mark.ci_fb
def test_FB_Filter():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_Filter."""
    _run_fb_test("FB_Filter")

@pytest.mark.ci_fb
def test_FB_Brake():
    """Test CI automatisé (C++ + ASSERT + Rapport HTML) pour FB_Brake."""
    _run_fb_test("FB_Brake")
