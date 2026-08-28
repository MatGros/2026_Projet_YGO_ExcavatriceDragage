#!/usr/bin/env python3
"""Compile le moteur interactif FB_Cycle (T173) depuis WORKING_COPY (jamais CODE/).

Chaîne : convert_codesys_to_iec.py -> strucpp (generated.hpp/cpp) -> g++ (cycle_engine).

Usage :
    python TOOLS/TEST_AUTO_CI/anim_bench/build_cycle_engine.py
    python TOOLS/TEST_AUTO_CI/anim_bench/build_cycle_engine.py --out <exe>
"""

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
RUNTIME_INCLUDE = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "test"
ENGINE_CPP = TEST_AUTO_CI / "engine" / "cycle_engine.cpp"

SOURCES = [
    "CODE/A_COMMUN/_TYPES/E_State.st",
    "CODE/A_COMMUN/_TYPES/ST_Fault.st",
    "CODE/A_COMMUN/_TYPES/ST_FaultCause.st",
    "CODE/A_COMMUN/_TYPES/ST_Lifecycle.st",
    "CODE/A_COMMUN/FB_FaultCore.st",
    "CODE/F_MODES/E_Mode.st",
    "CODE/G_CYCLE/_TYPES/E_CycleStep.st",
    "CODE/G_CYCLE/_TYPES/E_OperatorAxis.st",
    "CODE/G_CYCLE/_TYPES/E_ProgramSequence.st",
    "CODE/H_TREUILS_BENNE/_TYPES/ST_fbCycle_WinchCmdDemand.st",
    "CODE/I_TRANSLATION/ST_fbCycle_TranslationCmdDemand.st",
    "CODE/H_TREUILS_BENNE/BENNE/_TYPES/ST_fbCycle_BucketCmdDemand.st",
    "CODE/G_CYCLE/FB_Cycle.st",
]


def _ensure_gpp_in_path() -> None:
    import shutil
    if shutil.which("g++"):
        return
    candidates = []
    local_appdata = __import__("os").environ.get("LOCALAPPDATA")
    if local_appdata:
        candidates += list(pathlib.Path(local_appdata).glob(
            "Microsoft/WinGet/Packages/BrechtSanders.WinLibs*/mingw64/bin/g++.exe"))
    for fixed in (r"C:\mingw64\bin\g++.exe", r"C:\msys64\mingw64\bin\g++.exe"):
        p = pathlib.Path(fixed)
        if p.exists():
            candidates.append(p)
    if not candidates:
        return
    bin_dir = str(candidates[0].parent)
    __import__("os").environ["PATH"] = bin_dir + __import__("os").pathsep + __import__("os").environ.get("PATH", "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(TEST_AUTO_CI / "engine" / "cycle_engine.exe"))
    args = parser.parse_args()

    _ensure_gpp_in_path()
    work_dir = TEST_AUTO_CI / ".tmp_engine"
    work_dir.mkdir(parents=True, exist_ok=True)
    subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0

    src_paths = [TEST_AUTO_CI / "WORKING_COPY" / s for s in SOURCES]
    for s in src_paths:
        if not s.exists():
            print(f"[ERREUR] Source introuvable : {s}")
            return 1

    # 1. Conversion ST -> IEC
    convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in src_paths], "--out", str(work_dir)]
    r = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8", creationflags=subproc_flags)
    if r.returncode != 0:
        print("[ERREUR] Conversion échouée")
        print(r.stderr[-2000:])
        return 1

    converted = [str(work_dir / s.name) for s in src_paths]
    out_cpp = work_dir / "FB_Cycle.cpp"

    # 2. strucpp -> generated.hpp/cpp (sans --test : pas de test_main.cpp)
    strucpp_cmd = [str(STRUCPP), *converted, "-o", str(out_cpp), "-O", "0", "--cxx-flags", "-O0 -pipe"]
    proc = subprocess.Popen(strucpp_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", cwd=str(work_dir), bufsize=1,
                            creationflags=subproc_flags)
    lines = list(proc.stdout)
    proc.wait()
    if proc.returncode != 0:
        print("[ERREUR] strucpp échoué")
        print("".join(lines)[-3000:])
        return 1

    gen_hpp = work_dir / "FB_Cycle.hpp"
    gen_cpp = work_dir / "FB_Cycle.cpp"
    if not gen_hpp.exists() or not gen_cpp.exists():
        print(f"[ERREUR] FB_Cycle.hpp/cpp introuvables dans {work_dir}")
        return 1

    # 3. g++ : cycle_engine.cpp + generated.cpp
    exe = pathlib.Path(args.out)
    exe.parent.mkdir(parents=True, exist_ok=True)
    gpp = "g++"
    compile_cmd = [gpp, "-std=c++17", "-O0",
                   f"-I{RUNTIME_INCLUDE}", f"-I{RUNTIME_TEST}", f"-I{work_dir}",
                   str(ENGINE_CPP), str(gen_cpp), "-o", str(exe)]
    c = subprocess.run(compile_cmd, capture_output=True, text=True, encoding="utf-8", creationflags=subproc_flags)
    if c.returncode != 0:
        print("[ERREUR] Compilation g++ échouée")
        print(c.stderr[-3000:])
        return 1

    print(f"✅ Moteur compilé : {exe}")
    print(f"   source = WORKING_COPY/FB_Cycle.st (jamais CODE/)")

    # Traçabilité (REX audit 2026-08-28) : manifest source/build pour prouver quel ST le binaire exécute
    try:
        import hashlib
        import datetime
        fb_src = TEST_AUTO_CI / "WORKING_COPY" / "CODE" / "G_CYCLE" / "FB_Cycle.st"
        with open(exe.parent / "build_manifest.json", "w", encoding="utf-8") as f:
            json.dump({
                "source_path": "WORKING_COPY/CODE/G_CYCLE/FB_Cycle.st",
                "source_sha256": hashlib.sha256(fb_src.read_bytes()).hexdigest() if fb_src.exists() else "?",
                "build_time": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
                "exe": exe.name,
            }, f, ensure_ascii=False, indent=2)
        print(f"   manifest : {exe.parent / 'build_manifest.json'}")
    except Exception as exc:
        print(f"[WARN] manifest non écrit : {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
