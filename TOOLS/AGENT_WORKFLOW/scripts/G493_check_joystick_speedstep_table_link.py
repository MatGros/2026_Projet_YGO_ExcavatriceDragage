#!/usr/bin/env python3
"""Gate T223 : PRG_02 alimente le joystick depuis la table centrale des paliers."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> int:
    print(f"FAIL : {message}")
    return 1


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    source = root / "CODE" / "M_MAIN" / "PRG_02_Acquisition.st"
    if not source.is_file():
        return fail(f"source introuvable : {source}")
    text = source.read_text(encoding="utf-8")

    if not re.search(r"JoystickCfgEffective\s*:\s*ST_fbJoystick_Cfg\s*;", text):
        return fail("configuration effective joystick non declaree")

    copy = "JoystickCfgEffective := GVL_PERSISTENT._JoystickCfgPersist;"
    table = "JoystickCfgEffective.SpeedStepTable := GVL_PERSISTENT._WinchSpeedStepTable;"
    call = "Cfg                       := JoystickCfgEffective,"
    copy_index = text.find(copy)
    table_index = text.find(table)
    call_index = text.find(call)
    if min(copy_index, table_index, call_index) < 0:
        return fail("copie, injection de table ou call-site instJoystick absent")
    if not copy_index < table_index < call_index:
        return fail("ordre requis : copie config, injection table, puis instJoystick")

    forbidden = (
        "GVL_PERSISTENT._JoystickCfgPersist.SpeedStepTable :=",
        "GVL_PERSISTENT._WinchSpeedStepTable :=",
        "instJoystick.Cfg.SpeedStepTable :=",
    )
    for token in forbidden:
        if token in text:
            return fail(f"ecriture cyclique interdite detectee : {token}")

    print("PASS : instJoystick recoit la table centrale sans ecriture persistante.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
