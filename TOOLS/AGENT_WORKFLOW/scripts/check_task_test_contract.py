#!/usr/bin/env python3
"""Gate the test contract declared in a CODESYS task-context YAML file.

Automatic PLC-test artifacts are optional (decision 2026-08-01: the in-PLC test
overhead — RAM, resync cost — outweighs the benefit for most lots; C3/C4 safety
relies on human_validation_required + manual CODESYS verification before load).
If a task still declares tests_automated_required: true, this gate holds it to
its word: artifact paths must be named, and in --release mode the artifact must
be marked implemented with execution evidence.
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
    automated = value(text, "tests_automated_required").lower() == "true"
    paths = listed(text, "tests_implementation_paths")
    status = value(text, "tests_status")
    evidence = listed(text, "test_execution_evidence")

    errors: list[str] = []
    if automated and not paths:
        errors.append("tests_automated_required: true requires tests_implementation_paths to name the PLC test artifact(s).")
    if args.release and automated and status != "implemented":
        errors.append("tests_status must be implemented before release.")
    if args.release and automated and not evidence:
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
