#!/usr/bin/env python3
"""
Fill CODESYS POUs with ST content from .st files
Maps .st files to corresponding .xml files and updates TextBlobForSerialisation
"""

import xml.etree.ElementTree as ET
import os
import re
import sys

# Maps ST file → XML file by name
# Format: ("CODE/FileName.st", "CODE/FileName__GUID.xml")
MAPPINGS = [
    ("CODE/_TYPES.st", None),  # GVL_TYPES à créer manuellement dans CODESYS
    ("CODE/FB_DiagCanOpen.st", "CODE/DiagCanOpen__2f6867ac-7a6a-46ff-b874-0cb8099fff11.xml"),
    ("CODE/FB_BusAggregator.st", "CODE/BusAggregator__2b4ef824-ef6d-4538-9653-5fe1b189498c.xml"),
    ("CODE/FB_DiagEthercat.st", "CODE/diagETHERCAT__975119be-0e7c-4573-b289-5a04c2df8200.xml"),
    ("CODE/PRG_BusMonitor.st", "CODE/PRG_BusMonitor__434f83d9-99f2-4175-ac83-d43a4660b11e.xml"),
    ("CODE/FB_Safety.st", "CODE/FB_Safety__ae8cf596-3b07-456b-876e-68529c263a0c.xml"),
    ("CODE/FB_Encoder_Abs.st", "CODE/FB_Encoder_Abs__ac34b69a-d1e5-4495-94d7-6f60d31a26d9.xml"),
    ("CODE/GVL_BusHealth.st", None),  # GVL à créer manuellement dans CODESYS
]

def extract_interface_and_implementation(st_content):
    """Split ST code into interface (declarations) and implementation (code)"""
    # Match FUNCTION_BLOCK or PROGRAM
    match = re.search(
        r'(FUNCTION_BLOCK|PROGRAM|VAR_GLOBAL)\s+(\w+)(.*)',
        st_content,
        re.DOTALL
    )
    if not match:
        return None, None

    fb_type = match.group(1)  # FUNCTION_BLOCK, PROGRAM, or VAR_GLOBAL
    full_content = match.group(3)

    # For GVLs (VAR_GLOBAL), the entire content is "interface"
    if fb_type == "VAR_GLOBAL":
        return full_content, ""

    # For FB/PROGRAM: extract VAR sections (interface) and remaining code (implementation)
    var_match = re.search(
        r'(VAR.*?END_VAR(?:\s*VAR.*?END_VAR)*)',
        full_content,
        re.DOTALL
    )

    if var_match:
        interface = var_match.group(1)
        impl_start = var_match.end()
        implementation = full_content[impl_start:].strip()
    else:
        interface = ""
        implementation = full_content.strip()

    return interface, implementation

def escape_xml(text):
    """Escape special XML characters"""
    return (text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
    )

def read_st_file(filepath):
    """Read ST file content"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def update_xml_with_st(xml_path, st_content, st_filename):
    """Update XML TextDocument with ST content"""
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except Exception as e:
        print(f"  [ERROR] Error parsing XML: {e}")
        return False

    # Navigate to Object/Implementation and Object/Interface
    obj_elem = root.find('.//Single[@Name="Object"]')
    if obj_elem is None:
        print(f"  [ERROR] Cannot find Object element")
        return False

    impl_elem = obj_elem.find('.//Single[@Name="Implementation"]')
    iface_elem = obj_elem.find('.//Single[@Name="Interface"]')

    if impl_elem is None or iface_elem is None:
        print(f"  [ERROR] Missing Implementation or Interface element")
        return False

    impl_textdoc = impl_elem.find('.//Single[@Name="TextDocument"]')
    iface_textdoc = iface_elem.find('.//Single[@Name="TextDocument"]')

    if impl_textdoc is None or iface_textdoc is None:
        print(f"  [ERROR] Missing TextDocument in Implementation/Interface")
        return False

    text_docs = [iface_textdoc, impl_textdoc]  # [Interface, Implementation]

    interface_block, impl_block = extract_interface_and_implementation(st_content)

    if interface_block is None:
        print(f"  [ERROR] Error parsing ST file")
        return False

    # Get FB/PROGRAM declaration line
    decl_match = re.search(r'(FUNCTION_BLOCK|PROGRAM)\s+(\w+)', st_content)
    if not decl_match:
        print(f"  [ERROR] Cannot find FUNCTION_BLOCK or PROGRAM declaration")
        return False

    fb_type = decl_match.group(1)
    fb_name = decl_match.group(2)

    # Interface = "FUNCTION_BLOCK Name" + VAR sections + "END_FUNCTION_BLOCK"
    interface_full = f"{fb_type} {fb_name}\n{interface_block}\nEND_{fb_type}"

    # Fill interface TextDocument (text_docs[0] = Interface)
    blob = text_docs[0].find('.//Single[@Name="TextBlobForSerialisation"]')
    if blob is None:
        blob = ET.SubElement(text_docs[0], 'Single')
        blob.set('Name', 'TextBlobForSerialisation')
        blob.set('Type', 'string')
    blob.text = escape_xml(interface_full)

    # Fill implementation TextDocument (text_docs[1] = Implementation)
    blob = text_docs[1].find('.//Single[@Name="TextBlobForSerialisation"]')
    if blob is None:
        blob = ET.SubElement(text_docs[1], 'Single')
        blob.set('Name', 'TextBlobForSerialisation')
        blob.set('Type', 'string')
    blob.text = escape_xml(impl_block)

    # Write updated XML (NO declaration — these are fragments in Device.export)
    try:
        tree.write(xml_path, encoding='utf-8', xml_declaration=False)
        print(f"  [OK] Updated {os.path.basename(xml_path)}")
        return True
    except Exception as e:
        print(f"  [ERROR] Error writing XML: {e}")
        return False

def main():
    cwd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(cwd)

    print("=" * 70)
    print("FILLING CODESYS POUs WITH ST CONTENT")
    print("=" * 70)

    success_count = 0
    skip_count = 0
    fail_count = 0

    for st_file, xml_file in MAPPINGS:
        print(f"\n{st_file}")

        # Check for GVLs (to be created manually)
        if xml_file is None:
            print(f"  [GVL] Create manually in CODESYS")
            skip_count += 1
            continue

        # Check ST file exists
        if not os.path.exists(st_file):
            print(f"  ✗ ST file not found")
            fail_count += 1
            continue

        # Check XML file exists
        if not os.path.exists(xml_file):
            print(f"  ✗ XML file not found")
            fail_count += 1
            continue

        # Read ST and update XML
        st_content = read_st_file(st_file)
        if update_xml_with_st(xml_file, st_content, st_file):
            success_count += 1
        else:
            fail_count += 1

    print("\n" + "=" * 70)
    print(f"SUMMARY: {success_count} OK, {skip_count} GVLs (manual), {fail_count} errors")
    print("=" * 70)

    if fail_count > 0:
        print("\n[NOTES]")
        print("  - GVL_TYPES and GVL_BusHealth must be created manually in CODESYS")
        print("  - After filling XMLs, run: inject.py")
        print("  - Then reimport Device.export in CODESYS")
        sys.exit(1)

    print("\n[OK] Next step: python tools/inject.py")

if __name__ == '__main__':
    main()
