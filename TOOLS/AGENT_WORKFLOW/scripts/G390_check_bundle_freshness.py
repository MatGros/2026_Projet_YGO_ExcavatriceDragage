#!/usr/bin/env python3
"""Compare CODE_Bundle.xml with a deterministic regeneration in a temporary tree."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from uuid import uuid4


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    code_dir = root / "CODE"
    out_dir = root / "CODE_XML"
    bundle = out_dir / "CODE_Bundle.xml"
    generator_dir = root / "TOOLS" / "CONVERTER_ST2XML_PLCopenXML"
    if not code_dir.is_dir() or not bundle.is_file():
        print("ERROR: CODE/ or CODE_XML/CODE_Bundle.xml missing", file=sys.stderr)
        return 2

    tree = ET.parse(bundle)
    header = next((element for element in tree.iter() if element.tag.endswith("contentHeader")), None)
    if header is None:
        print("ERROR: bundle contentHeader missing", file=sys.stderr)
        return 2
    project_name = header.attrib.get("name", "Generated")
    if project_name.endswith(".project"):
        project_name = project_name[:-8]
    timestamp = header.attrib.get("creationDateTime") or header.attrib.get("modificationDateTime")
    if not timestamp:
        print("ERROR: bundle timestamp missing", file=sys.stderr)
        return 2

    # Scratch sous l'outillage, jamais a la racine et jamais supprime automatiquement.
    scratch = root / "TOOLS" / "AGENT_WORKFLOW" / ".tmp" / f"g390_freshness_{uuid4().hex[:12]}"
    scratch.mkdir(parents=True, exist_ok=True)
    print(f"INFO: scratch G390 conserve : {scratch.relative_to(root)}")
    try:
        temp_root = scratch
        temp_code = temp_root / "CODE"
        shutil.copytree(code_dir, temp_code, ignore=shutil.ignore_patterns("CODE_Bundle.xml"))
        command = [
            sys.executable,
            "-m",
            "generator.cli",
            "--code-dir",
            str(temp_code),
            "--out-dir",
            str(temp_code),
            "--bundle",
            "CODE_Bundle",
            "--project-name",
            project_name,
            "--timestamp",
            timestamp,
        ]
        result = subprocess.run(command, cwd=generator_dir, capture_output=True, text=True)
        if result.returncode:
            sys.stderr.write(result.stderr)
            return result.returncode
        generated = temp_code / "CODE_Bundle.xml"
        if not generated.is_file():
            print("ERROR: deterministic bundle was not generated", file=sys.stderr)
            return 2

        if generated.read_bytes() != bundle.read_bytes():
            print("FAIL: CODE_XML/CODE_Bundle.xml is stale")
            return 1
    finally:
        print(f"INFO: nettoyage manuel requis pour : {scratch.relative_to(root)}")

    print("PASS: CODE_XML/CODE_Bundle.xml is fresh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
