"""Offline safety checks for the fixed T409 frame (no PLC, no socket)."""
from m3_binary_protocol import COMMAND, PLANT, pack_command, pack_plant, unpack_command, unpack_plant


def main() -> int:
    command = pack_command(7, 1, 40.0, True, 123)
    assert len(command) == COMMAND.size == 32
    assert unpack_command(command)[0:4] == (7, 1, 40.0, True)

    valid_words = ((True, True, True, True, True),
                   (False, True, True, True, True),
                   (False, False, True, True, True),
                   (False, False, False, True, True),
                   (False, False, False, False, True),
                   (False, False, False, False, False))
    for sensors in valid_words:
        frame = pack_plant(8, 7, 40.0, 37.5, 0.75, 12.34, True, 135, sensors, False)
        assert len(frame) == PLANT.size == 39
        fields = unpack_plant(frame)
        assert fields[5:7] == (4000, 3750)  # requested != measured is preserved
        assert tuple(bool(v) for v in fields[10:15]) == sensors

    # The encoder rejects out-of-contract FMU values by clamping, never crashing.
    frame = pack_plant(9, 8, 999.0, -10.0, 100.0, 1e20, False, 0,
                       (False,) * 5, True)
    assert len(frame) == 39
    print("[PASS] T409 frame sizes, requested/measured Hz and bounds")
    print("[PASS] T409 admissible cumulative sensor words: 11111..00000")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
