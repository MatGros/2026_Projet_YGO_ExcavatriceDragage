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
    match = matcher(r"\s*(TORC|T\d+(?:-[0-9A-Z]+)*)", value, re.IGNORECASE)
    if not match:
        return None
    task_ref = match.group(1)
    # A mission can contain a canonical alias; remove its final agent suffix.
    task_ref = re.sub(r"-(?:CC|AGY|CDX|DSH|OPC|GLM|MMX|QWN)\d{2}$", "", task_ref, flags=re.IGNORECASE)
    return task_ref.upper()


# TORC : identifiant reserve a l'orchestrateur multi-tache (plan T427, ligne 731).
# Il ne correspond a aucune tache du catalogue : le titre est donc fourni explicitement.
ALIAS_PATTERN = r"^(TORC|T\d+(-[0-9A-Z]+)?)-(CC|AGY|CDX|DSH|OPC|GLM|MMX|QWN)\d{2}$"
ALIAS_IDENTITY_PATTERN = re.compile(
    r"^(?P<task>(?:TORC|T\d+(?:-[0-9A-Z]+)?))-(?P<agent>(?:CC|AGY|CDX|DSH|OPC|GLM|MMX|QWN)\d{2})$"
)
MAX_DISPLAY_TITLE_LENGTH = 80


def split_alias(alias: str) -> tuple[str, str]:
    """Separe l'alias machine de la designation libre de l'exploitant.

    "T417-C-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3" -> ("T417-C-AGY02", "GEMINI 4 HYDRO CHALLENGE SIMU M3")
    L'alias reste un identifiant machine ; la designation devient le titre lisible.
    """
    cleaned = str(alias or "").strip()
    if not cleaned:
        return "", ""
    if re.fullmatch(ALIAS_PATTERN, cleaned):
        return cleaned, ""
    parts = cleaned.split(maxsplit=1)
    if len(parts) == 2 and re.fullmatch(ALIAS_PATTERN, parts[0]):
        return parts[0], parts[1].strip()
    return cleaned, ""


def validate_alias(alias: str) -> str:
    """Valide l'alias de session : strictement 'TXXX-AGENT' (ex: T429-AGY01, T000-CC01, T428-1-CDX01).

    L'alias identifie la session et la machine exécutante (tâche + runtime + index).
    Il ne contient aucun texte libre/métier afin d'éviter toute ambiguïté ou invention.
    """
    cleaned = alias.strip()
    if not cleaned or len(cleaned) > 100:
        raise ValueError("Alias requis (100 caractères maximum)")
    if not re.fullmatch(ALIAS_PATTERN, cleaned):
        raise ValueError(
            f"L'alias '{cleaned}' ne respecte pas le format strict 'TXXX[-X]-AGENT' "
            "(ex: T429-AGY01, T428-1-CDX01, T000-CC01)"
        )
    return cleaned


def resolve_display_title(alias: str, requested: str | None = None, legacy_designation: str = "") -> str:
    """Build a compact display title; the official task title stays in the mission metadata."""
    descriptor = " ".join(str(requested or legacy_designation or "").split())
    if not descriptor:
        title = alias
    elif descriptor == alias or descriptor.startswith(alias + " "):
        title = descriptor
    else:
        title = f"{alias} {descriptor}"
    if len(title) > MAX_DISPLAY_TITLE_LENGTH:
        raise ValueError(f"Titre de session trop long ({len(title)} caractères, maximum {MAX_DISPLAY_TITLE_LENGTH})")
    return title


def alias_identity(alias: str) -> tuple[str, str] | None:
    """Return the task ID and runtime agent ID encoded by a canonical alias."""
    match = ALIAS_IDENTITY_PATTERN.fullmatch(alias.strip())
    return (match.group("task").upper(), match.group("agent").upper()) if match else None


