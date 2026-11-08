import json
import hashlib
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import threading
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server
from TOOLS.TASK_MANAGER.task_server import RemoteSupervisor, find_or_start_supervisor

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'supervisor_server.py'


def available_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def test_standalone_process_and_task_manager_relay_share_one_collector(tmp_path):
    state = tmp_path / 'state.json'
    port = available_port()
    process = subprocess.Popen([sys.executable, str(SCRIPT), '--port', str(port), '--state', str(state)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    base = f'http://127.0.0.1:{port}'
    try:
        deadline = time.monotonic() + 6
        while True:
            try:
                with urlopen(base + '/health', timeout=.5) as response:
                    assert json.load(response)['service'] == 'agent-supervisor'
                break
            except (URLError, TimeoutError):
                assert process.poll() is None and time.monotonic() < deadline
                time.sleep(.05)
        with urlopen(base + '/') as response:
            assert 'Agent Supervisor' in response.read().decode('utf8')
        with pytest.raises(HTTPError) as denied:
            urlopen(Request(base + '/api/supervision', data=b'{"action":"stop"}', method='POST'))
        assert denied.value.code == 403
        with pytest.raises(HTTPError) as denied:
            urlopen(Request(base + '/api/supervision', headers={'Origin':'https://invalid.example'}))
        assert denied.value.code == 403
        relay = RemoteSupervisor(port)
        assert relay.snapshot()['running'] is True
        relay.command({'action':'stop'})
        assert relay.snapshot()['running'] is False
        relay.command({'action':'start'})
        assert relay.snapshot()['running'] is True
        second = subprocess.run([sys.executable, str(SCRIPT), '--port', str(available_port()), '--state', str(state)],
                                capture_output=True, timeout=5, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        assert second.returncode != 0, 'different ports must not share storage'
        assert process.poll() is None
    finally:
        process.terminate()
        process.wait(timeout=5)


def test_occupied_port_releases_storage_lock(tmp_path):
    with socket.socket() as occupied:
        occupied.bind(('127.0.0.1', 0))
        occupied.listen()
        state = tmp_path / 'state.json'
        with pytest.raises(OSError):
            create_server(occupied.getsockname()[1], state)
        server = create_server(0, state)
        server.supervision.close()
        server.server_close()


def test_task_manager_starts_then_finds_same_standalone(tmp_path, monkeypatch):
    import TOOLS.TASK_MANAGER.task_server as task_server
    children = []
    original = task_server.subprocess.Popen
    def capture(*args, **kwargs):
        process = original(*args, **kwargs)
        children.append(process)
        return process
    monkeypatch.setattr(task_server.subprocess, 'Popen', capture)
    port = available_port()
    try:
        first = find_or_start_supervisor(port, tmp_path / 'state.json')
        second = find_or_start_supervisor(port, tmp_path / 'state.json')
        assert len(children) == 1
        assert first.started_here is True and second.started_here is False
        assert first.snapshot()['running'] and second.snapshot()['running']
        first.command({'action':'stop'})
        assert second.snapshot()['running'] is False
    finally:
        for child in children:
            child.terminate()
            child.wait(timeout=5)


def test_health_reports_loaded_build_and_changed_files(tmp_path):
    server = create_server(0, tmp_path / 'state.json')
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        url = f'http://127.0.0.1:{server.server_port}/health'
        with urlopen(url) as response:
            health = json.load(response)
        assert health['service_version'] == 2 and health['build_id'] == server.build_id
        assert health['update_available'] is False
        server.build_id = 'outdated-build'
        with urlopen(url) as response:
            assert json.load(response)['update_available'] is True
    finally:
        server.shutdown()
        server.supervision.close()
        server.server_close()
        worker.join(timeout=2)


def test_notification_summary_is_read_only_and_excludes_chat_and_token(tmp_path):
    server = create_server(0, tmp_path / 'state.json')
    sid = '11111111-1111-4111-8111-111111111111'
    session = server.supervision._new_session(sid, 'claude', 'native-session-id', 'TEST session', False, 'private mission')
    session.update(state='paused', analysis_state='alert', last_event='2026-11-08T10:00:00Z')
    session['memory'] = [{'text': 'private memory'}]
    session['judge_request'] = {'payload': {'prompt': 'private judge prompt'}}
    session['events'] = [{'text': 'private event'}]
    session['framing'] = [{'text': 'private framing'}]
    session['alerts'] = [dict(id='alert-1', severity='warning', reason='TEST reason', evidence='TEST quote',
                              category='other', created_at='2026-11-08T10:00:00Z', last_occurrence='2026-11-08T10:00:00Z',
                              occurrences=1, disposition='new', acknowledged_at=None,
                              workflow={'status':'awaiting_choice', 'delivery_status':'not_sent'})]
    session['alerts'][0]['comments'] = [{'text': 'private comment', 'author': 'user'}]
    session['alerts'][0]['history'] = [{'reason': 'private historical reason'}]
    server.supervision.sessions[sid] = session
    server.supervision._chat_histories[sid] = [{'role':'user', 'text':'private chat'}]
    server.supervision.running = True
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        with urlopen(f'http://127.0.0.1:{server.server_port}/api/supervision/summary') as response:
            summary = json.load(response)
        assert summary == {
            'schema_version': 1,
            'running': True,
            'counts': {'unread': 1, 'open': 1, 'deferred': 0, 'closed': 0, 'follow_up': 1,
                       'warnings': 1, 'alarms': 0, 'resolution_proposed': 0},
            'sessions': [{
                'id': sid, 'platform': 'claude', 'native_id': 'native-session-id', 'alias': 'TEST session',
                'state': 'paused', 'analysis_state': 'alert', 'last_event': '2026-11-08T10:00:00Z',
                'last_analysis': None,
                'counts': {'unread': 1, 'open': 1, 'deferred': 0, 'closed': 0, 'follow_up': 1,
                           'warnings': 1, 'alarms': 0, 'resolution_proposed': 0},
                'alerts': [{
                    'id': 'alert-1', 'severity': 'warning', 'reason': 'TEST reason',
                    'evidence_hash': hashlib.sha256('TEST quote'.encode('utf8')).hexdigest()[:24],
                    'category': 'other', 'created_at': '2026-11-08T10:00:00Z',
                    'last_occurrence': '2026-11-08T10:00:00Z', 'occurrences': 1, 'disposition': 'new',
                    'acknowledged_at': None, 'workflow_status': 'awaiting_choice', 'delivery_status': 'not_sent',
                    'business_state': 'open', 'version': 1, 'reference': 'A-alert-1',
                    'assessment': {'status': 'active', 'updated_at': '2026-11-08T10:00:00Z'}
                }]
            }]
        }
        encoded = json.dumps(summary)
        for private_value in ('private mission', 'private memory', 'private judge prompt', 'private chat',
                              'private event', 'private framing', 'private comment', 'private historical reason',
                              'TEST quote', 'token'):
            assert private_value not in encoded
    finally:
        server.shutdown()
        server.supervision.close()
        server.server_close()
        worker.join(timeout=2)


def test_task_manager_keeps_running_service_if_update_refused(monkeypatch):
    import TOOLS.TASK_MANAGER.task_server as task_server
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, *args):
            return json.dumps({'service':'agent-supervisor','service_version':2,'default_storage':True,'update_available':True}).encode()
    monkeypatch.setattr(task_server.urllib.request, 'urlopen', lambda *args, **kwargs: Response())
    class Refused:
        returncode=1
        stderr='Une affectation ou un chat actif existe'
    monkeypatch.setattr(task_server.subprocess, 'run', lambda *args, **kwargs: Refused())
    result=find_or_start_supervisor()
    assert result.started_here is False
    assert 'conserve en fonctionnement' in result.notice


def test_task_manager_never_auto_restarts_custom_storage(monkeypatch):
    import TOOLS.TASK_MANAGER.task_server as task_server
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, *args):
            return json.dumps({'service':'agent-supervisor','service_version':2,'default_storage':False,'update_available':True}).encode()
    monkeypatch.setattr(task_server.urllib.request, 'urlopen', lambda *args, **kwargs: Response())
    monkeypatch.setattr(task_server.subprocess, 'run', lambda *args, **kwargs: pytest.fail('must not restart custom storage'))
    result=find_or_start_supervisor()
    assert 'recharger le service configure' in result.notice
