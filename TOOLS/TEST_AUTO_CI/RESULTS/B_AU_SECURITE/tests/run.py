#!/usr/bin/env python3
"""Raccourci : lance les tests du domaine B_AU_SECURITE avec mesure du temps et calibrage multithread.
"""
import pathlib
import subprocess
import sys
import time

RUN_TESTS = pathlib.Path(__file__).resolve().parents[3] / "run_tests.py"

if __name__ == "__main__":
    start = time.perf_counter()
    code = subprocess.call([sys.executable, str(RUN_TESTS), "--domain", "B_AU_SECURITE", *sys.argv[1:]])
    elapsed = time.perf_counter() - start
    minutes = int(elapsed // 60)
    seconds = elapsed % 60
    t_str = f"{minutes}m {seconds:.2f}s" if minutes > 0 else f"{seconds:.2f}s"
    try:
        print(f"\n⏱️  Duree totale domaine B_AU_SECURITE : {t_str}")
    except UnicodeEncodeError:
        print(f"\n[TIME] Duree totale domaine B_AU_SECURITE : {t_str}")
    sys.exit(code)
