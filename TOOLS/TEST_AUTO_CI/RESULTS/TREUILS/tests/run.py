#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine TREUILS."""
import pathlib
import subprocess
import sys

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "scripts" / "run_tests.py"

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "TREUILS", *sys.argv[1:]]))
