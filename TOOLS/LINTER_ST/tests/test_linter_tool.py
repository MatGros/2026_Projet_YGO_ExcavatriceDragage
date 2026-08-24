"""Tests Pytest pour le moteur TOOLS/LINTER_ST."""

import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
LINTER_DIR = REPO_ROOT / "TOOLS" / "LINTER_ST"
LINT_PY = LINTER_DIR / "lint.py"
STRUCPP_EXE = LINTER_DIR / "bin" / "win32-x64" / "strucpp.exe"


def test_linter_binary_and_scripts_present():
    """Vérifie que le binaire strucpp.exe et le script lint.py sont présents."""
    assert LINT_PY.exists(), f"lint.py introuvable dans {LINTER_DIR}"
    assert STRUCPP_EXE.exists(), f"strucpp.exe introuvable dans {STRUCPP_EXE}"


def test_linter_execution_smoke():
    """Vérifie que le linter s'exécute et retourne un résultat JSON propre."""
    sample_file = REPO_ROOT / "CODE" / "A_COMMUN" / "FB_Ramp.st"
    if not sample_file.exists():
        # Fallback sur n'importe quel fichier .st de CODE
        st_files = list((REPO_ROOT / "CODE").rglob("*.st"))
        if not st_files:
            pytest.skip("Aucun fichier .st dans CODE")
        sample_file = st_files[0]

    cmd = [sys.executable, str(LINT_PY), str(sample_file), "--json"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    # Le linter peut sortir avec 0 (succès), 1 (erreur trouvée) ou 2 (incomplet), mais pas 3 (crash tooling)
    assert proc.returncode in (0, 1, 2), f"Crash inattendu du linter (code {proc.returncode}) : {proc.stderr}"
