#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Migration automatique des references legacy PRG_00_Inputs.

Objectif : remplacer PRG_00_Inputs.<x> par les nouveaux producteurs
PRG_00_ACQUISITION_CFC et PRG_01_INPUTS_LD, avec mapping explicite.

Contraintes :
- Ne touche pas a PRG_00_Inputs.st (archive).
- Verifie que la cible du mapping existe reellement dans le nouveau producteur.
- Liste les signaux non resolus sans les remplacer.
"""

import argparse
import os
import re
import sys
from collections import defaultdict, Counter
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = PROJECT_ROOT / "CODE"

EXCLUDED_FILES = {"PRG_00_Inputs.st"}

ACQUISITION_FILE = CODE_DIR / "MAIN" / "PRG_00_ACQUISITION_CFC.st"
INPUTS_LD_FILE = CODE_DIR / "MAIN" / "PRG_01_INPUTS_LD.st"

# ---------------------------------------------------------------------------
# Parsing CODESYS minimal
# ---------------------------------------------------------------------------

def strip_comments(line: str) -> str:
    """Retire les commentaires // et (* *) d'une ligne."""
    line = line.split("//")[0]
    # Suppression non-gourmande des (* *) ; OK car on traigne ligne par ligne.
    line = re.sub(r"\(\*.*?\*\)", "", line)
    return line


def parse_var_outputs(text: str) -> list[str]:
    """Retourne les noms declares dans les blocs VAR_OUTPUT."""
    outputs = []
    for block_match in re.finditer(r"VAR_OUTPUT\b.*?END_VAR", text, re.DOTALL | re.IGNORECASE):
        block = block_match.group(0)
        for line in block.splitlines():
            line = strip_comments(line).strip()
            if not line or re.match(r"VAR_OUTPUT\b|END_VAR\b", line, re.IGNORECASE):
                continue
            m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*[:=]", line)
            if m:
                outputs.append(m.group(1))
    return outputs


def parse_fb_instances(text: str) -> dict[str, str]:
    """Dans les blocs VAR, retourne {nom_instance: type_FB}."""
    instances = {}
    for block_match in re.finditer(r"\bVAR\b(?!_).*?END_VAR", text, re.DOTALL | re.IGNORECASE):
        block = block_match.group(0)
        for line in block.splitlines():
            line = strip_comments(line).strip()
            if not line or re.match(r"VAR\b|END_VAR\b", line, re.IGNORECASE):
                continue
            m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(FB_[A-Za-z0-9_]+)\s*;", line)
            if m:
                instances[m.group(1)] = m.group(2)
    return instances


def parse_fb_type_name(text: str) -> str | None:
    m = re.search(r"FUNCTION_BLOCK\s+(?:PUBLIC\s+)?([A-Za-z_][A-Za-z0-9_]*)", text)
    return m.group(1) if m else None


def collect_fb_outputs() -> dict[str, list[str]]:
    """Indexe les sorties de tous les FUNCTION_BLOCK sous CODE."""
    fb_outputs = {}
    for st_file in CODE_DIR.rglob("*.st"):
        try:
            content = st_file.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        fb_name = parse_fb_type_name(content)
        if fb_name:
            fb_outputs[fb_name] = parse_var_outputs(content)
    return fb_outputs


# ---------------------------------------------------------------------------
# Construction de l'ensemble des cibles valides
# ---------------------------------------------------------------------------

def build_allowed_targets(fb_outputs: dict[str, list[str]]) -> set[str]:
    allowed: set[str] = set()

    def read_or_empty(path: Path) -> str:
        if path.exists():
            return path.read_text(encoding="utf-8", errors="ignore")
        return ""

    acq_text = read_or_empty(ACQUISITION_FILE)
    inputs_text = read_or_empty(INPUTS_LD_FILE)

    # Sorties de PRG_00_ACQUISITION_CFC
    for out in parse_var_outputs(acq_text):
        allowed.add(f"PRG_00_ACQUISITION_CFC.{out}")

    # Sorties des instances FB declarees dans PRG_00_ACQUISITION_CFC
    for inst, fb_type in parse_fb_instances(acq_text).items():
        for out in fb_outputs.get(fb_type, []):
            allowed.add(f"PRG_00_ACQUISITION_CFC.{inst}.{out}")

    # Sorties de PRG_01_INPUTS_LD
    for out in parse_var_outputs(inputs_text):
        allowed.add(f"PRG_01_INPUTS_LD.{out}")

    return allowed


# ---------------------------------------------------------------------------
# Table de mapping (source -> cible)
# ---------------------------------------------------------------------------

