#!/usr/bin/env python3
"""build_bundle.py — Orchestrate a full PLCopenXML ``<project>`` bundle.

Takes a list of paths (``.st`` files, ``.xml`` CFC files, and/or directories)
and produces a single ``<project>`` bundle via ``build_project_xml``.
Dependencies are resolved automatically by the existing dependency resolver.

Usage:
    python scripts/build_bundle.py CODE/AU/ CODE/M_MAIN/PRG_06_Outputs.st -o CODE_AU_Bundle.xml
    python scripts/build_bundle.py CODE/AU/FB_Safety_EmergencyManagement.st -o single.xml
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

from scripts._common import make_cfc_source_object, parse_single_st_file  # noqa: E402

from generator.diagnostics import DiagnosticCollector, Severity  # noqa: E402
from generator.file_discovery import discover_objects  # noqa: E402
from generator.xml_builder import build_project_xml  # noqa: E402
from generator.xml_serializer import write_file  # noqa: E402


def _collect_objects_from_args(
    paths: list[Path], diagnostics: DiagnosticCollector
) -> dict[str, object]:
    """Discover SourceObjects from a mix of files and directories.

    - A directory → ``discover_objects`` scans it recursively.
    - A ``.xml`` file → treated as a native CFC POU (raw_xml_path).
    - A ``.st`` file → parsed via ``parse_single_st_file``.

    Returns a name → SourceObject dict (deduplicated by name).
    """
    objects_by_name: dict[str, object] = {}

    for p in paths:
        if p.is_dir():
            dir_objects = discover_objects(p, diagnostics)
            for obj in dir_objects:
                objects_by_name[obj.name] = obj
        elif p.is_file():
            if p.suffix.lower() == ".xml":
                obj = make_cfc_source_object(p)
                objects_by_name[obj.name] = obj
            elif p.suffix.lower() == ".st":
                obj = parse_single_st_file(p, diagnostics)
                if obj is not None:
                    objects_by_name[obj.name] = obj
            else:
                diagnostics.warning(f"skipping unsupported file type: {p}", str(p))
        else:
            diagnostics.error(f"path not found: {p}", str(p))

    return objects_by_name


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="build_bundle.py",
        description="Orchestrate a full PLCopenXML <project> bundle from .st/.xml files and/or directories.",
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        type=Path,
        help="Source paths: directories, .st files, and/or .xml CFC files",
    )
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .xml bundle file")
    parser.add_argument(
        "--no-deps",
        action="store_true",
        help="Do not embed transitive type-dependency closure",
    )
    parser.add_argument(
        "--project-name",
        default="Generated",
        help="Value used for contentHeader/@name and ProjectInformation/property (default: %(default)s)",
    )
    parser.add_argument(
        "--timestamp",
        default=None,
        help="Override creationDateTime/modificationDateTime (default: derived from first object mtime)",
    )
    args = parser.parse_args(argv)

    diagnostics = DiagnosticCollector()
    objects_by_name = _collect_objects_from_args(args.inputs, diagnostics)

    if not objects_by_name:
        print("error: no objects discovered from the given inputs", file=sys.stderr)
        return 1

    root_names = sorted(objects_by_name.keys())

    root = build_project_xml(
        root_names,
        objects_by_name,
        diagnostics,
        include_deps=not args.no_deps,
        project_name=args.project_name,
        timestamp_override=args.timestamp,
        exclude_gvl_persistent=True,
    )

    write_file(root, args.output)

    for diag in diagnostics:
        stream = sys.stdout if diag.severity is Severity.INFO else sys.stderr
        print(str(diag), file=stream)

    warning_count = len(diagnostics.of(Severity.WARNING))
    error_count = len(diagnostics.of(Severity.ERROR))
    print(
        f"Bundle written to {args.output} — {len(root_names)} root object(s), "
        f"{warning_count} warning(s), {error_count} error(s).",
        file=sys.stderr,
    )

    return 1 if diagnostics.has_errors() else 0


if __name__ == "__main__":
    raise SystemExit(main())