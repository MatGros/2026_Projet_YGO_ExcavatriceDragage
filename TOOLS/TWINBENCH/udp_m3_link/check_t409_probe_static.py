"""Garde-fou sur les verdicts de la sonde CODESYS CW-00."""
from __future__ import annotations

from pathlib import Path


PROBE = (Path(__file__).resolve().parents[2] / "PLC_CSV_SNAPSHOT" /
         "codesys_console" / "codesys_m3_t409_acceptance.py")


def main() -> int:
    source = PROBE.read_text(encoding="utf-8")
    checks = {
        "LinkInvalid lu": '"PRG_T409_M3_FmuBridge.LinkInvalid"' in source,
        "LinkInvalid contrôlé dans les deux lectures":
            "not _bool(first[PATHS[2]]) and not _bool(second[PATHS[2]])" in source,
        "PASS_FRONT vérifie le mot capteurs 00011":
            "ready_twice and simulation_ready and sensors_word == 3" in source,
        "PASS_FRONT exclut à P1 la mémoire restaurée":
            "and at_p1 and not at_maintenance and candidate != 3" in source,
    }
    failed = [label for label, passed in checks.items() if not passed]
    for label, passed in checks.items():
        print("[{}] {}".format("PASS" if passed else "FAIL", label))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
