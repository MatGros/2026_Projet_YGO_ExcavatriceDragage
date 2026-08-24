"""Tests Pytest automatisés pour le Linter ST sur l'intégralité du dossier CODE/.

Permet de tester tout le code ST en 1 clic ou fichier par fichier depuis
le panneau Testing de VS Code, équivalent à Ctrl+Shift+P > 'Linter ST : Analyser tout le code'.
"""

import json
import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
LINT_PY = REPO_ROOT / "TOOLS" / "LINTER_ST" / "lint.py"
CODE_DIR = REPO_ROOT / "CODE"

# Collecte de tous les fichiers .st de CODE/
ST_FILES = sorted([f.relative_to(REPO_ROOT) for f in CODE_DIR.rglob("*.st")])


@pytest.mark.linter
@pytest.mark.parametrize("st_rel_path", ST_FILES, ids=lambda p: str(p).replace("\\", "/"))
def test_linter_st_file(st_rel_path):
    """Vérifie la conformité syntaxique et sémantique STruCpp d'un fichier .st de CODE/."""
    file_path = REPO_ROOT / st_rel_path
    cmd = [sys.executable, str(LINT_PY), str(file_path)]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=str(REPO_ROOT),
    )

    if proc.stdout:
        print(proc.stdout)
    if proc.stderr:
        print(proc.stderr, file=sys.stderr)

    assert proc.returncode != 3, f"Erreur d'exécution du linter pour {st_rel_path} : {proc.stderr}"

    if proc.returncode == 1:
        try:
            data = json.loads(proc.stdout)
            diags = data.get("diagnostics", [])
            errors = [d for d in diags if d.get("severity") == "error"]
            if errors:
                msg = f"Erreurs de syntaxe / typage détectées dans {st_rel_path} :\n"
                for d in errors:
                    msg += f"  - Ligne {d['line']}, Col {d['col']}: {d['message']}\n"
                pytest.fail(msg)
        except json.JSONDecodeError:
            pytest.fail(f"Sortie invalide du linter pour {st_rel_path} :\n{proc.stdout}\n{proc.stderr}")
