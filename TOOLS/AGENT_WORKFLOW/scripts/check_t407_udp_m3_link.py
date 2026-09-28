#!/usr/bin/env python3
"""Garde-fou T407 : protocole loopback et phase shadow sans ecriture PLC."""

from __future__ import annotations

import ast
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SHADOW = ROOT / "TOOLS/PLC_CSV_SNAPSHOT/codesys_console/codesys_m3_udp_shadow.py"
PROTOCOL = ROOT / "TOOLS/TWINBENCH/udp_m3_link/protocol.py"


def main() -> int:
    failures: list[str] = []
    shadow = SHADOW.read_text(encoding="utf-8")
    protocol = PROTOCOL.read_text(encoding="utf-8")
    if 'HOST = "127.0.0.1"' not in shadow or 'PORT = 29030' not in shadow:
        failures.append("shadow non borne au loopback/port T407")
    forbidden = ("set_prepared_value", "write_prepared_values", "SimM3OpenModelica")
    for token in forbidden:
        if token in shadow:
            failures.append("shadow contient interdit: {}".format(token))
    if "with socket.socket" in shadow:
        failures.append("shadow utilise un context manager socket incompatible IronPython CODESYS")
    if "time.monotonic(" in shadow:
        failures.append("shadow utilise time.monotonic incompatible IronPython CODESYS")
    if "def _iec_number(value):" not in shadow or '"frequency_hz": _iec_number(values[1])' not in shadow:
        failures.append("shadow ne normalise pas les nombres IEC avant conversion")
    if 'HOST = "127.0.0.1"' not in protocol or 'PORT = 29030' not in protocol:
        failures.append("protocole non borne au loopback/port T407")
    try:
        ast.parse(shadow)
        ast.parse(protocol)
    except SyntaxError as exc:
        failures.append("syntaxe: {}".format(exc))
    if failures:
        for failure in failures:
            print("[FAIL] {}".format(failure))
        return 1
    print("[PASS] T407 guard : UDP loopback fixe, shadow sans ecriture PLC, syntaxe valide.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
