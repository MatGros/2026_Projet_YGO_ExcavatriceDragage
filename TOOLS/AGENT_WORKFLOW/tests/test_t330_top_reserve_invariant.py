#!/usr/bin/env python3
"""Tests T330 — invariant haut : oracles numeriques du bloc TC-P10-056-092 + structure ST.

Ces tests couvrent DEUX choses distinctes :
  1. les ORACLES NUMERIQUES du plan C3 v1.3 (formules R0/R1/R2/R3, cas Q21 bis, Sterbenz) —
     ils figent la SPECIFICATION telle qu'arbitree par l'humain et CC01 ;
  2. des assertions STRUCTURELLES sur l'implementation ST reelle (region balisee, ordre
     R0-avant-Delta, absence de clamp muet, absence de nom inexistant).

⚠️ Perimetre : ces tests verifient la specification et la structure, PAS l'execution du ST
   (aucun runtime CODESYS ici). La recette machine reste P5 du plan.
"""
from __future__ import annotations

import re
import struct
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]  # tests/ -> AGENT_WORKFLOW/ -> TOOLS/ -> racine
PRG07 = ROOT / "CODE" / "M_MAIN" / "PRG_07_Supervision.st"
# T341 : le corps de la normalisation T330 a ete extrait de PRG_07_Supervision.st vers ce FB
# dedie (CODE_QUALITY_STANDARDS §10.2). Le bloc de regles balise est desormais DANS LE FB ;
# PRG_07 ne porte plus que le cablage du signal de homing, au site d'appel.
FB_NORMALIZER = ROOT / "CODE" / "J_SUPERVISION" / "FB_CfgT330Normalizer.st"
BANNER = ROOT / "CODE" / "J_SUPERVISION" / "FB_Hmi_BannerFormatter.st"

FDC_MIN, FDC_MAX = 0.0, 9.0
TOP_MIN, TOP_MAX = 1.0, 10.0
RESERVE_MIN = 1.0
SLOWDOWN_MIN = 0.5


# ── Specification : les regles telles qu'arbitrees (Q1/Q2/Q21/Q21bis/Q17) ────────────────
def r0(fdc: float, top: float) -> tuple[float, float]:
    """R0 — clamp ABSOLU inconditionnel, chaque scan, FDC et TOP SEPAREMENT (Q21 bis)."""
    return min(max(fdc, FDC_MIN), FDC_MAX), min(max(top, TOP_MIN), TOP_MAX)


def normalise(fdc: float, top: float, slow: float, top_changed: bool,
              fdc_changed: bool) -> tuple[float, float, float]:
    """R0 puis (R3, R1/R2) — ORDRE IMPOSE par Q21 bis."""
    fdc, top = r0(fdc, top)
    if slow < SLOWDOWN_MIN:
        slow = SLOWDOWN_MIN
    if top - fdc < RESERVE_MIN:
        if top_changed and not fdc_changed:
            top = fdc + RESERVE_MIN            # R2 : le TOP a ete saisi
        else:
            fdc = top - RESERVE_MIN            # R1 / Q17 : preserver le TOP
    return round(fdc, 6), round(top, 6), round(slow, 6)


def f32(x: float) -> float:
    return struct.unpack("f", struct.pack("f", x))[0]


# ── A · Normalisation (TC-P10-056 .. TC-P10-062) ─────────────────────────────────────────
@pytest.mark.parametrize(
    "fdc, top, slow, top_ch, fdc_ch, want",
    [
        (8.70, 8.50, 0.50, False, True, (7.50, 8.50, 0.50)),   # TC-P10-056 R1
        (7.50, 7.00, 0.50, True, False, (7.50, 8.50, 0.50)),   # TC-P10-057 R2
        (7.60, 8.50, 0.50, False, True, (7.50, 8.50, 0.50)),   # TC-P10-058 R1 (Delta=0,90)
        (7.50, 8.50, 0.20, False, False, (7.50, 8.50, 0.50)),  # TC-P10-059 R3
        (7.50, 10.00, 0.50, True, False, (7.50, 10.00, 0.50)),  # TC-P10-060 valide : rien
        (9.50, 8.00, 0.50, False, True, (7.00, 8.00, 0.50)),   # TC-P10-061 Q17 : les 2 changent
    ],
)
def test_normalisation_oracles(fdc, top, slow, top_ch, fdc_ch, want):
    assert normalise(fdc, top, slow, top_ch, fdc_ch) == want


