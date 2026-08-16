# -*- coding: utf-8 -*-
"""Acquisition periodique de GVL_Troubleshooting EN ARRIERE-PLAN (ne bloque pas l'IDE).

A executer DANS la console de scripting CODESYS (Tools > Scripting), projet en ligne
(Login fait). Le script LANCE l'acquisition dans un thread separe et REND LA MAIN
IMMEDIATEMENT : tu peux continuer a utiliser CODESYS / te mettre en situation sur la
machine pendant que l'acquisition tourne.

Mecanisme (cf. doc scripting CODESYS, ScriptSystem.execute_on_primary_thread) : le thread
d'arriere-plan gere le minutage (time.sleep), et ne repasse sur le thread principal que
pour les tres breves lectures read_values() - la console CODESYS reste utilisable entre
deux lectures.

Encodage CSV (separateur ";", decimale ".", fin de ligne CRLF) — cf. TOOLS/PLC_LIVE_READER/README.md.
"""
import os
import threading
import time

VARIABLE_LIST_FILE = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\troubleshooting_variables.txt"
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\snapshots"
BATCH_SIZE = 100  # nombre de variables par appel read_values() groupe

DURATION_SECONDS = 10
INTERVAL_SECONDS = 1


def load_variable_list(path):
    with open(path, "r") as f:
        return [line.strip() for line in f if line.strip()]


def read_all(online_app, variables):
    values = []
    for i in range(0, len(variables), BATCH_SIZE):
        batch = variables[i:i + BATCH_SIZE]
        try:
            values.extend(online_app.read_values(tuple(batch)))
        except Exception as e:
            values.extend(["ERREUR: " + str(e)] * len(batch))
    return values


def write_csv(output_path, variables, ticks):
    with open(output_path, "wb") as f:
        header = "Variable;" + ";".join(label for label, _ in ticks)
        f.write(header + "\r\n")
        for idx, var_path in enumerate(variables):
            row_values = [str(values[idx]) for _, values in ticks]
            f.write(var_path + ";" + ";".join(row_values) + "\r\n")


def acquisition_worker(variables):
    state = {}

    def do_login():
        app = projects.primary.active_application
        state["online_app"] = online.create_online_application(app)
        if not state["online_app"].is_logged_in:
            state["online_app"].login(OnlineChangeOption.Try, False)

    def do_read():
        state["values"] = read_all(state["online_app"], variables)

    def do_dispose():
        try:
            state["online_app"].Dispose()
        except Exception:
            pass

    try:
        system.execute_on_primary_thread(do_login, False)

        ticks = []
        start = time.time()
        n_reads = int(DURATION_SECONDS / INTERVAL_SECONDS) + 1
        for i in range(n_reads):
            target = start + i * INTERVAL_SECONDS
            now = time.time()
            if target > now:
                time.sleep(target - now)

            system.execute_on_primary_thread(do_read, False)
            elapsed = time.time() - start
            ticks.append(("t={:.3f}s".format(elapsed), state["values"]))
            print("[acquisition] lecture " + str(i + 1) + "/" + str(n_reads) + " a t={:.3f}s".format(elapsed))

        system.execute_on_primary_thread(do_dispose, False)

        if not os.path.exists(OUTPUT_DIR):
            os.makedirs(OUTPUT_DIR)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        output_path = os.path.join(OUTPUT_DIR, "Acquisition_Troubleshooting_" + timestamp + ".csv")
        write_csv(output_path, variables, ticks)

        print("[acquisition] terminee : " + output_path)
    except Exception as e:
        print("[acquisition] ERREUR : " + str(e))


def start_background_acquisition():
    variables = load_variable_list(VARIABLE_LIST_FILE)
    t = threading.Thread(target=acquisition_worker, args=(variables,))
    t.setDaemon(True)
    t.start()
    print("Acquisition lancee en arriere-plan : " + str(DURATION_SECONDS) + " s, 1 lecture/" + str(INTERVAL_SECONDS) + "s.")
    print("CODESYS reste utilisable. Le CSV sera ecrit dans " + OUTPUT_DIR + " a la fin.")


if __name__ == "__main__":
    start_background_acquisition()
