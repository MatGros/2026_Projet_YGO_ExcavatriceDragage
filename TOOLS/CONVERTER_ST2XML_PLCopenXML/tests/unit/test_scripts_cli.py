"""Tests for the modular CLI scripts in ``scripts/``.

These tests validate the testable contract:
  1. st_to_pou.py → valid XML, 1 <pou> with 1 <body><ST>
  2. cfc_extract.py → valid XML, 1 <pou> with CFC body, ObjectIds aligned, xmlns=""
  3. build_bundle.py → valid <project> with <ProjectStructure>, ObjectId alignment, no nested addData
  4. st_to_dut.py → valid XML, 1 <dataType>
  5. Error handling: missing file exits 1
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

# Ensure the tool root is on sys.path (so ``scripts`` and ``generator`` import).
import sys
import os

_TOOL_ROOT = Path(__file__).resolve().parent.parent.parent  # CONVERTER_ST2XML_PLCopenXML/
if str(_TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOL_ROOT))

_REPO_ROOT = _TOOL_ROOT.parent.parent  # project root (CODE/ lives here)
CODE_DIR = _REPO_ROOT / "CODE"
MAIN_DIR = CODE_DIR / "M_MAIN" if (CODE_DIR / "M_MAIN").is_dir() else CODE_DIR / "MAIN"
AU_DIR = CODE_DIR / "B_AU_SECURITE" if (CODE_DIR / "B_AU_SECURITE").is_dir() else CODE_DIR / "AU"
CYCLE_DIR = CODE_DIR / "G_CYCLE" if (CODE_DIR / "G_CYCLE").is_dir() else CODE_DIR / "CYCLE"

from scripts.st_to_pou import build_st_pou_xml, build_st_project_xml
from scripts.st_to_dut import build_dut_xml, build_dut_project_xml
from scripts.cfc_extract import extract_cfc_pou, extract_cfc_project_xml
from scripts.build_bundle import _collect_objects_from_args

from generator.diagnostics import DiagnosticCollector
from generator.xml_serializer import serialize

PLCOPEN_NS = "http://www.plcopen.org/xml/tc6_0200"


def _parse_strip_ns(data: bytes) -> ET.Element:
    """Parse bytes and strip PLCopen namespace prefixes for plain-tag queries."""
    root = ET.fromstring(data)
    for el in root.iter():
        if "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]
    return root


def _has_xmlns_empty(element: ET.Element, tag: str) -> bool:
    """Check that an element's serialized form carries ``xmlns=""``.

    ET.parse() drops xmlns="" attributes, so we inspect the raw bytes instead.
    """
    # Re-serialize this element and check
    raw = ET.tostring(element).decode("utf-8")
    return f'<{tag} xmlns="">' in raw or f'<{tag} xmlns=""' in raw


# ── st_to_pou.py ─────────────────────────────────────────────────────────────


def test_st_to_pou_produces_valid_pou_with_st_body():
    st_file = AU_DIR / "FB_Safety_EmergencyManagement.st"
    if not st_file.exists():
        pytest.skip("FB_Safety_EmergencyManagement.st not available")
    diag = DiagnosticCollector()
    data = build_st_pou_xml(st_file, diag)
    root = _parse_strip_ns(data)

    assert root.tag == "pou"
    assert len([root]) == 1
    pou = root
    assert pou.get("name") == "FB_Safety_EmergencyManagement"

    bodies = pou.findall("body")
    assert len(bodies) == 1
    st = bodies[0].find("ST")
    assert st is not None, "body must contain <ST>"


def test_st_to_pou_missing_file_exits_1(tmp_path):
    from scripts.st_to_pou import main

    rc = main([str(tmp_path / "nonexistent.st"), "-o", str(tmp_path / "out.xml")])
    assert rc == 1


# ── cfc_extract.py ───────────────────────────────────────────────────────────


def test_cfc_extract_produces_valid_pou_with_aligned_objectid():
    xml_file = MAIN_DIR / "PRG_AU_Acquisition_CFC.xml"
    if not xml_file.exists():
        pytest.skip("PRG_AU_Acquisition_CFC.xml not available")
    data = extract_cfc_pou(xml_file)
    root = _parse_strip_ns(data)

    assert root.tag == "pou"
    assert root.get("name") == "PRG_AU_Acquisition"

    # ObjectId present and non-empty
    object_id = root.find(".//ObjectId")
    assert object_id is not None
    assert object_id.text

    # CallType / ElementType must have xmlns=""
    raw_text = data.decode("utf-8-sig")
    if "CallType" in raw_text:
        assert 'CallType xmlns=""' in raw_text
    if "ElementType" in raw_text:
        assert 'ElementType xmlns=""' in raw_text


def test_cfc_extract_missing_file_exits_1(tmp_path):
    from scripts.cfc_extract import main

    rc = main([str(tmp_path / "nonexistent.xml"), "-o", str(tmp_path / "out.xml")])
    assert rc == 1


# ── st_to_dut.py ─────────────────────────────────────────────────────────────


def test_st_to_dut_produces_valid_datatype_struct():
    st_file = AU_DIR / "ST_Safety_Emergency_HmiState.st"
    if not st_file.exists():
        pytest.skip("ST_Safety_Emergency_HmiState.st not available")
    diag = DiagnosticCollector()
    data = build_dut_xml(st_file, diag)
    root = _parse_strip_ns(data)

    assert root.tag == "dataType"
    assert root.get("name") == "ST_Safety_Emergency_HmiState"
    struct = root.find("baseType/struct")
    assert struct is not None


def test_st_to_dut_produces_valid_datatype_enum():
    st_file = CYCLE_DIR / "E_CycleStep.st"
    if not st_file.exists():
        pytest.skip("E_CycleStep.st not available")
    diag = DiagnosticCollector()
    data = build_dut_xml(st_file, diag)
    root = _parse_strip_ns(data)

    assert root.tag == "dataType"
    assert root.get("name") == "E_CycleStep"
    enum = root.find("baseType/enum")
    assert enum is not None


def test_st_to_dut_rejects_fb():
    st_file = AU_DIR / "FB_Safety_EmergencyManagement.st"
    if not st_file.exists():
        pytest.skip("FB_Safety_EmergencyManagement.st not available")
    diag = DiagnosticCollector()
    with pytest.raises(ValueError, match="STRUCT or ENUM"):
        build_dut_xml(st_file, diag)


def test_st_to_dut_missing_file_exits_1(tmp_path):
    from scripts.st_to_dut import main

    rc = main([str(tmp_path / "nonexistent.st"), "-o", str(tmp_path / "out.xml")])
    assert rc == 1


# ── build_bundle.py ──────────────────────────────────────────────────────────


def test_build_bundle_produces_valid_project_with_project_structure():
    au_dir = AU_DIR
    if not au_dir.exists():
        pytest.skip("CODE/AU/ not available")
    diag = DiagnosticCollector()
    objects_by_name = _collect_objects_from_args([au_dir], diag)

    assert len(objects_by_name) > 0

    from generator.xml_builder import build_project_xml

    root_names = sorted(objects_by_name.keys())
    root = build_project_xml(
        root_names,
        objects_by_name,
        diag,
        include_deps=True,
        project_name="TestBundle",
    )
    data = serialize(root)

    # Parse and strip namespace
    parsed = _parse_strip_ns(data)
    assert parsed.tag == "project"

    # ProjectStructure must exist
    ps = parsed.find(".//ProjectStructure")
    assert ps is not None, "bundle must contain <ProjectStructure>"

    # ObjectId alignment: every ObjectId in ProjectStructure must exist in the project body
    ps_ids = {obj.get("ObjectId") for obj in ps.findall(".//Object")}
    all_object_ids = set()
    for oid in parsed.findall(".//ObjectId"):
        if oid.text:
            all_object_ids.add(oid.text)
    mismatch = ps_ids.symmetric_difference(all_object_ids)
    assert mismatch == set(), f"ObjectId mismatch between ProjectStructure and project body: {mismatch}"

    # No nested addData inside addData
    for el in parsed.iter("addData"):
        nested = [c for c in el if c.tag == "addData"]
        assert len(nested) == 0, f"nested <addData> found inside <addData>"


def test_build_bundle_from_multiple_inputs():
    au_dir = AU_DIR
    st_file = MAIN_DIR / "PRG_06_Outputs.st"
    if not au_dir.exists() or not st_file.exists():
        pytest.skip("required inputs not available")
    diag = DiagnosticCollector()
    objects_by_name = _collect_objects_from_args([au_dir, st_file], diag)
    # PRG_06_Outputs should be included
    assert "PRG_06_Outputs" in objects_by_name


def test_build_bundle_missing_path_reports_error(tmp_path):
    diag = DiagnosticCollector()
    objects_by_name = _collect_objects_from_args([tmp_path / "nonexistent"], diag)
    assert len(objects_by_name) == 0
    assert diag.has_errors()


def test_build_bundle_main_exits_1_on_no_objects(tmp_path):
    from scripts.build_bundle import main

    rc = main([str(tmp_path / "nonexistent_dir"), "-o", str(tmp_path / "out.xml")])
    assert rc == 1


# ── Multi-file mode tests ─────────────────────────────────────────────────────


def _assert_valid_project_bundle(data: bytes, expected_pou_count: int) -> ET.Element:
    """Shared assertions for multi-file ``<project>`` bundle output."""
    root = _parse_strip_ns(data)
    assert root.tag == "project"

    # ProjectStructure must exist
    ps = root.find(".//ProjectStructure")
    assert ps is not None, "bundle must contain <ProjectStructure>"

    # ObjectId alignment: 0 mismatch between ProjectStructure and project body
    ps_ids = {obj.get("ObjectId") for obj in ps.findall(".//Object")}
    all_object_ids = set()
    for oid in root.findall(".//ObjectId"):
        if oid.text:
            all_object_ids.add(oid.text)
    mismatch = ps_ids.symmetric_difference(all_object_ids)
    assert mismatch == set(), f"ObjectId mismatch: {mismatch}"

    # No nested addData inside addData
    for el in root.iter("addData"):
        nested = [c for c in el if c.tag == "addData"]
        assert len(nested) == 0, "nested <addData> found inside <addData>"

    # CallType/ElementType must have xmlns=""
    raw_text = data.decode("utf-8-sig")
    if "CallType" in raw_text:
        assert 'CallType xmlns=""' in raw_text
    if "ElementType" in raw_text:
        assert 'ElementType xmlns=""' in raw_text

    # fileHeader / contentHeader / types / instances / addData present
    assert root.find("fileHeader") is not None
    assert root.find("contentHeader") is not None
    assert root.find("types") is not None
    assert root.find("instances") is not None
    assert root.find("addData") is not None

    pous = root.findall(".//pou")
    assert len(pous) == expected_pou_count

    return root


def test_st_to_pou_multi_file_produces_valid_project():
    """st_to_pou.py with 2 files → <project> with 2 <pou> in <ST>."""
    f1 = AU_DIR / "FB_Safety_EmergencyManagement.st"
    f2 = AU_DIR / "FB_Safety_EmergencyManagementLogic.st"
    if not f1.exists() or not f2.exists():
        pytest.skip("POU ST test files not available")
    diag = DiagnosticCollector()
    data = build_st_project_xml([f1, f2], diag)
    root = _assert_valid_project_bundle(data, 2)
    for pou in root.findall(".//pou"):
        st = pou.find(".//ST")
        assert st is not None, f"pou {pou.get('name')} must have <ST> body"


def test_cfc_extract_multi_file_produces_valid_project():
    """cfc_extract.py with 2 files → <project> with 2 CFC <pou>."""
    f1 = MAIN_DIR / "PRG_AU_Acquisition_CFC.xml"
    f2 = MAIN_DIR / "PRG_GLOBAL_CFC.xml"
    if not f1.exists() or not f2.exists():
        pytest.skip("CFC test files not available")
    diag = DiagnosticCollector()
    data = extract_cfc_project_xml([f1, f2], diag)
    root = _assert_valid_project_bundle(data, 2)
    pou_names = {p.get("name") for p in root.findall(".//pou")}
    assert "PRG_AU_Acquisition" in pou_names
    assert "PRG_GLOBAL_CFC" in pou_names


def test_st_to_dut_multi_file_produces_valid_project():
    """st_to_dut.py with 2 files → <project> with 2 <dataType>."""
    f1 = AU_DIR / "ST_Safety_Emergency_State.st"
    f2 = AU_DIR / "ST_Safety_Emergency_Diag.st"
    if not f1.exists() or not f2.exists():
        pytest.skip("DUT test files not available")
    diag = DiagnosticCollector()
    data = build_dut_project_xml([f1, f2], diag)
    root = _assert_valid_project_bundle(data, 0)  # 0 pous, 2 dataTypes
    dts = root.findall(".//dataType")
    assert len(dts) == 2
    dt_names = {dt.get("name") for dt in dts}
    assert "ST_Safety_Emergency_State" in dt_names
    assert "ST_Safety_Emergency_Diag" in dt_names