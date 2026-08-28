#!/usr/bin/env python3
"""Runner isolé des TESTS NÉGATIFS sur le code ORIGINAL CODE/G_CYCLE/FB_Cycle.st.

Exigence T3/T4 (plan T171) : prouver que le source historique CODE/ contient les défauts
F1 (X11 ouverture), F2 (SampleCount par scan) et F6 (reprise auto) — ces tests doivent
ÉCHOUER sur l'original. Ils sont EXCLUS de la suite verte (tests négatifs).

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/run_negative_tests.py
    python TOOLS/TEST_AUTO_CI/scripts/run_negative_tests.py --debug

Retour : 0 si les tests négatifs échouent comme attendu (preuve des défauts),
         1 si un test négatif passe (défaut absent → à signaler).
"""

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
RUNTIME_INCLUDE = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "test"

# Source ORIGINALE (lecture seule) — celle qui doit contenir les défauts
ORIGINAL_SOURCE = REPO_ROOT / "CODE" / "G_CYCLE" / "FB_Cycle.st"

# Fermeture de types complète de FB_Cycle (ordre = registry.yaml)
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

# Harnais de tests négatifs : chaque test DOIT échouer sur l'original
NEGATIVE_TEST_FILE = TEST_AUTO_CI / "WORKING_COPY" / "tests" / "test_fb_cycle_negative.st"


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


def _find_strucpp_temp_dir(before: set, tmp_root: pathlib.Path) -> pathlib.Path | None:
    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before
    if not new_dirs:
        return None
    return max(new_dirs, key=lambda p: p.stat().st_mtime)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    if not ORIGINAL_SOURCE.exists():
        print(f"[ERREUR] Source originale introuvable : {ORIGINAL_SOURCE}")
        return 1
    if not NEGATIVE_TEST_FILE.exists():
        print(f"[ERREUR] Harnais de tests négatifs introuvable : {NEGATIVE_TEST_FILE}")
        return 1

    _ensure_gpp_in_path()

    src_paths = [REPO_ROOT / s for s in SOURCES]
    tmp_root = TEST_AUTO_CI / ".tmp_neg"
    tmp_root.mkdir(parents=True, exist_ok=True)
    import uuid
    work_dir = tmp_root / f"run_{uuid.uuid4().hex[:8]}"
    work_dir.mkdir(parents=True, exist_ok=True)
    sys_tmp_root = pathlib.Path(tempfile.gettempdir())

    try:
        converted_dir = work_dir
        subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0

        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in src_paths], "--out", str(converted_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8",
                                creationflags=subproc_flags)
        if result.returncode != 0:
            print("[ERREUR] Conversion échouée")
            print(result.stderr)
            return 1

        converted_files = [str(converted_dir / s.name) for s in src_paths]
        out_cpp = converted_dir / "FB_Cycle.cpp"
        before = {p for p in sys_tmp_root.glob("strucpp-test-*") if p.is_dir()}

        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "-O", "0",
                       "--cxx-flags", "-O0 -pipe", "--test", str(NEGATIVE_TEST_FILE)]
        proc = subprocess.Popen(strucpp_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", cwd=str(converted_dir), bufsize=1,
                                creationflags=subproc_flags)
        lines = list(proc.stdout)
        proc.wait()
        text_report = "".join(lines)

        strucpp_temp_dir = _find_strucpp_temp_dir(before, sys_tmp_root)
        if strucpp_temp_dir is None:
            print("[ERREUR] Dossier temp STruCpp introuvable")
            if args.debug:
                print(text_report[-3000:])
            return 1

        # Compiler manuellement test_main.cpp + generated.cpp (le strucpp --test peut échouer
        # dans certains environnements à l'étape g++ interne, mais les fichiers sont générés).
        test_runner = strucpp_temp_dir / "test_runner.exe"
        if not test_runner.exists():
            manual_exe = strucpp_temp_dir / "manual_test.exe"
            compile_cmd = ["g++", "-std=c++17", "-O0",
                           f"-I{RUNTIME_INCLUDE}", f"-I{RUNTIME_TEST}", f"-I{strucpp_temp_dir}",
                           str(strucpp_temp_dir / "test_main.cpp"),
                           str(strucpp_temp_dir / "generated.cpp"),
                           "-o", str(manual_exe)]
            cresult = subprocess.run(compile_cmd, capture_output=True, text=True, encoding="utf-8",
                                     cwd=str(strucpp_temp_dir), creationflags=subproc_flags)
            if cresult.returncode != 0:
                print("[ERREUR] Compilation manuelle échouée")
                print(cresult.stderr[-2000:])
                return 1
            test_runner = manual_exe

        run_result = subprocess.run([str(test_runner), "--json"], capture_output=True,
                                    text=True, encoding="utf-8", creationflags=subproc_flags)
        import json
        try:
            data = json.loads(run_result.stdout)
        except json.JSONDecodeError:
            print("[ERREUR] Sortie JSON invalide")
            print(run_result.stdout[-2000:])
            return 1

        results = data.get("results", [])
        print(f"=== TESTS NÉGATIFS sur CODE/G_CYCLE/FB_Cycle.st (original) ===")
        print(f"Source : {ORIGINAL_SOURCE}")
        all_expected_fail = True
        for r in results:
            name = r.get("name", "")
            passed = r.get("passed", False)
            # Un test négatif DOIT échouer (passed=False) pour prouver le défaut
            status = "✅ ÉCHEC ATTENDU (défaut prouvé)" if not passed else "❌ PASSE (défaut absent!)"
            if passed:
                all_expected_fail = False
            print(f"  {status}  {name}")

        if all_expected_fail:
            print("\n✅ Tous les tests négatifs échouent comme attendu — défauts F1/F2/F6 prouvés sur l'original.")
            return 0
        else:
            print("\n❌ Au moins un test négatif PASSE — un défaut est absent de l'original (à signaler).")
            return 1
    finally:
        try:
            import shutil
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
