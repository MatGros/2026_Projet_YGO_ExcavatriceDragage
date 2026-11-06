"""Attach ONLY the explicitly created synthetic AGY preflight session to an isolated supervisor.

No existing supervisor is contacted, started or modified. Candidate discovery is
scoped to the one synthetic ID before os.walk recurses. The watcher hashes the
synthetic transcript on attach; neither event text nor transcripts are copied.
"""
import json
import os
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from supervisor_service import Supervisor
from session_watcher import resolve_jsonl_source

HERE = Path(__file__).resolve().parent
PREFLIGHT = ROOT / 'poc' / 'agy_routage' / 'preflight_e0afb6eb9c7d4f569ec6e147df5e90ec.json'
preflight = json.loads(PREFLIGHT.read_text(encoding='utf-8'))
if (preflight.get('synthetic_only') is not True or preflight.get('target_existing_session') is not False
        or preflight.get('returncode') != 0 or preflight.get('parsed', {}).get('status') != 'SUCCESS'
        or preflight.get('parsed', {}).get('response', '').strip() != 'PRET'):
    raise SystemExit('Preflight synthetic proof not established; no discovery or attachment attempted.')
native_id = str(uuid.UUID(preflight['parsed']['conversation_id']))
roots = [Path.home()/'.gemini'/name/'brain' for name in ('antigravity','antigravity-cli','antigravity-ide')]
scratch = Path(tempfile.mkdtemp(prefix='veilleur-poc-agy-discovery-'))
report = {'synthetic_only':True,'source_preflight':str(PREFLIGHT),'native_id':native_id,
          'created_utc':datetime.now(timezone.utc).isoformat(),'scratch':str(scratch),
          'started_supervisor':False,'llm_calls':0,'candidates_scope':'exact synthetic ID only'}
report['resolution'] = []
for root in roots:
    resolved = resolve_jsonl_source(root,native_id,platform='agy')
    report['resolution'].append({'root':str(root),'state':resolved.state,'matches':resolved.matches,
                                 'path':str(resolved.path) if resolved.path else None})

supervisor = Supervisor(state_path=scratch/'state.json',roots={'agy':roots},strict_assignments=True)
original_walk = os.walk
def restricted_walk(top, *args, **kwargs):
    for directory, subdirs, files in original_walk(top, *args, **kwargs):
        if Path(directory) == Path(top):
            subdirs[:] = [name for name in subdirs if name == native_id]
        yield directory, subdirs, files

try:
    os.walk = restricted_walk
    candidates = supervisor.candidates()
finally:
    os.walk = original_walk
report['candidates'] = candidates
source_paths = [item['path'] for item in report['resolution'] if item['state']=='ready']
report['expected'] = {'one_unambiguous_source':True,'candidate_exact':True,'strict_add':'accepted'}
report['checks'] = {
    'one_unambiguous_source': len(source_paths)==1 and not any(x['state']=='ambiguous' for x in report['resolution']),
    'candidate_exact':len(candidates['candidates'])==1 and candidates['candidates'][0]['native_id']==native_id
                      and candidates['candidates'][0]['platform']=='agy' and candidates['candidates'][0]['matches']==1,
}
try:
    supervisor.command({'action':'add','platform':'agy','native_id':native_id,
                        'alias':'AGY-POC-SYNTHETIQUE','mission':'POC synthétique : vérifier la source associée.'})
    sessions = supervisor.snapshot()['sessions']
    report['strict_add'] = 'accepted'
    report['checks']['added_exact_source'] = len(sessions)==1 and sessions[0]['native_id']==native_id and sessions[0]['source'] in source_paths
    report['attached_source'] = sessions[0]['source'] if sessions else None
except (ValueError,OSError) as exc:
    report['strict_add'] = 'rejected'
    report['error'] = str(exc)
    report['checks']['added_exact_source'] = False
report['pass'] = all(report['checks'].values())
name=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]
path=HERE/('evidence-'+name+'.json')
with path.open('x',encoding='utf-8') as stream:
    json.dump(report,stream,ensure_ascii=False,indent=2)
print(json.dumps(report,ensure_ascii=False,indent=2))
print('Evidence:',path)
raise SystemExit(0 if report['pass'] else 1)
