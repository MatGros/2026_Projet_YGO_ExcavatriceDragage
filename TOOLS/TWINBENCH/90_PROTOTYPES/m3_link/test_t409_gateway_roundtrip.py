"""Local FMU gateway round-trip test. Loopback only; never contacts a PLC."""
from __future__ import annotations

import socket
import selectors
import subprocess
import sys
import time
from pathlib import Path

from m3_binary_protocol import HOST, pack_command, unpack_plant

HERE = Path(__file__).resolve().parent
GATEWAY = HERE / "udp_m3_fmu_gateway.py"
TEST_PORT = 39161
UI_PORT = 39172


def main() -> int:
    proc = subprocess.Popen(
        [sys.executable, str(GATEWAY), "--duration-s", "8", "--listen-port", str(TEST_PORT), "--ui-port", str(UI_PORT)],
        cwd=str(HERE), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True,
    )
    received: dict[int, bytes] = {}
    mirrored: dict[int, bytes] = {}
    try:
        time.sleep(3.0)  # chargement FMU/OMSimulator avant l'envoi UDP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as ui:
            ui.bind((HOST, UI_PORT))
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind((HOST, 0))
                sock.setblocking(False)
                ui.setblocking(False)
                selector = selectors.DefaultSelector()
                selector.register(sock, selectors.EVENT_READ, "plc")
                selector.register(ui, selectors.EVENT_READ, "ui")
                next_send = time.perf_counter()
                for seq in range(100):
                    delay = next_send - time.perf_counter()
                    if delay > 0:
                        time.sleep(delay)
                    sock.sendto(pack_command(seq, 1, 40.0, True, time.time_ns()), (HOST, TEST_PORT))
                    next_send += 0.01
                deadline = time.perf_counter() + 5.0
                while time.perf_counter() < deadline and (len(received) < 100 or len(mirrored) < 100):
                    for key, _ in selector.select(timeout=0.1):
                        while True:
                            try:
                                payload, _ = key.fileobj.recvfrom(128)
                            except BlockingIOError:
                                break
                            sequence = unpack_plant(payload)[3]
                            target = received if key.data == "plc" else mirrored
                            target[sequence] = payload
                selector.close()
        frames = [unpack_plant(received[seq]) for seq in sorted(received)]
        mismatched = sum(received.get(seq) != mirrored.get(seq) for seq in set(received) | set(mirrored))
        first_position_m = frames[0][15] / 1000.0 if frames else -1.0
        sensor_words = {
            sum((int(bool(v)) << shift) for shift, v in zip((4, 3, 2, 1, 0), frame[10:15]))
            for frame in frames
        }
        ok = (
            len(received) == 100 and len(mirrored) == 100 and mismatched == 0
            and sorted(received) == list(range(100))
            and sensor_words <= {31, 15, 7, 3, 1, 0}
            and all(0 <= frame[6] <= 5000 for frame in frames)
            and abs(first_position_m - 20.0) <= 0.01
            and sensor_words == {3}
        )
        print(f"[T409] roundtrip PLC={len(received)} UI={len(mirrored)} differentes={mismatched} P1_initial={first_position_m:.3f}m capteurs={sorted(sensor_words)}")
        print("[PASS] T409 gateway round-trip 10 ms" if ok else "[FAIL] T409 gateway round-trip 10 ms")
        return 0 if ok else 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)


if __name__ == "__main__":
    raise SystemExit(main())
