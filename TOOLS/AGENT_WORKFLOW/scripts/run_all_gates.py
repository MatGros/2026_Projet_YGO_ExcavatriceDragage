#!/usr/bin/env python3
"""Unified gate runner: all checks must pass before any commit or release."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all project gates")
    parser.add_argument("--codesys-log", type=Path, help="Optional CODESYS build log to validate")
    parser.add_argument("--skip-codesys", action="store_true", help="Skip CODESYS log check")
    parser.add_argument("--strict", action="store_true", help="Fail on any warning")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[3]
    project_root = root

    print("=" * 60)
    print("GATE 1: Structure check")
    print("=" * 60)
    code, out, err = run([sys.executable, "TOOLS/AGENT_WORKFLOW/scripts/check_structure.py"], project_root)
    print(out.strip())
    if code:
        return code

    print("\n" + "=" * 60)
    print("GATE 2: Code style (incl. VAR_OUTPUT writes)")
    print("=" * 60)
    code, out, err = run([sys.executable, "TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py", "CODE"], project_root)
    print(out.strip())
    if err:
        print(err.strip(), file=sys.stderr)
    if code:
        return code

    print("\n" + "=" * 60)
    print("GATE 3: Config persistence (Cfg<->PERSISTENT mirror, Initialized guard, sentinels)")
    print("=" * 60)
    code, out, err = run([sys.executable, "TOOLS/AGENT_WORKFLOW/scripts/check_config_persistence.py", "."], project_root)
    print(out.strip())
    if err:
        print(err.strip(), file=sys.stderr)
    if code:
        return code

    print("\n" + "=" * 60)
    print("GATE 4: Bundle freshness")
    print("=" * 60)
    code, out, err = run([sys.executable, "TOOLS/AGENT_WORKFLOW/scripts/check_bundle_freshness.py", "."], project_root)
    print(out.strip())
    if code:
        return code

    print("\n" + "=" * 60)
    print("GATE 5: PyTest (generator tests)")
    print("=" * 60)
    # Use Python 3.13 where pytest is installed
    py313 = Path("C:/Python313/python.exe")
    if not py313.exists():
        print("WARNING: Python 3.13 not found at C:/Python313/python.exe, using current interpreter", file=sys.stderr)
        py313 = Path(sys.executable)
    code, out, err = run([str(py313), "-m", "pytest", "TOOLS/ST_PLCOPENXML_GENERATOR/tests", "-q"], project_root)
    print(out.strip())
    if err:
        print(err.strip(), file=sys.stderr)
    if code:
        return code

    if not args.skip_codesys and args.codesys_log:
        print("\n" + "=" * 60)
        print("GATE 6: CODESYS compilation")
        print("=" * 60)
        code, out, err = run([
            sys.executable,
            "TOOLS/AGENT_WORKFLOW/scripts/check_codesys_compile.py",
            "--log", str(args.codesys_log),
            "--strict" if args.strict else "",
            "--max-warnings", "0" if args.strict else "10"
        ], project_root)
        print(out.strip())
        if err:
            print(err.strip(), file=sys.stderr)
        if code:
            return code

    print("\n" + "=" * 60)
    print("ALL GATES PASSED [OK]")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())