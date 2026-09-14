#!/usr/bin/env python3
"""Generate a partial PLCopenXML bundle containing only the given objects.

Companion script to generate_codesys_bundle.py (unchanged, still the mandatory
full-bundle delivery command). This script lets an agent export just the
POUs/GVL/DUT it touched in the current lot, for a faster CODESYS import while
iterating -- it never replaces the full bundle + G200_check_linkage.py
requirement before a lot is considered delivered.

Usage:
    python generate_codesys_diff_bundle.py . FB_SimBench GVL_Simulation PRG_02_Acquisition
    python generate_codesys_diff_bundle.py . CODE/L_SIMULATION/FB_SimBench.st CODE/L_SIMULATION/GVL_Simulation.st
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def object_name_from_arg(raw: str) -> str:
    """Accept a bare object name or a CODE/.../Name.st path; return the object name."""
    return Path(raw).stem


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
    parser.add_argument("project_root")
    parser.add_argument(
        "objects",
        nargs="+",
        help="Object names or .st file paths touched this lot (e.g. FB_SimBench GVL_Simulation PRG_02_Acquisition)",
    )
    parser.add_argument("--project-name")
    parser.add_argument(
        "--out-name",
        default=None,
        help="Diff bundle filename without extension (default: CODE_DiffBundle, overwritten each call)",
    )
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    code_dir = root / "CODE"
    out_dir = root / "CODE_XML"
    generator_dir = root / "TOOLS" / "CONVERTER_ST2XML_PLCopenXML"
    full_bundle = root / "CODE_XML" / "CODE_Bundle.xml"

    project_name = args.project_name or existing_project_name(full_bundle)
    if not project_name:
        print(
            "ERROR: --project-name is required when no valid existing full bundle is available.",
            file=sys.stderr,
        )
        return 2

    object_names = sorted({object_name_from_arg(o) for o in args.objects})
    bundle_name = args.out_name or "CODE_DiffBundle"

    command = [
        sys.executable, "-m", "generator.cli",
        *object_names,
        "--code-dir", str(code_dir),
        "--out-dir", str(out_dir),
        "--bundle", bundle_name,
        "--project-name", project_name,
    ]
    result = subprocess.run(command, cwd=generator_dir)
    if result.returncode:
        return result.returncode

    print("=" * 40)
    print(f"[OK] DIFF BUNDLE EXPORTE : CODE_XML/{bundle_name}.xml")
    print("=" * 40)
    print("Objets inclus (+ fermeture des dependances de type) :")
    for name in object_names:
        print(f"  - {name}")
    print(
        "Rappel : complement au bundle complet (generate_codesys_bundle.py), "
        "jamais un remplacement -- la livraison de lot reste soumise au bundle "
        "complet + G200_check_linkage.py --report."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
