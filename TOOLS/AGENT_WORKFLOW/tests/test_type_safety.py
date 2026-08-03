"""Test de non-régression pour check_type_safety.py (détection statique des erreurs de type CODESYS)."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from check_type_safety import check_type_safety

def test_type_safety_passes_on_repository() -> None:
    errors = check_type_safety()
    assert errors == [], f"Erreurs de type détectées : {errors}"
