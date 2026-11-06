"""Continue only a synthetic session created by this POC's preflight evidence."""
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


def main():
    if len(sys.argv) != 2:
        raise SystemExit('Argument requis : chemin du JSON preflight créé par cet essai')
    base = Path(__file__).resolve().parent
    preflight_path = Path(sys.argv[1]).resolve()
    if preflight_path.parent != base or not preflight_path.name.startswith('preflight_'):
        raise SystemExit('Preuve preflight de ce dossier requise')
    pre = json.loads(preflight_path.read_text(encoding='utf8'))
    parsed = pre.get('parsed') or {}
    first = parsed.get('conversation_id')
    if (not pre.get('synthetic_only') or pre.get('target_existing_session') is not False
            or pre.get('returncode') != 0 or parsed.get('status') != 'SUCCESS'
            or not re.fullmatch(r'[0-9a-f-]{36}', str(first))):
        raise SystemExit('Preflight synthétique non valide ; aucun envoi')
    run_id = uuid.uuid4().hex
    marker = 'POC_ALERTE_' + uuid.uuid4().hex[:12].upper()
    evidence = {'synthetic_only': True, 'preflight': preflight_path.name,
                'first_session': first, 'marker': marker, 'stages': [],
                'expected': {'A': marker, 'B': 'AUCUNE'}}
    output = base / f'evidence_{run_id}.json'
    root = Path(pre['temporary_dir'])
    exe = pre['args'][0]

    def persist():
        output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf8')

    def call(name, prompt, session=None):
        args = [exe, '--mode', 'plan', '--sandbox', '--print-timeout', '60s', '--output-format', 'json']
        if session:
            args += ['--conversation', session]
        args += ['--print', 'Ne lance aucun outil, ne lis et ne modifie aucun fichier. ' + prompt]
        start = time.monotonic()
        try:
            p = subprocess.run(args, cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                               text=True, encoding='utf8', errors='replace', timeout=75,
                               creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            stage = {'name': name, 'args': args, 'returncode': p.returncode, 'stdout': p.stdout,
                     'stderr': p.stderr, 'seconds': round(time.monotonic()-start, 3)}
            try:
                stage['parsed'] = json.loads(p.stdout)
            except json.JSONDecodeError:
                stage['parsed'] = None
            evidence['stages'].append(stage)
            persist()
            data = stage['parsed']
            if p.returncode or not isinstance(data, dict) or data.get('status') != 'SUCCESS':
                raise RuntimeError(f'{name}: indisponible ou réponse invalide')
            if session and data.get('conversation_id') != session:
                raise RuntimeError(f'{name}: identité de conversation différente')
            return data
        except subprocess.TimeoutExpired as exc:
            evidence['stages'].append({'name': name, 'error':'timeout', 'stdout':str(exc.stdout or ''), 'stderr':str(exc.stderr or '')})
            persist()
            raise RuntimeError(f'{name}: timeout') from exc

    try:
        b = call('create_B', 'Essai synthétique. Réponds uniquement PRET.')
        second = b.get('conversation_id')
        if b.get('response','').strip() != 'PRET' or not re.fullmatch(r'[0-9a-f-]{36}', str(second)) or second == first:
            raise RuntimeError('Deuxième session non identifiée distinctement')
        evidence['second_session'] = second
        persist()
        a = call('send_A', f'Mémorise cette alerte synthétique pour le prochain message : {marker}. Réponds uniquement RECU.', first)
        if a.get('response','').strip() != 'RECU':
            raise RuntimeError('Réception initiale non confirmée')
        prompt = 'Quel identifiant POC_ALERTE as-tu reçu dans cette conversation ? Réponds uniquement par cet identifiant ou AUCUNE.'
        answer_a = call('query_A', prompt, first).get('response','').strip()
        answer_b = call('query_B', prompt, second).get('response','').strip()
        evidence['answers'] = {'A':answer_a, 'B':answer_b}
        evidence['verdict'] = {'A_exact':answer_a == marker, 'B_absent':answer_b == 'AUCUNE'}
        persist()
        print(json.dumps(evidence['verdict'], ensure_ascii=False))
        return 0 if all(evidence['verdict'].values()) else 1
    except Exception as exc:
        evidence['error'] = repr(exc)
        persist()
        print('ÉCHEC:', exc, file=sys.stderr)
        return 1
    finally:
        print('PREUVE:', output)


if __name__ == '__main__':
    sys.exit(main())
