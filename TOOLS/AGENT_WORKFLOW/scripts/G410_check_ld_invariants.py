#!/usr/bin/env python3
"""Garde-fou (REX 2026-08-04) : invariants LD de TOUS les POU `_LD`.

Vérifie sur le bundle (ou un XML direct) les contraintes structurelles CODESYS
découvertes lors du débogage IndexOutOfRangeException / ArgumentNullException.
Appliqué à chaque POU suffixé `_LD` (initialement figé sur PRG_06_Outputs_LD,
généralisé 2026-08-13 : un nouveau POU `_LD` comme PRG_02_Acquisition_LD doit
être couvert par le même garde-fou) :

1. localId du bloc < localId de ses sources (inVariable/contact connectés)
2. Pas de coil doublon : un output assigné par expression DANS le bloc ne doit
   PAS avoir de coil externe (double assignement -> ArgumentNullException)
3. Les coils pointent vers des variables déclarées dans l'interface du POU
   (les sorties Device _DQ sont absentes du bundle -> crash à l'ouverture)
4. Pas de motif inVariable(expression) -> outVariable (IndexOutOfRange)
5. Pas de contact câblé sur une broche de sortie de bloc (cause #6, REX_PRG06)

Usage:
    python G410_check_ld_invariants.py [project_root] [--bundle PATH] [--report]

Exemple:
    python G410_check_ld_invariants.py . --report
    python G410_check_ld_invariants.py --bundle scratch/PRG_02_Acquisition_LD.xml --report
"""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"pou": "http://www.plcopen.org/xml/tc6_0200"}

# 🧪 Exception documentée (décision utilisateur 2026-08-06) : coil voulue délibérément
# sur un nom HW brut, malgré le risque de crash que cet invariant même détecte. Liste
# synchronisée à la main avec DIRECT_HW_COILS dans gen_prg06_oracle.py. Reste en WARN
# (jamais silencieux) — retirer de cette liste dès validation réelle à l'import CODESYS,
# ou revenir au remap manuel qualifié si le crash annoncé se confirme (REX 2026-08-06).
KNOWN_DIRECT_HW_COIL_TARGETS = {
    "M1_RelayFwd_Up_DQ", "M1_RelayRev_Down_DQ",
    "M1_SpeedContactor_1_DQ", "M1_SpeedContactor_2_DQ", "M1_SpeedContactor_3_DQ", "M1_SpeedContactor_4_DQ",
    "M1_BrakeRelease_RQ",
    "M2_RelayFwd_Up_Close_DQ", "M2_RelayRev_Down_Open_DQ",
    "M2_SpeedContactor_1_DQ", "M2_SpeedContactor_2_DQ", "M2_SpeedContactor_3_DQ", "M2_SpeedContactor_4_DQ",
    "M2_BrakeRelease_RQ",
    "M3_BrakeRelease_RQ",
    "PowerKeepAlive_A_RQ", "PowerKeepAlive_B_RQ", "EmergencyArming_RQ",
    "M1_M2_KoboldMeasureEnable_DQ",  # 🆕 2026-08-07 (12bis) : retour terrain urgent, voir DIRECT_HW_COILS
}


def _tag(el: ET.Element) -> str:
    return el.tag.rsplit("}", 1)[-1]


def _local_vars(pou: ET.Element) -> set[str]:
    """Toutes les variables déclarées dans l'interface du POU."""
    names: set[str] = set()
    iface = pou.find("pou:interface", NS)
    if iface is None:
        return names
    for section in iface:
        for v in section.findall("pou:variable", NS):
            names.add(v.get("name"))
    return names


def check_bundle(bundle: Path, report: bool = False) -> tuple[list[str], list[str]]:
    """Retourne (errors, warnings). Applique les invariants à TOUS les POU `_LD`."""
    errors: list[str] = []
    warnings: list[str] = []

    tree = ET.parse(bundle)
    root = tree.getroot()

    ld_pous = [
        p for p in root.findall(".//pou:pou", NS)
        if p.get("name", "").endswith("_LD")
        and p.get("pouType") == "program"
    ]
    if not ld_pous:
        return ["Aucun POU `_LD` dans le bundle"], []

    for pou in ld_pous:
        pou_errors, pou_warnings = _check_pou(pou)
        errors.extend(pou_errors)
        warnings.extend(pou_warnings)

    return errors, warnings


