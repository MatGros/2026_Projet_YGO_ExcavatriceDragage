# -*- coding: utf-8 -*-
"""Attend DELAY_SECONDS puis lance snapshot_troubleshooting.py.

Permet de lancer le script en console CODESYS, puis d'avoir le temps de se mettre en
situation sur la machine avant que le snapshot ne soit pris.
"""
import time

DELAY_SECONDS = 5
SCRIPT_PATH = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\codesys_console\codesys_snapshot_troubleshooting.py"

print("Snapshot dans " + str(DELAY_SECONDS) + " s...")
time.sleep(DELAY_SECONDS)
execfile(SCRIPT_PATH)
