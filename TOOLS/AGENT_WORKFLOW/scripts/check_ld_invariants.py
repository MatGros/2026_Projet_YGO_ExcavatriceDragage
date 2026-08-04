#!/usr/bin/env python3
"""Garde-fou (REX 2026-08-04) : invariants LD du POU PRG_06_Outputs_LD.

Vérifie sur CODE_Bundle.xml les contraintes structurelles CODESYS découvertes
lors du débogage IndexOutOfRangeException / ArgumentNullException :

1. localId du bloc < localId de ses sources (inVariable/contact connectés)
2. Pas de coil doublon : un output assigné par expression DANS le bloc ne doit
   PAS avoir de coil externe (double assignement -> ArgumentNullException)
3. Les coils pointent vers des variables déclarées dans l'interface du POU
   (les sorties Device _DQ sont absentes du bundle -> crash à l'ouverture)
4. Pas de motif inVariable(expression) -> outVariable (IndexOutOfRange)

Usage:
    python check_ld_invariants.py [project_root] [--report]

Exemple:
    python check_ld_invariants.py . --report
"""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"pou": "http://www.plcopen.org/xml/tc6_0200"}
POU_NAME = "PRG_06_Outputs_LD"


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
    """Retourne (errors, warnings)."""
    errors: list[str] = []
    warnings: list[str] = []

    tree = ET.parse(bundle)
    root = tree.getroot()

    pou = next(
        (p for p in root.findall(".//pou:pou", NS) if p.get("name") == POU_NAME), None
    )
    if pou is None:
        return [f"POU {POU_NAME} introuvable dans le bundle"], []

    ld = pou.find("pou:body/pou:LD", NS)
    if ld is None:
        return [f"POU {POU_NAME} sans corps LD"], []

    all_ids = {el.get("localId"): el for el in ld}
    declared = _local_vars(pou)

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
                    f"block {block.get('typeName')} (localId={block_id}) a une source "
                    f"localId={ref} PLUS PETITE ou égale (doit être > lui) "
                    f"[REX: IndexOutOfRangeException]"
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
                f"coil {coil.find('pou:variable', NS).text} connecté à l'output "
                f"{conn.get('formalParameter')} DÉJÀ assigné par expression dans le bloc "
                f"[REX: ArgumentNullException à l'ouverture]"
            )

    # --- 3. Variables des coils déclarées dans le POU ---
    for coil in ld.findall("pou:coil", NS):
        var = coil.find("pou:variable", NS)
        name = (var.text or "").strip() if var is not None else ""
        if not name:
            errors.append(f"coil localId={coil.get('localId')} sans variable")
        elif "." not in name and name not in declared:
            errors.append(
                f"coil variable '{name}' NON déclarée dans l'interface du POU "
                f"[REX: ArgumentNullException GetOperandDeclarationInfo]"
            )

    # --- 4. Pas de motif inVariable -> outVariable ---
    out_vars = ld.findall("pou:outVariable", NS)
    if out_vars:
        errors.append(
            f"{len(out_vars)} outVariable présent(s) dans le LD "
            f"[REX: IndexOutOfRangeException]"
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
        bundle = root / "CODE" / "CODE_Bundle.xml"
    if not bundle.is_file():
        print(f"ERROR: {bundle} introuvable", file=sys.stderr)
        return 2

    errors, warnings = check_bundle(bundle, report=args.report)

    if args.report:
        print(f"=== Garde-fou LD ({POU_NAME}) ===")
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
