"""Isolated Claude session addressing probe; never resumes an existing session."""
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
    output_dir = Path(__file__).resolve().parent
    run_id = uuid.uuid4().hex
    root = Path(tempfile.mkdtemp(prefix='veilleur-claude-routage-'))
    marker = 'POC_ALERTE_' + uuid.uuid4().hex[:12].upper()
    sessions = {'A': str(uuid.uuid4()), 'B': str(uuid.uuid4())}
    evidence = {'synthetic_only': True, 'run_id': run_id, 'temporary_dir': str(root),
                'sessions': sessions, 'marker': marker, 'stages': [],
                'expected': {'A': marker, 'B': 'AUCUNE'}}
    output = output_dir / f'evidence_{run_id}.json'
    exe = shutil.which('claude')
    if not exe:
        raise SystemExit('CLI Claude introuvable')

    def persist():
        output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf-8')

    def call(name, args, expected_id):
        command = [exe, '-p', '--tools', '', '--strict-mcp-config', '--disable-slash-commands',
                   '--output-format', 'json', *args]
        started = time.monotonic()
        try:
            proc = subprocess.run(command, cwd=root, stdin=subprocess.DEVNULL,
                                  capture_output=True, text=True, encoding='utf-8',
                                  errors='replace', timeout=120,
                                  creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            stage = {'name': name, 'args': args, 'returncode': proc.returncode,
                     'stdout': proc.stdout, 'stderr': proc.stderr,
                     'seconds': round(time.monotonic()-started, 3)}
            try:
                stage['parsed'] = json.loads(proc.stdout)
            except json.JSONDecodeError:
                stage['parsed'] = None
            evidence['stages'].append(stage)
            persist()
            result = stage['parsed']
            if proc.returncode != 0 or not isinstance(result, dict) or result.get('is_error'):
                raise RuntimeError(f'{name}: commande ou JSON en échec')
            if result.get('session_id') != expected_id:
                raise RuntimeError(f'{name}: session retournée inattendue')
            return result.get('result', '').strip()
        except subprocess.TimeoutExpired as exc:
            evidence['stages'].append({'name': name, 'error': 'timeout', 'stdout': str(exc.stdout), 'stderr': str(exc.stderr)})
            persist()
            raise RuntimeError(f'{name}: délai dépassé') from exc

    try:
        for name, session_id in sessions.items():
            text = call('create_'+name, ['--session-id', session_id, 'Essai synthétique. Réponds uniquement PRET.'], session_id)
            if text != 'PRET':
                raise RuntimeError(f'create_{name}: réponse non attendue : {text}')
        accepted = call('send_A', ['--resume', sessions['A'], f'Mémorise cette alerte synthétique pour le prochain message : {marker}. Réponds uniquement RECU.'], sessions['A'])
        if accepted != 'RECU':
            raise RuntimeError('Réception initiale non confirmée : ' + accepted)
        for name, session_id in sessions.items():
            evidence.setdefault('answers', {})[name] = call('query_'+name, ['--resume', session_id, 'Quel identifiant POC_ALERTE as-tu reçu dans cette conversation ? Réponds uniquement par cet identifiant ou AUCUNE.'], session_id)
        evidence['verdict'] = {'A_exact': evidence['answers']['A'] == marker,
                               'B_absent': evidence['answers']['B'] == 'AUCUNE'}
        persist()
        print(json.dumps(evidence['verdict'], ensure_ascii=False), flush=True)
        return 0 if all(evidence['verdict'].values()) else 1
    except Exception as exc:
        evidence['error'] = repr(exc)
        persist()
        print('ÉCHEC:', exc, file=sys.stderr)
        return 1
    finally:
        print('PREUVE:', output, flush=True)


if __name__ == '__main__':
    sys.exit(main())
