#!/usr/bin/env python3
"""Runner unifié des tests FB_Cycle sur la COPIE DE TRAVAIL (WORKING_COPY).

Valide RÉELLEMENT les assertions : parse le JSON de test et échoue si une assertion échoue.
Contrairement à strucpp --test (qui échoue à l'étape g++ interne dans certains environnements),
ce runner compile manuellement test_main.cpp + generated.cpp avec g++ puis exécute.

Preuve qualifiée : « C++ généré par STruCpp, compilé/exécuté manuellement par g++ » — PAS
« test STruCpp PASS » (strucpp --test ne retourne pas 0 ici).

⚠️ CONVENTION VAR_IN_OUT (REX 2026-08-28, TC-P04-105) : le codegen STruCpp génère les
VAR_IN_OUT en COPY-IN SEUL (`s.FB.X = s.X;` avant l'appel, pas de copy-out), alors que
CODESYS 3.5 passe le IN_OUT par référence. Toute variable IN_OUT lue sur PLUSIEURS scans
consécutifs doit donc être resynchronisée dans le test après chaque appel susceptible de
la modifier : `X := FB.X;` (émulation copy-out). Sans cela, le copy-in du scan suivant
ré-écrase la valeur incrémentée par le FB avec la locale périmée — artefact harnais,
PAS un bug du FB. Voir test_fb_cycle_full.st / TC-P04-105 (SampleCount).

Usage :
    python TOOLS/TEST_AUTO_CI/anim_bench/run_cycle_tests.py            # copie corrigée
    python TOOLS/TEST_AUTO_CI/anim_bench/run_cycle_tests.py --original # CODE/ original
    python TOOLS/TEST_AUTO_CI/anim_bench/run_cycle_tests.py --negative # tests négatifs sur original
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

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
if str(COMPILER_DIR) not in sys.path:
    sys.path.insert(0, str(COMPILER_DIR))
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
RUNTIME_INCLUDE = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "include"
RUNTIME_TEST = COMPILER_DIR / "bin" / "win32-x64" / "runtime" / "test"

import inject_var_in_out_copyout

WORKING_COPY = TEST_AUTO_CI / "WORKING_COPY"
FULL_TEST = WORKING_COPY / "tests" / "test_fb_cycle_full.st"
NEGATIVE_TEST = WORKING_COPY / "tests" / "test_fb_cycle_negative.st"

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
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramWinchRequest.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramTranslationRequest.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramBucketRequest.st",
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


def _find_new_strucpp_dir(before: set, tmp_root: pathlib.Path) -> pathlib.Path | None:
    after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
    new_dirs = after - before
    if not new_dirs:
        return None
    return max(new_dirs, key=lambda p: p.stat().st_mtime)


def run_tests(src_root: pathlib.Path, test_file: pathlib.Path, label: str) -> int:
    """Compile et exécute les tests. Retourne 0 si toutes les assertions passent."""
    _ensure_gpp_in_path()
    src_paths = [src_root / s for s in SOURCES]
    tmp_root = TEST_AUTO_CI / ".tmp_run"
    tmp_root.mkdir(parents=True, exist_ok=True)
    import uuid
    work_dir = tmp_root / f"run_{uuid.uuid4().hex[:8]}"
    work_dir.mkdir(parents=True, exist_ok=True)
    sys_tmp_root = pathlib.Path(tempfile.gettempdir())
    subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0

    try:
        # 1. Conversion ST -> IEC
        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in src_paths], "--out", str(work_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True, encoding="utf-8",
                                creationflags=subproc_flags)
        if result.returncode != 0:
            print(f"[ERREUR] Conversion échouée ({label})")
            print(result.stderr[-2000:])
            return 1

        converted_files = [str(work_dir / s.name) for s in src_paths]
        out_cpp = work_dir / "FB_Cycle.cpp"
        before = {p for p in sys_tmp_root.glob("strucpp-test-*") if p.is_dir()}

        # 2. strucpp --test (génère test_main.cpp ; peut échouer à l'étape g++ interne)
        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "-O", "0",
                       "--cxx-flags", "-O0 -pipe", "--test", str(test_file)]
        proc = subprocess.Popen(strucpp_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", cwd=str(work_dir), bufsize=1,
                                creationflags=subproc_flags)
        lines = list(proc.stdout)
        proc.wait()
        strucpp_rc = proc.returncode

        strucpp_dir = _find_new_strucpp_dir(before, sys_tmp_root)
        if strucpp_dir is None:
            print(f"[ERREUR] Dossier temp STruCpp introuvable ({label})")
            return 1

        # 2bis. T181-21 : post-traitement VAR_IN_OUT (copy-out) sur test_main.cpp.
        # STruCpp ne genere qu'un copy-in (s.FB.X = s.X;) sans copy-out. On injecte
        # le copy-out des VAR_IN_OUT du FB testé apres chaque appel, avant la
        # compilation manuelle g++ ci-dessous. Mapping sans ambiguïté (ligne de
        # copy-in s.FB.X = s.Y;). No-op si le FB n'a pas de VAR_IN_OUT.
        fb_st_path = next((src_root / s for s in SOURCES if pathlib.Path(s).name == "FB_Cycle.st"), None)
        if fb_st_path is not None:
            try:
                inject_var_in_out_copyout.postprocess_file(
                    strucpp_dir / "test_main.cpp", fb_st_path, fb_var="FB")
            except Exception as exc:
                print(f"[var_in_out] post-traitement indisponible : {exc}")

        # 3. Compilation manuelle g++ (test_main.cpp + generated.cpp)
        exe = strucpp_dir / "manual_test.exe"
        compile_cmd = ["g++", "-std=c++17", "-O0",
                       f"-I{RUNTIME_INCLUDE}", f"-I{RUNTIME_TEST}", f"-I{strucpp_dir}",
                       str(strucpp_dir / "test_main.cpp"), str(strucpp_dir / "generated.cpp"),
                       "-o", str(exe)]
        cresult = subprocess.run(compile_cmd, capture_output=True, text=True, encoding="utf-8",
                                 cwd=str(strucpp_dir), creationflags=subproc_flags)
        if cresult.returncode != 0:
            print(f"[ERREUR] Compilation manuelle échouée ({label})")
            print(cresult.stderr[-2000:])
            return 1

        # 4. Exécution + parse JSON
        run_result = subprocess.run([str(exe), "--json"], capture_output=True,
                                    text=True, encoding="utf-8", creationflags=subproc_flags)
        try:
            data = json.loads(run_result.stdout)
        except json.JSONDecodeError:
            print(f"[ERREUR] Sortie JSON invalide ({label})")
            print(run_result.stdout[-2000:])
            return 1

        results = data.get("results", [])
        n_pass = sum(1 for r in results if r.get("passed"))
        n_total = len(results)
        print(f"=== {label} ===")
        print(f"Source : {src_root / 'CODE/G_CYCLE/FB_Cycle.st'}")
        print(f"Preuve : C++ généré par STruCpp, compilé/exécuté manuellement par g++ "
              f"(strucpp --test RC={strucpp_rc})")
        for r in results:
            name = r.get("name", "")
            passed = r.get("passed", False)
            detail = r.get("failure", {}).get("detail", "") if not passed else ""
            print(f"  {'✅' if passed else '❌'}  {name[:70]}" + (f"  | {detail[:80]}" if detail else ""))
        print(f"Résultat : {n_pass}/{n_total} PASS")

        if n_pass == n_total:
            print(f"✅ {label} : toutes les assertions passent")
            return 0
        print(f"❌ {label} : {n_total - n_pass} assertion(s) échouée(s)")
        return 1
    finally:
        try:
            import shutil
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", action="store_true",
                        help="Tester CODE/ original (au lieu de WORKING_COPY)")
    parser.add_argument("--negative", action="store_true",
                        help="Utiliser le harnais de tests négatifs (NEG-F1/F2/F6)")
    args = parser.parse_args()

    if args.original:
        src_root = REPO_ROOT  # CODE/ original
    else:
        src_root = WORKING_COPY

    if args.negative:
        test_file = NEGATIVE_TEST
        label = "TESTS NÉGATIFS (doivent échouer sur original)"
    else:
        test_file = FULL_TEST
        label = "HARNAIS COMPLET (TC-P04-100..105)"

    return run_tests(src_root, test_file, label)


if __name__ == "__main__":
    sys.exit(main())
