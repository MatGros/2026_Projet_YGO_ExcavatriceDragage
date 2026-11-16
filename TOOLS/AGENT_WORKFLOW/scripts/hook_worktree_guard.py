#!/usr/bin/env python3
"""Hook PreToolUse : alerte et blocage de la creation de worktree (T427, 2026-11-16).

Regle exploitant (2026-11-15) : un worktree n'est pas interdit, mais il est dangereux
s'il n'est pas annonce. Il faut une justification et une preuve avant tout worktree.

Bloque (code 2, message sur stderr) :
  * `EnterWorktree` (creation ou entree dans un worktree) ;
  * `Agent` avec `isolation: "worktree"`.

Ne bloque pas : tout autre outil, et toute erreur de lecture de l'entree (garde-fou
d'outillage : une panne du hook ne doit pas bloquer le travail).

Levee du blocage : l'exploitant lance la session avec `WORKTREE_GUARD=allow` dans
l'environnement, apres avoir lu la justification et la preuve.
"""
from __future__ import annotations

import json
import os
import sys

MESSAGE = (
    "WORKTREE BLOQUE : creation de worktree demandee. Regle exploitant : justification et "
    "preuve obligatoires avant tout worktree (fichiers concernes, agent concurrent identifie, "
    "preuve de conflit). Annonce : chemin, branche, raison, ce qui reste a merger. "
    "Un sous-agent ne cree jamais de worktree. Demande l'accord de l'exploitant, puis il "
    "levera le blocage (WORKTREE_GUARD=allow)."
)


def is_worktree_call(payload: dict) -> bool:
    name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}
    if name == "EnterWorktree":
        return True
    return name == "Agent" and tool_input.get("isolation") == "worktree"


def main() -> int:
    if os.environ.get("WORKTREE_GUARD", "").strip().lower() == "allow":
        return 0
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        return 0
    if isinstance(payload, dict) and is_worktree_call(payload):
        print(MESSAGE, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
