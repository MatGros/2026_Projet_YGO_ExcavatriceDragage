#!/usr/bin/env python3
"""Validate the project documentation and agent-workflow structure."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WORKFLOW_DIRS = {
    "docs",
    "templates",
    "skills",
    "prompts",
    "extensions",
    "scripts",
    "schemas",
    "config",
    "reports",
}

DOC_FILE_PATTERNS = (
    re.compile(r"^AF_Partie-\d{2}_.+_v\d+\.\d+\.md$"),
    re.compile(r"^PLAN_TASK_v\d+\.\d+\.md$"),
    re.compile(r"^VERSION_HISTORY\.md$"),
    re.compile(r"^AUDIT_.+_v\d+\.\d+\.md$"),
    re.compile(r"^CHECKLIST_.+_v\d+\.\d+\.md$"),
    re.compile(r"^NAMING_CONVENTION\.md$"),
    re.compile(r"^.+_Journal_Modifications\.md$"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[3],
        help="Project root (default: inferred from this script)",
    )
    return parser.parse_args()


def check_workflow(root: Path, errors: list[str], warnings: list[str]) -> None:
    workflow = root / "TOOLS" / "AGENT_WORKFLOW"
    if not workflow.is_dir():
        errors.append(f"missing directory: {workflow}")
        return

    for entry in workflow.iterdir():
        if entry.is_dir() and entry.name not in WORKFLOW_DIRS:
            errors.append(f"unexpected AGENT_WORKFLOW directory: {entry.name}")

    for skill_dir in (workflow / "skills").glob("*") if (workflow / "skills").is_dir() else []:
        if skill_dir.is_dir() and not (skill_dir / "SKILL.md").is_file():
            errors.append(f"skill missing SKILL.md: {skill_dir.relative_to(root)}")

    reports = workflow / "reports"
    if reports.is_dir() and any(reports.iterdir()):
        warnings.append("AGENT_WORKFLOW/reports contains generated files")


def check_doc(root: Path, errors: list[str], warnings: list[str]) -> None:
    doc = root / "DOC"
    if not doc.is_dir():
        errors.append(f"missing directory: {doc}")
        return

    for entry in doc.iterdir():
        if entry.is_dir():
            errors.append(f"unexpected DOC subdirectory: {entry.name}")
            continue
        if entry.suffix.lower() != ".md":
            errors.append(f"unexpected DOC file type: {entry.name}")
            continue
        if not any(pattern.match(entry.name) for pattern in DOC_FILE_PATTERNS):
            warnings.append(f"DOC filename not covered by standard: {entry.name}")


def main() -> int:
    args = parse_args()
    root = args.project_root.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    check_workflow(root, errors, warnings)
    check_doc(root, errors, warnings)

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(
        f"Structure check: {'FAIL' if errors else 'PASS'} "
        f"({len(errors)} error(s), {len(warnings)} warning(s))"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
