#!/usr/bin/env python3
"""Validate the config-persistence pattern established in the ConfigPersistence chantier.

4 checks (DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md §4):
1. Cfg <-> PERSISTENT mirror: every ST_*Cfg type must have a matching GVL_PERSISTENT
   variable of the exact same type (the FB_CfgPersistBridge_<Type> pattern).
2. Initialized guard: every ST_*Cfg struct, and every ST_Bypass* struct that carries
   a persisted `Global` bit (backed by GVL_BypassRetain), must declare `Initialized`.
   ST_BypassCommun is deliberately excluded: its 2 fields are recomputed every scan
   from simulation state (PRG_09_Supervision.st), never restored/saved, so it has no
   `Global` field and no GVL_BypassRetain counterpart -- Initialized would be meaningless.
3. No `= 0.0`-style sentinel guards in PRG_09_Supervision.st -- the whole chantier
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
SUPERVISION_FILE = Path("CODE/MAIN/PRG_09_Supervision.st")

TYPE_DECL_RE = re.compile(r"TYPE\s+(ST_\w+)\s*:")
FIELD_NAME_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*:", re.MULTILINE)
PERSISTENT_VAR_RE = re.compile(r"^\s*(_\w+)\s*:\s*(ST_\w+)\b", re.MULTILINE)
PERSISTENT_ANY_VAR_RE = re.compile(r"^\s*(_\w+)\s*:\s*\w", re.MULTILINE)
SENTINEL_RE = re.compile(r"=\s*0\.0\s+THEN")

# Check 4 - substrings that never belong in a PERSISTENT variable name (volatile /
# momentary signals recomputed every scan, not operator config to survive a reboot).
VOLATILE_NAME_MARKERS = ("CycleStep", "DeadmanArmed", "StartStop", "RawX", "RawY", "RawButton", "AxisCmd")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def struct_fields(source: str) -> set[str]:
    # crude but sufficient: field declarations are the "Name : Type" lines between
    # STRUCT and END_STRUCT, one per line, matching this project's formatting convention.
    body_match = re.search(r"STRUCT(.*?)END_STRUCT", source, re.DOTALL)
    if not body_match:
        return set()
    return {m.group(1) for m in FIELD_NAME_RE.finditer(body_match.group(1))}


def check_cfg_persistent_mirror(root: Path, errors: list[str]) -> None:
    persistent_source = read(root / PERSISTENT_FILE)
    declared_types = {m.group(2) for m in PERSISTENT_VAR_RE.finditer(persistent_source)}

    for cfg_file in sorted((root / TYPES_DIR).glob("ST_*Cfg.st")):
        type_match = TYPE_DECL_RE.search(read(cfg_file))
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
        if "Initialized" not in struct_fields(read(cfg_file)):
            errors.append(f"{cfg_file.name}: missing Initialized : BOOL field")

    for bypass_file in sorted((root / TYPES_DIR).glob("ST_Bypass*.st")):
        fields = struct_fields(read(bypass_file))
        if "Global" not in fields:
            continue  # not GVL_BypassRetain-backed (e.g. ST_BypassCommun) - see module docstring
        if "Initialized" not in fields:
            errors.append(f"{bypass_file.name}: has Global but no Initialized : BOOL field")


def check_no_sentinel(root: Path, errors: list[str]) -> None:
    for lineno, line in enumerate(read(root / SUPERVISION_FILE).splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("(*"):
            continue
        if SENTINEL_RE.search(line):
            errors.append(
                f"PRG_09_Supervision.st:{lineno}: obsolete '= 0.0 THEN' sentinel "
                "(use a dedicated Initialized flag instead)"
            )


def check_no_volatile_persisted(root: Path, errors: list[str]) -> None:
    persistent_source = read(root / PERSISTENT_FILE)
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
