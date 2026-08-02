#!/usr/bin/env python3
"""Run lightweight, non-destructive checks on project ST sources."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

FORBIDDEN = ("CoupeEnable", "FB_Watchdog")
DOC_REF = re.compile(r"DOC/[A-Za-z0-9_./-]+\.md")
# Détecte instFB.VarOutput :=  (écriture sur VAR_OUTPUT d'une instance)
VAR_OUTPUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(Ready|Busy|Done|Error|ErrorId|State|StateAtError)\s*:=")
GVL_SIMULATION_REFERENCE = re.compile(r"\bGVL_Simulation\.")
HYBRID_SIMULATION_FORCING = re.compile(
    r"\bOR\s*\(\s*GVL_Simulation\.[A-Za-z_][A-Za-z0-9_]*\s+AND\b",
    re.IGNORECASE,
)
# W1: Homme-mort — StartStop/StartStop_Active/Direction sans DeadmanArmed
HOMME_MORT_MISSING = re.compile(r"\b(StartStop|StartStop_Active|Direction)\s*:=\s*(?!.*DeadmanArmed)(?![^;]*DeadmanArmed)[^;]+")
# W3: FDC coupe commande sans rampe rapide
FDC_CUTS_WITHOUT_RAMP = re.compile(r"(LimitSwitchFwd|LimitSwitchRev|LimitSwitch)\s*[^;]*?DriveControlWord\s*:=\s*0")
# W5: IF Direction en contexte safety sans // DESIGN:
SAFETY_DIRECTION_IF = re.compile(r"IF\s+Direction\s*[=<>!]")

# Baseline des violations VAR_OUTPUT connues (dette technique préexistante)
# Clé = chemin relatif SANS prefixe CODE/
# Toute NOUVELLE occurrence non listée ici = ERROR
KNOWN_VAR_OUTPUT_VIOLATIONS = {
    "DIAG/FB_Diag_CanOpen.st": {
        "DeviceJoystick.State", "DeviceJoystick.Error", "DeviceJoystick.ErrorId"
    },
    "DIAG/FB_Diag_Ethercat.st": {
        "DeviceVariateur.State", "DeviceEncoderM1.State", "DeviceEncoderM2.State",
        "DeviceVariateur.Error", "DeviceEncoderM1.Error", "DeviceEncoderM2.Error",
        "DeviceVariateur.ErrorId", "DeviceEncoderM1.ErrorId", "DeviceEncoderM2.ErrorId"
    },
}

@dataclass(frozen=True)
class SimulationAllowance:
    """Justification d'une frontiere executable lisant GVL_Simulation."""

    executable_usage: str
    decision: str
    removal_condition: str


# Decision humaine 2026-08 : GVL_Simulation est interdit hors implementation
# CODE/SIMULATION et ces trois frontieres MAIN. Chaque exception est nommee,
# justifiee et temporaire ; ne jamais ajouter un chemin pour faire taire un gate.
SIMULATION_ALLOWED_PATHS: dict[str, SimulationAllowance] = {
    "CODE/MAIN/PRG_ACQUISITION_CFC.st": SimulationAllowance(
        executable_usage="Produit HwReal/HwSim/HwIn et aiguille reel/simule.",
        decision="Decision humaine 2026-08 : frontiere acquisition validee.",
        removal_condition="Retirer lors de la migration CFC/numerotation si la frontiere est remplacee.",
    ),
    "CODE/MAIN/PRG_SUPERVISION_CFC.st": SimulationAllowance(
        executable_usage="Publie les bypass et l'etat SimulationModeActive vers l'IHM.",
        decision="Decision humaine 2026-08 : frontiere supervision validee.",
        removal_condition="Retirer lors de la migration CFC/numerotation si le mapping IHM est remplace.",
    ),
    "CODE/MAIN/PRG_TROUBLESHOOTING_CFC.st": SimulationAllowance(
        executable_usage="Publie le diagnostic lecture seule SimulationEnabled dans GVL_Troubleshooting.",
        decision="Decision humaine 2026-08 : frontiere troubleshooting validee.",
        removal_condition="Retirer lors de la migration CFC/numerotation vers PRG_11_Troubleshooting.",
    ),
}


