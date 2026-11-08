"""Safe, exact-session chat turns for consultative Veilleur alerts.

These adapters append a bounded, tool-restricted turn to the observed session.
They do not guarantee that an already-open terminal redraws in real time.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import uuid


class DeliveryError(RuntimeError):
    pass


class UnsupportedPlatform(DeliveryError):
    pass


def parse_user_choice(text: str):
    """Parse one explicit choice; choices 1 and 3 require a short reason/condition."""
    if not isinstance(text, str):
        return None
    match = re.fullmatch(r"\s*([123])(?:\s*(?:[-:|]|\u2014)\s*(.{3,500}))?\s*", text, re.S)
    if not match:
        return None
    choice, rationale = match.group(1), (match.group(2) or "").strip()
    if choice in ("1", "3") and len(rationale) < 3:
        return None
    return {"choice": choice, "rationale": rationale}


def short_title(alert: dict) -> str:
    categories = {
        "unsupported_success": "R\u00e9ussite sans preuve",
        "ignored_instruction": "Consigne potentiellement ignor\u00e9e",
        "unauthorized_action": "Action hors p\u00e9rim\u00e8tre",
        "contradiction": "Contradiction \u00e0 v\u00e9rifier",
        "repeated_attempt": "R\u00e9p\u00e9tition \u00e0 v\u00e9rifier",
    }
    category = alert.get("category")
    if category in categories:
        return categories[category]
    reason = " ".join(str(alert.get("reason", "Point \u00e0 v\u00e9rifier")).split())
    first = re.split(r"(?<=[.!?])\s+", reason, maxsplit=1)[0]
    return first[:76].rstrip(" ,:;\u2014-") or "Point \u00e0 v\u00e9rifier"


def initial_alert_message(alert: dict) -> str:
    level = "Alarme" if alert.get("severity") == "error" else "Avertissement"
    title = short_title(alert)
    description = " ".join(str(alert.get("reason", "\u00c0 v\u00e9rifier.")).split())[:220]
    evidence = " ".join(str(alert.get("evidence", "")).split())[:300]
    lines = [f"\u26a0\ufe0f {level} \u2014 {title} \u2014 {description}"]
    if evidence:
        lines.append(f"Citation exacte \u00e0 v\u00e9rifier : \u00ab {evidence} \u00bb")
    lines.extend([
        "R\u00e9ponds en une seule ligne, sans analyse d\u00e9taill\u00e9e ni action : `VEILLEUR_ACK`.",
        "Attends ensuite le choix explicite de l\u2019utilisateur (1, 2 ou 3).",
        "Choix utilisateur :",
        "1 \u2014 Ignorer : r\u00e9pondre `1 \u2014 motif` (motif obligatoire).",
        "2 \u2014 Examiner maintenant : r\u00e9pondre `2` ; challenger l'alerte, v\u00e9rifier le contexte et proposer une suite.",
        "3 \u2014 Reporter : r\u00e9pondre `3 \u2014 condition de reprise` (condition obligatoire).",
        "Seul le choix de l'utilisateur est pris en compte ; l'agent attend sans agir.",
    ])
    return "\n".join(lines)


def choice_message(alert: dict, choice: str, rationale: str) -> str:
    title = short_title(alert)
    if choice == "1":
        return (f"L\u2019utilisateur choisit 1 : ne pas traiter \u00ab {title} \u00bb. Motif : {rationale}. "
                "R\u00e9ponds uniquement `VEILLEUR_ACK`; ne relance pas ce signal sans fait nouveau.")
    if choice == "3":
        return (f"L\u2019utilisateur choisit 3 : reporter \u00ab {title} \u00bb. Condition de reprise : {rationale}. "
                "R\u00e9ponds uniquement `VEILLEUR_ACK`; n\u2019entreprends aucune action.")
    return (f"L\u2019utilisateur choisit 2 : examine maintenant l\u2019alerte \u00ab {title} \u00bb en contestant "
            "l\u2019hypoth\u00e8se et en v\u00e9rifiant le contexte et la citation. Donne bri\u00e8vement les faits, "
            "les incertitudes et une proposition de r\u00e9solution ou un conseil. N\u2019utilise aucun outil, "
            "ne lance rien et ne modifie aucun fichier. R\u00e9ponse courte, sans traiter l\u2019alerte comme v\u00e9rit\u00e9.")


def _uuid(native_id: str) -> str:
    try:
        value = str(uuid.UUID(native_id))
    except (ValueError, TypeError, AttributeError) as exc:
        raise DeliveryError("L\u2019envoi exige l\u2019UUID natif complet de la conversation") from exc
    if value != native_id.lower():
        raise DeliveryError("UUID de conversation non canonique")
    return value


def deliver(platform: str, native_id: str, message: str, *, timeout: int = 125,
            runner=subprocess.run):
    """Append one exact-session turn. DSH is deferred until its send API is proven."""
    if not isinstance(message, str) or not message.strip() or len(message) > 1800:
        raise DeliveryError("Message de supervision vide ou trop long")
    session_id = _uuid(native_id)
    if platform == "claude":
        exe = shutil.which("claude")
        if not exe:
            raise DeliveryError("CLI Claude Code introuvable")
        args = [exe, "--resume", session_id, "--print", "--max-turns", "1", "--tools", "",
                "--strict-mcp-config", "--disable-slash-commands", "--output-format", "json", message]
        expected_id_key, response_key = "session_id", "result"
    elif platform == "agy":
        exe = shutil.which("agy") or shutil.which("agy.exe")
        if not exe:
            raise DeliveryError("CLI Antigravity introuvable")
        args = [exe, "--mode", "plan", "--sandbox", "--conversation", session_id,
                "--print-timeout", "90s", "--output-format", "json", "--print", message]
        expected_id_key, response_key = "conversation_id", "response"
    elif platform == "dsh":
        raise UnsupportedPlatform("Envoi DSH mis de c\u00f4t\u00e9 : aucune API de file d\u2019attente active n\u2019est valid\u00e9e.")
    else:
        raise UnsupportedPlatform(f"Envoi direct non valid\u00e9 pour la plateforme {platform!r}.")

    try:
        result = runner(args, cwd=None, stdin=subprocess.DEVNULL, capture_output=True,
                        text=True, encoding="utf-8", errors="replace", timeout=timeout,
                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except subprocess.TimeoutExpired as exc:
        raise DeliveryError("D\u00e9lai d\u2019envoi d\u00e9pass\u00e9") from exc
    if result.returncode != 0:
        detail = " ".join(str(getattr(result, "stderr", "") or "").split())
        detail = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", detail)[:320]
        suffix = ": " + detail if detail else ""
        raise DeliveryError("CLI destinataire en echec (code " + str(result.returncode) + ")" + suffix)
    try:
        payload = json.loads(result.stdout)
    except (TypeError, json.JSONDecodeError) as exc:
        raise DeliveryError("R\u00e9ponse JSON du CLI invalide") from exc
    if not isinstance(payload, dict) or payload.get("is_error") or payload.get("status") == "ERROR":
        raise DeliveryError("R\u00e9ponse du CLI signal\u00e9e en erreur")
    if payload.get(expected_id_key) != session_id:
        raise DeliveryError("Le CLI n\u2019a pas confirm\u00e9 l\u2019identifiant de session cibl\u00e9")
    response = payload.get(response_key)
    if not isinstance(response, str) or not response.strip():
        raise DeliveryError("Le CLI n\u2019a pas retourn\u00e9 de r\u00e9ponse exploitable")
    return {"session_id": session_id, "response": response.strip()[:4000]}


def stop_claude_background(native_id: str, *, runner=subprocess.run):
    """Stop only the explicitly selected Claude session; keep its transcript."""
    session_id = _uuid(native_id)
    exe = shutil.which("claude")
    if not exe:
        raise DeliveryError("CLI Claude Code introuvable")
    options = dict(stdin=subprocess.DEVNULL, capture_output=True, text=True,
                   encoding="utf-8", errors="replace", timeout=20,
                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    listing = runner([exe, "agents", "--json"], **options)
    try:
        entries = json.loads(listing.stdout) if listing.returncode == 0 else []
        matches = [item for item in entries if item.get("sessionId") == session_id
                   and item.get("kind") == "background"]
    except (TypeError, ValueError, AttributeError) as exc:
        raise DeliveryError("Liste des sessions Claude invalide") from exc
    if len(matches) != 1 or not re.fullmatch(r"[0-9a-fA-F]{8}", str(matches[0].get("id", ""))):
        raise DeliveryError("Session Claude en arriere-plan non identifiee exactement")
    short_id = matches[0]["id"]
    result = runner([exe, "stop", short_id], **options)
    if result.returncode != 0 or "stopped " + short_id not in result.stdout.lower():
        detail = " ".join(str(result.stderr or result.stdout or "").split())[:250]
        raise DeliveryError("Arret Claude non confirme : " + detail)
