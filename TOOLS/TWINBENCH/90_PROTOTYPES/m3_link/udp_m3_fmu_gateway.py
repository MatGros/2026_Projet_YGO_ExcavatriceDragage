"""T409: native binary UDP gateway between Control Win and the M3 FMU."""
from __future__ import annotations
import argparse
import csv
import socket
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE = HERE.parents[1] / "02_SIM" / "modelica" / "live_poc"
if str(LIVE) not in sys.path:
    sys.path.insert(0, str(LIVE))
from engine import M3FmuEngine
from m3_binary_protocol import (ECHO_UI, ECHO_UI_MAGIC, HOST, PORT, decode_plc_echo, echo_bytes,
                                pack_plant, plc_echo_summary, unpack_command)
from sequence_rules import is_acceptable

def run(duration_s: float, trace_file: str | None = None,
        listen_port: int = PORT, ui_port: int = 29072) -> int:
    engine = M3FmuEngine()
    accepted = rejected = 0
    previous = None
    previous_received_at = None
    started = time.monotonic()
    last_report = started
    last_snapshot = None
    last_echo_summary = None
    print(f"[T409] FMU M3 prete : udp://{HOST}:{listen_port} (loopback seulement)", flush=True)
    trace = None
    writer = None
    if trace_file:
        trace = open(trace_file, "w", newline="", encoding="utf-8")
        writer = csv.writer(trace)
        writer.writerow(("wall_time_s", "sequence", "command_word", "requested_hz",
                         "measured_hz", "velocity_mps", "position_m", "brake_open",
                         "status_word", "sensors_word", "hard_stop",
                         "plc_mode", "plc_maint_target_enable", "plc_maint_zone_access",
                         "plc_fb_state", "plc_block_reason", "plc_active_tremie",
                         "plc_active_maintenance", "plc_last_point", "plc_limit_tremie",
                         "plc_limit_maintenance", "plc_estimated_pos_m", "plc_safe_stop",
                         "plc_power_cutoff", "plc_safety_error_id", "plc_link_ready"))
        trace.flush()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, listen_port))
    sock.settimeout(0.20)
    ui_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) if ui_port else None
    try:
        while duration_s <= 0 or time.monotonic() - started < duration_s:
            try:
                payload, address = sock.recvfrom(128)
            except socket.timeout:
                if time.monotonic() - last_report >= 5.0:
                    print(f"[T409] ETAT gateway : accepte={accepted} rejete={rejected} derniere_sequence={previous if previous is not None else 'aucune'}", flush=True)
                    last_report = time.monotonic()
                continue
            if address[0] != HOST:
                rejected += 1
                continue
            try:
                seq, word, hz, brake, _timestamp = unpack_command(payload)
                raw_echo = echo_bytes(payload)
                echo = decode_plc_echo(raw_echo)
                # Journal sur changement d'état seulement : la position estimée varie en continu
                # et n'est pas un critère de changement (elle reste dans la ligne et dans la trace).
                state_key = None if echo is None else tuple(v for k, v in sorted(echo.items())
                                                            if k != "estimated_pos_m")
                if state_key != last_echo_summary:
                    print(f"[PLC] {plc_echo_summary(echo)}", flush=True)
                    last_echo_summary = state_key
                if ui_sock is not None and echo is not None:
                    try:
                        ui_sock.sendto(ECHO_UI.pack(ECHO_UI_MAGIC, seq & 0xFFFFFFFF, raw_echo), (HOST, ui_port))
                    except OSError:
                        pass
                now = time.monotonic()
                stale = previous_received_at is None or now - previous_received_at > 1.0
                if not is_acceptable(previous, seq, stale):
                    raise ValueError("sequence")
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
                # Copie locale en lecture seule de la même réponse FMU ; aucune
                # requête ni charge réseau additionnelle vers CODESYS/PLC.
                if ui_sock is not None:
                    try:
                        ui_sock.sendto(response, (HOST, ui_port))
                    except OSError as exc:
                        print(f"[T409] publication IHM indisponible : {exc}", flush=True)
                if writer is not None:
                    sensors_word = sum((int(bool(v)) << shift) for shift, v in zip(
                        (4, 3, 2, 1, 0), (snapshot.tremie, snapshot.pv, snapshot.p2,
                                           snapshot.p1, snapshot.maintenance)))
                    if echo is None:
                        echo_cols = ("",) * 15
                    else:
                        last_point = next((label for key, label in (("at_tremie", "TREMIE"), ("at_pv", "PV"),
                                           ("at_p2", "P2"), ("at_p1", "P1"), ("at_maintenance", "MAINT"))
                                           if echo[key]), "")
                        echo_cols = (echo["mode"], int(echo["maint_target_enable"]), int(echo["maint_zone_access"]),
                                     echo["fb_state"], echo["block_reason"], int(echo["active_tremie"]),
                                     int(echo["active_maintenance"]), last_point, int(echo["limit_tremie"]),
                                     int(echo["limit_maintenance"]), echo["estimated_pos_m"], int(echo["safe_stop"]),
                                     int(echo["power_cutoff"]), echo["safety_error_id"], int(echo["link_ready"]))
                    writer.writerow((time.monotonic(), seq, word, hz, snapshot.frequency_act_hz,
                                     snapshot.velocity_mps, snapshot.position_m,
                                     int(snapshot.brake_is_open), snapshot.drive_status_word,
                                     sensors_word, int(snapshot.hard_stop_tremie or snapshot.hard_stop_maintenance))
                                    + echo_cols)
                    trace.flush()
                accepted += 1
                if time.monotonic() - last_report >= 5.0:
                    print(f"[T409] ETAT gateway : accepte={accepted} rejete={rejected} derniere_sequence={previous} pos={snapshot.position_m:.3f}m vel={snapshot.velocity_mps:.3f}mps hz={snapshot.frequency_act_hz:.2f} frein={int(snapshot.brake_is_open)} capteurs={int(snapshot.tremie)}{int(snapshot.pv)}{int(snapshot.p2)}{int(snapshot.p1)}{int(snapshot.maintenance)}", flush=True)
                    last_report = time.monotonic()
            except (ValueError, OSError) as exc:
                rejected += 1
                print(f"[T409] rejet : {exc}", flush=True)
    finally:
        sock.close()
        if ui_sock is not None:
            ui_sock.close()
        engine.close()
        if trace is not None:
            trace.close()
    print(f"[T409] RAPPORT FMU : accepte={accepted} rejete={rejected}", flush=True)
    return 0 if accepted else 2

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration-s", type=float, default=0.0,
                        help="0 = fonctionnement illimité (Ctrl+C pour arrêter)")
    parser.add_argument("--trace-file", default=None)
    parser.add_argument("--listen-port", type=int, default=PORT)
    parser.add_argument("--ui-port", type=int, default=29072,
                        help="port de télémétrie locale IHM; 0 désactive la copie")
    args = parser.parse_args()
    raise SystemExit(run(args.duration_s, args.trace_file, args.listen_port, args.ui_port))
