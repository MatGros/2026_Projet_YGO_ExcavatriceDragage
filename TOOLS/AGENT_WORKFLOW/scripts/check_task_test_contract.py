#!/usr/bin/env python3
"""Gate the test contract declared in a CODESYS task-context YAML file.

C3/C4 and safety tasks must declare automatic PLC-test artifacts. In --release
mode, those artifacts must be marked implemented and have execution evidence.
This intentionally reads only the small flat YAML contract used by this project.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def value(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*[\"']?([^\n\"']+)[\"']?\s*$", text, re.M)
    return match.group(1).strip() if match else ""


def listed(text: str, key: str) -> list[str]:
    match = re.search(rf"^{re.escape(key)}:\s*\n((?:^[ \t]+- .*\n?)*)", text, re.M)
    if not match:
        return []
    return [line.split("-", 1)[1].strip().strip('"') for line in match.group(1).splitlines() if "-" in line]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task_context", type=Path)
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    text = args.task_context.read_text(encoding="utf-8")
    criticality = value(text, "criticality")
    required = criticality in {"C3", "C4"} or value(text, "pony_tail") == "forbidden"
    automated = value(text, "tests_automated_required").lower() == "true"
    paths = listed(text, "tests_implementation_paths")
    status = value(text, "tests_status")
    evidence = listed(text, "test_execution_evidence")

    errors: list[str] = []
    if required and not automated:
        errors.append("tests_automated_required: true is mandatory for C3/C4 or safety.")
    if required and not paths:
        errors.append("tests_implementation_paths must name the PLC test artifact(s).")
    if args.release and required and status != "implemented":
        errors.append("tests_status must be implemented before release.")
    if args.release and required and not evidence:
        errors.append("test_execution_evidence must record the simulation/CODESYS result before release.")

    if errors:
        print(f"TEST CONTRACT FAIL: {args.task_context}", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    phase = "release" if args.release else "plan"
    print(f"TEST CONTRACT PASS ({phase}): {args.task_context}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
