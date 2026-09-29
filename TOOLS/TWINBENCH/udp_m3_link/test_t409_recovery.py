"""Sequence/reconnect recovery test for the local FMU gateway."""
from __future__ import annotations

import socket
import subprocess
import sys
import time
from pathlib import Path

from m3_binary_protocol import HOST, PORT, pack_command, unpack_plant

HERE = Path(__file__).resolve().parent
GATEWAY = HERE / "udp_m3_fmu_gateway.py"


def exchange(sock: socket.socket, sequence: int):
    sock.sendto(pack_command(sequence, 1, 40.0, True, time.time_ns()), (HOST, PORT))
    payload, _ = sock.recvfrom(128)
    return unpack_plant(payload)


def main() -> int:
    proc = subprocess.Popen([sys.executable, str(GATEWAY), "--duration-s", "10"], cwd=str(HERE))
    try:
        time.sleep(3.0)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((HOST, 0))
            sock.settimeout(1.0)
            first = exchange(sock, 100)
            time.sleep(1.2)  # interruption autorisant la reconnexion / reset compteur
            recovered = exchange(sock, 0)
            latest = recovered
            for seq in range(1, 101):
                latest = exchange(sock, seq)
                time.sleep(0.01)
            time.sleep(1.2)
            exchange(sock, 0xFFFFFFFE)
            exchange(sock, 0xFFFFFFFF)
            wrapped = exchange(sock, 0)
        # response[3] is the gateway sequence; response[4] echoes command sequence.
        # Mot 1 = Trémie : la cote doit décroître après ouverture du frein (AF-P11).
        ok = (recovered[3] == 0 and recovered[4] == 0 and wrapped[3] == 0
              and wrapped[4] == 0 and recovered[6] <= 5000 and latest[15] < first[15])
        print(f"[T409] recovery first_seq={first[3]} recovered_seq={recovered[3]} wrap_seq={wrapped[3]} position_mm={first[15]}->{latest[15]} measured_x100={latest[6]}")
        print("[PASS] T409 reconnect sequence reset" if ok else "[FAIL] T409 reconnect sequence reset")
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
