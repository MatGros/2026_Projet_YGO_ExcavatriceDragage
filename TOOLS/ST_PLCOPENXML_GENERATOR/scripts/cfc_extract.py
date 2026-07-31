#!/usr/bin/env python3
"""cfc_extract.py — Extract a single ``<pou>`` from a native CFC ``.xml`` file.

Reads a native CODESYS CFC export (e.g. ``PRG_AU_Acquisition_CFC.xml``),
strips the ``<project>`` wrapper, cleans namespaces (removes ``ns0:`` prefixes,
restores ``xmlns=""`` on ``CallType``/``ElementType``), and aligns the
``ObjectId`` with a deterministic GUID derived from the POU name.  The output
is a standalone ``<pou>`` element containing the CFC body.

Usage:
    python scripts/cfc_extract.py CODE/MAIN/PRG_AU_Acquisition_CFC.xml -o output.xml
"""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Bootstrap sys.path so both ``generator`` and ``scripts`` packages are importable
# whether this file is run as a script or imported as a module.
_SCRIPTS_DIR = Path(__file__).resolve().parent
_TOOL_ROOT = _SCRIPTS_DIR.parent
if str(_TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOL_ROOT))

from generator.guid import object_guid  # noqa: E402
from generator.xml_serializer import serialize  # noqa: E402

from scripts._common import cfc_pou_name  # noqa: E402


XHTML_NS = "http://www.w3.org/1999/xhtml"


def _clean_namespaces(pou_node: ET.Element, guid: str) -> None:
    """Strip PLCopen namespace prefixes and fix vendor extension namespaces.

    Mirrors the cleaning logic in ``build_project_xml`` for native XML POU
    extraction: removes ``{uri}tag`` prefixes, drops ``xmlns:*`` attributes,
    restores ``xmlns=""`` on ``CallType``/``ElementType``, sets ``xmlns`` on
    ``xhtml``, and aligns the ``ObjectId`` to the deterministic GUID.
    """
    for elem in pou_node.iter():
        if "}" in elem.tag:
            elem.tag = elem.tag.split("}", 1)[1]
        for key in list(elem.attrib.keys()):
            if "xmlns" in key or "}" in key:
                del elem.attrib[key]
        if elem.tag == "xhtml":
            elem.attrib["xmlns"] = XHTML_NS
        if elem.tag in ("CallType", "ElementType"):
            elem.attrib["xmlns"] = ""

    obj_id_node = next((n for n in pou_node.iter() if n.tag == "ObjectId"), None)
    if obj_id_node is not None:
        obj_id_node.text = guid
    else:
        pou_adddata = next((n for n in pou_node.findall("addData")), None)
        if pou_adddata is None:
            pou_adddata = ET.SubElement(pou_node, "addData")
        data_el = ET.SubElement(pou_adddata, "data")
        data_el.set("name", "http://www.3s-software.com/plcopenxml/objectid")
        data_el.set("handleUnknown", "discard")
        obj_id_el = ET.SubElement(data_el, "ObjectId")
        obj_id_el.text = guid


def extract_cfc_pou(xml_path: Path) -> bytes:
    tree = ET.parse(xml_path)
    root = tree.getroot()
    pou_node = next((n for n in root.iter() if n.tag.endswith("pou")), None)
    if pou_node is None:
        raise ValueError(f"no <pou> element found in {xml_path}")

    pou_name = cfc_pou_name(xml_path)
    guid = object_guid("program", pou_name)
    _clean_namespaces(pou_node, guid)
    return serialize(pou_node)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="cfc_extract.py",
        description="Extract a single <pou> from a native CFC .xml file (namespace-clean, ObjectId-aligned).",
    )
    parser.add_argument("xml_file", type=Path, help="Source CFC .xml file")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .xml file")
    args = parser.parse_args(argv)

    xml_path: Path = args.xml_file
    out_path: Path = args.output

    if not xml_path.is_file():
        print(f"error: input file not found: {xml_path}", file=sys.stderr)
        return 1

    try:
        data = extract_cfc_pou(xml_path)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(data)
    print(f"CFC POU written to {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())