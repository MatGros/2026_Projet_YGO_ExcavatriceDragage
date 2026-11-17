# -*- coding: utf-8 -*-
"""Snapshot CSV des variables persistantes (GVL_PERSISTENT), LECTURE SEULE.

A lancer dans la console CODESYS (Tools > Scripting), projet DEJA EN LIGNE (Login fait a la main) :
  execfile(r"C:\\_MGS\\DEV\\2026_Projet_YGO_ExcavatriceDragage\\TOOLS\\PLC_CSV_SNAPSHOT\\variable_lists\\snapshot_persistent.py")

- Ne se connecte JAMAIS (un login depuis un script peut declencher un online change).
- N'ecrit AUCUNE variable sur l'automate.
- Lit la liste persistent_variables.txt (generate_persistent_variable_list.py), chemins courts
  « GVL_PERSISTENT.xxx » (valides ; le prefixe Device.Application. est refuse par read_values).
- Sortie : CSV « Variable;Type;Valeur » (separateur ;, fin de ligne CRLF).
  Une variable absente du projet en ligne donne « ERREUR: ... » sur sa ligne, sans bloquer les autres.
  (Projet v0.7.24 : les 6 dernieres variables de la liste, _RunningHours* et _TranslationCalib*,
  sont NOUVELLES dans le code actuel : erreur attendue.)

Valide par POC le 2026-11-17 : lecture d'un champ, d'un tableau [i], [i][j], [i,j,k,l] OK ;
structure entiere impossible (« Invalid pointer size ») ; prefixe Device.Application. impossible.
"""
import os
import time

VARIABLE_LIST = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\persistent_variables.txt"
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\DOC\WFLOW\MISE_EN_SERVICE\20261117_PERSISTANTES"
BATCH_SIZE = 100  # variables par appel read_values() groupe


def load_variable_list(path):
    with open(path, "r") as f:
        lines = [line.strip() for line in f]
    return [line for line in lines if line and not line.startswith("#")]


def read_batch_with_fallback(online_app, batch):
    """Une valeur par chemin ; si un lot contient un chemin invalide, relit variable par variable."""
    try:
        values = list(online_app.read_values(tuple(batch)))
        if len(values) != len(batch):
            raise RuntimeError("nombre de valeurs different du lot")
        return values
    except Exception:
        values = []
        for variable in batch:
            try:
                values.append(list(online_app.read_values((variable,)))[0])
            except Exception as variable_error:
                values.append("ERREUR: " + str(variable_error))
        return values


def split_type_value(raw):
    """'UDINT#16750628' -> ('UDINT', '16750628') ; 'TRUE' -> ('', 'TRUE')."""
    text = str(raw)
    if text.startswith("ERREUR"):
        return "", text
    if "#" in text:
        type_name, value = text.split("#", 1)
        return type_name, value
    return "", text


def take_persistent_snapshot():
    if not os.path.exists(VARIABLE_LIST):
        print("ERREUR : liste introuvable : " + VARIABLE_LIST)
        print("Generer-la : python TOOLS/PLC_CSV_SNAPSHOT/variable_lists/generate_persistent_variable_list.py")
        return None
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    app = projects.primary.active_application
    online_app = online.create_online_application(app)

    with online_app:
        if not online_app.is_logged_in:
            print("ARRET : pas en ligne. Faire Online > Login a la main, puis relancer.")
            print("Ce script ne se connecte jamais et n'ecrit rien sur l'automate.")
            return None
        names = load_variable_list(VARIABLE_LIST)
        t0 = time.time()
        rows = []
        for i in range(0, len(names), BATCH_SIZE):
            batch = names[i:i + BATCH_SIZE]
            rows.extend(zip(batch, read_batch_with_fallback(online_app, batch)))
        read_time = time.time() - t0

    output_path = os.path.join(OUTPUT_DIR, "Persistantes_" + time.strftime("%Y%m%d_%H%M%S") + ".csv")
    errors = []
    with open(output_path, "wb") as f:
        f.write("Variable;Type;Valeur\r\n")
        for name, raw in rows:
            type_name, value = split_type_value(raw)
            if value.startswith("ERREUR"):
                errors.append((name, value))
            f.write(name + ";" + type_name + ";" + value + "\r\n")

    print("Persistantes : " + str(len(rows)) + " variables, " + str(len(errors)) + " erreur(s), lecture {:.2f} s".format(read_time))
    for name, value in errors[:10]:
        print("  ! " + name + " -> " + value)
    print("  -> " + output_path)
    return output_path


take_persistent_snapshot()
