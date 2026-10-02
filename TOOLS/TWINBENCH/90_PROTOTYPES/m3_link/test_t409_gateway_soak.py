"""Soak loopback T409. Utiliser --duration-s 1800 pour la preuve 30 min."""
from __future__ import annotations

import argparse
import socket
import subprocess
import sys
import time
from pathlib import Path

from m3_binary_protocol import HOST, PORT, pack_command, unpack_plant

HERE = Path(__file__).resolve().parent
GATEWAY = HERE / "udp_m3_fmu_gateway.py"


def main(duration_s: float) -> int:
    gateway = subprocess.Popen([sys.executable, str(GATEWAY), "--duration-s", str(duration_s + 10.0)], cwd=str(HERE))
    sent = received = timeouts = 0
    started = time.monotonic()
    sequence = 0
    try:
        time.sleep(3.0)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((HOST, 0))
            sock.settimeout(1.0)
            while time.monotonic() - started < duration_s:
                sock.sendto(pack_command(sequence, 1, 40.0, True, time.time_ns()), (HOST, PORT))
                sent += 1
                try:
                    response, _ = sock.recvfrom(128)
                    fields = unpack_plant(response)
                    if fields[3] == sequence:
                        received += 1
                except (socket.timeout, ConnectionResetError):
                    timeouts += 1
                sequence = (sequence + 1) & 0xFFFFFFFF
                target = started + sent * 0.01
                pause = target - time.monotonic()
                if pause > 0:
                    time.sleep(pause)
        ok = sent == received and timeouts == 0
        print("[PASS] T409 soak {} s : {}/{} réponses, {} timeout".format(duration_s, received, sent, timeouts)
              if ok else "[FAIL] T409 soak {} s : {}/{} réponses, {} timeout".format(duration_s, received, sent, timeouts))
        return 0 if ok else 1
    finally:
        gateway.terminate()
        try:
            gateway.wait(timeout=3)
        except subprocess.TimeoutExpired:
            gateway.kill()
            gateway.wait(timeout=3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=5.0)
    args = parser.parse_args()
    raise SystemExit(main(args.duration_s))