def test_q17_preserve_le_top():
    """Q17 : quand les DEUX champs changent, le TOP est PRESERVE et le FDC corrige."""
    fdc, top, _ = normalise(9.50, 8.00, 0.50, top_changed=True, fdc_changed=True)
    assert top == 8.00 and fdc == 7.00


# ── B · Idempotence / non-rebond (Q24, Q27) ──────────────────────────────────────────────
def test_non_rebond_2_scans():
    """Q24 : apres une correction, le 2e scan ne corrige PLUS (Delta = 1,00 exactement)."""
    fdc, top, slow = normalise(8.70, 8.50, 0.50, False, True)
    fdc2, top2, slow2 = normalise(fdc, top, slow, False, False)
    assert (fdc2, top2, slow2) == (fdc, top, slow)
    assert top2 - fdc2 == RESERVE_MIN


def test_point_median_reserve_exactement_1_00():
    """Reserve EXACTEMENT 1,00 m : aucune correction, et le flottant est EXACT (Sterbenz)."""
    assert normalise(7.50, 8.50, 0.50, False, False) == (7.50, 8.50, 0.50)


@pytest.mark.parametrize("top, fdc", [(8.49, 7.49), (8.50, 7.50), (10.0, 9.0), (7.0, 6.0)])
def test_difference_exacte_sans_eps(top, fdc):
    """Q27 : AUCUN eps. La soustraction de deux valeurs du domaine est EXACTE en simple precision."""
    assert f32(f32(top) - f32(fdc)) == 1.0


def test_franchissement_seul_autour_du_seuil():
    """Balayage 7,4999 / 7,5000 / 7,5001 : seul le cas < 1,00 m est corrige."""
    assert normalise(7.4999, 8.50, 0.50, False, True)[0] < 7.50   # Delta = 1,0001 -> rien
    assert normalise(7.4999, 8.50, 0.50, False, True)[0] == 7.4999
    assert normalise(7.5001, 8.50, 0.50, False, True)[0] == 7.50   # Delta < 1 -> corrige
    assert normalise(7.5000, 8.50, 0.50, False, True)[0] == 7.5000  # exactement 1,00 -> rien


# ── E · Q21 bis — LE cas probatoire : les DEUX valeurs hors bornes, Delta >= 1 ───────────
def test_q21bis_fdc_9_50_top_12_00():
    """Q21 bis : Delta = 2,50 >= 1 donc AUCUNE regle Delta ; SEULE R0 agit."""
    fdc, top, slow = normalise(9.50, 12.00, 0.50, False, False)
    assert (fdc, top) == (9.00, 10.00)
    assert top - fdc == RESERVE_MIN          # coherent APRES clamp


@pytest.mark.parametrize("fdc, top, want", [
    (-1.00, 8.50, (0.00, 8.50)),
    (7.50, 0.50, (7.50, 1.00)),
    (-150.0, 150.0, (0.00, 10.00)),
    (0.00, 8.50, (0.00, 8.50)),
])
def test_r0_bornes_absolues(fdc, top, want):
    """R0 : clamp inconditionnel, FDC et TOP SEPAREMENT."""
    assert r0(fdc, top) == want


def test_r2_ne_sort_jamais_de_la_borne_top():
    """Avec R0 EN AMONT, R2 ne peut structurellement pas depasser TOP_MAX (preuve C1)."""
    for fdc in [0.0, 5.0, 9.0]:
        _, top, _ = normalise(fdc, 1.0, 0.5, True, False)
        assert TOP_MIN <= top <= TOP_MAX
    # FDC = 9,00 => R2 donne exactement TOP = 10,00 (a la borne)
    assert normalise(9.00, 1.00, 0.50, True, False)[1] == 10.00


