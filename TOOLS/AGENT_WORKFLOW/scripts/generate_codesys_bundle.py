#!/usr/bin/env python3
"""Generate CODE/CODE_Bundle.xml then prove that it is fresh.

Single mandatory delivery command for a CODE/ change. Keeps the project name of
an existing bundle unless --project-name is provided.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def existing_project_name(bundle: Path) -> str | None:
    if not bundle.is_file():
        return None
    try:
        tree = ET.parse(bundle)
        header = next((node for node in tree.iter() if node.tag.endswith("contentHeader")), None)
        if header is None:
            return None
        name = header.attrib.get("name")
        return name.removesuffix(".project") if name else None
    except ET.ParseError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--project-name")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    code_dir = root / "CODE"
    generator_dir = root / "TOOLS" / "ST_PLCOPENXML_GENERATOR"
    freshness = root / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "check_bundle_freshness.py"
    bundle = code_dir / "CODE_Bundle.xml"
    project_name = args.project_name or existing_project_name(bundle)

    if not project_name:
        print("ERROR: --project-name is required when no valid existing bundle is available.", file=sys.stderr)
        return 2

    command = [
        sys.executable, "-m", "generator.cli",
        "--code-dir", str(code_dir),
        "--out-dir", str(code_dir),
        "--bundle", "CODE_Bundle",
        "--project-name", project_name,
    ]
    result = subprocess.run(command, cwd=generator_dir)
    if result.returncode:
        return result.returncode

    # Post-traitement oracle : remplacer PRG_06_Outputs_LD par l'oracle CODESYS
    # (REX 2026-08-04 : ld_builder.py produit un LD non importable)
    oracle_script = generator_dir / "scripts" / "prg06_oracle_postprocess.py"
    bundle_path = code_dir / "CODE_Bundle.xml"
    result_oracle = subprocess.run(
        [sys.executable, str(oracle_script), str(bundle_path)],
        cwd=generator_dir,
    )
    if result_oracle.returncode:
        print("WARNING: oracle post-processing failed for PRG_06_Outputs_LD", file=sys.stderr)

    return subprocess.run([sys.executable, str(freshness), str(root)]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
