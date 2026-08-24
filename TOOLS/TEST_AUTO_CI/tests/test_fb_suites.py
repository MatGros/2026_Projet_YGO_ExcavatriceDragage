"""Tests Pytest unitaires pour chaque Function Block enregistré dans TEST_AUTO_CI.

Permet de lancer le test CI, la compilation C++ et la génération de rapport
de n'importe quel FB directement depuis le panneau Testing de VS Code ou en CLI :
    pytest TOOLS/TEST_AUTO_CI/tests/test_fb_suites.py -k FB_Joystick
"""

import subprocess
import sys
from pathlib import Path
import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
RUN_TESTS_PY = TEST_AUTO_CI / "run_tests.py"
REGISTRY_FILE = TEST_AUTO_CI / "registry.yaml"


def get_registered_fbs():
    """Charge la liste de tous les FB testables depuis registry.yaml."""
    if not REGISTRY_FILE.exists():
        return []
    try:
        data = yaml.safe_load(REGISTRY_FILE.read_text(encoding="utf-8")) or {}
        return [k for k, v in data.items() if isinstance(v, dict) and "test" in v]
    except Exception:
        return []


REGISTERED_FBS = get_registered_fbs()


@pytest.mark.ci_fb
@pytest.mark.parametrize("fb_name", REGISTERED_FBS)
def test_fb_ci_suite(fb_name):
    """Exécute la suite de tests C++ automatisée et génère le rapport pour le FB ciblé."""
    cmd = [sys.executable, str(RUN_TESTS_PY), "--fb", fb_name]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=str(REPO_ROOT),
    )

    # Affichage du résumé en cas d'échec
    if proc.returncode != 0:
        error_msg = f"Échec des tests CI pour {fb_name} (code {proc.returncode}) :\n"
        error_msg += proc.stdout[-1500:] if proc.stdout else ""
        error_msg += proc.stderr[-1000:] if proc.stderr else ""
        pytest.fail(error_msg)

    assert proc.returncode == 0, f"Le test CI de {fb_name} a échoué"
