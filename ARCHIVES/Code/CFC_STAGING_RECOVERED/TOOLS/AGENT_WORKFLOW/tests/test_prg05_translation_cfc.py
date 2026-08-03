"""Garde M4 : Translation M3 native CFC, safety visible et dette BrakeCmd conservée."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PAGE = ROOT / "CODE" / "MAIN" / "PRG_05_Translation_CFC.xml"
NS = "{http://www.plcopen.org/xml/tc6_0200}"


def _blocks(root: ET.Element) -> dict[str, ET.Element]:
    return {element.attrib.get("instanceName", ""): element for element in root.iter(f"{NS}block")}


def _input_ref(block: ET.Element, formal_parameter: str) -> str:
    for variable in block.find(f"{NS}inputVariables"):
        if variable.attrib.get("formalParameter") == formal_parameter:
            connection = variable.find(f".//{NS}connection")
            assert connection is not None
            return connection.attrib["refLocalId"]
    raise AssertionError(f"entrée absente : {formal_parameter}")


def test_translation_is_native_cfc_with_empty_st_body() -> None:
    root = ET.parse(PAGE).getroot()
    pou = root.find(f".//{NS}pou")
    assert pou is not None
    assert pou.attrib["name"] == "PRG_05_Translation_CFC"
    st = pou.find(f".//{NS}body/{NS}ST")
    assert st is not None
    assert not (st.text or "").strip()
    assert pou.find(f".//{NS}CFC") is not None


def test_translation_safety_is_visible_and_drives_movement_and_request() -> None:
    root = ET.parse(PAGE).getroot()
    blocks = _blocks(root)
    for instance in (
        "instTranslationArbiter",
        "instSafetyTranslationM3",
        "instTranslationM3",
        "instTranslationRequestPublisher",
    ):
        assert instance in blocks

    safe_stop_to_translation = _input_ref(blocks["instTranslationM3"], "SafeStop")
    safe_stop_to_request = _input_ref(blocks["instTranslationRequestPublisher"], "SafeStop")
    assert safe_stop_to_translation == safe_stop_to_request

    connectors = {element.attrib["localId"]: element for element in root.iter(f"{NS}connector")}
    safe_connector = connectors[safe_stop_to_translation]
    source = safe_connector.find(f".//{NS}connection")
    assert source is not None
    assert source.attrib["refLocalId"] == "101"
    assert source.attrib["formalParameter"] == "SafeStop"

    direction_to_safety = _input_ref(blocks["instSafetyTranslationM3"], "Direction")
    direction_to_motion = _input_ref(blocks["instTranslationM3"], "Direction")
    assert direction_to_safety == direction_to_motion


def test_brake_cmd_debt_keeps_legacy_outputs_command_source() -> None:
    root = ET.parse(PAGE).getroot()
    blocks = _blocks(root)
    connector_id = _input_ref(blocks["instSafetyTranslationM3"], "BrakeCmd")
    connector = next(element for element in root.iter(f"{NS}connector") if element.attrib["localId"] == connector_id)
    source_id = connector.find(f".//{NS}connection").attrib["refLocalId"]
    source = next(element for element in root.iter(f"{NS}inVariable") if element.attrib["localId"] == source_id)
    assert source.find(f"{NS}expression").text == "GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd"
