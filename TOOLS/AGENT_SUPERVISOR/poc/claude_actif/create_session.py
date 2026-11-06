"""Create a new synthetic session and persist its identity for the POC."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

root = Path(tempfile.mkdtemp(prefix='veilleur-claude-actif-'))
sid = str(uuid.uuid4())
args = ['claude', '-p', '--session-id', sid, '--tools', '', '--output-format', 'json',
        'Essai synthétique. Réponds uniquement PRET. Aucun outil, ne lis ni ne modifie aucun fichier.']
start = time.monotonic()
try:
    result = subprocess.run(args, cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                            text=True, encoding='utf8', errors='replace', timeout=100,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    data = {'synthetic_only': True, 'session_id': sid, 'cwd': str(root), 'args': args,
            'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
            'seconds': round(time.monotonic()-start, 3)}
    try:
        parsed = json.loads(result.stdout)
        data['valid'] = result.returncode == 0 and parsed.get('session_id') == sid and parsed.get('result', '').strip() == 'PRET'
    except ValueError:
        data['valid'] = False
except subprocess.TimeoutExpired:
    data = {'synthetic_only': True, 'session_id': sid, 'cwd': str(root), 'args': args,
            'valid': False, 'error': 'timeout'}
path = Path(__file__).resolve().parent / ('creation_' + uuid.uuid4().hex + '.json')
with path.open('x', encoding='utf8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print(json.dumps({'valid': data['valid'], 'session_id': sid, 'cwd': str(root), 'evidence': str(path)}, ensure_ascii=False))
raise SystemExit(0 if data['valid'] else 1)
