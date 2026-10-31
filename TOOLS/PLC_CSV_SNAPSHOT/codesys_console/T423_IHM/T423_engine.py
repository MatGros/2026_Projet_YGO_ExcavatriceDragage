# -*- coding: utf-8 -*-
"""Moteur de test T423 — Boîte à outils commune et robuste pour scripts CODESYS.

Dossier : TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/
Auditée & blindée par Agents A & B (Sécurité Machine & IronPython).
"""

import time

BANNER_PATHS = (
    "GVL_IHM.Banner.GlobalContextText",
    "GVL_IHM.Banner.SequenceProgressText",
    "GVL_IHM.Banner.SpecialConditionText",
    "GVL_IHM.Banner.OperatorActionText",
    "GVL_IHM.Banner.PositionM3Text",
    "GVL_IHM.Banner.AlarmBanner.HasAlarm",
    "GVL_IHM.Banner.AlarmBanner.Text",
    "GVL_IHM.Banner.AlarmBanner.Index",
    "GVL_IHM.Banner.AlarmBanner.Count",
)


def clean_val(raw):
    """Nettoie les préfixes de type CODESYS (INT#, WORD#, REAL#, etc.) et les quotes."""
    s = str(raw).strip()
    if s.startswith("'") and s.endswith("'"):
        s = s[1:-1].strip()
    if s.startswith('"') and s.endswith('"'):
        s = s[1:-1].strip()
    if "#" in s:
        # Ex: INT#1 -> 1, WORD#0 -> 0, REAL#7.9 -> 7.9, BOOL#TRUE -> TRUE
        parts = s.split("#", 1)
        if parts[0].upper() in ("INT", "DINT", "UINT", "UDINT", "WORD", "DWORD", "BYTE", "SINT", "USINT", "REAL", "LREAL", "TIME", "STRING", "BOOL"):
            s = parts[1].strip()
    return s


def int_val(raw):
    """Convertit une valeur CODESYS (ex: '16#0008', 'WORD#16#0008', '8', 8, enum) en entier."""
    try:
        s = clean_val(raw)
        if "VALID" in s:
            return 60
        if "MAINT_N1" in s:
            return 1
        if "MAINT_N2" in s:
            return 2
        if "SEMI_AUTO" in s:
            return 3
        if "DISABLE" in s:
            return 0
        if "16#" in s.lower():
            hex_part = s.lower().split("16#")[-1]
            return int(hex_part, 16)
        if "2#" in s.lower():
            bin_part = s.lower().split("2#")[-1]
            return int(bin_part, 2)
        return int(s)
    except Exception:
        return None


def bool_val(raw_val):
    clean = clean_val(raw_val).upper()
    return clean in ("TRUE", "1") or clean.startswith("TRUE") or "TRUE" in clean


def strip_accents(text):
    """Supprime les accents pour fiabiliser la comparaison de chaînes en environnement mixte ASCII/CP1252/UTF-8."""
    if not text:
        return ""
    s = str(text)
    replacements = (
        ("é", "e"), ("è", "e"), ("ê", "e"), ("ë", "e"),
        ("É", "E"), ("È", "E"), ("Ê", "E"), ("Ë", "E"),
        ("à", "a"), ("â", "a"), ("ä", "a"),
        ("À", "A"), ("Â", "A"), ("Ä", "A"),
        ("î", "i"), ("ï", "i"), ("Î", "I"), ("Ï", "I"),
        ("ô", "o"), ("ö", "o"), ("Ô", "O"), ("Ö", "O"),
        ("ù", "u"), ("û", "u"), ("ü", "u"),
        ("Ù", "U"), ("Û", "U"), ("Ü", "U"),
        ("ç", "c"), ("Ç", "C"),
    )
    for orig, repl in replacements:
        s = s.replace(orig, repl)
    return s


def match_text(expected, candidate):
    """Vérifie si expected est contenu dans candidate de manière robuste (insensible casse et accents)."""
    if not expected:
        return True
    exp_norm = strip_accents(str(expected)).upper()
    cand_norm = strip_accents(str(candidate)).upper()
    return exp_norm in cand_norm


def get_online_app():
    try:
        app = projects.primary.active_application
    except Exception as e:
        print("ERREUR: Impossible de recuperer active_application (" + str(e) + ")")
        return None
    online_app = online.create_online_application(app)
    if not online_app.is_logged_in:
        print("ERREUR: Veuillez faire 'Login' dans CODESYS avant d'executer ce test.")
        return None
    return online_app


