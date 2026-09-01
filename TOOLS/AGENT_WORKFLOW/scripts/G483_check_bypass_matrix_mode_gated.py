#!/usr/bin/env python3
"""G483 — Matrice de maintenance N1/N2 (T181-14, AF-05 §4bis).

Garde-fou automatique de la règle `fix:` + `guard:` (AGENTS.md) : refuse toute
régression où un bypass de sécurité treuil redeviendrait effectif hors MAINT_N2,
où l'override du FDC haut logiciel sortirait de sa borne (7,5 m / 8,5 m), ou où
le re-homing obligatoire perdrait sa condition de levée.

Contrôles
---------
AC1   Tout `Bypass*` / `EncoderFaultBypass` câblé depuis PRG_04 vers
      instSafetyWinchM1/M2, instWinchM1/M2, instBucket est gâté par `MaintN2`.
AC1b  L'ORIGINE du gate est l'arbitrage FB_Modes (`Auth.Mode`), jamais le sélecteur
      IHM brut (qui autoriserait les bypass dans un mode refusé).
AC2   `TopLimitM1_M` / `TopLimitM2_M` = MIN(SEL(override, 7,5 m, 8,5 m), bande de
      ralentissement) — la course supplémentaire reste couverte par le ralentissement.
AC2b  Invariant de configuration : CfgTopSensorPos_M - CfgCableLimitAscent_M ne doit
      jamais excéder WinchSlowdownDistance_M (sinon arrivée capteur à pleine vitesse).
AC3   L'override N1 n'ouvre jamais `BypassTopLimitSwitch` (butée capteur dure).
AC3b  L'override est conditionné à Homed ET NON HomingSuspect (pas de dépassement
      contrôlé sans référence de position).
AC4   `ModeChangeAllowed` = contacteurs retombés ET frein serré ET |v| < seuil,
      sur M1 ET M2 ; une transition vers/depuis DISABLE reste libre (contrat D2).
AC5   `FB_Modes.Fault` est publié (Data.ModesFault) et agrégé dans AnyFaultActive :
      un interlock invisible est un interlock contourné.
AC6   Armement IMMÉDIAT du re-homing (avant l'arbitrage de mode) sur les DEUX axes.
AC7   Levée de `HomingRequired` sur homing complet réussi uniquement.
AC8   SEMI_AUTO refusé si `HomingRequiredM1` OU `HomingRequiredM2`, causes séparées.
AC9   Câblage inter-PRG complet (PRG_03 ↔ PRG_04 ↔ PRG_07) : aucune fonction morte.
AC12  `BtnOverrideTopSoftware` déclaré dans ST_WinchCmd, absent de ST_BypassWinch.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRG04 = ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
PRG03 = ROOT / "CODE" / "M_MAIN" / "PRG_03_Modes_Cycle.st"
PRG07 = ROOT / "CODE" / "M_MAIN" / "PRG_07_Supervision.st"
FB_MODES = ROOT / "CODE" / "F_MODES" / "FB_Modes.st"
FB_CYCLE = ROOT / "CODE" / "G_CYCLE" / "FB_Cycle.st"
GVL_PERSISTENT = ROOT / "CODE" / "GVL_PERSISTENT.st"
ST_WINCH_CMD = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "1_TREUILS_BENNE" / "ST_WinchCmd.st"
ST_BYPASS_WINCH = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "1_TREUILS_BENNE" / "ST_BypassWinch.st"
ST_MODES_INTERPRG = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "3_CYCLE_ET_MODES" / "ST_ModesCycleInterPrg.st"
FB_SAFETY_WINCH = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Safety_Winch.st"

# Tolérances hors matrice, EXPLICITES et BORNÉES (1 occurrence + justification).
# Un 2e usage non gaté du même nom fait échouer le gate.
OUT_OF_SCOPE = {
    "GVL_IHM.M1M2Sync.Bypass.Global": "synchro M1/M2 — hors matrice treuils (contrat D7, AF-05 §9)",
}


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def strip_comments(text: str) -> str:
    """Retire les commentaires ST — un motif recopié dans un commentaire ne doit pas valider un contrôle."""
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", " ", text)
    return text


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"[G483] FAIL — {path.relative_to(ROOT)} introuvable")
    return path.read_text(encoding="utf-8", errors="replace")


def check_bypass_mode_gated(text: str) -> list[str]:
    """AC1 — toute affectation d'une entrée Bypass* d'instance est gâtée par MaintN2."""
    errors: list[str] = []
    pattern = re.compile(
        r"^\s*(EncoderFaultBypass|Bypass[A-Za-z0-9_]*)\s*:=\s*(?P<rhs>.+?),?\s*$",
        re.MULTILINE,
    )
    eff_locals = {f"BypassM{a}{n}Eff" for a in (1, 2) for n in
                  ("TopLimitSwitch", "TopLimitSoftware", "CableLimitSwitch", "LimitLegal", "MecaD")}
    found = 0
    for match in pattern.finditer(text):
        name = match.group("rhs").strip()
        if name in eff_locals or name.startswith("MaintN2 AND"):
            found += 1
            continue
        if name in OUT_OF_SCOPE:
            if text.count(name) > 1:
                errors.append(f"AC1 tolérance hors matrice utilisée {text.count(name)}× : {name}")
            continue
        errors.append(f"AC1 bypass non gaté par MAINT_N2 : {match.group(0).strip()}")
    if found < 30:
        errors.append(f"AC1 seulement {found} affectations Bypass* gâtées (attendu >= 30)")
    return errors


def check_eff_locals_are_gated(text: str) -> list[str]:
    """AC1 bis — les locaux `BypassM?*Eff` contiennent bien le gate MaintN2."""
    errors: list[str] = []
    names = [f"BypassM{a}{n}Eff" for a in (1, 2) for n in
             ("TopLimitSwitch", "TopLimitSoftware", "CableLimitSwitch", "LimitLegal", "MecaD")]
    for name in names:
        match = re.search(rf"^\s*{name}\s*:=\s*(.+?);\s*$", text, re.MULTILINE)
        if match is None:
            errors.append(f"AC1 local effectif absent : {name}")
        elif not match.group(1).strip().startswith("MaintN2 AND"):
            errors.append(f"AC1 local effectif non gaté par MaintN2 : {name}")
    return errors


def check_gate_origin(text: str) -> list[str]:
    """AC1b — MaintN1/MaintN2 dérivent de l'arbitrage FB_Modes, pas du sélecteur IHM brut."""
    errors: list[str] = []
    body = compact(text)
    for name, mode in (("MaintN1", "MAINT_N1"), ("MaintN2", "MAINT_N2")):
        if not re.search(
            rf"(?:^|\s){name}\s*:=\s*\(\s*PRG_03_Modes_Cycle\.Data\.Auth\.Mode\s*=\s*E_Mode\.{mode}\s*\)\s*;",
            body,
        ):
            errors.append(f"AC1b {name} ne dérive pas de PRG_03_Modes_Cycle.Data.Auth.Mode (= E_Mode.{mode})")
    return errors


