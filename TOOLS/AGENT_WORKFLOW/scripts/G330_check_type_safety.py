#!/usr/bin/env python3
"""Garde-fou statique de sécurité des types et vérification des membres de structures IEC 61131-3.

Détecte automatiquement avant compilation CODESYS :
  1. Accès à un membre inexistant d'une STRUCT (ex: GVL_IHM.Modes.State.ActiveMode au lieu de CurrentMode).
  2. Utilisation d'un opérateur booléen `NOT` sur une variable/champ non-booléen (ex: `NOT DeviceState`).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CODE_DIR = ROOT / "CODE"

def check_type_safety() -> list[str]:
    errors = []

    # 1. Collecter toutes les définitions de STRUCT dans CODE/
    struct_members: dict[str, set[str]] = {}
    
    struct_decl = re.compile(r"TYPE\s+(?P<name>ST_\w+)\s*:\s*\n?\s*STRUCT(?P<body>.*?)END_STRUCT", re.DOTALL)
    member_decl = re.compile(r"^\s*(?P<member>[A-Za-z_]\w*)\s*:", re.MULTILINE)

    for path in sorted(CODE_DIR.rglob("*.st")):
        text = path.read_text(encoding="utf-8")
        for match in struct_decl.finditer(text):
            struct_name = match.group("name")
            body = match.group("body")
            members = set(member_decl.findall(body))
            struct_members[struct_name] = members

    # 2. Vérifier les accès aux membres dans tous les fichiers .st
    gvl_modes_state_members = struct_members.get("ST_ModesState", set())

    for path in sorted(CODE_DIR.rglob("*.st")):
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        for idx, line in enumerate(lines, 1):
            line_clean = line.split("//")[0].split("(*")[0].strip()

            # Règle 1 : GVL_IHM.Modes.State.<Member> doit exister dans ST_ModesState
            modes_state_matches = re.finditer(r"\bGVL_IHM\.Modes\.State\.(?P<member>[A-Za-z_]\w*)", line_clean)
            for m in modes_state_matches:
                mem = m.group("member")
                if gvl_modes_state_members and mem not in gvl_modes_state_members:
                    errors.append(f"[TYPE] {path.relative_to(ROOT)}:{idx} Membre inexistant `{mem}` sur GVL_IHM.Modes.State (membres valides: {sorted(gvl_modes_state_members)})")

            # Règle 2 : NOT appliqué à un DeviceState (UINT/ENUM)
            if re.search(r"\bNOT\s+[\w\.]*DeviceState\b", line_clean):
                errors.append(f"[TYPE] {path.relative_to(ROOT)}:{idx} `NOT` ne peut pas être appliqué directement à un DeviceState (type ENUM/UINT). Utiliser `<> 8` ou `<> DEVICE_STATE.OPERATIONAL`.")

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
