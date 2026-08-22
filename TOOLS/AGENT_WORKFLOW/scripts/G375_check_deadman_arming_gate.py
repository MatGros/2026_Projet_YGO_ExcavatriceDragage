#!/usr/bin/env python3
"""AF08 TC-P08-008 : "Winch, Translation et Cycle exigent DeadmanArmed" (reformule 2026-08-22).

Le gate `AND (NOT TglJoystickMaster OR JoystickDeadmanArmed)` qui interdit tout mouvement
Joystick sans homme-mort armé vit dans le PRG de collage (`PRG_04_Treuils_Benne.st`), pas dans
un FB isolé (`FB_Joystick` produit `DeadmanArmed`, mais n'a aucune connaissance de Winch/
Translation/Cycle -- responsabilité unique). Un test FB-en-boîte-noire (`TEST_AUTO_CI`) ne
peut donc PAS le prouver, ni côté Joystick, ni côté Winch : ce n'est pas du comportement de FB,
c'est du câblage de programme. D'où ce gate statique, même famille que G360/G370.

Règle : tout `CODE/**/*.st` qui consomme `instJoystick.AxisCmdX`/`AxisCmdY` (donc pilote un
mouvement à partir de l'intention Joystick) ET assigne une variable `*StartStop*` doit aussi
référencer `JoystickDeadmanArmed` quelque part dans le même fichier — présence textuelle,
pas une preuve de câblage exact au sein de la même expression (limite assumée, comme G360).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

AXISCMD_RE = re.compile(r"instJoystick\.AxisCmd[XY]\b")
STARTSTOP_ASSIGN_RE = re.compile(r"\w*StartStop\w*\s*:=")
DEADMAN_ARMED_RE = re.compile(r"JoystickDeadmanArmed\b")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    errors = 0
    for path in sorted((root / "CODE").rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if not AXISCMD_RE.search(text):
            continue
        if not STARTSTOP_ASSIGN_RE.search(text):
            continue
        if not DEADMAN_ARMED_RE.search(text):
            rel = path.relative_to(root).as_posix()
            print(
                f"[ERROR] {rel}: pilote un StartStop a partir de instJoystick.AxisCmdX/Y "
                f"mais ne reference jamais JoystickDeadmanArmed -- un mouvement pourrait "
                f"demarrer sans homme-mort arme (AF08 TC-P08-008).",
                file=sys.stderr,
            )
            errors += 1

    print(f"Deadman arming gate check: {'FAIL' if errors else 'PASS'} ({errors} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
