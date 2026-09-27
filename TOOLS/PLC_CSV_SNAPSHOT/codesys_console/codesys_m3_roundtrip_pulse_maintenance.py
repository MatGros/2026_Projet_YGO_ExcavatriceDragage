# -*- coding: utf-8 -*-
"""Lanceur simple T402 : test aller-retour Maintenance sans paramètre."""

POC_PATH = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_m3_roundtrip_poc.py"
with open(POC_PATH, "rb") as poc_file:
    poc_code = compile(poc_file.read(), POC_PATH, "exec")
    # Conserver les objets injectés par CODESYS dans le script d'entrée :
    # projects, online, system, etc. Un scope neuf les ferait disparaître.
    poc_scope = globals().copy()
    poc_scope["POC_ACTION"] = "pulse_maintenance"
    poc_scope["__file__"] = POC_PATH
    exec(poc_code, poc_scope, poc_scope)