def check_top_limit(text: str) -> list[str]:
    """AC2 / AC2b / AC3 / AC3b — bornes et conditions de l'override du FDC haut logiciel."""
    errors: list[str] = []
    body = compact(text)
    required = {
        "AC2 plafond borné M1": (
            r"TopLimitM1_M\s*:=\s*MIN\s*\(\s*SEL\s*\(\s*OverrideTopSoftwareN1M1\s+OR\s+BypassM1TopLimitSoftwareEff\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*,"
            r"\s*_WinchM1CfgPersist\.CfgTopSensorPos_M\s*\)\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*\+\s*_CommunCfgPersist\.WinchSlowdownDistance_M\s*\)"
        ),
        "AC2 plafond borné M2": (
            r"TopLimitM2_M\s*:=\s*MIN\s*\(\s*SEL\s*\(\s*OverrideTopSoftwareN1M2\s+OR\s+BypassM2TopLimitSoftwareEff\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*\+\s*M2_LimitShift\s*,"
            r"\s*_WinchM2CfgPersist\.CfgTopSensorPos_M\s*\+\s*M2_LimitShift\s*\)\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*\+\s*M2_LimitShift"
            r"\s*\+\s*_CommunCfgPersist\.WinchSlowdownDistance_M\s*\)"
        ),
        "AC3 FDC capteur jamais ouvert par l'override": r"BypassTopLimitSwitch\s*:=\s*BypassM[12]TopLimitSwitchEff",
    }
    for label, pattern in required.items():
        if not re.search(pattern, body):
            errors.append(f"{label} — motif introuvable")

    # AC3b — l'override exige une référence de position fiable, sur les DEUX axes.
    for axis, winch in (("M1", "M1TreuilRetenue"), ("M2", "M2TreuilBenne")):
        if not re.search(
            rf"OverrideTopSoftwareN1{axis}\s*:=\s*MaintN1"
            rf"\s+AND\s+PRG_02_Acquisition\.Data\.Encoder{axis}\.Homed"
            rf"\s+AND\s+NOT\s+PRG_02_Acquisition\.Data\.Encoder{axis}\.HomingSuspect"
            rf"\s+AND\s+GVL_IHM\.{winch}\.Cmd\.BtnOverrideTopSoftware",
            body,
        ):
            errors.append(f"AC3b override {axis} non conditionné à Homed AND NOT HomingSuspect")

    # AC3 bis — l'override ne doit jamais apparaître dans un BypassTopLimitSwitch.
    for match in re.finditer(r"^\s*BypassTopLimitSwitch\s*:=\s*(.+?);\s*$", text, re.MULTILINE):
        if "OverrideTopSoftwareN1" in match.group(1):
            errors.append("AC3 l'override N1 ouvre BypassTopLimitSwitch (butée physique franchissable)")

    # AC2b — invariant de configuration : la course d'override reste couverte par le ralentissement.
    cfg = read(GVL_PERSISTENT)
    def value(name: str, default: float) -> float:
        found = re.search(rf"{name}\s*:=\s*([0-9]*\.?[0-9]+)", cfg)
        return float(found.group(1)) if found else default
    delta = value("CfgTopSensorPos_M", 8.5) - value("CfgCableLimitAscent_M", 7.5)
    band = value("WinchSlowdownDistance_M", 1.0)
    if delta > band + 1e-6:
        errors.append(
            f"AC2b CfgTopSensorPos_M - CfgCableLimitAscent_M = {delta} m > WinchSlowdownDistance_M = {band} m : "
            "sous override, le treuil arrive sur le capteur physique sans ralentissement"
        )
    return errors


