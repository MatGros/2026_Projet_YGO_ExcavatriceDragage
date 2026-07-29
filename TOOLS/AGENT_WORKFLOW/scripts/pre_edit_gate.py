#!/usr/bin/env python3
"""Pre-edit gate : verifie que les specs utiles ont ete lues avant de toucher CODE/.

REX 2026-07-29 — ce gate etait un no-op silencieux :
  * son `SPEC_MAP` listait des dossiers inexistants (`CODE/TREUILS/` existait,
    `CODE/MAIN/` — la ou le bug a eu lieu — n'y etait pas du tout) ;
  * il pointait des versions de specs supprimees (`_v1.12` quand `_v1.14` existait) ;
  * un chemin non couvert renvoyait `GATE PASS` au lieu d'alerter.

Corrections : dossiers reels, resolution **automatique** de la derniere version de
chaque spec (plus aucune version en dur a maintenir), et refus explicite d'un
chemin `CODE/` non couvert.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py --check CODE/MAIN/PRG_10_Outputs_LD.st
  python TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py --mark-read DOC/NAMING_CONVENTION.md ...
  python TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py --list
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STATE_FILE = ROOT / ".pi" / "spec_read_state.json"
DOC = ROOT / "DOC"

VERSIONED = re.compile(r"^AF_Partie-(?P<num>\d{2})_.+_v(?P<major>\d+)\.(?P<minor>\d+)\.md$")

# Specs exigees pour toute modification, quel que soit le dossier.
ALWAYS = ["DOC/CODE_QUALITY_STANDARDS.md", "DOC/NAMING_CONVENTION.md"]

# Dossier reel de CODE/ -> numeros de partie AF a avoir lus.
# La VERSION n'est jamais ecrite ici : elle est resolue au moment du controle.
SPEC_MAP: dict[str, list[int]] = {
    "CODE/AU/": [1, 3],
    "CODE/CODEURS/": [10, 3],
    "CODE/COMMUN/": [3, 6],
    "CODE/CYCLE/": [4],
    "CODE/DIAG/": [2],
    "CODE/JOYSTICK/": [8],
    "CODE/MAIN/": [2, 6],
    "CODE/MODES/": [5],
    "CODE/SIMULATION/": [13],
    "CODE/SUPERVISION/": [7],
    "CODE/TESTS/": [3],
    "CODE/TRANSLATION/": [11, 3],
    "CODE/TREUILS/": [9, 3, 12],
}


def latest_spec(partie: int) -> str | None:
    """Chemin de la version la plus recente de `AF_Partie-NN_*`."""
    best: tuple[tuple[int, int], str] | None = None
    for entry in DOC.glob("*.md"):
        match = VERSIONED.match(entry.name)
        if not match or int(match.group("num")) != partie:
            continue
        version = (int(match.group("major")), int(match.group("minor")))
        if best is None or version > best[0]:
            best = (version, f"DOC/{entry.name}")
    return best[1] if best else None


def load_state() -> dict:
    if STATE_FILE.is_file():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def required_specs(target: Path) -> tuple[list[str], bool]:
    """(specs requises, chemin couvert par la carte)."""
    normalized = target.as_posix().replace("\\", "/")
    if not normalized.startswith("CODE/"):
        return [], True

    required = list(ALWAYS)
    covered = False
    for prefix, parties in SPEC_MAP.items():
        if normalized.startswith(prefix):
            covered = True
            for partie in parties:
                spec = latest_spec(partie)
                if spec and spec not in required:
                    required.append(spec)
    return required, covered


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mark-read", nargs="+", help="Marquer des specs comme lues")
    parser.add_argument("--check", type=Path, help="Controler un fichier CODE/ cible")
    parser.add_argument("--list", action="store_true", help="Lister l'etat de lecture")
    parser.add_argument("--reset", action="store_true", help="Vider l'etat de lecture")
    args = parser.parse_args()

    if args.reset:
        save_state({})
        print("Etat de lecture vide.")
        return 0

    if args.mark_read:
        state = load_state()
        unknown = [s for s in args.mark_read if not (ROOT / s).is_file()]
        if unknown:
            for spec in unknown:
                print(f"[ERROR] spec introuvable, non marquee : {spec}", file=sys.stderr)
            return 1
        for spec in args.mark_read:
            state[spec] = True
        save_state(state)
        print(f"{len(args.mark_read)} spec(s) marquee(s) comme lue(s)")
        return 0

    if args.list:
        state = load_state()
        if not state:
            print("Aucune spec marquee comme lue.")
        for spec, read in sorted(state.items()):
            status = "OK " if read and (ROOT / spec).is_file() else "KO "
            suffix = "" if (ROOT / spec).is_file() else "  <- fichier absent (spec archivee ?)"
            print(f"  {status} {spec}{suffix}")
        return 0

    if args.check:
        required, covered = required_specs(args.check)
        if not covered:
            print(
                f"GATE FAIL: {args.check} — aucun dossier de SPEC_MAP ne couvre ce chemin.\n"
                f"Completer SPEC_MAP dans {Path(__file__).name} plutot que d'ignorer : "
                f"un chemin non couvert = un controle silencieusement absent.",
                file=sys.stderr,
            )
            return 1
        state = load_state()
        missing = [s for s in required if not state.get(s, False)]
        if not missing:
            print(f"GATE PASS: {args.check} — {len(required)} spec(s) requise(s) lue(s)")
            return 0
        print(f"GATE FAIL: {args.check} — specs non lues :", file=sys.stderr)
        for spec in missing:
            print(f"  KO  {spec}", file=sys.stderr)
        print(
            "\nLire ces documents, puis :\n"
            f"  python TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py --mark-read {' '.join(missing)}",
            file=sys.stderr,
        )
        return 1

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
