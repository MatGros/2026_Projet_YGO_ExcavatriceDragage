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
import os
import subprocess
import sys
import time
from pathlib import Path

# Assurer l'encodage UTF-8 sous console Windows pour les emojis et caractères spéciaux
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def run_stream(cmd: list[str], cwd: Path | None = None, stream: bool = True) -> tuple[int, str, str]:
    """Exécute une commande, avec flux détaillé ou capture compacte."""
    env = dict(os.environ)
    env["PYTHONUNBUFFERED"] = "1"
    p = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
        env=env,
    )
    lines: list[str] = []
    if p.stdout:
        for line in iter(p.stdout.readline, ""):
            if stream:
                sys.stdout.write(line)
                sys.stdout.flush()
            lines.append(line)
        p.stdout.close()
    code = p.wait()
    return code, "".join(lines), ""


def color_status(text: str, passed: bool) -> str:
    """Colore PASS/FAIL sur terminal interactif sans polluer les logs capturés."""
    if not sys.stdout.isatty():
        return text
    color = "\033[32m" if passed else "\033[31m"
    return f"{color}{text}\033[0m"


def failure_tail(output: str, limit: int = 30) -> str:
    """Dernières lignes utiles d'un gate rouge en mode compact."""
    lines = output.rstrip().splitlines()
    return "\n".join(lines[-limit:])


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
    ("C", "375", "G375 — Gate homme-mort mouvement (AF08 TC-P08-008)", [sys.executable, f"{S}/G375_check_deadman_arming_gate.py", "."]),
    ("C", "346", "G346 — Completude branches de mode PRG_03 (T168-C)", [sys.executable, f"{S}/G346_check_mode_branch_completeness.py", "."]),
    ("C", "347", "G347 — Type WORD sur la chaine OperatorActionId (T168-D)", [sys.executable, f"{S}/G347_check_actionid_type.py", "."]),
    ("A", "110", "G110 — Nommage IEC (NC-010 a NC-070, informatif)", [sys.executable, f"{S}/G110_check_naming_style.py", "CODE"]),
    ("A", "120", "G120 — Nommage DUT propriete d'un FB (NC-110, informatif)", [sys.executable, f"{S}/G120_check_fb_dut_naming.py", "."]),
    ("A", "127", "G127 — Completude gate neutralisation NOT Enable (informatif)", [sys.executable, f"{S}/G127_check_neutralization_completeness.py", "."]),
    ("C", "380", "G380 — Persistance config",                       [sys.executable, f"{S}/G380_check_config_persistence.py", "."]),
    ("C", "390", "G390 — Fraicheur bundle",                         [sys.executable, f"{S}/G390_check_bundle_freshness.py", "."]),
    ("C", "400", "G400 — Syntaxe ST du bundle (no terminator)",     [sys.executable, f"{S}/G400_check_bundle_st_syntax.py", "."]),
    ("C", "405", "G405 — Littéraux STRING ASCII (REX 2026-08-17)",   [sys.executable, f"{S}/G405_check_st_string_ascii.py", "."]),
    ("C", "410", "G410 — Invariants LD (tous les POU `_LD`, REX 2026-08-04/13)", [sys.executable, f"{S}/G410_check_ld_invariants.py", "."]),
    ("C", "420", "G420 — PyTest (gates + convertisseur)",           [str(_py313()), "-m", "pytest",
                                                                     "TOOLS/CONVERTER_ST2XML_PLCopenXML/tests",
                                                                     "TOOLS/AGENT_WORKFLOW/tests", "-q"]),
    ("C", "430", "G430 — Commentaires REX (Zéro journal intime, §2ter)", [sys.executable, f"{S}/G430_check_comments_rex.py", "."]),
    ("C", "440", "G440 — Skills agents (stub + canonique, anti-derive)", [sys.executable, f"{S}/check_skill_stubs.py", "."]),
    ("C", "450", "G450 — Couverture AF → TC → TEST_AUTO_CI (informatif)", [sys.executable, f"{S}/G450_check_af_ci_coverage.py", ".", "--report"]),
    ("C", "460", "G460 — Tests CI TEST_AUTO_CI (harnais STruCpp + négatifs + garde animation/fraîcheur, REX 2026-08-28)", [sys.executable, "TOOLS/TEST_AUTO_CI/anim_bench/run_ci_gates.py"]),
    # Palier D — sur demande (G500)
    ("D", "500", "G500 — Compilation CODESYS (log)",                [sys.executable, f"{S}/G500_check_codesys_compile.py"]),
]