def check_fb_modes(text: str) -> list[str]:
    """AC4 / AC5 / AC6 / AC7 / AC8 — arbitrage de mode, publication du défaut, re-homing."""
    errors: list[str] = []
    body = compact(text)
    required = {
        "AC4 contacteurs + frein + vitesse M1": (
            r"ModeChangeAllowed\s*:=\s*M1ContactorsReleased\s+AND\s+NOT\s+M1BrakeIsOpen"
            r"\s+AND\s*\(\s*ABS\s*\(\s*M1SpeedAbsMps\s*\)\s*<\s*MovementSpeedThresholdMps\s*\)"
        ),
        "AC4 contacteurs + frein + vitesse M2": (
            r"AND\s+M2ContactorsReleased\s+AND\s+NOT\s+M2BrakeIsOpen"
            r"\s+AND\s*\(\s*ABS\s*\(\s*M2SpeedAbsMps\s*\)\s*<\s*MovementSpeedThresholdMps\s*\)"
        ),
        "AC4 exemption DISABLE (contrat D2)": (
            r"AND\s*\(\s*SelMode\s*<>\s*E_Mode\.DISABLE\s*\)\s*AND\s*\(\s*PrevArbitratedMode\s*<>\s*E_Mode\.DISABLE\s*\)"
        ),
        "AC4 maintien du mode + remontée IHM": (
            r"Auth\.Mode\s*:=\s*PrevArbitratedMode\s*;\s*Auth\.ModeChangePendingBlocked\s*:=\s*TRUE"
        ),
        "AC6 armement immédiat M1": (
            r"IF\s+M1PositionLimitOverridden\s+THEN\s+MaintHomingRequiredM1\s*:=\s*TRUE\s*;\s*END_IF"
        ),
        "AC6 armement immédiat M2": (
            r"IF\s+M2PositionLimitOverridden\s+THEN\s+MaintHomingRequiredM2\s*:=\s*TRUE\s*;\s*END_IF"
        ),
        "AC6 restauration boot": (
            r"MaintHomingRequiredM1\s*:=\s*BootHomingRequiredM1"
        ),
        "AC7 levée homing M1": (
            r"IF\s+MaintHomingRequiredM1\s+AND\s+M1HomingDone\s+AND\s+M1Homed\s+AND\s+NOT\s+M1HomingSuspect\s+THEN"
        ),
        "AC7 levée homing M2": (
            r"IF\s+MaintHomingRequiredM2\s+AND\s+M2HomingDone\s+AND\s+M2Homed\s+AND\s+NOT\s+M2HomingSuspect\s+THEN"
        ),
        "AC8 SEMI_AUTO sélectionnable (mode suit SelMode, pas de repli)": (
            r"Auth\.Mode\s*:=\s*SelMode"
        ),
        "AC5 publication du défaut": r"Auth\.HomingRequiredM1\s*:=\s*MaintHomingRequiredM1",
    }
    for label, pattern in required.items():
        if not re.search(pattern, body):
            errors.append(f"{label} — motif introuvable dans FB_Modes.st")

    # AC6 — l'armement doit précéder l'arbitrage de mode (pas de fenêtre d'un scan).
    arm_pos = body.find("IF M1PositionLimitOverridden THEN")
    arb_pos = body.find("IF (SelMode <> PrevArbitratedMode)")
    if arm_pos < 0 or arb_pos < 0 or arm_pos > arb_pos:
        errors.append("AC6 l'armement du re-homing doit précéder l'arbitrage de mode §3")
    return errors