def strip_st_comments(text: str) -> str:
    """Replace ST comments with spaces while preserving line numbers."""
    def blank(match: re.Match[str]) -> str:
        return re.sub(r"[^\r\n]", " ", match.group(0))

    without_blocks = re.sub(r"\(\*.*?\*\)", blank, text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", blank, without_blocks)


def line_number(text: str, position: int) -> int:
    return text.count("\n", 0, position) + 1


def simulation_reference_allowed(path: Path) -> bool:
    normalized = path.as_posix()
    return normalized.startswith("CODE/SIMULATION/") or normalized in SIMULATION_ALLOWED_PATHS


def requires_doc_reference(path: Path) -> bool:
    normalized = path.as_posix()
    if path.name.startswith(("FB_", "PRG_", "GVL_")):
        return True
    return any(f"/{folder}/" in normalized for folder in ("AU", "TRANSLATION", "TREUILS"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", nargs="?", default="CODE", help="ST file or directory")
    args = parser.parse_args()
    scope = Path(args.scope)
    files = [scope] if scope.is_file() else sorted(scope.rglob("*.st"))
    errors = 0
    warnings = 0

    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        executable_text = strip_st_comments(text)

        # L7-L8 : la simulation est confinée à la frontière HwReal/HwSim/HwIn.
        # Les commentaires sont volontairement ignorés : seule une dépendance exécutable
        # pourrait réintroduire une fuite dans la logique métier.
        if not simulation_reference_allowed(path):
            for match in GVL_SIMULATION_REFERENCE.finditer(executable_text):
                line = line_number(text, match.start())
                print(
                    f"[ERROR] {path}:{line}: GVL_Simulation reference outside allowed simulation boundary",
                    file=sys.stderr,
                )
                errors += 1

        # C1 : ne jamais compléter une valeur réelle par un état simulé « sain ».
        for match in HYBRID_SIMULATION_FORCING.finditer(executable_text):
            line = line_number(text, match.start())
            print(
                f"[ERROR] {path}:{line}: forbidden hybrid simulation forcing "
                "OR (GVL_Simulation.<flag> AND ...)",
                file=sys.stderr,
            )
            errors += 1

        for token in FORBIDDEN:
            if token in text:
                print(f"[ERROR] {path}: forbidden token {token}", file=sys.stderr)
                errors += 1

        # VAR_OUTPUT write detection — only flag cross-file writes
        # (FB writing its own VAR_OUTPUT is correct; PRG writing another FB's VAR_OUTPUT is violation)
        for m in VAR_OUTPUT_WRITE.finditer(text):
            inst_name = m.group(1)
            var_name = m.group(2)
            key = f"{inst_name}.{var_name}"
            line_start = text.rfind("\n", 0, m.start()) + 1
            if text[line_start:m.start()].lstrip().startswith(("GVL_IHM.", "GVL_IHM_AU.")):
                # Bridge Pattern : publication de supervision, pas une écriture dans un FB.
                continue
            rel_path = path.as_posix()
            if rel_path.startswith("CODE/"):
                rel_path = rel_path[5:]
            known = KNOWN_VAR_OUTPUT_VIOLATIONS.get(rel_path, set())
            if key in known:
                print(f"[WARN] {path}: known VAR_OUTPUT write debt: {key}", file=sys.stderr)
                warnings += 1
            else:
                # Check if this is a cross-file write by looking at the instance declaration
                # If instance is declared in this file, it's internal (OK)
                # If instance is declared elsewhere, it's a cross-file write (ERROR)
                inst_decl_pattern = rf"\b{re.escape(inst_name)}\s*:\s*\w+\b"
                if re.search(inst_decl_pattern, text):
                    # Instance declared in this file - internal write, OK
                    continue
                print(f"[ERROR] {path}:{m.start()}: cross-file illegal write to VAR_OUTPUT {key}", file=sys.stderr)
                errors += 1

        # W1: Homme-mort manquant — StartStop/Direction assigné sans DeadmanArmed
        # Recherche assignation StartStop/StartStop_Active/Direction sans DeadmanArmed dans la même instruction
        for m in HOMME_MORT_MISSING.finditer(text):
            # Vérifier que DeadmanArmed n'est PAS dans un rayon de 100 chars
            context = text[max(0, m.start()-100):m.end()+100]
            if "DeadmanArmed" not in context and "PRG_TRANSLATION_CFC" in text:
                line = text[:m.start()].count('\n') + 1
                print(f"[WARN] {path}:{line}: StartStop/Direction assigned without DeadmanArmed check (homme-mort)", file=sys.stderr)
                warnings += 1

        # W3: FDC coupe DriveControlWord sans rampe rapide (SpeedRamp/RampDecelFastRate)
        for m in FDC_CUTS_WITHOUT_RAMP.finditer(text):
            # Chercher SpeedRamp ou RampDecelFastRate dans un rayon de 200 chars
            context = text[max(0, m.start()-200):m.end()+200]
            if "SpeedRamp" not in context and "RampDecelFastRate" not in context:
                line = text[:m.start()].count('\n') + 1
                print(f"[ERROR] {path}:{line}: FDC cuts DriveControlWord without fast ramp (SpeedRamp/RampDecelFastRate missing)", file=sys.stderr)
                errors += 1

        # W5: IF Direction en contexte safety sans commentaire // DESIGN:
        for m in SAFETY_DIRECTION_IF.finditer(text):
            # Chercher // DESIGN: dans un rayon de 300 chars avant/après
            context = text[max(0, m.start()-300):m.end()+300]
            if "DESIGN" not in context and ("FB_Safety" in text or "SafeStop" in text or "PowerCutOff" in text or "ErrorId" in text):
                line = text[:m.start()].count('\n') + 1
                print(f"[WARN] {path}:{line}: IF Direction in safety context missing // DESIGN: comment", file=sys.stderr)
                warnings += 1

        header = text[:4000]
        required = requires_doc_reference(path)
        if "DOC/" not in header:
            if required:
                print(f"[WARN] {path}: no DOC reference in header")
                warnings += 1
        for reference in DOC_REF.findall(header):
            if not Path(reference).is_file():
                level = "ERROR" if required else "WARN"
                print(f"[{level}] {path}: DOC reference not found: {reference}", file=sys.stderr if required else sys.stdout)
                if required:
                    errors += 1
                else:
                    warnings += 1

    print(f"Code style check: {'FAIL' if errors else 'PASS'} ({errors} error(s), {warnings} warning(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
