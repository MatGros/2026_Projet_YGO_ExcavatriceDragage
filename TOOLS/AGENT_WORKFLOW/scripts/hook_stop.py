#!/usr/bin/env python3
"""Hook Stop : empeche de conclure un tour sur du faux.

Classe de bug couverte (REX 2026-07-29) : un lot a ete annonce termine alors que
`PRG_10_Outputs_LD` n'etait relie a rien. Tous les controles etaient VOLONTAIRES —
l'agent devait penser a les lancer. Ce hook les rend obligatoires au seul moment
qui compte : celui ou l'agent veut dire « c'est fini ».

Ne se declenche QUE si des fichiers `CODE/**/*.st` ont ete modifies dans le
depot. Une session de discussion, d'audit ou de documentation n'est jamais
bloquee — on ne genera personne pour rien.

Verifications bloquantes quand du ST a bouge :
  S1  check_linkage.py vert (aucune instance orpheline, aucune ref cassee)
  S2  CODE/CODE_Bundle.xml a jour vis-a-vis des sources

Philosophie : echec d'INFRASTRUCTURE (git absent, script illisible) = on laisse
passer, on ne bloque pas le travail sur un probleme d'outillage. Echec de
VERIFICATION = on bloque.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"


def run(cmd: list[str]) -> tuple[int, str]:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return 0, ""  # infrastructure : ne jamais bloquer la-dessus
    return result.returncode, (result.stdout + result.stderr).strip()


def st_files_touched() -> bool:
    """Du ST a-t-il bouge dans le working tree (suivi ou non) ?"""
    code, out = run(["git", "status", "--porcelain", "--", "CODE"])
    if code or not out:
        return False
    return any(line.strip().endswith(".st") for line in out.splitlines())


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    # Le hook s'est deja declenche et l'agent repart : ne pas boucler a l'infini.
    if payload.get("stop_hook_active"):
        return 0

    if not st_files_touched():
        return 0

    problems: list[str] = []

    code, out = run([sys.executable, str(SCRIPTS / "check_linkage.py"), "--report"])
    if code:
        problems.append(
            "[S1] Gate de liaison EN ECHEC — une instance est orpheline ou une "
            "reference croisee est cassee :\n" + out
        )

    code, out = run([sys.executable, str(SCRIPTS / "check_bundle_freshness.py"), "."])
    if code:
        problems.append(
            "[S2] CODE/CODE_Bundle.xml est perime par rapport aux sources.\n"
            "Regenerer : python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .\n"
            + out
        )

    if problems:
        print(
            "Ce tour ne peut pas se conclure : du code ST a ete modifie et les "
            "verifications obligatoires ne passent pas.\n\n"
            + "\n\n".join(problems)
            + "\n\nCorriger, puis relancer. Ne pas annoncer le lot termine en l'etat.",
            file=sys.stderr,
        )
        return 2  # bloque la fin de tour, le message revient a l'agent

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