def build_mapping() -> list[tuple[str, str, str]]:
    """
    Retourne une liste de tuples (source, cible, mode).
    mode = 'prefix'  : remplace source + tout le suffixe
    mode = 'exact'   : remplace uniquement la chaine exacte
    """
    mapping = [
        # Images matérielles / simulation
        ("PRG_00_Inputs.HwIn.", "PRG_00_ACQUISITION_CFC.HwIn.", "prefix"),
        ("PRG_00_Inputs.HwReal.", "PRG_00_ACQUISITION_CFC.HwReal.", "prefix"),
        ("PRG_00_Inputs.HwSim.", "PRG_00_ACQUISITION_CFC.HwSim.", "prefix"),
        ("PRG_00_Inputs.WinchInputSourceChanged", "PRG_00_ACQUISITION_CFC.WinchInputSourceChanged", "exact"),
        # Décodeur de position M3 (instance -> instance)
        ("PRG_00_Inputs.instPositionDecoder.", "PRG_00_ACQUISITION_CFC.instPosDecoderM3.", "prefix"),
        # Entrees TOR qualifiees
        ("PRG_00_Inputs.PowerContactorEngaged", "PRG_01_INPUTS_LD.PowerContactorEngaged", "exact"),
        ("PRG_00_Inputs.EmergencyChainClosed", "PRG_01_INPUTS_LD.EmergencyChainClosed", "exact"),
        ("PRG_00_Inputs.TopPositionSensor", "PRG_01_INPUTS_LD.TopPositionSensor", "exact"),
        ("PRG_00_Inputs.SlackCableSwitch", "PRG_01_INPUTS_LD.SlackCableSwitch", "exact"),
        ("PRG_00_Inputs.KoboldContactFond", "PRG_01_INPUTS_LD.KoboldContactFond", "exact"),
        ("PRG_00_Inputs.PhaseRotationOk", "PRG_01_INPUTS_LD.PhaseRotationOk", "exact"),
        ("PRG_00_Inputs.BrakeThermalFeedback", "PRG_01_INPUTS_LD.BrakeThermalFeedback", "exact"),
        ("PRG_00_Inputs.M1FwdRevSpeedFeedbackOff", "PRG_01_INPUTS_LD.M1FwdRevSpeedFeedbackOff", "exact"),
        ("PRG_00_Inputs.M1ThermalFeedback", "PRG_01_INPUTS_LD.M1ThermalFeedback", "exact"),
        ("PRG_00_Inputs.M1BrakeFeedback", "PRG_01_INPUTS_LD.M1BrakeFeedback", "exact"),
        ("PRG_00_Inputs.M1BrakeCommandOpenConfirmed", "PRG_01_INPUTS_LD.M1BrakeCommandOpenConfirmed", "exact"),
        ("PRG_00_Inputs.M2FwdRevSpeedFeedbackOff", "PRG_01_INPUTS_LD.M2FwdRevSpeedFeedbackOff", "exact"),
        ("PRG_00_Inputs.M2ThermalFeedback", "PRG_01_INPUTS_LD.M2ThermalFeedback", "exact"),
        ("PRG_00_Inputs.M2BrakeFeedback", "PRG_01_INPUTS_LD.M2BrakeFeedback", "exact"),
        ("PRG_00_Inputs.M2BrakeCommandOpenConfirmed", "PRG_01_INPUTS_LD.M2BrakeCommandOpenConfirmed", "exact"),
        ("PRG_00_Inputs.M3BrakeFeedback", "PRG_01_INPUTS_LD.M3BrakeFeedback", "exact"),
        ("PRG_00_Inputs.M3BrakeCommandOpenConfirmed", "PRG_01_INPUTS_LD.M3BrakeCommandOpenConfirmed", "exact"),
        # Positions translation (sorties programme PRG_00_ACQUISITION_CFC, migration PRG_00_Inputs)
        ("PRG_00_Inputs.TranslationPosTremie", "PRG_00_ACQUISITION_CFC.TranslationPosTremie", "exact"),
        ("PRG_00_Inputs.TranslationPosPV", "PRG_00_ACQUISITION_CFC.TranslationPosPV", "exact"),
        ("PRG_00_Inputs.TranslationPosP2", "PRG_00_ACQUISITION_CFC.TranslationPosP2", "exact"),
        ("PRG_00_Inputs.TranslationPosP1", "PRG_00_ACQUISITION_CFC.TranslationPosP1", "exact"),
        ("PRG_00_Inputs.TranslationPosMaintenance", "PRG_00_ACQUISITION_CFC.TranslationPosMaintenance", "exact"),
        # Variateur M3 filtre (sorties programme PRG_00_ACQUISITION_CFC)
        ("PRG_00_Inputs.M3_StatusWord_Filtered", "PRG_00_ACQUISITION_CFC.M3_StatusWord_Filtered", "exact"),
        ("PRG_00_Inputs.M3_ActualFrequencyHz_Filtered", "PRG_00_ACQUISITION_CFC.M3_ActualFrequencyHz_Filtered", "exact"),
    ]
    # Ordre : plus longues sources d'abord pour eviter les collisions partielles.
    mapping.sort(key=lambda x: len(x[0]), reverse=True)
    return mapping


# ---------------------------------------------------------------------------
# Logique de remplacement
# ---------------------------------------------------------------------------

CHAIN_RE = r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*"


