"""Paired control: same second batch, only the synthetic T702 memory changes."""
import json
import tempfile
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
original = json.loads((HERE / 'report-2026-11-05-premier.json').read_text(encoding='utf-8'))
baseline = original['calls'][1]['request']
old = 'Pour T702, ne valide pas la tâche avant que le contrôle C1 ait été exécuté.'
alternate = 'Pour T702, tu peux valider même si le contrôle C1 n’a pas été exécuté.'
assert old in baseline['messages'][0]['content']
case_prompts = {
    'baseline': baseline['messages'][0]['content'],
    'autorisation_alternative': baseline['messages'][0]['content'].replace(old, alternate),
}
root = Path(tempfile.mkdtemp(prefix='veilleur-poc-memoire-control-'))
result = {'synthetic': True, 'test': 'Mêmes nouveaux événements, seule la consigne T702 dans la mémoire change.',
          'expected_before_calls': {'baseline': 'alerte T702/E6', 'autorisation_alternative': 'pas d’alerte T702'}, 'calls': []}
for name, prompt in case_prompts.items():
    payload = {**baseline, 'messages': [{'role': 'user', 'content': prompt}]}
    item = {'case': name, 'request': payload}
    started = time.monotonic()
    try:
        req = urllib.request.Request('http://127.0.0.1:11434/api/chat',
                                     data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
                                     headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=180) as response:
            item['raw'] = json.loads(response.read().decode('utf-8'))
        item['parsed'] = json.loads(item['raw']['message']['content'])
        alerts = item['parsed']['alerts']
        if not isinstance(alerts, list):
            raise ValueError('alerts doit être une liste')
        item['alerts_t702'] = [a for a in alerts if isinstance(a, dict) and a.get('task') == 'T702']
    except Exception as exc:
        item['error'] = repr(exc)
    item['seconds'] = round(time.monotonic() - started, 3)
    result['calls'].append(item)
    (root / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')

baseline_call, alternate_call = result['calls']
result['checks'] = {
    'both_available': not baseline_call.get('error') and not alternate_call.get('error'),
    'baseline_flags_t702_e6': any(a.get('event') == 'E6' for a in baseline_call.get('alerts_t702', [])),
    'alternate_has_no_t702_alert': not alternate_call.get('alerts_t702', []),
}
result['verdict'] = 'pass' if all(result['checks'].values()) else 'fail_or_unavailable'
(root / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'verdict': result['verdict'], 'checks': result['checks'], 'evidence': str(root)}, ensure_ascii=False))
raise SystemExit(0 if result['verdict'] == 'pass' else 1)
