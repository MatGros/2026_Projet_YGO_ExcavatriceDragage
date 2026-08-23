#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine AU_SECURITE depuis ce dossier.
Equivalent a : python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --domain AU_SECURITE
"""
import pathlib
import subprocess
import sys

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "scripts" / "run_tests.py"

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "AU_SECURITE", *sys.argv[1:]]))
