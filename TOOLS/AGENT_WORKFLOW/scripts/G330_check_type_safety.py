#!/usr/bin/env python3
"""Garde-fou statique de sécurité des types et vérification des membres de structures IEC 61131-3.

Détecte automatiquement avant compilation CODESYS :
  1. Accès à un membre inexistant d'une STRUCT (ex: GVL_IHM.Modes.State.ActiveMode au lieu de CurrentMode,
     ou WinchM2.Bucket.State.InexistentField).
  2. Utilisation d'un opérateur booléen `NOT` sur une variable/champ non-booléen (ex: `NOT DeviceState`).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = ROOT / "CODE"


def check_type_safety() -> list[str]:
    errors = []

    # 1. Collecter toutes les définitions de STRUCT dans CODE/ avec les types de leurs champs
    struct_members: dict[str, dict[str, str]] = {}

    struct_decl = re.compile(r"TYPE\s+(?P<name>ST_\w+)\s*:\s*\n?\s*STRUCT(?P<body>.*?)END_STRUCT", re.DOTALL)
    field_decl = re.compile(r"^\s*(?P<member>[A-Za-z_]\w*)\s*:\s*(?P<type>[A-Za-z_]\w*)", re.MULTILINE)

    for path in sorted(CODE_DIR.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in struct_decl.finditer(text):
            struct_name = match.group("name")
            body = match.group("body")
            fields: dict[str, str] = {}
            for fmatch in field_decl.finditer(body):
                mem = fmatch.group("member")
                typ = fmatch.group("type")
                fields[mem] = typ
            struct_members[struct_name] = fields

    # 2. Collecter les variables GVLs / VAR_INPUT / VAR_OUTPUT / VAR locales et leurs types
    var_decl = re.compile(r"^\s*(?P<var>[A-Za-z_]\w*)\s*:\s*(?P<type>[A-Za-z_]\w*)", re.MULTILINE)
    gvl_vars: dict[str, dict[str, str]] = {}

    for path in sorted(CODE_DIR.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if path.stem.startswith("GVL_"):
            gvl_name = path.stem
            fields: dict[str, str] = {}
            for match in var_decl.finditer(text):
                vname = match.group("var")
                vtype = match.group("type")
                if vname not in ("VAR", "VAR_GLOBAL", "END_VAR", "TYPE", "STRUCT", "END_STRUCT"):
                    fields[vname] = vtype
            gvl_vars[gvl_name] = fields

    # 3. Fonction de résolution récursive du type d'une chaîne (ex: GVL_IHM.M2TreuilBenne.Bucket.State.DeltaPosition_M)
    def resolve_chain_type(root_type: str, parts: list[str]) -> tuple[bool, str, str]:
        """Retourne (is_valid, current_type, error_msg)."""
        curr_type = root_type
        for idx, part in enumerate(parts):
            fields = struct_members.get(curr_type)
            if not fields:
                # Si le type courant n'est pas une ST_* connue (ex: REAL, BOOL, INT), on ne peut pas descendre plus loin
                return False, curr_type, f"Type `{curr_type}` n'est pas une STRUCT connue pour accéder au membre `{part}`"
            if part not in fields:
                valid_members = sorted(fields.keys())
                return False, curr_type, f"Membre `{part}` inexistant dans `{curr_type}` (membres valides: {valid_members})"
            curr_type = fields[part]
        return True, curr_type, ""

    # 4. Parcourir tous les fichiers .st pour valider les chaînes d'accès (ex: GVL_IHM.xxx.yyy.zzz ou WinchM2.Bucket.State.xxx)
    chain_pattern = re.compile(r"\b(?P<root>GVL_\w+|ST_\w+|WinchM2|WinchM1|DredgingAssist|instBucket|instWinchM1|instWinchM2)\.(?P<chain>[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+)\b")

    # Mappages connus des racines d'instances vers leur type STRUCT
    root_types: dict[str, str] = {
        "WinchM2": "ST_WinchBenneHMI",
        "WinchM1": "ST_WinchHMI",
        "DredgingAssist": "ST_DredgingAssistHMI",
        "instBucket": "FB_Bucket",
    }

    for path in sorted(CODE_DIR.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        for idx, line in enumerate(lines, 1):
            line_clean = line.split("//")[0].split("(*")[0].strip()

            # Validation des chaînes d'accès membres sur GVL et instances
            for match in chain_pattern.finditer(line_clean):
                root_name = match.group("root")
                chain_str = match.group("chain")
                parts = chain_str.split(".")

                root_struct_type = None
                if root_name.startswith("GVL_"):
                    gvl_fields = gvl_vars.get(root_name, {})
                    first_part = parts[0]
                    if first_part in gvl_fields:
                        root_struct_type = gvl_fields[first_part]
                        parts = parts[1:]
                elif root_name in root_types:
                    root_struct_type = root_types[root_name]

                if root_struct_type and parts:
                    ok, _type_found, err_detail = resolve_chain_type(root_struct_type, parts)
                    if not ok:
                        errors.append(f"[TYPE] {path.relative_to(ROOT)}:{idx} {err_detail} via `{match.group(0)}`")

            # Règle 2 : NOT appliqué à un DeviceState (UINT/ENUM)
            if re.search(r"\bNOT\s+[\w\.]*DeviceState\b", line_clean):
                errors.append(
                    f"[TYPE] {path.relative_to(ROOT)}:{idx} `NOT` ne peut pas être appliqué directement à un DeviceState (type ENUM/UINT). Utiliser `<> 8` ou `<> DEVICE_STATE.OPERATIONAL`."
                )

    return errors


def main() -> int:
    errors = check_type_safety()
    if errors:
        print("Type safety check: FAIL", file=sys.stderr)
        for err in errors:
            print(f"  [ERROR] {err}", file=sys.stderr)
        return 1
    print("Type safety check: PASS (0 erreur)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
