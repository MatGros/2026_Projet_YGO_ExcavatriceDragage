"""Garde-fou : chaque champ public groupé M3 possède une sémantique UI versionnée."""
from __future__ import annotations

from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "TOOLS/TWINBENCH/modelica_atelier/Dredge.mo"
CATALOG = ROOT / "DOC/WFLOW/CONTRACTS/T314_DREDGE_SIGNAL_CATALOG.yaml"


def declarations(text: str):
    block = re.search(r"model TranslationM3Plant.*?end TranslationM3Plant;", text, re.S)
    if not block:
        raise ValueError("TranslationM3Plant introuvable")
    public_groups = re.findall(
        r"^\s*(input|output|parameter)\s+(M3\w+)\s+(\w+)", block.group(0), re.M)
    declared = set()
    for direction, record_type, group_name in public_groups:
        record = re.search(
            rf"record\s+{re.escape(record_type)}\b.*?end\s+{re.escape(record_type)};",
            text,
            re.S,
        )
        if not record:
            raise ValueError(f"Record public {record_type} introuvable")
        for data_type, field_name in re.findall(
            r"^\s*(Boolean|Integer|Real)\s+(\w+)", record.group(0), re.M
        ):
            declared.add((direction, f"{group_name}.{field_name}", data_type))
    return declared


def main():
    declared = declarations(MODEL.read_text(encoding="utf-8"))
    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    items = {(row["direction"], row["name"], row["data_type"]): row for row in catalog["signals"]}
    missing = sorted(declared - set(items))
    stale = sorted(set(items) - declared)
    profiles = catalog.get("role_profiles", {})
    invalid = []
    for key, row in items.items():
        profile = profiles.get(row.get("role"), {})
        if (row.get("role") not in catalog["roles"] or not row.get("unit") or not row.get("label")
                or not (row.get("kind") or profile.get("kind"))
                or not (row.get("access") or profile.get("access"))
                or not (row.get("authority") or profile.get("authority"))):
            invalid.append(key)
    if missing or stale or invalid:
        print(f"FAIL missing={missing} stale={stale} invalid={invalid}")
        raise SystemExit(1)
    print(f"PASS: {len(declared)} signaux M3 classés causalité + flux + nature + autorité.")


if __name__ == "__main__":
    main()
