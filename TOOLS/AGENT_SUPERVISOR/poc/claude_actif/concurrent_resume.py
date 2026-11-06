"""Single noninteractive resume of the synthetic POC session while its TUI is open."""
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

here = Path(__file__).resolve().parent
if len(sys.argv) != 2:
    raise SystemExit('Argument requis : preuve de création synthétique de ce dossier')
creation_path = Path(sys.argv[1]).resolve()
if creation_path.parent != here or not creation_path.name.startswith('creation_'):
    raise SystemExit('Preuve de création située dans ce dossier requise')
creation = json.loads(creation_path.read_text(encoding='utf8'))
if not creation.get('valid') or not creation.get('synthetic_only'):
    raise SystemExit('Session synthétique non établie')
sid = str(uuid.UUID(creation['session_id']))
marker = 'POC_ALERTE_ACTIF_' + uuid.uuid4().hex[:10].upper()
args = ['claude', '-p', '--resume', sid, '--tools', '', '--output-format', 'json',
        'Alerte synthétique : réponds uniquement ' + marker + '. Aucun outil, ne lis ni ne modifie aucun fichier.']
start = time.monotonic()
try:
    p = subprocess.run(args, cwd=creation['cwd'], stdin=subprocess.DEVNULL, capture_output=True,
                       text=True, encoding='utf8', errors='replace', timeout=100,
                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    evidence = {'session_id': sid, 'marker': marker, 'args': args, 'exit_code': p.returncode,
                'stdout': p.stdout, 'stderr': p.stderr, 'seconds': round(time.monotonic()-start, 3)}
    try:
        parsed = json.loads(p.stdout)
        evidence['response_session_id'] = parsed.get('session_id')
        evidence['response'] = parsed.get('result')
    except ValueError:
        evidence['parse_error'] = True
except subprocess.TimeoutExpired:
    evidence = {'session_id':sid, 'marker':marker, 'args':args, 'exit_code':None, 'error':'timeout'}
out = here / ('concurrent_' + uuid.uuid4().hex + '.json')
with out.open('x',encoding='utf8') as f:
    json.dump(evidence,f,ensure_ascii=False,indent=2)
print(json.dumps({'marker':marker,'session_id':sid,'response':evidence.get('response'),
                  'response_session_id':evidence.get('response_session_id'),'evidence':str(out)},ensure_ascii=False))
