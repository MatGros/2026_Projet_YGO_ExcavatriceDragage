# -*- coding: utf-8 -*-
"""CW-00 T409 : preuve lecture seule du départ P1 par mémoire ou par front.

À lancer dans Tools > Scripting, ONLINE sur la copie TwinBench Control Win.
Ce script ne possède aucune API d'écriture, de force ou de téléchargement.
"""
import time


PATHS = (
    "PRG_T409_M3_FmuBridge.LinkReady",
    "PRG_T409_M3_FmuBridge.Timeout",
    "PRG_T409_M3_FmuBridge.LinkInvalid",
    "GVL_Simulation.SimulationModeActive",
    "GVL_Simulation.SimM3OpenModelicaActive",
    "PRG_05_Translation.M3_AtPositionBootRestored",
    "PRG_05_Translation.M3_BootSensorsWordCandidate",
    "PRG_05_Translation.instPosDecoderM3.SensorsWord",
    "PRG_05_Translation.M3_AtP1Stable",
    "PRG_05_Translation.M3_AtMaintenanceStable",
    "GVL_PERSISTENT._TranslationAtP1Persisted",
    "GVL_PERSISTENT._TranslationAtMaintenancePersisted",
)


def _bool(value):
    return str(value).strip().upper() in ("TRUE", "1")


def _integer(value):
    text = str(value).strip().upper()
    if "#" in text:
        prefix, text = text.split("#", 1)
        if prefix == "2":
            return int(text, 2)
    return int(float(text))


def _read_with_fallback(online_app):
    try:
        values = list(online_app.read_values(PATHS))
        if len(values) == len(PATHS):
            return dict(zip(PATHS, values))
    except Exception:
        pass
    values = {}
    for path in PATHS:
        try:
            one = list(online_app.read_values((path,)))
            values[path] = one[0] if len(one) == 1 else "INVALID_READ"
        except Exception as exc:
            values[path] = "INVALID_EXPRESSION: {}".format(exc)
    return values


def _show(label, values):
    print("--- {} ---".format(label))
    for path in PATHS:
        print("{} = {}".format(path, values[path]))


application = projects.primary.active_application
online_app = online.create_online_application(application)
with online_app:
    if not online_app.is_logged_in:
        raise RuntimeError("Faire Login sur la copie Control Win avant CW-00")

    first = _read_with_fallback(online_app)
    _show("LECTURE 1", first)
    time.sleep(2.0)
    second = _read_with_fallback(online_app)
    _show("LECTURE 2", second)

    invalid = [path for path in PATHS if str(first[path]).startswith("INVALID_")
               or str(second[path]).startswith("INVALID_")]
    if invalid:
        print("VERDICT: FAIL — chemins CODESYS non exposés : {}".format(", ".join(invalid)))
    else:
        ready_twice = (_bool(first[PATHS[0]]) and _bool(second[PATHS[0]])
                       and not _bool(first[PATHS[1]]) and not _bool(second[PATHS[1]])
                       and not _bool(first[PATHS[2]]) and not _bool(second[PATHS[2]]))
        simulation_ready = (_bool(second[PATHS[3]]) and _bool(second[PATHS[4]]))
        boot_restored = _bool(second[PATHS[5]])
        candidate = _integer(second[PATHS[6]])
        sensors_word = _integer(second[PATHS[7]])
        at_p1 = _bool(second[PATHS[8]])
        at_maintenance = _bool(second[PATHS[9]])
        p1_persisted = _bool(second[PATHS[10]])
        maintenance_persisted = _bool(second[PATHS[11]])

        if (ready_twice and simulation_ready and boot_restored and candidate == 3
                and sensors_word == 3 and at_p1 and not at_maintenance
                and p1_persisted and not maintenance_persisted):
            print("VERDICT: PASS_MEMOIRE — 00011 stable, P1 restauré par mémoire")
        elif (ready_twice and simulation_ready and sensors_word == 3
              and at_p1 and not at_maintenance and candidate != 3):
            print("VERDICT: PASS_FRONT_ORDRE_KO — P1 obtenu par front capteur, mémoire NON testée")
        else:
            print("VERDICT: FAIL — LinkReady2s={} Sim={} Boot={} Candidate={} Sensors={} AtP1={} AtMaint={} P1Persist={} MaintPersist={}".format(
                ready_twice, simulation_ready, boot_restored, candidate, sensors_word,
                at_p1, at_maintenance, p1_persisted, maintenance_persisted))
