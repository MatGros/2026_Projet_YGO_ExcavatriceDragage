#!/usr/bin/env python3
"""G483 — Matrice de maintenance N1/N2 (T181-14, AF-05 §4bis).

Garde-fou automatique de la règle `fix:` + `guard:` (AGENTS.md) : refuse toute
régression où un bypass de sécurité treuil redeviendrait effectif hors MAINT_N2,
où l'override du FDC haut logiciel sortirait de sa borne (7,5 m / 8,5 m), ou où
le re-homing obligatoire perdrait sa condition de levée.

Contrôles
---------
AC1  Tout `Bypass*` / `EncoderFaultBypass` câblé depuis PRG_04 vers
     instSafetyWinchM1/M2, instWinchM1/M2, instBucket est gâté par `MaintN2`
     (directement ou via un local `BypassM?*Eff`).
AC2  `TopLimitM1_M` / `TopLimitM2_M` = SEL(override, 7,5 m, 8,5 m) — les deux
     bornes sont la config nominale et la position du capteur de homing haut.
AC3  L'override N1 n'ouvre jamais `BypassTopLimitSwitch` (butée capteur dure).
AC4  `BasculeModeAutorisee` = contacteurs retombés ET frein serré ET |v| < seuil,
     sur M1 ET M2 ; une transition vers/depuis DISABLE reste libre (contrat D2).
AC6  Transfert `MaintOverrideUsedM?` -> `HomingRequiredM?` à la sortie de N1/N2.
AC7  Levée de `HomingRequired` sur homing complet réussi uniquement.
AC8  SEMI_AUTO refusé si `HomingRequiredM1` OU `HomingRequiredM2`.
AC12 `BtnOverrideTopSoftware` déclaré dans ST_WinchCmd, absent de ST_BypassWinch.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PRG04 = ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
FB_MODES = ROOT / "CODE" / "F_MODES" / "FB_Modes.st"
ST_WINCH_CMD = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "1_TREUILS_BENNE" / "ST_WinchCmd.st"
ST_BYPASS_WINCH = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "1_TREUILS_BENNE" / "ST_BypassWinch.st"


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"[G483] FAIL — {path.relative_to(ROOT)} introuvable")
    return path.read_text(encoding="utf-8", errors="replace")


def check_bypass_mode_gated(text: str) -> list[str]:
    """AC1 — toute affectation d'une entrée Bypass* d'instance est gâtée par MaintN2."""
    errors: list[str] = []
    # Lignes de la forme `  BypassXxx := ...,` ou `  EncoderFaultBypass := ...,`
    pattern = re.compile(
        r"^\s*(EncoderFaultBypass|Bypass[A-Za-z0-9_]*)\s*:=\s*(?P<rhs>.+?),?\s*$",
        re.MULTILINE,
    )
    eff_locals = {
        "BypassM1TopLimitSwitchEff",
        "BypassM1TopLimitSoftwareEff",
        "BypassM1CableLimitSwitchEff",
        "BypassM1LimitLegalEff",
        "BypassM1MecaDEff",
        "BypassM2TopLimitSwitchEff",
        "BypassM2TopLimitSoftwareEff",
        "BypassM2CableLimitSwitchEff",
        "BypassM2LimitLegalEff",
        "BypassM2MecaDEff",
    }
    # Hors périmètre volontaire (contrat D7) : la synchro M1/M2 n'est pas un bypass de sécurité
    # treuil — la matrice AF-05 §4bis couvre les treuils M1/M2 + benne. Extension à part
    # (AF-05 §9). Liste explicite : tout ajout ici doit être justifié et signalé.
    out_of_scope = {
        "GVL_IHM.M1M2Sync.Bypass.Global": "synchro M1/M2 — hors matrice treuils (contrat D7)",
    }
    found = 0
    for match in pattern.finditer(text):
        name = match.group("rhs").strip()
        if name in eff_locals or name.startswith("MaintN2 AND"):
            found += 1
            continue
        if name in out_of_scope:
            continue
        errors.append(f"AC1 bypass non gaté par MAINT_N2 : {match.group(0).strip()}")
    if found < 30:
        errors.append(f"AC1 seulement {found} affectations Bypass* gâtées (attendu >= 30)")
    return errors


def check_eff_locals_are_gated(text: str) -> list[str]:
    """AC1 bis — les locaux `BypassM?*Eff` contiennent bien le gate MaintN2."""
    errors: list[str] = []
    for name in (
        "BypassM1TopLimitSwitchEff",
        "BypassM1TopLimitSoftwareEff",
        "BypassM1CableLimitSwitchEff",
        "BypassM1LimitLegalEff",
        "BypassM1MecaDEff",
        "BypassM2TopLimitSwitchEff",
        "BypassM2TopLimitSoftwareEff",
        "BypassM2CableLimitSwitchEff",
        "BypassM2LimitLegalEff",
        "BypassM2MecaDEff",
    ):
        match = re.search(rf"^\s*{name}\s*:=\s*(.+?);\s*$", text, re.MULTILINE)
        if match is None:
            errors.append(f"AC1 local effectif absent : {name}")
        elif not match.group(1).strip().startswith("MaintN2 AND"):
            errors.append(f"AC1 local effectif non gaté par MaintN2 : {name}")
    return errors


def check_top_limit_sel(text: str) -> list[str]:
    """AC2 / AC3 — bornes de l'override du FDC haut logiciel."""
    errors: list[str] = []
    body = compact(text)
    required = {
        "AC2 SEL M1": (
            r"TopLimitM1_M\s*:=\s*SEL\s*\(\s*OverrideTopSoftwareN1M1\s+OR\s+BypassM1TopLimitSoftwareEff\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*,\s*_WinchM1CfgPersist\.CfgTopSensorPos_M\s*\)"
        ),
        "AC2 SEL M2": (
            r"TopLimitM2_M\s*:=\s*SEL\s*\(\s*OverrideTopSoftwareN1M2\s+OR\s+BypassM2TopLimitSoftwareEff\s*,"
            r"\s*_CommunCfgPersist\.CfgCableLimitAscent_M\s*\+\s*M2_LimitShift\s*,"
            r"\s*_WinchM2CfgPersist\.CfgTopSensorPos_M\s*\+\s*M2_LimitShift\s*\)"
        ),
        "AC2 override M1 momentané N1": r"OverrideTopSoftwareN1M1\s*:=\s*MaintN1\s+AND\s+GVL_IHM\.M1TreuilRetenue\.Cmd\.BtnOverrideTopSoftware",
        "AC2 override M2 momentané N1": r"OverrideTopSoftwareN1M2\s*:=\s*MaintN1\s+AND\s+GVL_IHM\.M2TreuilBenne\.Cmd\.BtnOverrideTopSoftware",
        "AC3 FDC capteur jamais ouvert par l'override": r"BypassTopLimitSwitch\s*:=\s*BypassM[12]TopLimitSwitchEff",
    }
    for label, pattern in required.items():
        if not re.search(pattern, body):
            errors.append(f"{label} — motif introuvable")

    # AC3 bis — l'override ne doit jamais apparaître dans un BypassTopLimitSwitch.
    for match in re.finditer(r"^\s*BypassTopLimitSwitch\s*:=\s*(.+?);\s*$", text, re.MULTILINE):
        if "OverrideTopSoftwareN1" in match.group(1):
            errors.append("AC3 l'override N1 ouvre BypassTopLimitSwitch (butée physique franchissable)")
    return errors


