"""Attach the current, explicitly identified CLI conversation to Supervisor."""
from __future__ import annotations

import argparse
import json
import os
import re
import unicodedata
from pathlib import Path
from urllib.parse import urlsplit
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

try:
    import yaml
except ImportError:
    yaml = None


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


ALIAS_PATTERN = r"^T\d+(-[0-9A-Z]+)?-(CC|AGY|CDX|DSH|OPC)\d{2}$"


def validate_alias(alias: str, *, confirm_without_task: bool = False) -> str:
    """Valide l'alias de session : strictement 'TXXX-AGENT' (ex: T429-AGY01, T000-CC01, T428-1-CDX01).

    L'alias identifie la session et la machine exécutante (tâche + runtime + index).
    Il ne contient aucun texte libre/métier afin d'éviter toute ambiguïté ou invention.
    """
    cleaned = alias.strip()
    if not cleaned or len(cleaned) > 100:
        raise ValueError("Alias requis (100 caractères maximum)")
    if confirm_without_task:
        return cleaned
    if not re.fullmatch(ALIAS_PATTERN, cleaned):
        raise ValueError(
            f"L'alias '{cleaned}' ne respecte pas le format strict 'TXXX[-X]-AGENT' "
            "(ex: T429-AGY01, T428-1-CDX01, T000-CC01)"
        )
    return cleaned


def lookup_task_title(task_ref: str) -> str | None:
    """Récupère automatiquement le titre officiel d'une tâche depuis DOC/WFLOW/TASKS.yaml."""
    if not yaml:
        return None
    repo_root = Path(__file__).resolve().parents[3]
    tasks_file = repo_root / "DOC" / "WFLOW" / "TASKS.yaml"
    if not tasks_file.exists():
        return None
    try:
        data = yaml.safe_load(tasks_file.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return None
        for t in data.get("tasks", []):
            if isinstance(t, dict) and str(t.get("id", "")).upper() == task_ref.upper():
                return t.get("titre")
    except Exception:
        return None
    return None


def is_no_task(value: str) -> bool:
    folded = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii").upper()
    return folded.strip().startswith("SANS TACHE FORMELLE")


def validate_local_base_url(value: str) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost", "::1")
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in ("", "/")):
        raise ValueError("Le service Superviseur doit rester sur HTTP loopback local")
    return value.rstrip("/")


def api_json(url: str, *, token: str | None = None, payload: dict | None = None, max_bytes: int = 10_000_000):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    headers = {"Accept": "application/json"}
    method = "GET"
    if payload is not None:
        method = "POST"
        headers.update({"Content-Type": "application/json", "X-Supervision-Token": token or ""})
    request = Request(url, data=body, headers=headers, method=method)
    with urlopen(request, timeout=10) as response:
        return json.loads(response.read(max_bytes).decode("utf-8"))


def find_task_contract(task_id: str) -> tuple[Path | None, dict | None]:
    if not yaml:
        return None, None
    repo_root = Path(__file__).resolve().parents[3]
    doc_wflow = repo_root / "DOC" / "WFLOW"
    if not doc_wflow.exists():
        return None, None
    candidates = list(doc_wflow.glob(f"**/*{task_id}*.*yaml"))
    active = [c for c in candidates if "ARCHIVES" not in c.parts]
    for c in active or candidates:
        try:
            data = yaml.safe_load(c.read_text(encoding="utf-8"))
            if isinstance(data, dict) and ("contract" in data or "task_id" in data):
                return c, data
        except Exception:
            continue
    return None, None


def populate_mission_from_contract(base_url: str, token: str, assignment_id: str,
                                   task_ref: str, task_raw: str, mission_raw: str) -> bool:
    contract_path, data = find_task_contract(task_ref)
    if not contract_path or not data:
        return False
    c = data.get("contract") or data
    objective = str(c.get("objective") or task_raw).strip()
    scope = str(c.get("scope") or "DOC/WFLOW/ selon contrat de tâche").strip()
    constraints = str(c.get("constraints") or f"Criticité {c.get('criticality', 'C2')} · Stratégie {c.get('strategy', 'patch')}").strip()
    acceptance = c.get("acceptance") or []
    criteria_lines = []
    if isinstance(acceptance, list):
        for item in acceptance[:6]:
            if isinstance(item, dict):
                statement = item.get("statement") or item.get("id") or ""
                if statement:
                    criteria_lines.append(f"{item.get('id', 'AC')}: {statement}")
            elif isinstance(item, str):
                criteria_lines.append(item)
    criteria_text = " · ".join(criteria_lines)[:600] if criteria_lines else "Selon critères du contrat"

    structure = {
        "subject": task_raw.strip(),
        "task_ref": task_ref.strip(),
        "primary_goal": objective[:400],
        "current_goal": mission_raw.strip()[:400],
        "milestone": f"Contrat {contract_path.name[:80]}",
        "scope_permissions": scope[:300],
        "constraints": constraints[:300],
        "criteria": criteria_text[:400],
        "evidence": f"Contrat validé : {contract_path.name[:80]}",
        "unknowns": "Selon avancement session",
        "next_step": "Exécution cadrée de la tâche",
        "extra": f"Contrat chargé automatiquement depuis {contract_path.name}"
    }
    try:
        api_json(base_url + "/api/supervision", token=token, payload={
            "action": "set_mission_structure",
            "id": assignment_id,
            "structure": structure
        })
        return True
    except Exception:
        return False