def _check_pou(pou: ET.Element) -> tuple[list[str], list[str]]:
    """Invariants LD pour un POU `_LD`. Retourne (errors, warnings)."""
    pou_name = pou.get("name")
    errors: list[str] = []
    warnings: list[str] = []

    ld = pou.find("pou:body/pou:LD", NS)
    if ld is None:
        return [f"{pou_name}: sans corps LD"], []

    all_ids = {el.get("localId"): el for el in ld}
    declared = _local_vars(pou)

    def pref(msg: str) -> str:
        return f"{pou_name}: {msg}"

    # --- 1. localId du bloc < localId de ses sources ---
    # Oracle CODESYS : block=3, sources=4-10 (bloc PLUS PETIT que ses sources).
    # Le bug était block=10 avec sources=3-9 -> IndexOutOfRangeException.
    for block in ld.findall("pou:block", NS):
        block_id = int(block.get("localId"))
        connected: list[int] = []
        for cpi in block.findall(".//pou:inputVariables/pou:variable/pou:connectionPointIn", NS):
            conn = cpi.find("pou:connection", NS)
            if conn is not None and conn.get("refLocalId"):
                connected.append(int(conn.get("refLocalId")))
        for ref in connected:
            if ref <= block_id:
                errors.append(
                    pref(
                        f"block {block.get('typeName')} (localId={block_id}) a une source "
                        f"localId={ref} PLUS PETITE ou égale (doit être > lui) "
                        f"[REX: IndexOutOfRangeException]"
                    )
                )
                break

    # --- 2. Pas de coil doublon sur un output assigné dans le bloc ---
    assigned_in_block = set()
    for block in ld.findall("pou:block", NS):
        for var in block.findall("pou:outputVariables/pou:variable", NS):
            cpo = var.find("pou:connectionPointOut", NS)
            if cpo is not None:
                expr = cpo.find("pou:expression", NS)
                if expr is not None and (expr.text or "").strip():
                    assigned_in_block.add(var.get("formalParameter"))

    for coil in ld.findall("pou:coil", NS):
        conn = coil.find("pou:connectionPointIn/pou:connection", NS)
        if conn is not None and conn.get("formalParameter") in assigned_in_block:
            errors.append(
                pref(
                    f"coil {coil.find('pou:variable', NS).text} connecté à l'output "
                    f"{conn.get('formalParameter')} DÉJÀ assigné par expression dans le bloc "
                    f"[REX: ArgumentNullException à l'ouverture]"
                )
            )

    # --- 3. Variables des coils déclarées dans le POU ---
    for coil in ld.findall("pou:coil", NS):
        var = coil.find("pou:variable", NS)
        name = (var.text or "").strip() if var is not None else ""
        if not name:
            errors.append(pref(f"coil localId={coil.get('localId')} sans variable"))
        elif "." not in name and name not in declared:
            if name in KNOWN_DIRECT_HW_COIL_TARGETS:
                warnings.append(
                    pref(
                        f"coil variable '{name}' NON déclarée dans l'interface du POU — "
                        f"exception documentée (décision utilisateur 2026-08-06), NON "
                        f"VALIDÉE par un import CODESYS réel [REX: ArgumentNullException "
                        f"GetOperandDeclarationInfo si le crash déjà vécu se reproduit]"
                    )
                )
            else:
                errors.append(
                    pref(
                        f"coil variable '{name}' NON déclarée dans l'interface du POU "
                        f"[REX: ArgumentNullException GetOperandDeclarationInfo]"
                    )
                )

    # --- 4. Pas de motif inVariable -> outVariable ---
    out_vars = ld.findall("pou:outVariable", NS)
    if out_vars:
        errors.append(
            pref(
                f"{len(out_vars)} outVariable présent(s) dans le LD "
                f"[REX: IndexOutOfRangeException]"
            )
        )

    # --- 5. Pas de contact câblé sur une broche de sortie de bloc ---
    # REX 2026-08 (LOT_STRUCTURE_INTERLOCKS_LD, DOC/REX_PRG06_Import_Error.md cause #6) :
    # un <contact> connecte(refLocalId=<block>, formalParameter=<Output>) casse la
    # résolution d'opérande CODESYS («référence de l'objet non définie») dès que son
    # libellé <variable> n'est pas EXACTEMENT la référence source attendue. Règle :
    # une sortie de bloc s'assigne UNIQUEMENT par <expression> dans le bloc lui-même,
    # jamais via un contact externe pointé sur sa broche de sortie.
    for contact in ld.findall("pou:contact", NS):
        conn = contact.find("pou:connectionPointIn/pou:connection", NS)
        if conn is not None and conn.get("formalParameter") and conn.get("refLocalId") in all_ids:
            ref_el = all_ids.get(conn.get("refLocalId"))
            if ref_el is not None and _tag(ref_el) == "block":
                var = contact.find("pou:variable", NS)
                errors.append(
                    pref(
                        f"contact localId={contact.get('localId')} variable "
                        f"'{var.text if var is not None else '?'}' câblé sur la broche de "
                        f"sortie '{conn.get('formalParameter')}' du bloc localId={conn.get('refLocalId')} "
                        f"[REX: référence de l'objet non définie à l'import/ouverture, "
                        f"DOC/REX_PRG06_Import_Error.md cause #6 — assigner par <expression> "
                        f"dans le bloc, jamais via contact externe]"
                    )
                )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--bundle", help="chemin direct vers un bundle à vérifier")
    parser.add_argument("--report", action="store_true", help="sortie détaillée")
    args = parser.parse_args()

    if args.bundle:
        bundle = Path(args.bundle).resolve()
    else:
        root = Path(args.project_root).resolve()
        bundle = root / "CODE_XML" / "CODE_Bundle.xml"
    if not bundle.is_file():
        print(f"ERROR: {bundle} introuvable", file=sys.stderr)
        return 2

    errors, warnings = check_bundle(bundle, report=args.report)

    if args.report:
        print(f"=== Garde-fou LD (tous les POU `_LD`) ===")
        if errors:
            print(f"  [KO] {len(errors)} erreur(s) :")
            for e in errors:
                print(f"    - {e}")
        else:
            print("  [OK] 0 erreur")
        if warnings:
            print(f"  [!!] {len(warnings)} avertissement(s)")
            for w in warnings:
                print(f"    - {w}")

    if errors:
        print(f"FAIL: {len(errors)} invariant(s) LD violé(s)")
        return 1
    print("PASS: invariants LD OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
