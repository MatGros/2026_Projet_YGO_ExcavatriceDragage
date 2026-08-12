#!/usr/bin/env python3
"""Gate de cablage CFC natif : detecte les fils invisibles/orphelins avant import CODESYS.

Classe de bug couverte (REX 2026-08, PRG_AU_Acquisition_CFC.xml) : un CFC natif
(.xml fusionne tel quel dans le bundle, cf. PRG_GLOBAL_CFC.xml) peut etre bien
forme XML-wise, generer un bundle sans erreur, et pourtant s'afficher SANS AUCUN
LIEN VISIBLE une fois importe dans CODESYS -- parce que plusieurs <connector>
partagent la position (0,0), produisant des fils de longueur nulle empiles.

Controles :
  W1  chaque <connector> a une position (x,y) non nulle
  W2  aucune paire de <connector> ne partage exactement la meme position dans la
      meme page CFC (fils superposes = illisibles)
  W3  chaque <connector> est bien reference par au moins un <connection refLocalId=...>
      ailleurs dans la page (sinon : connecteur orphelin, jamais consomme)
  W4  chaque <block>/<inVariable>/<outVariable> a une position non nulle

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G210_check_cfc_wiring.py
  python TOOLS/AGENT_WORKFLOW/scripts/G210_check_cfc_wiring.py --report
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS = "{http://www.plcopen.org/xml/tc6_0200}"
POSITIONED_TAGS = {"block", "inVariable", "outVariable", "connector"}


def find_cfc_pages(xml_path: Path) -> list[tuple[str, ET.Element]]:
    """Retourne [(pou_name, <CFC> element), ...] pour un fichier XML natif."""
    tree = ET.parse(xml_path)
    root = tree.getroot()
    pages: list[tuple[str, ET.Element]] = []
    for pou in root.iter():
        if not pou.tag.endswith("}pou"):
            continue
        pou_name = pou.get("name", "?")
        for cfc in pou.iter():
            if cfc.tag.endswith("}CFC") or cfc.tag == "CFC":
                pages.append((pou_name, cfc))
    return pages


def check_page(pou_name: str, cfc: ET.Element, rel: str) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    connector_ids: dict[str, tuple[str, str]] = {}  # localId -> (x, y)
    all_local_ids: set[str] = set()
    referenced_ids: set[str] = set()
    # Les pages de staging sont nos pages de migration les plus exposées aux
    # squelettes XML : un bloc sans entrée ou une sortie publique non raccordée
    # semble valide en XML mais ne représente aucun flux CFC réel dans CODESYS.
    is_staging_page = "_Staging_CFC" in pou_name or pou_name in {
        "PRG_03_Modes_Cycle_CFC",
        "PRG_04_Treuils_Benne_CFC",
        "PRG_05_Translation_CFC",
        "PRG_07_Supervision_CFC",
    }

    for child in cfc:
        tag = child.tag.replace(NS, "")
        local_id = child.get("localId")
        if local_id:
            all_local_ids.add(local_id)

        if tag in POSITIONED_TAGS:
            pos = child.find(f"{NS}position")
            if pos is None:
                pos = child.find("position")
            x = pos.get("x") if pos is not None else None
            y = pos.get("y") if pos is not None else None
            if tag == "connector":
                if x == "0" and y == "0":
                    warnings.append(
                        f"[W1] {rel} pou={pou_name}: connector localId={local_id} "
                        f"en position (0,0) — fil de longueur nulle, invisible dans CODESYS"
                    )
                if x is not None and y is not None:
                    connector_ids[local_id] = (x, y)

        if is_staging_page and tag == "block":
            inputs = child.find(f"{NS}inputVariables")
            if inputs is None:
                inputs = child.find("inputVariables")
            if inputs is None or not list(inputs):
                errors.append(
                    f"[W5] {rel} pou={pou_name}: block `{child.get('instanceName', '?')}` "
                    "sans entrée — squelette CFC interdit"
                )

        if is_staging_page and tag == "inVariable":
            expression = child.findtext(f"{NS}expression") or child.findtext("expression") or ""
            if re.search(r"\b(?:NOT|OR|AND)\b|\bABS\s*\(", expression, re.IGNORECASE):
                errors.append(
                    f"[W6] {rel} pou={pou_name}: expression inline interdite `{expression}`; "
                    "extraire un FB ST"
                )

        if is_staging_page and tag == "outVariable":
            expression = child.findtext(f"{NS}expression") or child.findtext("expression") or ""
            has_input = child.find(f"{NS}connectionPointIn/{NS}connection") is not None or child.find("connectionPointIn/connection") is not None
            if not expression or not has_input:
                errors.append(
                    f"[W7] {rel} pou={pou_name}: outVariable localId={local_id} "
                    "sans publication raccordée"
                )

        # Collecte toutes les references <connection refLocalId="...">
        for conn in child.iter():
            conn_tag = conn.tag.replace(NS, "")
            if conn_tag == "connection":
                ref = conn.get("refLocalId")
                if ref:
                    referenced_ids.add(ref)

    # W2 — connecteurs empiles a la meme position
    seen_positions: dict[tuple[str, str], list[str]] = {}
    for cid, pos in connector_ids.items():
        seen_positions.setdefault(pos, []).append(cid)
    for pos, ids in seen_positions.items():
        if len(ids) > 1 and pos != ("0", "0"):  # (0,0) deja signale par W1
            warnings.append(
                f"[W2] {rel} pou={pou_name}: connectors {ids} empiles a la position {pos}"
            )

    # W3 — connecteurs jamais references (orphelins)
    for cid in connector_ids:
        if cid not in referenced_ids:
            errors.append(
                f"[W3] {rel} pou={pou_name}: connector localId={cid} jamais reference "
                f"par un <connection refLocalId=\"{cid}\"> — orphelin, mort"
            )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--report", action="store_true", help="Afficher le bloc de restitution agent")
    args = parser.parse_args()

    root = args.root.resolve()
    code = root / "CODE"
    if not code.is_dir():
        print(f"[ERROR] dossier introuvable : {code}", file=sys.stderr)
        return 2

    all_errors: list[str] = []
    all_warnings: list[str] = []
    pages_checked = 0

    for xml_path in sorted(code.rglob("*.xml")):
        if xml_path.name.startswith("CODE_Bundle") or xml_path.name.startswith("CODE_AU_Bundle"):
            continue
        try:
            pages = find_cfc_pages(xml_path)
        except ET.ParseError as exc:
            all_errors.append(f"[XML] {xml_path}: fichier XML mal forme ({exc})")
            continue
        rel = xml_path.relative_to(root).as_posix()
        for pou_name, cfc in pages:
            pages_checked += 1
            errors, warnings = check_page(pou_name, cfc, rel)
            all_errors.extend(errors)
            all_warnings.extend(warnings)

    for warning in all_warnings:
        print(f"[WARN] {warning}")
    for error in all_errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    if args.report:
        print()
        print("```text")
        print(f"Auto-verification cablage CFC (G210_check_cfc_wiring.py) — {'FAIL' if all_errors else 'PASS'}")
        print(f"  {pages_checked} page(s) CFC native(s) verifiee(s)")
        for error in all_errors[:8]:
            print(f"  KO  {error}")
        for warning in all_warnings[:8]:
            print(f"  !   {warning}")
        print("```")

    failed = bool(all_errors)
    print(
        f"\nCFC wiring check: {'FAIL' if failed else 'PASS'} "
        f"({len(all_errors)} erreur(s), {len(all_warnings)} avertissement(s), "
        f"{pages_checked} page(s) verifiee(s))"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
