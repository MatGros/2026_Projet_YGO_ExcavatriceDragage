#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine JOYSTICK depuis ce dossier.
Equivalent a : python TOOLS/TEST_AUTO_CI/run_tests.py --domain JOYSTICK
"""
import pathlib
import subprocess
import sys

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "run_tests.py"

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "JOYSTICK", *sys.argv[1:]]))
