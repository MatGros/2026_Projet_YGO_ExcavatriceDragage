#!/usr/bin/env python3
"""Post-compilation gate: verify CODESYS build log has zero errors.

This does NOT compile CODESYS (no headless API). It validates the compilation
log exported from CODESYS after a manual build.

Usage:
    python check_codesys_compile.py --log build.log
    python check_codesys_compile.py --log build.log --strict

Exit codes:
    0 = PASS (0 errors)
    1 = FAIL (errors found)
    2 = USAGE ERROR
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Pattern erreur CODESYS typique : "[ERREUR]" ou "Cxxxx:" ou "Error:" selon locale
ERROR_PATTERNS = [
    re.compile(r"\[ERREUR\]", re.IGNORECASE),
    re.compile(r"\[ERROR\]", re.IGNORECASE),
    re.compile(r"\bC\d{4}:\b"),           # C0037, C0013, etc.
    re.compile(r"\bErreur\b.*\d+", re.IGNORECASE),  # "Erreur ... 24"
    re.compile(r"\bError\b.*\d+", re.IGNORECASE),   # "Error ... 24"
]

WARNING_PATTERNS = [
    re.compile(r"\[AVERTISSEMENT\]", re.IGNORECASE),
    re.compile(r"\[WARNING\]", re.IGNORECASE),
    re.compile(r"\bWarning\b", re.IGNORECASE),
]


def analyze_log(log_path: Path, strict: bool = False) -> tuple[int, int, list[str]]:
    text = log_path.read_text(encoding="utf-8", errors="replace")
    errors = []
    warnings = []

    for line_num, line in enumerate(text.splitlines(), 1):
        for pat in ERROR_PATTERNS:
            if pat.search(line):
                errors.append(f"L{line_num}: {line.strip()}")
                break
        else:
            for pat in WARNING_PATTERNS:
                if pat.search(line):
                    warnings.append(f"L{line_num}: {line.strip()}")
                    break

    return len(errors), len(warnings), errors + warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True, help="CODESYS build log file")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    parser.add_argument("--max-warnings", type=int, default=0, help="Max warnings allowed (0 = unlimited unless --strict)")
    args = parser.parse_args()

    if not args.log.is_file():
        print(f"ERROR: log file not found: {args.log}", file=sys.stderr)
        return 2

    err_count, warn_count, findings = analyze_log(args.log, args.strict)

    if findings:
        from codesys_compilation_diag import parse_codesys_line, format_diagnostic_report
        parsed = [parse_codesys_line(f) for f in findings]
        parsed = [p for p in parsed if p is not None]
        print(format_diagnostic_report(parsed))

    print(f"\nErrors: {err_count}, Warnings: {warn_count}")

    if err_count > 0:
        print("GATE: FAIL — compilation errors present")
        return 1

    if args.strict and warn_count > 0:
        print("GATE: FAIL — strict mode, warnings treated as errors")
        return 1

    if args.max_warnings > 0 and warn_count > args.max_warnings:
        print(f"GATE: FAIL — warnings ({warn_count}) exceed limit ({args.max_warnings})")
        return 1

    print("GATE: PASS — compilation clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())