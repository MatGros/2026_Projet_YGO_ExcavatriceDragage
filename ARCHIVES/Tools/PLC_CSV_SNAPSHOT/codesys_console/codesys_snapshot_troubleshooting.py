# -*- coding: utf-8 -*-
"""Snapshot CSV de GVL_Troubleshooting a l'instant T, via l'API scripting CODESYS.

A executer DANS la console de scripting CODESYS (Tools > Scripting), projet en ligne
(Login fait). Lit la liste de variables generee par generate_variable_list.py et ecrit un
CSV horodate dans le meme dossier.

Encodage CSV (separateur ";", decimale ".", fin de ligne CRLF) — cf. TOOLS/PLC_CSV_SNAPSHOT/README.md.
"""
import os
import time

VARIABLE_LIST_FILE = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\troubleshooting_variables.txt"
OUTPUT_DIR = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\RESULTS\snapshot"


def load_variable_list(path):
    with open(path, "r") as f:
        return [line.strip() for line in f if line.strip()]


BATCH_SIZE = 100  # nombre de variables par appel read_values() groupe


def read_batch_with_fallback(online_app, batch):
    """Lit un lot puis isole les chemins fautifs si l'appel groupe echoue.

    L'API scripting CODESYS rejette le lot entier lorsqu'une seule expression est
    introuvable. L'ancien code recopiait alors la meme erreur sur toutes les lignes,
    ce qui produisait de faux KO massifs (ex. 100 erreurs pour 1 chemin perime).
    Le repli conserve l'optimisation par lots pour le cas nominal et relit chaque
    variable uniquement lorsque cela est necessaire.

    Retourne ``(values, used_fallback)`` avec exactement une valeur par variable.
    """
    try:
        values = list(online_app.read_values(tuple(batch)))
        if len(values) != len(batch):
            raise RuntimeError(
                "read_values a retourne {} valeur(s) pour {} variable(s)".format(
                    len(values), len(batch)
                )
            )
        return values, False
    except Exception:
        values = []
        for variable in batch:
            try:
                single_values = list(online_app.read_values((variable,)))
                if len(single_values) != 1:
                    raise RuntimeError(
                        "read_values a retourne {} valeur(s) pour 1 variable".format(
                            len(single_values)
                        )
                    )
                values.append(single_values[0])
            except Exception as variable_error:
                values.append("ERREUR: " + str(variable_error))
        return values, True


def take_snapshot():
    app = projects.primary.active_application
    online_app = online.create_online_application(app)
    variables = load_variable_list(VARIABLE_LIST_FILE)

    rows = []
    read_time_total = 0.0
    fallback_batch_count = 0
    fallback_variable_count = 0
    with online_app:
        if not online_app.is_logged_in:
            online_app.login(OnlineChangeOption.Try, False)
        for i in range(0, len(variables), BATCH_SIZE):
            batch = variables[i:i + BATCH_SIZE]
            t0 = time.time()
            values, used_fallback = read_batch_with_fallback(online_app, batch)
            if used_fallback:
                fallback_batch_count += 1
                fallback_variable_count += len(batch)
            read_time_total += time.time() - t0
            rows.extend(zip(batch, values))

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Compte les variables en erreur (chemin perime / variable inexistante) pour les signaler.
    error_count = sum(1 for _, v in rows if isinstance(v, str) and v.startswith("ERREUR"))

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

    status_str = "❌ FAIL ({} ERREURS)".format(error_count) if error_count > 0 else "✅ PASS (0 ERREUR)"
    print("=" * 60)
    print("📸 SNAPSHOT TROUBLESHOOTING CODESYS — {}".format(status_str))
    print("=" * 60)
    print("📁 Fichier généré   : {}".format(output_path))
    print("📊 Variables lues   : {} / {}".format(len(rows) - error_count, len(rows)))
    if error_count:
        print("⚠️ Variables en KO  : {} (chemins périmés ou non trouvés dans CODESYS)".format(error_count))
        print("💡 Action requise   : vérifier les chemins KO après Clean & Rebuild CODESYS")
    else:
        print("✨ Intégrité        : 100% des variables lues avec succès")
    if fallback_batch_count:
        print("🔎 Repli individuel : {} lot(s), {} variable(s) réévaluée(s)".format(
            fallback_batch_count, fallback_variable_count
        ))
    print("⏱️ Temps total      : {:.3f} s (Lecture: {:.3f}s, Écriture: {:.3f}s)".format(
        read_time_total + write_time_total, read_time_total, write_time_total
    ))
    print("=" * 60)
    return output_path


if __name__ == "__main__":
    take_snapshot()
