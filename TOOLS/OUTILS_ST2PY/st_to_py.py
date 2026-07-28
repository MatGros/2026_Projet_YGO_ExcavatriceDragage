#!/usr/bin/env python3
"""Prototype sélectif ST/PLCopen -> Python

Usage:
  python st_to_py.py --bundle CODE/CODE_Bundle.xml --list
  python st_to_py.py --bundle CODE/CODE_Bundle.xml --pou PRG_07_TranslationControl --out out/

Notes:
- Optional dependency: plcopen (pip install plcopen)
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

try:
    # plcopen provides xsdata-generated classes for PLCopen XML
    from plcopen import XmlParser, XmlContext, Project
except Exception:
    XmlParser = None
    XmlContext = None
    Project = None


def list_pous(bundle_path: Path) -> list[str]:
    if XmlParser is None:
        print("plcopen not installed. Install with: pip install plcopen", file=sys.stderr)
        return []
    parser = XmlParser(context=XmlContext())
    with open(bundle_path, "rb") as f:
        proj = parser.from_bytes(f.read(), Project)
    types = getattr(proj, "types", None)
    pous = []
    if types and getattr(types, "pous", None):
        for pou in types.pous:
            pous.append(pou.name)
    return pous


def generate_skeleton(pou_name: str, out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    filename = out_dir / f"{pou_name}.py"
    class_name = pou_name.replace(".", "_")
    content = f"""# Auto-generated skeleton for {pou_name}

class {class_name}:
    def __init__(self):
        # TODO: populate inputs/outputs/internal vars
        self.inputs = dict()
        self.outputs = dict()
        self.internals = dict()

    def init(self):
        """Initialisation - called once"""
        pass

    def step(self):
        """Single step / scan of the POU - implement translated logic here"""
        # Example: self.outputs['Ready'] = self.inputs.get('Start', False)
        pass


def create_instance():
    return {class_name}()

"""
    filename.write_text(content, encoding="utf-8")
    return filename


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="st_to_py")
    parser.add_argument("--bundle", type=Path, default=Path("CODE/CODE_Bundle.xml"), help="PLCopen XML bundle")
    parser.add_argument("--list", action="store_true", help="List POU names in bundle")
    parser.add_argument("--pou", type=str, help="POU/FB name to generate")
    parser.add_argument("--out", type=Path, default=Path("out"), help="Output directory")
    args = parser.parse_args(argv)

    if not args.bundle.is_file():
        print(f"Bundle not found: {args.bundle}", file=sys.stderr)
        return 2

    if args.list:
        pous = list_pous(args.bundle)
        if not pous:
            print("No POUs found or plcopen missing")
            return 1
        for p in pous:
            print(p)
        return 0

    if args.pou:
        # For prototype we don't parse the POU body; we emit skeleton only
        out_file = generate_skeleton(args.pou, args.out)
        print(f"Generated: {out_file}")
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
