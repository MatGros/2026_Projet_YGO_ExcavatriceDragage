#!/usr/bin/env python3
"""Unified gate runner: all checks must pass before any commit or release."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all project gates")
    parser.add_argument("--codesys-log", type=Path, help="Optional CODESYS build log to validate")
    parser.add_argument("--skip-codesys", action="store_true", help="Skip CODESYS log check")
    parser.add_argument("--strict", action="store_true", help="Fail on any warning")
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="S'arreter au premier gate rouge (defaut : tout executer puis resumer)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[3]
    project_root = root

    # REX 2026-07-29 : le runner s'arretait au premier echec. Un seul gate rouge
    # preexistant masquait donc l'etat de TOUS les suivants — on ne savait plus si
    # la liaison, le bundle ou les tests passaient. On execute tout, on resume a la fin.
    results: list[tuple[str, bool]] = []

    def gate(title: str, cmd: list[str]) -> bool:
        print("\n" + "=" * 60)
        print(title)
        print("=" * 60)
        code, out, err = run(cmd, project_root)
        if out.strip():
            print(out.strip())
        if err.strip():
            print(err.strip(), file=sys.stderr)
        results.append((title, code == 0))
        return code == 0

    py313 = Path("C:/Python313/python.exe")
    if not py313.exists():
        print("WARNING: Python 3.13 introuvable, interpreteur courant utilise", file=sys.stderr)
        py313 = Path(sys.executable)

    S = "TOOLS/AGENT_WORKFLOW/scripts"
    plan: list[tuple[str, list[str]]] = [
        ("GATE 1: Structure",                          [sys.executable, f"{S}/check_structure.py"]),
        ("GATE 1bis: Structure CODE (POU, suffixe, ordre)", [sys.executable, f"{S}/check_code_structure.py"]),
        ("GATE 1ter: Couverture MAIN du bundle", [sys.executable, f"{S}/check_bundle_main_coverage.py"]),
        ("GATE 1quater: Securite des types et membres STRUCT", [sys.executable, f"{S}/check_type_safety.py"]),
        ("GATE 2: Code style (VAR_OUTPUT, simulation)", [sys.executable, f"{S}/check_code_style.py", "CODE"]),
        ("GATE 2bis: LIAISON (instances, refs, bundle)", [sys.executable, f"{S}/check_linkage.py"]),
        ("GATE 2bis-bis: Cablage CFC natif",           [sys.executable, f"{S}/check_cfc_wiring.py"]),
        ("GATE 2ter: Routage modele",                  [sys.executable, f"{S}/check_model_routing.py"]),
        ("GATE 2quater: Liens documentaires",          [sys.executable, f"{S}/check_doc_links.py"]),
        ("GATE 2quinquies: Collision noms HW (REX 2026-08-05)", [sys.executable, f"{S}/check_hw_name_collision.py", "."]),
        ("GATE 2sexies: Interlock changement de sens (REX 2026-08-05)", [sys.executable, f"{S}/check_direction_change_interlock.py", "."]),
        ("GATE 2septies: Cablage position calibree (REX 2026-08-06)", [sys.executable, f"{S}/check_position_calibration_wiring.py", "."]),
        ("GATE 3: Persistance config",                 [sys.executable, f"{S}/check_config_persistence.py", "."]),
        ("GATE 4: Fraicheur bundle",                   [sys.executable, f"{S}/check_bundle_freshness.py", "."]),
        ("GATE 4bis: Syntaxe ST du bundle (no terminator)", [sys.executable, f"{S}/check_bundle_st_syntax.py", "."]),
        ("GATE 4ter: Invariants LD PRG_06 (REX 2026-08-04)", [sys.executable, f"{S}/check_ld_invariants.py", "."]),
        ("GATE 5: PyTest",                             [str(py313), "-m", "pytest",
                                                        "TOOLS/ST_PLCOPENXML_GENERATOR/tests",
                                                        "TOOLS/AGENT_WORKFLOW/tests", "-q"]),
    ]

    for title, cmd in plan:
        ok = gate(title, cmd)
        if not ok and args.fail_fast:
            break

    if not args.skip_codesys and args.codesys_log:
        gate("GATE 6: Compilation CODESYS", [
            sys.executable, f"{S}/check_codesys_compile.py",
            "--log", str(args.codesys_log),
            "--max-warnings", "0" if args.strict else "10",
        ])

    print("\n" + "=" * 60)
    print("RESUME")
    print("=" * 60)
    failed = [title for title, ok in results if not ok]
    for title, ok in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {title}")
    if failed:
        print(f"\n{len(failed)} gate(s) en echec sur {len(results)} :")
        for title in failed:
            print(f"  - {title}")
        return 1
    print("\nALL GATES PASSED [OK]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
