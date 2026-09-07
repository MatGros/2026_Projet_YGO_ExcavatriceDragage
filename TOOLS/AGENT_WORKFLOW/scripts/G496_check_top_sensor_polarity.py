#!/usr/bin/env python3
"""G496 - Verrouille la polarité NC du FdC haut dans PRG_04.

Le DI est nommé TopPositionFree_DI : TRUE signifie zone haute libre.
FB_Safety_Winch attend cette même polarité et bloque sur NOT TopPositionSensor.
"""
from pathlib import Path
import sys


TARGET = Path("CODE/M_MAIN/PRG_04_Treuils_Benne.st")
RAW = "PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI"


def main() -> int:
    if not TARGET.is_file():
        print(f"G496 FAIL: fichier absent: {TARGET}")
        return 1
    text = TARGET.read_text(encoding="utf-8")
    expected = f"TopPositionSensor      := {RAW},"
    count = text.count(expected)
    forbidden = f"TopPositionSensor      := NOT {RAW},"
    if count != 2:
        print(f"G496 FAIL: {count}/2 liaisons directes attendues")
        return 1
    if forbidden in text:
        print("G496 FAIL: inversion NOT interdite sur le DI TopPositionFree")
        return 1
    print("G496 PASS: M1/M2 utilisent le contact NC TopPositionFree_DI sans double inversion")
    return 0


if __name__ == "__main__":
    sys.exit(main())
