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
