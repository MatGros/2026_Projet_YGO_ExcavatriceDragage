# -*- coding: utf-8 -*-
"""POC T402 — échange ponctuel avec M3 dans la Simulation IDE CODESYS.

Exécution dans Tools > Scripting uniquement. Le mode par défaut ``probe`` est
strictement en lecture. ``pulse_maintenance`` écrit brièvement le bouton de
simulation Maintenance, puis le restaure dans un bloc finally.
"""

import time


ACTION_PROBE = "probe"
ACTION_PULSE_MAINTENANCE = "pulse_maintenance"
WRITE_PATH = "GVL_Simulation.SimBtnMaintenance"
PULSE_DURATION_S = 0.75

PRECONDITION_PATHS = (
    "GVL_Simulation.SimulationModeActive",
    "GVL_Simulation.SimTranslationActive",
)

COMMAND_PATHS = (
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx501_CmdDriveControlWord",
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz",
    "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ",
)

FEEDBACK_PATHS = (
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx101_PosTremie_DI",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx102_PosPV_DI",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx103_PosP2_DI",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx107_DriveStatusWord",
    "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx108_BrakeApplied",
)


def _bool_value(raw_value):
    return str(raw_value).strip().upper() in ("TRUE", "1")


def _find_device(application):
    current = application
    for _unused in range(12):
        if current is None:
            break
        getter = getattr(current, "get_simulation_mode", None)
        if hasattr(getter, "__call__"):
            return current
        current = getattr(current, "parent", None)
    raise RuntimeError("Device parent introuvable depuis l'application active")


def _read_map(online_app, paths):
    values = list(online_app.read_values(tuple(paths)))
    if len(values) != len(paths):
        raise RuntimeError("read_values: {} valeurs pour {} chemins".format(len(values), len(paths)))
    return dict(zip(paths, values))


def _print_snapshot(label, online_app):
    print("\n=== {} ===".format(label))
    snapshot = _read_map(online_app, COMMAND_PATHS + FEEDBACK_PATHS)
    print("COMMANDES PLC")
    for path in COMMAND_PATHS:
        print("  {} = {}".format(path, snapshot[path]))
    print("RETOURS PLANTE SIMULEE")
    for path in FEEDBACK_PATHS:
        print("  {} = {}".format(path, snapshot[path]))


def _require_simulation(application, online_app):
    device = _find_device(application)
    if not bool(device.get_simulation_mode()):
        raise RuntimeError("REFUS: le Device CODESYS n'est pas en mode Simulation IDE")
    flags = _read_map(online_app, PRECONDITION_PATHS)
    for path in PRECONDITION_PATHS:
        if not _bool_value(flags[path]):
            raise RuntimeError("REFUS: {} doit etre TRUE (lu: {})".format(path, flags[path]))


def _wait_button_state(online_app, expected, timeout_s=1.5):
    """Attend la propagation cyclique de l'écriture dans le runtime CODESYS."""
    deadline = time.time() + timeout_s
    last_readback = None
    while time.time() < deadline:
        last_readback = online_app.read_value(WRITE_PATH)
        if _bool_value(last_readback) == bool(expected):
            return last_readback
        time.sleep(0.1)
    raise RuntimeError("Ecriture non confirmee: {} lu {}".format(WRITE_PATH, last_readback))


def _write_sim_button(online_app, value):
    online_app.set_prepared_value(WRITE_PATH, "TRUE" if value else "FALSE")
    online_app.write_prepared_values()
    _wait_button_state(online_app, value)


def run_poc(action):
    if action not in (ACTION_PROBE, ACTION_PULSE_MAINTENANCE):
        raise ValueError("POC_ACTION invalide: {}".format(action))

    application = projects.primary.active_application
    online_app = online.create_online_application(application)
    with online_app:
        if not online_app.is_logged_in:
            raise RuntimeError("Faire Login dans CODESYS avant de lancer le POC")

        _print_snapshot("LECTURE INITIALE", online_app)
        if action == ACTION_PROBE:
            print("\nPASS T402 PROBE: lecture CODESYS reussie, aucune ecriture.")
            return

        _require_simulation(application, online_app)
        if _bool_value(online_app.read_value(WRITE_PATH)):
            raise RuntimeError("REFUS: {} est deja TRUE avant le test".format(WRITE_PATH))

        write_started = False
        try:
            _write_sim_button(online_app, True)
            write_started = True
            time.sleep(PULSE_DURATION_S)
            _print_snapshot("PENDANT IMPULSION MAINTENANCE", online_app)
        finally:
            if write_started:
                _write_sim_button(online_app, False)

        if _bool_value(online_app.read_value(WRITE_PATH)):
            raise RuntimeError("ECHEC: le bouton Maintenance n'est pas revenu a FALSE")
        _print_snapshot("APRES RESTAURATION", online_app)
        print("\nPASS T402 ROUNDTRIP: ecriture lue puis restauree, sans forcage.")


try:
    requested_action = POC_ACTION
except NameError:
    requested_action = ACTION_PROBE

run_poc(requested_action)
