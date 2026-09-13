#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test ad hoc T216 - Atomicite commande Both M1/M2 (criticite C4).

Compile FB_WinchCmdArbitrationM1 + FB_WinchCmdArbitrationM2 + leurs dependances
(types) et execute le test _TROUBLESHOOTING/tests/test_arb_cmd_both_atomic.st
via STruCpp. Meme pattern que run_minstepdown_test.py (dossier jetable SKILL §4ter).

Preuve des 5 tests de garde T216 :
  #1 Atomicite Both descente / #2 Both nominal / #3 Preservation unitaire
   #4 Soft-stop (aucun demarrage unilateral en Both).
"""
import pathlib
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8")

ROOT_DIR = pathlib.Path(__file__).resolve().parents[4]
STRUC_EXE = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "strucpp.exe"
CONVERTER = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "convert_codesys_to_iec.py"
OUT_DIR = pathlib.Path(__file__).resolve().parent / "arb_both_run"
TEST_ST = pathlib.Path(__file__).resolve().parent / "tests" / "test_arb_cmd_both_atomic.st"

# Sources des FB d'arbitrage + dependances transitives (types).
SOURCES = [
    "CODE/F_MODES/E_Mode.st",
    "CODE/A_COMMUN/_TYPES/ST_Fault.st",
    "CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st",
    "CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionJoystickQualified.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_Modes_Autorisations.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramWinchRequest.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_OperatorCoupledIntent.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_Context.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_IHM.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_Cfg.st",
    "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st",
    "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st",
]

OUT_DIR.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="struc_arb_") as tmp:
    tmp_path = pathlib.Path(tmp)
    combined = tmp_path / "ARB_ALL.st"
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
        converted = tmp_path / (src.stem + ".st")
        parts.append(f"(* ===== {rel} ===== *)\n" + converted.read_text(encoding="utf-8"))
    combined.write_text("\n".join(parts), encoding="utf-8")

    out_cpp = OUT_DIR / "ARB_Both_trb.cpp"
    cmd = [
        str(STRUC_EXE),
        str(combined),
        "-o", str(out_cpp),
        "-O", "0",
        "--cxx-flags", "-O0 -pipe",
        "--test", str(TEST_ST),
    ]
    print("Compilation + execution STruCpp (atomicite Both M1/M2) ...")
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=str(tmp_path))
    print(res.stdout[-12000:] if res.stdout else "(pas de stdout)")
    if res.stderr:
        print("STDERR:", res.stderr[-4000:])
    sys.exit(res.returncode)
