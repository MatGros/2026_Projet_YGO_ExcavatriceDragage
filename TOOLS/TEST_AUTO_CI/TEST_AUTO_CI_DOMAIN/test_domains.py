"""Tests Pytest automatiques par domaine (A_COMMUN, B_AU_SECURITE, etc.)."""

import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
RUN_TESTS_PY = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "run_tests.py"


def _run_domain_test(domain_name: str, workers: int = 4):
    cmd = [sys.executable, str(RUN_TESTS_PY), "--domain", domain_name, "--fast", "-j", str(workers)]
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
        error_msg = f"Échec du test pour le domaine {domain_name} (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-2000:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)
    assert proc.returncode == 0


@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_A_COMMUN():
    _run_domain_test("A_COMMUN", workers=6)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_B_AU_SECURITE():
    _run_domain_test("B_AU_SECURITE", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_C_DIAG_RESEAUX():
    _run_domain_test("C_DIAG_RESEAUX", workers=3)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_D_JOYSTICK():
    _run_domain_test("D_JOYSTICK", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_E_CODEURS():
    _run_domain_test("E_CODEURS", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_F_MODES():
    _run_domain_test("F_MODES", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_G_CYCLE():
    _run_domain_test("G_CYCLE", workers=3)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_H_TREUILS_BENNE():
    _run_domain_test("H_TREUILS_BENNE", workers=4)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_I_TRANSLATION():
    _run_domain_test("I_TRANSLATION", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_J_SUPERVISION():
    _run_domain_test("J_SUPERVISION", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_L_SIMULATION():
    _run_domain_test("L_SIMULATION", workers=2)

@pytest.mark.ci_fb
@pytest.mark.domain
def test_DOMAIN_M_MAIN():
    _run_domain_test("M_MAIN", workers=6)
