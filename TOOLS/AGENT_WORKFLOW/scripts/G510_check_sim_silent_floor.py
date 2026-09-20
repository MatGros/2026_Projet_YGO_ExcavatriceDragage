#!/usr/bin/env python3
"""G510 — Butée silencieuse interdite sur un comptage brut de position (T338).

Classe de bug couverte (incident banc 2026-09-20) : le modèle codeur simulé
rappetissait son comptage brut jusqu'à un littéral (``RawPos := 0``) dans la branche
de descente. Un compteur non signé n'a aucune raison de s'arrêter là : la position
restait FIGÉE pour toujours en descente alors que la vitesse PLEINE continuait d'être
publiée — « position figée + vitesse non nulle + aucun défaut », qui a fini par
fabriquer une référence de homing aberrante (saut de 204,677 m après réarmement).

Règle : une variable de **comptage brut de position** (``*RawPos*``, ``*PosPts*``,
``*Odom*``) ne reçoit JAMAIS un littéral nu. Le comptage brut est un entier signé 32 bits
dont le zéro est arbitraire — le borner à un littéral est une butée muette.

Exception admise, et elle doit être VISIBLE dans le code :
  - une saturation explicitement signalée dans le même bloc (``<...>Saturated := TRUE``,
    ``<...>Overflow``, ``<...>OutOfRange``, ``<...>AtLimit``) ;
  - ou le marqueur de revue ``@floor-ok`` sur la ligne même (cas documenté hors modèle).

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G510_check_sim_silent_floor.py [racine]
  python TOOLS/AGENT_WORKFLOW/scripts/G510_check_sim_silent_floor.py --selftest
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Vocabulaire du comptage brut de position (narrow VOLONTAIREMENT : les compteurs
# d'evenements — AttemptCount, AlarmCount, BlipCount... — se remettent legitimement a 0).
COUNT_TOKENS = ("RawPos", "PosPts", "Odom")

ASSIGN = re.compile(r"^\s*([A-Za-z_]\w*)\s*:=\s*(.+?);\s*(?:\(\*.*?\*\))?\s*$")
LITERAL = re.compile(r"^-?\d+(?:\.\d+)?$")
SIGNAL = re.compile(r"\w*(?:Saturat|Overflow|OutOfRange|AtLimit)\w*\s*:=\s*TRUE", re.IGNORECASE)
ALLOW_MARKER = "@floor-ok"

# Fenetre de contexte (lignes de part et d'autre) ou chercher le signal de saturation.
WINDOW_BEFORE = 7
WINDOW_AFTER = 5


def scan_text(text: str) -> list[tuple[int, str, str]]:
    """Retourne les affectations litterales sur un comptage brut : (ligne, variable, valeur)."""
    lines = text.splitlines()
    assigns: list[tuple[int, str, str]] = []
    for num, line in enumerate(lines, 1):
        code = line.split("(*")[0].split("//")[0]
        match = ASSIGN.match(code)
        if match:
            assigns.append((num, match.group(1), match.group(2).strip()))

    counters: set[str] = set()
    for _, var, rhs in assigns:
        if re.search(rf"\b{re.escape(var)}\b", rhs) and re.search(r"[+\-]", rhs):
            counters.add(var)
    counters = {var for var in counters if any(token in var for token in COUNT_TOKENS)}

    findings: list[tuple[int, str, str]] = []
    for num, var, rhs in assigns:
        if var not in counters or not LITERAL.match(rhs):
            continue
        window = "\n".join(lines[max(0, num - 1 - WINDOW_BEFORE): num + WINDOW_AFTER])
        if SIGNAL.search(window) or ALLOW_MARKER in lines[num - 1]:
            continue
        findings.append((num, var, rhs))
    return findings


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    return scan_text(path.read_text(encoding="utf-8", errors="replace"))


def scan_repo(root: Path) -> list[str]:
    errors: list[str] = []
    for st in sorted((root / "CODE").rglob("*.st")):
        for num, var, rhs in scan_file(st):
            rel = st.relative_to(root).as_posix()
            errors.append(
                f"{rel}:{num}: butee silencieuse `{var} := {rhs}` — un comptage brut de position "
                f"ne se borne pas a un litteral (signaler la saturation, ou marquer {ALLOW_MARKER})"
            )
    return errors


SELFTEST_VIOLATION = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_IN_OUT
    RawPos : UDINT;
END_VAR
IF RelayRev THEN
    IF RawPos >= Increment THEN
        RawPos := RawPos - Increment;
    ELSE
        RawPos := 0;
    END_IF;
END_IF
END_FUNCTION_BLOCK
"""

SELFTEST_SIGNALLED = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_IN_OUT
    RawPos : UDINT;
END_VAR
IF RawPos >= Limit THEN
    RawPos := Limit;
    CountSaturated := TRUE;
END_IF
END_FUNCTION_BLOCK
"""

SELFTEST_ALLOWED_MARKER = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_IN_OUT
    RawPos : UDINT;
END_VAR
RawPos := 0; (* @floor-ok : remise a zero volontaire documentee *)
END_FUNCTION_BLOCK
"""


def selftest(root: Path) -> int:
    """Le detecteur doit voir la mutation, et ne pas crier sur les formes conformes."""
    failures: list[str] = []

    if not scan_text(SELFTEST_VIOLATION):
        failures.append("mutation NON detectee : `RawPos := 0` en butee non signalee")
    if scan_text(SELFTEST_SIGNALLED):
        failures.append("faux positif : saturation signalee (CountSaturated := TRUE) signalee a tort")
    if scan_text(SELFTEST_ALLOWED_MARKER):
        failures.append(f"faux positif : marqueur {ALLOW_MARKER} non respecte")

    # Preuve sur la mutation reelle de l'incident : le fichier corrige ne doit RIEN lever,
    # et la version d'avant correction doit lever exactement ce motif.
    real = root / "CODE" / "L_SIMULATION" / "FB_Sim_Encoder.st"
    if real.is_file():
        if scan_file(real):
            failures.append(f"{real.name} porte encore une butee silencieuse sur un comptage brut")
        legacy = real.read_text(encoding="utf-8", errors="replace")
        legacy = legacy.replace(
            "    RawPos := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(Increment));",
            "    IF RawPos >= Increment THEN\n        RawPos := RawPos - Increment;\n    ELSE\n        RawPos := 0;\n    END_IF;",
        )
        if not scan_text(legacy):
            failures.append("mutation du fichier REEL non detectee (motif d'incident re-injecte)")

    if failures:
        print("[G510] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("[G510] SELFTEST PASS — detecteur reactif a la mutation d'incident, sans faux positif")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette une mutation")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G510] FAIL — dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    errors = scan_repo(root)
    if errors:
        print("[G510] FAIL — butee silencieuse sur un comptage brut de position :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("[G510] PASS — aucun comptage brut de position borne a un litteral sans saturation signalee")
    return 0


if __name__ == "__main__":
    sys.exit(main())
