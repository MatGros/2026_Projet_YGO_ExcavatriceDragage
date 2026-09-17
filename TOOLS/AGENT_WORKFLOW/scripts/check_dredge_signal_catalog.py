"""Garde-fou : chaque déclaration I/O/parameter M3 possède une sémantique UI versionnée."""
from __future__ import annotations

from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "TOOLS/TWINBENCH/modelica_atelier/Dredge.mo"
CATALOG = ROOT / "TOOLS/TWINBENCH/modelica_atelier/contracts/dredge_signal_catalog.yaml"


def declarations(text: str):
    block = re.search(r"model TranslationM3Plant.*?end TranslationM3Plant;", text, re.S)
    if not block:
        raise ValueError("TranslationM3Plant introuvable")
    return {(direction, name) for direction, name in re.findall(
        r"^\s*(input|output|parameter)\s+Real\s+(\w+)", block.group(0), re.M)}


def main():
    declared = declarations(MODEL.read_text(encoding="utf-8"))
    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    items = {(row["direction"], row["name"]): row for row in catalog["signals"]}
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
