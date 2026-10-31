# -*- coding: utf-8 -*-
"""T423_TC00_probe_baseline — Lecture seule de l'état nominal du bandeau IHM.

A exécuter dans CODESYS : Tools > Scripting > Execute Script File...
"""

import os

ENGINE_PATH = os.path.join(os.path.dirname(__file__), "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())

online_app = get_online_app()
if online_app is not None:
    with online_app:
        print("\n>>> Demarrage T423_TC00_probe_baseline (Lecture seule) ...")
        banner = read_banner(online_app)
        print_banner("BASELINE BANDEAU IHM", banner)
        print("[OK] Baseline lue avec succes.")
