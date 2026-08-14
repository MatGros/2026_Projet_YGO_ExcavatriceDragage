"""Garde-fou M3 : ordre du mot capteurs et modèle de simulation.

REX 2026-08-14 : FB_SimBench câblait bit0 vers Trémie et bit4 vers Maintenance,
à l'inverse du contrat FB_Translation_PositionDecoder. Un override pourtant valide
créait un mot incohérent et un faux SafeStop.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SIM_BENCH = ROOT / "CODE" / "SIMULATION" / "FB_SimBench.st"
SIM_TRANSLATION = ROOT / "CODE" / "SIMULATION" / "FB_Sim_Translation.st"


def test_m3_sensor_override_uses_decoder_bit_order() -> None:
    source = SIM_BENCH.read_text(encoding="utf-8")
    expected = (
        "Translation.M3_PosTremie_DI      := SimM3SensorsWord.4;",
        "Translation.M3_PosPV_DI          := SimM3SensorsWord.3;",
        "Translation.M3_PosPVP2_DI        := SimM3SensorsWord.2;",
        "Translation.M3_PosP1_DI          := SimM3SensorsWord.1;",
        "Translation.M3_PosMaintenance_DI := SimM3SensorsWord.0;",
    )
    for assignment in expected:
        assert assignment in source


def test_m3_dynamic_model_preserves_only_thermometer_sequence() -> None:
    source = SIM_TRANSLATION.read_text(encoding="utf-8")
    # Les cinq paliers du modèle doivent décrire les six mots valides et ne plus
    # dépendre d'une cible qui publiait directement une butée temporaire.
    assert "TargetNum" not in source
    assert "PositionProgress" in source
    assert "CST_PositionAtTremie" in source
    assert "CST_PositionAtPV" in source
    assert "CST_PositionAtP2" in source
    assert "CST_PositionAtP1" in source
    assert "CST_PositionAtMaintenance" in source
    assert "PosTremie := TRUE;\n    PosPV := TRUE;\n    PosP2 := TRUE;\n    PosP1 := TRUE;\n    PosMaintenance := TRUE;" in source
    assert "PosPV := TRUE;\n    PosP2 := TRUE;\n    PosP1 := TRUE;\n    PosMaintenance := TRUE;" in source
    assert "PosP2 := TRUE;\n    PosP1 := TRUE;\n    PosMaintenance := TRUE;" in source
    assert "PosP1 := TRUE;\n    PosMaintenance := TRUE;" in source
    assert "PosMaintenance := TRUE;" in source
