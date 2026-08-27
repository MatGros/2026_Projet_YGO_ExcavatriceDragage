#!/usr/bin/env python3
"""G315 — Vérifie la conformité des interfaces des blocs fonctionnels (FB_*.st).

Référentiel :
  - DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies (Contrats light & standard)
  - DOC/AF/AF_Partie-03_Contrats_Composants/FB_FaultCore_v1.0.md
  - ARCHIVES/Doc/CONTRACTS/TASK_CONTRACT_STANDARD_INTERFACES_FB.yaml (T136, archivé)

Profils d'interface :
  1. Standard (score 5/5) : porte le bloc d'état complet, sous l'une des trois formes ci-dessous
  2. Light (score 0/5)    : ne porte aucun des 5 membres d'état (calculateur, filtre, utilitaire)
  3. Exceptions (1-4/5)   : FB en entre-deux expressément documentés et justifiés

Trois formes valent 5/5 pour le profil standard :
  - FORME CIBLE (T164-3)   : `Fault : ST_Fault;` — rempli par une instance FB_FaultCore à partir
                             d'une liste `Causes : ARRAY[0..15] OF ST_FaultCause`. Cycle de vie
                             éventuel dans `Lifecycle : ST_Lifecycle` (Busy/Done), séparé.
  - FORME LEGACY-STATUS     : `Status : ST_Status;` (ex-ST_FbStatus renommé) — tolérance tracée,
                             levée à la clôture de T164-5 (migration des 17 FB vers Fault:ST_Fault).
  - FORME HÉRITÉE (à plat)  : les 5 membres déclarés individuellement — tolérance transitoire T137.

REX 2026-08-19 (corrigé) : la version initiale ne détectait QUE la forme à plat. Un FB migré
tombait à 0%, était classé « Light » et le script sortait en SUCCÈS sans rien signaler.

REX 2026-08-20 (corrigé — revue T136) : classifieur TYPE-BLIND sur `State`. Il vérifie désormais
que `State` est une SORTIE PUBLIQUE typée `E_State`.

T164-3 (2026-08-27) : forme cible passée de `Status : ST_FbStatus` à `Fault : ST_Fault` (socle
FB_FaultCore). `ST_FbStatus`/`FB_FbStatus`/`ST_FbCause` supprimés du code (commit 51fccce6) ;
`ST_FbStatus` renommé `ST_Status`. Le DUT dont l'existence est vérifiée est désormais `ST_Fault.st`.
Un FB à `State` domaine (E_Diag_State, ST_Safety_Emergency_State, E_CycleStep…) N'est plus
« non migrable » : `ST_Fault` ne porte pas de champ `State`, il peut donc coexister avec un état
domaine séparé — ces FB restent listés en exception le temps de T164-5, plus comme blocage définitif.

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

# Forme CIBLE (T164-3) : un membre typé ST_Fault (rempli par FB_FaultCore).
# Le nom du membre n'est pas contraint (Fault par convention) — c'est le TYPE qui fait foi.
FAULT_STRUCT_RE = re.compile(r"^\s*\w+\s*:\s*ST_Fault\b", re.MULTILINE)
# Forme LEGACY-STATUS : membre typé ST_Status (ex-ST_FbStatus) — tolérée jusqu'à T164-5.
STATUS_STRUCT_RE = re.compile(r"^\s*\w+\s*:\s*ST_Status\b", re.MULTILINE)

# Dérogations documentées des FB non migrables / en entre-deux (AC7).
# ⚠️ Un FB à « State » domaine (E_Diag_State, ST_Safety_Emergency_State, CycleStep…) ne peut PAS
# adopter ST_FbStatus (State:E_State) sans perte sémantique → jamais standard, jamais light.
# (REX 2026-08-20 : ces FB étaient comptés « standard » à tort — classifieur type-blind.)
# NB (T164-3) : « non migrable » supprimé — ST_Fault ne porte pas de champ State, il coexiste
# avec un état domaine séparé. Ces FB restent listés le temps de T164-5 (migration vers Fault:ST_Fault).
EXCEPTIONS_JUSTIFICATION: dict[str, str] = {
    "FB_Safety_EmergencyManagementLogic": "Sous-composant interne de sécurité AU (POO) ; porte Error et ErrorId (2/5), pas de cycle de vie Done/Busy. À migrer Fault:ST_Fault en T164-5.",
    "FB_Safety_EmergencyManagementOutput": "Étage de sortie sécurité AU ; état domaine State : ST_Safety_Emergency_State (séparé, cohabite avec Fault:ST_Fault). Migration T164-5.",
    "FB_SimBench": "Banc d'orchestration de simulation ; porte Error et ErrorId (2/5). Migration T164-5.",
    "FB_Safety_EmergencyManagement": "Séquenceur de réarmement AU ; état domaine State : ST_Safety_Emergency_State (séparé). Migration T164-5.",
    "FB_Diag_CanOpen": "Diagnostic CANopen ; état domaine State : E_Diag_State (séparé). Migration T164-5.",
    "FB_Diag_Ethercat": "Diagnostic EtherCAT ; état domaine State : E_Diag_State (séparé). Migration T164-5.",
    "FB_Cycle": "Séquenceur cycle semi-auto ; étape publique CycleStep : E_CycleStep. Migration T164-5.",
    "FB_WinchOutputInterlock": "Barrière interlock treuil ; état domaine State : E_WinchFinalInterlockState (séparé). Migration T164-5.",
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

        # Forme CIBLE (Fault:ST_Fault) OU forme LEGACY-STATUS (Status:ST_Status) : un membre
        # struct porte le bloc d'état. Sans ce test, un FB migré serait classé « Light ».
        if FAULT_STRUCT_RE.search(content) or STATUS_STRUCT_RE.search(content):
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
    """Le DUT cible ST_Fault doit exister dans CODE/ avant toute migration (T164-3)."""
    code_dir = root / "CODE" if (root / "CODE").is_dir() else root
    return (code_dir / "A_COMMUN" / "ST_Fault.st").is_file() or (code_dir / "A_COMMUN" / "_TYPES" / "ST_Fault.st").is_file()


def split_standard_by_form(standard_fbs: list[Path]) -> tuple[list[Path], list[Path], list[Path]]:
    """Répartit les FB standard en 3 formes : cible (Fault:ST_Fault), legacy-status
    (Status:ST_Status, jusqu'à T164-5) et héritée à plat (T137).

    Indicateur d'avancement : la migration est terminée quand `legacy_status` ET
    `legacy_flat` sont vides.
    """
    target_form: list[Path] = []
    legacy_status: list[Path] = []
    legacy_flat: list[Path] = []
    for fb_path in standard_fbs:
        content = fb_path.read_text(encoding="utf-8", errors="replace")
        if FAULT_STRUCT_RE.search(content):
            target_form.append(fb_path)
        elif STATUS_STRUCT_RE.search(content):
            legacy_status.append(fb_path)
        else:
            legacy_flat.append(fb_path)
    return target_form, legacy_status, legacy_flat


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
        target_form, legacy_status, legacy_flat = split_standard_by_form(standard_fbs)
        print(f"  * DUT ST_Fault present dans CODE/ : {'OUI' if dut_present else 'NON ⚠️'}")
        print(f"  * Profil Standard (bloc d'etat complet) : {len(standard_fbs)}")
        print(f"      - forme cible       (Fault : ST_Fault)   : {len(target_form)}")
        print(f"      - legacy-status     (Status : ST_Status, T164-5) : {len(legacy_status)}")
        print(f"      - legacy a plat     (5 membres, T137)    : {len(legacy_flat)}")
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
        print("FAIL: le DUT cible ST_Fault est absent de CODE/A_COMMUN/ (migration T164-x impossible).", file=sys.stderr)
        return 1

    if unauthorized:
        print(f"FAIL: {len(unauthorized)} FB hors-contrat detecte(s).", file=sys.stderr)
        return 1

    print(f"PASS: {total_fbs} FB classes avec succes (Standard: {len(standard_fbs)}, Light: {len(light_fbs)}, Exceptions: {len(documented_exceptions)}). DUT present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
