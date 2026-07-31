#!/usr/bin/env python3
"""Gate de tracabilite : verifie que TEST_REGISTRY.md et les tests reels concordent.

Classe de dette couverte (REX 2026-08) : des dizaines de tests s'accumulent dans
out/ et tests/ sans registre de ce qui est teste, pour quelle fonction, avec quel
identifiant de cas critique (TC-*). Impossible de savoir si une fonction a perdu
sa couverture de non-regression lors d'une evolution.

Controles :
  R1  chaque test reference dans TEST_REGISTRY.md existe reellement (fichier::fonction)
  R2  chaque `def test_*` present dans tests/contracts/ est reference dans le registre
  R3  aucun out/st2py-test-* residuel (dossiers de scratch jamais nettoyes)

Usage :
  python TOOLS/OUTILS_ST2PY/check_test_registry.py
  python TOOLS/OUTILS_ST2PY/check_test_registry.py --report
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REGISTRY_LINE = re.compile(
    r"`tests/(?P<relpath>[\w/]+\.py)::(?P<funcname>test_\w+)`"
)
TEST_DEF = re.compile(r"^def (test_\w+)\s*\(", re.MULTILINE)


def load_registry_references(registry_path: Path) -> set[tuple[str, str]]:
    text = registry_path.read_text(encoding="utf-8")
    return {(m.group("relpath"), m.group("funcname")) for m in REGISTRY_LINE.finditer(text)}


def load_actual_tests(tests_dir: Path, subfolder: str) -> set[tuple[str, str]]:
    out: set[tuple[str, str]] = set()
    folder = tests_dir / subfolder
    if not folder.is_dir():
        return out
    for path in sorted(folder.glob("test_*.py")):
        text = path.read_text(encoding="utf-8")
        rel = f"{subfolder}/{path.name}"
        for m in TEST_DEF.finditer(text):
            out.add((rel, m.group(1)))
    return out


def find_stale_scratch_dirs(out_dir: Path) -> list[Path]:
    if not out_dir.is_dir():
        return []
    return sorted(p for p in out_dir.iterdir() if p.is_dir() and p.name.startswith("st2py-test-"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--report", action="store_true", help="Afficher le bloc de restitution agent")
    args = parser.parse_args()

    root = args.root.resolve()
    registry_path = root / "TEST_REGISTRY.md"
    tests_dir = root / "tests"
    out_dir = root / "out"

    if not registry_path.is_file():
        print(f"[ERROR] registre introuvable : {registry_path}", file=sys.stderr)
        return 2

    registry_refs = load_registry_references(registry_path)
    # Seul tests/contracts/ porte des fonctions metier tracables par TC-*.
    # tests/generation/ et tests/simulation/ sont de l'outillage (AUTO), aussi tracables.
    actual_contracts = load_actual_tests(tests_dir, "contracts")
    actual_generation = load_actual_tests(tests_dir, "generation")
    actual_simulation = load_actual_tests(tests_dir, "simulation")
    actual_all = actual_contracts | actual_generation | actual_simulation

    errors: list[str] = []
    warnings: list[str] = []

    # R1 — chaque reference du registre existe reellement
    missing_in_code = registry_refs - actual_all
    for relpath, funcname in sorted(missing_in_code):
        errors.append(f"[R1] TEST_REGISTRY.md reference `{relpath}::{funcname}` introuvable dans tests/")

    # R2 — chaque test reel est reference dans le registre
    missing_in_registry = actual_all - registry_refs
    for relpath, funcname in sorted(missing_in_registry):
        errors.append(f"[R2] tests/{relpath}::{funcname} existe mais absent de TEST_REGISTRY.md")

    # R3 — dossiers de scratch residuels
    stale_dirs = find_stale_scratch_dirs(out_dir)
    for stale in stale_dirs:
        warnings.append(f"[R3] out/{stale.name}/ residuel (dossier de scratch jamais nettoye)")

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    if args.report:
        print()
        print("```text")
        print(f"Auto-verification registre tests (check_test_registry.py) — {'FAIL' if errors else 'PASS'}")
        print(f"  {len(actual_all)} test(s) reel(s) trouve(s) : "
              f"{len(actual_contracts)} contracts, {len(actual_generation)} generation, "
              f"{len(actual_simulation)} simulation")
        for error in errors[:8]:
            print(f"  KO  {error}")
        for warning in warnings[:5]:
            print(f"  !   {warning}")
        print("```")

    failed = bool(errors)
    print(
        f"\nTest registry check: {'FAIL' if failed else 'PASS'} "
        f"({len(errors)} erreur(s), {len(warnings)} avertissement(s), "
        f"{len(actual_all)} test(s) verifie(s))"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
