"""Tests Pytest automatiques pour le domaine H_TREUILS_BENNE."""

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
@pytest.mark.domain
def test_H_TREUILS_BENNE():
    """Test global du domaine H_TREUILS_BENNE (compilation parallèle multi-cœurs)."""
    cmd = [sys.executable, str(RUN_TESTS_PY), "--domain", "H_TREUILS_BENNE", "--fast", "-j", "2"]
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
        error_msg = f"Échec des tests pour le domaine H_TREUILS_BENNE (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-2000:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0

@pytest.mark.ci_fb
@pytest.mark.unit
def test_FB_Winch():
    """Test CI automatisé pour FB_Winch."""
    _run_fb_test("FB_Winch")

@pytest.mark.ci_fb
@pytest.mark.unit
def test_FB_Bucket():
    """Test CI automatisé pour FB_Bucket."""
    _run_fb_test("FB_Bucket")
