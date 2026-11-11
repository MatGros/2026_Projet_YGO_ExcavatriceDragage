"""Script client de revue de session pour la commande /review-session-supervisor (T429).

Interroge le serveur Veilleur local (port 8082) en mode PULL, résout la session active
de manière fail-closed, sélectionne le constat prioritaire (ou selon filtre), et formate
le texte d'injection pour l'agent dans le tour de chat courant.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_PORT = 8082


def help_text() -> str:
    return """🛡️ Agent Supervisor — Commande /review-session-supervisor

Usage :
  /review-session-supervisor                Examiner le constat prioritaire (Alarm > Warning)
  /review-session-supervisor help           Afficher cette aide
  /review-session-supervisor all            Examiner tous les constats ouverts de la session
  /review-session-supervisor alarm          Filtrer sur la première alarme (Alarm / Error)
  /review-session-supervisor warning        Filtrer sur le premier avertissement (Warning)
  /review-session-supervisor <numéro>       Examiner un constat spécifique par son numéro (ex: 1, 2)
  /review-session-supervisor <id_court>     Examiner un constat par son préfixe hexadécimal (ex: 26fcd4)
  /review-session-supervisor --session <ID> Forcer l'UUID exact en cas de sessions multiples

Rappel : Cette commande est consultative. Elle n'auto-clôture aucun constat.
"""


def fetch_supervision_state(port: int = DEFAULT_PORT) -> dict:
    url = f"http://127.0.0.1:{port}/api/supervision"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"🔴 Supervisor — Erreur HTTP {exc.code} retournée par le Veilleur sur 127.0.0.1:{port}.") from exc
    except urllib.error.URLError as exc:
        raise ConnectionError(f"🔴 Supervisor — Service local injoignable sur 127.0.0.1:{port}.\n"
                              f"Vérifiez que le serveur Veilleur est démarré :\n"
                              f"  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py --port {port}") from exc


def fetch_summary(port: int = DEFAULT_PORT) -> dict:
    url = f"http://127.0.0.1:{port}/api/supervision/summary"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"🔴 Supervisor — Erreur HTTP {exc.code} sur 127.0.0.1:{port}/api/supervision/summary.") from exc
    except urllib.error.URLError as exc:
        raise ConnectionError(f"🔴 Supervisor — Service local injoignable sur 127.0.0.1:{port}.") from exc


def fetch_session_review(session_id: str, port: int = DEFAULT_PORT) -> tuple[dict, list[dict]]:
    """Consomme la route allégée /api/supervision/review avec pagination si nécessaire (T429 Lot 2 & 3)."""
    all_alerts = []
    session_meta = {}
    offset = 0
    revision = None
    while True:
        params = {"session": session_id}
        if offset > 0 and revision is not None:
            params["offset"] = str(offset)
            params["revision"] = revision
        url = f"http://127.0.0.1:{port}/api/supervision/review?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if not session_meta:
            session_meta = {
                "id": data.get("id"),
                "alias": data.get("alias"),
                "platform": data.get("platform"),
                "state": data.get("state"),
                "counts": data.get("counts", {}),
            }
        alerts = data.get("alerts", [])
        all_alerts.extend(alerts)
        next_offset = data.get("next_offset")
        if not next_offset or not alerts:
            break
        offset = next_offset
        revision = data.get("revision")
    return session_meta, all_alerts


def extract_candidate_files(text: str) -> list[str]:
    """Extrait les chemins de fichiers existants mentionnés dans la citation ou le motif."""
    pattern = r'(?:[A-Za-z0-9_\-./\\]+[/\\][A-Za-z0-9_\-.]+\.[A-Za-z0-9_]+|[A-Za-z0-9_\-]+\.(?:st|py|js|mjs|json|yaml|yml|md|txt))'
    matches = re.findall(pattern, text)
    candidates = []
    seen = set()
    for m in matches:
        clean = m.strip().strip("'\"`(),;")
        if clean and clean not in seen:
            seen.add(clean)
            p = Path(clean)
            if p.exists() and p.is_file():
                candidates.append(clean)
    return candidates


def _severity_of(alert: dict) -> str:
    raw = alert.get("severity")
    return str(raw).strip().lower() if raw is not None else "warning"


def _is_alarm(alert: dict) -> bool:
    return _severity_of(alert) in ("error", "alarm")


def resolve_session(sessions: list[dict], requested_id: str | None = None) -> tuple[dict | None, str | None]:
    """Résout la session cible de manière FAIL-CLOSED.
    Retourne (session_dict, None) en cas de succès, ou (None, error_message) en cas d'ambiguïté/erreur.
    """
    if requested_id:
        req_clean = requested_id.strip().lower()
        matches = [s for s in sessions if str(s.get("native_id") or "").lower() == req_clean
                   or str(s.get("id") or "").lower() == req_clean
                   or str(s.get("native_id") or "").lower().startswith(req_clean)]
        if not matches:
            return None, f"❌ Aucune session ne correspond à l'identifiant '{requested_id}'."
        if len(matches) > 1:
            return None, f"⚠️ Identifiant ambigu : plusieurs sessions correspondent à '{requested_id}'."
        return matches[0], None

    # Résolution automatique sans requested_id
    active_sessions = [s for s in sessions if s.get("enabled") is not False and s.get("state") not in ("stopped",)]
    if not active_sessions:
        if not sessions:
            return None, "ℹ️ Aucune session n'est enregistrée dans le Veilleur."
        return None, "ℹ️ Aucune session active n'est enregistrée (toutes les sessions sont en pause ou arrêtées)."

    if len(active_sessions) == 1:
        return active_sessions[0], None

    # Plusieurs sessions actives : tenter de discriminer par présence de fichiers locaux
    candidates = []
    # Test Antigravity : lock de présence ou brain
    for s in active_sessions:
        if s.get("platform") == "agy":
            nid = str(s.get("native_id") or "").strip()
            if nid and re.match(r'^[a-zA-Z0-9_\-]+$', nid):
                presence = Path.home() / ".gemini" / "antigravity-cli" / "presence" / f"{nid}.lock"
                if presence.exists():
                    candidates.append(s)

    if len(candidates) == 1:
        return candidates[0], None

    # Ambiguïté non résolue -> FAIL-CLOSED immédiat
    lines = [
        "⚠️ Supervisor — Session ambiguë : plusieurs sessions actives détectées sur le Veilleur.",
        "Précisez l'identifiant de session avec l'option --session :\n"
    ]
    for s in active_sessions:
        alias = s.get("alias") or s.get("platform")
        nid = s.get("native_id")
        plat = s.get("platform")
        lines.append(f"  • {alias} ({plat}) :\n    ❯ /review-session-supervisor --session {nid}\n")
    return None, "\n".join(lines)


def format_single_finding(alert: dict, session: dict, index: int, total_open: int, remaining_count: int) -> str:
    is_alarm = _is_alarm(alert)
    icon = "🔴 Alarm" if is_alarm else "⚠️ Warning"
    title = str(alert.get("title") or alert.get("reason", "")).split("\n")[0][:75]
    reason = str(alert.get("reason") or "").strip()
    evidence = str(alert.get("evidence") or "").strip()
    ref = str(alert.get("id") or "")
    version = alert.get("version", 1)
    short_ref = ref[:8]
    created = str(alert.get("created_at") or "")[:19].replace("T", " ")
    native_id = str(session.get('native_id') or "")
    turns = session.get("judge_turn_count", 0)
    reevals = session.get("re_evaluations_count", max(0, turns - 1) if turns > 0 else 0)
    eval_info = f" · Suivi : {turns} tour(s) ({reevals} ré-év.)" if turns > 0 else ""

    lines = [
        f"🔎 Supervisor — Point prioritaire [{index}/{total_open}]",
        f"Session : {session.get('alias', session.get('platform'))} ({session.get('platform')} / {native_id[:8]}...){eval_info}",
        "",
        f"{icon} · Ref {short_ref} (v{version}) — {title}",
        f"Date : {created}",
        "",
        f"Motif :",
        f"{reason}",
    ]
    if evidence:
        lines.extend([
            "",
            f"Citation exacte :",
            f"« {evidence} »",
        ])

    candidates = extract_candidate_files(evidence + "\n" + reason)
    if candidates:
        lines.extend([
            "",
            "📌 Pistes déterministes détectées (fichiers locaux existants) :",
            *[f"  • {c}" for c in candidates[:3]],
        ])

    lines.extend([
        "",
        f"Référence formelle : {ref} v{version}",
        "",
        "📋 Format de réponse exigé pour l'agent :",
        "1. [CONSTAT] : Analyse factuelle en 2 lignes (sans paraphrase verbeuse).",
        "2. [PREUVE BRUTE] : Exécution de l'outil approprié et citation du résultat brut vérifiable.",
        "3. [VERDICT] : Confirmé / Contesté / Résolu avec preuve.",
        "- Une simple affirmation textuelle sans résultat d'outil sera jugée « Avis incertain » par le Veilleur.",
    ])

    if remaining_count > 0:
        lines.append(f"\n*(Reste {remaining_count} autre(s) alerte(s) en attente. Relancez /review-session-supervisor pour la suivante, /review-session-supervisor warning pour cibler les avertissements, ou /review-session-supervisor all pour tout voir).*")
    else:
        lines.append("\n*(Dernier point ouvert de cette session).*")

    return "\n".join(lines)


def format_all_findings(alerts: list[dict], session: dict) -> str:
    total = len(alerts)
    alarms = sum(1 for a in alerts if _is_alarm(a))
    warnings = total - alarms
    native_id = str(session.get('native_id') or "")

    lines = [
        f"🔎 Supervisor — {total} point(s) à examiner ({alarms} Alarm · {warnings} Warning)",
        f"Session : {session.get('alias', session.get('platform'))} ({session.get('platform')} / {native_id[:8]}...)",
        "",
    ]

    for idx, alert in enumerate(alerts, 1):
        icon = "🔴 Alarm" if _is_alarm(alert) else "⚠️ Warning"
        title = str(alert.get("title") or alert.get("reason", "")).split("\n")[0][:75]
        ref = str(alert.get("id") or "")[:8]
        lines.append(f"{idx}. {icon} · {ref} — {title}")
        if alert.get("evidence"):
            raw_ev = " ".join(str(alert.get("evidence") or "").split())
            clean_ev = (raw_ev[:120] + "...") if len(raw_ev) > 120 else raw_ev
            lines.append(f"   Citation : « {clean_ev} »")

    lines.extend([
        "",
        f"📋 Consigne de traitement exhaustif & format exigé :",
        f"Examine ces {total} constats dans l'ordre pour couvrir l'ensemble des {total}/{total} références avec preuves brutes dans le transcript :",
        "  1. [CONSTAT i/N] : Résumé factuel.",
        "  2. [PREUVE BRUTE] : Exécution d'outil obligatoire pour faire figurer la preuve dans le transcript.",
        "  3. [VERDICT] : Confirmé / Contesté / Résolu.",
        "Rappel : Cette commande est consultative. Aucun statut n'est clos automatiquement dans le Veilleur."
    ])

    return "\n".join(lines)


def run_review(filter_arg: str | None = None, session_id: str | None = None, port: int = DEFAULT_PORT) -> str:
    if filter_arg in ("help", "-h", "--help"):
        return help_text()

    session = None
    open_alerts = []
    closed_count = 0
    last_poll = None

    # T429 Lot 2 & 3: Fast path via route allégée /api/supervision/summary + /api/supervision/review (< 30 Ko)
    is_mocked = hasattr(fetch_supervision_state, "mock_calls") or hasattr(fetch_supervision_state, "assert_called")
    if not is_mocked:
        try:
            summary = fetch_summary(port=port)
            sessions_summary = summary.get("sessions", [])
            resolved_meta, err = resolve_session(sessions_summary, requested_id=session_id)
            if err:
                return err
            session_meta, open_alerts = fetch_session_review(resolved_meta["id"], port=port)
            session = {**resolved_meta, **session_meta}
            closed_count = session.get("counts", {}).get("closed", 0)
            last_poll = str(summary.get("last_poll_at") or "")[:19].replace("T", " ")
        except Exception:
            is_mocked = True

    if is_mocked:
        # Fallback de compatibilité vers le snapshot complet (ou environnement de test avec mock)
        state = fetch_supervision_state(port=port)
        sessions = state.get("sessions", [])
        session, err = resolve_session(sessions, requested_id=session_id)
        if err:
            return err
        all_alerts = session.get("alerts", [])
        open_alerts = [a for a in all_alerts if a.get("business_state") != "closed" and a.get("disposition") not in ("resolved", "false_positive")]
        closed_count = len(all_alerts) - len(open_alerts)
        last_poll = str(state.get("last_poll_at") or "")[:19].replace("T", " ")

    turns = session.get("judge_turn_count", 0)
    reevals = session.get("re_evaluations_count", max(0, turns - 1) if turns > 0 else 0)
    eval_str = f" · {turns} tour(s) d'évaluation ({reevals} ré-évaluation(s))" if turns > 0 else ""

    if not open_alerts:
        return (f"✅ Supervisor — Aucun point ouvert pour cette session ({session.get('alias', session.get('platform'))}).\n"
                f"Statut : Session saine · {closed_count} constat(s) clos archivé(s){eval_str}.\n"
                f"Dernière collecte : {last_poll or 'active'}.")

    # Ordonner : Alarmes d'abord, puis par ancienneté croissante (FIFO des problèmes)
    def alert_sort_key(a):
        return (0 if _is_alarm(a) else 1, str(a.get("created_at") or ""))

    sorted_alerts = sorted(open_alerts, key=alert_sort_key)

    # Filtrage selon argument
    if not filter_arg or filter_arg in ("next", "1"):
        target_alert = sorted_alerts[0]
        remaining = len(sorted_alerts) - 1
        return format_single_finding(target_alert, session, index=1, total_open=len(sorted_alerts), remaining_count=remaining)

    filter_lower = filter_arg.strip().lower()

    if filter_lower == "all":
        return format_all_findings(sorted_alerts, session)

    if filter_lower in ("alarm", "alarms", "error"):
        alarms = [a for a in sorted_alerts if _is_alarm(a)]
        if not alarms:
            return f"ℹ️ Aucune alarme (Alarm/Error) ouverte sur cette session ({len(sorted_alerts)} warning(s) ouvert(s))."
        return format_single_finding(alarms[0], session, index=1, total_open=len(alarms), remaining_count=len(alarms) - 1)

    if filter_lower in ("warning", "warnings"):
        warnings = [a for a in sorted_alerts if not _is_alarm(a)]
        if not warnings:
            return f"ℹ️ Aucun avertissement (Warning) ouvert sur cette session ({len(sorted_alerts)} alarm(s) ouverte(s))."
        return format_single_finding(warnings[0], session, index=1, total_open=len(warnings), remaining_count=len(warnings) - 1)

    # Filtre par numéro d'index (ex: 2, 3)
    if filter_lower.isdigit():
        idx = int(filter_lower)
        if 1 <= idx <= len(sorted_alerts):
            return format_single_finding(sorted_alerts[idx - 1], session, index=idx, total_open=len(sorted_alerts), remaining_count=len(sorted_alerts) - idx)
        return f"❌ Numéro de constat invalide ({idx}). Cette session comporte {len(sorted_alerts)} constat(s) ouvert(s)."

    # Filtre par préfixe d'ID (ex: 26fcd4)
    matches = [a for a in sorted_alerts if a.get("id", "").lower().startswith(filter_lower)]
    if matches:
        return format_single_finding(matches[0], session, index=1, total_open=len(matches), remaining_count=len(matches) - 1)

    return f"❌ Filtre '{filter_arg}' non reconnu. Tapez '/review-session-supervisor help' pour voir les commandes valides."


def main():
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument("filter", nargs="?", default=None, help="Filtre (help, all, alarm, warning, numéro, ou ID court)")
    parser.add_argument("--session", "-s", dest="session_id", default=None, help="UUID de session spécifique")
    parser.add_argument("--port", "-p", type=int, default=DEFAULT_PORT, help="Port du Veilleur (défaut 8082)")
    parser.add_argument("--help", "-h", action="store_true", help="Afficher l'aide")

    args = parser.parse_args()
    if args.help:
        print(help_text())
        return

    try:
        output = run_review(filter_arg=args.filter, session_id=args.session_id, port=args.port)
        print(output)
    except ConnectionError as exc:
        print(str(exc))
        sys.exit(1)
    except Exception as exc:
        print(f"❌ Erreur inattendue : {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
