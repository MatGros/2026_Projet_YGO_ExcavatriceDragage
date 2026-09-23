#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere la liste a plat des chemins de variables de GVL_Troubleshooting a partir du CODE.

Remplace generate_variable_list.py (qui dependait d'un export Symbol Configuration, souvent
perime). Ce script parse directement les sources ST dans CODE/ :
  - GVL_Troubleshooting.st (champs top-level + types)
  - les structs ST_Chain*.st / ST_*Checklist.st / ST_HardwareImage.st (definitions STRUCT)

Lancement : python generate_variable_list_from_code.py [--output troubleshooting_variables.txt]
A relancer quand la structure de GVL_Troubleshooting change (nouveau champ, nouvelle chaine).
Le snapshot (codesys_snapshot_troubleshooting.py) lit ensuite cette liste, ultra-rapide.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = REPO_ROOT / "CODE"
GVL_PATH = CODE_DIR / "J_SUPERVISION" / "GVL_Troubleshooting.st"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "troubleshooting_variables.txt"

# Ligne de declaration d'un champ STRUCT : "Nom : Type;"
FIELD_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_.]*)\s*;")
# Ouverture d'un TYPE STRUCT : "TYPE <Nom> :"
TYPE_OPEN_RE = re.compile(r"^\s*TYPE\s+([A-Za-z_][A-Za-z0-9_]*)\s*:")
# Fermeture d'un TYPE : "END_TYPE"
END_TYPE_RE = re.compile(r"^\s*END_TYPE\s*")


def strip_comments(text: str) -> str:
    """Retire les commentaires ST (/* */ et //) pour ne garder que les declarations."""
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def build_type_registry() -> dict[str, list[tuple[str, str]]]:
    """Scanne tous les ST_*.st de CODE et construit {type_name: [(field, type), ...]}."""
    registry: dict[str, list[tuple[str, str]]] = {}
    for path in CODE_DIR.rglob("*.st"):
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        current_type: str | None = None
        in_struct = False
        for line in text.splitlines():
            m = TYPE_OPEN_RE.match(line)
            if m:
                current_type = m.group(1)
                in_struct = False
                continue
            if current_type and "STRUCT" in line:
                in_struct = True
                registry.setdefault(current_type, [])
                continue
            if current_type and in_struct:
                if "END_STRUCT" in line:
                    in_struct = False
                    continue
                fm = FIELD_RE.match(line)
                if fm:
                    registry[current_type].append((fm.group(1), fm.group(2)))
            if current_type and END_TYPE_RE.match(line):
                current_type = None
                in_struct = False
    return registry


def walk(field_type: str, prefix: str, registry: dict[str, list[tuple[str, str]]], out: list[str]) -> None:
    """Parcourt recursivement : si le type est une struct connue, on descend ; sinon c'est une feuille."""
    if field_type in registry:
        for sub_name, sub_type in registry[field_type]:
            walk(sub_type, f"{prefix}.{sub_name}", registry, out)
    else:
        out.append(prefix)


def main(output: Path) -> int:
    if not GVL_PATH.is_file():
        print(f"ERROR: {GVL_PATH} introuvable", file=sys.stderr)
        return 2

    registry = build_type_registry()
    gvl_text = strip_comments(GVL_PATH.read_text(encoding="utf-8", errors="replace"))

    # Champs top-level de GVL_Troubleshooting : "Nom : Type;"
    out: list[str] = []
    for line in gvl_text.splitlines():
        m = FIELD_RE.match(line)
        if m:
            walk(m.group(2), f"GVL_Troubleshooting.{m.group(1)}", registry, out)

    if not out:
        print("ERROR: aucun champ top-level trouve dans GVL_Troubleshooting", file=sys.stderr)
        return 1

    # Ajout des variables GVL_BypassRetain (bypasses RETAIN actifs/inactifs)
    gvl_bypass_path = CODE_DIR / "L_SIMULATION" / "GVL_BypassRetain.st"
    if gvl_bypass_path.is_file():
        bypass_text = strip_comments(gvl_bypass_path.read_text(encoding="utf-8", errors="replace"))
        for line in bypass_text.splitlines():
            m = FIELD_RE.match(line)
            if m:
                out.append(f"GVL_BypassRetain.{m.group(1)}")

    # Ajout des variables cles de diagnostic AU / Contacteur de securite (PRG_06_Outputs)
    emergency_diag_vars = [
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.Ready",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.Done",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.State.ChainOk",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.State.ContactorOk",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.State.Step",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.Diag.Error",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.Diag.LastAbortStep",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Status.Diag.LastAbortCause",
        "PRG_06_Outputs.instSafetyEmergencyManagement.ArmingSeqStep",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainA_Cmd",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.MaintainB_Cmd",
        "PRG_06_Outputs.instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd",
        "PRG_06_Outputs.instSafetyEmergencyManagement.ForceTestA",
        "PRG_06_Outputs.instSafetyEmergencyManagement.ForceTestB",
        "PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestA",
        "PRG_06_Outputs.instSafetyEmergencyManagement.BypassTestB",
    ]
    out.extend(emergency_diag_vars)

    # Ajout des variables cles de diagnostic Interlocks / Treuils
    winch_diag_vars = [
        "PRG_06_Outputs.instWinchOutputInterlockM1.State",
        "PRG_06_Outputs.instWinchOutputInterlockM1.Reason",
        "PRG_06_Outputs.instWinchOutputInterlockM1.RestartRequired",
        "PRG_06_Outputs.instWinchOutputInterlockM1.BrakeCmd",
        "PRG_06_Outputs.instWinchOutputInterlockM1.AuthorizedStep",
        "PRG_06_Outputs.instWinchOutputInterlockM2.State",
        "PRG_06_Outputs.instWinchOutputInterlockM2.Reason",
        "PRG_06_Outputs.instWinchOutputInterlockM2.RestartRequired",
        "PRG_06_Outputs.instWinchOutputInterlockM2.BrakeCmd",
        "PRG_06_Outputs.instWinchOutputInterlockM2.AuthorizedStep",
        "PRG_04_Treuils_Benne.Data.WinchM1State.DirectionChangePending",
        "PRG_04_Treuils_Benne.Data.WinchM2State.DirectionChangePending",
        "PRG_06_Outputs.Data.M1AscentStartReady",
        "PRG_06_Outputs.Data.ContactorMismatch",
    ]
    out.extend(winch_diag_vars)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(out) + "\n", encoding="ascii")
    print(f"{len(out)} variables ecrites dans {output}")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="fichier de sortie")
    args = parser.parse_args()
    sys.exit(main(args.output))
