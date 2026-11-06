"""Crée uniquement une nouvelle session synthétique AGY ; conserve les preuves."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

root = Path(tempfile.mkdtemp(prefix='veilleur-agy-actif-'))
evidence_dir = Path(__file__).resolve().parent
run_id = uuid.uuid4().hex
marker = 'POC_AGY_ACTIF_' + uuid.uuid4().hex[:10].upper()
args = ['agy.exe', '--mode', 'plan', '--sandbox', '--print-timeout', '90s',
        '--output-format', 'json', '--print',
        'Essai synthétique : réponds uniquement PRET. Ne lance aucun outil et ne lis aucun fichier.']
start = time.monotonic()
evidence = {'synthetic_only': True, 'target_existing_session': False,
            'scratch': str(root), 'marker': marker, 'args': args}
try:
    p = subprocess.run(args, cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                       text=True, encoding='utf8', errors='replace', timeout=105,
                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    evidence.update(returncode=p.returncode, stdout=p.stdout, stderr=p.stderr)
    try:
        evidence['parsed'] = json.loads(p.stdout)
    except json.JSONDecodeError:
        evidence['parsed'] = None
except subprocess.TimeoutExpired as exc:
    evidence.update(returncode=None, error='timeout', stdout=str(exc.stdout or ''), stderr=str(exc.stderr or ''))
evidence['seconds'] = round(time.monotonic()-start, 3)
path = evidence_dir / f'creation_{run_id}.json'
with path.open('x', encoding='utf8') as out:
    json.dump(evidence, out, ensure_ascii=False, indent=2)
print(json.dumps({'evidence': str(path), 'returncode': evidence.get('returncode'),
                  'parsed': evidence.get('parsed'), 'seconds': evidence['seconds']}, ensure_ascii=False))
if (evidence.get('returncode') != 0 or not isinstance(evidence.get('parsed'), dict)
        or evidence['parsed'].get('status') != 'SUCCESS'
        or evidence['parsed'].get('response', '').strip() != 'PRET'):
    raise SystemExit(1)
