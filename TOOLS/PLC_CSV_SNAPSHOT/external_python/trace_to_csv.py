#!/usr/bin/env python3
"""Convert a CODESYS .trace export to a portable CSV.

CODESYS stores trace exports as XML (usually UTF-16) with one TraceVariable
containing a Values list and a matching Timestamps list. This utility keeps
the source trace untouched and writes either a long CSV (default) or a wide
CSV suitable for a spreadsheet.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class TraceVariable:
    name: str
    values: list[str]
    timestamps_ms: list[str]
    value_type: str


def _text(element: ET.Element | None) -> str:
    return (element.text or "").strip() if element is not None else ""


def _split_values(text: str) -> list[str]:
    return [item.strip() for item in text.split(",")] if text else []


def read_trace(path: Path) -> tuple[list[TraceVariable], dict[str, object]]:
    """Read a CODESYS trace XML export and validate every series."""
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        raise ValueError(f"XML CODESYS invalide: {exc}") from exc

    variables: list[TraceVariable] = []
    for record in root.findall(".//TraceRecord"):
        for node in record.findall("TraceVariable"):
            name = node.get("VarName") or _text(node.find("VariableName"))
            if not name:
                raise ValueError("TraceVariable sans VarName")
            values = _split_values(_text(node.find("Values")))
            timestamps = _split_values(_text(node.find("Timestamps")))
            if len(values) != len(timestamps):
                raise ValueError(
                    f"{name}: {len(values)} valeurs pour {len(timestamps)} horodatages"
                )
            variables.append(TraceVariable(name, values, timestamps, node.get("Type", "")))

    if not variables:
        raise ValueError("Aucune TraceVariable trouvee dans le fichier")
    metadata = {
        "source": str(path),
        "variable_count": len(variables),
        "sample_count": max((len(item.values) for item in variables), default=0),
        "variables": [
            {"name": item.name, "type": item.value_type, "samples": len(item.values)}
            for item in variables
        ],
    }
    return variables, metadata


def write_long(path: Path, variables: Iterable[TraceVariable]) -> int:
    rows = 0
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream, delimiter=";", lineterminator="\r\n")
        writer.writerow(("Timestamp_ms", "Variable", "Value"))
        for item in variables:
            for timestamp, value in zip(item.timestamps_ms, item.values):
                writer.writerow((timestamp, item.name, value))
                rows += 1
    return rows


def write_wide(path: Path, variables: list[TraceVariable]) -> int:
    timestamps: list[str] = []
    seen: set[str] = set()
    for item in variables:
        for timestamp in item.timestamps_ms:
            if timestamp not in seen:
                timestamps.append(timestamp)
                seen.add(timestamp)
    series = {item.name: dict(zip(item.timestamps_ms, item.values)) for item in variables}
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream, delimiter=";", lineterminator="\r\n")
        # Format temporel : une variable par colonne, un instant par ligne.
        writer.writerow(["Timestamp_ms", *[item.name for item in variables]])
        for timestamp in timestamps:
            writer.writerow([timestamp, *[series[item.name].get(timestamp, "") for item in variables]])
    return len(variables)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="Export CODESYS .trace a convertir")
    parser.add_argument("-o", "--output", type=Path, help="CSV de sortie (defaut: meme nom, .csv)")
    parser.add_argument("--format", choices=("long", "wide"), default="long", help="Format CSV (defaut: long)")
    parser.add_argument("--metadata", type=Path, help="Ecrit aussi les metadonnees au format JSON")
    parser.add_argument("--force", action="store_true", help="Autorise l'ecrasement des sorties existantes")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if not args.trace.is_file():
        print(f"Erreur: fichier introuvable: {args.trace}", file=sys.stderr)
        return 2
    output = args.output or args.trace.with_suffix(".csv")
    destinations = [output] + ([args.metadata] if args.metadata else [])
    if not args.force:
        existing = [path for path in destinations if path.exists()]
        if existing:
            print("Erreur: sortie deja existante (utiliser --force pour ecraser): " + ", ".join(map(str, existing)), file=sys.stderr)
            return 2
    try:
        variables, metadata = read_trace(args.trace)
        rows = write_long(output, variables) if args.format == "long" else write_wide(output, variables)
        if args.metadata:
            args.metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError) as exc:
        print(f"Erreur: {exc}", file=sys.stderr)
        return 1
    print(f"OK: {len(variables)} variables, {rows} lignes -> {output}")
    if args.metadata:
        print(f"OK: metadonnees -> {args.metadata}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
