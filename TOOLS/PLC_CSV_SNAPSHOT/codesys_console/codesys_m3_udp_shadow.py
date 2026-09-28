# -*- coding: utf-8 -*-
"""T407 — pont d'observation CODESYS -> UDP loopback -> plante M3 FMU.

A executer uniquement dans Tools > Scripting du projet TwinBench Control Win
deja ONLINE. Cette phase ne comporte volontairement AUCUNE ecriture PLC :
ni image de retours, ni bit de selection, ni commande machine.
"""

import json
import socket
import time


HOST = "127.0.0.1"
PORT = 29030
PERIOD_S = 0.05
DEFAULT_DURATION_S = 30.0
SCHEMA = 1

COMMAND_PATHS = (
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx501_CmdDriveControlWord",
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz",
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ",
)


def _iec_number(value):
    text = str(value).strip().upper()
    if "#" in text:
        text = text.split("#", 1)[1]
    return float(text)


def _word_to_int(value):
    return int(_iec_number(value))


def _bool(value):
    return str(value).strip().upper() in ("TRUE", "1")


def _percentile(values, fraction):
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(round((len(ordered) - 1) * fraction)))]


def _validate_response(frame, sequence):
    if frame.get("kind") != "M3_PlantImage":
        raise RuntimeError("kind reponse invalide")
    if frame.get("schema") != SCHEMA or frame.get("origin") != "OpenModelica":
        raise RuntimeError("schema/origine reponse invalide")
    if frame.get("command_sequence") != sequence or not frame.get("is_valid"):
        raise RuntimeError("sequence/validite reponse invalide")
    sensors = frame.get("sensors")
    if not isinstance(sensors, dict) or set(sensors.keys()) != set(("tremie", "pv", "p2", "p1", "maintenance")):
        raise RuntimeError("image capteurs incomplete")


def run_shadow(duration_s):
    application = projects.primary.active_application
    online_app = online.create_online_application(application)
    with online_app:
        if not online_app.is_logged_in:
            raise RuntimeError("REFUS: faire Login sur la COPIE Control Win avant le test T407")

        print("=== T407 UDP SHADOW — LECTURE SEULE ===")
        print("[SECURITE] Aucune ecriture PLC dans ce script. Cible UDP : 127.0.0.1:29030")
        sent = received = rejected = timeout = 0
        latencies_ms = []
        sequence = 0
        deadline = time.time() + duration_s
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            sock.settimeout(PERIOD_S * 0.8)
            while time.time() < deadline:
                values = list(online_app.read_values(COMMAND_PATHS))
                if len(values) != 3:
                    raise RuntimeError("Lecture commandes M3 incomplete")
                started = time.time()
                frame = {
                    "kind": "M3_CommandImage",
                    "schema": SCHEMA,
                    "origin": "PLC",
                    "sequence": sequence,
                    # IronPython CODESYS 2.7 n expose pas l horloge monotone moderne.
                    # Cette date UTC est aussi celle attendue par la plante T407.
                    "source_timestamp_ns": int(time.time() * 1000000000),
                    "control_word": _word_to_int(values[0]),
                    "frequency_hz": _iec_number(values[1]),
                    "brake_release_cmd": _bool(values[2]),
                }
                sock.sendto(json.dumps(frame, separators=(",", ":")).encode("utf-8"), (HOST, PORT))
                sent += 1
                try:
                    payload, address = sock.recvfrom(65535)
                    if address[0] != HOST:
                        raise RuntimeError("reponse hors loopback")
                    response = json.loads(payload.decode("utf-8"))
                    _validate_response(response, sequence)
                    received += 1
                    latencies_ms.append((time.time() - started) * 1000.0)
                except socket.timeout:
                    timeout += 1
                except (ValueError, RuntimeError) as exc:
                    rejected += 1
                    print("[REJET] {}".format(exc))
                sequence += 1
                remaining = PERIOD_S - (time.time() - started)
                if remaining > 0:
                    time.sleep(remaining)
        finally:
            sock.close()

        print("[T407] RAPPORT shadow : envoyees={} reponses={} timeout={} rejets={} rtt_ms p50={:.3f} p95={:.3f} p99={:.3f} max={:.3f}".format(
            sent, received, timeout, rejected, _percentile(latencies_ms, 0.50),
            _percentile(latencies_ms, 0.95), _percentile(latencies_ms, 0.99), max(latencies_ms) if latencies_ms else 0.0))
        if received == 0:
            raise RuntimeError("ECHEC T407: aucune reponse plante, aucune ecriture PLC effectuee")
        print("PASS T407 SHADOW: liaison UDP loopback observee, sans ecriture PLC.")


try:
    requested_duration = T407_DURATION_S
except NameError:
    requested_duration = DEFAULT_DURATION_S

run_shadow(float(requested_duration))
