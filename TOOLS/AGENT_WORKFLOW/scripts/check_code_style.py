#!/usr/bin/env python3
"""Run lightweight, non-destructive checks on project ST sources."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FORBIDDEN = ("CoupeEnable", "FB_Watchdog")
DOC_REF = re.compile(r"DOC/[A-Za-z0-9_./-]+\.md")


def requires_doc_reference(path: Path) -> bool:
    normalized = path.as_posix()
    if "/SIMULATION/PLC_TESTS/" in normalized:
        return False
    if path.name.startswith(("FB_", "PRG_", "GVL_")):
        return True
    return any(f"/{folder}/" in normalized for folder in ("AU", "TRANSLATION", "TREUILS"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", nargs="?", default="CODE", help="ST file or directory")
    args = parser.parse_args()
    scope = Path(args.scope)
    files = [scope] if scope.is_file() else sorted(scope.rglob("*.st"))
    errors = 0
    warnings = 0

    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in FORBIDDEN:
            if token in text:
                print(f"[ERROR] {path}: forbidden token {token}", file=sys.stderr)
                errors += 1
        header = text[:4000]
        required = requires_doc_reference(path)
        if "DOC/" not in header:
            if required:
                print(f"[WARN] {path}: no DOC reference in header")
                warnings += 1
        for reference in DOC_REF.findall(header):
            if not Path(reference).is_file():
                level = "ERROR" if required else "WARN"
                print(f"[{level}] {path}: DOC reference not found: {reference}", file=sys.stderr if required else sys.stdout)
                if required:
                    errors += 1
                else:
                    warnings += 1

    print(f"Code style check: {'FAIL' if errors else 'PASS'} ({errors} error(s), {warnings} warning(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
