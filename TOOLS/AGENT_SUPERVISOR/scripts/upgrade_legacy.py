"""Upgrade an idle loopback server, retaining its in-memory chat.

Only a recognized server with no analysis or chat currently in progress is accepted.
The backup is never removed. No transcript or agent is controlled.
"""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen

BASE = 'http://127.0.0.1:8082'
RECOVERY = {'stopped': False, 'pid': None, 'token': None, 'was_running': False}
LEGACY_ALERT_WORKFLOW = {'status': 'legacy', 'delivery_status': 'not_sent', 'choice': None,
                         'rationale': '', 'chosen_at': None, 'response': ''}


def stable_sessions(snapshot):
    """Compare retained user data while ignoring only the v2 default added to legacy alerts."""
    keys = ('id', 'platform', 'native_id', 'alias', 'mission', 'initial_mission', 'alerts', 'chat_messages', 'memory')
    result = []
    for item in snapshot.get('sessions', []):
        saved = {key: item.get(key) for key in keys}
        saved['alerts'] = []
        for alert in item.get('alerts', []):
            normalized = dict(alert)
            if normalized.get('workflow') == LEGACY_ALERT_WORKFLOW:
                normalized.pop('workflow')
            saved['alerts'].append(normalized)
        result.append(saved)
    return sorted(result, key=lambda item: item['id'])


def get(path):
    with urlopen(BASE + path, timeout=3) as response:
        return json.load(response)


def post(token, payload):
    req = Request(BASE + '/api/supervision', data=json.dumps(payload).encode('utf8'),
                  headers={'Content-Type': 'application/json', 'X-Supervision-Token': token})
    with urlopen(req, timeout=5) as response:
        return json.load(response)


