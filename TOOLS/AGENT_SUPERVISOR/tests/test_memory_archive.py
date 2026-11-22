"""R29 (2026-11-22) : garde-fous de la memoire longue durable.
- archive JSONL : append/recherche/compteurs, texte INTEGRAL (zero troncature a l'ecriture)
- resume de fenetre recyclee : concis, <= 3000 car, JAMAIS une troncature brute
- validate_memory accepte les entrees kind=summary et refuse le reste
- migration idempotente : etat existant -> archive (zero perte)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / 'TOOLS' / 'AGENT_SUPERVISOR' / 'scripts'
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import memory_archive  # noqa: E402
import supervisor_service as m  # noqa: E402


def test_archive_append_search_stats(tmp_path, monkeypatch):
    monkeypatch.setattr(memory_archive, 'ROOT', tmp_path)
    monkeypatch.setattr(memory_archive, 'MEMORY_DIR', tmp_path / 'agent-memory')
    long_text = 'debut ' + ('x' * 5000) + ' aiguille-rare fin'
    memory_archive.append('S1', [
        {'role': 'user', 'text': long_text, 'observed_at': '2026-11-22T10:00:00+00:00',
         'event_id': 'e1'},
        {'role': 'assistant', 'text': 'autre message sans aiguille',
         'observed_at': '2026-11-22T10:01:00+00:00', 'event_id': 'e2'},
    ])
    stats = memory_archive.stats('S1')
    assert stats['lines'] == 2
    assert stats['chars'] >= 5000, 'le texte est archive INTEGRAL'
    found = memory_archive.search('S1', 'aiguille-rare', limit=5)
    assert len(found['matches']) == 1
    assert 'aiguille-rare' in found['matches'][0]['snippet']
    assert memory_archive.search('S1', 'introuvable-xyz')['matches'] == []


def test_resume_fenetre_borne_et_sans_troncature_muette():
    items = [dict(role='user', text='message %d ' % i + 'z' * 4000, event_id='e%d' % i)
             for i in range(12)]
    summary = m.build_window_summary(items)
    assert len(summary) <= m.MEMORY_SUMMARY_MAX_CHARS
    assert summary.startswith('Resume fenetre recyclee (12 message(s))')
    assert summary.count('- [user]') == 12, 'chaque message presente dans le resume'
    assert '[…]' in summary, 'un marqueur signale la compression (jamais silencieuse)'


def test_validate_memory_accepte_resume_refuse_inconnu():
    valid = [
        dict(kind='user_message', text='m', observed_at='2026-11-22T00:00:00+00:00'),
        dict(kind='summary', text='Resume 12 msg', observed_at='2026-11-22T00:00:00+00:00'),
    ]
    assert len(m.Supervisor._validate_memory(valid, 100)) == 2
    bad = [dict(kind='autre', text='m', observed_at='2026-11-22T00:00:00+00:00')]
    try:
        m.Supervisor._validate_memory(bad, 100)
    except ValueError:
        pass
    else:
        raise AssertionError('kind inconnu doit etre refuse')


def test_recyclage_cree_un_resume_dans_la_memoire():
    service = m.Supervisor.__new__(m.Supervisor)
    service.judge_settings = dict(m.DEFAULT_JUDGE_SETTINGS, memory_max_items=100)
    session = dict(id='S-REC', memory=[], events=[], alerts=[], framing=[])
    popped = [dict(role='user', text='objectif: stabiliser', event_id='e1', event_index=1),
              dict(role='assistant', text='decision: cache TTL', event_id='e2', event_index=2)]
    service._recycle_context(session, popped)
    entries = [item for item in session['memory'] if item['kind'] == 'summary']
    assert len(entries) == 1
    assert 'objectif: stabiliser' in entries[0]['text']
    assert 'decision: cache TTL' in entries[0]['text']
    assert any(event.get('kind') == 'window_recycled' for event in session['events'])


def test_flap_poll_amorti_avant_source_error():
    """R29 : 1-2 incidents transitoires ne crient pas 'source_error' ; le 3e oui.
    Constat exploitant 2026-11-22 : statusline 'EN ERREUR (source_error)' d'une seconde."""
    session = dict(id='S-FLAP', state='active', events=[])
    m._record_poll_failure(session, PermissionError('fichier en ecriture'))
    m._record_poll_failure(session, PermissionError('fichier en ecriture'))
    assert session['state'] == 'active', 'deux incidents consecutifs : etat conserve (flap amorti)'
    m._record_poll_failure(session, PermissionError('fichier en ecriture'))
    assert session['state'] == 'source_error', 'trois incidents consecutifs : source_error annonce'
    m._reset_poll_failures(session)
    assert session['_poll_failures'] == 0


def test_migration_idempotente_et_sans_perte(tmp_path, monkeypatch):
    monkeypatch.setattr(memory_archive, 'ROOT', tmp_path)
    monkeypatch.setattr(memory_archive, 'MEMORY_DIR', tmp_path / 'agent-memory')
    service = m.Supervisor.__new__(m.Supervisor)
    service.judge_settings = dict(m.DEFAULT_JUDGE_SETTINGS)
    session = dict(id='S-MIG', events=[], alerts=[], framing=[], memory=[
        dict(kind='user_message', text='un', observed_at='2026-11-22T00:00:00+00:00', event_id='m1'),
        dict(kind='user_message', text='deux', observed_at='2026-11-22T00:01:00+00:00', event_id='m2'),
        dict(kind='summary', text='Resume deja la', observed_at='2026-11-22T00:02:00+00:00', event_id='r1'),
    ])
    service.sessions = {'S-MIG': session}
    service._migrate_memory_archive()
    stats = memory_archive.stats('S-MIG')
    assert stats['lines'] == 2, 'les 2 user_message sont archives, le resume reste en etat'
    service._migrate_memory_archive()
    assert memory_archive.stats('S-MIG')['lines'] == 2, 'idempotent : aucune duplication'
