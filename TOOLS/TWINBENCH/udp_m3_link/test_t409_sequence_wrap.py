"""Régressions de séquence : stale/restart et wrap UDINT pour T409."""
from __future__ import annotations

from sequence_rules import is_acceptable, is_strictly_newer


def bridge_st_accepts(last: int, response: int, command: int, rx_count: int) -> bool:
    newer = command > last and response > last
    if last == 0xFFFFFFFF and command == 0 and response == 0:
        newer = True
    return rx_count == 0 or newer


def main() -> int:
    assert is_strictly_newer(10, 11)
    assert not is_strictly_newer(10, 10)
    assert not is_strictly_newer(10, 9)
    assert is_strictly_newer(0xFFFFFFFF, 0)
    assert is_acceptable(110, 0, True)
    assert not is_acceptable(110, 0, False)
    assert bridge_st_accepts(0xFFFFFFFF, 0, 0, 1)
    assert not bridge_st_accepts(100, 0, 0, 1)

    bridge = ("PRG_T409_M3_FmuBridge_IMPLEMENTATION.st")
    source = (__import__("pathlib").Path(__file__).with_name(bridge)
              .read_text(encoding="utf-8"))
    assert "16#FFFFFFFF" in source and "RxSequence = 0" in source
    print("[PASS] T409 séquence : restart après stale et wrap FFFFFFFF -> 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
