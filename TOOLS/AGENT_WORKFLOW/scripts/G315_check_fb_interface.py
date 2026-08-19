#!/usr/bin/env python3
"""G315 — Vérifie la conformité des interfaces des blocs fonctionnels (FB_*.st).

Référentiel :
  - DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies (Contrats light & standard)
  - DOC/WFLOW/CONTRACTS/TASK_CONTRACT_STANDARD_INTERFACES_FB.yaml (T136)

Profils d'interface :
  1. Standard (score 5/5) : porte les 5 membres d'état (Busy, Done, Error, ErrorId, State)
  2. Light (score 0/5)    : ne porte aucun des 5 membres d'état (calculateur, filtre, utilitaire)
  3. Exceptions (1-4/5)   : FB en entre-deux expressément documentés et justifiés

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G315_check_fb_interface.py
  python TOOLS/AGENT_WORKFLOW/scripts/G315_check_fb_interface.py --report
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Les 5 membres du bloc d'état caractérisant le profil standard
STATUS_MEMBERS = ["Busy", "Done", "Error", "ErrorId", "State"]

# Dérogations documentées des 5 FB en entre-deux (AC7)
EXCEPTIONS_JUSTIFICATION: dict[str, str] = {
    "FB_Output": "Bloc de barrière finale Ladder; porte uniquement State (1/5), pas de machine d'état asynchrone.",
    "FB_Safety_EmergencyManagementLogic": "Sous-composant interne de sécurité AU (POO); porte Error et ErrorId (2/5), pas de cycle de vie Done/Busy.",
    "FB_Safety_EmergencyManagementOutput": "Sous-composant étage de sortie sécurité AU; porte Error, ErrorId et State (3/5).",
    "FB_Joystick": "Acquisition de manche analogique; porte Busy, Done, Error, ErrorId (4/5), sans machine d'état State.",
    "FB_SimBench": "Banc d'orchestration de simulation pour banc de test; porte Error et ErrorId (2/5).",
}


def analyze_fb_files(root: Path) -> tuple[list[Path], list[Path], list[tuple[Path, int]], list[tuple[Path, int]]]:
    standard_fbs: list[Path] = []
    light_fbs: list[Path] = []
    documented_exceptions: list[tuple[Path, int]] = []
    unauthorized_in_between: list[tuple[Path, int]] = []

    code_dir = root / "CODE" if (root / "CODE").is_dir() else root
    fb_files = sorted(code_dir.glob("**/FB_*.st"))

    for fb_path in fb_files:
        content = fb_path.read_text(encoding="utf-8", errors="replace")
        score = 0
        for member in STATUS_MEMBERS:
            if re.search(rf"^\s*{member}\s*:\s*", content, re.MULTILINE):
                score += 1

        fb_name = fb_path.stem

        if score == 5:
            standard_fbs.append(fb_path)
        elif score == 0:
            light_fbs.append(fb_path)
        else:
            if fb_name in EXCEPTIONS_JUSTIFICATION:
                documented_exceptions.append((fb_path, score))
            else:
                unauthorized_in_between.append((fb_path, score))

    return standard_fbs, light_fbs, documented_exceptions, unauthorized_in_between


def main() -> int:
    parser = argparse.ArgumentParser(description="Vérifie la conformité des interfaces FB (G315).")
    parser.add_argument("--root", type=Path, default=Path("."), help="Racine du dépôt")
    parser.add_argument("--report", action="store_true", help="Affiche le détail de la classification")
    args = parser.parse_args()

    standard_fbs, light_fbs, documented_exceptions, unauthorized = analyze_fb_files(args.root)

    total_fbs = len(standard_fbs) + len(light_fbs) + len(documented_exceptions) + len(unauthorized)

    if args.report or unauthorized:
        print("=" * 70)
        print(f"[RAPPORT] CLASSIFICATION DES INTERFACES FB (Total: {total_fbs})")
        print("=" * 70)
        print(f"  * Profil Standard (5/5 status) : {len(standard_fbs)}")
        print(f"  * Profil Light    (0/5 status) : {len(light_fbs)}")
        print(f"  * Exceptions documentees (1-4) : {len(documented_exceptions)}")
        for path, score in documented_exceptions:
            reason = EXCEPTIONS_JUSTIFICATION.get(path.stem, "N/A")
            print(f"      - {path.name:35} (Score {score}/5) : {reason}")

        if unauthorized:
            print(f"\n[ALERTE] FB HORS-CONTRAT NON AUTORISES ({len(unauthorized)}) :")
            for path, score in unauthorized:
                print(f"      [!] {path.name:35} (Score {score}/5)")
        print("=" * 70)

    if unauthorized:
        print(f"FAIL: {len(unauthorized)} FB hors-contrat detecte(s).", file=sys.stderr)
        return 1

    print(f"PASS: {total_fbs} FB classes avec succes (Standard: {len(standard_fbs)}, Light: {len(light_fbs)}, Exceptions: {len(documented_exceptions)}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
