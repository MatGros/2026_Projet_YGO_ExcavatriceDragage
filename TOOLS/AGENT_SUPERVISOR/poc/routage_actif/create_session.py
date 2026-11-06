"""Create exactly one new synthetic session; persist JSON events and exact UUID."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def main():
    root = Path(tempfile.mkdtemp(prefix='veilleur-poc-actif-'))
    run_id = uuid.uuid4().hex
    output = Path(__file__).resolve().parent / f'creation_{run_id}.json'
    exe = shutil.which('codex.exe' if os.name == 'nt' else 'codex')
    prompt = 'Essai synthétique isolé : réponds uniquement PRET. Ne lance aucun outil et ne lis aucun fichier.'
    args = [exe, 'exec', '--skip-git-repo-check', '-s', 'read-only', '--json', prompt]
    start = time.monotonic()
    data = {'synthetic_only': True, 'temporary_dir': str(root), 'args': args}
    try:
        p = subprocess.run(args, cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                           encoding='utf8', errors='replace', timeout=120,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        data.update(returncode=p.returncode, stdout=p.stdout, stderr=p.stderr)
        events = []
        for line in p.stdout.splitlines():
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        threads = [x.get('thread_id') for x in events if x.get('type') == 'thread.started']
        replies = [x.get('item', {}).get('text') for x in events if x.get('type') == 'item.completed' and x.get('item', {}).get('type') == 'agent_message']
        if p.returncode != 0 or len(threads) != 1 or not replies or replies[-1].strip() != 'PRET':
            raise RuntimeError('Création ou réponse non conforme ; arrêt sans routage')
        data['thread_id'] = str(uuid.UUID(threads[0]))
    except Exception as exc:
        data['error'] = repr(exc)
    data['seconds'] = round(time.monotonic() - start, 3)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf8')
    print('PREUVE:', output)
    print('THREAD:', data.get('thread_id'))
    print('TEMP:', root)
    if 'error' in data:
        print('ERREUR:', data['error'], file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
