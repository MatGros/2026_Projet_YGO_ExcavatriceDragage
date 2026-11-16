"""Loopback-only standalone Supervisor server. No Task Manager dependency."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import os
import sys
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


LOG_ROTATE_BYTES = 2 * 1024 * 1024  # R29 : rotation simple a 2 Mo, une seule archive


def log_line(message: str) -> None:
    """Journal du serveur : trace qui tourne, qui est tue, qui s arrete, qui interroge (R29)."""
    try:
        from datetime import datetime
        log_dir = Path(os.environ.get('LOCALAPPDATA', Path.home() / '.local/share')) / 'ExcavatriceDragage'
        log_path = log_dir / 'agent-supervisor-server.log'
        try:
            if log_path.exists() and log_path.stat().st_size > LOG_ROTATE_BYTES:
                log_path.replace(log_path.with_name('agent-supervisor-server.log.1'))
        except OSError:
            pass
        with open(log_path, 'a', encoding='utf-8') as handle:
            handle.write(f"{datetime.now().isoformat(timespec='seconds')} pid={os.getpid()} {message}\n")
    except OSError:
        pass


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, value, content_type='application/json; charset=utf-8'):
        raw = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode('utf-8')
        # R29 : trace debug des requetes — POST (commandes) et erreurs ; les GET 200
        # (polls IHM toutes les 2 s) restent silencieux pour ne pas inonder le journal.
        try:
            verb = self.command
            route = urlparse(self.path).path
            if verb == 'POST' or status >= 400:
                log_line(f"HTTP {verb} {route} -> {status} ({len(raw)} o)")
        except Exception:
            pass
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
            log_line(f"commande action={command.get('action')} id={command.get('id') or '-'}")
            self.server.supervision.command(command)
            result = self.server.supervision.snapshot()
            result.update(self.service_info())
            result['token'] = self.server.supervision_token
            log_line(f"commande action={command.get('action')} -> ok")
            return self.reply(200, result)
        except (ValueError, OSError, KeyError, TypeError) as exc:
            log_line(f"commande -> ECHEC : {type(exc).__name__}: {exc}")
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
    sur du code frais et un port libre. Les PID du netstat sont tures sauf le notre.

    R29 (2026-11-16, incident prove) : le filtre par sous-chaine ':<port> ' matchait la
    colonne DISTANTE (0.0.0.0:0 sur toute ligne LISTENING). Avec port=0 (tests), la fonction
    tuait TOUS les listeners de la machine. Desormais : parsing par colonnes, l adresse
    LOCALE seule decide, et une purge sans port (<= 0) est ignoree."""
    if port is None or port <= 0:
        log_line(f"port {port} : purge ignoree (sans port concret, rien a tuer)")
        return
    try:
        out = subprocess.run(['netstat', '-ano'], capture_output=True, text=True,
                             encoding='utf-8', errors='replace', timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return
    my_pid = os.getpid()
    killed = []
    for line in out.splitlines():
        stripped = line.strip()
        if 'LISTENING' not in stripped:
            continue
        columns = stripped.split()
        if len(columns) < 4:
            continue
        local_address = columns[1]
        if not local_address.endswith(f':{port}'):
            continue
        try:
            pid = int(columns[-1])
        except (ValueError, IndexError):
            continue
        if pid == my_pid or pid <= 0:
            continue
        try:
            print(f"[supervisor] port {port} : arrêt de l'instance précédente PID {pid}", flush=True)
            log_line(f"kill port {port} pid={pid}")
            killed.append(pid)
            os.kill(pid, signal.SIGTERM)
        except (OSError, ValueError):
            pass
    # R29 : apres les kills on REVÉRIFIE le port et le verdict est trace.
    if not killed:
        log_line(f"port {port} : rien a purger (deja libre)")
        return
    import time as _time
    _time.sleep(1.0)
    try:
        recheck = subprocess.run(['netstat', '-ano'], capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        log_line(f"port {port} : verdict indetermine (netstat indisponible), kills={killed}")
        return
    survivors = []
    for line in recheck.splitlines():
        stripped = line.strip()
        if 'LISTENING' not in stripped:
            continue
        columns = stripped.split()
        if len(columns) < 4 or not columns[1].endswith(f':{port}'):
            continue
        try:
            survivors.append(int(columns[-1]))
        except (ValueError, IndexError):
            continue
    remaining = [pid for pid in survivors if pid != my_pid and pid > 0]
    if remaining:
        log_line(f"VERDICT port {port} : ENCORE OCCUPE par pid(s) {remaining} (killed={killed})")
    else:
        log_line(f"VERDICT port {port} : libere (killed={killed})")


def _silence_client_abort(self, request, client_address):
    """R29 : les pollers qui coupent leur connexion en cours d'ecriture produisent
    ConnectionAborted/ConnectionReset — bruit, pas un defaut. On le tait ; tout
    autre probleme reste trace."""
    import sys
    if sys.exc_info()[0] in (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
        return
    import traceback
    traceback.print_exc()


def create_server(port=8082, state_path=None):
    # R29 - architecture exploitant (un python par service) : le superviseur ne purge
    # que SON port. Pas de croisade sur 8081/8092 : chaque service est maitre chez lui.
    log_line(f"SCRIPT LANCE : {Path(sys.argv[0]).resolve()} args={sys.argv[1:] or '[aucun]'}")
    # R29 (incident 2026-11-16) : port=0 (tests, socket ephemere) = aucune purge.
    if port is None or port <= 0:
        log_line("bind ephemere (port 0) : purge ignoree")
    else:
        log_line(f"demarrage : purge du port {port} avant bind")
        kill_port_listeners(port)
    home = Path.home()
    default_path = Path(os.environ.get('LOCALAPPDATA', home / '.local/share')) / 'ExcavatriceDragage/agent-supervision.json'
    state_path = Path(state_path) if state_path else default_path
    state_path = state_path.resolve()
    state_path.parent.mkdir(parents=True, exist_ok=True)
    log_line(f"etat persiste : {state_path}")
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
        server = type('Server', (ThreadingHTTPServer,), {
            'daemon_threads': True,
            'handle_error': _silence_client_abort,
        })(('127.0.0.1', port), Handler)
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
    log_line(f"serveur PRET port={server.server_port} build={server.build_id} ui={ui_build_id()} "
             f"python={sys.version.split()[0]}")
    print(f'Supervisor: http://127.0.0.1:{server.server_port}/', flush=True)
    # Pattern canonique (docs.python) : serve_forever dans un THREAD, Ctrl+C attrape
    # dans le thread principal, shutdown() appele depuis un autre thread que la boucle.
    import threading

    def run_forever(server_ref):
        """R29 : le thread journalise proprement ce qui le tue — un serveur qui meurt
        sans explication est inacceptable (constat exploitant 2026-11-16)."""
        try:
            server_ref.serve_forever()
        except Exception:
            import traceback
            log_line('THREAD SERVEUR MORT :\n' + traceback.format_exc())
            raise

    run_thread = threading.Thread(target=run_forever, args=(server,), daemon=True, name='supervisor-serve')
    run_thread.start()
    # R29 : Event().wait() infini n est PAS interruptible par Ctrl+C sur Windows
    # (preuve exploitant 2026-11-16 : l exception sortait dans le thread serve_forever).
    # Boucle d attente par tranches courtes : le Ctrl+C se leve sur le thread principal.
    try:
        while run_thread.is_alive():
            run_thread.join(0.5)
    except KeyboardInterrupt:
        log_line('arret du serveur (Ctrl+C)')
    finally:
        # Le thread peut deja etre mort (trace dans le journal) : shutdown() n'attendrait
        # rien et peut se bloquer a l'infini dans ce cas.
        if run_thread.is_alive():
            try:
                server.shutdown()
            except Exception:
                pass
        try:
            server.supervision.close(timeout=3)
        except Exception:
            pass
        try:
            server.server_close()
        except Exception:
            pass
        os._exit(0)  # garantie de mort : tue tout thread residuel, sans negocier


if __name__ == '__main__':
    main()
