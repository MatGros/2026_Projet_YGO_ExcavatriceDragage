#!/usr/bin/env python3
"""Gate runner par palier (GUIDE_GATES_ET_TESTS_v1.2.md §2) — exécution par intention.

Menu par intention : l'agent CHOISIT le palier adapté à sa tâche du moment
(palier A = bloc isolé, B = liens, C = fin de lot, D = sur demande). Sans
--palier, on exécute tout (mode "fin de lot complet", comportement historique).

Un fichier unique (FB/fonction/POU) peut être ciblé avec --files : seuls les
gates applicables à un bloc isolé s'y appliquent (G100, G110, G200). Les gates
globaux (structure, bundle, liens doc...) sont signalés comme non applicables
en mode fichier — ils s'exécuteront sur le bundle complet (palier C).

Usage:
    python run_all_gates.py                       # tout (comportement historique)
    python run_all_gates.py --palier A            # bloc isolé : G100, G110 (rapide < 1s)
    python run_all_gates.py --palier B            # liens/dépendances : G200, G210
    python run_all_gates.py --palier C            # fin de lot : G300..G420
    python run_all_gates.py --palier D            # sur demande : G500 (avec --codesys-log)
    python run_all_gates.py --files CODE/08_TRANSLATION/FB_Translation.st
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


def run(cmd: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.returncode, r.stdout or "", r.stderr or ""


# ── Paliers (GUIDE_GATES_ET_TESTS_v1.2.md §2) — tranche d'ID par palier ──────────
S = "TOOLS/AGENT_WORKFLOW/scripts"


def _py313() -> str:
    py313 = Path("C:/Python313/python.exe")
    if not py313.exists():
        return sys.executable
    return str(py313)


PLANS: list[tuple[str, str, str, list[str]]] = [
    # Palier C — structure (G300..G330)
    ("C", "300", "G300 — Structure du depot",                       [sys.executable, f"{S}/G300_check_structure.py"]),
    ("C", "310", "G310 — Structure CODE (POU, suffixe, ordre)",     [sys.executable, f"{S}/G310_check_code_structure.py"]),
    ("C", "320", "G320 — Couverture MAIN du bundle",                [sys.executable, f"{S}/G320_check_bundle_main_coverage.py"]),
    ("C", "330", "G330 — Securite des types et membres STRUCT",     [sys.executable, f"{S}/G330_check_type_safety.py"]),
    # Palier A — bloc isolé (G100, G110)
    ("A", "100", "G100 — Code style (VAR_OUTPUT, simulation)",      [sys.executable, f"{S}/G100_check_code_style.py", "CODE"]),
    # Palier B — liens/dépendances (G200..G210)
    ("B", "200", "G200 — LIAISON (instances, refs, bundle)",        [sys.executable, f"{S}/G200_check_linkage.py"]),
    ("B", "210", "G210 — Cablage CFC natif",                        [sys.executable, f"{S}/G210_check_cfc_wiring.py"]),
    # Palier C — fin de lot (G340..G420)
    ("C", "340", "G340 — Liens documentaires",                      [sys.executable, f"{S}/G340_check_doc_links.py"]),
    ("C", "350", "G350 — Collision noms HW (REX 2026-08-05)",       [sys.executable, f"{S}/G350_check_hw_name_collision.py", "."]),
    ("C", "360", "G360 — Interlock changement de sens (REX 2026-08-05)", [sys.executable, f"{S}/G360_check_direction_change_interlock.py", "."]),
    ("C", "370", "G370 — Cablage position calibree (REX 2026-08-06)", [sys.executable, f"{S}/G370_check_position_calibration_wiring.py", "."]),
    ("A", "110", "G110 — Nommage IEC (NC-010 a NC-070, informatif)", [sys.executable, f"{S}/G110_check_naming_style.py", "CODE"]),
    ("C", "380", "G380 — Persistance config",                       [sys.executable, f"{S}/G380_check_config_persistence.py", "."]),
    ("C", "390", "G390 — Fraicheur bundle",                         [sys.executable, f"{S}/G390_check_bundle_freshness.py", "."]),
    ("C", "400", "G400 — Syntaxe ST du bundle (no terminator)",     [sys.executable, f"{S}/G400_check_bundle_st_syntax.py", "."]),
    ("C", "405", "G405 — Littéraux STRING ASCII (REX 2026-08-17)",   [sys.executable, f"{S}/G405_check_st_string_ascii.py", "."]),
    ("C", "410", "G410 — Invariants LD (tous les POU `_LD`, REX 2026-08-04/13)", [sys.executable, f"{S}/G410_check_ld_invariants.py", "."]),
    ("C", "420", "G420 — PyTest (gates + convertisseur)",           [str(_py313()), "-m", "pytest",
                                                                     "TOOLS/ST_PLCOPENXML_GENERATOR/tests",
                                                                     "TOOLS/AGENT_WORKFLOW/tests", "-q"]),
    # Palier D — sur demande (G500)
    ("D", "500", "G500 — Compilation CODESYS (log)",                [sys.executable, f"{S}/G500_check_codesys_compile.py"]),
]

PALIERS = {"A", "B", "C", "D"}
FILE_SCOPED_GATES = {"100", "110", "200"}


def select_plan(palier: str | None) -> list[tuple[str, str, str, list[str]]]:
    if palier is None:
        return [g for g in PLANS if g[0] != "D"]
    palier = palier.upper()
    if palier not in PALIERS:
        raise SystemExit(f"ERROR: palier inconnu '{palier}' (attendu A/B/C/D)")
    return [g for g in PLANS if g[0] == palier]


def main() -> int:
    start_total_time = time.perf_counter()
    parser = argparse.ArgumentParser(description="Run project gates, par palier (A/B/C/D) ou tout")
    parser.add_argument("--palier", choices=sorted(PALIERS), help="Palier à exécuter (menu par intention, GUIDE_GATES_ET_TESTS_v1.2.md §2)")
    parser.add_argument("--codesys-log", type=Path, help="Log de compilation CODESYS (palier D)")
    parser.add_argument("--files", nargs="+", type=Path, help="Cibler un/des fichier(s) .st : seuls les gates applicables à un bloc isolé s'exécutent (G100, G110, G200)")
    parser.add_argument("--skip-codesys", action="store_true", help="Ne pas lancer G500 même si --codesys-log fourni")
    parser.add_argument("--strict", action="store_true", help="Fail on any warning")
    parser.add_argument("--fail-fast", action="store_true", help="S'arrêter au premier gate rouge")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[3]

    file_mode = bool(args.files)
    skipped_global: list[tuple[str, str]] = []
    if file_mode:
        for f in args.files:
            if not f.is_file():
                print(f"ERROR: fichier introuvable : {f}", file=sys.stderr)
                return 2
        base_plan = select_plan(args.palier)
        plan = [g for g in base_plan if g[1] in FILE_SCOPED_GATES]
        skipped_global = [(g[1], g[2]) for g in base_plan if g[1] not in FILE_SCOPED_GATES]
        rebuilt: list[tuple[str, str, str, list[str]]] = []
        for pal, gid, title, cmd in plan:
            if gid in ("100", "110"):
                if len(args.files) == 1:
                    rebuilt.append((pal, gid, title, [sys.executable, f"{S}/{Path(cmd[1]).name}"] + [str(f) for f in args.files]))
                else:
                    for f in args.files:
                        rebuilt.append((pal, gid, f"{title} ({f.name})", [sys.executable, f"{S}/{Path(cmd[1]).name}", str(f)]))
            elif gid == "200":
                rebuilt.append((pal, gid, title, [sys.executable, f"{S}/G200_check_linkage.py", "--files"] + [str(f) for f in args.files]))
        for f in args.files:
            if f.name.endswith("_LD.st"):
                rebuilt.append(("A", "410x", f"LD convertible + invariants ({f.name})", [sys.executable, f"{S}/check_ld_file.py", str(f)]))
        plan = rebuilt
    else:
        plan = select_plan(args.palier)

    results: list[tuple[str, bool, float]] = []

    def gate(title: str, cmd: list[str]) -> bool:
        print("\n" + "=" * 60)
        print(title.encode("ascii", "replace").decode("ascii"))
        print("=" * 60)
        t0 = time.perf_counter()
        code, out, err = run(cmd, project_root)
        duration = time.perf_counter() - t0
        if out.strip():
            print(out.strip().encode("ascii", "replace").decode("ascii"))
        if err.strip():
            print(err.strip().encode("ascii", "replace").decode("ascii"), file=sys.stderr)
        print(f"[TEMPS] Durée gate : {duration:.2f}s")
        results.append((title, code == 0, duration))
        return code == 0

    for gid, title in skipped_global:
        print("\n" + "=" * 60)
        print(title)
        print("=" * 60)
        print(f"[--] Gate {gid} global : non applicable en mode --files (bloc isolé). S'exécutera sur le bundle complet (palier C).")
        results.append((f"{title} [non applicable : gate global, bundle requis]", True, 0.0))

    d_plan = [g for g in plan if g[1] == "500"]
    if d_plan and not args.codesys_log and not args.skip_codesys:
        print("\n" + "=" * 60)
        print("G500 — Compilation CODESYS (log)")
        print("=" * 60)
        print("Palier D = validation sur demande : fournir --codesys-log <build.log> pour exécuter G500.")
        results.append(("G500 — Compilation CODESYS (log) [sauté : aucun log fourni]", True, 0.0))
        plan = [g for g in plan if g[1] != "500"]

    for _, _id, title, cmd in plan:
        ok = gate(title, cmd)
        if not ok and args.fail_fast:
            break

    if not args.skip_codesys and args.codesys_log and not d_plan:
        gate("G500 — GATE 6: Compilation CODESYS", [
            sys.executable, f"{S}/G500_check_codesys_compile.py",
            "--log", str(args.codesys_log),
            "--max-warnings", "0" if args.strict else "10",
        ])

    total_duration = time.perf_counter() - start_total_time

    print("\n" + "=" * 60)
    if file_mode:
        label = "FICHIER(S) " + " ".join(str(f) for f in args.files)
    else:
        label = f"PALIER {args.palier.upper()}" if args.palier else "TOUT"
    print(f"RESUME — {label} (Temps total : {total_duration:.2f}s)")
    print("=" * 60)
    failed = [title for title, ok, _dur in results if not ok]
    for title, ok, dur in results:
        status_str = "PASS" if ok else "FAIL"
        print(f"  {status_str:4s}  [{dur:6.2f}s]  {title}")
    
    print("-" * 60)
    print(f"TEMPS TOTAL DE L'EXECUTION : {total_duration:.2f} secondes")
    
    if failed:
        print(f"\n[FAIL] {len(failed)} gate(s) en echec sur {len(results)} :")
        for title in failed:
            print(f"  - {title}")
        return 1
    print(f"\nALL GATES PASSED [OK] ({label})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
