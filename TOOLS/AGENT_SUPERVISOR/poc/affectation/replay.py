"""POC read-only sources: synthetic transcripts, isolated temporary state.

Run from any directory: python TOOLS/AGENT_SUPERVISOR/poc/affectation/replay.py
Never touches a real transcript, Task Manager, or running supervisor.
Temporary files are intentionally retained.
"""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from supervisor_service import Supervisor

base = Path(tempfile.mkdtemp(prefix='veilleur-poc-affectation-'))
roots = {p: [base / p] for p in ('claude', 'codex', 'agy')}
ids = {'claude': '11111111-1111-4111-8111-111111111111',
       'codex': '22222222-2222-4222-8222-222222222222',
       'agy': '33333333-3333-4333-8333-333333333333'}
paths = {'claude': roots['claude'][0] / 'projet' / (ids['claude'] + '.jsonl'),
         'codex': roots['codex'][0] / '2026' / '11' / '05' / ('rollout-' + ids['codex'] + '.jsonl'),
         'agy': roots['agy'][0] / ids['agy'] / '.system_generated' / 'logs' / 'transcript.jsonl'}
for path in paths.values():
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('{}\n', encoding='utf-8')

s = Supervisor(state_path=base/'state'/'state.json', roots=roots, strict_assignments=True)
results = []
def record(case, observed, expected):
    results.append({'case': case, 'expected': expected, 'observed': observed,
                    'result': 'PASS' if observed == expected else 'FAIL'})

def add(platform, native_id, mission):
    try:
        s.command({'action': 'add', 'platform': platform, 'native_id': native_id, 'mission': mission})
        return 'accepted'
    except ValueError as exc:
        return 'rejected: ' + str(exc)

discovered = {(x['platform'], x['native_id']): x['matches'] for x in s.candidates()['candidates']}
for platform, native_id in ids.items():
    record('discovery_' + platform, discovered.get((platform, native_id)), 1)
    record('attach_' + platform, add(platform, native_id, 'T999 - mission synthétique'), 'accepted')

record('same_session_twice', add('claude', ids['claude'], 'T999 - mission synthétique'),
       'rejected: Session deja affectee')
record('same_task_three_sessions', sum(v['mission'].startswith('T999') for v in s.sessions.values()), 1)

missionless_id = '44444444-4444-4444-8444-444444444444'
path = roots['claude'][0] / 'projet' / (missionless_id + '.jsonl')
path.write_text('{}\n', encoding='utf-8')
record('attach_without_mission', add('claude', missionless_id, ''), 'accepted')
item = next(v for v in s.sessions.values() if v['native_id'] == missionless_id)
record('without_mission_state', item['analysis_state'], 'context_required')
record('unknown_id', add('agy', 'unknown', 'T998'),
       'rejected: Conversation introuvable ou ambigue : verifier plateforme et ID')

ambiguous = roots['claude'][0] / 'autre' / (ids['claude'] + '.jsonl')
ambiguous.parent.mkdir(parents=True, exist_ok=True)
ambiguous.write_text('{}\n', encoding='utf-8')
record('ambiguous_source', add('claude', ids['claude'], 'T999'),
       'rejected: Conversation introuvable ou ambigue : verifier plateforme et ID')

print(json.dumps({'synthetic_only': True, 'temporary_root': str(base), 'cases': results,
                  'note': 'Same task represented as free text: no formal task identity or Task Manager lookup is exercised.'},
                 indent=2, ensure_ascii=False))
sys.exit(1 if any(result['result'] == 'FAIL' for result in results) else 0)
