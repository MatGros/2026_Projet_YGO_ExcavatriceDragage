"""AUDIT R29/T429 (demande exploitant 2026-11-18) : le Superviseur est-il ACTIF et bien
relaye, sur une SESSION FICTIVE sur serveur ISOLE (jamais contre le 8082 reel) ?

Verifies ici :
1. Session fictive (transcript synthetique) -> rattachement, observation, memoire longue
   (doit croitre jusqu'a la borne, plus de 20), contextes, journal de session, evenements.
2. Inactivite : session fictive idle -> constat session_inactive (seuil coordination 4 h).
3. Journal/service : chaque etape tracee.
Usage : python TOOLS/AGENT_SUPERVISOR/tests/audit_fictif.py
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / 'TOOLS' / 'AGENT_SUPERVISOR' / 'scripts'
for p in (str(SCRIPTS),):
    if p not in sys.path:
        sys.path.insert(0, p)

from supervisor_service import Supervisor, memory_limit, validate_judge_settings  # noqa: E402
from supervisor_service import is_coordination_session, _inactivity_threshold_seconds  # noqa: E402


def log(message):
    print(message, flush=True)


def make_transcript(folder: Path, sid: str, messages: int, ts_offset=0) -> Path:
    """Transcript Claude synthetique : N messages user/assistant alteres."""
    file = folder / f"{sid}.jsonl"
    lines = []
    for index in range(messages):
        who = 'user' if index % 2 == 0 else 'assistant'
        text = f"Message synthetique {index} : contenu d'audit de fonctionnement {sid[:8]}"
        lines.append(json.dumps({'type': who, 'message': {'content': [
            {'type': 'text', 'text': text}]},
            'timestamp': '2026-11-17T00:00:00+00:00'}))
    file.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return file


def append_lines(folder: Path, sid: str, messages: int) -> None:
    """R29 : APPEND de lignes fraiches (date courante) — le collecteur lit depuis son
    checkpoint EOF : un append, pas une reecriture identique (lecon de l'audit)."""
    file = folder / f"{sid}.jsonl"
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    lines = []
    for index in range(messages):
        who = 'user' if index % 2 == 0 else 'assistant'
        lines.append(json.dumps({'type': who, 'message': {'content': [
            {'type': 'text', 'text': f"Audit append {time.time():.3f} #{index}"}]},
            'timestamp': now}))
    with open(file, 'a', encoding='utf-8') as handle:
        handle.write('\n'.join(lines) + '\n')


def main():
    verdicts = []
    scratch = Path(tempfile.mkdtemp(prefix='t429_audit_fictif_'))
    folder = scratch / 'claude-roots'
    folder.mkdir()
    sid = '7f3c0000-0000-4000-8000-a0d1facf0001'
    make_transcript(folder, sid, messages=4)

    state = scratch / 'state.json'
    service = Supervisor(state, roots={'claude': [folder], 'codex': [], 'agy': [], 'dsh': []},
                         poll_interval=0.2, strict_assignments=True, persist_chat=False)
    settings = validate_judge_settings({'memory_max_items': 100})
    service.judge_settings = settings
    service.command({'action': 'add', 'platform': 'claude', 'native_id': sid,
                     'alias': 'T000-CC01', 'mission': 'Audit fictif : session de essai du service',
                     'display_title': 'T000-CC01 AUDIT FICTIF'})
    service.command({'action': 'start'})
    session = next(value for value in service.sessions.values() if value['native_id'] == sid)
    log(f"1. attach : etat={session['state']} source={'oui' if session.get('source') else 'non'}")
    verdicts.append(('attach', session.get('source') is not None and session['state'] == 'active'))

    service._wake.set()
    time.sleep(1.5)
    log(f"2. attache + checkpoint EOF (les messages d'avant ne sont pas relus — voulu) "
        f"fenetre={len(session.get('context') or [])}")

    # ajout de messages -> observation + memoire longue doivent croitre ensemble
    for _ in range(3):
        append_lines(folder, sid, 5)
        time.sleep(0.6)
    service._wake.set()
    time.sleep(2.5)
    memoire = len(session.get('memory') or [])
    observes = session.get('messages_observed', 0)
    borne = memory_limit(service.judge_settings)
    log(f"3. apres 15 appends : messages_observed={observes} fenetre={len(session.get('context') or [])} "
        f"memoire={memoire}/{borne} (borne reglable {settings['memory_max_items']}, bornes code 20..{500})")
    verdicts.append(('observation', observes >= 10 and len(session.get('context') or []) > 0))
    verdicts.append(('memoire_croit', memoire > 0 and memoire <= borne))

    # inactivite : fabrication d'une session muette
    from datetime import datetime, timezone
    old_iso = datetime.fromtimestamp(time.time() - 5 * 3600, tz=timezone.utc).isoformat()
    idle = dict(id='idle-1', alias='TORC-CC10', task_id='TORC', state='active', enabled=True,
                closed=False, alerts=[], events=[{'event': 'x', 'at': old_iso}])
    service.sessions['idle-1'] = idle
    service._detect_inactive_sessions()
    constat = [a for a in idle['alerts'] if a.get('category') == 'session_inactive']
    log(f"4. inactivite TORC (idle 5h, seuil 4h) : constat={'oui' if constat else 'NON'} "
        f"({constat[0]['reason'][:90] if constat else '-'})")
    verdicts.append(('inactivite', bool(constat)))

    # coordination TORC (constat 2 T427) et seuils
    log(f"5. coordination TORC reconnue : {is_coordination_session({'alias': 'TORC-CC10'})} ; "
        f"seuil TORC = {_inactivity_threshold_seconds({'alias': 'TORC-CC10', 'task_id': 'TORC'}) / 3600} h")
    verdicts.append(('coordination_torc', is_coordination_session({'alias': 'TORC-CC10'})))

    # arret propre (threads daemon, close borne 3 s)
    service.close(timeout=6)
    log(f"6. arret gracieux : {'ok' if all(not t.is_alive() for t in (service._threads or [])) else 'threads restants'}")

    shutil.rmtree(scratch, ignore_errors=True)
    ok = all(v for _, v in verdicts)
    log("== VERDICT AUDIT : " + ("PASS" if ok else "ECHEC") + " — "
        + " ; ".join(f"{n}={'OK' if v else 'KO'}" for n, v in verdicts))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
