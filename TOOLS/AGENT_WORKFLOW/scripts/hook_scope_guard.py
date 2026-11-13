#!/usr/bin/env python3
"""Hook PreToolUse : garde de dérive de périmètre (T429 R9).

Une écriture hors du périmètre de la tâche attachée à la session est refusée avec un
message précis : l'agent doit alors demander l'accord de l'exploitant, et non continuer
en silence. Le refus n'est qu'un garde-fou d'outillage : tout échec d'infrastructure
(Superviseur injoignable, contrat illisible, transcript absent) laisse passer.

Modes :
  * `report` (défaut) : signale sur stderr, ne bloque pas — période de mesure.
  * `block`            : refuse l'appel (code 2), le message revient à l'agent.

Le mode se règle par la variable d'environnement `TASK_SCOPE_GUARD` (report|block).
Une dérogation déjà accordée (accès exploitant) est reconnue : voir `task_scope.py deroge`.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import miss_log  # noqa: E402  (chemin local du script)
import task_scope  # noqa: E402  (chemin local du script)
import trace_log  # noqa: E402  (journal interne)

WRITE_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")


def mode() -> str:
    value = (os.environ.get("TASK_SCOPE_GUARD") or "report").strip().lower()
    return value if value in ("report", "block") else "report"


def evaluate(session_id: str, target: str) -> dict:
    """Décide (ou non) d'une écriture. Pur :aucun effet de bord."""
    scope = task_scope.scope_for_session(session_id)
    if not scope.get("produit"):
        return {"decision": "allow", "kind": "inconnu", "reason": "aucun perimetre declare pour cette session"}
    relative = task_scope.normalize(target)
    kind = task_scope.classify(relative, scope["produit"], scope["interdits"], scope["processus"])
    if kind == "produit":
        return {"decision": "allow", "kind": "produit", "reason": "dans le perimetre produit"}
    if kind == "processus":
        return {"decision": "allow", "kind": "processus", "reason": "gestion de tache (comptee a part)"}
    if task_scope.is_derogated(session_id, relative):
        # Une derogation est un ecart ACCORDE : elle reste visible dans la metrique.
        return {"decision": "allow", "kind": "derogation", "reason": "derogation accordee"}
    return {
        "decision": "block",
        "kind": "hors",
        "reason": f"{relative} est hors du perimetre de la tache {scope.get('task_id') or '?'}",
        "path": relative,
        "task_id": scope.get("task_id"),
        "scope": scope.get("produit"),
    }


WAIT_PATTERNS = ("je ne modifie rien", "je ne touche a rien", "j'attends",
                  "tant que tu ne dis pas", "je fais rien", "je ne lance rien",
                  "en attente de ton", "je n'attends rien")


def last_wait_announcement(transcript_path) -> str:
    """Derniere phrase par laquelle l'agent annonce une attente (signature M5)."""
    if not transcript_path:
        return ""
    try:
        path = Path(transcript_path)
        size = path.stat().st_size
        with path.open("rb") as stream:
            if size > 400_000:
                stream.seek(size - 400_000)
                stream.readline()
            raw = stream.read().decode("utf-8", errors="replace")
    except Exception:
        return ""
    for line in reversed(raw.splitlines()):
        line = line.strip()
        if not line or '"assistant"' not in line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") != "assistant":
            continue
        content = (entry.get("message") or {}).get("content")
        texts = []
        if isinstance(content, str):
            texts = [content]
        elif isinstance(content, list):
            texts = [b.get("text", "") for b in content
                     if isinstance(b, dict) and b.get("type") == "text"]
        text = "\n".join(texts)
        lowered = text.lower()
        for phrase in WAIT_PATTERNS:
            if phrase in lowered:
                return text.strip()[:400]
        return ""
    return ""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("tool_name") not in WRITE_TOOLS:
        return 0

    session_id = str(payload.get("session_id") or "").strip()
    target = str((payload.get("tool_input") or {}).get("file_path") or "").strip()
    if not session_id or not target:
        return 0

    try:
        verdict = evaluate(session_id, target)
    except Exception:
        return 0  # infrastructure : on ne bloque jamais sur un probleme d'outillage

    # Toute tentative d'ecriture est tracee : la metrique s'appuye sur ce journal,
    # elle ne relit pas le transcript.
    try:
        relative = task_scope.normalize(target)
        task_scope.record_write(session_id, relative, verdict.get("kind", "hors"))
        trace_log.emit("ecriture", session=session_id, path=relative,
                       kind_verdict=verdict.get("kind"), decision=verdict.get("decision"),
                       derogation=task_scope.is_derogated(session_id, relative),
                       task_id=verdict.get("task_id"))
        if verdict.get("kind") == "hors":
            # M3 : ecriture hors perimetre -> manquement consigne (revue ulterieure).
            miss_log.record(session_id, "M3", f"Ecriture hors perimetre : {relative}",
                            f"tache={verdict.get('task_id')} perimetre={verdict.get('scope')}")
        wait_phrase = last_wait_announcement(payload.get("transcript_path"))
        if wait_phrase:
            # M5 : l'agent a annonce une attente puis ecrit quand meme.
            miss_log.record(session_id, "M5", f"Attente annoncee puis ecriture : {relative}",
                            wait_phrase[:400])
    except Exception:
        pass

    if verdict["decision"] == "allow":
        return 0

    message = (
        f"Ecriture hors perimetre de la tache {verdict.get('task_id') or '?'} : "
        f"{verdict.get('path')}\n\n"
        "Le perimetre produit de la tache est :\n"
        + "\n".join(f"  - {entry}" for entry in verdict.get("scope", []))
        + "\n\nSi cette ecriture est legitime, demande l'accord de l'exploitant et "
        "enregistre la derogation :\n"
        f"  python TOOLS/AGENT_WORKFLOW/scripts/task_scope.py deroge --session {session_id} "
        f"--path \"{verdict.get('path')}\" --motif \"<motif>\"\n"
        "Sinon, reste dans le perimetre : la phase en cours (CADRAGE) est dediee a la tache attribuee."
    )
    if mode() == "block":
        print(message, file=sys.stderr)
        return 2  # refus : le message revient a l'agent
    print("[garde de perimetre - rapport] " + message.replace("\n", " | "), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