def resolve_task_title(task_records: list, task_ref: str) -> str | None:
    """Resolve one non-empty official title, refusing duplicate task IDs."""
    matches = [t for t in task_records
               if isinstance(t, dict) and str(t.get("id", "")).upper() == task_ref.upper()]
    if len(matches) > 1:
        raise ValueError(f"ID de tâche ambigu dans TASKS.yaml : {task_ref}")
    if not matches:
        return None
    title = str(matches[0].get("titre", "")).strip()
    return title or None


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
        return resolve_task_title(data.get("tasks", []), task_ref)
    except ValueError:
        raise
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
        # R29/T427-CC02 (2026-11-17) : une fiche vide acceptee en silence = une mission
        # fantome que le juge analyse.
        # T000/TORC : l'outil CONNAIT le contrat de gouvernance d'un orchestrateur
        # (les 5 criteres de la notice COORDINATION_JUDGE_NOTICE) -> template rempli,
        # non vide, ajustable par l'exploitant. Sans contrat par conception.
        if task_ref.strip().upper().startswith(("T000", "TORC")):
            structure = {
                "subject": task_raw.strip(),
                "task_ref": task_ref.strip(),
                "primary_goal": (f"Orchestration du projet par {task_ref.strip()} : piloter les taches "
                                  "du catalogue via le canal orchestrateur designe ; NE JAMAIS cloter "
                                  "un constat ni une tache soi-meme (regle 10)."),
                "current_goal": "N/A — suivi au fil de l'eau, jalon porte par le pilotage orchestrateur",
                "milestone": "Orchestration (sans contrat par conception — alias T000*/TORC*)",
                "scope_permissions": ("Orchestration : DOC/WFLOW/TASKS via API Task Manager, chat agent, "
                                       "journal ; lecture seule partout ailleurs"),
                "constraints": "Orchestrateur hors catalogue : pas de contrat, regles de gouvernance obligatoires",
                "criteria": ("Criteres de gestion : (1) clotures par l'exploitant ou un juge code ; "
                              "(2) fiches modifiees via l'API Task Manager, jamais en direct ; "
                              "(3) ne jamais contourner un verrou d'un autre acteur ; "
                              "(4) preuve = git diff reel, pas un rapport d'agent ; "
                              "(5) aucun commit ni push sans accord humain explicite."),
                "evidence": "Template orchestrateur pose par connect_session",
                "unknowns": "Fiche orchestrateur generique — ajustable par l'exploitant (pas de contrat)",
                "next_step": "Pilotage du canal orchestrateur selon les criteres de gestion",
                "extra": "Template orchestrateur (T000*/TORC*) pose par connect_session",
            }
        else:
            # R29 (regle exploitant 2026-11-17) : AUCUN champ vide — chaque champ non
            # applicable est rempli explicitement ("N/A — raison"), informer toujours.
            na = "N/A — fiche sans contrat, a cadrer par l'exploitant"
            structure = {
                "subject": task_raw.strip(),
                "task_ref": task_ref.strip(),
                "primary_goal": na,
                "current_goal": na,
                "milestone": f"Contrat introuvable pour {task_ref.strip()}",
                "scope_permissions": na,
                "constraints": na,
                "criteria": na,
                "evidence": "Fiche generee depuis connect_session sans contrat",
                "unknowns": ("Fiche incomplete : contrat absent ou alias hors catalogue — a "
                             "completer par l'exploitant (orchestrateur hors catalogue : sans contrat par conception)"),
                "next_step": "A cadrer avec l'exploitant si la tache est formelle",
                "extra": "Fiche generee depuis connect_session sans contrat",
            }
        try:
            api_json(base_url + "/api/supervision", token=token, payload={
                "action": "set_mission_structure", "origin": "contrat",
                "id": assignment_id,
                "structure": structure
            })
            return True
        except Exception:
            return False
    c = data.get("contract") or data
    objective = str(c.get("objective") or task_raw).strip()
    raw_scope = c.get("scope")
    # R29 : humaniser le perimetre — {"allowed": [...], "forbidden": [...]} devient
    # "Autorise : a, b · Interdit : c" au lieu du repr brut du dict.
    if isinstance(raw_scope, dict):
        allowed_text = ", ".join(str(item) for item in (raw_scope.get("allowed") or []))
        forbidden_text = ", ".join(str(item) for item in (raw_scope.get("forbidden") or []))
        scope = "Autorisé : " + (allowed_text or "—")
        if forbidden_text:
            scope += " · Interdit : " + forbidden_text
    else:
        scope = str(raw_scope or "DOC/WFLOW/ selon contrat de tâche").strip()
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

    def capped(value: str, limit: int, source_name: str) -> str:
        """R29 : jamais de troncature silencieuse — un marqueur dit ou lire la fin."""
        text = str(value or "").strip()
        if len(text) <= limit:
            return text
        marker = f" […] tronqué à {limit} car. — lire {source_name}"
        return text[:max(0, limit - len(marker))].rstrip() + marker

    structure = {
        "subject": task_raw.strip(),
        "task_ref": task_ref.strip(),
        "primary_goal": capped(objective, 400, contract_path.name),
        # T429 : le titre de session n est PAS un objectif courant -> on ne le recopie
        # pas ; le champ reste a completer par l exploitant (la consigne est dans l IHM).
        "current_goal": "",
        "milestone": capped(f"Contrat {contract_path.name}", 80, contract_path.name),
        "scope_permissions": capped(scope, 300, contract_path.name),
        "constraints": capped(constraints, 300, contract_path.name),
        "criteria": capped(criteria_text, 400, contract_path.name),
        "evidence": f"Contrat validé : {contract_path.name[:80]}",
        "unknowns": "Selon avancement session",
        "next_step": "Exécution cadrée de la tâche",
        "extra": f"Contrat chargé automatiquement depuis {contract_path.name}"
    }
    try:
        api_json(base_url + "/api/supervision", token=token, payload={
            "action": "set_mission_structure", "origin": "contrat",
            "id": assignment_id,
            "structure": structure
        })
        return True
    except Exception:
        return False


