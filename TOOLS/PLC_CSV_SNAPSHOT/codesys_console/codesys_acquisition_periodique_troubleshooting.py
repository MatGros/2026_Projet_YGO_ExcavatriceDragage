# -*- coding: utf-8 -*-
"""Acquisition periodique de GVL_Troubleshooting sur une duree donnee (ex: 10 s, 1 lecture/s).

A executer DANS la console de scripting CODESYS (Tools > Scripting), projet en ligne
(Login fait). Produit UN SEUL CSV "large" : une ligne par variable, une colonne par instant
de lecture (plus facile a analyser pour un agent qu'une serie de fichiers separes).

Encodage CSV (separateur ";", decimale ".", fin de ligne CRLF) — cf. TOOLS/PLC_CSV_SNAPSHOT/README.md.
"""
import os
import time

VARIABLE_LIST_FILE = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\troubleshooting_variables.txt"
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\RESULTS\acquisition"
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


def run_acquisition():
    variables = load_variable_list(VARIABLE_LIST_FILE)

    app = projects.primary.active_application
    online_app = online.create_online_application(app)

    ticks = []  # liste de (label_instant, [valeurs...])
    start = time.time()
    n_reads = int(DURATION_SECONDS / INTERVAL_SECONDS) + 1

    with online_app:
        if not online_app.is_logged_in:
            online_app.login(OnlineChangeOption.Try, False)

        for i in range(n_reads):
            target_time = start + i * INTERVAL_SECONDS
            now = time.time()
            if target_time > now:
                time.sleep(target_time - now)

            elapsed = time.time() - start
            values = read_all(online_app, variables)
            ticks.append(("t={:.3f}s".format(elapsed), values))
            print("Lecture " + str(i + 1) + "/" + str(n_reads) + " a t={:.3f}s".format(elapsed))

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(OUTPUT_DIR, "Acquisition_Troubleshooting_" + timestamp + ".csv")

    with open(output_path, "wb") as f:
        header = "Variable;" + ";".join(label for label, _ in ticks)
        f.write(header + "\r\n")
        for idx, var_path in enumerate(variables):
            row_values = [str(values[idx]) for _, values in ticks]
            f.write(var_path + ";" + ";".join(row_values) + "\r\n")

    print("Acquisition ecrite : " + output_path)
    print(str(len(ticks)) + " instants x " + str(len(variables)) + " variables")
    return output_path


if __name__ == "__main__":
    run_acquisition()
