#!/usr/bin/env python3
"""G533 — garde-fou des alias de session (TORC, acteurs, timeout Superviseur).

Cree le 2026-11-16 apres trois defauts constates le meme jour :
  1. l'alias reserve TORC, documente dans le plan T427 ligne 731, etait refuse
     par connect_session.py et rename_session.py ;
  2. la liste des acteurs est dupliquee dans les deux fichiers : une divergence
     passe inapercue ;
  3. rename_session.py imposait un timeout HTTP de 1,0 s alors que le service
     repond en ~0,55 s par appel, ce qui faisait echouer /rename-session.

Regle fix + guard (AGENTS.md) : ces trois defauts ne doivent plus pouvoir revenir
sans un echec explicite de ce script.

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G533_check_session_alias.py [--report]
Code retour : 0 si tout passe, 1 sinon.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
CONNECT = REPO_ROOT / "TOOLS" / "AGENT_SUPERVISOR" / "scripts" / "connect_session.py"
RENAME = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "rename_session.py"

ACCEPTED = ("TORC-CC10", "T432-CDX02", "T417-C-AGY02")
REFUSED = ("TORC", "TORC-CC", "T432", "T432-CC1", "ABCD-CC10")
# 2026-11-16 : le premier correctif ne couvrait que RE_MACHINE_ALIAS.
# Le jeton brut passe d'abord par RE_TASK_ID : TORC-CC10 y etait encore refuse.
TASK_ID_REFUSED = ("TORC-CC", "TORC-XYZ10", "TORC-CC10-EXTRA")
ACTOR_GROUP = re.compile(r"\((?:CC|AGY|CDX|DSH|OPC|GLM|MMX|QWN)(?:\|[A-Z]{2,3})*\)")


def _load(path: Path, name: str):
    sys.path.insert(0, str(path.parent))
    try:
        return __import__(name)
    finally:
        sys.path.pop(0)


def check() -> list[str]:
    failures: list[str] = []
    connect = _load(CONNECT, "connect_session")
    rename = _load(RENAME, "rename_session")

    for alias in ACCEPTED:
        try:
            connect.validate_alias(alias)
        except Exception as exc:
            failures.append(f"connect_session refuse {alias} : {exc}")
        if not rename.RE_MACHINE_ALIAS.fullmatch(alias):
            failures.append(f"rename_session refuse {alias}")
        if not rename.RE_TASK_ID.match(alias):
            failures.append(f"rename_session RE_TASK_ID refuse le jeton d'alias {alias}")

    for alias in TASK_ID_REFUSED:
        if rename.RE_TASK_ID.match(alias):
            failures.append(f"rename_session RE_TASK_ID accepte {alias} alors qu'il doit le refuser")

    for alias in REFUSED:
        try:
            connect.validate_alias(alias)
            failures.append(f"connect_session accepte {alias} alors qu'il doit le refuser")
        except Exception:
            pass
        if rename.RE_MACHINE_ALIAS.fullmatch(alias):
            failures.append(f"rename_session accepte {alias} alors qu'il doit le refuser")

    if connect.task_reference("TORC-CC10") != "TORC":
        failures.append("task_reference ne resout pas TORC-CC10 vers TORC")

    actors = {
        path.name: {a for a in (m.group(0) for m in ACTOR_GROUP.finditer(path.read_text(encoding="utf-8")))}
        for path in (CONNECT, RENAME)
    }
    if actors[CONNECT.name] != actors[RENAME.name]:
        failures.append(
            "listes d'acteurs divergentes entre les deux fichiers : "
            f"{sorted(actors[CONNECT.name])} vs {sorted(actors[RENAME.name])}"
        )

    timeout = getattr(rename, "SUPERVISOR_HTTP_TIMEOUT", None)
    if not isinstance(timeout, (int, float)) or timeout < 3.0:
        failures.append(f"SUPERVISOR_HTTP_TIMEOUT absent ou trop court : {timeout!r} (>= 3,0 s attendu)")

    return failures


def main() -> int:
    failures = check()
    report = "--report" in sys.argv
    if failures:
        print(f"[X] G533 ECHEC — {len(failures)} ecart(s)")
        for line in failures:
            print(f"  - {line}")
        return 1
    if report:
        print(f"[OK] G533 PASS — alias TORC accepte, {len(ACCEPTED)} alias valides, "
              f"{len(REFUSED)} alias refuses, listes d'acteurs identiques, timeout Superviseur >= 3,0 s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
