#!/usr/bin/env python3
"""Gate T222 : invariants du verrou d'inversion inter-scan de FB_Joystick."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> int:
    print(f"FAIL : {message}")
    return 1


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    source = root / "CODE" / "D_JOYSTICK" / "FB_Joystick.st"
    if not source.is_file():
        return fail(f"source introuvable : {source}")
    text = source.read_text(encoding="utf-8")

    required = (
        "InversionLockActive",
        "PrevDirX",
        "PrevDirY",
        "FlipX",
        "FlipY",
        "NeutralXYEdge(CLK := AtNeutralXY)",
        "DeadmanArmPending AND NOT DeadmanArmed AND ArmingPermit AND NOT InversionLockActive",
        "PrevDirX := DirX",
        "PrevDirY := DirY",
    )
    for token in required:
        if token not in text:
            return fail(f"invariant absent : {token}")

    if not re.search(r"FlipX\s*:=\s*\(\(PrevDirX = 1\).*?DirX = -1.*?\).*?\(\(PrevDirX = -1\).*?DirX = 1", text):
        return fail("FlipX ne compare pas les deux sens qualifies successifs")
    if not re.search(r"FlipY\s*:=\s*\(\(PrevDirY = 1\).*?DirY = -1.*?\).*?\(\(PrevDirY = -1\).*?DirY = 1", text):
        return fail("FlipY ne compare pas les deux sens qualifies successifs")

    gate_start = text.find('{region "§2 Gate securite')
    gate_end = text.find('{endregion}', gate_start)
    if gate_start < 0 or gate_end < 0:
        return fail("region §2 Gate securite introuvable")
    neutral_release = text.find("IF NeutralXYEdge.Q THEN")
    neutral_release_end = text.find("END_IF;", neutral_release)
    for match in re.finditer(r"InversionLockActive\s*:=\s*FALSE", text):
        in_gate = gate_start <= match.start() < gate_end
        in_neutral_release = neutral_release <= match.start() < neutral_release_end
        if not (in_gate or in_neutral_release):
            return fail("InversionLockActive ne peut etre efface que par §2 ou front AtNeutralXY (jamais Reset)")

    reset_blocks = re.findall(r"IF Reset.*?END_IF;", text, flags=re.DOTALL)
    if any("InversionLockActive" in block for block in reset_blocks):
        return fail("Reset ne doit jamais effacer InversionLockActive")

    print("PASS : verrou inversion T222 protege (rearmement gate, Reset et memoires verifies).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
