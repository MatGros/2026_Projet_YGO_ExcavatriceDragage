"""Serveur local T407 : UDP loopback -> plante M3 FMU -> UDP loopback.

Il ne contacte jamais CODESYS. L'autre extrémité est nécessairement un script
exécuté dans l'IDE CODESYS déjà connecté par l'humain à Control Win local.
"""

from __future__ import annotations

import argparse
import socket
import statistics
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE_POC = HERE.parent / "modelica_poc_m3" / "live_poc"
if str(LIVE_POC) not in sys.path:
    sys.path.insert(0, str(LIVE_POC))

from engine import M3FmuEngine  # noqa: E402
from protocol import (  # noqa: E402
    HOST,
    PORT,
    FrameError,
    control_word_to_direction,
    decode,
    encode,
    make_plant_image,
    validate_command,
)


def percentile(values: list[float], value: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * value))
    return ordered[index]


def run(duration_s: float) -> int:
    engine = M3FmuEngine()
    accepted = rejected = 0
    previous_sequence = None
    latencies_ms: list[float] = []
    started = time.monotonic()
    print("[T407] Plante M3 OpenModelica prete : udp://{}:{} (loopback seulement)".format(HOST, PORT), flush=True)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((HOST, PORT))
            sock.settimeout(0.20)
            while time.monotonic() - started < duration_s:
                try:
                    payload, address = sock.recvfrom(65535)
                except socket.timeout:
                    continue
                if address[0] != HOST:
                    rejected += 1
                    continue
                received_ns = time.monotonic_ns()
                try:
                    command = decode(payload)
                    validate_command(command, previous_sequence)
                    previous_sequence = command["sequence"]
                    snapshot = engine.step(
                        control_word_to_direction(command["control_word"]),
                        float(command["frequency_hz"]),
                        bool(command["brake_release_cmd"]),
                    )
                    response = make_plant_image(accepted, command, snapshot)
                    response["gateway_timestamp_ns"] = received_ns
                    sock.sendto(encode(response), address)
                    accepted += 1
                    latencies_ms.append((time.monotonic_ns() - received_ns) / 1_000_000.0)
                except (FrameError, OSError, ValueError) as exc:
                    rejected += 1
                    print("[T407] Trame rejetee : {}".format(exc), flush=True)
    finally:
        engine.close()

    print("[T407] RAPPORT plante : accepte={} rejete={} calc_ms p50={:.3f} p95={:.3f} p99={:.3f} max={:.3f}".format(
        accepted, rejected, percentile(latencies_ms, 0.50), percentile(latencies_ms, 0.95),
        percentile(latencies_ms, 0.99), max(latencies_ms, default=0.0)), flush=True)
    return 0 if accepted else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=45.0)
    arguments = parser.parse_args()
    raise SystemExit(run(arguments.duration_s))
