#!/usr/bin/env python3
"""
Fill empty CODESYS POUs (TextLines) with ST code from .st files
Maps .st files to corresponding .xml files and updates TextBlobForSerialisation
"""

import xml.etree.ElementTree as ET
import os
import re

# Map ST file content to XML POU
MAPPINGS = [
    ("CODE/FB_DiagCanOpen.st", "CODE/DiagCanOpen__2f6867ac-7a6a-46ff-b874-0cb8099fff11.xml"),
    ("CODE/FB_BusAggregator.st", "CODE/BusAggregator__2b4ef824-ef6d-4538-9653-5fe1b189498c.xml"),
    ("CODE/PRG_BusMonitor.st", "CODE/PRG_BusMonitor__434f83d9-99f2-4175-ac83-d43a4660b11e.xml"),
]

def extract_interface_and_implementation(st_content):
    """Split ST code into interface and implementation sections"""
    # Find FUNCTION_BLOCK or PROGRAM
    match = re.search(r'(FUNCTION_BLOCK|PROGRAM)\s+(\w+)(.*?)END_\1', st_content, re.DOTALL)
    if not match:
        return None, None

    full_content = match.group(3)

    # Extract VAR declarations (everything before the main code)
    var_match = re.search(r'(VAR.*?END_VAR(?:\s*VAR.*?END_VAR)*)', full_content, re.DOTALL)

    if var_match:
        interface = var_match.group(1)
        # Implementation is everything after the last END_VAR
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

def update_xml_with_st(xml_path, st_content):
    """Update XML file with ST content"""
    # Parse XML
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Define namespace
    ns = {'': 'urn:schemas-microsoft-com:xml-msdata'}

    # Find TextDocument elements
    text_docs = root.findall('.//TextDocument[@Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}"]', ns)

    if not text_docs:
        print(f"  Warning: No TextDocument found in {xml_path}")
        return False

    # Extract interface and implementation
    interface_block, impl_block = extract_interface_and_implementation(st_content)

    if not interface_block or not impl_block:
        print(f"  Error parsing {st_content_file}")
        return False

    # Update Interface TextBlobForSerialisation
    interface_found = False
    for i, text_doc in enumerate(text_docs):
        if i == 0:  # First TextDocument = Interface
            # Extract the FUNCTION_BLOCK / PROGRAM line
            fb_match = re.search(r'(FUNCTION_BLOCK|PROGRAM)\s+(\w+)', st_content)
            if fb_match:
                fb_type = fb_match.group(1)
                fb_name = fb_match.group(2)
                interface_full = f"{fb_type} {fb_name}\n{interface_block}\nEND_{fb_type}"

                # Create or update TextBlobForSerialisation
                blob = text_doc.find('TextBlobForSerialisation')
                if blob is None:
                    blob = ET.SubElement(text_doc, 'Single')
                    blob.set('Name', 'TextBlobForSerialisation')
                    blob.set('Type', 'string')

                blob.text = escape_xml(interface_full)
                interface_found = True
        elif i == 1:  # Second TextDocument = Implementation
            # Create or update TextBlobForSerialisation
            blob = text_doc.find('TextBlobForSerialisation')
            if blob is None:
                blob = ET.SubElement(text_doc, 'Single')
                blob.set('Name', 'TextBlobForSerialisation')
                blob.set('Type', 'string')

            blob.text = escape_xml(impl_block)

    if not interface_found:
        print(f"  Error: Could not find interface section in {xml_path}")
        return False

    # Write updated XML
    tree.write(xml_path, encoding='utf-8')
    print(f"  ✓ Updated {xml_path}")
    return True

# Main
if __name__ == '__main__':
    cwd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(cwd)

    print("Filling empty CODESYS POUs with ST content...\n")

    for st_file, xml_file in MAPPINGS:
        if not os.path.exists(st_file):
            print(f"✗ {st_file} not found")
            continue

        if not os.path.exists(xml_file):
            print(f"✗ {xml_file} not found")
            continue

        print(f"Processing {st_file} → {xml_file}")
        st_content = read_st_file(st_file)
        update_xml_with_st(xml_file, st_content)

    print("\nDone!")
