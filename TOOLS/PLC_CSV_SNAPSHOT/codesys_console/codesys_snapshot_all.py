# -*- coding: utf-8 -*-
"""Snapshot CSV de GVL_Troubleshooting ET GVL_IHM a l'instant T, en une seule execution.

A executer DANS la console de scripting CODESYS (Tools > Scripting), projet en ligne
(Login fait). Reutilise la meme session en ligne pour les deux GVL (un seul login).

Encodage CSV (separateur ";", decimale ".", fin de ligne CRLF) — cf. TOOLS/PLC_CSV_SNAPSHOT/README.md.
"""
import os
import time

SNAPSHOTS = [
    ("Troubleshooting", r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\troubleshooting_variables.txt"),
    ("IHM", r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\ihm_variables.txt"),
]
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\RESULTS\snapshot"
BATCH_SIZE = 100  # nombre de variables par appel read_values() groupe


def load_variable_list(path):
    with open(path, "r") as f:
        return [line.strip() for line in f if line.strip()]


def read_batch_with_fallback(online_app, batch):
    """Retourne une valeur par chemin, meme si un lot contient un chemin invalide."""
    try:
        values = list(online_app.read_values(tuple(batch)))
        if len(values) != len(batch):
            raise RuntimeError("nombre de valeurs retourne different du lot")
        return values, False
    except Exception:
        values = []
        for variable in batch:
            try:
                single_values = list(online_app.read_values((variable,)))
                if len(single_values) != 1:
                    raise RuntimeError("nombre de valeurs retourne different de 1")
                values.append(single_values[0])
            except Exception as variable_error:
                values.append("ERREUR: " + str(variable_error))
        return values, True


def read_all(online_app, variables):
    rows = []
    read_time = 0.0
    fallback_batches = 0
    for i in range(0, len(variables), BATCH_SIZE):
        batch = variables[i:i + BATCH_SIZE]
        t0 = time.time()
        values, used_fallback = read_batch_with_fallback(online_app, batch)
        if used_fallback:
            fallback_batches += 1
        read_time += time.time() - t0
        rows.extend(zip(batch, values))
    return rows, read_time, fallback_batches


def write_csv(path, rows):
    t0 = time.time()
    # Mode binaire : evite la double traduction \n -> \r\n de Python en mode texte sur Windows.
    with open(path, "wb") as f:
        f.write("Variable;Valeur\r\n")
        for var_path, value in rows:
            f.write(var_path + ";" + str(value) + "\r\n")
    return time.time() - t0


def take_all_snapshots():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
    timestamp = time.strftime("%Y%m%d_%H%M%S")

    app = projects.primary.active_application
    online_app = online.create_online_application(app)

    total_read_time = 0.0
    total_write_time = 0.0
    total_vars = 0
    outputs = []

    with online_app:
        if not online_app.is_logged_in:
            online_app.login(OnlineChangeOption.Try, False)

        for label, list_file in SNAPSHOTS:
            variables = load_variable_list(list_file)
            rows, read_time, fallback_batches = read_all(online_app, variables)
            output_path = os.path.join(OUTPUT_DIR, "Snapshot_" + label + "_" + timestamp + ".csv")
            write_time = write_csv(output_path, rows)

            total_read_time += read_time
            total_write_time += write_time
            total_vars += len(rows)
            outputs.append(output_path)

            print(label + " : " + str(len(rows)) + " variables, lecture {:.3f} s, ecriture {:.3f} s".format(read_time, write_time))
            if fallback_batches:
                print("  Repli individuel : " + str(fallback_batches) + " lot(s)")
            print("  -> " + output_path)

    print("---")
    print("Total : " + str(total_vars) + " variables, lecture {:.3f} s, ecriture {:.3f} s, total {:.3f} s".format(
        total_read_time, total_write_time, total_read_time + total_write_time))
    return outputs


if __name__ == "__main__":
    take_all_snapshots()
