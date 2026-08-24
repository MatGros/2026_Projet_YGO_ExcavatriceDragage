#!/usr/bin/env python3
"""Regenere tous les diagrammes du projet et fait echouer le build si un
seul est suspect (crop serveur PlantUML, fichier vide, etc.).

Point d'entree unique : `python TOOLS/DIAGRAM_GENERATORS/generate_all.py`
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATORS = [
    "TOOLS/visualize_workflow.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_af_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_single_hifi.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_code_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_treuils_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_benne_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_joystick_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_encoder_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_safety_map.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_tool_project_workspace.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_tool_plcopenxml.py",
    "TOOLS/DIAGRAM_GENERATORS/generate_tool_diagram_generators.py",
]


def main() -> int:
    ok = True
    for script in GENERATORS:
        print(f"\n=== {script} ===")
        result = subprocess.run([sys.executable, script], cwd=ROOT)
        ok = ok and result.returncode == 0

    print("\n" + "=" * 40)
    if ok:
        print(">>> Tous les diagrammes sont valides.")
        return 0
    print(">>> ECHEC : au moins un diagramme est invalide/crope. Voir logs ci-dessus.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
