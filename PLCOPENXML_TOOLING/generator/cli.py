from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .diagnostics import DiagnosticCollector, Severity
from .file_discovery import discover_objects
from .xml_builder import build_project_xml
from .xml_serializer import write_file

_TOOLING_DIR = Path(__file__).resolve().parent.parent
DEFAULT_CODE_DIR = _TOOLING_DIR.parent / "CODE"
DEFAULT_OUT_DIR = _TOOLING_DIR / "generated"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="st2plcopenxml",
        description=(
            "Deterministic ST -> PLCopenXML generator for CODESYS 3.5 SP19. "
            "Reads CODE/, writes one .xml per object into --out-dir, mirroring CODE/'s folder layout."
        ),
    )
    parser.add_argument(
        "objects",
        nargs="*",
        help="Object names to generate (default: every object discovered in CODE/)",
    )
    parser.add_argument(
        "--code-dir", type=Path, default=DEFAULT_CODE_DIR, help="Source CODE/ directory (default: %(default)s)"
    )
    parser.add_argument(
        "--out-dir", type=Path, default=DEFAULT_OUT_DIR, help="Output directory (default: %(default)s)"
    )
    parser.add_argument(
        "--no-deps",
        action="store_true",
        help="Do not embed each object's transitive type-dependency closure in the generated file",
    )
    parser.add_argument(
        "--bundle",
        metavar="FILENAME",
        default=None,
        help=(
            "Write every requested object (plus their combined dependency closure) into a "
            "single FILENAME.xml under --out-dir instead of one file per object"
        ),
    )
    parser.add_argument(
        "--timestamp",
        default=None,
        help="Override creationDateTime/modificationDateTime (default: derived from each object's .st mtime)",
    )
    parser.add_argument(
        "--project-name",
        default="Generated",
        help="Value used for contentHeader/@name and ProjectInformation/property (default: %(default)s)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    diagnostics = DiagnosticCollector()
    objects = discover_objects(args.code_dir, diagnostics)
    objects_by_name = {obj.name: obj for obj in objects}

    targets = args.objects if args.objects else sorted(objects_by_name)

    generated = 0
    if args.bundle:
        known_targets = []
        for name in targets:
            if name in objects_by_name:
                known_targets.append(name)
            else:
                diagnostics.error(f"unknown object requested: {name!r}", name)
        if known_targets:
            root = build_project_xml(
                known_targets,
                objects_by_name,
                diagnostics,
                include_deps=not args.no_deps,
                project_name=args.project_name,
                timestamp_override=args.timestamp,
            )
            bundle_name = args.bundle[:-4] if args.bundle.lower().endswith(".xml") else args.bundle
            out_path = args.out_dir / f"{bundle_name}.xml"
            write_file(root, out_path)
            generated = len(known_targets)
    else:
        for name in targets:
            obj = objects_by_name.get(name)
            if obj is None:
                diagnostics.error(f"unknown object requested: {name!r}", name)
                continue
            root = build_project_xml(
                name,
                objects_by_name,
                diagnostics,
                include_deps=not args.no_deps,
                project_name=args.project_name,
                timestamp_override=args.timestamp,
            )
            out_path = args.out_dir / obj.folder / f"{name}.xml"
            write_file(root, out_path)
            generated += 1

    for diagnostic in diagnostics:
        stream = sys.stdout if diagnostic.severity is Severity.INFO else sys.stderr
        print(str(diagnostic), file=stream)

    warning_count = len(diagnostics.of(Severity.WARNING))
    error_count = len(diagnostics.of(Severity.ERROR))
    print(
        f"Generated {generated}/{len(targets)} object(s) into {args.out_dir} "
        f"-- {warning_count} warning(s), {error_count} error(s).",
        file=sys.stderr,
    )

    return 1 if diagnostics.has_errors() else 0


if __name__ == "__main__":
    raise SystemExit(main())
