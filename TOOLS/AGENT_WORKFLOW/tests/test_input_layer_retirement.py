"""Garde-fous de retrait de l'ancienne couche PRG_01/FB_Input.

Le test historique test_prg_inputs_ld_standalone_import.py est archivé :
il vérifiait volontairement la présence de PRG_01, désormais retiré.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = ROOT / "CODE" / "CODE_Bundle.xml"
NS = {"pou": "http://www.plcopen.org/xml/tc6_0200"}


def _bundle_root() -> ET.Element:
    assert BUNDLE.is_file(), f"Bundle absent : {BUNDLE}"
    return ET.parse(BUNDLE).getroot()


def _pou_names(root: ET.Element) -> set[str]:
    return {
        pou.get("name")
        for pou in root.findall(".//pou:pou", NS)
        if pou.get("name")
    }


def test_legacy_input_layer_is_absent_from_bundle() -> None:
    names = _pou_names(_bundle_root())
    assert "PRG_01_Inputs_LD" not in names
    assert "FB_Input" not in names


def test_legacy_qualified_types_are_absent_from_bundle() -> None:
    root = _bundle_root()
    data_types = {
        data_type.get("name")
        for data_type in root.findall(".//pou:dataType", NS)
        if data_type.get("name")
    }
    assert not {
        "ST_InputsQualified",
        "ST_InputsQualifiedMachine",
        "ST_InputsQualifiedTranslation",
        "ST_InputsQualifiedWinch",
    } & data_types


def test_acquisition_filter_is_present_and_used() -> None:
    root = _bundle_root()
    names = _pou_names(root)
    assert "PRG_02_Acquisition" in names
    assert "FB_DigitalInputFilter" in names
    acquisition = next(
        pou for pou in root.findall(".//pou:pou", NS)
        if pou.get("name") == "PRG_02_Acquisition"
    )
    body_text = ET.tostring(acquisition, encoding="unicode")
    assert body_text.count("FB_DigitalInputFilter") >= 22
    assert "HwRealQualified" in body_text
