"""R29/T427-CC02 (2026-11-17) : consigne a 3 constats.
1. TORC = agent de coordination (is_coordination_session).
2. Attach sans contrat -> fiche EXPLICITEMENT incomplete, jamais {} muette.
3. Veille d'inactivite : seuil 4 h coordination / criticite sinon ; constat unique.
Preuves exigees par T427 dans la reponse RECU : sorties brutes citees.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / 'TOOLS' / 'AGENT_SUPERVISOR' / 'scripts'
for candidate in (str(SCRIPTS), str(SCRIPTS / 'AGENT_WORKFLOW' / 'scripts')):
    pass
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))
WORKFLOW = ROOT / 'TOOLS' / 'AGENT_WORKFLOW' / 'scripts'
if str(WORKFLOW) not in sys.path:
    sys.path.insert(0, str(WORKFLOW))

from supervisor_service import (  # noqa: E402
    _inactivity_threshold_seconds, _seconds_since_last_activity,
    is_coordination_session, timestamp)
from connect_session import populate_mission_from_contract  # noqa: E402


def test_torc_est_coordination():
    """Constat 2 de T427 : is_coordination_session("TORC-CC10") == True (etait False)."""
    assert is_coordination_session({"alias": "TORC-CC10"}) is True
    assert is_coordination_session({"alias": "T000-CC10"}) is True
    assert is_coordination_session({"alias": "TORC-CC10", "task_id": "TORC"}) is True
    assert is_coordination_session({"alias": "T432-CDX02"}) is False


def test_fiche_torc_template_coordination():
    """Constat 1 (T427) : TORC sans contrat -> fiche REMPLIE par le template coordination
    (l'outil connait les regles de gouvernance d'un orchestrateur), jamais {} muette."""
    posts = []

    def fake_api_json(url, token=None, payload=None):
        posts.append(payload)
        return {"sessions": []}

    with patch('connect_session.api_json', fake_api_json):
        resultat = populate_mission_from_contract(
            "http://127.0.0.1:8082", "token", "session-test", "TORC",
            "TORC Orchestrateur hors catalogue", "coordination du projet")

    assert resultat is True, "la fiche coordination est POSEE"
    posted = posts[-1]
    structure = posted["structure"]
    assert structure, "structure jamais vide"
    assert "Coordination du projet" in structure["primary_goal"], "objectif d'orchestrateur auto-rempli"
    assert "(1) clotures par l'exploitant" in structure["criteria"], "les 5 regles de gouvernance sont dans la fiche"
    assert "Coordination (sans contrat par conception" in structure["milestone"]
    assert "Fiche coordination generique" in structure["unknowns"]


def test_torc_connect_serveur_isole(tmp_path):
    """Garde demande par TORC-CC10 (2026-11-18) : rattachement TORC-CCnn sur SERVEUR
    ISOLE (sous-process, port 8094, etat tmp), jamais contre 8081/8082.
    Fiche template posee, attach TORC-CCnn accepte."""
    import subprocess as _sub
    import json as _json
    import urllib.request as _urllib
    # Le serveur isole garde ses racines PAR DEFAUT (les vrais transcripts) : on attache
    # donc la session reelle d'essai (d9739b30) — source valide, alias TORC-CC22.
    native = "d9739b30-d0bb-46e9-87c5-243ffc255f90"
    server = _sub.Popen([sys.executable, str(ROOT / 'TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py'),
                          '--port', '8094', '--state', str(tmp_path / 'state.json')],
                         stdin=_sub.DEVNULL, stdout=_sub.DEVNULL, stderr=_sub.DEVNULL,
                         cwd=str(ROOT))
    try:
        base = 'http://127.0.0.1:8094'
        for _ in range(20):  # attente de /health (demarrage ~5-9 s)
            try:
                with _urllib.urlopen(base + '/health', timeout=2) as response:
                    _json.load(response)
                break
            except Exception:
                time.sleep(0.5)
        with _urllib.urlopen(base + '/api/supervision', timeout=10) as response:
            snapshot = _json.load(response)
        mission = ("Coordination du projet par TORC-CC22 : piloter les taches du catalogue "
                   "via le canal orchestrateur designe ; NE JAMAIS cloter un constat ni une tache soi-meme (regle 10)")
        token = snapshot.get('token')
        request = _urllib.Request(base + '/api/supervision', data=_json.dumps({
            'action': 'add', 'platform': 'claude', 'native_id': native,
            'alias': 'TORC-CC22', 'display_title': 'TORC-CC22 Orchestrateur',
            'mission': mission, 'task_ref': 'TORC',
            'task_title': 'Orchestrateur TORC-CC22 (essai)'}).encode(),
            headers={'Content-Type': 'application/json', 'X-Supervision-Token': str(token or '')}
        )
        with _urllib.urlopen(request, timeout=20) as response:
            result = _json.load(response)
        session_essai = next(s for s in result['sessions'] if s['native_id'] == native)
        assert session_essai.get('alias') == 'TORC-CC22', 'attach TORC-CCnn accepte sur isole'
        assert session_essai.get('source'), 'source unique confirmee'
    finally:
        server.terminate()
        server.wait(timeout=10)


def json_line(native):
    import json as _json
    return _json.dumps({'type': 'user', 'message': {'content': [
        {'type': 'text', 'text': 'ligne TORC'}]}, 'timestamp': '2026-11-18T00:00:00+00:00'})


def test_seuil_coordination_4h_autres_criticite():
    coordination = {"alias": "TORC-CC10", "task_id": "TORC", "state": "active",
                    "enabled": True, "closed": False, "alerts": [], "events": []}
    hors_catalogue = {"alias": "T432-CDX02", "task_id": "T432", "state": "active",
                      "enabled": True, "closed": False, "alerts": [], "events": []}
    assert _inactivity_threshold_seconds(coordination) == 4 * 3600.0, "seuil coordination 4 h"
    # T432 = contrat C2 -> 12 h (constat du contrat T432, criticite C2)
    assert _inactivity_threshold_seconds(hors_catalogue) == 12 * 3600.0


def test_inactivite_fait_un_constat_unique():
    from supervisor_service import Supervisor
    old = time.time() - 5 * 3600.0  # coordination -> seuil 4 h : depasse
    from datetime import datetime, timezone
    iso = datetime.fromtimestamp(old, tz=timezone.utc).isoformat()
    session = {"id": "s-torc", "alias": "TORC-CC10", "task_id": "TORC", "state": "active",
               "enabled": True, "closed": False, "alerts": [],
               "events": [{"event": "x", "at": iso}]}
    service = Supervisor.__new__(Supervisor)  # sans __init__ : le detecteur est pur
    service.sessions = {"s-torc": session}
    service._detect_inactive_sessions()
    alarmes = [a for a in session["alerts"] if a["category"] == "session_inactive"]
    assert len(alarmes) == 1, "un constat d'inactivite doit apparaitre"
    assert "aucune activite depuis plus de 4.0 h" in alarmes[0]["reason"]
    # idempotent : aucune deuxieme creation
    service._detect_inactive_sessions()
    assert len([a for a in session["alerts"] if a["category"] == "session_inactive"]) == 1
    # session fraiche : rien
    fraiche = {"id": "s-f", "alias": "T432-CDX02", "task_id": "T432", "state": "active",
               "enabled": True, "closed": False, "alerts": [],
               "events": [{"event": "x", "at": timestamp()}]}
    service.sessions = {"s-f": fraiche}
    service._detect_inactive_sessions()
    assert [a for a in fraiche["alerts"] if a["category"] == "session_inactive"] == []
