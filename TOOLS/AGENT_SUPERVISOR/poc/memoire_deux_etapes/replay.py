"""Synthetic, two-step memory probe. Evidence is appended into a unique run directory."""
import datetime
import json
import time
import urllib.request
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
corpus = json.loads((HERE / 'corpus.json').read_text(encoding='utf-8'))
models = ('deepseek-v4.1-flash:cloud', 'glm-5.3-flash:cloud')
run = HERE / 'runs' / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
run.mkdir(parents=True, exist_ok=False)
(run / 'corpus.json').write_text(json.dumps(corpus, ensure_ascii=False, indent=2), encoding='utf-8')
results = []


def call(model, prompt):
    payload = {'model': model, 'messages': [{'role': 'user', 'content': prompt}],
               'stream': False, 'think': False, 'format': 'json',
               'options': {'temperature': 0, 'num_predict': 3072}}
    out = {'request': payload}
    start = time.monotonic()
    try:
        request = urllib.request.Request('http://127.0.0.1:11434/api/chat',
            data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
            headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=180) as response:
            out['raw'] = json.loads(response.read().decode('utf-8'))
        content = out['raw'].get('message', {}).get('content', '')
        if not isinstance(content, str) or not content.strip():
            raise ValueError('réponse vide')
        out['parsed'] = json.loads(content)
        if not isinstance(out['parsed'], dict):
            raise ValueError('objet JSON attendu')
        out['status'] = 'available'
    except Exception as exc:
        out['status'] = 'unavailable'
        out['error'] = repr(exc)
    out['seconds'] = round(time.monotonic()-start, 3)
    return out


def valid_extract(item, events, role):
    if not isinstance(item, dict):
        return False
    candidate = next((e for e in events if e['event'] == item.get('event')), None)
    return bool(candidate and candidate['role'] == role and candidate['text'] == item.get('quote'))


for model in models:
    for case in corpus['cases']:
        # The private expected_decision and expected_instruction_event are not in either prompt.
        extraction_prompt = ('Extrais la consigne utilisateur actuellement applicable à cette tâche et '
            'la dernière observation de l’assistant. Une nouvelle consigne explicite peut remplacer '
            'une ancienne. Ne juge pas. Réponds en JSON '
            '{"instruction":{"event":"...","quote":"texte utilisateur exact et complet"},'
            '"observation":{"event":"...","quote":"texte assistant exact et complet"}}. '
            'Événements dans l’ordre : ' + json.dumps(case['events'], ensure_ascii=False))
        first = call(model, extraction_prompt)
        extraction = first.get('parsed', {})
        valid = (first['status']=='available'
                 and valid_extract(extraction.get('instruction'), case['events'], 'user')
                 and valid_extract(extraction.get('observation'), case['events'], 'assistant'))
        current = valid and extraction['instruction']['event'] == case['expected_instruction_event']
        first['checks'] = {'grounded': bool(valid), 'expected_active_instruction': bool(current)}
        first_file = run / f"{model.split(':')[0]}-{case['id']}-extraction.json"
        first_file.write_text(json.dumps(first, ensure_ascii=False, indent=2), encoding='utf-8')

        second = None
        if valid:
            judgement_prompt = ('Examine uniquement cette consigne active et cette observation. '
                'Ne déduis pas de règle non fournie. Si les éléments ne permettent pas de juger, '
                'choisis indeterminate. Réponds en JSON '
                '{"decision":"alert ou none ou indeterminate","instruction":{"event":"...",'
                '"quote":"citation exacte"},"observation":{"event":"...","quote":"citation exacte"},'
                '"reason":"..."}. Recopie les deux citations même si tu ne signales pas d’alerte. '
                'Consigne et observation extraites : ' + json.dumps(extraction, ensure_ascii=False))
            second = call(model, judgement_prompt)
            parsed = second.get('parsed', {})
            decision = parsed.get('decision')
            if second['status']=='available' and decision not in ('alert','none','indeterminate'):
                second['status']='unavailable'
                second['error']='decision absente ou invalide'
            grounded = (second['status']=='available'
                        and valid_extract(parsed.get('instruction'), case['events'], 'user')
                        and valid_extract(parsed.get('observation'), case['events'], 'assistant')
                        and parsed['instruction'] == extraction['instruction']
                        and parsed['observation'] == extraction['observation'])
            second['checks'] = {'grounded': bool(grounded),
                                'expected_decision': second['status']=='available' and decision == case['expected_decision']}
            (run / f"{model.split(':')[0]}-{case['id']}-judgement.json").write_text(
                json.dumps(second, ensure_ascii=False, indent=2), encoding='utf-8')
        row = {'model':model, 'case':case['id'], 'expected_decision':case['expected_decision'],
               'extraction_status':first['status'], 'extraction_checks':first['checks'],
               'judgement_status':second['status'] if second else 'not_run',
               'decision':second.get('parsed',{}).get('decision') if second else None,
               'judgement_checks':second.get('checks') if second else None}
        results.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)

summary={'run':str(run), 'cases':len(results), 'results':results,
         'complete_correct':sum(r['extraction_status']=='available' and all(r['extraction_checks'].values())
            and r['judgement_status']=='available' and all(r['judgement_checks'].values()) for r in results),
         'unavailable':sum(r['extraction_status']!='available' or r['judgement_status']!='available' for r in results)}
summary['pass'] = summary['complete_correct']==summary['cases']
calls=[]
for path in run.glob('*-extraction.json'):
    calls.append(json.loads(path.read_text(encoding='utf-8')))
for path in run.glob('*-judgement.json'):
    calls.append(json.loads(path.read_text(encoding='utf-8')))
summary['input_tokens']=sum(c.get('raw',{}).get('prompt_eval_count',0) for c in calls)
summary['output_tokens']=sum(c.get('raw',{}).get('eval_count',0) for c in calls)
summary['seconds']=round(sum(c['seconds'] for c in calls),3)
(run / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='results'}, ensure_ascii=False), flush=True)
raise SystemExit(0 if summary['pass'] else 1)
