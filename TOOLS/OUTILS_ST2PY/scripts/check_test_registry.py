#!/usr/bin/env python3
"""Gate de tracabilite : verifie que TEST_REGISTRY.md et les suites reelles concordent.

Classe de dette couverte (REX 2026-08) : des dizaines de tests s'accumulent sans
registre de ce qui est teste, pour quelle fonction, avec quel identifiant de cas
critique (TC-*). Impossible de savoir si une fonction a perdu sa couverture de
non-regression lors d'une evolution.

Controles :
  R1  chaque test reference dans TEST_REGISTRY.md existe reellement (fichier::fonction)
  R2  chaque `def test_*` present dans suites/ est reference dans le registre
  R3  aucun dossier de scratch `st2py-test-*` residuel sous RESULTS/
      (les tests doivent utiliser le temp systeme, jamais l'arborescence de resultats)

Usage :
  python TOOLS/OUTILS_ST2PY/scripts/check_test_registry.py
  python TOOLS/OUTILS_ST2PY/scripts/check_test_registry.py --report
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

#: Le registre reference les tests sous la forme `suites/<groupe>/<fichier>.py::<test>`.
REGISTRY_LINE = re.compile(r"`suites/(?P<relpath>[\w/]+\.py)::(?P<funcname>test_\w+)`")
TEST_DEF = re.compile(r"^def (test_\w+)\s*\(", re.MULTILINE)

#: Groupes de suites tracables. contracts = comportement metier (TC-*),
#: generation/simulation = outillage (AUTO), mais tous doivent etre traces.
SUITE_GROUPS = ("contracts", "generation", "simulation")


def load_registry_references(registry_path: Path) -> set[tuple[str, str]]:
    text = registry_path.read_text(encoding="utf-8")
    return {(m.group("relpath"), m.group("funcname")) for m in REGISTRY_LINE.finditer(text)}


def load_actual_tests(suites_dir: Path, group: str) -> set[tuple[str, str]]:
    found: set[tuple[str, str]] = set()
    folder = suites_dir / group
    if not folder.is_dir():
        return found
    for path in sorted(folder.glob("test_*.py")):
        text = path.read_text(encoding="utf-8")
        rel = f"{group}/{path.name}"
        for match in TEST_DEF.finditer(text):
            found.add((rel, match.group(1)))
    return found


def find_stale_scratch_dirs(results_dir: Path) -> list[Path]:
    if not results_dir.is_dir():
        return []
    return sorted(p for p in results_dir.rglob("st2py-test-*") if p.is_dir())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", action="store_true", help="Afficher le bloc de restitution agent")
    args = parser.parse_args()

    root = args.root.resolve()
    registry_path = root / "TEST_REGISTRY.md"
    suites_dir = root / "suites"
    results_dir = root / "RESULTS"

    if not registry_path.is_file():
        print(f"[ERROR] registre introuvable : {registry_path}", file=sys.stderr)
        return 2

    registry_refs = load_registry_references(registry_path)
    by_group = {g: load_actual_tests(suites_dir, g) for g in SUITE_GROUPS}
    actual_all: set[tuple[str, str]] = set()
    for tests in by_group.values():
        actual_all |= tests

    errors: list[str] = []
    warnings: list[str] = []

    for relpath, funcname in sorted(registry_refs - actual_all):
        errors.append(f"[R1] TEST_REGISTRY.md reference `{relpath}::{funcname}` introuvable dans suites/")

    for relpath, funcname in sorted(actual_all - registry_refs):
        errors.append(f"[R2] suites/{relpath}::{funcname} existe mais absent de TEST_REGISTRY.md")

    for stale in find_stale_scratch_dirs(results_dir):
        warnings.append(
            f"[R3] {stale.relative_to(root).as_posix()} residuel "
            f"(scratch de test dans RESULTS/ : utiliser le temp systeme)"
        )

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    if args.report:
        print()
        print("```text")
        print(f"Auto-verification registre tests (check_test_registry.py) — {'FAIL' if errors else 'PASS'}")
        summary = ", ".join(f"{len(v)} {k}" for k, v in by_group.items())
        print(f"  {len(actual_all)} test(s) reel(s) trouve(s) : {summary}")
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
