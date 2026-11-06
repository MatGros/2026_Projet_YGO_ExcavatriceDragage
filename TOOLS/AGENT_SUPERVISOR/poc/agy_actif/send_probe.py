"""Envoie un marqueur à la seule session synthétique créée par create_session.py."""
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

base = Path(__file__).resolve().parent
if len(sys.argv) != 2:
    raise SystemExit('Argument : preuve creation_*.json produite par le POC')
creation = Path(sys.argv[1]).resolve()
if creation.parent != base or not creation.name.startswith('creation_'):
    raise SystemExit('Preuve de création du POC requise')
proof = json.loads(creation.read_text(encoding='utf8'))
data = proof.get('parsed') or {}
if (proof.get('synthetic_only') is not True or proof.get('target_existing_session') is not False
        or proof.get('returncode') != 0 or data.get('status') != 'SUCCESS'
        or data.get('response', '').strip() != 'PRET'):
    raise SystemExit('Preuve synthétique insuffisante ; aucun envoi')
session = str(uuid.UUID(data['conversation_id']))
marker = proof['marker']
if not marker.startswith('POC_AGY_ACTIF_'):
    raise SystemExit('Marqueur synthétique requis')
args = ['agy.exe', '--mode', 'plan', '--sandbox', '--print-timeout', '90s',
        '--output-format', 'json', '--conversation', session, '--print',
        f'Alerte synthétique {marker} : réponds uniquement {marker}. Ne lance aucun outil et ne lis aucun fichier.']
result = {'synthetic_only': True, 'creation_proof': creation.name, 'session': session, 'marker': marker, 'args': args}
start = time.monotonic()
try:
    p = subprocess.run(args, cwd=proof['scratch'], stdin=subprocess.DEVNULL, capture_output=True,
                       text=True, encoding='utf8', errors='replace', timeout=105,
                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    result.update(returncode=p.returncode, stdout=p.stdout, stderr=p.stderr)
    try:
        result['parsed'] = json.loads(p.stdout)
    except json.JSONDecodeError:
        result['parsed'] = None
except subprocess.TimeoutExpired as exc:
    result.update(returncode=None, error='timeout', stdout=str(exc.stdout or ''), stderr=str(exc.stderr or ''))
result['seconds'] = round(time.monotonic()-start, 3)
path = base / ('send_' + uuid.uuid4().hex + '.json')
with path.open('x', encoding='utf8') as output:
    json.dump(result, output, ensure_ascii=False, indent=2)
print(json.dumps({'evidence':str(path),'returncode':result.get('returncode'),
                  'parsed':result.get('parsed'),'seconds':result['seconds']},ensure_ascii=False))
if (result.get('returncode') != 0 or not isinstance(result.get('parsed'), dict)
        or result['parsed'].get('status') != 'SUCCESS'
        or result['parsed'].get('conversation_id') != session):
    raise SystemExit(1)
