"""Tests du décodage INT16 signé de vitesse dans le bridge T409, hors PLC."""
from pathlib import Path


def decode_st_int16(low_byte: int, high_byte: int) -> int:
    raw = low_byte | (high_byte << 8)
    return raw - 65536 if raw >= 32768 else raw


def main() -> int:
    assert decode_st_int16(0x70, 0xFE) == -400
    assert decode_st_int16(0x18, 0xFC) == -1000
    assert decode_st_int16(0x90, 0x01) == 400
    source = (Path(__file__).with_name("PRG_T409_M3_FmuBridge_IMPLEMENTATION.st")
              .read_text(encoding="utf-8"))
    assert "RxVelocity_x1000 >= 32768" in source
    assert "RxVelocity_x1000 := RxVelocity_x1000 - 65536" in source
    print("[PASS] T409 vitesse INT16 : -0.400, -1.000 et +0.400 m/s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
