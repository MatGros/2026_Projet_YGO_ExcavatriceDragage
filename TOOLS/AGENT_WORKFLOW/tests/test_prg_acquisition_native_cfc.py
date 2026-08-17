"""Garde-fou : PRG_02_Acquisition est un programme ST pur (15 sorties publiques)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ST_PATH = ROOT / "CODE" / "M_MAIN" / "PRG_02_Acquisition.st"
LEGACY_XML = ROOT / "CODE" / "M_MAIN" / "PRG_02_Acquisition_CFC.xml"

def test_acquisition_is_pure_st_and_legacy_xml_is_absent():
    assert ST_PATH.is_file()
    assert not LEGACY_XML.exists()

    content = ST_PATH.read_text(encoding="utf-8")
    assert "PROGRAM PRG_02_Acquisition" in content
    assert "HwIn" in content
    assert "HwReal" in content
    assert "HwSim" in content


def test_acquisition_publishes_public_contract():
    content = ST_PATH.read_text(encoding="utf-8")
    expected = [
        "HwReal", "HwSim", "HwIn", "WinchInputSourceChanged",
        "TranslationPosTremie", "TranslationPosPV", "TranslationPosP2",
        "TranslationPosP1", "TranslationPosMaintenance",
        "M3_StatusWord_Filtered", "M3_ActualFrequencyHz_Filtered",
        "M3_LimitSwitchFwd", "M3_LimitSwitchRev",
        "M3_SensorWordIncoherent", "M3_SensorsWord",
    ]
    for name in expected:
        assert name in content, f"Sortie publique {name} absente de PRG_02_Acquisition.st"
