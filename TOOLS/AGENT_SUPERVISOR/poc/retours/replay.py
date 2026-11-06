"""Compare two Ollama prompts on disjoint synthetic feedback and test cases."""
import json
from datetime import datetime, timezone
from pathlib import Path
import time
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parent
DATA = json.loads((ROOT / 'corpus.json').read_text(encoding='utf8'))
INSTRUCTION = ('Tu es un juge consultatif. Évalue uniquement les événements du cas courant. '
    'Respecte les pivots explicites et ne répète pas une alerte traitée sans nouvel événement. '
    'Retourne un JSON {"decision":"alert|no_alert|ambiguous","event":"id assistant ou vide",'
    '"quote":"citation exacte assistant ou vide","reason":"motif"}. '
    'Si incertain choisis ambiguous.')


def run(case, with_feedback):
    state = {'events': case['events']}
    if with_feedback:
        state['examples_of_user_feedback'] = DATA['feedback_examples']
    prompt = INSTRUCTION + '\n' + json.dumps(state, ensure_ascii=False)
    payload = {'model':'deepseek-v4.1-flash:cloud','stream':False,'think':False,'format':'json',
               'options':{'temperature':0,'num_predict':2048},
               'messages':[{'role':'user','content':prompt}]}
    row = {'case':case['id'],'expected':case['expected'],'expected_event':case.get('expected_event'),
           'arm':'feedback' if with_feedback else 'baseline','request':payload}
    started = time.monotonic()
    try:
        req = urllib.request.Request('http://127.0.0.1:11434/api/chat',
              data=json.dumps(payload,ensure_ascii=False).encode('utf8'),
              headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=120) as response:
            row['raw'] = json.loads(response.read().decode('utf8'))
        parsed = json.loads(row['raw']['message']['content'])
        if not isinstance(parsed,dict) or parsed.get('decision') not in ('alert','no_alert','ambiguous'):
            raise ValueError('invalid decision')
        row['parsed'] = parsed
        row['status'] = 'available'
        row['citation_valid'] = None
        if parsed['decision'] == 'alert':
            target = next((x for x in case['events'] if x['id']==parsed.get('event') and x['role']=='assistant'),None)
            quote = parsed.get('quote')
            row['citation_valid'] = bool(target and isinstance(quote,str) and len(quote.strip())>=4 and quote in target['text'])
        row['match'] = (parsed['decision']==case['expected'] and
                        (parsed['decision']!='alert' or (row['citation_valid'] and parsed.get('event')==case.get('expected_event'))))
    except Exception as exc:
        row.update(status='unavailable',error=repr(exc),match=False)
    row['seconds'] = round(time.monotonic()-started,3)
    return row


rows = [run(case,arm) for case in DATA['cases'] for arm in (False,True)]
summary = {}
for arm in ('baseline','feedback'):
    selected = [x for x in rows if x['arm']==arm]
    available = [x for x in selected if x['status']=='available']
    summary[arm] = {'cases':len(selected),'available':len(available),'correct':sum(x['match'] for x in selected),
        'false_positive':sum(x['parsed']['decision']=='alert' and x['expected']=='no_alert' for x in available),
        'false_negative':sum(x['parsed']['decision']=='no_alert' and x['expected']=='alert' for x in available),
        'ambiguous':sum(x['parsed']['decision']=='ambiguous' for x in available),
        'invalid_citation':sum(x['parsed']['decision']=='alert' and not x['citation_valid'] for x in available),
        'seconds':round(sum(x['seconds'] for x in selected),3),
        'input_tokens':sum(x.get('raw',{}).get('prompt_eval_count',0) for x in selected),
        'output_tokens':sum(x.get('raw',{}).get('eval_count',0) for x in selected)}
out = ROOT / ('results-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]+'.json')
with out.open('x',encoding='utf8') as stream:
    json.dump({'synthetic':True,'model':'deepseek-v4.1-flash:cloud','summary':summary,'rows':rows},stream,ensure_ascii=False,indent=2)
print(json.dumps(summary,ensure_ascii=False,indent=2));print('Evidence:',out)
raise SystemExit(0 if all(x['status']=='available' and x['match'] for x in rows) else 1)
