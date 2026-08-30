#!/usr/bin/env python3
"""G487 — Interdit l'initialiseur de struct anonyme en parametre d'appel FB.

CODESYS 3.5 ST N'ACCEPTE PAS :
    instFB(Param := (Champ1 := x, Champ2 := y));
Le compilo CI STruCpp l'avale silencieusement -> CI verte mais 90 erreurs
C0189/C0037 a l'import CODESYS (REX 2026-08-30, PRG_04 refonte DriveRequest T181-08).

Correctif attendu : remplir une variable struct temporaire champ par champ
AVANT l'appel, puis passer la variable.

Detection : dans un CALL `ident(...)`, un parametre de la forme
    <ident> := ( <ident> := ...
c.-a-d. une parenthese ouvrante suivie (apres espaces/sauts de ligne) d'un
`ident :=`. Les expressions normales `X := (A OR B)` ne matchent pas car il n'y
a pas de `:=` immediatement dans la parenthese.

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G487_check_no_inline_struct_literal.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G487_check_no_inline_struct_literal.py --selftest

Sortie : code 0 si aucune occurrence, 1 sinon.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# `:= (` puis (espaces/newlines/commentaires ligne) puis `IDENT :=`
PATTERN = re.compile(
    r""":=\s*\(\s*                     # ' := ('  ouvrant
        (?://[^\n]*\n\s*)*             # commentaires ligne eventuels
        [A-Za-z_][A-Za-z0-9_]*         # nom de champ
        \s*:=                          # affectation de champ -> struct literal
    """,
    re.VERBOSE,
)


_VAR_OPEN = re.compile(r"^\s*(VAR(_INPUT|_OUTPUT|_IN_OUT|_GLOBAL|_STAT|_TEMP)?|TYPE)\b", re.I)
_VAR_CLOSE = re.compile(r"^\s*(END_VAR|END_TYPE)\b", re.I)


def _body_only(text: str) -> str:
    """Neutralise les lignes situees dans un bloc VAR*/TYPE (initialiseurs de
    struct en DECLARATION = legaux CODESYS). Ne reste que le corps executable."""
    out = []
    depth = 0
    for line in text.splitlines(keepends=True):
        if _VAR_OPEN.match(line):
            depth += 1
            out.append("\n")
            continue
        if _VAR_CLOSE.match(line):
            depth = max(0, depth - 1)
            out.append("\n")
            continue
        out.append("\n" if depth > 0 else line)
    return "".join(out)


def scan_text(text: str) -> list[int]:
    """Retourne les numeros de ligne (1-based) des occurrences dans le CORPS."""
    scoped = _body_only(text)
    hits: list[int] = []
    for m in PATTERN.finditer(scoped):
        hits.append(scoped.count("\n", 0, m.start()) + 1)
    return hits


def scan_repo(root: Path) -> dict[Path, list[int]]:
    found: dict[Path, list[int]] = {}
    for st in sorted(root.glob("CODE/**/*.st")):
        # _TYPES/ contient des declarations TYPE ... STRUCT avec initialisateurs
        # de champ legitimes (`Champ : INT := 3;`) -> hors scope de ce guard.
        if "_TYPES" in st.parts:
            continue
        text = st.read_text(encoding="utf-8", errors="replace")
        hits = scan_text(text)
        if hits:
            found[st] = hits
    return found


def selftest() -> int:
    bad = "instWinchM1(\n    DriveRequest := (StartStop := x,\n                    Direction := y));"
    ok1 = "instFB(Enable := (A OR B) AND NOT C);"
    ok2 = "M1DriveRequest.StartStop := x;\ninstWinchM1(DriveRequest := M1DriveRequest);"
    ok3 = "TON(IN := (x AND y), PT := T#1s);"
    fails = []
    if not scan_text(bad):
        fails.append("cas KO non detecte")
    if scan_text(ok1):
        fails.append("faux positif ok1 (OR dans parenthese)")
    if scan_text(ok2):
        fails.append("faux positif ok2 (struct temp correcte)")
    if scan_text(ok3):
        fails.append("faux positif ok3 (TON IN expression)")
    if fails:
        print("G487 SELFTEST: FAIL -> " + " ; ".join(fails))
        return 1
    print("G487 SELFTEST: PASS")
    return 0


def main(argv: list[str]) -> int:
    if "--selftest" in argv:
        return selftest()
    root = Path(argv[1]) if len(argv) > 1 else Path(".")
    found = scan_repo(root)
    if not found:
        print("G487 check: PASS (aucun initialiseur de struct anonyme en appel FB)")
        return 0
    print("G487 check: FAIL — initialiseur de struct anonyme en parametre d'appel "
          "(CODESYS 3.5 le refuse — assembler une variable struct temporaire avant l'appel) :")
    for st, lines in found.items():
        for ln in lines:
            print(f"  {st.as_posix()}:{ln}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
