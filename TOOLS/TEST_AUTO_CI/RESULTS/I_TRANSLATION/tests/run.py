#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine I_TRANSLATION avec mesure du temps et calibrage multithread.
"""
import pathlib
import subprocess
import sys
import time

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "run_tests.py"

if __name__ == "__main__":
    start = time.perf_counter()
    code = subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "I_TRANSLATION", *sys.argv[1:]])
    elapsed = time.perf_counter() - start
    minutes = int(elapsed // 60)
    seconds = elapsed % 60
    t_str = f"{minutes}m {seconds:.2f}s" if minutes > 0 else f"{seconds:.2f}s"
    print(f"\n⏱️  Duree totale domaine I_TRANSLATION : {t_str}")
    sys.exit(code)
