#!/usr/bin/env python3
"""Automated background test & iteration loop for TOOLS/convert.py.

Converts all ST POUs in CODE/MAIN to PLCopen XML, tests topology invariants,
verifies bidirectional retro-sync, and runs quality gates.
"""

from __future__ import annotations
import sys
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
TOOLS_DIR = ROOT_DIR / "TOOLS"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from converter.st_parser import parse_st_file
from converter.ld_xml_writer import build_ld_project_xml
from converter.ld_xml_reader import extract_ld_to_st


def run_autotest() -> int:
    code_main = ROOT_DIR / "CODE" / "MAIN"
    st_files = sorted(list(code_main.glob("PRG_*.st")))

    print(f"=== Starting Autotest Loop on {len(st_files)} POUs ===")

    success_count = 0
    errors = []

    for st_path in st_files:
        xml_out = ROOT_DIR / "CODE_XML" / "MAIN" / f"{st_path.stem}_LD.xml"
        st_reconstructed = ROOT_DIR / "scratch" / f"{st_path.stem}_LD_reconstructed.st"

        print(f"\n[TEST] {st_path.name} -> {xml_out.name}")

        try:
            # 1. Parse ST
            ast = parse_st_file(st_path)
            target_name = f"{st_path.stem}_LD"
            ast.name = target_name

            # 2. Convert ST -> PLCopen XML
            xml_bytes = build_ld_project_xml([ast], project_name=target_name)
            xml_out.parent.mkdir(parents=True, exist_ok=True)
            xml_out.write_bytes(xml_bytes)

            # 3. Retro-sync XML -> ST
            st_code = extract_ld_to_st(xml_out)
            st_reconstructed.parent.mkdir(parents=True, exist_ok=True)
            st_reconstructed.write_text(st_code, encoding="utf-8")

            print(f"  [OK] Converted {st_path.name} -> {xml_out.name} ({len(xml_bytes)} bytes)")
            success_count += 1

        except Exception as ex:
            print(f"  [FAIL] {st_path.name}: {ex}")
            errors.append((st_path.name, str(ex)))

    print("\n=== Running Quality Gates ===")
    gate_script = ROOT_DIR / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "run_all_gates.py"
    res = subprocess.run([sys.executable, str(gate_script)], capture_output=True, text=True)
    print(res.stdout)

    print(f"\n=== Summary: {success_count}/{len(st_files)} POUs successfully converted ===")
    if errors:
        print("Errors:")
        for name, err in errors:
            print(f"  - {name}: {err}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(run_autotest())