def check_fb_modes(text: str) -> list[str]:
    """AC4 / AC6 / AC7 / AC8 — arbitrage de mode et re-homing."""
    errors: list[str] = []
    body = compact(text)
    required = {
        "AC4 contacteurs + frein + vitesse M1": (
            r"BasculeModeAutorisee\s*:=\s*M1ContactorsReleased\s+AND\s+NOT\s+M1BrakeIsOpen"
            r"\s+AND\s*\(\s*ABS\s*\(\s*M1SpeedAbsMps\s*\)\s*<\s*MovementSpeedThresholdMps\s*\)"
        ),
        "AC4 contacteurs + frein + vitesse M2": (
            r"AND\s+M2ContactorsReleased\s+AND\s+NOT\s+M2BrakeIsOpen"
            r"\s+AND\s*\(\s*ABS\s*\(\s*M2SpeedAbsMps\s*\)\s*<\s*MovementSpeedThresholdMps\s*\)"
        ),
        "AC4 exemption DISABLE (contrat D2)": (
            r"AND\s*\(\s*SelMode\s*<>\s*E_Mode\.DISABLE\s*\)\s*AND\s*\(\s*PrevArbitratedMode\s*<>\s*E_Mode\.DISABLE\s*\)"
        ),
        "AC4 maintien du mode + remontée IHM": r"Auth\.Mode\s*:=\s*PrevArbitratedMode\s*;\s*Auth\.ModeChangePendingBlocked\s*:=\s*TRUE",
        "AC6 transfert en sortie de maintenance": (
            r"MaintHomingRequiredM1\s*:=\s*MaintHomingRequiredM1\s+OR\s+MaintOverrideUsedM1"
        ),
        "AC7 levée homing M1": (
            r"IF\s+MaintHomingRequiredM1\s+AND\s+M1HomingDone\s+AND\s+M1Homed\s+AND\s+NOT\s+M1HomingSuspect\s+THEN"
        ),
        "AC7 levée homing M2": (
            r"IF\s+MaintHomingRequiredM2\s+AND\s+M2HomingDone\s+AND\s+M2Homed\s+AND\s+NOT\s+M2HomingSuspect\s+THEN"
        ),
        "AC8 refus SEMI_AUTO si re-homing requis": (
            r"IF\s*\(\s*SelMode\s*=\s*E_Mode\.SEMI_AUTO\s*\)\s*AND\s*\(\s*EncoderFaultPresent"
            r"\s+OR\s+MaintHomingRequiredM1\s+OR\s+MaintHomingRequiredM2\s*\)"
        ),
    }
    for label, pattern in required.items():
        if not re.search(pattern, body):
            errors.append(f"{label} — motif introuvable dans FB_Modes.st")
    return errors


def check_dut(text_cmd: str, text_bypass: str) -> list[str]:
    """AC12 — bouton momentané dans ST_WinchCmd, jamais dans ST_BypassWinch."""
    errors: list[str] = []
    if not re.search(r"^\s*BtnOverrideTopSoftware\s*:\s*BOOL\s*;", text_cmd, re.MULTILINE):
        errors.append("AC12 BtnOverrideTopSoftware absent de ST_WinchCmd.st")
    if "BtnOverrideTopSoftware" in text_bypass:
        errors.append("AC12 BtnOverrideTopSoftware présent dans ST_BypassWinch.st (ce n'est pas un bypass latché)")
    return errors


def main() -> int:
    errors: list[str] = []
    prg04 = read(PRG04)
    errors += check_bypass_mode_gated(prg04)
    errors += check_eff_locals_are_gated(prg04)
    errors += check_top_limit_sel(prg04)
    errors += check_fb_modes(read(FB_MODES))
    errors += check_dut(read(ST_WINCH_CMD), read(ST_BYPASS_WINCH))

    if errors:
        print("[G483] FAIL — matrice de maintenance N1/N2 :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "[G483] PASS — bypass gatés MAINT_N2 · override FDC borné 7,5/8,5 m · "
        "bascule subordonnée à l'arrêt confirmé · re-homing obligatoire"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
