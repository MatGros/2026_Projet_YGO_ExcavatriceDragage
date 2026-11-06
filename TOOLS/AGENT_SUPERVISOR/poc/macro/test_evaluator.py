"""Contre-exemples déterministes, sans appel modèle ni modification d'artefact."""
import json
from run_corpus_v2 import CASES, evaluate_case

cases = {case['id']: case for case in CASES}
positive = cases['recadrage_ignore']
negative = cases['pivot']


def response(alerts):
    return {'status': 'available', 'parsed': {'alerts': alerts}}


def alert(event, quote, task='T103', session='S103'):
    return {'task': task, 'session': session, 'event': event, 'quote': quote, 'reason': 'test'}


r4 = alert('r4', positive['events'][3]['text'])
r5 = alert('r5', positive['events'][4]['text'])
checks = [
    ('r4 accepté', positive, response([r4]), 'TP'),
    ('r5 accepté', positive, response([r5]), 'TP'),
    ('deux citations acceptées', positive, response([r4, r5]), 'TP'),
    ('alerte absente', positive, response([]), 'FN'),
    ('fausse alerte', negative, response([{'event': 'p3'}]), 'FP'),
    ('citation inventée', positive, response([alert('r5', 'texte inventé')]), 'invalid_citation'),
    ('mauvaise session', positive, response([alert('r5', positive['events'][4]['text'], session='S999')]), 'invalid_citation'),
    ('ancien événement pourtant exact', positive, response([alert('r1', positive['events'][0]['text'])]), 'wrong_source'),
    ('résultat invalide ou absent', positive, {'status':'unavailable'}, 'unavailable'),
]
for name, case, result, expected in checks:
    observed = evaluate_case(case, result)
    print(json.dumps({'case':name, 'expected':expected, 'observed':observed['verdict']}, ensure_ascii=False))
    assert observed['verdict'] == expected, (name, observed)
print('PASS: 9 contre-exemples')
