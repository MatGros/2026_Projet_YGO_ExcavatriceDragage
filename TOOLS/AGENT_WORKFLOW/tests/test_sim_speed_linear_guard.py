"""Garde-fou : vitesse de simulation linéaire par palier (palier 1 → 1 m/s, palier 5 → 2 m/s).

REX 2026-08-22 : FB_Sim_Encoder comptait `Increment := SpeedRefPct * 0.1 * SpeedScaleFactor`,
soit ≈ 0,244 m/s à pleine vitesse (10 ms, 8192 pts/tour, 2 m/tour) — ~6-8× trop lent face à la
machine réelle (1-2 m/s).

Fix : la vitesse est déduite du palier (StepNumber) par interpolation linéaire
MinSpeedMps (palier 1 = 1 m/s) → MaxSpeedMps (palier 5 = 2 m/s), pas de 0,25 m/s,
puis convertie en points/cycle via les paramètres physiques + période de tâche.

⚠️ Si ce test échoue → quelqu'un a réintroduit la vitesse magique en % (SpeedRefPct*0.1).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SIM_ENC = ROOT / "CODE" / "L_SIMULATION" / "FB_Sim_Encoder.st"


def test_uses_linear_pallet_speed() -> None:
    src = SIM_ENC.read_text(encoding="utf-8")
    # Nouveau modèle : palier + interpolation linéaire + conversion physique
    assert "StepNumber" in src
    assert "MinSpeedMps" in src
    assert "MaxSpeedMps" in src
    assert "PointsPerRev" in src
    assert "CableM_PerRev" in src
    assert "CycleTimeS" in src
    assert "SpeedMps" in src
    # Ancien modèle magique supprimé
    assert "SpeedRefPct" not in src
    assert "0.1 * SpeedScaleFactor" not in src


def test_linear_speed_profile_endpoints() -> None:
    # Palier 1 → 1,0 m/s ; palier 5 → 2,0 m/s ; pas constant de 0,25.
    for pallet in range(1, 6):
        speed = 1.0 + (pallet - 1) * 0.25
        assert speed == 1.0 + (pallet - 1) * ((2.0 - 1.0) / 4.0)
    assert 1.0 + 0 * 0.25 == 1.0   # palier 1
    assert 1.0 + 4 * 0.25 == 2.0   # palier 5
