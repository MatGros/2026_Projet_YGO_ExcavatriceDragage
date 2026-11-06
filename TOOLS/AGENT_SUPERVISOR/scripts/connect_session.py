"""Attach the current, explicitly identified CLI conversation to Veilleur."""
from __future__ import annotations

import argparse
import json
import os
import re
import unicodedata
from urllib.parse import urlsplit
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


SESSION_ENV = {
    "claude": "CLAUDE_CODE_SESSION_ID",
    "dsh": "DSH_SESSION_ID",
}


def session_id_for(platform: str, supplied: str | None = None) -> str:
    env_id = os.environ.get(SESSION_ENV.get(platform, ""), "").strip() if platform in SESSION_ENV else ""
    candidate = (supplied or env_id).strip()
    if supplied and env_id and supplied.strip() != env_id:
        raise ValueError("L’ID fourni ne correspond pas à l’ID de la session CLI courante")
    if not candidate:
        raise ValueError("ID courant non exposé : fournir l’UUID exact, sans chercher la session la plus récente")
    patterns = {
        "claude": r"[A-Za-z0-9_-]{1,150}",
        "codex": r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}",
        "agy": r"[A-Za-z0-9_-]{1,150}",
        "dsh": r"session-[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}",
    }
    if platform == "claude" and candidate.startswith("session_"):
        raise ValueError("Cet ID vient de claude.ai ; Claude Code exige l’ID du transcript local")
    if not re.fullmatch(patterns[platform], candidate):
        raise ValueError("Format d’ID invalide pour cette plateforme")
    return candidate


def task_reference(value: str, *, anywhere: bool = False) -> str | None:
    matcher = re.search if anywhere else re.match
    match = matcher(r"\s*(T\d+)\b", value, re.IGNORECASE)
    return match.group(1).upper() if match else None


def is_no_task(value: str) -> bool:
    folded = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii").upper()
    return folded.strip().startswith("SANS TACHE FORMELLE")


def validate_local_base_url(value: str) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost", "::1")
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in ("", "/")):
        raise ValueError("Le service Veilleur doit rester sur HTTP loopback local")
    return value.rstrip("/")


def api_json(url: str, *, token: str | None = None, payload: dict | None = None):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    headers = {"Accept": "application/json"}
    method = "GET"
    if payload is not None:
        method = "POST"
        headers.update({"Content-Type": "application/json", "X-Supervision-Token": token or ""})
    request = Request(url, data=body, headers=headers, method=method)
    with urlopen(request, timeout=4) as response:
        return json.loads(response.read(1_000_000).decode("utf-8"))


def connect(platform: str, session_id: str, alias: str, task: str, mission: str,
            base_url: str = "http://127.0.0.1:8082", *, confirm_without_task: bool = False) -> dict:
    if not alias.strip() or len(alias) > 100:
        raise ValueError("Alias requis (100 caractères maximum)")
    if not mission.strip() or len(mission) > 1500:
        raise ValueError("Mission requise (1500 caractères maximum)")
    no_task = is_no_task(task)
    task_ref = task_reference(task)
    if not task_ref and not no_task:
        raise ValueError("Référence de tâche T### requise, ou suivi sans tâche formelle confirmé explicitement")
    if no_task and not confirm_without_task:
        raise ValueError("Suivi sans tâche formelle : confirmation explicite requise")
    attached_mission = f"Tâche / sujet : {task.strip()}\n{mission.strip()}"
    if len(attached_mission) > 1500:
        raise ValueError("Tâche et mission combinées : 1500 caractères maximum")
    base_url = validate_local_base_url(base_url)
    snapshot = api_json(base_url + "/api/supervision")
    if not snapshot.get("running"):
        raise RuntimeError("Collecte Veilleur arrêtée : démarrez-la depuis Task Manager puis relancez /connect-session-supervisor")
    existing = next((item for item in snapshot.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if existing:
        status = "already_assigned" if existing.get("source") and existing.get("state") in ("active", "paused", "waiting") else "source_unavailable"
        return dict(status=status, assignment_id=existing["id"], state=existing["state"],
                    alias=existing.get("alias"), platform=platform, native_id=session_id,
                    task=task, source=existing.get("source"), error=existing.get("error"))
    if task_ref:
        for item in snapshot.get("sessions", []):
            current_ref = task_reference(item.get("mission", ""), anywhere=True)
            if (current_ref == task_ref and
                    (item.get("platform") != platform or item.get("native_id") != session_id)):
                raise ValueError(f"{task_ref} est déjà suivie par {item.get('alias') or item.get('native_id')}; une tâche ne peut avoir qu'une session Veilleur")
    result = api_json(base_url + "/api/supervision", token=snapshot.get("token"), payload={
        "action": "add", "platform": platform, "native_id": session_id,
        "alias": alias.strip(), "mission": attached_mission})
    attached = next((item for item in result.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if not attached or not attached.get("source"):
        raise RuntimeError("Le service n’a pas confirmé une source unique pour cet ID")
    return dict(status="attached", assignment_id=attached["id"], state=attached["state"],
                alias=attached.get("alias"), platform=platform, native_id=session_id,
                task=task, source=attached["source"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("claude", "codex", "agy", "dsh"))
    parser.add_argument("--session-id", help="Exact native ID; Claude Code/DSH may provide one via environment")
    parser.add_argument("--alias", required=True)
    parser.add_argument("--task", required=True, help="Task reference T###, or explicit 'SANS TACHE FORMELLE' after confirmation")
    parser.add_argument("--confirm-without-task", action="store_true", help="Explicit user confirmation to track without a formal task")
    parser.add_argument("--mission", required=True)
    parser.add_argument("--url", default="http://127.0.0.1:8082")
    args = parser.parse_args()
    try:
        session_id = session_id_for(args.platform, args.session_id)
        result = connect(args.platform, session_id, args.alias, args.task, args.mission, args.url,
                         confirm_without_task=args.confirm_without_task)
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, RuntimeError, HTTPError, URLError, TimeoutError) as exc:
        print(json.dumps({"status": "error", "message": str(exc)[:240]}, ensure_ascii=False))
        raise SystemExit(2)


if __name__ == "__main__":
    main()
