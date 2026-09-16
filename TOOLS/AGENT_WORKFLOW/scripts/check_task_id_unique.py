#!/usr/bin/env python3
"""Gate d'unicite des identifiants de tache — catalogue ET identifiants reserves.

Classe de bug couverte (REX 2026-09-16) : un agent a cree la tache T300 apres
avoir verifie son unicite dans le seul DOC/WFLOW/TASKS.yaml. Or T300 a T303
etaient deja RESERVES la veille dans DOC/WFLOW/REGISTRES/ par un rapport de
mise en service ("| **`T300`** (a creer) |"), pour des sujets machine reels.
Le controle etait vrai et la conclusion fausse : un identifiant peut etre pris
sans exister encore dans le catalogue.

Ce script verifie deux choses :

  U1  aucun identifiant n'apparait deux fois dans TASKS.yaml
  U2  aucun identifiant du catalogue ne collisionne avec un identifiant
      reserve ailleurs (registres, audits, plans) pour une AUTRE tache

Et il rend un service : --next affiche le premier identifiant reellement libre.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_id_unique.py
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_id_unique.py --next
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
TASKS = REPO / "DOC" / "WFLOW" / "TASKS.yaml"
# Endroits ou un identifiant peut etre reserve avant d'exister au catalogue.
RESERVATION_DIRS = [
    REPO / "DOC" / "WFLOW" / "REGISTRES",
    REPO / "DOC" / "WFLOW" / "AUDITS",
]

TASK_ID_RE = re.compile(r"\bT(\d{3,4})\b")
CATALOG_ID_RE = re.compile(r"^- id:\s*(T\d{3,4})\s*$", re.MULTILINE)
# "(a creer)" / "(à créer)" a moins de 80 caracteres apres l'identifiant.
RESERVED_RE = re.compile(r"\bT(\d{3,4})\b[^\n]{0,80}?\(\s*[àa]\s*cr[ée]er\s*\)", re.IGNORECASE)


def catalog_ids(text: str) -> list[str]:
    return CATALOG_ID_RE.findall(text)


def reserved_ids(dirs: list[Path]) -> dict[str, str]:
    """Identifiants marques '(a creer)' -> fichier:ligne ou ils sont reserves."""
    found: dict[str, str] = {}
    for root in dirs:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.md")):
            try:
                lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            except OSError:
                continue
            for n, line in enumerate(lines, 1):
                for num in RESERVED_RE.findall(line):
                    tid = f"T{num}"
                    found.setdefault(tid, f"{path.relative_to(REPO)}:{n}")
    return found


def all_mentioned_ids() -> set[str]:
    """Tout identifiant cite quelque part — base du calcul de --next."""
    seen: set[str] = set()
    for root in [TASKS.parent] + RESERVATION_DIRS:
        if not root.exists():
            continue
        paths = [TASKS] if root == TASKS.parent else sorted(root.rglob("*.md"))
        if root == TASKS.parent:
            paths = [TASKS] + sorted(root.glob("*.md"))
        for path in paths:
            try:
                seen.update(f"T{n}" for n in TASK_ID_RE.findall(
                    path.read_text(encoding="utf-8", errors="replace")))
            except OSError:
                continue
    return seen


def next_free() -> str:
    seen = all_mentioned_ids()
    nums = sorted(int(t[1:]) for t in seen if t[1:].isdigit())
    candidate = (nums[-1] + 1) if nums else 1
    while f"T{candidate}" in seen:
        candidate += 1
    return f"T{candidate}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--next", action="store_true",
                        help="affiche le premier identifiant libre et sort")
    args = parser.parse_args()

    if args.next:
        print(next_free())
        return 0

    if not TASKS.is_file():
        print(f"[ERREUR] catalogue introuvable : {TASKS}")
        return 2

    ids = catalog_ids(TASKS.read_text(encoding="utf-8", errors="replace"))
    errors: list[str] = []

    # U1 — doublons internes au catalogue
    for tid in sorted({t for t in ids if ids.count(t) > 1}):
        errors.append(f"U1 {tid} apparait {ids.count(tid)} fois dans TASKS.yaml")

    # U2 — collision avec une reservation portant sur un autre sujet
    reserved = reserved_ids(RESERVATION_DIRS)
    for tid in sorted(set(ids) & set(reserved)):
        errors.append(
            f"U2 {tid} est reserve dans {reserved[tid]} — verifier que la tache "
            f"du catalogue est bien CE sujet, sinon renumeroter")

    if errors:
        print("Task ID unicity check: FAIL")
        for line in errors:
            print(f"  - {line}")
        print(f"\n  Premier identifiant libre : {next_free()}")
        return 1

    print(f"Task ID unicity check: PASS ({len(ids)} taches, "
          f"{len(reserved)} identifiant(s) reserve(s) hors catalogue)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
