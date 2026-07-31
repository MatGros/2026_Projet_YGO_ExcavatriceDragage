#!/usr/bin/env python3
"""st_to_dut.py — Convert ``.st`` file(s) (STRUCT or ENUM) to PLCopenXML.

With a single input file, generates a standalone ``<dataType>`` element — NOT
a full ``<project>`` bundle.

With multiple input files, generates a full ``<project>`` bundle containing
all the dataTypes assembled together (with ``<ProjectStructure>``, ObjectIds
aligned, and inter-object dependencies resolved).

Usage:
    python scripts/st_to_dut.py CODE/AU/ST_EmergencyState.st -o output.xml
    python scripts/st_to_dut.py CODE/CYCLE/E_CycleStep.st CODE/AU/ST_EmergencyState.st -o bundle.xml
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

from scripts._common import build_multi_file_project, parse_single_st_file  # noqa: E402

from generator.diagnostics import DiagnosticCollector, Severity  # noqa: E402
from generator.xml_builder import _build_enum_datatype, _build_struct_datatype  # noqa: E402
from generator.xml_serializer import serialize  # noqa: E402
from generator.guid import object_guid  # noqa: E402


def build_dut_xml(st_path: Path, diagnostics: DiagnosticCollector) -> bytes:
    obj = parse_single_st_file(st_path, diagnostics)
    if obj is None:
        raise ValueError(f"failed to parse {st_path}")
    if obj.kind == "struct":
        guid = object_guid(obj.kind, obj.name)
        element = _build_struct_datatype(obj, guid, {obj.name: obj}, diagnostics)
    elif obj.kind == "enum":
        guid = object_guid(obj.kind, obj.name)
        element = _build_enum_datatype(obj, guid, diagnostics)
    else:
        raise ValueError(
            f"{st_path.name}: not a STRUCT or ENUM — st_to_dut.py only "
            f"converts DUT files (TYPE ... STRUCT/ENUM). Got: {obj.kind} '{obj.name}'."
        )
    return serialize(element)


def build_dut_project_xml(
    st_paths: list[Path], diagnostics: DiagnosticCollector
) -> bytes:
    """Assemble a full ``<project>`` bundle from multiple STRUCT/ENUM ``.st`` files."""
    objects_by_name: dict[str, object] = {}
    root_names: list[str] = []
    for st_path in st_paths:
        obj = parse_single_st_file(st_path, diagnostics)
        if obj is None:
            raise ValueError(f"failed to parse {st_path}")
        if obj.kind not in ("struct", "enum"):
            raise ValueError(
                f"{st_path.name}: not a STRUCT or ENUM — st_to_dut.py only "
                f"converts DUT files (TYPE ... STRUCT/ENUM). Got: {obj.kind} '{obj.name}'."
            )
        objects_by_name[obj.name] = obj
        root_names.append(obj.name)
    return build_multi_file_project(objects_by_name, root_names, diagnostics)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="st_to_dut.py",
        description=(
            "Convert .st file(s) (STRUCT or ENUM) to PLCopenXML. Single file → "
            "standalone <dataType>; multiple files → full <project> bundle."
        ),
    )
    parser.add_argument(
        "st_files",
        nargs="+",
        type=Path,
        help="One or more source .st files (TYPE ... STRUCT/ENUM ... END_TYPE)",
    )
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .xml file")
    args = parser.parse_args(argv)

    st_paths: list[Path] = args.st_files
    out_path: Path = args.output

    for st_path in st_paths:
        if not st_path.is_file():
            print(f"error: input file not found: {st_path}", file=sys.stderr)
            return 1

    diagnostics = DiagnosticCollector()
    try:
        if len(st_paths) == 1:
            data = build_dut_xml(st_paths[0], diagnostics)
            label = "dataType"
        else:
            data = build_dut_project_xml(st_paths, diagnostics)
            label = f"DUT project bundle ({len(st_paths)} dataTypes)"
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(data)

    for diag in diagnostics:
        stream = sys.stdout if diag.severity is Severity.INFO else sys.stderr
        print(str(diag), file=stream)

    print(f"{label} written to {out_path}", file=sys.stderr)
    return 1 if diagnostics.has_errors() else 0


if __name__ == "__main__":
    raise SystemExit(main())