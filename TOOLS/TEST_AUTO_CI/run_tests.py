#!/usr/bin/env python3
"""Runner de tests automatises pour FB CODESYS, base sur registry.yaml (source unique des
dependances -- jamais devinees a la volee). Pipeline par FB :

    sources (registry.yaml) --[moulinette COMPILER_ST2C_STruCpp]--> .st IEC standard
                             --[strucpp.exe --test]--> compile C++ + execute les ASSERT

Usage :
    python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_Joystick
    python TOOLS/TEST_AUTO_CI/run_tests.py --all

Necessite g++ (MinGW-w64) dans le PATH -- voir TOOLS/COMPILER_ST2C_STruCpp/README.md.
"""

import argparse
import datetime as _dt
import pathlib
import subprocess
import sys
import tempfile

import yaml

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"
REGISTRY = TEST_AUTO_CI / "registry.yaml"


def load_registry() -> dict:
    return yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))


def run_one(fb_name: str, entry: dict) -> bool:
    domain = entry["domain"]
    sources = [REPO_ROOT / p for p in entry["sources"]]
    test_file = REPO_ROOT / entry["test"]

    print(f"\n=== {fb_name} (domaine {domain}) ===")

    with tempfile.TemporaryDirectory(prefix=f"st2c_{fb_name}_") as tmp:
        converted_dir = pathlib.Path(tmp)
        convert_cmd = [sys.executable, str(CONVERTER), *[str(s) for s in sources], "--out", str(converted_dir)]
        result = subprocess.run(convert_cmd, capture_output=True, text=True)
        print(result.stdout)
        if result.returncode != 0:
            print(result.stderr, file=sys.stderr)
            print(f"[ERREUR] Conversion echouee pour {fb_name}")
            return False

        converted_files = [str(converted_dir / s.name) for s in sources]
        out_cpp = converted_dir / f"{fb_name}.cpp"
        strucpp_cmd = [str(STRUCPP), *converted_files, "-o", str(out_cpp), "--test", str(test_file)]
        result = subprocess.run(strucpp_cmd, capture_output=True, text=True, cwd=str(converted_dir))
        report = result.stdout + result.stderr
        print(report)

        reports_dir = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / domain / "reports"
        reports_dir.mkdir(parents=True, exist_ok=True)
        timestamp = _dt.datetime.now().strftime("%Y%m%d_%H%M%S")
        status = "PASS" if result.returncode == 0 else "FAIL"
        report_path = reports_dir / f"{fb_name}_{timestamp}_{status}.txt"
        report_path.write_text(report, encoding="utf-8")
        print(f"Rapport : {report_path}")

        return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--fb", help="Nom du FB a tester (cle du registry.yaml)")
    group.add_argument("--all", action="store_true", help="Tester tous les FB du registre")
    args = parser.parse_args()

    if not STRUCPP.exists():
        print(f"[ERREUR] strucpp.exe introuvable : {STRUCPP}")
        return 1

    registry = load_registry()

    if args.fb:
        if args.fb not in registry:
            print(f"[ERREUR] '{args.fb}' absent de {REGISTRY} -- entrees disponibles : {', '.join(registry)}")
            return 1
        ok = run_one(args.fb, registry[args.fb])
        results = {args.fb: ok}
    else:
        results = {name: run_one(name, entry) for name, entry in registry.items()}

    print("\n=== RESUME ===")
    for name, ok in results.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    n_fail = sum(1 for ok in results.values() if not ok)
    print(f"{len(results)} FB testes, {len(results) - n_fail} PASS, {n_fail} FAIL")

    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