PALIERS = {"A", "B", "C", "D"}
FILE_SCOPED_GATES = {"100", "110", "200"}


def gate_family(gate_id: str) -> str:
    """Famille quotidienne par centaine, lisible sans connaître les IDs unitaires."""
    families = {
        "1": "G100 — Qualité du bloc",
        "2": "G200 — Liaison & câblage",
        "3": "G300 — Structure, documentation & sécurité",
        "4": "G400 — Bundle, qualité source & CI",
        "5": "G500 — Compilation CODESYS",
    }
    if gate_id and gate_id[0] in families:
        return families[gate_id[0]]
    return "Contrôles complémentaires"


def grouped_plan(plan: list[tuple[str, str, str, list[str]]]) -> list[tuple[str, list[tuple[str, str, str, list[str]]]]]:
    """Regroupe les gates contiguës d'une même famille en préservant leur ordre d'exécution."""
    groups: list[tuple[str, list[tuple[str, str, str, list[str]]]]] = []
    for item in plan:
        family = gate_family(item[1])
        if groups and groups[-1][0] == family:
            groups[-1][1].append(item)
        else:
            groups.append((family, [item]))
    return groups


def select_plan(palier: str | None, with_pytest: bool = False, with_full_ci: bool = False) -> list[tuple[str, str, str, list[str]]]:
    if palier is None:
        plan = [g for g in PLANS if g[0] != "D"]
    else:
        palier = palier.upper()
        if palier not in PALIERS:
            raise SystemExit(f"ERROR: palier inconnu '{palier}' (attendu A/B/C/D)")
        plan = [g for g in PLANS if g[0] == palier]
    
    # Par défaut : G420 (PyTest infrastructure 530 tests) est opt-in via --pytest / --ci
    if not with_pytest:
        plan = [g for g in plan if g[1] != "420"]
    if not with_full_ci:
        plan = [g for g in plan if g[1] != "460"]
    return plan


