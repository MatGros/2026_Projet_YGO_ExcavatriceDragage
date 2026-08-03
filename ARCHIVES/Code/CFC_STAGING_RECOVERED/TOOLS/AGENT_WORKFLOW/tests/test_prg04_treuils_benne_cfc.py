"""Garde M3 : la page CFC Treuils/Benne rend la safety M1/M2 visible et câblée."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PAGE = ROOT / "CODE" / "MAIN" / "PRG_04_Treuils_Benne_CFC.xml"
NS = "{http://www.plcopen.org/xml/tc6_0200}"


def test_treuils_benne_is_native_cfc_with_empty_st_body() -> None:
    root = ET.parse(PAGE).getroot()
    pou = root.find(f".//{NS}pou")
    assert pou is not None
    assert pou.attrib["name"] == "PRG_04_Treuils_Benne_CFC"
    st = pou.find(f".//{NS}body/{NS}ST")
    assert st is not None
    assert not (st.text or "").strip()
    assert pou.find(f".//{NS}CFC") is not None


def test_treuils_benne_has_visible_safety_to_winch_links_for_both_axes() -> None:
    root = ET.parse(PAGE).getroot()
    blocks = {element.attrib.get("instanceName"): element for element in root.iter(f"{NS}block")}
    for instance in ("instSafetyWinchM1", "instSafetyWinchM2", "instWinchM1", "instWinchM2"):
        assert instance in blocks

    connectors = {element.attrib["localId"]: element for element in root.iter(f"{NS}connector")}
    expected = {
        "instWinchM1": ("201", "202", "203"),
        "instWinchM2": ("204", "205", "206"),
    }
    for winch, connector_ids in expected.items():
        inputs = {
            variable.attrib.get("formalParameter"): variable.find(f".//{NS}connection").attrib.get("refLocalId")
            for variable in blocks[winch].find(f"{NS}inputVariables")
        }
        assert tuple(inputs[name] for name in ("SafeStop", "ForbidDescent", "ForbidAscent")) == connector_ids
        for connector_id in connector_ids:
            assert connector_id in connectors
            position = connectors[connector_id].find(f"{NS}position")
            assert position is not None
            assert (position.attrib["x"], position.attrib["y"]) != ("0", "0")
