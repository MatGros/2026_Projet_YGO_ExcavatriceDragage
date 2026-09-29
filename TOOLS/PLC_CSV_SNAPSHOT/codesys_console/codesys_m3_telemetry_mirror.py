# -*- coding: utf-8 -*-
"""Miroir CODESYS -> animation M3, lecture seule.

A lancer dans Tools > Scripting sur la copie Control Win ONLINE.
Ce script ne lit que les variables et émet des trames vers le loopback local.
"""
import socket
import struct
import time


HOST = "127.0.0.1"
PORT = 29072
PERIOD_S = 0.05
DEFAULT_DURATION_S = 300.0
MAGIC = b"M3B1"
PLANT_FORMAT = "<4sBBIIHHhBB5BiiB3x"

PATHS = (
    "PRG_T409_M3_FmuBridge.FmuPosition_M",
    "PRG_T409_M3_FmuBridge.FmuVelocity_Mps",
    "PRG_T409_M3_FmuBridge.FmuFrequency_Hz",
    "GVL_Troubleshooting.L_TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz",
    "GVL_Simulation.SimM3OpenModelica.M3_BrakeIsOpen_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_StatusWord",
    "GVL_Simulation.SimM3OpenModelica.M3_PosTremie_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosPV_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosPVP2_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosP1_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosMaintenance_DI",
    "PRG_T409_M3_FmuBridge.FmuState",
    "PRG_T409_M3_FmuBridge.LinkReady",
    "PRG_T409_M3_FmuBridge.Timeout",
)


def _number(value):
    text = str(value).strip().upper()
    if "#" in text:
        text = text.split("#", 1)[1]
    return float(text)


def _bool(value):
    return str(value).strip().upper() in ("TRUE", "1")


def _read_values(online_app):
    try:
        values = list(online_app.read_values(PATHS))
        if len(values) == len(PATHS):
            return values
    except Exception:
        pass
    values = []
    for path in PATHS:
        single = list(online_app.read_values((path,)))
        if len(single) != 1:
            raise RuntimeError("expression invalide: " + path)
        values.append(single[0])
    return values


def _pack(sequence, values):
    position = int(round(_number(values[0]) * 1000.0))
    velocity = int(round(_number(values[1]) * 1000.0))
    measured_hz = max(0, min(5000, int(round(_number(values[2]) * 100.0))))
    requested_hz = max(0, min(5000, int(round(_number(values[3]) * 100.0))))
    brake = 1 if _bool(values[4]) else 0
    status = int(_number(values[5])) & 0xFF
    sensors = tuple(1 if _bool(value) else 0 for value in values[6:11])
    hard_stop = 1 if int(_number(values[11])) == 4 else 0
    return struct.pack(
        PLANT_FORMAT, MAGIC, 1, 2, sequence, sequence,
        requested_hz, measured_hz, max(-32768, min(32767, velocity)),
        brake, status, sensors[0], sensors[1], sensors[2], sensors[3], sensors[4],
        max(-2147483648, min(2147483647, position)), measured_hz, hard_stop)


def run_mirror(duration_s):
    application = projects.primary.active_application
    online_app = online.create_online_application(application)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sent = 0
    started_all = time.time()
    try:
        with online_app:
            if not online_app.is_logged_in:
                raise RuntimeError("Faire Login sur la copie Control Win avant le miroir")
            deadline = time.time() + duration_s
            while time.time() < deadline:
                started = time.time()
                values = _read_values(online_app)
                if _bool(values[12]) and not _bool(values[13]):
                    sock.sendto(_pack(sent, values), (HOST, PORT))
                    sent += 1
                remaining = PERIOD_S - (time.time() - started)
                if remaining > 0:
                    time.sleep(remaining)
    finally:
        sock.close()
    elapsed = max(0.001, time.time() - started_all)
    print("PASS miroir M3: {} trames lecture seule vers {}:{} ({:.1f} trames/s)".format(
        sent, HOST, PORT, sent / elapsed))


try:
    requested_duration = T412_DURATION_S
except NameError:
    requested_duration = DEFAULT_DURATION_S

run_mirror(float(requested_duration))