# ── Structure de l'implementation ST ────────────────────────────────────────────────────
def _prg07() -> str:
    return PRG07.read_text(encoding="utf-8")


def _fb() -> str:
    return FB_NORMALIZER.read_text(encoding="utf-8")


def _region(text: str) -> str:
    start = text.find('{region "\U0001f527 T330 NORMALISATION"}')
    assert start >= 0, "region balisee T330 absente du fichier controle"
    end = text.find("{endregion}", start)
    assert end > start
    return text[start:end]


def _region_fb() -> str:
    """Corps de regles T330 : balise dans FB_CfgT330Normalizer depuis T341."""
    return _region(_fb())


def _region_prg07() -> str:
    """Site d'appel T330 : cablage du signal de homing, dans PRG_07."""
    return _region(_prg07())


def test_region_balisee_presente():
    assert "T330 NORMALISATION" in _prg07(), "region T330 absente du site d'appel PRG_07"
    assert "T330 NORMALISATION" in _fb(), "region T330 absente du corps du FB"


def test_regles_portees_par_le_fb_et_non_par_prg07():
    """§10.2 : aucune logique metier inline dans PRG_07 — le corps des regles vit dans le FB."""
    assert "CST_T330ReserveMinMargin_M" not in _prg07(), "regle T330 restee inline dans PRG_07"
    assert "CST_T330ReserveMinMargin_M" in _region_fb()


def test_r0_est_en_amont_de_la_regle_delta():
    """Q21 bis : le clamp absolu precede la regle Delta dans le source."""
    body = _region_fb()
    assert 0 <= body.find("CST_T330FdcMin_M") < body.find("CST_T330ReserveMinMargin_M")


def test_aucun_clamp_muet():
    """G504-6 : toute ecriture de correction porte un message dans les 4 lignes suivantes."""
    lines = _region_fb().splitlines()
    for i, line in enumerate(lines):
        if re.search(r"(CfgCableLimitAscent_M|CfgTopSensorPos_M|WinchSlowdownDistanceTop_M)\s*:=", line):
            assert "Corrected := TRUE" in "\n".join(lines[i:i + 4]), line.strip()


def test_gating_homing_sur_le_cycle_complet():
    """C2a : le cycle COMPLET (MachineHoming.Active) ET la transaction preset doivent etre combines."""
    body = _region_prg07()
    assert "MachineHoming.Active" in body
    assert "HomingLifecycle.Busy" in body


def test_aucune_memoire_d_intention_dans_le_homing():
    """Decision 2c : 'rien a memoriser' — aucun latch d'intention ne doit exister."""
    assert "T330R2Pending" not in _prg07()
    assert "T330R2Pending" not in _fb()


def test_aucun_nom_inexistant_dans_le_code():
    """Cadrage section 1 : ces libelles n'existent pas dans le projet."""
    text = _prg07() + _fb()
    for name in ("PositionHomingTop_M", "PositionFdcLogicielHaut_M"):
        assert name not in text


def test_variable_morte_prev_slowdown_retiree():
    """T341 : T330PrevSlowdownTopM etait ecrite et jamais lue — elle doit avoir disparu."""
    text = _prg07() + _fb()
    assert "T330PrevSlowdownTopM" not in text


def test_message_ihm_conforme():
    """Le message T330 : prefixe [CFG] discriminant, <= 70 car. (G408), non alarmant."""
    text = BANNER.read_text(encoding="utf-8")
    assert "CfgCorrectedT330" in text
    match = re.search(r"OperatorActionCandidate\s*:=\s*'(\[CFG\][^']*)';", text)
    assert match, "libelle [CFG] absent du formateur"
    label = match.group(1)
    assert label.startswith("[CFG]")
    assert len(label) <= 70, f"{len(label)} caracteres > 70 (G408)"
    assert not re.search(r"ALARME|DEFAUT|URGENCE", label.upper())