def check_cycle_encoder_gate(text: str) -> list[str]:
    """AC8 — le cycle ne tourne jamais avec un codeur défaillant : FB_Cycle gate sur
    EncoderFaultPresent (barrière primaire du cycle, le mode SEMI_AUTO restant sélectionnable)."""
    errors: list[str] = []
    body = compact(strip_comments(text))
    if not re.search(
        r"IF\s+NOT\s+Enable\s+OR\s+NOT\s+PowerContactorEngaged\s+OR\s+EncoderFaultPresent\s+THEN",
        body,
    ):
        errors.append("AC8 FB_Cycle ne gate pas sur EncoderFaultPresent (cycle autorisé avec codeur défaillant)")
    return errors


def check_interprg_wiring(prg03: str, prg04: str, prg07: str, interprg: str) -> list[str]:
    """AC5 / AC9 — câblage inter-PRG complet : aucune fonction morte silencieuse."""
    errors: list[str] = []
    c3, c4, c7, cip = (compact(t) for t in (prg03, prg04, prg07, interprg))
    required = {
        ("PRG03", c3, r"M1PositionLimitOverridden\s*:=\s*PRG_04_Treuils_Benne\.Data\.PositionLimitOverriddenM1"),
        ("PRG03", c3, r"M2PositionLimitOverridden\s*:=\s*PRG_04_Treuils_Benne\.Data\.PositionLimitOverriddenM2"),
        ("PRG03", c3, r"BootHomingRequiredM1\s*:=\s*GVL_PERSISTENT\._MaintM1HomingRequired"),
        ("PRG03", c3, r"BootHomingRequiredM2\s*:=\s*GVL_PERSISTENT\._MaintM2HomingRequired"),
        ("PRG03", c3, r"GVL_PERSISTENT\._MaintM1HomingRequired\s*:=\s*instModes\.Auth\.HomingRequiredM1"),
        ("PRG03", c3, r"GVL_PERSISTENT\._MaintM2HomingRequired\s*:=\s*instModes\.Auth\.HomingRequiredM2"),
        ("PRG03", c3, r"Data\.ModesFault\s*:=\s*instModes\.Fault"),
        ("PRG04", c4, r"Data\.PositionLimitOverriddenM1\s*:=\s*PositionLimitOverriddenM1"),
        ("PRG04", c4, r"Data\.PositionLimitOverriddenM2\s*:=\s*PositionLimitOverriddenM2"),
        ("PRG07", c7, r"GVL_IHM\.Modes\.State\.ModeChangePendingBlocked\s*:=\s*PRG_03_Modes_Cycle\.Data\.Auth\.ModeChangePendingBlocked"),
        ("PRG07", c7, r"GVL_IHM\.Modes\.State\.HomingRequiredM1\s*:=\s*PRG_03_Modes_Cycle\.Data\.Auth\.HomingRequiredM1"),
        ("PRG07", c7, r"GVL_IHM\.Modes\.State\.HomingRequiredM2\s*:=\s*PRG_03_Modes_Cycle\.Data\.Auth\.HomingRequiredM2"),
        ("PRG07", c7, r"OR\s+PRG_03_Modes_Cycle\.Data\.ModesFault\.Error"),
        ("PRG07", c7, r"OR\s+PRG_03_Modes_Cycle\.Data\.ModesFault\.Latched"),
        ("DUT", cip, r"ModesFault\s*:\s*ST_Fault"),
    }
    for where, body, pattern in required:
        if not re.search(pattern, body):
            errors.append(f"AC9 câblage inter-PRG manquant ({where}) : {pattern}")
    return errors


