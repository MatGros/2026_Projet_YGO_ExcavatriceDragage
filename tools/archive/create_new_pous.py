#!/usr/bin/env python3
"""
Crée les nouveaux POUs (DiagCanOpen, BusAggregator, PRG_BusMonitor)
et les GVLs (_TYPES, GVL_BusHealth) dans Device.export
"""

import xml.etree.ElementTree as ET
import uuid
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEVICE_EXPORT = PROJECT_ROOT / "PRJ_CODESYS" / "PROJ_Full_ImportExport" / "Device.export"
CODE_DIR = PROJECT_ROOT / "CODE"

# Référence parent : Application (guid connu)
APP_PARENT_GUID = "103fbab6-1b12-4ccb-9cc6-6c66cad0e1cb"

# Templates pour les POUs à créer
POUS_TO_CREATE = [
    {
        "name": "FB_DiagCanOpen",
        "pou_type": "FUNCTION_BLOCK",
        "st_file": "FB_DiagCanOpen.st",
    },
    {
        "name": "FB_BusAggregator",
        "pou_type": "FUNCTION_BLOCK",
        "st_file": "FB_BusAggregator.st",
    },
    {
        "name": "PRG_BusMonitor",
        "pou_type": "PROGRAM",
        "st_file": "PRG_BusMonitor.st",
    },
]

GLVS_TO_CREATE = [
    {
        "name": "_TYPES",
        "st_file": "_TYPES.st",
    },
    {
        "name": "GVL_BusHealth",
        "st_file": "GVL_BusHealth.st",
    },
]


def read_st_file(st_file):
    """Lit le contenu ST"""
    path = CODE_DIR / st_file
    if not path.exists():
        print(f"  [ERROR] {st_file} not found")
        return None
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def extract_interface_impl(st_content):
    """Extrait interface et implementation d'un ST"""
    import re
    match = re.search(
        r'(FUNCTION_BLOCK|PROGRAM)\s+(\w+)(.*)',
        st_content,
        re.DOTALL
    )
    if not match:
        return None, None, None

    fb_type = match.group(1)
    fb_name = match.group(2)
    full_content = match.group(3)

    var_match = re.search(r'(VAR.*?END_VAR(?:\s*VAR.*?END_VAR)*)', full_content, re.DOTALL)
    if var_match:
        interface = var_match.group(1)
        impl = full_content[var_match.end():].strip()
    else:
        interface = ""
        impl = full_content.strip()

    return fb_type, interface, impl


def extract_glv_content(st_content):
    """Extrait le contenu d'une GVL"""
    import re
    match = re.search(r'VAR_GLOBAL(.*)', st_content, re.DOTALL)
    if match:
        return match.group(1).replace("END_VAR", "").strip()
    return ""


def escape_xml(text):
    """Échappe les caractères XML"""
    return (text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
    )


