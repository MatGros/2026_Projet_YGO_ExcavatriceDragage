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
                    de T137 (arbitrage 2026-08-19 : ST_FbStatus est une cible, pas une variante)

REX 2026-08-19 (corrigé) : la version initiale ne détectait QUE la forme à plat et ignorait
ST_FbStatus. Un FB migré perdait ses membres à plat, tombait à 0%, était classé « Light » et
le script sortait en SUCCÈS sans rien signaler.

REX 2026-08-20 (corrigé — revue T136) : le classifieur était TYPE-BLIND. Il comptait le membre
`State` sur son NOM seul, sans vérifier son TYPE ni sa visibilité : un FB avec `State` public
typé hors `E_State` (E_Diag_State, E_WinchFinalInterlockState, ST_Safety_Emergency_State…) ou un
`State` local `[LOC]` (ex. FB_Cycle) était compté 5/5 et classé « standard » — or ces FB NE PEUVENT
PAS adopter `ST_FbStatus` (dont `State : E_State`) sans perte sémantique. La conséquence : le
décompte « 21 standard » était erroné (~5 FB non migrables). Le classifieur vérifie désormais que
`State` est une SORTIE PUBLIQUE typée `E_State` ; un FB à `State` domaine est reclassé et doit être
explicitement listé en exception. Il vérifie aussi l'existence du DUT `ST_FbStatus` dans `CODE/`.

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

# Types scalaires : un `State` ainsi typé n'est PAS un état de machine d'état
# (ex. FB_Output.State : BOOL = sortie logique physique) → ne compte pas.
SCALAR_STAT_TYPES = {
    "BOOL", "BYTE", "WORD", "DWORD", "LWORD",
    "INT", "DINT", "LINT", "UINT", "UDINT", "ULINT", "SINT", "USINT",
    "REAL", "LREAL", "TIME", "DATE", "DT",
}

# Forme cible : un membre unique typé ST_FbStatus agrège tout le bloc d'état.
# Le nom du membre n'est pas contraint (Status par convention) — c'est le TYPE qui fait foi.
STATUS_STRUCT_RE = re.compile(r"^\s*\w+\s*:\s*ST_FbStatus\b", re.MULTILINE)

# Dérogations documentées des FB non migrables / en entre-deux (AC7).
# ⚠️ Un FB à « State » domaine (E_Diag_State, ST_Safety_Emergency_State, CycleStep…) ne peut PAS
# adopter ST_FbStatus (State:E_State) sans perte sémantique → jamais standard, jamais light.
# (REX 2026-08-20 : ces FB étaient comptés « standard » à tort — classifieur type-blind.)
EXCEPTIONS_JUSTIFICATION: dict[str, str] = {
    "FB_Safety_EmergencyManagementLogic": "Sous-composant interne de sécurité AU (POO); porte Error et ErrorId (2/5), pas de cycle de vie Done/Busy.",
    "FB_Safety_EmergencyManagementOutput": "Étage de sortie sécurité AU; bus d'état domaine State : ST_Safety_Emergency_State (non migrable).",
    "FB_Joystick": "Acquisition de manche analogique; porte Busy, Done, Error, ErrorId (4/5), sans machine d'état State.",
    "FB_SimBench": "Banc d'orchestration de simulation pour banc de test; porte Error et ErrorId (2/5).",
    "FB_Safety_EmergencyManagement": "Séquenceur de réarmement AU ; bus d'état domaine State : ST_Safety_Emergency_State (non migrable).",
    "FB_Diag_CanOpen": "Diagnostic CANopen ; état domaine State : E_Diag_State (non migrable).",
    "FB_Diag_Ethercat": "Diagnostic EtherCAT ; état domaine State : E_Diag_State (non migrable).",
    "FB_Cycle": "Séquenceur cycle semi-auto ; étape publique CycleStep : E_CycleStep, sans State:E_State public (non migrable).",
    "FB_WinchOutputInterlock": "Barrière interlock treuil ; état domaine State : E_WinchFinalInterlockState (non migrable).",
}


def get_output_block(content: str) -> str:
    """Extrait le premier bloc VAR_OUTPUT..END_VAR (les sorties publiques)."""
    m = re.search(r"\bVAR_OUTPUT\b(.*?)\bEND_VAR\b", content, re.DOTALL)
    return m.group(1) if m else ""


def decl_type(block: str, name: str) -> str | None:
    """Type d'un membre déclaré dans le bloc (None si absent). N'utilise que le
    bloc VAR_OUTPUT : un `State` local `[LOC]` ou un membre d'une autre section
    n'est jamais compté comme sortie publique."""
    m = re.search(rf"^\s*{re.escape(name)}\s*:\s*([A-Za-z_]\w*)", block, re.MULTILINE)
    return m.group(1) if m else None


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
        # Sans ce test, un FB migré perdrait ses membres à plat et serait classé « Light ».
        if STATUS_STRUCT_RE.search(content):
            standard_fbs.append(fb_path)
            continue

        # Forme héritée : les 5 membres déclarés individuellement (tolérance transitoire T137).
        # ⚠️ TYPE-AWARE (REX 2026-08-20) : `State` n'est compté que s'il est une SORTIE PUBLIQUE
        # typée E_State. Un état domaine (E_Diag_State, ST_Safety_Emergency_State, …) ou un `State`
        # scalaire/sortie physique (ex. BOOL) ne compte pas.
        out = get_output_block(content)
        score = 0
        for member in ("Busy", "Done", "Error", "ErrorId"):
            if decl_type(out, member):
                score += 1
        state_type = decl_type(out, "State")
        if state_type == "E_State":
            score += 1

        fb_name = fb_path.stem

        # État de machine « domaine » : un `State` public struct/enum (non E_State, non scalaire).
        # Ce FB NE PEUT PAS adopter ST_FbStatus (State:E_State) sans perte → jamais standard,
        # jamais light → doit être une exception documentée.
        domain_state = state_type is not None and state_type not in SCALAR_STAT_TYPES and state_type != "E_State"

        if domain_state:
            if fb_name in EXCEPTIONS_JUSTIFICATION:
                documented_exceptions.append((fb_path, score))
            else:
                unauthorized_in_between.append((fb_path, score))
            continue

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


def dut_exists(root: Path) -> bool:
    """Le DUT cible ST_FbStatus doit exister dans CODE/ avant toute migration (REX 2026-08-20)."""
    code_dir = root / "CODE" if (root / "CODE").is_dir() else root
    return (code_dir / "A_COMMUN" / "ST_FbStatus.st").is_file()


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
    dut_present = dut_exists(args.root)

    if args.report or unauthorized or not dut_present:
        print("=" * 70)
        print(f"[RAPPORT] CLASSIFICATION DES INTERFACES FB (Total: {total_fbs})")
        print("=" * 70)
        target_form, legacy_form = split_standard_by_form(standard_fbs)
        print(f"  * DUT ST_FbStatus present dans CODE/ : {'OUI' if dut_present else 'NON ⚠️'}")
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

    if not dut_present:
        print(f"FAIL: le DUT cible ST_FbStatus est absent de CODE/A_COMMUN/ (T137 ne peut pas demarrer).", file=sys.stderr)
        return 1

    if unauthorized:
        print(f"FAIL: {len(unauthorized)} FB hors-contrat detecte(s).", file=sys.stderr)
        return 1

    print(f"PASS: {total_fbs} FB classes avec succes (Standard: {len(standard_fbs)}, Light: {len(light_fbs)}, Exceptions: {len(documented_exceptions)}). DUT present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
