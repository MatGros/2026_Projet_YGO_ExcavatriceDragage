#!/usr/bin/env python3
"""Hook Stop : empeche de CONCLURE UN LOT sur du faux — pas de bloquer le WIP.

Classe de bug couverte (REX 2026-07-29) : un lot a ete annonce termine alors que
`PRG_10_Outputs_LD` n'etait relie a rien. Tous les controles etaient VOLONTAIRES —
l'agent devait penser a les lancer. Ce hook les rend obligatoires au seul moment
qui compte : celui ou l'agent DECLARE la fin d'un lot (bannieres definies dans
AGENTS.md, ex. "BUNDLE EXPORTE ET VALIDE", "lot termine").

Ne se declenche QUE si des fichiers `CODE/**/*.st` ont ete modifies dans le
depot. Une session de discussion, d'audit ou de documentation n'est jamais
bloquee. Pendant l'implementation (WIP), G200/le bundle peuvent etre rouges
aussi longtemps que necessaire : coder, committer, pousser, iterer, s'arreter
pour reflechir — rien de tout ca n'est bloque (REX 2026-08-23, l'utilisateur a
explicitement rejete le blocage pendant le WIP). Seule la DECLARATION de fin
de lot, texte a l'appui dans le transcript, active la verification.

Verifications bloquantes quand du ST a bouge ET que le dernier message de
l'agent declare un lot termine :
  S1  G200_check_linkage.py vert (aucune instance orpheline, aucune ref cassee)
  S2  CODE_XML/CODE_Bundle.xml a jour vis-a-vis des sources

Philosophie : echec d'INFRASTRUCTURE (git absent, script illisible) = on laisse
passer, on ne bloque pas le travail sur un probleme d'outillage. Echec de
VERIFICATION au moment d'une declaration de fin = on bloque.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"

# Marqueurs de declaration de fin de lot — cf. AGENTS.md "Bandeau de restitution
# obligatoire". Volontairement etroit : un "termine"/"fini" isole dans une phrase
# de discussion normale (ex. "l'iteration est terminee pour ce soir") ne doit
# PAS declencher le gate. Doit rester aligne avec les bannieres reellement demandees.
COMPLETION_MARKERS = (
    "bundle exporté",       # bandeaux 1 et 2 d'AGENTS.md commencent tous les deux ainsi
    "lot terminé",
)


def last_assistant_text(transcript: Path) -> str:
    """Texte du dernier message assistant du transcript (preuve non falsifiable)."""
    text = ""
    try:
        with transcript.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                message = entry.get("message") or {}
                if message.get("role") != "assistant":
                    continue
                content = message.get("content")
                if not isinstance(content, list):
                    continue
                blocks = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
                if blocks:
                    text = "\n".join(blocks)
    except OSError:
        return ""
    return text


def declares_completion(transcript_path: str | None) -> bool:
    if not transcript_path:
        return True  # transcript illisible : on ne peut pas prouver l'absence -> comportement prudent conserve
    text = last_assistant_text(Path(transcript_path)).lower()
    if not text:
        return True
    return any(marker in text for marker in COMPLETION_MARKERS)


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

    if not declares_completion(payload.get("transcript_path")):
        # WIP : le code bouge mais l'agent ne declare pas de fin de lot.
        # On n'alerte meme pas — pas de bruit pendant l'iteration normale.
        return 0

    problems: list[str] = []

    code, out = run([sys.executable, str(SCRIPTS / "G200_check_linkage.py"), "--report"])
    if code:
        problems.append(
            "[S1] Gate de liaison EN ECHEC — une instance est orpheline ou une "
            "reference croisee est cassee :\n" + out
        )

    code, out = run([sys.executable, str(SCRIPTS / "G390_check_bundle_freshness.py"), "."])
    if code:
        problems.append(
            "[S2] CODE_XML/CODE_Bundle.xml est perime par rapport aux sources.\n"
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
