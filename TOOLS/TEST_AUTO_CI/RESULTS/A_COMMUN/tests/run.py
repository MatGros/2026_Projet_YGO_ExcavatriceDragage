#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine A_COMMUN depuis ce dossier
(4 FB independants, une seule fiche de rapport groupee -- cf. registry.yaml "report_group").
Equivalent a : python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --domain A_COMMUN
"""
import pathlib
import subprocess
import sys

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "scripts" / "run_tests.py"

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "A_COMMUN", *sys.argv[1:]]))
