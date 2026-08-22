"""Garde-fou simulation : la simu ne doit plus auto-bypasser les limites réelles de montée.

REX 2026-08-22 (fiche TROUBLESHOOTING_CableLimitAscent_M1_20260822) :
PRG_07 §2d forçait `Commun.Bypass.TopLimitSwitch/TopLimitSoftware/LimitLegal := TRUE`
au front montant de `SimulationBypassActive` (défaut TRUE au boot). La butée logicielle haute
était donc levée dès le démarrage : AscentPermit restait TRUE et le treuil M1 ne s'arrêtait
pas à 7,5 m.

Fix : ces 3 limites réelles ne sont plus bypassées par la simulation — seule la protection
de montée/descente reste active au banc. Seuls les bypass Meca (M1/M2.Safety/Process) restent
armés (travail sans faux blocage Meca en banc).

⚠️ Si ce test échoue → quelqu'un a réintroduit l'auto-bypass des limites dans la simu.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PRG07 = ROOT / "CODE" / "M_MAIN" / "PRG_07_Supervision.st"
SAFETY = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Safety_Winch.st"

FORBIDDEN_IN_RISE = (
    "Commun.Bypass.TopLimitSwitch",
    "Commun.Bypass.TopLimitSoftware",
    "Commun.Bypass.LimitLegal",
)
KEPT_IN_RISE = (
    "M1TreuilRetenue.Bypass.Safety",
    "M1TreuilRetenue.Bypass.Process",
    "M2TreuilBenne.Bypass.Safety",
    "M2TreuilBenne.Bypass.Process",
)


def _sim_rise_block(source: str) -> str:
    start = source.index("IF SimBypassRise.Q THEN")
    end = source.index("END_IF;", start)
    return source[start:end]


def test_sim_rise_does_not_arm_top_or_legal_limits() -> None:
    source = PRG07.read_text(encoding="utf-8")
    block = _sim_rise_block(source)
    for name in FORBIDDEN_IN_RISE:
        assert name not in block, f"La simu ne doit pas armer {name} (REX 2026-08-22)"


def test_sim_rise_still_keeps_meca_bypasses() -> None:
    source = PRG07.read_text(encoding="utf-8")
    block = _sim_rise_block(source)
    for name in KEPT_IN_RISE:
        assert name in block, f"Le bypass Meca {name} ne doit pas être retiré"


def test_safety_still_blocks_on_software_top_limit() -> None:
    """La butée logicielle (position >= limite) doit toujours couper AscentPermit,
    sauf bypass TopLimitSoftware explicite."""
    source = SAFETY.read_text(encoding="utf-8")
    assert "CablePosM >= TopLimitM" in source
    assert "NOT BypassTopLimitSoftware" in source
