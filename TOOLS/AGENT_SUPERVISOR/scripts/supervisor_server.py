"""Loopback-only standalone Supervisor server. No Task Manager dependency."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import os
import hashlib
import signal
import subprocess
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
        if path == '/api/supervision/review':
            query = parse_qs(urlparse(self.path).query)
            try:
                result = self.server.supervision.review_snapshot(
                    query.get('session', [''])[0], int(query.get('offset', ['0'])[0]),
                    query.get('revision', [None])[0])
                return self.reply(200, result)
            except KeyError:
                return self.reply(404, {'error': 'Session inconnue'})
            except ValueError as exc:
                return self.reply(400, {'error': str(exc)})
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


def log_line(message: str) -> None:
    """Journal du serveur : trace qui tourne, qui est tue, qui s arrete (R29)."""
    try:
        from datetime import datetime
        log_dir = Path(os.environ.get('LOCALAPPDATA', Path.home() / '.local/share')) / 'ExcavatriceDragage'
        with open(log_dir / 'agent-supervisor-server.log', 'a', encoding='utf-8') as handle:
            handle.write(f"{datetime.now().isoformat(timespec='seconds')} pid={os.getpid()} {message}\n")
    except OSError:
        pass


def kill_port_listeners(port: int) -> None:
    """M27 (decision exploitant 2026-11-15) : AU LANCEMENT, tout ce qui ecoute le port est tue.
    Aucune instance precedente n est reutilisee et nul ne fait foi : le serveur demarre toujours
    sur du code frais et un port libre. Les PID du netstat sont tures sauf le notre."""
    try:
        out = subprocess.run(['netstat', '-ano'], capture_output=True, text=True,
                             encoding='utf-8', errors='replace', timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return
    my_pid = os.getpid()
    for line in out.splitlines():
        stripped = line.strip()
        if f':{port} ' not in stripped + ' ' or 'LISTENING' not in stripped:
            continue
        try:
            pid = int(stripped.rsplit(None, 1)[-1])
        except (ValueError, IndexError):
            continue
        if pid == my_pid or pid <= 0:
            continue
        try:
            print(f"[supervisor] port {port} : arrêt de l'instance précédente PID {pid}", flush=True)
            log_line(f"kill port {port} pid={pid}")
            os.kill(pid, signal.SIGTERM)
        except (OSError, ValueError):
            pass


def create_server(port=8082, state_path=None):
    # R29 (demande exploitant) : au lancement on purge aussi les ports voisins du
    # superviseur (8081 relance TM, 8092 serveur d'essai), pas seulement le notre.
    log_line(f"demarrage : purge des ports 8081 8082 8092 avant bind sur {port}")
    for known in (8081, 8092):
        if known != port:
            kill_port_listeners(known)
    kill_port_listeners(port)
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
        server = type('Server', (ThreadingHTTPServer,), {'daemon_threads': True})(('127.0.0.1', port), Handler)
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
    try:
        server = create_server(args.port, args.state)
    except Exception:
        import traceback
        log_line('ECHEC au demarrage :\n' + traceback.format_exc())
        raise
    server.supervision.command({'action': 'start'})
    log_line(f"serveur PRET port={server.server_port} build={server.build_id} ui={ui_build_id()}")
    print(f'Supervisor: http://127.0.0.1:{server.server_port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    except Exception:
        import traceback
        traceback.print_exc()
        raise
    finally:
        log_line("arret du serveur")
        server.supervision.close()
        server.server_close()


if __name__ == '__main__':
    main()
