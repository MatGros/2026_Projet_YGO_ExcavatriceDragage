"""Garde-fou : PRG_02_Acquisition_CFC est une page CFC XML native (15 sorties, sans bridge)."""

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
XML_PATH = ROOT / "CODE" / "MAIN" / "PRG_02_Acquisition_CFC.xml"
LEGACY_ST = ROOT / "CODE" / "MAIN" / "PRG_02_Acquisition_CFC.st"
BRIDGE = ROOT / "CODE" / "ACQUISITION" / "FB_AcquisitionLegacyBridge.st"
NS = {"p": "http://www.plcopen.org/xml/tc6_0200"}


def test_acquisition_cfc_is_native_xml_and_legacy_program_st_is_absent():
    assert XML_PATH.is_file()
    assert not LEGACY_ST.exists()

    root = ET.parse(XML_PATH).getroot()
    pou = root.find(".//p:pou", NS)
    assert pou is not None
    assert pou.attrib["name"] == "PRG_02_Acquisition_CFC"
    st = pou.find(".//p:ST", NS)
    assert st is not None
    assert any(node.tag.endswith("xhtml") for node in st)
    assert pou.find(".//p:CFC", NS) is not None


def test_acquisition_cfc_publishes_public_contract_without_bridge():
    root = ET.parse(XML_PATH).getroot()
    # Vérifier que le pont legacy n'est plus instancié
    bridge_block = root.find(".//p:block[@typeName='FB_AcquisitionLegacyBridge']", NS)
    assert bridge_block is None

    interface = root.find(".//p:outputVars", NS)
    assert interface is not None
    outputs = {var.attrib["name"] for var in interface.findall("p:variable", NS)}
    expected = {
        "HwReal", "HwSim", "HwIn", "WinchInputSourceChanged",
        "TranslationPosTremie", "TranslationPosPV", "TranslationPosP2",
        "TranslationPosP1", "TranslationPosMaintenance",
        "M3_StatusWord_Filtered", "M3_ActualFrequencyHz_Filtered",
        "M3_LimitSwitchFwd", "M3_LimitSwitchRev",
        "M3_SensorWordIncoherent", "M3_SensorsWord",
    }
    assert expected <= outputs

    published = {node.findtext("p:expression", namespaces=NS) for node in root.findall(".//p:outVariable", NS)}
    assert expected <= published
