#!/usr/bin/env python3
"""Unified OOP Converter CLI for CODESYS PLCopen XML & Structured Text (ST).

Usage:
    python TOOLS/convert.py st2xml CODE/MAIN/PRG_02_Acquisition.st -o CODE_XML/MAIN/PRG_02_Acquisition_LD.xml
    python TOOLS/convert.py xml2st CODE_XML/MAIN/PRG_06_Outputs.xml -o CODE/MAIN/PRG_06_Outputs.st
    python TOOLS/convert.py bundle . -o CODE/CODE_Bundle.xml
"""

from __future__ import annotations
import argparse
import sys
from pathlib import Path

# Path bootstrap
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from converter.st_parser import parse_st_file
from converter.ld_xml_writer import build_ld_project_xml
from converter.ld_xml_reader import extract_ld_to_st


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="convert.py",
        description="Unified OOP Converter CLI for IEC 61131-3 ST and PLCopen XML Ladder (LD).",
    )
    subparsers = parser.add_subparsers(dest="command", required=True, help="Command verb")

    # st2xml
    p_st2xml = subparsers.add_parser("st2xml", help="Convert Structured Text (.st) to PLCopen XML Ladder (.xml)")
    p_st2xml.add_argument("input", type=Path, help="Input .st file")
    p_st2xml.add_argument("-o", "--output", type=Path, required=True, help="Output .xml file")
    p_st2xml.add_argument("--name", type=str, help="Override POU name in XML")

    # xml2st
    p_xml2st = subparsers.add_parser("xml2st", help="Extract Structured Text (.st) from PLCopen XML Ladder (.xml)")
    p_xml2st.add_argument("input", type=Path, help="Input .xml file")
    p_xml2st.add_argument("-o", "--output", type=Path, required=True, help="Output .st file")

    # bundle
    p_bundle = subparsers.add_parser("bundle", help="Build global CODE_Bundle.xml for CODESYS import")
    p_bundle.add_argument("project_dir", type=Path, default=Path("."), nargs="?", help="Project root directory")
    p_bundle.add_argument("-o", "--output", type=Path, default=Path("CODE/CODE_Bundle.xml"), help="Output bundle XML file")

    args = parser.parse_args(argv)

    if args.command == "st2xml":
        if not args.input.is_file():
            print(f"Error: input file not found: {args.input}", file=sys.stderr)
            return 1

        ast = parse_st_file(args.input)
        if args.name:
            ast.name = args.name
        elif args.output.stem.endswith("_LD") and not ast.name.endswith("_LD"):
            ast.name = args.output.stem

        xml_bytes = build_ld_project_xml([ast], project_name=ast.name)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(xml_bytes)
        print(f"[OK] Successful conversion: {args.input} -> {args.output} (POU: {ast.name})")
        if ast.unsupported_statements:
            print(
                f"[WARNING] {len(ast.unsupported_statements)} statement(s) NOT translated "
                f"(IF/CASE unsupported) -- silently dropped from the LD output, not an error "
                f"but a real content gap:",
                file=sys.stderr,
            )
            for stmt in ast.unsupported_statements:
                preview = stmt[:120] + ("..." if len(stmt) > 120 else "")
                print(f"    - {preview}", file=sys.stderr)
        return 0

    elif args.command == "xml2st":
        if not args.input.is_file():
            print(f"Error: input file not found: {args.input}", file=sys.stderr)
            return 1

        st_code = extract_ld_to_st(args.input)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(st_code, encoding="utf-8")
        print(f"[OK] Successful extraction: {args.input} -> {args.output}")
        return 0

    elif args.command == "bundle":
        # Run bundle generator script
        import subprocess
        bundle_script = ROOT_DIR / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "generate_codesys_bundle.py"
        cmd = [sys.executable, str(bundle_script), str(args.project_dir)]
        res = subprocess.run(cmd)
        return res.returncode

    return 0


if __name__ == "__main__":
    sys.exit(main())
