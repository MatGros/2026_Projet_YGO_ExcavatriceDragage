#!/usr/bin/env python3
"""Pre-edit gate: verify relevant DOC specs have been read before CODE/ modification."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SPEC_MAP = {
    "CODE/AU/": ["DOC/AF_Partie-03_Template_FB_Commun_v1.3.md", "DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md"],
    "CODE/TRANSLATION/": ["DOC/AF_Partie-11_Fonction_Translation_v1.11.md", "DOC/AF_Partie-03_Template_FB_Commun_v1.3.md"],
    "CODE/TREUILS/": ["DOC/AF_Partie-09_Fonction_Winch_v1.11.md", "DOC/AF_Partie-03_Template_FB_Commun_v1.3.md"],
    "CODE/CODEURS/": ["DOC/AF_Partie-10_Fonction_Encoder_Homing_v1.10.md"],
    "CODE/BENNE/": ["DOC/AF_Partie-12_Fonction_Benne_v1.4.md"],
    "CODE/CYCLE/": ["DOC/AF_Partie-04_Cycle_Sequenceur_v1.4.md"],
    "CODE/MODES/": ["DOC/AF_Partie-05_Modes_Maintenance_v1.6.md"],
    "CODE/DIAG/": ["DOC/AF_Partie-02_Architecture_Programme_v2.12.md"],
    "CODE/JOYSTICK/": ["DOC/AF_Partie-08_Fonction_Joystick_v1.3.md"],
    "CODE/SIMULATION/": ["DOC/AF_Partie-13_Fonction_Simulation_v1.2.md", "DOC/AF_Partie-14_PLC_Tests_Validation_v1.2.md"],
    "CODE/COMMUN/": ["DOC/AF_Partie-03_Template_FB_Commun_v1.3.md", "DOC/AF_Partie-06_IO_Conditioning_v1.6.md"],
    "CODE/SUPERVISION/": ["DOC/AF_Partie-07_Interface_IHM_v1.4.md"],
}

STATE_FILE = Path(".pi/spec_read_state.json")


def load_state() -> dict:
    if STATE_FILE.is_file():
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    return {}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def mark_read(spec_path: str) -> None:
    state = load_state()
    state[spec_path] = True
    save_state(state)


def check_specs_for_file(target_path: Path) -> tuple[bool, list[str]]:
    """Return (ok, missing_specs) for a target CODE/ file."""
    target_str = target_path.as_posix()
    required = []
    for prefix, specs in SPEC_MAP.items():
        if target_str.startswith(prefix):
            required.extend(specs)
    if not required:
        return True, []
    state = load_state()
    missing = [s for s in required if not state.get(s, False)]
    return len(missing) == 0, missing


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Pre-edit gate for CODE/ modifications")
    parser.add_argument("--mark-read", nargs="+", help="Mark specs as read")
    parser.add_argument("--check", type=Path, help="Check specs for a target file")
    parser.add_argument("--list", action="store_true", help="List all tracked specs")
    args = parser.parse_args()

    if args.mark_read:
        for s in args.mark_read:
            mark_read(s)
        print(f"Marked {len(args.mark_read)} spec(s) as read")
        return 0

    if args.list:
        state = load_state()
        for spec, read in state.items():
            status = "✅" if read else "❌"
            print(f"  {status} {spec}")
        return 0

    if args.check:
        ok, missing = check_specs_for_file(args.check)
        if ok:
            print(f"GATE PASS: {args.check} — all required specs read")
            return 0
        else:
            print(f"GATE FAIL: {args.check} — missing specs:", file=sys.stderr)
            for m in missing:
                print(f"  ❌ {m}", file=sys.stderr)
            print("\nRun: python -m tools.gates.pre_edit_gate --mark-read <spec...>", file=sys.stderr)
            return 1

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
