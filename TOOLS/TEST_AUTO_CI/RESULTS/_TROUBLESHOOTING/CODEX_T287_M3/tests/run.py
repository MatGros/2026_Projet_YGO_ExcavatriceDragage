#!/usr/bin/env python3
"""Lance l'exploration T287 avec un registre local, hors registre CI officiel."""
from __future__ import annotations

import pathlib
import sys
import tempfile

import yaml


HERE = pathlib.Path(__file__).resolve()
REPO_ROOT = next(parent for parent in HERE.parents if (parent / "TOOLS" / "TEST_AUTO_CI").is_dir())
SCRIPTS = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "scripts"
TEST_FILE = HERE.parent / "test_m3_limit_escalation_exploratory.st"

sys.path.insert(0, str(SCRIPTS))
import run_tests  # noqa: E402  (runner canonique du projet)


def main() -> int:
    entry = {
        "FB_Safety_Translation": {
            "domain": "_TROUBLESHOOTING/CODEX_T287_M3",
            "sources": [
                "CODE/A_COMMUN/_TYPES/E_State.st",
                "CODE/A_COMMUN/_TYPES/ST_Fault.st",
                "CODE/A_COMMUN/_TYPES/ST_FaultCause.st",
                "CODE/A_COMMUN/FB_FaultCore.st",
                "CODE/F_MODES/E_Mode.st",
                "CODE/I_TRANSLATION/FB_Safety_Translation.st",
            ],
            "test": str(TEST_FILE),
        }
    }
    # Registre éphémère hors dépôt : aucune entrée exploratoire n'est ajoutée au CI officiel.
    fd, registry_name = tempfile.mkstemp(prefix="codex_t287_registry_", suffix=".yaml")
    pathlib.Path(registry_name).write_text(yaml.safe_dump(entry, sort_keys=False), encoding="utf-8")
    pathlib.Path(registry_name).chmod(0o600)
    # Le fichier système est volontairement laissé au nettoyage normal de l'OS.
    run_tests.REGISTRY = pathlib.Path(registry_name)
    sys.argv = [str(SCRIPTS / "run_tests.py"), "--fb", "FB_Safety_Translation", *sys.argv[1:]]
    return run_tests.main()


if __name__ == "__main__":
    raise SystemExit(main())