def is_target_allowed(target: str, allowed: set[str], mode: str) -> bool:
    """
    target : chaine complete ou prefixe a valider.
    Pour un prefixe d'image (HwIn/HwReal/HwSim), tout suffixe est accepte.
    """
    if target in allowed:
        return True
    clean = target.rstrip(".")
    if mode == "prefix" and clean.endswith(("HwIn", "HwReal", "HwSim")):
        return True
    return False


def apply_migration(file_path: Path, mapping: list[tuple[str, str, str]], allowed: set[str], dry_run: bool):
    text = file_path.read_text(encoding="utf-8", errors="ignore")
    original = text
    replacements: list[tuple[str, str, str]] = []  # (source_pattern, original_occurrence, new_occurrence)
    unresolved: list[tuple[str, str]] = []  # (source_pattern, original_occurrence)

    for source, target, mode in mapping:
        if mode == "exact":
            pattern = re.compile(re.escape(source))
            if not pattern.search(text):
                continue
            if not is_target_allowed(target, allowed, mode):
                for m in pattern.finditer(text):
                    unresolved.append((source, m.group(0)))
                continue
            new_text = pattern.sub(target, text)
            for m in pattern.finditer(text):
                replacements.append((source, m.group(0), target))
            text = new_text
        else:  # prefix
            # Capture la suite de la chaine (identifiants separes par des points).
            pattern = re.compile(re.escape(source) + f"({CHAIN_RE})")
            if not pattern.search(text):
                continue
            # Validation du prefixe, puis du premier segment si ce n'est pas une image.
            prefix_allowed = True
            prefix_target = target.rstrip(".")
            is_image_prefix = prefix_target.endswith(("HwIn", "HwReal", "HwSim"))
            for m in pattern.finditer(text):
                captured = m.group(1)
                first_seg = captured.split(".")[0]
                if is_image_prefix:
                    check = prefix_target
                else:
                    check = prefix_target + "." + first_seg
                if not is_target_allowed(check, allowed, mode):
                    prefix_allowed = False
                    unresolved.append((source, m.group(0)))
            if not prefix_allowed:
                continue
            for m in pattern.finditer(text):
                captured = m.group(1)
                replacements.append((source, m.group(0), target + captured))
            text = pattern.sub(lambda m, target=target: target + m.group(1), text)

    changed = text != original
    if changed and not dry_run:
        file_path.write_text(text, encoding="utf-8")

    return changed, replacements, unresolved


# ---------------------------------------------------------------------------
# Compteur de references legacy
# ---------------------------------------------------------------------------

def count_legacy_references() -> int:
    total = 0
    for st_file in CODE_DIR.rglob("*.st"):
        if st_file.name in EXCLUDED_FILES:
            continue
        text = st_file.read_text(encoding="utf-8", errors="ignore")
        total += len(re.findall(r"PRG_00_Inputs\.", text))
    return total


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Migration PRG_00_Inputs legacy")
    parser.add_argument("--dry-run", action="store_true", help="Simule sans ecrire")
    parser.add_argument("--verbose", action="store_true", help="Detail par fichier")
    args = parser.parse_args()

    fb_outputs = collect_fb_outputs()
    allowed = build_allowed_targets(fb_outputs)
    mapping = build_mapping()

    if args.verbose:
        print(f"Cibles valides trouvees : {len(allowed)}")
        for t in sorted(allowed):
            print(f"  {t}")
        print()

    before = count_legacy_references()
    print(f"References PRG_00_Inputs avant : {before}")

    files_modified = 0
    all_replacements = []
    all_unresolved = []
    per_file_unresolved = defaultdict(list)

    for st_file in sorted(CODE_DIR.rglob("*.st")):
        if st_file.name in EXCLUDED_FILES:
            continue
        changed, reps, unres = apply_migration(st_file, mapping, allowed, args.dry_run)
        if changed or reps or unres:
            if args.verbose:
                print(f"\n{st_file.relative_to(PROJECT_ROOT)}")
                print(f"  Remplacements : {len(reps)}")
                print(f"  Non resolus   : {len(unres)}")
                for _, orig, new in reps[:10]:
                    print(f"    {orig} -> {new}")
                if len(reps) > 10:
                    print(f"    ... et {len(reps)-10} autres")
                for _, occ in unres[:10]:
                    print(f"    ! {occ}")
                if len(unres) > 10:
                    print(f"    ... et {len(unres)-10} autres non resolus")
        if changed:
            files_modified += 1
        all_replacements.extend(reps)
        all_unresolved.extend(unres)
        per_file_unresolved[st_file].extend(unres)

    after = count_legacy_references()
    print(f"\nFichiers modifies : {files_modified}")
    print(f"References PRG_00_Inputs apres : {after}")

    # Signaux non resolus uniques
    unresolved_signals = sorted({occ for _, occ in all_unresolved})
    print(f"\nSignaux non resolus ({len(unresolved_signals)}):")
    for sig in unresolved_signals:
        print(f"  - {sig}")

    if args.dry_run:
        print("\n[DRY-RUN] Aucun fichier n'a ete modifie.")
        return 1 if unresolved_signals else 0

    return 0 if after == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
