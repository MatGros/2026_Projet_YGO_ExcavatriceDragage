"""Garde-fou : PRG_02_Acquisition est un programme ST pur (sorties publiques)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ST_PATH = ROOT / "CODE" / "M_MAIN" / "PRG_02_Acquisition.st"
PRG05_PATH = ROOT / "CODE" / "M_MAIN" / "PRG_05_Translation.st"
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
        "M3_StatusWord_Filtered", "M3_ActualFrequencyHz_Filtered",
    ]
    for name in expected:
        assert name in content, f"Sortie publique {name} absente de PRG_02_Acquisition.st"


def test_decodeur_m3_publie_dans_prg05():
    # T161 (AF-02 TBD §8 #5) : le décodage M3 a migré de PRG_02 vers PRG_05.
    # PRG_02 ne publie plus les faits M3 ; PRG_05 les produit et les publie.
    prg02 = ST_PATH.read_text(encoding="utf-8")
    prg05 = PRG05_PATH.read_text(encoding="utf-8")

    # PRG_02 ne doit plus publier les faits M3 (déplacés vers PRG_05)
    for name in ["TranslationPosTremie", "M3_LimitSwitchFwd", "M3_SensorWordIncoherent", "M3_SensorsWord"]:
        assert name not in prg02, f"Fait M3 {name} encore publié par PRG_02 (migré vers PRG_05 par T161)"

    # PRG_05 doit publier les faits M3
    for name in ["TranslationPosTremie", "TranslationPosPV", "TranslationPosP2",
                 "TranslationPosP1", "TranslationPosMaintenance",
                 "M3_LimitSwitchFwd", "M3_LimitSwitchRev",
                 "M3_SensorWordIncoherent", "M3_SensorsWord"]:
        assert name in prg05, f"Fait M3 {name} absent de PRG_05_Translation.st"
