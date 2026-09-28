#!/usr/bin/env python3
"""Garde-fou T408 : POC natif strictement loopback et hors M3/production."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "TOOLS/TWINBENCH/native_udp_poc/PRG_TwinBenchNativeUdp.st"
MULTI_SOURCE = ROOT / "TOOLS/TWINBENCH/native_udp_poc/PRG_TwinBenchNativeUdpMulti.st"
ECHO = ROOT / "TOOLS/TWINBENCH/native_udp_poc/udp_echo_t408.py"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    multi_source = MULTI_SOURCE.read_text(encoding="utf-8")
    echo = ECHO.read_text(encoding="utf-8")
    failures = []
    for token in ("'127.0.0.1'", "29031", "29032", "SOCKET_FIONBIO", "SysSockCloseUdp"):
        if token not in source:
            failures.append("source incomplet : {}".format(token))
    for forbidden in ("GVL_Simulation", "HwReal", "HwSim", "HwIn", "M3_"):
        if forbidden in source:
            failures.append("source interdit : {}".format(forbidden))
    if 'HOST = "127.0.0.1"' not in echo or "PORTS = {29031" not in echo:
        failures.append("echo non borne au loopback T408")
    if not re.search(r"IF Stop OR NOT Enable THEN[\s\S]{0,400}SysSockCloseUdp", source):
        failures.append("fermeture socket non prouvee a l arret")
    for token in ("29031", "29032", "29041", "29042", "29051", "29052", "SOCKET_FIONBIO"):
        if token not in multi_source:
            failures.append("multi-flux incomplet : {}".format(token))
    for token in ("SysTypes.RTS_IEC_HANDLE", "SysTypes.RTS_INVALID_HANDLE", "SysTypes.RTS_IEC_RESULT"):
        if token not in multi_source:
            failures.append("type systeme non qualifie : {}".format(token))
    if multi_source.count("SysSockCloseUdp") < 3:
        failures.append("multi-flux sans fermeture explicite des trois sockets")
    for forbidden in ("GVL_Simulation", "HwReal", "HwSim", "HwIn", "M3_"):
        if forbidden in multi_source:
            failures.append("multi-flux interdit : {}".format(forbidden))
    for failure in failures:
        print("[FAIL] {}".format(failure))
    if failures:
        return 1
    print("[PASS] T408 guard : loopback, non-blocking, fermeture explicite, aucune reference M3/production.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
