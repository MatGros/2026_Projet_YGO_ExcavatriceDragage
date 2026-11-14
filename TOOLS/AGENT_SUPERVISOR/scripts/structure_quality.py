#!/usr/bin/env python3
"""Verdict MECANIQUE sur la fiche structuree d'une session (T429).

L exploitant doit voir, pour chaque attribut : la valeur, sa source, et son etat.
Aucun modele : tout se deduit du contrat, de la mission et de la structure.

Etats par attribut :
  renseigne      : valeur presente, source confirmee
  deduit         : valeur presente, source derivee (contrat / mission) -> a confirmer
  a_completer    : valeur absente
  hors_perimetre : la valeur sort du perimetre autorise par le contrat
  perime         : la valeur est anterieure a la derniere revision du contrat
  hors_sujet     : la valeur ne renvoie aucun livrable de l objectif
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"

CONTRACT_FIELDS = ("scope.allowed", "scope.forbidden")

# Valeurs generiques : produites par defaut, sans information pour l exploitant.
GENERIC_VALUES = (
    "selon avancement session",
    "execution cadree de la tache",
    "a completer",
    "a completer par l exploitant",
    "-",
)
VALUE_LIMIT = 4000


def _is_generic(value: str) -> bool:
    text = str(value or "").strip().lower()
    if not text:
        return True
    if text in GENERIC_VALUES:
        return True
    return text.startswith("contrat valide") or text.startswith("criticite c") or text.startswith("selon ")


VALUE_CAPS = (300, 400, 1000, 2000, 4000)


def _is_truncated(value: str) -> bool:
    """Valeur coupee sans marqueur de troncature.

    Deux signatures : des crochets non equilibres (repr d un dict/list coupe),
    ou une valeur arrivee au cap de l auto-remplissage sans terminateur.
    """
    text = str(value or "").rstrip()
    if not text:
        return False
    if text.count("[") != text.count("]") or text.count("{") != text.count("}"):
        return True
    if len(text) in VALUE_CAPS and not text.endswith(("…", "...", ".", ")", "]", "}", "'", '"')):
        return True
    return False


def contract_for(task_id: str) -> Path | None:
    if not task_id:
        return None
    for folder in sorted(TASKS_DIR.glob(f"{task_id}*")):
        if not folder.is_dir():
            continue
        for candidate in sorted(folder.glob("*CONTRAT*.yaml")):
            return candidate
    return None


def contract_data(task_id: str) -> dict:
    path = contract_for(task_id)
    if path is None:
        return {}
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, ValueError, ImportError):
        return {}
    return data if isinstance(data, dict) else {}


def _mtime(path: Path | None) -> float:
    try:
        return path.stat().st_mtime if path else 0.0
    except OSError:
        return 0.0


def quality(session) -> dict:
    """Verdict par attribut + verdict de la fiche (cadrage)."""
    structure = session.get("mission_structure") or {}
    task_id = str(session.get("task_id") or "")
    data = contract_data(task_id)
    contract = (data.get("contract") or {}) if isinstance(data, dict) else {}
    allowed = [str(x) for x in ((contract.get("scope") or {}).get("allowed") or [])]
    forbidden = [str(x) for x in ((contract.get("scope") or {}).get("forbidden") or [])]
    livrables = contract.get("livrables") or []
    markers = []
    for livrable in livrables:
        if isinstance(livrable, dict):
            markers.append(str(livrable.get("id") or ""))
            markers.append(str(livrable.get("path") or ""))
        else:
            markers.append(str(livrable))
    markers = [m for m in markers if m]

    sources = {}
    try:
        import sys
        scripts_dir = Path(__file__).resolve().parents[2] / "AGENT_WORKFLOW" / "scripts"
        if str(scripts_dir) not in sys.path:
            sys.path.insert(0, str(scripts_dir))
        import task_scope
        from supervisor_service import parse_mission_attributes  # noqa: F401  (presence du service)
    except Exception:
        pass
    try:
        import supervisor_service
        sources = supervisor_service.structure_proposal(session)
    except Exception:
        sources = {}

    contract_path = contract_for(task_id)
    contract_stamp = _mtime(contract_path)
    structure_stamp = _mtime(Path(session.get("source") or "")) if False else 0.0

    items = []
    counts = {"renseigne": 0, "deduit": 0, "a_completer": 0, "alerte": 0}
    for field, info in sources.items():
        label = info.get("label", field)
        value = str(info.get("value") or "").strip()
        source = str(info.get("source") or "")
        alerts = []
        if not value:
            state = "a_completer"
        elif source == "confirmé":
            state = "renseigne"
        else:
            state = "deduit"
        # T429 : une valeur ecrite par l auto-remplissage n est PAS confirmee.
        if source == "confirmé" and str(session.get("mission_structure_origin") or "exploitant") != "exploitant":
            origin = str(session.get("mission_structure_origin"))
            source = f"déduit ({origin})"
            state = "deduit"
        if value and forbidden:
            for denied in forbidden:
                base = denied[:-3] if denied.endswith("/**") else denied
                if base and base.lower() in value.lower():
                    alerts.append(f"la valeur mentionne un chemin interdit ({denied})")
                    state = "hors_perimetre"
                    break
        if value and allowed and state == "deduit":
            for allowed_path in allowed:
                base = allowed_path[:-3] if allowed_path.endswith("/**") else allowed_path
                if base and base.lower() in value.lower() and not any(
                        (denied[:-3] if denied.endswith("/**") else denied).lower() in value.lower()
                        for denied in forbidden):
                    alerts.append(f"la valeur cite le perimetre autorise ({allowed_path})")
                    break
        if value and _is_generic(value) and not source.startswith("confirm"):
            alerts.append("valeur generique : elle n apporte aucune information")
            state = "a_completer"
        if value and _is_truncated(value):
            alerts.append("valeur tronquee sans marqueur : lire la source pour la fin")
            state = "hors_perimetre"
        alias = str(session.get("alias") or "").strip()
        title = str((session.get("mission") or "").splitlines()[0] if session.get("mission") else "").strip()
        if value and field in ("primary_goal", "current_goal") and (
                (alias and value.strip().upper().startswith(alias.upper() + " ")) or
                (title and title and value.strip().upper().startswith(title.upper())) or
                (alias and value.strip().upper() == alias.upper()) or
                (title and value.strip().upper() == title.upper())):
            alerts.append("la valeur reprend le titre de session : ce n est pas un objectif")
            state = "hors_sujet"
        if value and markers and field in ("primary_goal", "current_goal", "scope_permissions", "criteria", "milestone"):
            if not any(marker.lower() in value.lower() for marker in markers):
                alerts.append("la valeur ne renvoie aucun livrable de l objectif")
                state = "hors_sujet"
        counts["renseigne" if state == "renseigne" else ("deduit" if state == "deduit" else ("a_completer" if state == "a_completer" else "alerte"))] += 1
        items.append({"champ": field, "label": label, "valeur": value, "source": source,
                      "etat": state, "alertes": alerts})

    # Reference de tache : doit correspondre a la tache dont le contrat alimente la fiche.
    declared_ref = str((structure.get("task_ref") or "").strip().upper())
    contract_ref = str((contract.get("task_id") or "")).strip().upper()
    if declared_ref and contract_ref and declared_ref != contract_ref:
        for item in items:
            if item["champ"] == "task_ref":
                item["alertes"].append(f"la reference declaree ({declared_ref}) ne correspond pas "
                                       f"au contrat utilise ({contract_ref})")
                item["etat"] = "hors_sujet"

    covered = []
    uncovered = []
    for livrable in livrables:
        if isinstance(livrable, dict):
            marker = str(livrable.get("id") or livrable.get("path") or "")
            zone = str(livrable.get("path") or "")
        else:
            marker, zone = str(livrable), ""
        hit = False
        for item in items:
            text = item["valeur"].lower()
            if marker and marker.lower() in text:
                hit = True
                break
            if zone and zone.split("/")[0].lower() in text:
                hit = True
                break
            if item.get("couvre") and marker in [str(x) for x in item["couvre"]]:
                hit = True
                break
        (covered if hit else uncovered).append(marker)

    return {
        "attributs": items,
        "compteurs": counts,
        "livrables_couverts": covered,
        "livrables_non_couverts": uncovered,
        "alertes": [f"{item['label']} : {alerte}" for item in items for alerte in item["alertes"]],
        "verdict": ("cadrage incomplet" if counts["a_completer"] else
                    ("cadrage alerte" if counts["alerte"] else
                     ("cadrage derives, a confirmer" if counts["deduit"] else "cadrage complet"))),
    }
