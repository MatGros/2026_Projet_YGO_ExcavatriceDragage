#!/usr/bin/env python3
"""Garde-fou T168-C (2026-08-29) : trou de reset d'etats inter-modes dans PRG_03.

CODE/M_MAIN/PRG_03_Modes_Cycle.st publie l'etat public de sequence
(Data.SequenceState.*) via une chaine IF / ELSIF / ELSE sur le mode machine :

    IF   instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN ...
    ELSIF instModes.Auth.Mode = E_Mode.MAINT_N1 OR ... MAINT_N2 THEN ...
    ELSE  (* DISABLE *) ...

PRG_03 est le PRODUCTEUR UNIQUE de Data.SequenceState. Toute feuille ecrite dans
au moins une branche mais pas dans TOUTES laisse une valeur remanente au
changement de mode : un flag arme en MAINT (ex. DumpAtTremieDescentLocked := TRUE)
subsiste en memoire au passage SEMI_AUTO et PRG_04_Treuils_Benne verrouille alors
la descente treuil M1/M2 pendant le cycle automatique, sans cause visible
(regression du commit 7e65e566, corrigee par T168-C).

Regle : pour chaque feuille `Data.SequenceState.<chemin>` (sous-membres inclus,
ex. `Fault.ErrorId`, `Lifecycle.Busy`) assignee (`:=`) dans au moins une branche
de mode, ERREUR si elle n'est pas assignee dans les 3 branches. Une assignation
d'un ancetre (`Fault := ...` couvre `Fault.ErrorId`) ou d'un descendant
(`Lifecycle.Busy := ...` + `Lifecycle.Done := ...` couvrent `Lifecycle`) vaut
couverture : c'est le contenu de la feuille qui ne doit pas rester remanent.

Limite assumee (comme G360/G375) : analyse textuelle par branche, pas de preuve
de flot (une feuille assignee dans un seul sous-IF d'une branche compte comme
assignee pour cette branche). Le filet vise l'oubli complet d'une feuille dans
une branche, pas la couverture conditionnelle fine.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

TARGET = "CODE/M_MAIN/PRG_03_Modes_Cycle.st"

START_RE = re.compile(r"\bIF\b.*E_Mode\.SEMI_AUTO\b.*\bTHEN\b")
ELSIF_MAINT_RE = re.compile(r"^\s*ELSIF\b.*E_Mode\.MAINT_N1\b")
ELSE_RE = re.compile(r"^\s*ELSE\b\s*$")
IF_TOKEN_RE = re.compile(r"\bIF\b")
ENDIF_TOKEN_RE = re.compile(r"\bEND_IF\b")
LEAF_ASSIGN_RE = re.compile(r"\bData\.SequenceState\.([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\s*:=")

BRANCHES = ("SEMI_AUTO", "MAINT_N1/N2", "ELSE (DISABLE)")


def strip_comment(line: str) -> str:
    """Retire les commentaires // et (* ... *) mono-ligne (le fichier n'a pas de bloc multi-ligne dans cette region)."""
    line = re.sub(r"\(\*.*?\*\)", " ", line)
    idx = line.find("//")
    if idx >= 0:
        line = line[:idx]
    return line


def covers(assigned: set[str], path: str) -> bool:
    for p in assigned:
        if p == path or path.startswith(p + ".") or p.startswith(path + "."):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    target = root / TARGET
    if not target.is_file():
        print(f"[ERROR] Fichier introuvable : {TARGET}", file=sys.stderr)
        print("Mode branch completeness check: FAIL (1 erreur(s))")
        return 1

    lines = target.read_text(encoding="utf-8", errors="replace").splitlines()

    branch_assign: dict[str, set[str]] = {b: set() for b in BRANCHES}
    current: str | None = None
    depth = 0
    started = False

    for raw in lines:
        line = strip_comment(raw)

        if not started:
            if START_RE.search(line):
                started = True
                current = BRANCHES[0]
                depth = 1
            continue

        if depth == 1 and ELSIF_MAINT_RE.search(line):
            current = BRANCHES[1]
            continue
        if depth == 1 and ELSE_RE.search(line):
            current = BRANCHES[2]
            continue

        depth += len(IF_TOKEN_RE.findall(line)) - len(ENDIF_TOKEN_RE.findall(line))
        if depth <= 0:
            break

        if current is not None:
            for m in LEAF_ASSIGN_RE.finditer(line):
                branch_assign[current].add(m.group(1))

    if not started:
        print(f"[ERROR] {TARGET}: chaine 'IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN' introuvable "
              f"— structure des branches de mode modifiee, gate a revoir.", file=sys.stderr)
        print("Mode branch completeness check: FAIL (1 erreur(s))")
        return 1

    all_paths = set().union(*branch_assign.values())
    errors = 0
    for path in sorted(all_paths):
        missing = [b for b in BRANCHES if not covers(branch_assign[b], path)]
        if missing:
            errors += 1
            print(f"[ERROR] {TARGET}: Data.SequenceState.{path} assignee dans "
                  f"{[b for b in BRANCHES if b not in missing]} mais PAS dans {missing} "
                  f"— valeur remanente au changement de mode (producteur unique PRG_03).",
                  file=sys.stderr)

    if errors == 0:
        print("Mode branch completeness check: PASS (0 erreur)")
        return 0
    print(f"Mode branch completeness check: FAIL ({errors} erreur(s))")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
