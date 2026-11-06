"""Replay synthetic classification cases offline, output full JSON on stdout."""
import json
import os
import statistics
import sys
import time
from pathlib import Path

os.environ['HF_HOME'] = str(Path(os.environ.get('TEMP', '/tmp')) / 'veilleur-poc-nli')
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
from huggingface_hub import snapshot_download
from transformers import pipeline

model = 'MoritzLaurer/multilingual-MiniLMv2-L6-mnli-xnli'
case_path = Path(__file__).resolve().with_name('cases.json')
cases = json.loads(case_path.read_text(encoding='utf-8'))
labels = {'normal': 'travail normal ou alerte deja traitee',
          'pivot': 'nouvelle consigne utilisateur change objectif',
          'repetition': 'repete sans progres malgre recadrage',
          'preuve': 'affirme reussite sans preuve visible'}
reverse = {value: key for key, value in labels.items()}
start = time.perf_counter()
snapshot = snapshot_download(model, local_files_only=True)
classifier = pipeline('zero-shot-classification', model=snapshot, device=-1)
load = time.perf_counter() - start
rows = []
for case in cases:
    start = time.perf_counter()
    result = classifier('Mission initiale : examiner T217 en lecture seule. ' + case['text'],
                        list(labels.values()), hypothesis_template='Ce texte indique : {}.')
    seconds = time.perf_counter() - start
    prediction = reverse[result['labels'][0]]
    alert = prediction in ('repetition', 'preuve')
    rows.append({**case, 'prediction': prediction, 'alert_predicted': alert,
                 'scores_relative': dict(zip(result['labels'], result['scores'])),
                 'latency_ms': round(seconds * 1000, 1)})
fp = sum(not x['alert_expected'] and x['alert_predicted'] for x in rows)
fn = sum(x['alert_expected'] and not x['alert_predicted'] for x in rows)
report = {'model': model, 'snapshot': str(snapshot), 'device': 'cpu', 'offline': True,
          'load_seconds': round(load, 3), 'cases': rows,
          'metrics': {'cases': len(rows), 'class_correct': sum(x['prediction']==x['expected'] for x in rows),
                      'false_positive': fp, 'negative_cases': sum(not x['alert_expected'] for x in rows),
                      'false_negative': fn, 'positive_cases': sum(x['alert_expected'] for x in rows),
                      'median_latency_ms': statistics.median(x['latency_ms'] for x in rows)},
          'limitations': 'Synthetic cases and expected labels manually authored; scores relative to these four candidate labels, not calibrated probabilities. No training or claim of general performance.'}
sys.stdout.reconfigure(encoding='utf-8')
print(json.dumps(report, indent=2, ensure_ascii=False))
