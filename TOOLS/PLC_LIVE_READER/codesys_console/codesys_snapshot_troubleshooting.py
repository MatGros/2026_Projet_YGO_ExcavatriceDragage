# -*- coding: utf-8 -*-
"""Snapshot CSV de GVL_Troubleshooting a l'instant T, via l'API scripting CODESYS.

A executer DANS la console de scripting CODESYS (Tools > Scripting), projet en ligne
(Login fait). Lit la liste de variables generee par generate_variable_list.py et ecrit un
CSV horodate dans le meme dossier.

Encodage CSV aligne sur FB_SnapshotTroubleshooting (DOC/AF/AF_Partie-12_Fonction_Diagnostic/
FB_SnapshotTroubleshooting_v1.0.md) : separateur ";", decimale ".", fin de ligne CRLF.
"""
import os
import time

VARIABLE_LIST_FILE = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\variable_lists\troubleshooting_variables.txt"
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_LIVE_READER\RESULTS\snapshot"


def load_variable_list(path):
    with open(path, "r") as f:
        return [line.strip() for line in f if line.strip()]


BATCH_SIZE = 100  # nombre de variables par appel read_values() groupe


def take_snapshot():
    app = projects.primary.active_application
    online_app = online.create_online_application(app)
    variables = load_variable_list(VARIABLE_LIST_FILE)

    rows = []
    read_time_total = 0.0
    with online_app:
        if not online_app.is_logged_in:
            online_app.login(OnlineChangeOption.Try, False)
        for i in range(0, len(variables), BATCH_SIZE):
            batch = variables[i:i + BATCH_SIZE]
            t0 = time.time()
            try:
                values = online_app.read_values(tuple(batch))
            except Exception as e:
                values = ["ERREUR: " + str(e)] * len(batch)
            read_time_total += time.time() - t0
            rows.extend(zip(batch, values))

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(OUTPUT_DIR, "Snapshot_Troubleshooting_" + timestamp + ".csv")

    # Mode binaire : evite la double traduction \n -> \r\n de Python en mode texte sur Windows
    # (qui produirait \r\r\n, affiche comme des lignes vides dans certains lecteurs/Excel).
    t0 = time.time()
    with open(output_path, "wb") as f:
        f.write("Variable;Valeur\r\n")
        for var_path, value in rows:
            f.write(var_path + ";" + str(value) + "\r\n")
    write_time_total = time.time() - t0

    print("Snapshot ecrit : " + output_path)
    print(str(len(rows)) + " variables lues")
    print("Temps lecture (read_values, " + str(len(variables) // BATCH_SIZE + 1) + " appels groupes) : {:.3f} s".format(read_time_total))
    print("Temps ecriture fichier : {:.3f} s".format(write_time_total))
    print("Temps total : {:.3f} s".format(read_time_total + write_time_total))
    return output_path


if __name__ == "__main__":
    take_snapshot()
