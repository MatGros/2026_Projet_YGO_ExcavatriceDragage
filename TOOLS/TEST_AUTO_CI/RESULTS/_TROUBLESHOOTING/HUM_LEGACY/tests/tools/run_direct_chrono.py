#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Compilation g++ & Exécution du chronogramme C++ pour FB_Encoder_SpeedMeasure
"""

import os
import pathlib
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8')

ROOT_DIR = pathlib.Path(__file__).resolve().parents[4]
STRUC_EXE = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "strucpp.exe"
CONVERTER = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "convert_codesys_to_iec.py"
RUNTIME_INC = ROOT_DIR / "TOOLS" / "COMPILER_ST2C_STruCpp" / "bin" / "win32-x64" / "runtime" / "include"

SOURCE_ST = ROOT_DIR / "CODE" / "E_CODEURS" / "FB_Encoder_SpeedMeasure.st"
CHRONO_CPP = pathlib.Path(__file__).resolve().parent / "chrono_runner.cpp"

with tempfile.TemporaryDirectory(prefix="struc_gen_") as tmp:
    tmp_path = pathlib.Path(tmp)
    subprocess.run([sys.executable, str(CONVERTER), str(SOURCE_ST), "--out", str(tmp_path)], check=True)
    iec_source = tmp_path / "FB_Encoder_SpeedMeasure.st"

    # Transpilation STruCpp ST -> C++
    cmd_struc = [str(STRUC_EXE), str(iec_source), "-o", str(tmp_path / "generated.cpp")]
    subprocess.run(cmd_struc, check=True, cwd=str(tmp_path))

    # Compilation avec g++
    exe_out = tmp_path / "chrono.exe"
    cmd_gpp = [
        "g++", "-std=c++17", "-O2",
        f"-I{RUNTIME_INC}", f"-I{tmp_path}",
        str(CHRONO_CPP),
        str(tmp_path / "generated.cpp"),
        "-o", str(exe_out)
    ]
    subprocess.run(cmd_gpp, check=True)

    # Exécution du chronogramme avec encodage UTF-8
    res = subprocess.run([str(exe_out)], capture_output=True, encoding="utf-8", errors="replace")
    print(res.stdout)
