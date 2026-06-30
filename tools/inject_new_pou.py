#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_new_pou.py — Ajoute de NOUVELLES POUs (créées avec st2xml.py) dans Device.export

Contrairement à inject.py qui modifie des POUs existantes,
ce script AJOUTE des POUs completement nouvelles (GUIDs non présents).

Usage:
    python tools/inject_new_pou.py CODE/Types_Diagnostic__<GUID>.xml
    python tools/inject_new_pou.py CODE/FB_*.xml --glob  (si besoin multiple)

Fonctionnement:
    1. Lit le fragment XML de la nouvelle POU
    2. Valide le GUID (doit être unique = pas déjà dans Device.export)
    3. Insère avant la balise de fermeture </StructuredView>
    4. Backup horodaté du Device.export avant modif
"""
from __future__ import print_function

import argparse
import io
import re
import sys
import shutil
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TARGET = PROJECT_ROOT / "PRJ_CODESYS" / "PROJ_Full_ImportExport" / "Device.export"
DEFAULT_SOURCE = PROJECT_ROOT / "CODE"


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Ajoute de NOUVELLES POUs (st2xml.py) dans Device.export"
    )
    parser.add_argument("files", nargs="+", help="Fichiers XML (issus de st2xml.py)")
    parser.add_argument("--target", default=str(DEFAULT_TARGET),
                        help="Device.export cible (defaut: PROJ_Full_ImportExport/Device.export)")
    parser.add_argument("--yes", action="store_true",
                        help="Ajoute tout sans confirmation")
    args = parser.parse_args(argv)

    target = Path(args.target)
    if not target.is_file():
        print("[ERREUR] Cible introuvable : {}".format(target))
        return 1

    # Lire Device.export
    target_text = target.read_text(encoding="utf-8")

    # Extraire tous les GUIDs existants (pour vérifier unicité)
    existing_guids = set(re.findall(r'<Single Name="Guid"[^>]*>([a-f0-9\-]+)</Single>', target_text))

    print("Ajout de nouvelles POUs dans Device.export")
    print("=" * 60)

    # Traiter chaque fichier XML
    pou_fragments = []
    for file_pattern in args.files:
        file_path = Path(file_pattern)
        if not file_path.is_file():
            print("[WARN] Fichier non trouvé : {}".format(file_path))
            continue

        # Lire le fragment XML
        frag_text = file_path.read_text(encoding="utf-8")

        # Extraire le GUID et nom
        guid_match = re.search(r'<Single Name="Guid"[^>]*>([a-f0-9\-]+)</Single>', frag_text)
        name_match = re.search(r'<Single Name="Name"[^>]*Type="string">([^<]+)</Single>', frag_text)

        if not guid_match or not name_match:
            print("[ERREUR] Impossible extraire GUID/Name de {}".format(file_path.name))
            return 1

        pou_guid = guid_match.group(1)
        pou_name = name_match.group(1)

        # Vérifier unicité GUID
        if pou_guid in existing_guids:
            print("[ERREUR] GUID déjà présent : {} ({})".format(pou_name, pou_guid))
            return 1

        # Valider XML
        try:
            ET.fromstring(frag_text)
        except ET.ParseError as e:
            print("[ERREUR] XML mal formé dans {} : {}".format(file_path.name, str(e)))
            return 1

        print("[OK] {} ({})".format(pou_name, pou_guid))
        pou_fragments.append(frag_text)
        existing_guids.add(pou_guid)

    if not pou_fragments:
        print("Aucune POU valide à ajouter.")
        return 0

    print("=" * 60)

    # Demander confirmation
    if not args.yes:
        response = input("Ajouter {} POU(s) ? [o]ui / [n]on : ".format(len(pou_fragments)))
        if response.lower() != "o":
            print("Annule.")
            return 0

    # Backup du Device.export
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = target.parent / "Device.export.{}.bak".format(timestamp)
    shutil.copy(target, backup_file)
    print("[BACKUP] {}".format(backup_file.name))

    # Insérer les POUs avant </StructuredView>
    # Chercher la position d'insertion (avant la fermeture du root)
    insert_pos = target_text.rfind("</StructuredView>")
    if insert_pos == -1:
        print("[ERREUR] Structure Device.export non reconnue (pas de </StructuredView>)")
        # Restore backup
        shutil.copy(backup_file, target)
        return 1

    # Construire le nouvel XML
    new_text = target_text[:insert_pos]
    for frag in pou_fragments:
        new_text += frag + "\n"
    new_text += target_text[insert_pos:]

    # Valider l'XML complet avant écriture
    try:
        ET.fromstring(new_text)
    except ET.ParseError as e:
        print("[ERREUR] XML final invalide : {}".format(str(e)))
        print("Restore depuis backup...")
        shutil.copy(backup_file, target)
        return 1

    # Écrire le nouveau Device.export
    target.write_text(new_text, encoding="utf-8")
    print("[ECRIT] Device.export mis à jour ({} POU(s) ajoutée(s))".format(len(pou_fragments)))

    return 0


if __name__ == "__main__":
    sys.exit(main())
