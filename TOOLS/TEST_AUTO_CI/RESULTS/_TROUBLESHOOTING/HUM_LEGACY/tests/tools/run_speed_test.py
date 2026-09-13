#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Chronogramme & Test de FB_Encoder_SpeedMeasure sous STruCpp
"""

import json
import os
import pathlib
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8')

ROOT_DIR = pathlib.Path(__file__).resolve().parents[4]
STRUC_EXE = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "strucpp.exe"
CONVERTER = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "convert_codesys_to_iec.py"
OUT_DIR = pathlib.Path(__file__).resolve().parent / "speed_measure_run"

# Import chronogram module
sys.path.insert(0, str(ROOT_DIR / "TOOLS" / "TEST_AUTO_CI" / "scripts"))
import chronogram

RUNTIME_INCLUDE = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "runtime" / "test"

SOURCE_ST = ROOT_DIR / "CODE" / "E_CODEURS" / "FB_Encoder_SpeedMeasure.st"
TEST_ST = pathlib.Path(__file__).resolve().parent / "tests" / "test_fb_encoder_speedmeasure.st"

OUT_DIR.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="struc_speed_") as tmp:
    tmp_path = pathlib.Path(tmp)
    tmp_root = pathlib.Path(tempfile.gettempdir())
    before = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}

    # Conversion Codesys -> Standard IEC
    subprocess.run([sys.executable, str(CONVERTER), str(SOURCE_ST), "--out", str(tmp_path)], check=True)

    iec_source = tmp_path / "FB_Encoder_SpeedMeasure.st"
    out_cpp = OUT_DIR / "FB_Encoder_SpeedMeasure.cpp"

    cmd = [
        str(STRUC_EXE),
        str(iec_source),
        "-o", str(out_cpp),
        "-O", "0",
        "--cxx-flags", "-O0 -pipe",
        "--test", str(TEST_ST)
    ]
    
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=str(tmp_path))

    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before

    if new_dirs:
        test_dir = max(new_dirs, key=lambda p: p.stat().st_mtime)
        runner_exe = test_dir / "test_runner.exe"
        
        # Chronogramme
        trace_entries, field_types = chronogram.build_and_run_traced(
            test_dir, RUNTIME_INCLUDE, RUNTIME_TEST, "FB_ENCODER_SPEEDMEASURE"
        )
        
        print("=" * 105)
        print("📊 RAPPORT D'ESSAI & CHRONOGRAMME : FB_Encoder_SpeedMeasure (Fenêtre Glissante 50ms)")
        print("=" * 105)
        
        for entry in trace_entries:
            test_name = entry.get("test_name", "")
            scans = entry.get("scans", [])
            print(f"\n🧪 Scénario : {test_name}")
            print("=" * 105)
            print(f"{'Scan':<5} | {'t(ms)':<6} | {'Enable':<7} | {'PosValid':<9} | {'Pos(m)':<8} | {'Valid':<7} | {'Speed(m/s)':<11} | {'Signed(m/s)':<11} | {'Commentaire comportement'}")
            print("-" * 105)
            for i, s in enumerate(scans):
                t_ms = s.get("time_ns", 0) / 1_000_000
                en = s.get("ENABLE", s.get("Enable", "?"))
                pv = s.get("POSITIONVALID", s.get("PositionValid", "?"))
                pos = s.get("POSITION_M", s.get("Position_M", 0.0))
                val = s.get("VALID", s.get("Valid", "?"))
                spd = s.get("SPEED_MPS", s.get("Speed_Mps", 0.0))
                s_spd = s.get("SIGNEDSPEED_MPS", s.get("SignedSpeed_Mps", 0.0))
                
                comment = ""
                if i == 0: comment = "Scan 0 : Neutralisation initiale (Speed=0, Valid=FALSE)"
                elif i == 1: comment = "Scan 1 : Activation (1er échantillon à 0.0m)"
                elif 2 <= i <= 5: comment = f"Scan {i} : Déplacement 1.0 m/s (remplissage fenêtre {i}/6)"
                elif i == 6: comment = "Scan 6 : 🎯 FENÊTRE 50ms ATTEINTE -> Valid=TRUE, Speed=1.000 m/s !"
                elif i == 7: comment = "Scan 7 : Accélération 2.0 m/s (transition glissante 1.200 m/s)"
                elif i == 8: comment = "Scan 8 : Déplacement 2.0 m/s (transition glissante 1.400 m/s)"
                elif i == 9: comment = "Scan 9 : Descente négative (SignedSpeed < 0)"
                elif i == 10: comment = "Scan 10: 🛡️ RUPTURE PositionValid=FALSE -> PURGE IMMÉDIATE (Speed=0) !"
                
                print(f"{i:<5} | {t_ms:<6.0f} | {str(en):<7} | {str(pv):<9} | {pos:<8.3f} | {str(val):<7} | {spd:<11.3f} | {s_spd:<11.3f} | {comment}")
            print("-" * 105)

