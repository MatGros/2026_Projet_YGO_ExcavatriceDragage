#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fonctions communes aux scripts extract.py / inject.py.

On travaille au niveau TEXTE (jamais de re-serialisation du fichier complet de
~6.8 MB) pour preserver octet-pour-octet tout ce qu'on ne modifie pas : CODESYS
est sensible au formatage.

Une entree POU dans Device.export ressemble a :

    <Single Type="{6198ad31-4b98-445c-927f-3258a0e82fe3}" Method="IArchivable">
      <Single Name="MetaObject" ...>
        <Single Name="Guid" Type="System.Guid">....</Single>
        <Single Name="Name" Type="string">FB_Xxx</Single>
        <Single Name="TypeGuid" Type="System.Guid">6f9dac99-...</Single>
        ...
      </Single>
      <Single Name="Object" ...> ... </Single>
      ...
    </Single>

Les <Single ...> sont imbriques : on isole le bloc d'une entree par comptage de
profondeur sur la balise `Single`.
"""
from __future__ import print_function

import re

# Type d'une entree de EntryList (FB / PRG / DUT / dossier / device ...)
ENTRY_TYPE = "{6198ad31-4b98-445c-927f-3258a0e82fe3}"
# TypeGuid qui distingue un POU (FB ou PRG) des autres objets
POU_TYPE_GUID = "6f9dac99-8de1-4efc-8465-68ac443b7d08"

# Ouverture d'une entree EntryList
ENTRY_OPEN_RE = re.compile(
    r'<Single\s+Type="\{6198ad31-4b98-445c-927f-3258a0e82fe3\}"\s+Method="IArchivable"\s*>'
)
# Toute balise <Single ...> ouvrante (non auto-fermante) ou fermante </Single>
SINGLE_TOKEN_RE = re.compile(r'<Single\b[^>]*?(/?)>|</Single>')

GUID_RE = re.compile(
    r'<Single\s+Name="Guid"\s+Type="System\.Guid">([^<]+)</Single>'
)
NAME_RE = re.compile(
    r'<Single\s+Name="Name"\s+Type="string">([^<]*)</Single>'
)
TYPEGUID_RE = re.compile(
    r'<Single\s+Name="TypeGuid"\s+Type="System\.Guid">([^<]+)</Single>'
)


def find_entry_end(text, open_start):
    """
    A partir de l'index de debut d'une balise ouvrante <Single ...> (open_start),
    retourne l'index juste apres le </Single> correspondant, par comptage de
    profondeur. Gere les balises auto-fermantes <Single ... />.
    """
    depth = 0
    pos = open_start
    for m in SINGLE_TOKEN_RE.finditer(text, open_start):
        token = m.group(0)
        if token.startswith('</'):
            depth -= 1
            if depth == 0:
                return m.end()
        else:
            # balise ouvrante ; group(1) == '/' si auto-fermante
            if m.group(1) != '/':
                depth += 1
            # auto-fermante : ne change pas la profondeur
        pos = m.end()
    raise ValueError("Balise </Single> de fermeture introuvable (XML mal forme ?)")


def iter_pou_entries(text):
    """
    Itere sur les entrees POU (FB/PRG) du texte Device.export.
    Yield des dicts : {name, guid, start, end, block}.
      start/end : bornes du bloc complet de l'entree dans `text`.
      block     : sous-chaine text[start:end].
    """
    for m in ENTRY_OPEN_RE.finditer(text):
        start = m.start()
        end = find_entry_end(text, start)
        block = text[start:end]

        tg = TYPEGUID_RE.search(block)
        if not tg or tg.group(1).strip() != POU_TYPE_GUID:
            continue  # pas un POU (dossier, device, GVL, DUT...)

        guid_m = GUID_RE.search(block)
        name_m = NAME_RE.search(block)
        if not guid_m or not name_m:
            continue

        yield {
            "name": name_m.group(1).strip(),
            "guid": guid_m.group(1).strip(),
            "start": start,
            "end": end,
            "block": block,
        }


def is_ladder(block):
    """
    Vrai si l'Implementation du POU est graphique (Ladder/FBD) plutot que ST.
    Detecte la presence d'un NetworkList dans le bloc.
    """
    return "NetworkList" in block


def safe_filename(name, guid):
    """Nom de fichier d'extraction : <Name>__<Guid>.xml (Name nettoye)."""
    clean = re.sub(r'[^0-9A-Za-z_\-]', '_', name)
    return "{}__{}.xml".format(clean, guid)
