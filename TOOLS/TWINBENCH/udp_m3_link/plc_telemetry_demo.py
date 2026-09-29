"""Source de télémétrie PLC synthétique pour valider l'interface lecture seule."""
from __future__ import annotations

import argparse
import socket
import time

from m3_binary_protocol import HOST, pack_plant


def sensors(position):
    return (position <= 0.0, position <= 5.0, position <= 15.0,
            position <= 20.0, position < 30.0)


def run(duration_s=0.0, period_s=0.05):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    started = time.monotonic()
    sequence = 0
    send_times = []
    try:
        while duration_s <= 0 or time.monotonic() - started < duration_s:
            elapsed = time.monotonic() - started
            phase = (elapsed % 60.0) / 30.0
            phase = phase if phase <= 1.0 else 2.0 - phase
            position = -0.30 + phase * 30.60
            measured_hz = 10.0 + 30.0 * phase
            velocity = 0.02 * measured_hz
            brake_open = True
            at_stop = position <= -0.30 or position >= 30.30
            if at_stop:
                position = max(-0.30, min(30.30, position))
                velocity = 0.0
                measured_hz = 0.0
                brake_open = False
            sock.sendto(pack_plant(sequence, sequence, 25.5, measured_hz,
                                    velocity, position, brake_open, 128,
                                    sensors(position), at_stop),
                        (HOST, 29072))
            sequence += 1
            send_times.append(time.monotonic())
            next_tick = started + sequence * period_s
            delay = next_tick - time.monotonic()
            if delay > 0:
                time.sleep(delay)
    finally:
        sock.close()
    elapsed = max(0.001, time.monotonic() - started)
    print("[PASS] Démo PLC télémétrie terminée : {} trames ({:.1f} trames/s)".format(
        sequence, sequence / elapsed))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=0.0,
                        help="0 = fonctionnement illimité (Ctrl+C pour arrêter)")
    args = parser.parse_args()
    run(args.duration_s)
