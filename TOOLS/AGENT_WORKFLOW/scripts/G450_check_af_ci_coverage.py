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

REPO_ROOT = Path(__file__).resolve().parents[3]
CI_SCRIPTS = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "scripts"
sys.path.insert(0, str(CI_SCRIPTS))
from af_coverage_v2 import parse_af_catalog

TITLE_RE = re.compile(r"TEST\s+'([^']*)'")
TC_RE = re.compile(r"TC-P(\d+)-([A-Za-z0-9][A-Za-z0-9./-]*)")


def expand_tc_ids(text: str) -> set[str]:
    """IDs simples, groupes 004/009, scenarios et sous-cas."""
    ids: set[str] = set()
    for part, suffix in TC_RE.findall(text):
        suffix = suffix.rstrip(".,;:()")
        if re.fullmatch(r"\d+(?:/\d+)+", suffix):
            ids.update(f"TC-P{part}-{item}" for item in suffix.split("/"))
        else:
            ids.add(f"TC-P{part}-{suffix}")
    return ids


def ids_from_test_titles(text: str) -> set[str]:
    """Retourne les TC portés par les seuls titres TEST, y compris Pxx-001/002."""
    ids: set[str] = set()
    for title in TITLE_RE.findall(text):
        ids.update(expand_tc_ids(title))
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
            expanded = set().union(*(expand_tc_ids(raw) for raw in function.get("tc_couvrants", [])))
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


def assess_component(functions: dict, catalog: dict, tested: set[str], ignored: list) -> dict:
    """Croise, pour un FB, les fonctions AF, son catalogue et ses titres TEST."""
    linked: set[str] = set()
    functions_without_tc: list[str] = []
    for fid, function in sorted(functions.items()):
        ids = set().union(*(expand_tc_ids(raw) for raw in function.get("tc_couvrants", [])))
        if not ids:
            functions_without_tc.append(fid)
        linked.update(ids)
    catalog_ids = set(catalog)
    ignored_ids: set[str] = set()
    ignore_warnings: list[str] = []
    for item in ignored or []:
        if isinstance(item, str):
            ignored_ids.add(item)
            ignore_warnings.append(f"{item} (raison/scope manquants)")
        elif isinstance(item, dict) and item.get("id"):
            ignored_ids.add(str(item["id"]))
            if not item.get("reason") or not item.get("scope"):
                ignore_warnings.append(f"{item['id']} (raison ou scope manquant)")
    auto_ids = {tc for tc, row in catalog.items() if "AUTO" in str(row.get("type", "")).upper()}
    return {
        "functions_without_tc": functions_without_tc,
        "function_tc_missing_catalog": sorted(linked - catalog_ids),
        "catalog_tc_without_function": sorted(catalog_ids - linked),
        "auto_tc_missing_test": sorted((auto_ids - tested) - ignored_ids),
        "test_tc_missing_catalog": sorted(tc for tc in tested if tc not in catalog_ids and not tc.startswith("TC-P03-")),
        "ignore_warnings": ignore_warnings,
    }


def component_inputs(root: Path, entry: dict, matrix: dict):
    """AF est la source de verite ; la matrice YAML n'est jamais lue ici."""
    if not entry.get("af_doc") or not entry.get("test"):
        return None
    af_path, test_path = root / entry["af_doc"], root / entry["test"]
    if not af_path.is_file() or not test_path.is_file():
        return None
    catalog = {tc: {"type": typ, "intention": intent, "etat": state}
               for tc, typ, intent, state in parse_af_catalog(af_path.read_text(encoding="utf-8"))}
    prefixes = {match.group(1) for tc in catalog if (match := re.match(r"TC-P(\d+)-", tc))}
    if len(prefixes) != 1:
        return None
    functions = matrix.get("domains", {}).get(f"AF-{next(iter(prefixes))}", {}).get("functions", {})
    return functions, catalog, ids_from_test_titles(test_path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", type=Path)
    parser.add_argument("--report", action="store_true", help="Affiche les écarts détaillés")
    parser.add_argument("--strict", action="store_true", help="Retourne 1 en présence d'écarts")
    parser.add_argument("--fb", help="Limite le rapport a un FB du registry")
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
    entries = {args.fb: registry.get(args.fb)} if args.fb else registry
    component_errors = 0
    for fb_name, entry in sorted(entries.items()):
        if not isinstance(entry, dict):
            continue
        inputs = component_inputs(root, entry, matrix)
        if inputs is None:
            continue
        functions, catalog, component_tested = inputs
        result = assess_component(functions, catalog, component_tested, entry.get("af_ignore", []))
        count = sum(len(result[key]) for key in ("functions_without_tc", "function_tc_missing_catalog", "catalog_tc_without_function", "auto_tc_missing_test", "test_tc_missing_catalog"))
        component_errors += count
        print(f"G450 {fb_name} : {len(functions)} fonctions, {len(catalog)} TC AF, {len(component_tested)} TC TEST, {count} ecart(s)")
        if args.report:
            for key, label in (("functions_without_tc", "Fonction sans TC"), ("function_tc_missing_catalog", "TC fonction absent catalogue"), ("catalog_tc_without_function", "TC catalogue sans fonction"), ("auto_tc_missing_test", "TC AUTO sans TEST"), ("test_tc_missing_catalog", "TC TEST absent catalogue"), ("ignore_warnings", "af_ignore")):
                for item in result[key]:
                    print(f"[WARN] {fb_name} {label} : {item}")
    if args.strict and (no_tc or missing or missing_paths or component_errors):
        print("FAIL: écarts AF/CI présents (--strict)")
        return 1
    print("PASS: contrôle informatif — présence déclarée uniquement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
