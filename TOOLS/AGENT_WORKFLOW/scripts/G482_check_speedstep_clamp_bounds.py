#!/usr/bin/env python3
"""G482 — Invariants T181-07 du clamp de FB_SpeedStep.

Refuse une régression où le plancher devancerait le plafond, où le LIMIT final
disparaîtrait, ou où la neutralisation laisserait un palier actif.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_SpeedStep.st"


def normalise(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def main() -> int:
    if not SOURCE.is_file():
        print("[G482] FAIL — FB_SpeedStep.st introuvable")
        return 1

    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    compact = normalise(text)
    required = {
        "plafond borne": r"_MaxStepClamped\s*:=\s*LIMIT\s*\(\s*1\s*,\s*MaxStepNumber\s*,\s*5\s*\)",
        "plancher apres plafond": r"_MinStepClamped\s*:=\s*LIMIT\s*\(\s*1\s*,\s*MinStepNumber\s*,\s*_MaxStepClamped\s*\)",
        "clamp final": r"StepNumber\s*:=\s*LIMIT\s*\(\s*_MinStepClamped\s*,\s*SpeedStepReq\s*,\s*_MaxStepClamped\s*\)",
        "neutralisation": r"IF\s*\(\s*NOT\s+Enable\s*\).*?StepNumber\s*:=\s*0",
    }
    errors = [name for name, pattern in required.items() if not re.search(pattern, compact, re.IGNORECASE)]

    forbidden = [
        "SpeedTgt_Pct",
        "HystMargin",
        "MeasuredSpeedBand",
        "SpeedGuardEnable",
        "SpeedGuardReady",
        "SpeedGuardLimited",
    ]
    for name in forbidden:
        if re.search(rf"\b{re.escape(name)}\b", text):
            errors.append(f"identifiant retire encore present : {name}")

    final_pos = compact.find("StepNumber := LIMIT(_MinStepClamped, SpeedStepReq, _MaxStepClamped)")
    case_pos = compact.find("CASE StepNumber OF")
    if final_pos < 0 or case_pos < 0 or final_pos > case_pos:
        errors.append("LIMIT final absent ou place apres CASE")

    if errors:
        print("[G482] FAIL — invariants SpeedStep :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("[G482] PASS — plafond > plancher > LIMIT final > CASE ; relache vers 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
