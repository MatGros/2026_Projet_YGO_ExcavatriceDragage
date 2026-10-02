"""T408 — echo UDP binaire loopback pour le POC natif Control Win."""

from __future__ import annotations

import argparse
import select
import socket
import time

HOST = "127.0.0.1"
PORTS = {29031: "rapide", 29041: "cyclique", 29051: "evenement"}
MAGIC = b"TB08"


def percentile(values: list[float], ratio: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * ratio))]


def run(duration_s: float) -> int:
    stats = {name: {"received": 0, "invalid": 0, "missing": 0, "prior_sequence": None,
                    "prior_at": None, "intervals_ms": []} for name in PORTS.values()}
    deadline = time.monotonic() + duration_s
    sockets = []
    try:
        for port in PORTS:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.bind((HOST, port))
            sockets.append(sock)
        print("[T408] Echo UDP pret : {}:{} / {} / {}".format(HOST, *PORTS.keys()), flush=True)
        while time.monotonic() < deadline:
            readable, _, _ = select.select(sockets, [], [], 0.2)
            if not readable:
                continue
            for sock in readable:
                payload, address = sock.recvfrom(64)
                name = PORTS[sock.getsockname()[1]]
                item = stats[name]
                now = time.monotonic()
                if address[0] != HOST or len(payload) != 16 or payload[:4] != MAGIC:
                    item["invalid"] += 1
                    continue
                sequence = payload[4] | (payload[5] << 8)
                if item["prior_sequence"] is not None:
                    gap = (sequence - item["prior_sequence"] - 1) & 0xFFFF
                    if gap < 1000:
                        item["missing"] += gap
                item["prior_sequence"] = sequence
                if item["prior_at"] is not None:
                    item["intervals_ms"].append((now - item["prior_at"]) * 1000.0)
                item["prior_at"] = now
                item["received"] += 1
                sock.sendto(payload, address)
    finally:
        for sock in sockets:
            sock.close()
    for name in ("rapide", "cyclique", "evenement"):
        item = stats[name]
        values = item["intervals_ms"]
        print("[T408] RAPPORT {} : recues={} manquantes={} invalides={} intervalle_ms p50={:.3f} p95={:.3f} p99={:.3f} max={:.3f}".format(
            name, item["received"], item["missing"], item["invalid"], percentile(values, 0.50),
            percentile(values, 0.95), percentile(values, 0.99), max(values, default=0.0)), flush=True)
    return 0 if stats["rapide"]["received"] else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=75.0)
    args = parser.parse_args()
    raise SystemExit(run(args.duration_s))
