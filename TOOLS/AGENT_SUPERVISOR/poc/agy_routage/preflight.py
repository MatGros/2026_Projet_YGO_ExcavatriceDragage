"""Single synthetic AGY availability call; never resumes an existing session."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def main():
    run_id = uuid.uuid4().hex
    output = Path(__file__).resolve().parent / f'preflight_{run_id}.json'
    root = Path(tempfile.mkdtemp(prefix='veilleur-agy-poc-'))
    exe = shutil.which('agy')
    prompt = 'Essai synthétique isolé. Ne lance aucun outil, ne lis et ne modifie aucun fichier. Réponds uniquement PRET.'
    evidence = {'synthetic_only': True, 'run_id': run_id, 'temporary_dir': str(root),
                'prompt': prompt, 'max_remote_calls': 1, 'target_existing_session': False}
    if not exe:
        evidence['error'] = 'AGY CLI introuvable'
    else:
        args = [exe, '--mode', 'plan', '--sandbox', '--disable-slash-commands',
                '--print-timeout', '45s', '--output-format', 'json', '--print', prompt]
        evidence['args'] = args
        start = time.monotonic()
        try:
            proc = subprocess.run(args, cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                                  text=True, encoding='utf8', errors='replace', timeout=60,
                                  creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            evidence.update(returncode=proc.returncode, stdout=proc.stdout, stderr=proc.stderr)
            try:
                evidence['parsed'] = json.loads(proc.stdout)
            except json.JSONDecodeError:
                evidence['parsed'] = None
        except subprocess.TimeoutExpired as exc:
            evidence.update(returncode=None, error='timeout', stdout=str(exc.stdout or ''), stderr=str(exc.stderr or ''))
        evidence['seconds'] = round(time.monotonic()-start, 3)
    output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf8')
    print('PREUVE:', output)
    print('EXIT:', evidence.get('returncode'), 'SECONDS:', evidence.get('seconds'))
    print('STDOUT:', evidence.get('stdout', '')[-2500:])
    print('STDERR:', evidence.get('stderr', '')[-2500:])
    return 0 if evidence.get('returncode') == 0 and evidence.get('parsed') is not None else 1


if __name__ == '__main__':
    sys.exit(main())
