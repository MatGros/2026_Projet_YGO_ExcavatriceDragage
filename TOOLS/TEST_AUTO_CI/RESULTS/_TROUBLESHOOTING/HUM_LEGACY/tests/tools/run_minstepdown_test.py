#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test ad hoc troubleshooting — FB_Winch / plancher MinStepDown vs permis descente
Fiche : DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TreuilM2_LimiteDescente_20260901.md

Compile FB_Winch + ses dépendances (sources registry.yaml) et exécute le test
_TROUBLESHOOTING/tests/test_fb_winch_minstepdown.st. Dossier jetable (SKILL §4ter).
"""

import pathlib
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

ROOT_DIR = pathlib.Path(__file__).resolve().parents[4]
STRUC_EXE = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "strucpp.exe"
CONVERTER = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "convert_codesys_to_iec.py"
OUT_DIR = pathlib.Path(__file__).resolve().parent / "minstepdown_run"
TEST_ST = pathlib.Path(__file__).resolve().parent / "tests" / "test_fb_winch_minstepdown.st"

# Sources FB_Winch (copiées du registry.yaml, entrée FB_Winch)
SOURCES = [
    "CODE/A_COMMUN/_TYPES/E_State.st",
    "CODE/A_COMMUN/_TYPES/ST_Fault.st",
    "CODE/A_COMMUN/_TYPES/ST_FaultCause.st",
    "CODE/A_COMMUN/_TYPES/ST_ContactorCheck.st",
    "CODE/A_COMMUN/FB_FaultCore.st",
    "CODE/A_COMMUN/FB_CycleTime.st",
    "CODE/A_COMMUN/FB_Brake.st",
    "CODE/F_MODES/E_Mode.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_SpeedStepTable.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinch_DriveRequest.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinch_Sensors.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinch_Cfg.st",
    "CODE/H_TREUILS_BENNE/_TYPES/E_WinchFinalInterlockReason.st",
    "CODE/H_TREUILS_BENNE/_TYPES/E_WinchFinalInterlockState.st",
    "CODE/H_TREUILS_BENNE/FB_SpeedStep.st",
    "CODE/H_TREUILS_BENNE/FB_DriftGuard.st",
    "CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st",
    "CODE/H_TREUILS_BENNE/FB_Safety_Winch.st",
    "CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st",
    "CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st",
    "CODE/H_TREUILS_BENNE/FB_Winch.st",
]

OUT_DIR.mkdir(parents=True, exist_ok=True)

# Concaténer toutes les sources converties en un seul .st IEC
import tempfile
with tempfile.TemporaryDirectory(prefix="struc_trb_") as tmp:
    tmp_path = pathlib.Path(tmp)
    combined = tmp_path / "FB_ALL.st"
    parts = []
    for rel in SOURCES:
        src = ROOT_DIR / rel
        if not src.exists():
            print(f"ERREUR: source manquante {src}")
            sys.exit(2)
        res = subprocess.run(
            [sys.executable, str(CONVERTER), str(src), "--out", str(tmp_path)],
            capture_output=True, text=True)
        if res.returncode != 0:
            print(f"ERREUR conversion {rel}:\n{res.stdout}\n{res.stderr}")
            sys.exit(2)
        # le converteur écrit <nom>.st dans tmp_path
        converted = tmp_path / (src.stem + ".st")
        parts.append(f"(* ===== {rel} ===== *)\n" + converted.read_text(encoding="utf-8"))
    combined.write_text("\n".join(parts), encoding="utf-8")

    out_cpp = OUT_DIR / "FB_Winch_trb.cpp"
    cmd = [
        str(STRUC_EXE),
        str(combined),
        "-o", str(out_cpp),
        "-O", "0",
        "--cxx-flags", "-O0 -pipe",
        "--test", str(TEST_ST),
    ]
    print("Compilation + exécution STruCpp ...")
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=str(tmp_path))
    print(res.stdout[-8000:] if res.stdout else "(pas de stdout)")
    if res.stderr:
        print("STDERR:", res.stderr[-3000:])
    sys.exit(res.returncode)
