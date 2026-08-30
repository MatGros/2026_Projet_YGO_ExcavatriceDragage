#!/usr/bin/env python3
"""G484 — ContactorStuck : proprietaire unique (T181-02/03 AC7).

Refuse une regression ou la detection contacteur colle serait re-introduite dans
FB_Winch (le champ ``ContactorsCheck.StuckClosed`` ne doit etre force qu'a FALSE,
Phase 0), et verifie que FB_Safety_Winch est bien le producteur unique de la
detection (sortie ``ContactorStuck`` alimentee). Le gate echoue si plus d'un FB
produit la detection contacteur colle du treuil.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WINCH = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Winch.st"
SAFETY = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Safety_Winch.st"
CODE_DIR = ROOT / "CODE"


def main() -> int:
    errors: list[str] = []
    if not WINCH.is_file():
        print("[G484] FAIL — FB_Winch.st introuvable")
        return 1
    if not SAFETY.is_file():
        print("[G484] FAIL — FB_Safety_Winch.st introuvable")
        return 1

    winch = WINCH.read_text(encoding="utf-8", errors="replace")
    safety = SAFETY.read_text(encoding="utf-8", errors="replace")

    # 1. FB_Winch : StuckClosed force a FALSE, jamais a TRUE ni a une expression de detection.
    stuck_assigns = re.findall(r"ContactorsCheck\.StuckClosed\s*:=\s*([A-Za-z_][A-Za-z0-9_]*)", winch)
    if not stuck_assigns:
        errors.append("FB_Winch ne force pas ContactorsCheck.StuckClosed := FALSE (Phase 0, AC4)")
    for val in stuck_assigns:
        if val.upper() != "FALSE":
            errors.append(f"FB_Winch assigne ContactorsCheck.StuckClosed := {val} (detection re-introduite)")

    # 2. FB_Safety_Winch : produit ContactorStuck (sortie declaree + affectation).
    if not re.search(r"ContactorStuck\s*:\s*BOOL", safety):
        errors.append("FB_Safety_Winch ne declare pas la sortie ContactorStuck")
    if not re.search(r"ContactorStuck\s*:=", safety):
        errors.append("FB_Safety_Winch n'affecte pas ContactorStuck (producteur unique absent)")

    # 3. Aucun autre FB ne produit la detection contacteur colle du treuil
    #    (champ ContactorsCheck.StuckClosed, specifique a FB_Winch).
    for st in sorted(CODE_DIR.rglob("*.st")):
        if st.name in ("FB_Winch.st", "FB_Safety_Winch.st"):
            continue
        text = st.read_text(encoding="utf-8", errors="replace")
        if re.search(r"ContactorsCheck\.StuckClosed\s*:=", text):
            errors.append(f"{st.name} assigne ContactorsCheck.StuckClosed (producteur non autorise)")

    if errors:
        print("[G484] FAIL — invariants ContactorStuck :")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("[G484] PASS — ContactorStuck produit uniquement par FB_Safety_Winch ; FB_Winch force FALSE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