def connect(platform: str, session_id: str, alias: str, task: str, mission: str,
            base_url: str = "http://127.0.0.1:8082", *, confirm_without_task: bool = False,
            reassign: bool = False) -> dict:
    alias = validate_alias(alias, confirm_without_task=confirm_without_task)
    if not mission.strip() or len(mission) > 1500:
        raise ValueError("Mission requise (1500 caractères maximum)")
    no_task = is_no_task(task)
    task_ref = task_reference(task)
    # T000 ou tâche provisoire : dispensée de confirmation explicite
    is_provisional = (task_ref == "T000")
    if not task_ref and not no_task:
        raise ValueError("Référence de tâche T### requise, ou suivi sans tâche formelle confirmé explicitement")
    if no_task and not confirm_without_task:
        raise ValueError("Suivi sans tâche formelle : confirmation explicite requise")

    # Résolution automatique du libellé de tâche :
    # Si task est juste l'ID (ex: "T423") ou si un titre officiel existe dans TASKS.yaml, on l'aligne automatiquement
    official_title = lookup_task_title(task_ref) if task_ref else None
    if official_title and (task.strip().upper() == task_ref.upper() or len(task.strip()) <= len(task_ref) + 3):
        task_label = f"{task_ref} {official_title}"
    else:
        task_label = task.strip()

    attached_mission = f"Tâche / sujet : {task_label}\n{mission.strip()}"
    if len(attached_mission) > 1500:
        raise ValueError("Tâche et mission combinées : 1500 caractères maximum")
    base_url = validate_local_base_url(base_url)
    snapshot = api_json(base_url + "/api/supervision")
    if not snapshot.get("running"):
        raise RuntimeError("Collecte Superviseur arrêtée : démarrez-la depuis Task Manager puis relancez /connect-session-supervisor")
    existing = next((item for item in snapshot.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if existing:
        status = "already_assigned" if existing.get("source") and existing.get("state") in ("active", "paused", "waiting") else "source_unavailable"
        return dict(status=status, assignment_id=existing["id"], state=existing["state"],
                    alias=existing.get("alias"), platform=platform, native_id=session_id,
                    task=task, source=existing.get("source"), error=existing.get("error"))
    if task_ref and not is_provisional:
        for item in snapshot.get("sessions", []):
            current_ref = task_reference(item.get("mission", ""), anywhere=True)
            if (current_ref == task_ref and
                    (item.get("platform") != platform or item.get("native_id") != session_id)):
                if not reassign:
                    raise ValueError(
                        f"{task_ref} est déjà suivie par '{item.get('alias') or item.get('native_id')}'; "
                        "pour transférer le suivi de cette tâche vers ce nouveau runtime, relancez avec --reassign"
                    )
                result = api_json(base_url + "/api/supervision", token=snapshot.get("token"), payload={
                    "action": "reassign", "id": item["id"], "platform": platform, "native_id": session_id,
                    "alias": alias.strip(), "mission": attached_mission, "handover": True})
                attached = next((s for s in result.get("sessions", []) if s["id"] == item["id"]), None)
                if not attached or not attached.get("source"):
                    raise RuntimeError("Le service n’a pas confirmé une source unique pour la réassignation")
                structure_loaded = False
                if task_ref and snapshot.get("token"):
                    structure_loaded = populate_mission_from_contract(
                        base_url, snapshot.get("token"), attached["id"], task_ref, task_label, mission
                    )
                return dict(status="reassigned", assignment_id=attached["id"], state=attached["state"],
                            alias=attached.get("alias"), platform=platform, native_id=session_id,
                            task=task_label, source=attached["source"], previous_alias=item.get("alias"),
                            mission_structure_loaded=structure_loaded)
    result = api_json(base_url + "/api/supervision", token=snapshot.get("token"), payload={
        "action": "add", "platform": platform, "native_id": session_id,
        "alias": alias.strip(), "mission": attached_mission})
    attached = next((item for item in result.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if not attached or not attached.get("source"):
        raise RuntimeError("Le service n’a pas confirmé une source unique pour cet ID")
    structure_loaded = False
    if task_ref and snapshot.get("token"):
        structure_loaded = populate_mission_from_contract(
            base_url, snapshot.get("token"), attached["id"], task_ref, task_label, mission
        )
    return dict(status="attached", assignment_id=attached["id"], state=attached["state"],
                alias=attached.get("alias"), platform=platform, native_id=session_id,
                task=task_label, source=attached["source"], mission_structure_loaded=structure_loaded)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("claude", "codex", "agy", "dsh"))
    parser.add_argument("--session-id", help="Exact native ID; Claude Code/DSH may provide one via environment")
    parser.add_argument("--alias", required=True)
    parser.add_argument("--task", required=True, help="Task reference T###, or explicit 'SANS TACHE FORMELLE' after confirmation")
    parser.add_argument("--confirm-without-task", action="store_true", help="Explicit user confirmation to track without a formal task")
    parser.add_argument("--reassign", action="store_true", help="Transférer le suivi d'une session existante pour cette tâche vers ce nouveau runtime")
    parser.add_argument("--mission", required=True)
    parser.add_argument("--url", default="http://127.0.0.1:8082")
    args = parser.parse_args()
    try:
        session_id = session_id_for(args.platform, args.session_id)
        result = connect(args.platform, session_id, args.alias, args.task, args.mission, args.url,
                         confirm_without_task=args.confirm_without_task, reassign=args.reassign)
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, RuntimeError, HTTPError, URLError, TimeoutError) as exc:
        print(json.dumps({"status": "error", "message": str(exc)[:240]}, ensure_ascii=False))
        raise SystemExit(2)


if __name__ == "__main__":
    main()