def create_pou_xml(pou_config):
    """Crée un élément XML POU"""
    guid = str(uuid.uuid4())
    iface_guid = str(uuid.uuid4())
    impl_guid = str(uuid.uuid4())

    st_content = read_st_file(pou_config["st_file"])
    if st_content is None:
        return None

    fb_type, interface_block, impl_block = extract_interface_impl(st_content)
    if fb_type is None:
        return None

    # Construire les textes complets
    interface_full = f"{fb_type} {pou_config['name']}\n{interface_block}\nEND_{fb_type}"

    # Créer l'élément XML
    root = ET.Element("Single", Type="{6198ad31-4b98-445c-927f-3258a0e82fe3}", Method="IArchivable")

    # MetaObject
    meta = ET.SubElement(root, "Single", Name="MetaObject", Type="{81297157-7ec9-45ce-845e-84cab2b88ade}", Method="IArchivable")
    ET.SubElement(meta, "Single", Name="Guid", Type="System.Guid").text = guid
    ET.SubElement(meta, "Single", Name="ParentGuid", Type="System.Guid").text = APP_PARENT_GUID
    ET.SubElement(meta, "Single", Name="Name", Type="string").text = pou_config["name"]
    ET.SubElement(meta, "Single", Name="Properties", Type="{2c41fa04-1834-41c1-816e-303c7aa2c05b}", Name="Properties")
    ET.SubElement(meta, "Single", Name="TypeGuid", Type="System.Guid").text = "6f9dac99-8de1-4efc-8465-68ac443b7d08"

    embedded_types = ET.SubElement(meta, "Array", Name="EmbeddedTypeGuids", Type="System.Guid")
    ET.SubElement(embedded_types, "Single", Type="System.Guid").text = "a9ed5b7e-75c5-4651-af16-d2c27e98cb94"
    ET.SubElement(embedded_types, "Single", Type="System.Guid").text = "3b83b776-fb25-43b8-99f2-3c507c9143fc"

    ET.SubElement(meta, "Single", Name="Timestamp", Type="long").text = str(int(datetime.now().timestamp() * 10000000 + 621355968000000000))

    # Object
    obj = ET.SubElement(root, "Single", Name="Object", Type="{6f9dac99-8de1-4efc-8465-68ac443b7d08}", Method="IArchivable")
    ET.SubElement(obj, "Single", Name="SpecialFunc", Type="{0db3d7bb-cde0-4416-9a7b-ce49a0124323}").text = "None"

    # Implementation
    impl_elem = ET.SubElement(obj, "Single", Name="Implementation", Type="{3b83b776-fb25-43b8-99f2-3c507c9143fc}", Method="IArchivable")
    impl_textdoc = ET.SubElement(impl_elem, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(impl_textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(impl_block)
    ET.SubElement(impl_textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_Impl_LineIds"

    # Interface
    iface_elem = ET.SubElement(obj, "Single", Name="Interface", Type="{a9ed5b7e-75c5-4651-af16-d2c27e98cb94}", Method="IArchivable")
    iface_textdoc = ET.SubElement(iface_elem, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(iface_textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(interface_full)
    ET.SubElement(iface_textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_Decl_LineIds"

    ET.SubElement(obj, "Single", Name="UniqueIdGenerator", Type="string").text = "10"
    ET.SubElement(obj, "Single", Name="POULevel", Type="{8e575c5b-1d37-49c6-941b-5c0ec7874787}").text = "Standard"
    ET.SubElement(obj, "List", Name="ChildObjectGuids", Type="System.Collections.ArrayList")
    ET.SubElement(obj, "Single", Name="AddAttributeSubsequent", Type="bool").text = "False"

    # Path et Parent
    ET.SubElement(root, "Single", Name="ParentSVNodeGuid", Type="System.Guid").text = APP_PARENT_GUID
    path_arr = ET.SubElement(root, "Array", Name="Path", Type="string")
    ET.SubElement(path_arr, "Single", Type="string").text = "Device"
    ET.SubElement(path_arr, "Single", Type="string").text = "Logique API"
    ET.SubElement(path_arr, "Single", Type="string").text = "Application"

    ET.SubElement(root, "Single", Name="Index", Type="int").text = "-1"

    return root, guid


def create_glv_xml(glv_config):
    """Crée un élément XML GVL (Global Variable List)"""
    guid = str(uuid.uuid4())

    st_content = read_st_file(glv_config["st_file"])
    if st_content is None:
        return None

    glv_content = extract_glv_content(st_content)
    glv_full = f"VAR_GLOBAL\n{glv_content}\nEND_VAR"

    # Créer l'élément XML (structure simplifiée pour GVL)
    root = ET.Element("Single", Type="{6198ad31-4b98-445c-927f-3258a0e82fe3}", Method="IArchivable")

    # MetaObject
    meta = ET.SubElement(root, "Single", Name="MetaObject", Type="{81297157-7ec9-45ce-845e-84cab2b88ade}", Method="IArchivable")
    ET.SubElement(meta, "Single", Name="Guid", Type="System.Guid").text = guid
    ET.SubElement(meta, "Single", Name="ParentGuid", Type="System.Guid").text = APP_PARENT_GUID
    ET.SubElement(meta, "Single", Name="Name", Type="string").text = glv_config["name"]
    ET.SubElement(meta, "Single", Name="Properties", Type="{2c41fa04-1834-41c1-816e-303c7aa2c05b}")
    ET.SubElement(meta, "Single", Name="TypeGuid", Type="System.Guid").text = "5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6"
    ET.SubElement(meta, "Single", Name="Timestamp", Type="long").text = str(int(datetime.now().timestamp() * 10000000 + 621355968000000000))

    # Object
    obj = ET.SubElement(root, "Single", Name="Object", Type="{5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6}", Method="IArchivable")
    obj_textdoc = ET.SubElement(obj, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(obj_textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(glv_full)
    ET.SubElement(obj_textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_LineIds"

    # Path et Parent
    ET.SubElement(root, "Single", Name="ParentSVNodeGuid", Type="System.Guid").text = APP_PARENT_GUID
    path_arr = ET.SubElement(root, "Array", Name="Path", Type="string")
    ET.SubElement(path_arr, "Single", Type="string").text = "Device"
    ET.SubElement(path_arr, "Single", Type="string").text = "Logique API"

    ET.SubElement(root, "Single", Name="Index", Type="int").text = "-1"

    return root, guid


def main():
    if not DEVICE_EXPORT.exists():
        print(f"[ERROR] {DEVICE_EXPORT} not found")
        return False

    print("=" * 70)
    print("CREATING NEW POUs AND GVLs IN DEVICE.EXPORT")
    print("=" * 70)

    # Parse Device.export
    try:
        tree = ET.parse(str(DEVICE_EXPORT))
        root = tree.getroot()
    except Exception as e:
        print(f"[ERROR] Cannot parse Device.export: {e}")
        return False

    # Créer backup
    backup_path = DEVICE_EXPORT.with_suffix(f".export.{datetime.now().strftime('%Y%m%d_%H%M%S')}.bak")
    import shutil
    shutil.copy(str(DEVICE_EXPORT), str(backup_path))
    print(f"Backup created: {backup_path.name}")

    created_count = 0

    # Créer les POUs
    print("\n[POUs]")
    for pou_config in POUS_TO_CREATE:
        print(f"  Creating {pou_config['name']}...", end=" ")
        pou_elem, guid = create_pou_xml(pou_config)
        if pou_elem is None:
            print("[SKIP]")
            continue

        root.append(pou_elem)
        print(f"[OK] {guid[:8]}...")
        created_count += 1

    # Créer les GVLs
    print("\n[GVLs]")
    for glv_config in GLVS_TO_CREATE:
        print(f"  Creating {glv_config['name']}...", end=" ")
        glv_elem, guid = create_glv_xml(glv_config)
        if glv_elem is None:
            print("[SKIP]")
            continue

        root.append(glv_elem)
        print(f"[OK] {guid[:8]}...")
        created_count += 1

    # Write back
    print(f"\nWriting {created_count} new elements...")
    try:
        tree.write(str(DEVICE_EXPORT), encoding='utf-8', xml_declaration=True)
        print("[OK] Device.export updated")
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

    print("\n" + "=" * 70)
    print(f"SUCCESS: {created_count} new POUs/GVLs added to Device.export")
    print("=" * 70)
    print("\nNext: python tools/extract.py --yes")
    return True


if __name__ == '__main__':
    import sys
    sys.exit(0 if main() else 1)
