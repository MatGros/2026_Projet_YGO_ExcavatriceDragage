"""Contre-exemples de validation et de confirmation, sans appel au modèle."""
from copy import deepcopy
from replay import CASES, decision_gate, validate, normalize


def events(case):
    return [{'id':item['id'],'role':normalize('agy',item)[0],'text':normalize('agy',item)[1]}
            for item in case['events']]


def evidence(field,item):
    return {'field':field,'event_id':item['id'],'quote':item['content']}


ready, no_task, ambiguous = CASES[:3]
r=ready['events']
good={'status':'ready','alias':'AGY01','task_id':'T501','mission':r[2]['content'],'question':None,
      'evidence':[evidence('alias',r[0]),evidence('task',r[1]),evidence('mission',r[2])]}
assert not validate(good,ready,events(ready))
wrong=deepcopy(good);wrong['task_id']='T999'
assert 'wrong_task_id_or_invented' in validate(wrong,ready,events(ready))
wrong=deepcopy(good);wrong['evidence'][1]['quote']='preuve inventée'
assert 'fabricated_or_unattributed_quote' in validate(wrong,ready,events(ready))
wrong=deepcopy(good);wrong['mission']='Mission non citée'
assert 'mission_not_exact_quote' in validate(wrong,ready,events(ready))
wrong=deepcopy(good);wrong['evidence'][0]['event_id']='inconnu'
assert 'fabricated_or_unattributed_quote' in validate(wrong,ready,events(ready))
n=no_task['events']
empty={'status':'no_task','alias':'AGY02','task_id':None,'mission':n[2]['content'],
       'question':'Créer une tâche ou suivre sans tâche ?',
       'evidence':[evidence('alias',n[0]),evidence('task',n[1]),evidence('mission',n[2])]}
assert not validate(empty,no_task,events(no_task))
wrong=deepcopy(empty);wrong['task_id']='T999';wrong['question']=None
assert {'wrong_task_id_or_invented','missing_question'} <= set(validate(wrong,no_task,events(no_task)))
a=ambiguous['events']
conflict={'status':'ambiguous','alias':'AGY03','task_id':None,'mission':a[3]['content'],
          'question':'Quelle tâche choisir ?',
          'evidence':[evidence('alias',a[0]),evidence('task',a[1]),evidence('task',a[2]),evidence('mission',a[3])]}
assert not validate(conflict,ambiguous,events(ambiguous))
wrong=deepcopy(conflict);wrong['evidence'].pop(2)
assert 'missing_ambiguity_proof_T602' in validate(wrong,ambiguous,events(ambiguous))
for status in ('ready','no_task','ambiguous','source_ambiguous','source_missing'):
    assert decision_gate(status,False,'follow_without_task',verified=True) is False
assert decision_gate('ready',True,verified=False) is False
assert decision_gate('ready',True,verified=True) is True
assert decision_gate('no_task',True,verified=True) is False
assert decision_gate('no_task',True,'follow_without_task',verified=True) is True
assert decision_gate('ambiguous',True,'follow_without_task',verified=True) is False
print('PASS: source, citation, identité, tâche inventée, ambiguïté et garde de confirmation')
