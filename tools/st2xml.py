#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
st2xml.py — Convertit fichiers ST simples → XML CODESYS (prêt pour inject.py)

Usage:
    python tools/st2xml.py CODE/FB_MyNewFB.st
    python tools/st2xml.py CODE/FB_*.st  (multiple files)
    python tools/st2xml.py --template CODE/MyFB.st  (affiche template XML généré)

Sortie:
    CODE/FB_MyNewFB__<UUID>.xml (prêt pour inject.py → Device.export)

Structure ST attendue:
    FUNCTION_BLOCK FB_MonFB
    VAR_INPUT
        Input1 : BOOL;
    END_VAR
    VAR_OUTPUT
        Output1 : BOOL;
    END_VAR
    VAR
        Temp1 : INT;
    END_VAR
    // Implémentation ST
    ...
    END_FUNCTION_BLOCK
"""
from __future__ import print_function

import argparse
import io
import re
import sys
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = PROJECT_ROOT / "CODE"


def parse_st_file(st_path):
    """
    Parse un fichier ST et extrait :
    - pou_type : FUNCTION_BLOCK / PROGRAM
    - pou_name : nom du POU
    - interface_text : section déclaration VAR_* complète
    - impl_text : code d'implémentation
    """
    content = st_path.read_text(encoding="utf-8")

    # Parser le type et nom du POU
    pou_match = re.search(
        r'^\s*(FUNCTION_BLOCK|PROGRAM)\s+(\w+)',
        content,
        re.MULTILINE | re.IGNORECASE
    )
    if not pou_match:
        raise ValueError("Pas de FUNCTION_BLOCK ou PROGRAM trouvé dans {}".format(st_path.name))

    pou_type = pou_match.group(1).upper()
    pou_name = pou_match.group(2)

    # Extraire l'interface (tout jusqu'à END_FUNCTION_BLOCK ou END_PROGRAM)
    end_pattern = r'^END_{}\s*$'.format(re.escape(pou_type))
    end_match = re.search(end_pattern, content, re.MULTILINE)

    if not end_match:
        raise ValueError("Pas de END_{} trouvé dans {}".format(pou_type, st_path.name))

    pou_body = content[:end_match.start()]

    # Séparer l'interface (VAR_*) de l'implémentation
    # L'interface se termine avant le premier code exécutable (IF, FOR, WHILE, appel de fonction, etc.)
    interface_end = 0

    # Chercher la fin des sections VAR_*
    var_sections = list(re.finditer(
        r'^\s*VAR(?:_INPUT|_OUTPUT|_RETAIN|_GLOBAL)?\s*\n(.*?)^\s*END_VAR\s*$',
        pou_body,
        re.MULTILINE | re.DOTALL | re.IGNORECASE
    ))

    if var_sections:
        interface_end = var_sections[-1].end()

    # Tout ce qui suit l'interface est l'implémentation
    interface_part = pou_body[pou_body.find(pou_type) + len(pou_type):interface_end]
    impl_part = pou_body[interface_end:].strip()

    # Construire l'interface complète (VAR_INPUT/OUTPUT/VAR)
    interface_text = "FUNCTION_BLOCK {}\n{}END_VAR".format(pou_name, interface_part)

    return {
        'pou_type': pou_type,
        'pou_name': pou_name,
        'interface_text': interface_text,
        'impl_text': impl_part,
        'full_path': st_path
    }


def escape_xml_text(text):
    """Échappe les caractères XML dans le texte ST."""
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    text = text.replace('"', '&quot;')
    return text


def generate_xml(pou_info):
    """
    Génère le wrapper XML CODESYS complet pour le POU.
    Structure conforme aux exports Device.export.
    """
    pou_name = pou_info['pou_name']
    pou_guid = str(uuid.uuid4())  # GUID unique pour ce POU

    interface_escaped = escape_xml_text(pou_info['interface_text'])
    impl_escaped = escape_xml_text(pou_info['impl_text'])

    timestamp = int(datetime.utcnow().timestamp() * 10000000 + 116444736000000000)

    # Construire le XML (structure simplifié de Device.export)
    xml_template = '''<Single Type="{{6198ad31-4b98-445c-927f-3258a0e82fe3}}" Method="IArchivable">
      <Single Name="IsRoot" Type="bool">False</Single>
      <Single Name="MetaObject" Type="{{81297157-7ec9-45ce-845e-84cab2b88ade}}" Method="IArchivable">
        <Single Name="Guid" Type="System.Guid">{guid}</Single>
        <Single Name="ParentGuid" Type="System.Guid">103fbab6-1b12-4ccb-9cc6-6c66cad0e1cb</Single>
        <Single Name="Name" Type="string">{name}</Single>
        <Dictionary Type="{{2c41fa04-1834-41c1-816e-303c7aa2c05b}}" Name="Properties" />
        <Single Name="TypeGuid" Type="System.Guid">6f9dac99-8de1-4efc-8465-68ac443b7d08</Single>
        <Array Name="EmbeddedTypeGuids" Type="System.Guid">
          <Single Type="System.Guid">a9ed5b7e-75c5-4651-af16-d2c27e98cb94</Single>
          <Single Type="System.Guid">3b83b776-fb25-43b8-99f2-3c507c9143fc</Single>
        </Array>
        <Single Name="Timestamp" Type="long">{timestamp}</Single>
      </Single>
      <Single Name="Object" Type="{{6f9dac99-8de1-4efc-8465-68ac443b7d08}}" Method="IArchivable">
        <Single Name="SpecialFunc" Type="{{0db3d7bb-cde0-4416-9a7b-ce49a0124323}}">None</Single>
        <Single Name="Implementation" Type="{{3b83b776-fb25-43b8-99f2-3c507c9143fc}}" Method="IArchivable">
          <Single Name="TextDocument" Type="{{f3878285-8e4f-490b-bb1b-9acbb7eb04db}}" Method="IArchivable">
            <Single Name="TextBlobForSerialisation" Type="string">{impl}</Single>
            <Single Name="LineInfoPersistence" Type="string">{guid}_Impl_LineIds</Single>
          </Single>
        </Single>
        <Single Name="Interface" Type="{{a9ed5b7e-75c5-4651-af16-d2c27e98cb94}}" Method="IArchivable">
          <Single Name="TextDocument" Type="{{f3878285-8e4f-490b-bb1b-9acbb7eb04db}}" Method="IArchivable">
            <Single Name="TextBlobForSerialisation" Type="string">{interface}</Single>
            <Single Name="LineInfoPersistence" Type="string">{guid}_Decl_LineIds</Single>
          </Single>
        </Single>
        <Single Name="UniqueIdGenerator" Type="string">10</Single>
        <Single Name="POULevel" Type="{{8e575c5b-1d37-49c6-941b-5c0ec7874787}}">Standard</Single>
        <List Name="ChildObjectGuids" Type="System.Collections.ArrayList" />
        <Single Name="AddAttributeSubsequent" Type="bool">False</Single>
      </Single>
      <Single Name="ParentSVNodeGuid" Type="System.Guid">103fbab6-1b12-4ccb-9cc6-6c66cad0e1cb</Single>
      <Array Name="Path" Type="string">
        <Single Type="string">Device</Single>
        <Single Type="string">Logique API</Single>
        <Single Type="string">Application</Single>
        <Single Type="string">_TYPES</Single>
      </Array>
      <Single Name="Index" Type="int">-1</Single>
    </Single>'''

    xml_str = xml_template.format(
        guid=pou_guid,
        name=pou_name,
        timestamp=timestamp,
        interface=interface_escaped,
        impl=impl_escaped
    )

    # Valider XML
    try:
        ET.fromstring(xml_str)
    except ET.ParseError as e:
        raise ValueError("XML généré invalide : {}".format(e))

    return xml_str, pou_guid


def write_xml_file(xml_str, pou_name, pou_guid, output_dir):
    """Écrit le fichier XML dans CODE/"""
    output_file = output_dir / "{}__{}.xml".format(pou_name, pou_guid)
    output_file.write_text(xml_str, encoding="utf-8")
    return output_file


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Convertit fichiers ST → XML CODESYS (prêt pour inject.py)"
    )
    parser.add_argument("files", nargs="+", help="Fichiers .st à convertir (ou glob pattern)")
    parser.add_argument("--output", default=str(DEFAULT_SOURCE),
                        help="Répertoire de sortie (défaut: CODE/)")
    parser.add_argument("--template", action="store_true",
                        help="Affiche le XML généré sans l'écrire (debug)")
    args = parser.parse_args(argv)

    output_dir = Path(args.output)
    if not output_dir.is_dir():
        print("ERREUR: répertoire de sortie introuvable : {}".format(output_dir))
        return 1

    # Expand glob patterns
    st_files = []
    for pattern in args.files:
        matched = list(Path(".").glob(pattern)) if "*" in pattern else [Path(pattern)]
        st_files.extend([f for f in matched if f.suffix.lower() == ".st"])

    if not st_files:
        print("Aucun fichier .st trouvé dans : {}".format(args.files))
        return 1

    print("Conversion ST → XML CODESYS")
    print("=" * 60)

    success_count = 0
    for st_file in st_files:
        if not st_file.is_file():
            print("⚠ Ignoré (pas un fichier) : {}".format(st_file))
            continue

        try:
            # Parser le fichier ST
            pou_info = parse_st_file(st_file)
            pou_name = pou_info['pou_name']

            # Générer XML
            xml_str, pou_guid = generate_xml(pou_info)

            if args.template:
                print("\n[TEMPLATE] {}".format(pou_name))
                print(xml_str[:500] + "...")
            else:
                # Écrire le fichier XML
                output_file = write_xml_file(xml_str, pou_name, pou_guid, output_dir)
                print("✓ {} → {}".format(st_file.name, output_file.name))
                success_count += 1

        except Exception as e:
            print("✗ ERREUR {} : {}".format(st_file.name, str(e)))
            return 1

    print("=" * 60)
    if not args.template:
        print("OK. {} fichier(s) converti(s).".format(success_count))
        print("\nProchain : python tools/inject.py")

    return 0


if __name__ == "__main__":
    sys.exit(main())
