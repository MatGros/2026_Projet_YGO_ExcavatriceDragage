#!/usr/bin/env python3
"""G497 - MecaD ne doit pas armer pendant la manoeuvre benne."""
from pathlib import Path
import sys


TARGET = Path("CODE/H_TREUILS_BENNE/FB_Safety_Winch.st")


def main() -> int:
    if not TARGET.is_file():
        print(f"G497 FAIL: fichier absent: {TARGET}")
        return 1
    text = TARGET.read_text(encoding="utf-8")
    expected = "UncommandedActiveD := NOT (BenneBusy OR BenneHoldStillActive)"
    if expected not in text:
        print("G497 FAIL: garde BenneBusy/BenneHoldStillActive absente de MecaD")
        return 1
    if "AscentPermit := NOT (" not in text or "CauseTopLimitSwitchActive" not in text:
        print("G497 FAIL: calcul AscentPermit/FdC introuvable")
        return 1
    print("G497 PASS: MecaD inhibé uniquement pendant la manœuvre benne; FdC permis conservé")
    return 0


if __name__ == "__main__":
    sys.exit(main())
