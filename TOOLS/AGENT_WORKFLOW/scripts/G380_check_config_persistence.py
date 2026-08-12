#!/usr/bin/env python3
"""Validate the config-persistence pattern established in the ConfigPersistence chantier.

4 checks (DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md §4):
1. Cfg <-> PERSISTENT mirror: every ST_*Cfg type must have a matching GVL_PERSISTENT
   variable of the exact same type (the FB_CfgPersistBridge_<Type> pattern).
2. Initialized guard: every ST_*Cfg struct, and every ST_Bypass* struct that carries
   a persisted `Global` bit (backed by GVL_BypassRetain), must declare `Initialized`.
   ST_BypassCommun is deliberately excluded: its 2 fields are recomputed every scan
   from simulation state (PRG_07_Supervision.st), never restored/saved, so it has no
   `Global` field and no GVL_BypassRetain counterpart -- Initialized would be meaningless.
3. No `= 0.0`-style sentinel guards in PRG_07_Supervision.st -- the whole chantier
   replaced this fragile pattern with a dedicated `Initialized` flag (see REX
   2026-07-23 in that file); a new sentinel would be a regression.
4. No obviously volatile/momentary signal persisted in GVL_PERSISTENT.st (state-machine
   step, deadman status, raw joystick reads, momentary buttons).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TYPES_DIR = Path("CODE/SUPERVISION/_TYPES")
PERSISTENT_FILE = Path("CODE/GVL_PERSISTENT.st")
SUPERVISION_FILE = Path("CODE/MAIN/PRG_07_Supervision.st")

TYPE_DECL_RE = re.compile(r"TYPE\s+(ST_\w+)\s*:", re.IGNORECASE)
STRUCT_BODY_RE = re.compile(r"STRUCT(.*?)END_STRUCT", re.DOTALL | re.IGNORECASE)
FIELD_NAME_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*:", re.MULTILINE)
PERSISTENT_VAR_RE = re.compile(r"^\s*(_\w+)\s*:\s*(ST_\w+)\b", re.MULTILINE)
PERSISTENT_ANY_VAR_RE = re.compile(r"^\s*(_\w+)\s*:\s*\w", re.MULTILINE)
# Deliberately keeps the THEN requirement (this flags the specific "IF ... = 0.0 THEN"
# init-sentinel anti-pattern, not every "= 0.0" comparison) but tolerates: extra trailing
# zeros (0.00), other conditions between the comparison and THEN (OR Enable THEN), and the
# comparison/THEN split across lines. Stops at ';' so it can't run past a statement boundary
# into unrelated code (an IF condition never contains a bare ';' before its own THEN).
SENTINEL_RE = re.compile(r"=\s*0\.0+\b[^;]{0,80}?\bTHEN\b", re.IGNORECASE | re.DOTALL)
BLOCK_COMMENT_RE = re.compile(r"\(\*.*?\*\)", re.DOTALL)
LINE_COMMENT_RE = re.compile(r"//.*$", re.MULTILINE)

# Check 4 - substrings that never belong in a PERSISTENT variable name (volatile /
# momentary signals recomputed every scan, not operator config to survive a reboot).
VOLATILE_NAME_MARKERS = ("CycleStep", "DeadmanArmed", "StartStop", "RawX", "RawY", "RawButton", "AxisCmd")


def read(path: Path) -> str:
    # utf-8-sig: harmlessly strips a BOM if present (CODESYS exports sometimes have one),
    # behaves exactly like utf-8 when absent.
    return path.read_text(encoding="utf-8-sig")


def strip_comments(source: str) -> str:
    """Blank out //... and (* ... *) comments, preserving line breaks (and therefore line
    numbers) so callers that report a line number stay accurate. Prevents both false
    positives (comment text that happens to look like code, e.g. a REX note quoting an old
    sentinel or a field name) and false negatives (a real field/pattern hidden inside a
    comment that should NOT count as present)."""

    def blank_block(m: re.Match[str]) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))

    source = BLOCK_COMMENT_RE.sub(blank_block, source)
    source = LINE_COMMENT_RE.sub("", source)
    return source


def struct_fields(source: str) -> set[str]:
    # crude but sufficient: field declarations are the "Name : Type" lines between
    # STRUCT and END_STRUCT, one per line, matching this project's formatting convention.
    # Case-folded: CODESYS/IEC 61131-3 keywords and identifiers are case-insensitive.
    body_match = STRUCT_BODY_RE.search(strip_comments(source))
    if not body_match:
        return set()
    return {m.group(1).lower() for m in FIELD_NAME_RE.finditer(body_match.group(1))}


def check_cfg_persistent_mirror(root: Path, errors: list[str]) -> None:
    persistent_source = strip_comments(read(root / PERSISTENT_FILE))
    declared_types = {m.group(2) for m in PERSISTENT_VAR_RE.finditer(persistent_source)}

    for cfg_file in sorted((root / TYPES_DIR).glob("ST_*Cfg.st")):
        type_match = TYPE_DECL_RE.search(strip_comments(read(cfg_file)))
        if not type_match:
            errors.append(f"{cfg_file.name}: no TYPE declaration found")
            continue
        type_name = type_match.group(1)
        if type_name not in declared_types:
            errors.append(
                f"{cfg_file.name}: no GVL_PERSISTENT variable of type {type_name} "
                f"(FB_CfgPersistBridge_{type_name.removeprefix('ST_')} needs a Persist mirror)"
            )


def check_initialized_guard(root: Path, errors: list[str]) -> None:
    for cfg_file in sorted((root / TYPES_DIR).glob("ST_*Cfg.st")):
        if "initialized" not in struct_fields(read(cfg_file)):
            errors.append(f"{cfg_file.name}: missing Initialized : BOOL field")

    for bypass_file in sorted((root / TYPES_DIR).glob("ST_Bypass*.st")):
        fields = struct_fields(read(bypass_file))
        if "global" not in fields:
            continue  # not GVL_BypassRetain-backed (e.g. ST_BypassCommun) - see module docstring
        if "initialized" not in fields:
            errors.append(f"{bypass_file.name}: has Global but no Initialized : BOOL field")


def check_no_sentinel(root: Path, errors: list[str]) -> None:
    # Whole-source search (not line-by-line) so a sentinel/THEN split across lines is still
    # caught; line number is derived from the match's start offset for accurate reporting.
    source = strip_comments(read(root / SUPERVISION_FILE))
    for m in SENTINEL_RE.finditer(source):
        lineno = source.count("\n", 0, m.start()) + 1
        errors.append(
            f"PRG_07_Supervision.st:{lineno}: obsolete '= 0.0 THEN' sentinel "
            "(use a dedicated Initialized flag instead)"
        )


def check_no_volatile_persisted(root: Path, errors: list[str]) -> None:
    persistent_source = strip_comments(read(root / PERSISTENT_FILE))
    for m in PERSISTENT_ANY_VAR_RE.finditer(persistent_source):
        var_name = m.group(1)
        for marker in VOLATILE_NAME_MARKERS:
            if marker in var_name:
                errors.append(f"GVL_PERSISTENT.st: {var_name} looks volatile/momentary (matches '{marker}')")
        if var_name.lstrip("_").startswith("Btn"):
            errors.append(f"GVL_PERSISTENT.st: {var_name} looks like a momentary command button")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    errors: list[str] = []

    check_cfg_persistent_mirror(root, errors)
    check_initialized_guard(root, errors)
    check_no_sentinel(root, errors)
    check_no_volatile_persisted(root, errors)

    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(f"Config persistence check: {'FAIL' if errors else 'PASS'} ({len(errors)} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
