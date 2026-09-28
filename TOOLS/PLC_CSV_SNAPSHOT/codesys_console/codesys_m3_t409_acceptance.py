# -*- coding: utf-8 -*-
"""T409 Control Win acceptance probe, read-only.

Run inside CODESYS Tools > Scripting while ONLINE on the TwinBench copy.
No PLC variable is written by this script.
"""

DEFAULT_PATHS = (
    "PRG_T409_M3_FmuBridge.LinkReady",
    "PRG_T409_M3_FmuBridge.Timeout",
    "PRG_T409_M3_FmuBridge.LinkInvalid",
    "PRG_T409_M3_FmuBridge.SensorWordIncoherent",
    "PRG_T409_M3_FmuBridge.FmuPosition_M",
    "PRG_T409_M3_FmuBridge.FmuVelocity_Mps",
    "PRG_T409_M3_FmuBridge.FmuFrequency_Hz",
    "GVL_Simulation.SimM3OpenModelica.M3_BrakeIsOpen_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosTremie_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosPV_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosPVP2_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosP1_DI",
    "GVL_Simulation.SimM3OpenModelica.M3_PosMaintenance_DI",
)


def _bool(value):
    return str(value).strip().upper() in ("TRUE", "1")


application = projects.primary.active_application
online_app = online.create_online_application(application)
with online_app:
    if not online_app.is_logged_in:
        raise RuntimeError("Faire Login sur la copie Control Win avant le test")
    values = list(online_app.read_values(DEFAULT_PATHS))
    if len(values) != len(DEFAULT_PATHS):
        raise RuntimeError("Lecture T409 incomplete: {} / {}".format(len(values), len(DEFAULT_PATHS)))
    print("=== T409 CONTROL WIN — ACCEPTATION LECTURE SEULE ===")
    print("[SECURITE] Aucune ecriture PLC. Copie Control Win uniquement.")
    for path, value in zip(DEFAULT_PATHS, values):
        print("{} = {}".format(path, value))
    ready = _bool(values[0])
    timeout = _bool(values[1])
    invalid = _bool(values[2])
    incoherent = _bool(values[3])
    brake = _bool(values[7])
    if ready and not timeout and not invalid and not incoherent:
        print("PASS T409: liaison et image capteurs coherentes")
    else:
        print("DIAGNOSTIC T409: LinkReady={} Timeout={} LinkInvalid={} SensorWordIncoherent={} BrakeOpen={}".format(
            ready, timeout, invalid, incoherent, brake))