def listener_pid():
    result = subprocess.run(['netstat', '-ano', '-p', 'tcp'], capture_output=True, text=True, encoding='utf8', errors='replace', check=True,
                            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    matches = re.findall(r'^\s*TCP\s+127\.0\.0\.1:8082\s+\S+\s+LISTENING\s+(\d+)\s*$', result.stdout, re.M | re.I)
    if len(matches) != 1:
        raise RuntimeError('Impossible d’identifier uniquement le serveur local sur 8082')
    return int(matches[0])


def source_stamp(path):
    if not path:
        return None
    try:
        stat = Path(path).stat()
        return [stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns]
    except OSError:
        return None


def preserves_previous(old, new):
    """Allow additive migration fields while preserving every old value and list item."""
    if isinstance(old, dict):
        return isinstance(new, dict) and all(key in new and preserves_previous(value, new[key]) for key, value in old.items())
    if isinstance(old, list):
        return isinstance(new, list) and len(old) == len(new) and all(preserves_previous(a, b) for a, b in zip(old, new))
    return old == new


def main():
    if os.name != 'nt':
        raise RuntimeError('Migration automatique disponible uniquement sous Windows')
    health, current = get('/health'), get('/api/supervision')
    if health.get('service') != 'agent-supervisor' or not (health.get('version') == 1 or health.get('service_version') == 2):
        raise RuntimeError('Le service actif n’est pas un Veilleur reconnu')
    if health.get('default_storage') is False:
        raise RuntimeError('Stockage personnalisé : migration automatique refusée')
    sessions = current.get('sessions', [])
    was_running = bool(current.get('running'))
    if current.get('chat', {}).get('state') not in ('idle', 'unavailable') or any(s.get('analysis_state') in ('queued', 'analyzing') for s in sessions):
        raise RuntimeError('Une analyse ou un chat est en cours : migration interrompue')
    if sessions and any('memory' not in s or 'chat_messages' not in s for s in sessions):
        raise RuntimeError('Cette ancienne version ne permet pas de sauvegarder les sessions : migration interrompue')
    previous = {s['id']: {'state':s['state'], 'source':s.get('source'), 'stamp':source_stamp(s.get('source'))} for s in sessions}
    pid = listener_pid()
    token = current['token']
    print('Serveur Veilleur identifié ; arrêt de sa collecte avant sauvegarde.', flush=True)
    post(token, {'action':'stop'})
    RECOVERY.update(stopped=True, pid=pid, token=token, was_running=was_running)
    frozen = get('/api/supervision')
    if frozen.get('running') or {s['id'] for s in frozen.get('sessions', [])} != set(previous):
        raise RuntimeError('Etat modifié pendant la préparation ; aucun processus arrêté')
    chat = frozen.get('chat', {})
    messages = chat.get('messages', [])
    if not isinstance(messages, list):
        raise RuntimeError('Chat illisible : migration interrompue')
    base = Path(os.environ.get('LOCALAPPDATA', Path.home() / '.local/share')) / 'ExcavatriceDragage' / 'supervision-backups'
    base.mkdir(parents=True, exist_ok=True)
    backup = base / ('legacy_chat_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '.json')
    payload = {'session_id': chat.get('session_id'), 'messages': messages}
    saved = {'chat':payload, 'sessions':frozen.get('sessions', []), 'previous':previous}
    with backup.open('x', encoding='utf8') as stream:
        json.dump(saved, stream, ensure_ascii=False, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    if json.loads(backup.read_text(encoding='utf8')) != saved:
        raise RuntimeError('Sauvegarde non vérifiée ; aucun processus arrêté')
    check = get('/api/supervision')
    if listener_pid() != pid or check.get('chat', {}).get('messages') != messages or stable_sessions(check) != stable_sessions(frozen):
        raise RuntimeError('Le serveur ou le chat a changé ; sauvegarde conservée, aucun processus arrêté')
    print(f'Sauvegarde vérifiée : {backup} ({len(messages)} messages).', flush=True)
    os.kill(pid, signal.SIGTERM)
    RECOVERY['stopped'] = False  # The old server no longer owns the port.
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        try:
            old_pid = listener_pid()
        except RuntimeError:
            break
        if old_pid != pid:
            raise RuntimeError(f'Le port est occupé par un autre processus ; sauvegarde : {backup}')
        time.sleep(.1)
    else:
        raise RuntimeError(f'Le serveur historique ne s’est pas arrêté ; sauvegarde : {backup}')
    server_script = Path(__file__).with_name('supervisor_server.py')
    process = subprocess.Popen([sys.executable, str(server_script), '--port', '8082'],
                               creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        try:
            health = get('/health')
            if health.get('service_version') == 2:
                break
        except OSError:
            pass
        if process.poll() is not None:
            raise RuntimeError(f'Nouveau serveur arrêté ; sauvegarde disponible : {backup}')
        time.sleep(.1)
    else:
        raise RuntimeError(f'Nouveau serveur indisponible ; sauvegarde disponible : {backup}')
    new = get('/api/supervision')
    restored_sessions = {s['id']:s for s in new.get('sessions', [])}
    if set(restored_sessions) != set(previous):
        raise RuntimeError(f'Affectations non restaurées ; sauvegarde disponible : {backup}')
    for old in frozen.get('sessions', []):
        restored = restored_sessions[old['id']]
        for key in ('platform', 'native_id', 'alias', 'mission', 'initial_mission', 'alerts', 'chat_messages'):
            if not preserves_previous(old.get(key), restored.get(key)):
                raise RuntimeError(f'{key} de session non restauré ; sauvegarde disponible : {backup}')
    selected = payload['session_id']
    restored_chat = new['chat']['messages'] if selected is None else restored_sessions[selected].get('chat_messages', [])
    if messages and restored_chat != messages:
        new = post(new['token'], {'action':'import_chat', **payload})
        if selected is None and new['chat']['messages'] != messages:
            raise RuntimeError(f'Import non confirmé ; sauvegarde disponible : {backup}')
    resumed, attention = 0, []
    if was_running:
        for old in frozen.get('sessions', []):
            sid, prior = old['id'], previous[old['id']]
            if prior['state'] not in ('active', 'waiting'):
                continue
            if prior['stamp'] is None or source_stamp(prior['source']) != prior['stamp']:
                attention.append(old['alias'] + ' : source modifiée pendant la mise à jour ; session en pause')
                continue
            post(new['token'], {'action':'resume', 'id':sid})
            if old.get('memory'):
                post(new['token'], {'action':'restore_memory', 'id':sid, 'memory':old['memory']})
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                latest = get('/api/supervision')
                item = next(s for s in latest['sessions'] if s['id'] == sid)
                if item['state'] == 'active':
                    break
                time.sleep(.1)
            if source_stamp(prior['source']) != prior['stamp'] or item['state'] != 'active':
                post(new['token'], {'action':'pause', 'id':sid})
                attention.append(old['alias'] + ' : continuité non confirmée ; session en pause')
            else:
                resumed += 1
    else:
        post(new['token'], {'action':'stop'})
    print(f"Nouveau service v{health['service_version']} ({health['build_id']}) actif ; {len(messages)} messages et {len(previous)} affectations conservés, {resumed} reprises.", flush=True)
    for warning in attention:
        print('À vérifier : ' + warning, flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'Migration interrompue : {exc}', file=sys.stderr, flush=True)
        if RECOVERY['stopped'] and RECOVERY['was_running']:
            try:
                if listener_pid() == RECOVERY['pid']:
                    post(RECOVERY['token'], {'action':'start'})
                    print('Ancien Veilleur relancé. Vérifiez les messages reçus pendant l’interruption.', file=sys.stderr, flush=True)
            except Exception as recovery_error:
                print(f'Reprise de l’ancien Veilleur non confirmée : {recovery_error}', file=sys.stderr, flush=True)
        sys.exit(1)