def connect(platform: str, session_id: str, alias: str, task: str, mission: str,
            base_url: str = "http://127.0.0.1:8082", *, task_title: str | None = None,
            confirm_without_task: bool = False, reassign: bool = False,
            display_title: str | None = None) -> dict:
    alias, designation = split_alias(alias)
    alias = validate_alias(alias)
    identity = alias_identity(alias)
    if not identity:
        raise ValueError("Alias agent invalide")
    alias_task_ref, agent_id = identity

    no_task = is_no_task(task)
    task_ref = "T000" if no_task and confirm_without_task else task_reference(task)
    if no_task and not confirm_without_task:
        raise ValueError("Suivi sans tâche formelle : confirmation explicite requise")
    if not task_ref:
        raise ValueError("ID de tâche T### requis")
    if alias_task_ref != task_ref:
        raise ValueError(f"L'ID tâche de l'alias ({alias_task_ref}) ne correspond pas à --task ({task_ref})")
    is_provisional = task_ref in ("T000", "TORC")

    task_match = re.match(r"^\s*T\d+(?:-[0-9A-Z]+)*\b(.*)$", task, re.IGNORECASE)
    inline_title = task_match.group(1).strip(" \t:—-") if task_match and not no_task else ""
    if is_provisional:
        resolved_title = (task_title or inline_title).strip()
        if not resolved_title:
            raise ValueError("Titre explicite requis pour T000 / TORC / le suivi sans tâche formelle")
        if task_title and inline_title and " ".join(task_title.split()).casefold() != " ".join(inline_title.split()).casefold():
            raise ValueError("Les titres fournis pour T000 ne correspondent pas")
    else:
        resolved_title = lookup_task_title(task_ref)
        if not resolved_title:
            raise ValueError(f"Tâche {task_ref} absente de TASKS.yaml ou sans titre officiel")
        for supplied_title in (task_title, inline_title):
            if supplied_title and " ".join(supplied_title.split()).casefold() != " ".join(resolved_title.split()).casefold():
                raise ValueError(f"Titre fourni différent du titre officiel de {task_ref} : {resolved_title}")

    if not mission.strip() or len(mission) > 1500:
        raise ValueError("Mission requise (1500 caractères maximum)")
    task_label = f"{task_ref} {resolved_title}"
    # Titre de status line compact et séparé du titre officiel, conservé dans la mission.
    title_line = resolve_display_title(alias, display_title, designation)
    attached_mission = title_line
    if resolved_title and not is_provisional:  # T000 : pas de doublon
        # le titre explicite est deja dans la premiere ligne
        attached_mission += f"\nTâche : {resolved_title}"
    attached_mission += f"\nTâche / sujet : {task_label}\n{mission.strip()}"
    if len(attached_mission) > 1500:
        raise ValueError("Tâche et mission combinées : 1500 caractères maximum")
    base_url = validate_local_base_url(base_url)
    snapshot = api_json(base_url + "/api/supervision")
    if not snapshot.get("running"):
        raise RuntimeError("Collecte Superviseur arrêtée : démarrez-la depuis Task Manager puis relancez /connect-session-supervisor")
    existing = next((item for item in snapshot.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if existing:
        # T429 : on compare l ETAT COURANT (alias + mission). La mission INITIALE est gelee
        # au premier rattachement : apres un renommage legitime, elle ne correspond plus
        # jamais et le rattachement etait refuse pour toujours.
        current_mission = str(existing.get("mission") or "")
        current_task = task_reference(current_mission, anywhere=True)
        same_task = bool(current_task) and current_task.upper() == task_ref.upper()
        if existing.get("alias") != alias or not same_task:
            raise ValueError(
                f"Session déjà reliée avec alias/tâche différents ({existing.get('alias')}, "
                f"tâche {current_task or 'inconnue'} vs {task_ref}); aucun changement appliqué. "
                "Pour transférer le suivi vers cette tâche, relancez avec --reassign :\n"
                f"  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py --platform {platform} "
                f"--session-id {session_id} --alias \"{alias}\" --task \"{task_ref}\" "
                f"--mission \"{mission.strip()[:80]}\" --reassign"
            )
        status = "already_assigned" if existing.get("source") and existing.get("state") in ("active", "paused", "waiting") else "source_unavailable"
        # R29/T427 (2026-11-17) : une fiche VIDE heritee d'un attach anterieur est comblee
        # ici aussi — une fiche muette ne doit survivre a aucun re-rattachement.
        fiche_vide = not (existing.get("mission_structure") or {})
        if fiche_vide and task_ref and snapshot.get("token"):
            populate_mission_from_contract(
                base_url, snapshot.get("token"), existing["id"], task_ref, task_label, mission
            )
        return dict(status=status, assignment_id=existing["id"], state=existing["state"],
                    alias=existing.get("alias"), platform=platform, native_id=session_id,
                    task_id=task_ref, task_title=resolved_title, agent_id=agent_id,
                    task=task_label, source=existing.get("source"), error=existing.get("error"),
                    fiche_completee=fiche_vide)
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
                api_json(base_url + "/api/supervision", token=snapshot.get("token"), payload={
                    "action": "set_alias", "id": attached["id"], "alias": alias.strip(),
                    "display_title": title_line})
                confirmed = api_json(base_url + "/api/supervision/summary")
                confirmed_session = next((s for s in confirmed.get("sessions", [])
                                          if s.get("id") == attached["id"]), None)
                if not confirmed_session or confirmed_session.get("display_title") != title_line:
                    raise RuntimeError("Réaffectation faite, mais le titre court n’a pas été confirmé")
                structure_loaded = False
                if task_ref and snapshot.get("token"):
                    # R29/T427 : TORC/T000 passent aussi — la fiche porte son etat
                    # "sans contrat par conception" au lieu de rester vide et muette.
                    structure_loaded = populate_mission_from_contract(
                        base_url, snapshot.get("token"), attached["id"], task_ref, task_label, mission
                    )
                return dict(status="reassigned", assignment_id=attached["id"], state=attached["state"],
                            alias=attached.get("alias"), platform=platform, native_id=session_id,
                            task_id=task_ref, task_title=resolved_title, agent_id=agent_id,
                            task=task_label, source=attached["source"], previous_alias=item.get("alias"),
                            display_title=title_line,
                            mission_structure_loaded=structure_loaded)
    # T429 : le socle (documents a lire AVANT d agir) est exige des l affectation.
    try:
        import sys as _sys
        _wf = str(Path(__file__).resolve().parents[2] / "AGENT_WORKFLOW" / "scripts")
        if _wf not in _sys.path:
            _sys.path.insert(0, _wf)
        import task_socle
        socle = task_socle.socle_for(task_ref)
    except Exception:
        socle = []
    result = api_json(base_url + "/api/supervision", token=snapshot.get("token"), payload={
        "action": "add", "platform": platform, "native_id": session_id,
        "alias": alias.strip(), "display_title": title_line, "mission": attached_mission,
        # T429 : la tache et son titre sont des DONNEES, plus du texte a parser.
        "task_ref": task_ref, "task_title": resolved_title,
        # T429 : le socle a lire est exige des l attachement.
        "socle": socle})
    attached = next((item for item in result.get("sessions", [])
                     if item.get("platform") == platform and item.get("native_id") == session_id), None)
    if not attached or not attached.get("source"):
        raise RuntimeError("Le service n’a pas confirmé une source unique pour cet ID")
    structure_loaded = False
    if task_ref and snapshot.get("token"):
        # R29/T427 : TORC/T000 compris — fiche explicite "sans contrat par conception".
        structure_loaded = populate_mission_from_contract(
            base_url, snapshot.get("token"), attached["id"], task_ref, task_label, mission
        )
    return dict(status="attached", assignment_id=attached["id"], state=attached["state"],
                alias=attached.get("alias"), platform=platform, native_id=session_id,
                task_id=task_ref, task_title=resolved_title, agent_id=agent_id,
                task=task_label, source=attached["source"], display_title=title_line,
                mission_structure_loaded=structure_loaded)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=("claude", "codex", "agy", "dsh"))
    parser.add_argument("--session-id", help="Exact native ID; Claude Code/DSH may provide one via environment")
    parser.add_argument("--alias", required=True)
    parser.add_argument("--task", required=True, help="Task ID T###, optionally followed by its exact official title")
    parser.add_argument("--task-title", help="Required for T000; formal task titles resolve from TASKS.yaml")
    parser.add_argument("--display-title", help="Titre court lisible; l'alias canonique est préfixé automatiquement (80 caractères max)")
    parser.add_argument("--confirm-without-task", action="store_true", help="Explicit user confirmation to track without a formal task")
    parser.add_argument("--reassign", action="store_true", help="Transférer le suivi d'une session existante pour cette tâche vers ce nouveau runtime")
    parser.add_argument("--mission", required=True, help="Short mission context, separate from the task title")
    parser.add_argument("--url", default="http://127.0.0.1:8082")
    args = parser.parse_args()
    try:
        session_id = session_id_for(args.platform, args.session_id)
        result = connect(args.platform, session_id, args.alias, args.task, args.mission, args.url,
                         task_title=args.task_title,
                         confirm_without_task=args.confirm_without_task, reassign=args.reassign,
                         display_title=args.display_title)
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, RuntimeError, HTTPError, URLError, TimeoutError) as exc:
        # R29/T427 (demande TORC-CC10, 2026-11-18) : un 400 sans son corps est un trou de
        # diagnostic — le client affiche desormais le motif du service, verbatim.
        message = str(exc)
        if isinstance(exc, HTTPError):
            try:
                body = json.loads(exc.read().decode("utf-8", errors="replace"))
                detail = str(body.get("error") or "").strip()
                if detail:
                    message = f"{message} — motif du service : {detail}"
            except (ValueError, UnicodeDecodeError, OSError):
                pass
        print(json.dumps({"status": "error", "message": message[:400]}, ensure_ascii=False))
        raise SystemExit(2)


if __name__ == "__main__":
    main()
