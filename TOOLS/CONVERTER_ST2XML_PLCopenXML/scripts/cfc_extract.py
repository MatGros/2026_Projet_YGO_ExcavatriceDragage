#!/usr/bin/env python3
"""cfc_extract.py — Extract ``<pou>`` element(s) from native CFC ``.xml`` file(s).

With a single input file, reads a native CODESYS CFC export (e.g.
``PRG_AU_Acquisition_CFC.xml``), strips the ``<project>`` wrapper, cleans
namespaces (removes ``ns0:`` prefixes, restores ``xmlns=""`` on
``CallType``/``ElementType``), and aligns the ``ObjectId`` with a deterministic
GUID derived from the POU name.  The output is a standalone ``<pou>`` element
containing the CFC body.

With multiple input files, generates a full ``<project>`` bundle containing
all the CFC POUs assembled together (with ``<ProjectStructure>``, ObjectIds
aligned, and inter-object dependencies resolved).

Usage:
    python scripts/cfc_extract.py CODE/MAIN/PRG_AU_Acquisition_CFC.xml -o output.xml
    python scripts/cfc_extract.py CODE/MAIN/PRG_AU_Acquisition_CFC.xml CODE/MAIN/PRG_GLOBAL_CFC.xml -o bundle.xml
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

from generator.diagnostics import DiagnosticCollector, Severity  # noqa: E402
from generator.guid import object_guid  # noqa: E402
from generator.xml_serializer import serialize  # noqa: E402

from scripts._common import build_multi_file_project, cfc_pou_name, make_cfc_source_object  # noqa: E402


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


def extract_cfc_project_xml(
    xml_paths: list[Path], diagnostics: DiagnosticCollector
) -> bytes:
    """Assemble a full ``<project>`` bundle from multiple native CFC ``.xml`` files."""
    objects_by_name: dict[str, object] = {}
    root_names: list[str] = []
    for xml_path in xml_paths:
        obj = make_cfc_source_object(xml_path)
        if obj.name in objects_by_name:
            diagnostics.warning(
                f"duplicate POU name {obj.name!r} — already seen, skipping {xml_path}",
                obj.name,
            )
            continue
        objects_by_name[obj.name] = obj
        root_names.append(obj.name)
    if not root_names:
        raise ValueError("no valid CFC POU found among the input files")
    return build_multi_file_project(objects_by_name, root_names, diagnostics)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="cfc_extract.py",
        description=(
            "Extract <pou> element(s) from native CFC .xml file(s). Single file "
            "→ standalone <pou> (namespace-clean, ObjectId-aligned); multiple "
            "files → full <project> bundle."
        ),
    )
    parser.add_argument(
        "xml_files",
        nargs="+",
        type=Path,
        help="One or more source CFC .xml files",
    )
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .xml file")
    args = parser.parse_args(argv)

    xml_paths: list[Path] = args.xml_files
    out_path: Path = args.output

    for xml_path in xml_paths:
        if not xml_path.is_file():
            print(f"error: input file not found: {xml_path}", file=sys.stderr)
            return 1

    diagnostics = DiagnosticCollector()
    try:
        if len(xml_paths) == 1:
            data = extract_cfc_pou(xml_paths[0])
            label = "CFC POU"
        else:
            data = extract_cfc_project_xml(xml_paths, diagnostics)
            label = f"CFC project bundle ({len(xml_paths)} POUs)"
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(data)

    for diag in diagnostics:
        stream = sys.stdout if diag.severity is Severity.INFO else sys.stderr
        print(str(diag), file=stream)

    print(f"{label} written to {out_path}", file=sys.stderr)
    return 1 if diagnostics.has_errors() else 0


if __name__ == "__main__":
    raise SystemExit(main())