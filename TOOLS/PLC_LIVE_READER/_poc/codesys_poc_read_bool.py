# -*- coding: utf-8 -*-
"""POC - lit une variable BOOL en live via l'API de scripting native CODESYS (scriptengine).

Contexte : ce script s'utilise quand le projet tourne en mode Simulation interne a l'IDE
(aucun port reseau ouvert, pas d'OPC UA/Modbus disponible - cf. TOOLS/PLC_LIVE_READER/README.md
"Mode A"). Il pilote directement l'application en cours dans l'IDE via son API officielle,
gratuite, sans bibliotheque tierce (pas de pip install).

A executer DANS la console de scripting CODESYS (Tools > Scripting), avec le projet deja
ouvert et en ligne (Login fait) - pas via un `python` externe classique. Voir README.md
"Mode A - Simulation interne" pour la procedure pas a pas.
"""

VARIABLE_PATH = "GVL_IHM.HmiInitDone"  # a adapter : chemin exact de la variable a lire (relatif a l'application, sans prefixe "Application.")


def read_bool(variable_path):
    app = projects.primary.active_application
    online_app = online.create_online_application(app)
    with online_app:
        if not online_app.is_logged_in:
            online_app.login(OnlineChangeOption.Try, False)
        value = online_app.read_value(variable_path)
        return value


if __name__ == "__main__":
    result = read_bool(VARIABLE_PATH)
    print("{} = {}".format(VARIABLE_PATH, result))
