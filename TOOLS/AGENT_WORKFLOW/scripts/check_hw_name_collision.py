#!/usr/bin/env python3
"""Garde-fou REX 2026-08-05 (audit terrain M3, contacteur frein jamais piloté).

Un PROGRAM (PRG_*) qui déclare une variable (VAR/VAR_INPUT/VAR_OUTPUT) avec le nom
EXACT d'un point matériel du mapping E/S (Device_IO CSV, ex. M3_BrakeRelease_RQ,
M1_RelayFwd_Up_DQ) crée une collision de portée : CODESYS crée aussi une variable
GLOBALE de ce nom lors du mapping E/S réel du device. Un identificateur local masque
toujours un global homonyme (IEC 61131-3) — toute écriture DANS ce POU résout vers la
variable locale, jamais vers la globale réellement mappée au matériel. Aucune erreur
de compilation ni d'import ne signale ce piège : la sortie physique ne bouge
simplement jamais.

Confirmé en test terrain (2026-08-05) : forcer M3_BrakeRelease_RQ depuis un AUTRE POU
pilotait bien le relais ; PRG_06_Outputs_LD écrivant sur le même nom ne pilotait rien.
Fix appliqué (M1/M2/M3 relais/contacteurs/frein ET chaîne AU PowerKeepAlive_A_RQ/
PowerKeepAlive_B_RQ/EmergencyArming_RQ, confirmées câblées réel par l'utilisateur) :
TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py (plus de coil ni de
VAR_OUTPUT sur les noms Device bruts, renommage *Cmd) + CODE/MAIN/PRG_06_Outputs_LD.st
+ CODE/MAIN/PRG_02_Acquisition.st (références qualifiées mises à jour).

Seul PRG_02_Acquisition (frontière acquisition, AF_Partie-06) a le droit de porter ces
noms bruts, en VAR_INPUT — c'est son rôle architectural documenté.

Source de vérité matérielle : TOOLS/AGENT_WORKFLOW/config/Device_IO_20260806.csv
(colonne 1, "Mapped variable" — export CODESYS réel, référence AF_Partie-06 §4).
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

# Seul POU dont le rôle architectural est de porter les noms Device bruts (AF_Partie-06 §1/§4).
ACQUISITION_FRONTIER = "MAIN/PRG_02_Acquisition.st"

# Trappe de sortie pour une collision detectee mais pas encore verifiee terrain :
# WARN (pas ERROR, non bloquant) le temps de confirmer sur machine reelle. Vide
# depuis 2026-08-05 (PowerKeepAlive_A_RQ/B_RQ/EmergencyArming_RQ confirmes casses
# et corriges, meme lot que le frein M1/M2/M3). Ne JAMAIS l'utiliser pour faire
# taire durablement une collision confirmee — c'est une pause, pas une exemption.
PENDING_FIELD_VERIFICATION: set[str] = set()

# Un identificateur local ne risque de masquer un global HW que dans un PROGRAM
# (singleton, adressable sans instance) — un FUNCTION_BLOCK est toujours référencé
# via une instance (instXxx.Param), jamais par son nom de paramètre nu : pas le même
# risque de collision de portée. On limite donc le contrôle aux PRG_*.st.
VAR_BLOCK_START = re.compile(r"\bVAR(?:_INPUT|_OUTPUT)?\b(?!\s*_IN_OUT)", re.IGNORECASE)
END_VAR = re.compile(r"\bEND_VAR\b", re.IGNORECASE)
DECL_LINE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?::|,)")


def strip_st_comments(text: str) -> str:
    """Remplace les commentaires ST par des espaces, en conservant les numéros de ligne."""

    def blank(match: re.Match[str]) -> str:
        return re.sub(r"[^\r\n]", " ", match.group(0))

    without_blocks = re.sub(r"\(\*.*?\*\)", blank, text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", blank, without_blocks)


def load_hw_names(csv_path: Path) -> set[str]:
    names: set[str] = set()
    with csv_path.open(encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f, delimiter=";"):
            if not row or not row[0]:
                continue
            name = row[0].strip()
            if not name or name.startswith("//"):
                continue
            names.add(name)
    return names


def declared_names(text: str) -> list[tuple[str, int]]:
    """Retourne (nom, ligne) pour chaque variable déclarée dans un bloc VAR/VAR_INPUT/VAR_OUTPUT."""
    results: list[tuple[str, int]] = []
    pos = 0
    while True:
        start_match = VAR_BLOCK_START.search(text, pos)
        if not start_match:
            break
        end_match = END_VAR.search(text, start_match.end())
        if not end_match:
            break
        block = text[start_match.end():end_match.start()]
        block_offset = start_match.end()
        for line in block.splitlines(keepends=True):
            m = DECL_LINE.match(line)
            if m:
                line_no = text.count("\n", 0, block_offset) + 1
                results.append((m.group(1), line_no))
            block_offset += len(line)
        pos = end_match.end()
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    csv_path = root / "TOOLS" / "AGENT_WORKFLOW" / "config" / "Device_IO_20260806.csv"
    if not csv_path.is_file():
        print(f"[ERROR] Device IO CSV introuvable : {csv_path}", file=sys.stderr)
        return 1
    hw_names = load_hw_names(csv_path)

    errors = 0
    warnings = 0
    for path in sorted((root / "CODE" / "MAIN").glob("PRG_*.st")):
        rel = path.relative_to(root / "CODE").as_posix()
        if rel == ACQUISITION_FRONTIER:
            continue
        text = strip_st_comments(path.read_text(encoding="utf-8", errors="replace"))
        for name, line in declared_names(text):
            if name not in hw_names:
                continue
            if name in PENDING_FIELD_VERIFICATION:
                print(
                    f"[WARN] CODE/{rel}:{line}: '{name}' partage le nom d'une variable "
                    f"matérielle (Device_IO CSV) — meme schema que le bug frein M3, mais "
                    f"NON VERIFIE terrain. Confirmer le mapping E/S qualifie avant de "
                    f"considerer ce point sain (voir REX 2026-08-05).",
                    file=sys.stderr,
                )
                warnings += 1
                continue
            print(
                f"[ERROR] CODE/{rel}:{line}: '{name}' est un nom de variable matérielle "
                f"(Device_IO CSV) — le déclarer localement masque la globale réellement "
                f"mappée au HW (IEC 61131-3), la sortie/entrée physique ne suit alors plus "
                f"jamais. Renommer la variable locale (voir REX 2026-08-05).",
                file=sys.stderr,
            )
            errors += 1

    print(f"HW name collision check: {'FAIL' if errors else 'PASS'} ({errors} error(s), {warnings} warning(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