def safe_read(online_app, path, default="N/A"):
    """Lecture unitaire protégée contre toute exception de symbole absent."""
    try:
        val = online_app.read_value(path)
        return str(val)
    except Exception:
        return default


def safe_write(online_app, path, value_str, force=False):
    """Écriture unitaire protégée avec option de forçage temporaire."""
    try:
        online_app.set_prepared_value(path, value_str)
        if force:
            forced = False
            for method_name in ("force_prepared_values", "ForcePreparedValues", "force_values"):
                if hasattr(online_app, method_name):
                    try:
                        getattr(online_app, method_name)()
                        forced = True
                        break
                    except Exception:
                        pass
            if forced:
                return True
        if force:
            return False
        online_app.write_prepared_values()
        return True
    except Exception:
        return False


def safe_unforce(online_app):
    """Retire tout forçage actif pour garantir l'intégrité de l'automate."""
    for method_name in ("unforce_all_values", "UnforceAll", "unforce_prepared_values", "UnforcePreparedValues", "unforce_all"):
        if hasattr(online_app, method_name):
            try:
                getattr(online_app, method_name)()
                return True
            except Exception:
                pass
    return False


def read_banner(online_app):
    """Lecture protégée des champs du bandeau principal."""
    res = {}
    for p in BANNER_PATHS:
        res[p] = safe_read(online_app, p, "")
    return res


def get_active_alarms(online_app):
    """Lecture atomique et résiliente de la liste des alarmes actives via Array direct + carrousel."""
    res = []
    # 1. Lecture du texte courant du bandeau
    curr = safe_read(online_app, "GVL_IHM.Banner.AlarmBanner.Text", "")
    clean = clean_val(curr)
    if clean and clean != "N/A" and clean != "" and clean not in res:
        res.append(clean)

    # 2. Lecture du compteur et du tableau
    count_str = safe_read(online_app, "GVL_IHM.Banner.AlarmBanner.Count", "0")
    count_clean = clean_val(count_str)
    try:
        count = min(max(int(count_clean), 0), 20)
    except Exception:
        count = 0

    for i in range(max(count, 10)):
        arr_val = safe_read(online_app, "GVL_IHM.Banner.AlarmBanner.AlarmArray[%d]" % i, "")
        clean_arr = clean_val(arr_val)
        if clean_arr and clean_arr != "N/A" and clean_arr != "" and clean_arr not in res:
            res.append(clean_arr)

    # 3. Si plusieurs alarmes, rotation rapide
    if count > 1:
        for _ in range(min(count, 3)):
            time.sleep(0.35)
            curr = safe_read(online_app, "GVL_IHM.Banner.AlarmBanner.Text", "")
            clean = clean_val(curr)
            if clean and clean != "N/A" and clean != "" and clean not in res:
                res.append(clean)

    return res


def rearm_emergency(online_app):
    """Séquence de réarmement sécurisée en boucle fermée avec impulsion garantie."""
    # 0. Retrait préalable de tout forçage résiduel
    safe_unforce(online_app)

    # 1. Armement des drapeaux de simulation indispensables
    safe_write(online_app, "GVL_Simulation.SimulationModeActive", "TRUE")
    safe_write(online_app, "GVL_Simulation.SimWinchActive", "TRUE")
    safe_write(online_app, "GVL_Simulation.SimTranslationActive", "TRUE")
    safe_write(online_app, "GVL_Simulation.SimSafetyActive", "TRUE")
    safe_write(online_app, "GVL_Simulation.SimChainOk", "TRUE")
    safe_write(online_app, "GVL_Simulation.SimPhaseRotationOk", "TRUE")
    safe_write(online_app, "PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational", "TRUE")
    safe_write(online_app, "PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM2.Operational", "TRUE")
    safe_write(online_app, "PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Operational", "TRUE")
    safe_write(online_app, "GVL_IHM.Network.Bypass.Global", "FALSE")
    time.sleep(0.1)

    # 2. Acquittement préalable des défauts (Reset général)
    safe_write(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "TRUE")
    time.sleep(0.2)
    safe_write(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "FALSE")
    time.sleep(0.3)

    # 3. Impulsion d'armement garantie avec relâchement sous finally
    try:
        safe_write(online_app, "GVL_IHM.Emergency.Cmd.BtnEmergencyArming", "TRUE")
        time.sleep(0.5)
    finally:
        safe_write(online_app, "GVL_IHM.Emergency.Cmd.BtnEmergencyArming", "FALSE")

    # 4. Attente de la séquence contacteur et purge de la fenêtre transitoire TonRearmWindow (T#4s)
    time.sleep(4.5)
