#!/usr/bin/env python3
"""G529 — la compensation M2 ne se relache que pendant une ouverture relative."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "CODE/L_SIMULATION/FB_SimBench.st"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    branch = re.search(
        r"ELSIF\s+M2_RelayRev\s+AND\s+NOT\s+M2_RelayFwd(?P<condition>.*?)THEN"
        r"(?P<body>.*?)WinchCouplingAccumPts\s*:=\s*MAX\(",
        source,
        re.DOTALL,
    )
    if branch is None:
        print("FAIL: branche de relachement M2 introuvable")
        return 1

    condition = branch.group("condition")
    expected = ("NOT M1_RelayFwd", "NOT M1_RelayRev")
    missing = [term for term in expected if term not in condition]
    if missing:
        print("FAIL: relachement actif pendant mouvement M1 : " + ", ".join(missing))
        return 1

    print("PASS: relachement de compensation limite a l ouverture relative M2 seule")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
