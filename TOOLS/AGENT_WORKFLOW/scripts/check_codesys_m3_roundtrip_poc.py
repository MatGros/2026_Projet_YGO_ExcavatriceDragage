"""Garde-fou T402 : le POC d'écriture CODESYS reste simulation-only et réversible."""
from __future__ import annotations

import ast
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
POC = ROOT / "TOOLS/PLC_CSV_SNAPSHOT/codesys_console/codesys_m3_roundtrip_poc.py"
LAUNCHER = ROOT / "TOOLS/PLC_CSV_SNAPSHOT/codesys_console/codesys_m3_roundtrip_pulse_maintenance.py"


def main() -> None:
    text = POC.read_text(encoding="utf-8")
    launcher = LAUNCHER.read_text(encoding="utf-8")
    ast.parse(text)
    ast.parse(launcher)
    errors: list[str] = []

    required = {
        'ACTION_PROBE = "probe"': "mode probe par défaut",
        "get_simulation_mode()": "contrôle Simulation IDE",
        '"GVL_Simulation.SimulationModeActive"': "garde SimulationModeActive",
        '"GVL_Simulation.SimTranslationActive"': "garde SimTranslationActive",
        "finally:": "restauration garantie",
        "_write_sim_button(online_app, False)": "retour du bouton à FALSE",
        "write_prepared_values()": "écriture non forcée",
    }
    for needle, label in required.items():
        if needle not in text:
            errors.append(f"{label} absent")

    forbidden = (
        "force_prepared_values",
        "set_simulation_mode",
        ".login(",
        "GVL_IHM.",
        "PRG_06_Outputs.",
    )
    for needle in forbidden:
        if needle in text:
            errors.append(f"appel/écriture interdite détecté: {needle}")

    write_path = re.search(r'^WRITE_PATH\s*=\s*"([^"]+)"', text, re.M)
    if not write_path or write_path.group(1) != "GVL_Simulation.SimBtnMaintenance":
        errors.append("WRITE_PATH doit rester limité à SimBtnMaintenance")

    prepared_calls = re.findall(r"set_prepared_value\(([^,]+),", text)
    if prepared_calls != ["WRITE_PATH"]:
        errors.append(f"cibles set_prepared_value inattendues: {prepared_calls}")

    simulation_check = text.find("get_simulation_mode()")
    write_call = text.find("set_prepared_value(")
    if simulation_check < 0 or write_call < 0 or simulation_check > write_call:
        errors.append("le contrôle Simulation IDE doit précéder toute écriture")

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        raise SystemExit(1)
    if '"POC_ACTION"] = "pulse_maintenance"' not in launcher or "globals().copy()" not in launcher or "exec(poc_code" not in launcher:
        print("FAIL: lanceur pulse_maintenance incomplet")
        raise SystemExit(1)
    print("PASS: POC T402 lecture par défaut, écriture unique simulation-only et restauration garantie.")


if __name__ == "__main__":
    main()
