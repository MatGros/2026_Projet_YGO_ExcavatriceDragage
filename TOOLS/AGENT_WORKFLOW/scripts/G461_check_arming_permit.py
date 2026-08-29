#!/usr/bin/env python3
"""Gate: refuser tout câblage d'ArmingPermit par un littéral dans CODE/*.st.

Standard : CODE_QUALITY_STANDARDS.md (déclaration, liaison, non-régression) + NC-100.
ArmingPermit = permission d'armement homme-mort (entrée FB_Joystick, consommée PRG_02).
Sa valeur doit TOUJOURS être câblée depuis une logique métier (ex. PRG_04_Treuils_Benne
§3bis : `ArmingPermit := NOT instBucket.Lifecycle.Busy AND NOT BenneBusyFallEdge.Q;`),
JAMAIS par un littéral TRUE/FALSE en dur dans un PROGRAM (PRG_*) ou une logique.

Seule tolérance : la déclaration d'initialisation `ArmingPermit : BOOL := TRUE` dans un
type d'interface (fichier ST_*, ex. champ défini dans ST_WinchInterPrg/Data). Toute autre
affectation littérale — y compris `:= FALSE` en déclaration — est une erreur.

Usage:
    python G460_check_arming_permit.py [project_root]

Exit codes:
    0 = PASS (aucun littéral ArmingPermit)
    1 = FAIL (un ou plusieurs littéraux ArmingPermit)
    2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Affectation littérale : `ArmingPermit := TRUE/FALSE` (sans type intermédiaire).
# Le `\b` évite de matcher `ArmingPermitDenied := ...`.
ASSIGN_RE = re.compile(r"\bArmingPermit\b\s*:=\s*(TRUE|FALSE)\b")

# Déclaration avec initialisation : `ArmingPermit : BOOL := TRUE/FALSE`.
DECL_RE = re.compile(r"\bArmingPermit\b\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*:=\s*(TRUE|FALSE)\b")

# Blocs VAR_INPUT ... END_VAR (pour localiser la tolérance de déclaration).
VAR_INPUT_RE = re.compile(r"\b(VAR_INPUT|END_VAR)\b")


def _var_input_regions(text: str) -> list[tuple[int, int]]:
    """Retourne les bornes (début, fin) des blocs VAR_INPUT ... END_VAR."""
    regions: list[tuple[int, int]] = []
    stack: list[int] = []
    for m in VAR_INPUT_RE.finditer(text):
        if m.group(1) == "VAR_INPUT":
            stack.append(m.start())
        elif stack:
            regions.append((stack.pop(), m.end()))
    return regions


def _in_region(pos: int, regions: list[tuple[int, int]]) -> bool:
    return any(start <= pos < end for start, end in regions)


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    violations: list[tuple[str, int, str]] = []  # (chemin, ligne, snippet)

    for st_file in sorted(code_dir.rglob("*.st")):
        try:
            text = st_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"ERROR: {st_file} n'est pas en UTF-8 lisible", file=sys.stderr)
            return 2
        rel = str(st_file.relative_to(root))
        is_interface_type = st_file.name.startswith("ST_")
        regions = _var_input_regions(text)

        # Déclarations avec initialisation : tolérées seulement si `:= TRUE` dans un
        # type d'interface (ST_*). `:= FALSE` en déclaration est toujours une erreur.
        for m in DECL_RE.finditer(text):
            value = m.group(1)
            if value == "TRUE" and is_interface_type:
                continue  # cas légitime : champ d'interface initialisé à TRUE
            line_no = text[: m.start()].count("\n") + 1
            violations.append((rel, line_no, m.group(0).strip()))

        # Affectations littérales : toujours une erreur (PRG_* ou logique).
        for m in ASSIGN_RE.finditer(text):
            line_no = text[: m.start()].count("\n") + 1
            violations.append((rel, line_no, m.group(0).strip()))

    if not violations:
        print("PASS : aucun câblage littéral d'ArmingPermit dans les sources .st.")
        return 0

    print(f"FAIL : {len(violations)} câblage(s) littéral(aux) d'ArmingPermit :")
    for path, line, snippet in violations:
        print(f"  - {path}:{line} -> {snippet}")
    print(
        "\nStandard : CODE_QUALITY_STANDARDS.md + NC-100 — ArmingPermit doit être câblé "
        "depuis une logique métier (ex. PRG_04_Treuils_Benne §3bis), jamais par un "
        "littéral TRUE/FALSE en dur. Seule tolérance : `ArmingPermit : BOOL := TRUE` en "
        "déclaration d'un type d'interface (ST_*)."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
