#!/usr/bin/env python3
"""st_to_ld.py — Convert one ``PRG_*_LD.st`` file to a standalone ``<pou>`` in ``<LD>``.

Generates a PLCopenXML file containing exactly one ``<pou>`` whose body is a
``<LD>`` (Ladder Diagram). The file is NOT a full ``<project>`` bundle — it is
the single POU element only, for inclusion or standalone inspection.

Usage:
    python scripts/st_to_ld.py CODE/MAIN/PRG_AU_Outputs_LD.st -o output.xml

Only ``PRG_*_LD`` programs are eligible — the ``_LD`` suffix is the contract
that marks the Ladder-readable boundary for PROGRAM objects.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Bootstrap sys.path so both ``generator`` and ``scripts`` packages are importable
# whether this file is run as a script or imported as a module.
_SCRIPTS_DIR = Path(__file__).resolve().parent
_TOOL_ROOT = _SCRIPTS_DIR.parent
if str(_TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOL_ROOT))

from scripts._common import parse_single_st_file  # noqa: E402

from generator.diagnostics import DiagnosticCollector, Severity  # noqa: E402
from generator.xml_builder import _build_pou  # noqa: E402
from generator.xml_serializer import serialize  # noqa: E402
from generator.guid import object_guid  # noqa: E402


def _is_ld_program(obj) -> bool:
    return (
        obj is not None
        and obj.kind == "program"
        and obj.name.startswith("PRG_")
        and obj.name.endswith("_LD")
    )


def build_ld_pou_xml(st_path: Path, diagnostics: DiagnosticCollector) -> bytes:
    obj = parse_single_st_file(st_path, diagnostics)
    if obj is None:
        raise ValueError(f"failed to parse {st_path}")
    if not _is_ld_program(obj):
        raise ValueError(
            f"{st_path.name}: not a PRG_*_LD program — st_to_ld.py only converts "
            f"PROGRAM objects named PRG_*_LD. Got: {obj.kind} '{obj.name}'."
        )

    guid = object_guid(obj.kind, obj.name)
    pou = _build_pou(obj, guid, {obj.name: obj}, diagnostics)
    return serialize(pou)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="st_to_ld.py",
        description="Convert one PRG_*_LD.st file to a standalone <pou> in <LD> (PLCopenXML).",
    )
    parser.add_argument("st_file", type=Path, help="Source .st file (must be PRG_*_LD)")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .xml file")
    args = parser.parse_args(argv)

    st_path: Path = args.st_file
    out_path: Path = args.output

    if not st_path.is_file():
        print(f"error: input file not found: {st_path}", file=sys.stderr)
        return 1

    diagnostics = DiagnosticCollector()
    try:
        data = build_ld_pou_xml(st_path, diagnostics)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(data)

    for diag in diagnostics:
        stream = sys.stdout if diag.severity is Severity.INFO else sys.stderr
        print(str(diag), file=stream)

    print(f"LD POU written to {out_path}", file=sys.stderr)
    return 1 if diagnostics.has_errors() else 0


if __name__ == "__main__":
    raise SystemExit(main())