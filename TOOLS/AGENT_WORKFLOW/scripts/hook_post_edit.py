#!/usr/bin/env python3
"""Hook PostToolUse : auto-verification apres chaque edition.

Objectif : l'agent n'a plus a « penser » a verifier le cablage — le controle
part tout seul et lui revient dans le contexte. C'est ce qui rend la regle
robuste quel que soit le modele, le workflow (Claude, Codex, Pi) ou la fatigue
de l'orchestrateur.

Declenche uniquement sur les fichiers qui le meritent :
  * `CODE/**/*.st`  -> G200_check_linkage.py (instances orphelines, refs croisees)
  * `*.md`          -> G340_check_doc_links.py (liens morts, versions perimees)

Silencieux quand tout va bien : seuls les problemes remontent a l'agent.
Ne bloque jamais une edition (exit 0) — il informe, le gate de restitution
`run_all_gates.py` reste l'autorite bloquante.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def edited_path(payload: dict) -> str:
    tool_input = payload.get("tool_input") or {}
    return tool_input.get("file_path") or tool_input.get("notebook_path") or ""


def run_check(script: str, *args: str) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / script), *args],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    return result.returncode, (result.stdout + result.stderr).strip()


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    target = edited_path(payload).replace("\\", "/")
    if not target:
        return 0

    messages: list[str] = []

    if "/CODE/" in f"/{target}" and target.endswith(".st"):
        code, out = run_check("G200_check_linkage.py")
        if code:
            messages.append(
                "Gate de liaison EN ECHEC apres cette edition — instance orpheline, "
                "reference croisee cassee ou bundle incoherent :\n" + out
            )

    if target.endswith(".md"):
        code, out = run_check("G340_check_doc_links.py")
        if code:
            messages.append(
                "Liens documentaires invalides apres cette edition "
                "(lien mort ou version perimee) :\n" + out
            )

    if messages:
        print("\n\n".join(messages), file=sys.stderr)
        # exit 2 = la sortie est renvoyee a l'agent pour correction immediate
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
