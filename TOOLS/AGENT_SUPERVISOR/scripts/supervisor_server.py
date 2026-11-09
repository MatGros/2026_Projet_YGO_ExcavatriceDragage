"""Loopback-only standalone Veilleur server. No Task Manager dependency."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import os
import hashlib
from urllib.parse import urlparse, parse_qs

try:
    from .supervisor_service import Supervisor
except ImportError:
    from supervisor_service import Supervisor

UI = Path(__file__).resolve().parents[1] / 'ui' / 'index.html'
SCRIPT_DIR = Path(__file__).resolve().parent
BUILD_FILES = (Path(__file__), SCRIPT_DIR / 'supervisor_service.py', SCRIPT_DIR / 'session_watcher.py',
               SCRIPT_DIR / 'platform_adapters.py', SCRIPT_DIR / 'agent_chat.py', SCRIPT_DIR / 'dsh_session_watcher.py',
               SCRIPT_DIR / 'dsh_zstd_decode.mjs', SCRIPT_DIR / 'finding_lifecycle.py')


def build_id():
    digest = hashlib.sha256()
    for path in BUILD_FILES:
        digest.update(path.name.encode('utf8'))
        digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


def ui_build_id():
    return hashlib.sha256(UI.read_bytes()).hexdigest()[:12]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, value, content_type='application/json; charset=utf-8'):
        raw = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(raw)

    def local(self):
        host = self.headers.get('Host', '')
        return (self.client_address[0] == '127.0.0.1'
                and host in (f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}')
                and self.headers.get('Origin') in (None, 'http://' + host))

    def service_info(self):
        try:
            update = build_id() != self.server.build_id
            interface = ui_build_id()
        except OSError:
            update = None
            interface = None
        return {'service_version': 2, 'build_id': self.server.build_id, 'ui_build_id': interface, 'update_available': update,
                'default_storage': self.server.default_storage}

    def do_GET(self):
        if not self.local():
            return self.reply(403, {'error': 'Local origin required'})
        path = urlparse(self.path).path
        if path in ('/', '/index.html', '/AGENT_SUPERVISION.html'):
            return self.reply(200, UI.read_bytes(), 'text/html; charset=utf-8')
        if path == '/health':
            return self.reply(200, dict(service='agent-supervisor', **self.service_info()))
        if path == '/api/supervision/summary':
            return self.reply(200, self.server.supervision.notification_snapshot())
        if path == '/api/supervision':
            result = self.server.supervision.snapshot()
            result.update(self.service_info())
            result['token'] = self.server.supervision_token
            return self.reply(200, result)
        if path == '/api/supervision/candidates':
            return self.reply(200, self.server.supervision.candidates())
        if path == '/api/supervision/history':
            try:
                sid = parse_qs(urlparse(self.path).query).get('id', [''])[0]
                return self.reply(200, self.server.supervision.history(sid))
            except (ValueError, OSError, KeyError, TypeError) as exc:
                return self.reply(400, {'error': str(exc)})
        return self.reply(404, {'error': 'Unknown route'})

    def do_POST(self):
        if not self.local() or not secrets.compare_digest(self.headers.get('X-Supervision-Token', ''), self.server.supervision_token):
            return self.reply(403, {'error': 'Local origin and token required'})
        if urlparse(self.path).path != '/api/supervision':
            return self.reply(404, {'error': 'Unknown route'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 65536:
                return self.reply(413, {'error': 'Invalid body size'})
            command = json.loads(self.rfile.read(size))
            if not isinstance(command, dict):
                raise ValueError('Object required')
            self.server.supervision.command(command)
            result = self.server.supervision.snapshot()
            result.update(self.service_info())
            result['token'] = self.server.supervision_token
            return self.reply(200, result)
        except (ValueError, OSError, KeyError, TypeError) as exc:
            return self.reply(400, {'error': str(exc)})


def create_server(port=8082, state_path=None):
    home = Path.home()
    default_path = Path(os.environ.get('LOCALAPPDATA', home / '.local/share')) / 'ExcavatriceDragage/agent-supervision.json'
    state_path = Path(state_path) if state_path else default_path
    state_path = state_path.resolve()
    state_path.parent.mkdir(parents=True, exist_ok=True)
    lock = open(str(state_path) + '.lock', 'a+b')
    try:
        if os.name == 'nt':
            import msvcrt
            lock.seek(0, 2)
            if lock.tell() == 0:
                lock.write(b'0'); lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
        server.supervision = Supervisor(state_path=state_path, strict_assignments=True, persist_chat=True)
    except Exception:
        lock.close()
        raise
    server.storage_lock = lock
    server.default_storage = state_path == default_path.resolve()
    server.build_id = build_id()
    original_close = server.server_close
    def close_server():
        original_close()
        lock.close()
    server.server_close = close_server
    server.supervision_token = secrets.token_urlsafe(32)
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8082)
    parser.add_argument('--state', type=Path)
    args = parser.parse_args()
    server = create_server(args.port, args.state)
    server.supervision.command({'action': 'start'})
    print(f'Veilleur: http://127.0.0.1:{server.server_port}/')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.supervision.close()
        server.server_close()


if __name__ == '__main__':
    main()
