"""R29 (incident 2026-11-18 -> 22, exigence exploitant : ZERO PERte) :
le chargement de l etat doit accepter les memoires longues au-dela de 20
quand le reglage memory_max_items le permet, et ne JAMAIS jeter les sessions
a cause d un transcript disparu.

Preuves d incident : etat reel 2026-11-22, sessions T427 (22 items), TORC (31),
T417 (30) -> load_error=ValueError, 0 session, "Configuration illisible".
"""
from __future__ import annotations

import json
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / 'TOOLS' / 'AGENT_SUPERVISOR' / 'scripts'
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import supervisor_service as m  # noqa: E402


def _memory_items(count):
    return [dict(kind="user_message", text=f"message {i}", observed_at="2026-11-18T00:00:00+00:00",
                 event_id=f"e{i}", event_index=i) for i in range(count)]


def _state_file(tmp_path, memory_items, settings_memory):
    state = {
        "model": m.DEFAULT_MODEL,
        "allow_cloud": False,
        "judge_settings": dict(m.DEFAULT_JUDGE_SETTINGS, memory_max_items=settings_memory),
        "sessions": [{
            "id": "11111111-1111-4111-8111-111111111111",
            "platform": "claude",
            "native_id": "absent-source-xyz-0001",
            "alias": "T999-CC01",
            "mission": "Session d essai chargement memoire longue",
            "display_title": "T999-CC01 TEST",
            "memory": memory_items,
            "alerts": [],
            "events": [],
        }],
    }
    path = tmp_path / 'state.json'
    path.write_text(json.dumps(state), encoding='utf-8')
    return path


def test_memoire_31_avec_reglage_100_charge_sans_perte(tmp_path):
    """LE cas de l incident : 31 items + reglage 100 => 8/8 doivent charger, memoire intacte."""
    path = _state_file(tmp_path, _memory_items(31), settings_memory=100)
    service = m.Supervisor(path, roots={'claude': [tmp_path], 'codex': [], 'agy': [], 'dsh': []})
    assert service.load_error is None, f"chargement refuse : {service.load_error}"
    assert len(service.sessions) == 1, "la session doit etre conservee"
    session = next(iter(service.sessions.values()))
    assert len(session["memory"]) == 31, "la memoire longue ne perd AUCUN element"


def test_memoire_au_dela_du_reglage_reste_refusee(tmp_path):
    """La protection demeure : au-dela du REGLAGE, la borne reste stricte."""
    path = _state_file(tmp_path, _memory_items(31), settings_memory=20)
    service = m.Supervisor(path, roots={'claude': [tmp_path], 'codex': [], 'agy': [], 'dsh': []})
    assert service.load_error is not None, "31 items avec reglage 20 : refus attendu (borne inchangee)"


def test_source_disparue_ne_fait_pas_tomber_les_autres(tmp_path):
    """Une session a source introuvable est conservee et signalee, jamais fatale."""
    state = {
        "judge_settings": dict(m.DEFAULT_JUDGE_SETTINGS),
        "sessions": [
            {"id": "22222222-2222-4222-8222-222222222222", "platform": "claude",
             "native_id": "absent-source-xyz-0002", "alias": "T999-CC02", "mission": "x",
             "memory": [], "alerts": [], "events": []},
            {"id": "33333333-3333-4333-8333-333333333333", "platform": "claude",
             "native_id": "absent-source-xyz-0003", "alias": "T999-CC03", "mission": "y",
             "memory": [], "alerts": [], "events": []},
        ],
    }
    path = tmp_path / 'state.json'
    path.write_text(json.dumps(state), encoding='utf-8')
    service = m.Supervisor(path, roots={'claude': [tmp_path], 'codex': [], 'agy': [], 'dsh': []})
    assert service.load_error is None, "le chargement doit survivre aux sources absentes"
    assert len(service.sessions) == 2, "les 2 sessions sont conservees"
