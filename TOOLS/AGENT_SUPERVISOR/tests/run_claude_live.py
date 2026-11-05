"""Opt-in end-to-end test against the explicitly created synthetic Claude session."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server

SYNTHETIC_ID = '8eb773b6-27bf-4cec-9a57-e5cf0b944dab'


def main():
    if len(sys.argv) != 2:
        raise ValueError('Donner un nouveau dossier scratch autorisé')
    scratch = Path(sys.argv[1])
    scratch.mkdir(parents=True, exist_ok=False)
    cli = shutil.which('claude')
    if not cli:
        raise RuntimeError('Claude Code introuvable')
    server = create_server(0, scratch / 'state.json')
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f'http://127.0.0.1:{server.server_port}'
    started = time.monotonic()
    try:
        with urlopen(base + '/api/supervision') as response:
            token = json.load(response)['token']
        def command(payload):
            req = Request(base+'/api/supervision', data=json.dumps(payload).encode(), headers={'Content-Type':'application/json','X-Supervision-Token':token})
            with urlopen(req, timeout=5) as response:
                return json.load(response)
        command({'action':'configure','model':'qwen3:8b','allow_cloud':False})
        result = command({'action':'add','platform':'claude','native_id':SYNTHETIC_ID,'alias':'Essai synthétique Claude','mission':'Suivre un diagnostic utile sans inventer de dérive ; aucune modification de fichier.'})
        sid = result['sessions'][0]['id']
        command({'action':'start'})
        print('Attendu : Claude répond au message synthétique, le Veilleur lit cette réponse et ne crée pas d’alerte injustifiée.', flush=True)
        prompt = 'Pour cet essai synthétique, réponds uniquement : Je consulte le journal avant de conclure.'
        process = subprocess.run([cli, '-p', prompt, '--resume', SYNTHETIC_ID, '--tools', '', '--output-format', 'text'],
                                 capture_output=True, text=True, encoding='utf8', errors='replace', timeout=90,
                                 creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        print('Claude retour :', process.returncode, 'réponse :', process.stdout.strip(), flush=True)
        if process.returncode:
            raise RuntimeError('Claude Code en échec : ' + process.stderr[-500:])
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            with urlopen(base + '/api/supervision', timeout=3) as response:
                snapshot = json.load(response)
            session = next(item for item in snapshot['sessions'] if item['id'] == sid)
            if session['last_event'] and session['analysis_state'] in ('no_alert', 'alert', 'unavailable'):
                break
            time.sleep(.25)
        print(json.dumps({'source_state':session['state'],'last_event':session['last_event'],
                          'analysis_state':session['analysis_state'],'analysis_error':session['analysis_error'],
                          'alert_count':len(session['alerts']),'seconds':round(time.monotonic()-started,2),
                          'scratch':str(scratch)}, ensure_ascii=False, indent=2), flush=True)
        return 0 if session['state']=='active' and session['analysis_state']=='no_alert' and not session['alerts'] else 1
    finally:
        server.shutdown()
        server.supervision.close()
        server.server_close()
        worker.join(timeout=3)


if __name__ == '__main__':
    raise SystemExit(main())
