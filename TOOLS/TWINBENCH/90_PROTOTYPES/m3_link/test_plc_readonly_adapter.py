"""Tests locaux de l'adaptateur PLC lecture seule."""
from __future__ import annotations

import socket
import time

from m3_binary_protocol import HOST, PLANT, pack_plant
from plc_readonly_adapter import UdpPlantReadOnlyAdapter


def main() -> int:
    port = 29172
    adapter = UdpPlantReadOnlyAdapter(port=port, stale_after_s=0.05)
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        initial = adapter.poll()
        assert initial.stale and initial.source == "PLC_READONLY"
        sender.sendto(b"x" * 200, (HOST, port))
        adapter.poll()
        invalid = bytearray(pack_plant(99, 99, 40.0, 20.0, -0.4, 99.0, True, 128,
                                       (False, False, True, True, True), False))
        invalid[14] = 0x70
        invalid[15] = 0x17
        sender.sendto(bytes(invalid), (HOST, port))
        adapter.poll()
        for sequence in range(7, 17):
            sender.sendto(pack_plant(sequence, sequence, 40.0, 20.0, -0.4,
                                     12.345 + sequence, True, 128,
                                     (False, False, True, True, True), False),
                          (HOST, port))
        deadline = time.monotonic() + 1.0
        state = initial
        while time.monotonic() < deadline and state.stale:
            state = adapter.poll()
            time.sleep(0.005)
        assert not state.stale
        assert state.position_m == 12.345 + 16
        assert state.measured_frequency_hz == 20.0
        assert state.sensors == (False, False, True, True, True)
        time.sleep(0.06)
        assert adapter.state().stale
        sender.sendto(pack_plant(0, 0, 20.0, 10.0, 0.2, 2.0, True, 128,
                                 (False, False, False, False, True), False),
                      (HOST, port))
        recovered = adapter.poll()
        assert not recovered.stale and recovered.sequence == 0 and recovered.position_m == 2.0
        time.sleep(0.06)
        sender.sendto(pack_plant(0xFFFFFFFE, 0xFFFFFFFE, 20.0, 10.0, 0.2, 3.0,
                                 True, 128, (False, False, False, False, True), False),
                      (HOST, port))
        adapter.poll()
        sender.sendto(pack_plant(0xFFFFFFFF, 0xFFFFFFFF, 20.0, 10.0, 0.2, 3.1,
                                 True, 128, (False, False, False, False, True), False),
                      (HOST, port))
        adapter.poll()
        sender.sendto(pack_plant(0, 0, 20.0, 10.0, 0.2, 3.2,
                                 True, 128, (False, False, False, False, True), False),
                      (HOST, port))
        wrapped = adapter.poll()
        assert not wrapped.stale and wrapped.sequence == 0 and wrapped.position_m == 3.2
        print("[PASS] PLC read-only adapter: rafale, stale et resynchronisation")
        return 0
    finally:
        sender.close()
        adapter.close()


if __name__ == "__main__":
    raise SystemExit(main())
