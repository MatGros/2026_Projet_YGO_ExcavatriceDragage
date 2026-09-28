"""Local FMU gateway round-trip test. Loopback only; never contacts a PLC."""
from __future__ import annotations

import socket
import subprocess
import sys
import time
from pathlib import Path

from m3_binary_protocol import HOST, PORT, pack_command, unpack_plant

HERE = Path(__file__).resolve().parent
GATEWAY = HERE / "udp_m3_fmu_gateway.py"


def main() -> int:
    proc = subprocess.Popen(
        [sys.executable, str(GATEWAY), "--duration-s", "8"],
        cwd=str(HERE), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True,
    )
    received = []
    rejected = 0
    try:
        time.sleep(3.0)  # chargement FMU/OMSimulator avant l'envoi UDP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((HOST, 0))
            sock.settimeout(0.25)
            for seq in range(100):
                sock.sendto(pack_command(seq, 1, 40.0, True, time.time_ns()), (HOST, PORT))
                try:
                    payload, _ = sock.recvfrom(128)
                    received.append((seq, unpack_plant(payload)))
                except (socket.timeout, ConnectionResetError):
                    rejected += 1
                time.sleep(0.01)
        seqs = [seq for seq, _ in received]
        frames = [frame for _, frame in received]
        sensor_words = {
            sum((int(bool(v)) << shift) for shift, v in zip((4, 3, 2, 1, 0), frame[10:15]))
            for frame in frames
        }
        ok = (
            len(received) == 100 and rejected == 0 and seqs == list(range(100))
            and sensor_words <= {31, 15, 7, 3, 1, 0}
            and all(0 <= frame[6] <= 5000 for frame in frames)
        )
        print(f"[T409] roundtrip responses={len(received)} timeouts={rejected} sensor_words={sorted(sensor_words)}")
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