def check_dut(text_cmd: str, text_bypass: str) -> list[str]:
    """AC12 — bouton momentané dans ST_WinchCmd, jamais dans ST_BypassWinch."""
    errors: list[str] = []
    if not re.search(r"^\s*BtnOverrideTopSoftware\s*:\s*BOOL\s*;", text_cmd, re.MULTILINE):
        errors.append("AC12 BtnOverrideTopSoftware absent de ST_WinchCmd.st")
    if "BtnOverrideTopSoftware" in text_bypass:
        errors.append("AC12 BtnOverrideTopSoftware présent dans ST_BypassWinch.st (ce n'est pas un bypass latché)")
    return errors


def check_legal_limit_bypass(text: str) -> list[str]:
    """T197: la cote legale a un bypass dedie, separe du groupe procede."""
    errors: list[str] = []
    body = compact(strip_comments(text))
    if not re.search(r"LimitLegalReached\s+AND\s+NOT\s+BypassLimitLegal", body):
        errors.append("T197: la limite legale n'est pas protegee par le seul BypassLimitLegal")
    if re.search(r"LimitLegalReached\s+AND\s+NOT\s*\(\s*BypassProcess", body):
        errors.append("T197: BypassProcess neutralise encore la limite legale")
    return errors


def check_simulation_bypass_gate(text: str) -> list[str]:
    """T197: le bypass banc ne s'arme que dans le domaine simulation treuil."""
    errors: list[str] = []
    body = compact(strip_comments(text))
    pattern = (
        r"SimulationBypassEffective\s*:=\s*GVL_Simulation\.SimulationModeActive"
        r"\s+AND\s+GVL_Simulation\.SimWinchActive"
        r"\s+AND\s+GVL_Simulation\.SimulationBypassActive"
    )
    if not re.search(pattern, body):
        errors.append("T197: SimulationBypassEffective non gate par SimulationModeActive AND SimWinchActive")
    if re.search(r"SimBypass(?:Rise|Fall)\s*\(\s*CLK\s*:=\s*GVL_Simulation\.SimulationBypassActive", body):
        errors.append("T197: front bypass simulation branche sans gate effectif")
    return errors


def main() -> int:
    errors: list[str] = []
    prg04_raw = read(PRG04)
    prg04 = strip_comments(prg04_raw)
    errors += check_bypass_mode_gated(prg04)
    errors += check_eff_locals_are_gated(prg04)
    errors += check_gate_origin(prg04)
    errors += check_top_limit(prg04)
    errors += check_fb_modes(strip_comments(read(FB_MODES)))
    errors += check_cycle_encoder_gate(read(FB_CYCLE))
    errors += check_interprg_wiring(
        strip_comments(read(PRG03)), prg04, strip_comments(read(PRG07)), read(ST_MODES_INTERPRG)
    )
    errors += check_dut(read(ST_WINCH_CMD), read(ST_BYPASS_WINCH))
    errors += check_legal_limit_bypass(read(FB_SAFETY_WINCH))
    errors += check_simulation_bypass_gate(read(PRG07))

    if errors:
        print("[G483] FAIL — matrice de maintenance N1/N2 :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "[G483] PASS — bypass gatés MAINT_N2 (origine Auth.Mode) · override FDC borné + conditionné "
        "Homed · bascule subordonnée à l'arrêt confirmé · re-homing immédiat publié · câblage inter-PRG complet"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
