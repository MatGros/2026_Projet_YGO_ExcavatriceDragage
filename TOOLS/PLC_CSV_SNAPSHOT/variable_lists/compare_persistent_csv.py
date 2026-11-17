#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compare deux releves CSV de persistantes (snapshot_persistent.py) — HORS CODESYS, lecture seule.

Usage :
  python compare_persistent_csv.py AVANT.csv APRES.csv
  python compare_persistent_csv.py                       # compare les 2 plus recents de DOC/WFLOW/MISE_EN_SERVICE/20261117_PERSISTANTES
  python compare_persistent_csv.py AVANT.csv APRES.csv --volatile   # liste a part les variables qui bougent en exploitation

Sortie : valeurs differentes, variables nouvelles / disparues, erreurs de lecture.
Code retour : 0 = aucun ecart bloquant, 1 = ecarts, 2 = erreur d'usage.
Ne se connecte a rien, n'ecrit aucun fichier.
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

DEFAULT_DIR = Path(__file__).resolve().parents[3] / "DOC" / "WFLOW" / "MISE_EN_SERVICE" / "20261117_PERSISTANTES"

# Variables qui evoluent normalement en exploitation (compteurs, position estimee, statistiques).
VOLATILE_PREFIXES = (
    "GVL_PERSISTENT._CycleSampleCount",
    "GVL_PERSISTENT._TranslationPosEstimated",
    "GVL_PERSISTENT._TranslationAt",
    "GVL_PERSISTENT._RunningHours",
    "GVL_PERSISTENT._WinchSymmetryDataPersist",
    "GVL_PERSISTENT._WinchSpeedLearnTable",
    "GVL_PERSISTENT._CalibM1.LastKnownRawPos",
    "GVL_PERSISTENT._CalibM2.LastKnownRawPos",
    "GVL_PERSISTENT._BucketState.LastPos",
)


def load(path: Path) -> dict[str, tuple[str, str]]:
    with path.open(encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f, delimiter=";"))
    return {r[0]: (r[1], r[2]) for r in rows[1:] if len(r) >= 3}


def is_error(value: str) -> bool:
    return value.startswith("ERREUR")


def is_volatile(name: str) -> bool:
    return name.startswith(VOLATILE_PREFIXES)


def numeric_equal(a: str, b: str) -> bool:
    try:
        return abs(float(a) - float(b)) < 1e-6
    except ValueError:
        return a == b


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("avant", nargs="?", type=Path)
    parser.add_argument("apres", nargs="?", type=Path)
    parser.add_argument("--volatile", action="store_true", help="separer les variables normalement mouvantes")
    args = parser.parse_args()

    if args.avant and args.apres:
        before_path, after_path = args.avant, args.apres
    elif not args.avant and not args.apres:
        files = sorted(DEFAULT_DIR.glob("Persistantes_*.csv"))
        if len(files) < 2:
            print(f"ERREUR : moins de 2 releves dans {DEFAULT_DIR}", file=sys.stderr)
            return 2
        before_path, after_path = files[-2], files[-1]
    else:
        print("ERREUR : donner 0 ou 2 fichiers", file=sys.stderr)
        return 2

    for p in (before_path, after_path):
        if not p.exists():
            print(f"ERREUR : fichier introuvable : {p}", file=sys.stderr)
            return 2

    a, b = load(before_path), load(after_path)
    print(f"AVANT : {before_path.name} ({len(a)} lignes)")
    print(f"APRES : {after_path.name} ({len(b)} lignes)")

    diffs, volatile_diffs = [], []
    for name in a:
        if name in b and not is_error(a[name][1]) and not is_error(b[name][1]):
            if not numeric_equal(a[name][1], b[name][1]):
                (volatile_diffs if args.volatile and is_volatile(name) else diffs).append((name, a[name][1], b[name][1]))

    new_ok = [n for n in b if n not in a and not is_error(b[n][1])]
    gone = [n for n in a if n not in b]
    became_error = [n for n in a if n in b and not is_error(a[n][1]) and is_error(b[n][1])]
    fixed = [n for n in a if n in b and is_error(a[n][1]) and not is_error(b[n][1])]
    still_error = [n for n in b if is_error(b[n][1]) and (n not in a or is_error(a[n][1]))]

    print(f"\nVALEURS DIFFERENTES : {len(diffs)}")
    for name, va, vb in diffs:
        print(f"  {name.replace('GVL_PERSISTENT.', '')} : {va} -> {vb}")
    if args.volatile:
        print(f"\nVALEURS DIFFERENTES MAIS NORMALEMENT MOUVANTES : {len(volatile_diffs)}")
        for name, va, vb in volatile_diffs:
            print(f"  {name.replace('GVL_PERSISTENT.', '')} : {va} -> {vb}")
    new_all = new_ok + fixed
    print(f"\nVARIABLES NOUVELLES (lues) : {len(new_all)}")
    if len(new_all) <= 15:
        for name in new_all:
            print(f"  {name.replace('GVL_PERSISTENT.', '')} = {b[name][1]}")
    else:  # beaucoup de lignes (ex. table d'apprentissage) : regrouper par variable de premier niveau
        groups: dict[str, int] = {}
        for name in new_all:
            top = name.replace("GVL_PERSISTENT.", "").split(".")[0].split("[")[0]
            groups[top] = groups.get(top, 0) + 1
        for top, count in groups.items():
            print(f"  {top} : {count} variable(s)")
    print(f"\nVARIABLES DISPARUES : {len(gone)}")
    for name in gone:
        print(f"  {name.replace('GVL_PERSISTENT.', '')}")
    print(f"\nDEVENUES ILLISIBLES : {len(became_error)}")
    for name in became_error:
        print(f"  {name.replace('GVL_PERSISTENT.', '')}")
    print(f"\nERREURS DE LECTURE (apres) : {len(still_error)}")
    for name in still_error[:15]:
        print(f"  {name.replace('GVL_PERSISTENT.', '')}")

    blocking = len(diffs) + len(gone) + len(became_error)
    print("\n=> " + ("AUCUN ECART BLOQUANT" if blocking == 0 else f"{blocking} ECART(S) A EXAMINER"))
    return 0 if blocking == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
