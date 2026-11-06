"""GET Task Manager réel sur données synthétiques ; aucun accès aux catalogues réels."""
import hashlib
import http.server
import json
import sys
import tempfile
import threading
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(REPO))
import TOOLS.TASK_MANAGER.task_server as manager

CORPUS_BYTES=(HERE/'corpus.json').read_bytes()
CORPUS=json.loads(CORPUS_BYTES.decode('utf-8'))


def evaluate(tasks, case):
    """Prototype consultatif ; registre des sessions fourni séparément, non émis par Task Manager."""
    if not isinstance(tasks,list):
        return {'decision':'manager_unavailable','identity_verified':False}
    matches=[t for t in tasks if isinstance(t,dict) and str(t.get('id'))==case['task']]
    if not matches:
        return {'decision':'task_missing','identity_verified':False}
    if len(matches)!=1:
        return {'decision':'task_ambiguous','identity_verified':False}
    task=matches[0]
    actor=case['agent']
    lock=task.get('work_lock')
    result={'task':case['task'],'session':case['session'],'asserted_agent':actor,
            'catalog_agent':task.get('agent'),'work_lock_actor':lock.get('actor') if isinstance(lock,dict) else None,
            'task_revision':task.get('revision'),'identity_verified':False}
    if task.get('statut') in ('✅','❌'):
        result['decision']='closed'
    elif not task.get('agent') or task['agent'] in ('—','-'):
        result['decision']='unassigned'
    elif task['agent']!=actor:
        result['decision']='conflict_agent'
    elif not isinstance(lock,dict):
        result['decision']='missing_lock'
    elif lock.get('actor')!=actor:
        result['decision']='conflict_lock'
    elif case['registry'] is None:
        result['decision']='registry_unavailable'
    elif not isinstance(case['registry'],list) or any(not isinstance(item,dict) or not isinstance(item.get('task'),str) or not isinstance(item.get('session'),str) for item in case['registry']):
        result['decision']='invalid_registry'
    elif any(item['task']==case['task'] and item['session']!=case['session'] for item in case['registry']):
        result['decision']='conflict_task_session'
    elif any(item['session']==case['session'] and item['task']!=case['task'] for item in case['registry']):
        result['decision']='conflict_session_task'
    elif any(item['session']==case['session'] and item['task']==case['task'] for item in case['registry']):
        result['decision']='already_attached'
    else:
        result['decision']='proposable'
    return result


def main():
    scratch=Path(tempfile.mkdtemp(prefix='veilleur-tache-isolee-'))
    task_path=scratch/'TASKS.yaml';lock_path=scratch/'TASK_LOCKS.json'
    task_path.write_text(yaml.safe_dump({'tasks':CORPUS['tasks']},allow_unicode=True,sort_keys=False),encoding='utf-8')
    lock_path.write_text(json.dumps(CORPUS['locks'],ensure_ascii=False,indent=2),encoding='utf-8')
    before={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (task_path,lock_path)}
    # These globals exist only in this isolated Python process. No service start() or collector is called.
    manager.WFLOW=scratch;manager.TASKS_PATH=task_path;manager.LOCKS_PATH=lock_path;manager.MUTEX_PATH=scratch/'write.lock'
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),manager.Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    report={'created_utc':datetime.now(timezone.utc).isoformat(),'synthetic_only':True,
            'corpus_sha256':hashlib.sha256(CORPUS_BYTES).hexdigest(),'scratch':str(scratch),
            'endpoint':'/api/tasks/json','requests':['GET'],'actual_attachments':0,'catalogue_writes':0}
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{server.server_port}/api/tasks/json',timeout=5) as response:
            report['http_status']=response.status
            tasks=json.load(response)
        report['manager_response_synthetic']=tasks
        report['cases']=[]
        for case in CORPUS['cases']:
            observed=evaluate(tasks,case)
            report['cases'].append({'input':case,'observed':observed,
                                    'pass':observed['decision']==case['expected'] and not observed.get('identity_verified',True)})
    except Exception as exc:
        report['error']=repr(exc)
    finally:
        server.shutdown();server.server_close();thread.join(timeout=5)
    after={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (task_path,lock_path)}
    report['file_hashes_before']=before;report['file_hashes_after']=after
    report['unchanged']=before==after
    report['pass']=('error' not in report and report.get('http_status')==200 and report['unchanged'] and
                    len(report.get('cases',[]))==len(CORPUS['cases']) and all(c['pass'] for c in report['cases']))
    path=HERE/('result-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]+'.json')
    with path.open('x',encoding='utf-8') as stream:
        json.dump(report,stream,ensure_ascii=False,indent=2)
    print(json.dumps({'pass':report['pass'],'http_status':report.get('http_status'),
                      'unchanged':report['unchanged'],
                      'cases':[{'id':c['input']['id'],'decision':c['observed']['decision'],'pass':c['pass']} for c in report.get('cases',[])]},ensure_ascii=False,indent=2))
    print('Evidence:',path)
    return 0 if report['pass'] else 1


if __name__=='__main__':
    raise SystemExit(main())
