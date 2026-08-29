#!/usr/bin/env python3
"""Garde-fou T168-D (2026-08-29) : type WORD obligatoire sur la chaine OperatorActionId.

Le champ OperatorActionId (identifiant d'action operateur, valeurs bit-codees en
hexadecimal 16#0100..16#0480, 0 = aucune) transite du sequenceur (FB_Cycle) vers
l'IHM / le troubleshooting en passant par plusieurs STRUCT relais
(ST_SequencePublicState, ST_ChainCycleSemiAuto, FB_TroubleshootingView) et il est
deja type WORD cote assistants de dragage (FB_DiveSearch, FB_ExtractionSequence,
ST_DredgingAssistState, ST_ChainDredgingAssist.Idx401).

Toute declaration de ce champ dans un type autre que WORD (UINT, INT, DINT, ...)
reintroduit une conversion implicite UINT<->WORD sur le chemin vivant, ce qui
produit des warnings de compilation CODESYS 3.5 (defaut C, T168-B/T168-D).

Regle : dans CODE/**/*.st, toute declaration de variable / membre de STRUCT dont
le nom matche :
    - (^|_)OperatorActionId$        (ex. OperatorActionId, Cycle... exclu ici)
    - ^CycleOperatorActionId$
    - ^Idx\\d+_OperatorActionId$     (ex. Idx211_OperatorActionId)
DOIT etre declaree de type WORD. Sinon -> ERREUR avec fichier:ligne.

Limite assumee : analyse textuelle ligne a ligne (une declaration = un identifiant
suivi de ':' puis d'un type). Suffisant pour ce champ (toujours declare seul).
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

CODE_DIR = "CODE"

# Declaration ST : <ident> : <type> [ ( ... ) ] ;
DECL_RE = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\b"
)

NAME_RES = (
    re.compile(r"(^|_)OperatorActionId$"),
    re.compile(r"^CycleOperatorActionId$"),
    re.compile(r"^Idx\d+_OperatorActionId$"),
)

EXPECTED_TYPE = "WORD"


def strip_comment(line: str) -> str:
    """Retire les commentaires // et (* ... *) mono-ligne."""
    line = re.sub(r"\(\*.*?\*\)", " ", line)
    idx = line.find("//")
    if idx >= 0:
        line = line[:idx]
    return line


def name_matches(name: str) -> bool:
    return any(rx.search(name) for rx in NAME_RES)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    code_root = root / CODE_DIR
    if not code_root.is_dir():
        print(f"[ERROR] Repertoire introuvable : {CODE_DIR}", file=sys.stderr)
        print("ActionId type check: FAIL (1 erreur(s))")
        return 1

    errors = 0
    checked = 0
    for path in sorted(code_root.rglob("*.st")):
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError as exc:
            print(f"[ERROR] Lecture impossible : {path} ({exc})", file=sys.stderr)
            errors += 1
            continue

        rel = path.relative_to(root).as_posix()
        for lineno, raw in enumerate(lines, start=1):
            line = strip_comment(raw)
            m = DECL_RE.match(line)
            if not m:
                continue
            name, decl_type = m.group(1), m.group(2)
            if not name_matches(name):
                continue
            checked += 1
            if decl_type.upper() != EXPECTED_TYPE:
                errors += 1
                print(
                    f"[ERROR] {rel}:{lineno}: {name} declare en {decl_type} "
                    f"— attendu {EXPECTED_TYPE} (identifiant bit-code, evite la "
                    f"conversion implicite {decl_type}<->WORD sur la chaine de diagnostic).",
                    file=sys.stderr,
                )

    if errors == 0:
        print(f"ActionId type check: PASS (0 erreur) — {checked} declaration(s) verifiee(s)")
        return 0
    print(f"ActionId type check: FAIL ({errors} erreur(s))")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
