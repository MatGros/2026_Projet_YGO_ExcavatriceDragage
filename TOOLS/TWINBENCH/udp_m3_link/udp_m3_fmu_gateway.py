"""T409: native binary UDP gateway between Control Win and the M3 FMU."""
from __future__ import annotations
import argparse
import csv
import socket
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE = HERE.parent / "modelica_poc_m3" / "live_poc"
if str(LIVE) not in sys.path:
    sys.path.insert(0, str(LIVE))
from engine import M3FmuEngine
from m3_binary_protocol import HOST, PORT, pack_plant, unpack_command

def run(duration_s: float, trace_file: str | None = None) -> int:
    engine = M3FmuEngine()
    accepted = rejected = 0
    previous = None
    previous_received_at = None
    started = time.time()
    last_report = started
    last_snapshot = None
    print(f"[T409] FMU M3 prete : udp://{HOST}:{PORT} (loopback seulement)", flush=True)
    trace = None
    writer = None
    if trace_file:
        trace = open(trace_file, "w", newline="", encoding="utf-8")
        writer = csv.writer(trace)
        writer.writerow(("wall_time_s", "sequence", "command_word", "requested_hz",
                         "measured_hz", "velocity_mps", "position_m", "brake_open",
                         "status_word", "sensors_word", "hard_stop"))
        trace.flush()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))
    sock.settimeout(0.20)
    try:
        while time.time() - started < duration_s:
            try:
                payload, address = sock.recvfrom(128)
            except socket.timeout:
                if time.time() - last_report >= 5.0:
                    print(f"[T409] ETAT gateway : accepte={accepted} rejete={rejected} derniere_sequence={previous if previous is not None else 'aucune'}", flush=True)
                    last_report = time.time()
                continue
            if address[0] != HOST:
                rejected += 1
                continue
            try:
                seq, word, hz, brake, _timestamp = unpack_command(payload)
                now = time.time()
                # Une coupure/reconnexion du POU peut remettre son compteur a
                # zero. On n accepte ce reset qu apres une interruption > 1 s.
                if previous is not None and seq <= previous:
                    if previous_received_at is None or now - previous_received_at <= 1.0:
                        raise ValueError("sequence")
                    previous = None
                previous = seq
                previous_received_at = now
                # Convention AF-P11 : mot 1 = Trémie (cote décroissante),
                # mot 2 = Maintenance (cote croissante). Le modèle FMU
                # utilise +1 pour une cote croissante.
                direction = -1.0 if word == 1 else (1.0 if word == 2 else 0.0)
                snapshot = engine.step(direction, hz, brake)
                last_snapshot = snapshot
                response = pack_plant(seq, seq, hz, snapshot.frequency_act_hz, snapshot.velocity_mps,
                                      snapshot.position_m, snapshot.brake_is_open,
                                      snapshot.drive_status_word, (snapshot.tremie, snapshot.pv,
                                      snapshot.p2, snapshot.p1, snapshot.maintenance),
                                      snapshot.hard_stop_tremie or snapshot.hard_stop_maintenance)
                sock.sendto(response, address)
                if writer is not None:
                    sensors_word = sum((int(bool(v)) << shift) for shift, v in zip(
                        (4, 3, 2, 1, 0), (snapshot.tremie, snapshot.pv, snapshot.p2,
                                           snapshot.p1, snapshot.maintenance)))
                    writer.writerow((time.time(), seq, word, hz, snapshot.frequency_act_hz,
                                     snapshot.velocity_mps, snapshot.position_m,
                                     int(snapshot.brake_is_open), snapshot.drive_status_word,
                                     sensors_word, int(snapshot.hard_stop_tremie or snapshot.hard_stop_maintenance)))
                    trace.flush()
                accepted += 1
                if time.time() - last_report >= 5.0:
                    print(f"[T409] ETAT gateway : accepte={accepted} rejete={rejected} derniere_sequence={previous} pos={snapshot.position_m:.3f}m vel={snapshot.velocity_mps:.3f}mps hz={snapshot.frequency_act_hz:.2f} frein={int(snapshot.brake_is_open)} capteurs={int(snapshot.tremie)}{int(snapshot.pv)}{int(snapshot.p2)}{int(snapshot.p1)}{int(snapshot.maintenance)}", flush=True)
                    last_report = time.time()
            except (ValueError, OSError) as exc:
                rejected += 1
                print(f"[T409] rejet : {exc}", flush=True)
    finally:
        sock.close()
        engine.close()
        if trace is not None:
            trace.close()
    print(f"[T409] RAPPORT FMU : accepte={accepted} rejete={rejected}", flush=True)
    return 0 if accepted else 2

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=300.0)
    parser.add_argument("--trace-file", default=None)
    args = parser.parse_args()
    raise SystemExit(run(args.duration_s, args.trace_file))