def main() -> int:
    start_total_time = time.perf_counter()
    parser = argparse.ArgumentParser(description="Run project gates, par palier (A/B/C/D) ou tout")
    parser.add_argument("--palier", choices=sorted(PALIERS), help="Palier à exécuter (menu par intention, GUIDE_GATES_ET_TESTS_v1.2.md §2)")
    parser.add_argument("--codesys-log", type=Path, help="Log de compilation CODESYS (palier D)")
    parser.add_argument("--files", nargs="+", type=Path, help="Cibler un/des fichier(s) .st : seuls les gates applicables à un bloc isolé s'exécutent (G100, G110, G200)")
    parser.add_argument("--pytest", "--ci", dest="with_pytest", action="store_true", help="Inclure G420 PyTest (suite de 530 tests unitaires convertisseur + outillage)")
    parser.add_argument("--full-ci", action="store_true", help="Inclure G460 : harnais Cycle, négatifs et animation (lent, jalon/demande explicite)")
    parser.add_argument("--skip-codesys", action="store_true", help="Ne pas lancer G500 même si --codesys-log fourni")
    parser.add_argument("--strict", action="store_true", help="Fail on any warning")
    parser.add_argument("--fail-fast", action="store_true", help="S'arrêter au premier gate rouge")
    display_mode = parser.add_mutually_exclusive_group()
    display_mode.add_argument("--compact", dest="compact", action="store_true", default=True,
                              help="Résumé quotidien (défaut) : lancement + résultat/durée ; détail seulement sur FAIL")
    display_mode.add_argument("--verbose", dest="compact", action="store_false",
                              help="Diagnostic : restitue toute la sortie interne de chaque gate")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[3]

    file_mode = bool(args.files)
    skipped_global: list[tuple[str, str]] = []
    if file_mode:
        for f in args.files:
            if not f.is_file():
                print(f"ERROR: fichier introuvable : {f}", file=sys.stderr)
                return 2
        base_plan = select_plan(args.palier, with_pytest=args.with_pytest, with_full_ci=args.full_ci)
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
        plan = select_plan(args.palier, with_pytest=args.with_pytest, with_full_ci=args.full_ci)

    mode_label = "COMPACT" if args.compact else "DIAGNOSTIC VERBEUX"
    if file_mode:
        target_label = "FICHIER(S) " + " ".join(str(f) for f in args.files)
    else:
        target_label = f"PALIER {args.palier.upper()}" if args.palier else "TOUS LES PALIERS"
    print("\n" + "=" * 60, flush=True)
    print(f"🧪 GATES PROJET / MODE {mode_label} ACTIF", flush=True)
    print("=" * 60, flush=True)
    print(f"Cible : {target_label} · {len(plan)} gate(s) prévues", flush=True)
    print("Légende : ✅ PASS · ❌ FAIL · durée cumulée par famille", flush=True)

    results: list[tuple[str, bool, float]] = []
    failure_outputs: dict[str, str] = {}
    compact_results: list[tuple[str, bool, int, int, float]] = []

    def gate(idx: int, total: int, title: str, cmd: list[str]) -> bool:
        clean_title = title.encode("ascii", "replace").decode("ascii")
        if not args.compact:
            print("\n" + "=" * 60, flush=True)
            print(f"⏳ [{idx}/{total}] {clean_title} ...", flush=True)
            print("=" * 60, flush=True)
        t0 = time.perf_counter()
        code, out, _err = run_stream(cmd, project_root, stream=not args.compact)
        duration = time.perf_counter() - t0
        status_icon = "✅ PASS" if code == 0 else "❌ FAIL"
        if args.compact:
            if code != 0:
                failure_outputs[title] = out
        else:
            print(f"\n[{status_icon}] Durée gate : {duration:.2f}s", flush=True)
        results.append((title, code == 0, duration))
        return code == 0

    for gid, title in skipped_global:
        print("\n" + "=" * 60, flush=True)
        print(title, flush=True)
        print("=" * 60, flush=True)
        print(f"[--] Gate {gid} global : non applicable en mode --files (bloc isolé). S'exécutera sur le bundle complet (palier C).", flush=True)
        results.append((f"{title} [non applicable : gate global, bundle requis]", True, 0.0))

    d_plan = [g for g in plan if g[1] == "500"]
    if d_plan and not args.codesys_log and not args.skip_codesys:
        print("\n" + "=" * 60, flush=True)
        print("G500 — Compilation CODESYS (log)", flush=True)
        print("=" * 60, flush=True)
        print("Palier D = validation sur demande : fournir --codesys-log <build.log> pour exécuter G500.", flush=True)
        results.append(("G500 — Compilation CODESYS (log) [sauté : aucun log fourni]", True, 0.0))
        plan = [g for g in plan if g[1] != "500"]

    total_gates = len(plan)
    if args.compact:
        stopped = False
        for group_index, (family, group) in enumerate(grouped_plan(plan), 1):
            ids = ", ".join(f"G{item[1]}" for item in group)
            print(f"▶ [{group_index:02d}] {family} — {ids}", flush=True)
            group_start = time.perf_counter()
            before = len(results)
            for idx, (_, _id, title, cmd) in enumerate(group, before + 1):
                ok = gate(idx, total_gates, title, cmd)
                if not ok and args.fail_fast:
                    stopped = True
                    break
            group_results = results[before:]
            group_ok = all(ok for _title, ok, _duration in group_results)
            group_duration = time.perf_counter() - group_start
            compact_results.append((family, group_ok, sum(ok for _title, ok, _duration in group_results), len(group_results), group_duration))
            print(f"  {color_status('✅ PASS' if group_ok else '❌ FAIL', group_ok)}  "
                  f"{sum(ok for _title, ok, _duration in group_results)}/{len(group_results)} gates · {group_duration:.2f}s", flush=True)
            if not group_ok:
                for title, ok, _duration in group_results:
                    if not ok:
                        print(f"  └─ {title}", flush=True)
                        for line in failure_tail(failure_outputs.get(title, "")).splitlines():
                            print(f"     {line}", flush=True)
            if stopped:
                break
    else:
        for idx, (_, _id, title, cmd) in enumerate(plan, 1):
            ok = gate(idx, total_gates, title, cmd)
            if not ok and args.fail_fast:
                break

    if not args.skip_codesys and args.codesys_log and not d_plan:
        gate(total_gates + 1, total_gates + 1, "G500 — GATE 6: Compilation CODESYS", [
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
    if args.compact:
        for family, ok, passed, count, duration in compact_results:
            status_str = color_status("PASS" if ok else "FAIL", ok)
            print(f"  {status_str:4s}  [{duration:6.2f}s]  {family} ({passed}/{count})")
    else:
        for title, ok, dur in results:
            status_str = "PASS" if ok else "FAIL"
            print(f"  {color_status(status_str, ok):4s}  [{dur:6.2f}s]  {title}")
    
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
