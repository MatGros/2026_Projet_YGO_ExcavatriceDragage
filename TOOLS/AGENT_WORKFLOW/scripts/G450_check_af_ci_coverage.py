#!/usr/bin/env python3
"""G450 — Traçabilité fraîche AF → fonctions → TC → titres TEST déclarés.

Informatif par défaut : les écarts de catalogue restent affichés sans bloquer les gates.
`--strict` les rend bloquants quand le catalogue sera assaini. Ce contrôle atteste une
présence déclarée dans un titre TEST d'un fichier du registry, jamais son exécution.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

from extract_functions_matrix import build_matrix

TITLE_RE = re.compile(r"TEST\s+'([^']*)'")
TC_RE = re.compile(r"TC-P(\d+)-(\d+)(?:/(\d+))?")


def ids_from_test_titles(text: str) -> set[str]:
    """Retourne les TC portés par les seuls titres TEST, y compris Pxx-001/002."""
    ids: set[str] = set()
    for title in TITLE_RE.findall(text):
        for part, first, second in TC_RE.findall(title):
            ids.add(f"TC-P{part}-{first}")
            if second:
                ids.add(f"TC-P{part}-{second}")
    return ids


def registry_test_ids(root: Path, registry: dict) -> tuple[set[str], dict[str, set[str]], list[str]]:
    tested: set[str] = set()
    ignored: dict[str, set[str]] = {}
    missing_paths: list[str] = []
    for registry_key, entry in registry.items():
        if not isinstance(entry, dict):
            continue
        for tc in entry.get("af_ignore", []):
            ignored.setdefault(tc, set()).add(registry_key)
        test = entry.get("test")
        if not test:
            continue
        path = root / test
        if not path.is_file():
            missing_paths.append(str(test))
            continue
        tested.update(ids_from_test_titles(path.read_text(encoding="utf-8")))
    return tested, ignored, missing_paths


def assess(matrix: dict, tested: set[str], ignored: dict[str, set[str]]) -> tuple[list[str], list[str], list[str]]:
    """Retourne (fonctions_sans_tc, tc_auto_absents, exceptions_af_ignore_visibles)."""
    no_tc: list[str] = []
    missing: list[str] = []
    exceptions: list[str] = []
    for af, domain in sorted(matrix.get("domains", {}).items()):
        points = domain.get("validation_points", {})
        for function_id, function in sorted(domain.get("functions", {}).items()):
            tc_ids = [tc for raw in function.get("tc_couvrants", []) for tc in TC_RE.findall(raw)]
            expanded = {f"TC-P{part}-{first}" for part, first, _second in tc_ids}
            expanded.update(f"TC-P{part}-{second}" for part, _first, second in tc_ids if second)
            if not expanded:
                no_tc.append(f"{af} {function_id}")
                continue
            for tc in sorted(expanded):
                typ = str(points.get(tc, {}).get("type", ""))
                if tc in tested or ("SITE" in typ and "AUTO" not in typ):
                    continue
                if tc in ignored:
                    producers = ", ".join(sorted(ignored[tc]))
                    exceptions.append(f"{af} {function_id} -> {tc} (af_ignore: {producers})")
                    continue
                # Sortie ASCII : le gate doit aussi fonctionner sur une console CP1252 Windows.
                missing.append(f"{af} {function_id} -> {tc}")
    return no_tc, missing, exceptions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", type=Path)
    parser.add_argument("--report", action="store_true", help="Affiche les écarts détaillés")
    parser.add_argument("--strict", action="store_true", help="Retourne 1 en présence d'écarts")
    args = parser.parse_args()
    root = args.root.resolve()
    registry_path = root / "TOOLS/TEST_AUTO_CI/registry.yaml"
    if not registry_path.is_file():
        print(f"ERROR: registre introuvable : {registry_path}")
        return 2
    matrix = build_matrix(root / "DOC/AF")
    registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or {}
    tested, ignored, missing_paths = registry_test_ids(root, registry)
    no_tc, missing, exceptions = assess(matrix, tested, ignored)
    function_count = sum(len(d.get("functions", {})) for d in matrix.get("domains", {}).values())
    print(f"G450 AF/CI : {function_count} fonctions, {len(tested)} TC déclarés dans TEST, "
          f"{len(no_tc)} sans TC, {len(missing)} TC AUTO absents")
    if args.report:
        for path in missing_paths:
            print(f"[WARN] Fichier test declare mais introuvable : {path}")
        for item in no_tc:
            print(f"[WARN] Fonction sans TC : {item}")
        for item in missing:
            print(f"[WARN] TC AUTO sans titre TEST : {item}")
        for item in exceptions:
            print(f"[WARN] Hors CI explicite : {item}")
    if args.strict and (no_tc or missing or missing_paths):
        print("FAIL: écarts AF/CI présents (--strict)")
        return 1
    print("PASS: contrôle informatif — présence déclarée uniquement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
