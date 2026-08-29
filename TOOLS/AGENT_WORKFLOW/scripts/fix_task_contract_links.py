#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Repointe les champs ``contrat:`` morts de DOC/WFLOW/TASKS.yaml.

Contexte : l'archivage des contrats clos (commit 5c9dca9c et suivants) a deplace
les ``TASK_CONTRACT_*.yaml`` de DOC/WFLOW/CONTRACTS/ vers ARCHIVES/Doc/WFLOW/
CONTRACTS/ sans mettre a jour les references dans TASKS.yaml -> ~54 taches ✅
pointent vers un fichier inexistant.

Regle : pour chaque ligne ``  contrat: <chemin>`` dont le fichier n'existe plus,
si ``<basename>`` existe sous ARCHIVES/Doc/WFLOW/CONTRACTS/ (contrat clos archive)
ou sous DOC/WFLOW/CONTRACTS/ (cas d'un chemin nu), on repointe. Sinon on liste
l'orphelin sans y toucher.

Idempotent : re-executable a chaque nouvelle vague d'archivage. Lecture/ecriture
purement textuelle ligne a ligne -> commentaires et mise en forme de TASKS.yaml
preserves (pas de yaml.safe_dump destructif).

Usage : python TOOLS/AGENT_WORKFLOW/scripts/fix_task_contract_links.py [--check]
  --check : ne modifie rien, code retour 1 s'il reste des liens a repointer.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except Exception:  # pragma: no cover
        pass

REPO = Path(__file__).resolve().parents[3]
TASKS = REPO / "DOC" / "WFLOW" / "TASKS.yaml"
SEARCH_DIRS = (
    REPO / "ARCHIVES" / "Doc" / "WFLOW" / "CONTRACTS",
    REPO / "DOC" / "WFLOW" / "CONTRACTS",
)
LINE_RE = re.compile(r"^(\s*contrat:\s+)(\S.*?)\s*$")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="Audit seul, aucune ecriture.")
    args = ap.parse_args()

    lines = TASKS.read_text(encoding="utf-8").splitlines(keepends=True)
    repointed: list[tuple[str, str, str]] = []
    orphans: list[tuple[int, str]] = []

    for idx, raw in enumerate(lines):
        m = LINE_RE.match(raw.rstrip("\n"))
        if not m:
            continue
        prefix, val = m.group(1), m.group(2).strip().strip("'\"")
        if not val or (REPO / val).exists():
            continue
        base = Path(val).name
        newpath = None
        for d in SEARCH_DIRS:
            if (d / base).is_file():
                newpath = (d / base).relative_to(REPO).as_posix()
                break
        if newpath is None:
            orphans.append((idx + 1, val))
            continue
        lines[idx] = f"{prefix}{newpath}\n"
        repointed.append((val, newpath, base))

    print(f"contrat: repointables = {len(repointed)}, orphelins = {len(orphans)}")
    for _old, new, base in repointed:
        print(f"  -> {base}  ==>  {new}")
    for ln, val in orphans:
        print(f"  [ORPHELIN] L{ln} : {val}  (absent aussi de ARCHIVES/)")

    if args.check:
        return 1 if repointed else 0

    if repointed:
        TASKS.write_text("".join(lines), encoding="utf-8")
        print(f"\nTASKS.yaml mis a jour : {len(repointed)} lien(s) repointe(s).")
    else:
        print("\nRien a repointer.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
