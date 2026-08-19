#!/usr/bin/env python3
"""G315 — Vérifie la conformité des interfaces des blocs fonctionnels (FB_*.st).

Référentiel :
  - DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies (Contrats light & standard)
  - DOC/WFLOW/CONTRACTS/TASK_CONTRACT_STANDARD_INTERFACES_FB.yaml (T136)

Profils d'interface :
  1. Standard (score 5/5) : porte le bloc d'état complet, sous l'une des deux formes ci-dessous
  2. Light (score 0/5)    : ne porte aucun des 5 membres d'état (calculateur, filtre, utilitaire)
  3. Exceptions (1-4/5)   : FB en entre-deux expressément documentés et justifiés

Deux formes valent 5/5 pour le profil standard :
  - FORME CIBLE   : `Status : ST_FbStatus;` (un seul membre agrégeant le bloc d'état)
  - FORME HÉRITÉE : les 5 membres déclarés à plat — tolérance transitoire, levée à la clôture
                    de T137 (arbitrage 2026-08-19 : ST_FbStatus est une CIBLE, pas une variante)

REX 2026-08-19 (corrigé) : la version initiale ne détectait QUE la forme à plat et ignorait
ST_FbStatus. Un FB migré perdait ses membres à plat, tombait à 0/5, était classé « light » et
le script sortait en SUCCÈS sans rien signaler — le garde-fou se dégradait en silence dès le
premier FB migré. Le décompte des deux formes sert désormais d'indicateur d'avancement T137.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G315_check_fb_interface.py
  python TOOLS/AGENT_WORKFLOW/scripts/G315_check_fb_interface.py --report
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Les 5 membres du bloc d'état caractérisant le profil standard (forme héritée, à plat)
STATUS_MEMBERS = ["Busy", "Done", "Error", "ErrorId", "State"]

# Forme cible : un membre unique typé ST_FbStatus agrège tout le bloc d'état.
# Le nom du membre n'est pas contraint (Status par convention) — c'est le TYPE qui fait foi.
STATUS_STRUCT_RE = re.compile(r"^\s*\w+\s*:\s*ST_FbStatus\b", re.MULTILINE)

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

        # Forme cible : un membre typé ST_FbStatus porte à lui seul tout le bloc d'état.
        # Sans ce test, un FB migré perdrait ses membres à plat et serait classé « light ».
        if STATUS_STRUCT_RE.search(content):
            standard_fbs.append(fb_path)
            continue

        # Forme héritée : les 5 membres déclarés individuellement (tolérance transitoire T137).
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


def split_standard_by_form(standard_fbs: list[Path]) -> tuple[list[Path], list[Path]]:
    """Sépare les FB standard entre forme cible (ST_FbStatus) et forme héritée (à plat).

    Sert d'indicateur d'avancement de T137 : la migration est terminée quand la
    liste « héritée » est vide.
    """
    target_form: list[Path] = []
    legacy_form: list[Path] = []
    for fb_path in standard_fbs:
        content = fb_path.read_text(encoding="utf-8", errors="replace")
        if STATUS_STRUCT_RE.search(content):
            target_form.append(fb_path)
        else:
            legacy_form.append(fb_path)
    return target_form, legacy_form


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
        target_form, legacy_form = split_standard_by_form(standard_fbs)
        print(f"  * Profil Standard (bloc d'etat complet) : {len(standard_fbs)}")
        print(f"      - forme cible   (Status : ST_FbStatus) : {len(target_form)}")
        print(f"      - forme heritee (membres a plat, T137) : {len(legacy_form)}")
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
