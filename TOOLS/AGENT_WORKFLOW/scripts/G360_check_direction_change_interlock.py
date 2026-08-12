#!/usr/bin/env python3
"""Garde-fou REX 2026-08-05 (translation M3, inversion de sens jamais prise en compte).

Un FB de mouvement pilotant un `CommandedDirection` (sens réellement appliqué, distinct
du `Direction` brut demandé) doit forcer sa consigne de rampe à 0 tant qu'une inversion de
sens est en attente (`DirectionChangePending`). Sans cette garde, la consigne de rampe suit
la magnitude joystick en continu et ne croise jamais le seuil d'arrêt qui autorise
l'interlock changement de sens à basculer `CommandedDirection` : une inversion plus rapide
que la décélération réelle bloque indéfiniment le mouvement dans l'ancien sens.

Découvert sur `FB_Winch` (REX 2026-07-02, corrigé), jamais porté sur `FB_Translation`
(cassé jusqu'au REX 2026-08-05, corrigé dans le même lot que ce garde-fou).

Règle : tout `CODE/**/*.st` qui déclare `CommandedDirection : INT` doit aussi déclarer et
référencer `DirectionChangePending` (présence textuelle — pas une preuve de câblage exact,
mais un filet contre l'oubli complet du pattern sur un futur FB de mouvement).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

COMMANDED_DIRECTION_DECL = re.compile(r"\bCommandedDirection\s*:\s*INT\b")
DIRECTION_CHANGE_PENDING = re.compile(r"\bDirectionChangePending\b")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    errors = 0
    for path in sorted((root / "CODE").rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if not COMMANDED_DIRECTION_DECL.search(text):
            continue
        if not DIRECTION_CHANGE_PENDING.search(text):
            rel = path.relative_to(root).as_posix()
            print(
                f"[ERROR] {rel}: declare CommandedDirection mais pas DirectionChangePending "
                f"— une inversion de sens plus rapide que la decel reelle peut bloquer le "
                f"mouvement dans l'ancien sens indefiniment (voir REX 2026-08-05, FB_Winch/"
                f"FB_Translation).",
                file=sys.stderr,
            )
            errors += 1

    print(f"Direction change interlock check: {'FAIL' if errors else 'PASS'} ({errors} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
