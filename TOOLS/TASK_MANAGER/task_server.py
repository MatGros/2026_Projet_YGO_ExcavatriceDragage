#!/usr/bin/env python3
"""Serveur local Task Manager : taches YAML, verrous JSON separes."""
from __future__ import annotations

import hashlib
import http.server
import json
import os
import secrets
import sys
import threading
import time
import urllib.parse
import urllib.request
import subprocess
import webbrowser
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WFLOW = ROOT / "DOC" / "WFLOW"
TASKS_PATH = WFLOW / "TASKS.yaml"
LOCKS_PATH = WFLOW / "TASK_LOCKS.json"
MUTEX_PATH = WFLOW / ".task_manager.write.lock"
HOST, PORT = "127.0.0.1", 8081
UI = ROOT / "TOOLS" / "TASK_MANAGER" / "ui"  # pages web (viewers) ; les donnees restent dans WFLOW
VIEWERS = frozenset({"TASK_VIEWER.html", "ORCHESTRATOR_VIEWER.html"})
LOCAL_MUTEX = threading.Lock()
VERBOSE = False


class RemoteSupervisor:
    """Relay to the single standalone collector; never owns a collector."""
    def __init__(self, port=8082):
        self.base = f"http://127.0.0.1:{port}"
        self.started_here = False
        self.notice = None

    def snapshot(self):
        with urllib.request.urlopen(self.base + "/api/supervision", timeout=3) as response:
            data = json.load(response)
        data.pop("token", None)
        return data

    def command(self, payload):
        with urllib.request.urlopen(self.base + "/api/supervision", timeout=3) as response:
            token = json.load(response)["token"]
        request = urllib.request.Request(self.base + "/api/supervision", data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", "X-Supervision-Token": token})
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.load(response)


def find_or_start_supervisor(port=8082, state_path=None):
    service = RemoteSupervisor(port)
    def health():
        with urllib.request.urlopen(service.base + '/health', timeout=1) as response:
            data = json.load(response)
            if data.get('service') != 'agent-supervisor':
                raise ValueError('Port Veilleur occupe par un autre service')
            return data
    try:
        info = health()
        if info.get('update_available') is True:
            if port != 8082 or state_path is not None or info.get('default_storage') is not True:
                service.notice = 'Mise a jour disponible ; recharger le service configure apres sauvegarde de son etat.'
            else:
                # The helper snapshots sessions and chat, and refuses a busy analysis.
                helper = ROOT / 'TOOLS/AGENT_SUPERVISOR/scripts/upgrade_legacy.py'
                try:
                    print('Mise a jour du Veilleur : sauvegarde et reprise des sessions en cours...', flush=True)
                    upgrade = subprocess.run([sys.executable, str(helper)], stderr=subprocess.PIPE, text=True,
                                             encoding='utf8', errors='replace',
                                             creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                    if upgrade.returncode:
                        service.notice = 'Veilleur conserve en fonctionnement ; mise a jour non appliquee : ' + (upgrade.stderr.strip() or 'etat actif')
                    else:
                        updated = health()
                        service.notice = ('Veilleur mis a jour avec sauvegarde de son etat.' if updated.get('update_available') is False
                                          else 'Mise a jour du Veilleur non confirmee ; verifier son etat.')
                except OSError as exc:
                    service.notice = 'Mise a jour du Veilleur non confirmee : ' + type(exc).__name__
        return service
    except urllib.error.HTTPError as exc:
        raise ValueError('Port Veilleur occupe par un autre service') from exc
    except (urllib.error.URLError, ConnectionError, TimeoutError):
        script = ROOT / 'TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py'
        args = [sys.executable, str(script), '--port', str(port)]
        if state_path is not None:
            args.extend(['--state', str(state_path)])
        process = subprocess.Popen(args,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                health()
                service.started_here = True
                return service
            except urllib.error.HTTPError as exc:
                raise ValueError('Port Veilleur occupe par un autre service') from exc
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                if process.poll() is not None:
                    raise OSError('Le service Veilleur ne peut pas demarrer')
                time.sleep(.1)
        raise TimeoutError('Demarrage du service Veilleur non confirme')


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


@contextmanager
def mutex():
    """Verrou threads + processus Windows, pour eviter les read-modify-write perdus."""
    import msvcrt
    with LOCAL_MUTEX, open(MUTEX_PATH, "a+b") as handle:
        handle.seek(0)
        if not handle.read(1):
            handle.seek(0); handle.write(b"0"); handle.flush()
        for _ in range(100):
            try:
                handle.seek(0); msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1); break
            except OSError:
                time.sleep(0.05)
        else:
            raise TimeoutError("Catalogue occupe par une autre instance")
        try:
            yield
        finally:
            handle.seek(0); msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)


def atomic_write(path: Path, text: str) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def describe_yaml_error(exc: yaml.YAMLError, path: Path) -> str:
    """Erreur YAML en une ligne : probleme + position + ligne fautive + tache concernee."""
    problem = str(exc).splitlines()[0] if str(exc) else type(exc).__name__
    mark = getattr(exc, "problem_mark", None) or getattr(exc, "context_mark", None)
    if mark is None:
        return f"syntaxe YAML invalide — {problem}"
    lines = path.read_text(encoding="utf-8").splitlines()
    culprit = lines[mark.line].strip()[:100] if mark.line < len(lines) else "?"
    # Remonter au bloc de la tache fautive pour designer l'ID, pas seulement la ligne
    import re
    for previous in range(mark.line, -1, -1):
        match = re.match(r"^-\s+id:\s*(\S+)", lines[previous])
        if match:
            return (f"syntaxe YAML invalide ligne {mark.line + 1} (tache {match.group(1)}) "
                    f"— {problem} — ligne fautive : « {culprit} »")
    return f"syntaxe YAML invalide ligne {mark.line + 1} — {problem} — ligne fautive : « {culprit} »"


def tasks() -> list[dict]:
    try:
        data = yaml.safe_load(TASKS_PATH.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        raise ValueError(f"TASKS.yaml : {describe_yaml_error(exc, TASKS_PATH)}") from exc
    result = data.get("tasks")
    if not isinstance(result, list):
        raise ValueError("TASKS.yaml invalide : cle tasks absente")
    ids = [str(t.get("id", "")) for t in result if isinstance(t, dict)]
    if len(ids) != len(result) or not all(ids) or len(ids) != len(set(ids)):
        raise ValueError("TASKS.yaml invalide : IDs absents ou dupliques")
    return result


def save_tasks(value: list[dict]) -> None:
    atomic_write(TASKS_PATH, yaml.safe_dump({"tasks": value}, allow_unicode=True, sort_keys=False, width=120))


def normalize_agent(raw: str) -> str:
    v = (raw or "").strip()
    if not v or v in ("—", "-", "None", "null"):
        return "—"
    upper = v.upper()
    if upper == "HUM":
        return "HUM"
    alias_map = {
        "CLAUDE": "CC01", "CC": "CC01", "CC-01": "CC01", "CC-SUB": "CC02",
        "ANTIGRAVITY": "AGY01", "AGY": "AGY01", "AGY-01": "AGY01", "AGY-02": "AGY02",
        "CODEX": "CDX01", "CDX": "CDX01",
        "DSH": "DSH01", "DSH-01": "DSH01", "DSH-02": "DSH02",
        "DSH (DEEPSEEK)": "DSH01", "DSH (ORCHESTRATEUR)": "DSH01",
        "OPENCODE": "OPC01", "OPC": "OPC01",
    }
    if upper in alias_map:
        return alias_map[upper]
    import re
    clean = re.sub(r"[^A-Z0-9]", "", upper)
    if re.match(r"^(CC|AGY|CDX|DSH|OPC)\d{2}$", clean):
        return clean
    return v[:10]


def locks() -> dict[str, dict[str, dict]]:
    if not LOCKS_PATH.exists():
        return {"work_locks": {}, "edit_flags": {}}
    try:
        data = json.loads(LOCKS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"TASK_LOCKS.json : JSON invalide — {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("TASK_LOCKS.json invalide")
    # Migration automatique de l'ancien format : les anciens locks etaient des flags d'edition.
    state = {"work_locks": data.get("work_locks", {}), "edit_flags": data.get("edit_flags", data.get("locks", {}))}
    if not all(isinstance(value, dict) for value in state.values()): raise ValueError("TASK_LOCKS.json invalide")
    return state


def save_locks(value: dict[str, dict]) -> None:
    atomic_write(LOCKS_PATH, json.dumps({**value, "updated_at": now()}, ensure_ascii=False, indent=2) + "\n")


def rev(task: dict) -> str:
    raw = json.dumps(task, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode()).hexdigest()


def public(task: dict, all_locks: dict[str, dict]) -> dict:
    item = dict(task)
    item["revision"] = rev(task)
    item["work_lock"] = all_locks["work_locks"].get(str(task["id"]))
    item["edit_flag"] = all_locks["edit_flags"].get(str(task["id"]))
    return item


def actor(payload: dict) -> str:
    result = str(payload.get("actor", "")).strip()
    if not result or len(result) > 80:
        raise ValueError("actor obligatoire (1 a 80 caracteres)")
    return result


def owns(all_locks: dict[str, dict], task_id: str, who: str, token: str) -> bool:
    lock = all_locks.get(task_id)
    return bool(lock and lock.get("actor") == who and secrets.compare_digest(str(lock.get("token", "")), token))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WFLOW), **kwargs)

    def translate_path(self, path):
        """Viewers servis depuis UI ; TASKS.yaml, TASKS_ORCHESTRATOR.yaml, etc. depuis WFLOW."""
        name = urllib.parse.unquote(urllib.parse.urlparse(path).path).lstrip("/")
        if name in VIEWERS:
            return str(UI / name)
        return super().translate_path(path)

    def log_message(self, fmt, *args):
        if VERBOSE:
            print(f"[{self.log_date_time_string()}] {fmt % args}")
            return
        # Mode silencieux par defaut : masquer les requetes GET de routine (polling status/tasks, assets, etc.)
        if len(args) >= 2:
            req, code = str(args[0]), str(args[1])
            if req.startswith("GET ") and (code.startswith(("2", "3")) or code == "404"):
                return
        elif len(args) >= 1 and "404" in str(args[0]):
            return
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def log_error(self, fmt, *args):
        if not VERBOSE:
            if len(args) >= 1 and str(args[0]) in ("404", "File not found"):
                return
        super().log_error(fmt, *args)

    def reply(self, status: int, data: dict | list):
        try:
            raw = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers(); self.wfile.write(raw)
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError):
            pass

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= 1_000_000:
            raise ValueError("Corps JSON absent ou trop volumineux")
        result = json.loads(self.rfile.read(length).decode())
        if not isinstance(result, dict):
            raise ValueError("Corps JSON objet attendu")
        return result

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/supervision":
            return self.supervision_request()
        try:
            if path == "/AGENT_SUPERVISION.html":
                service = getattr(self.server, "supervision", None)
                if isinstance(service, RemoteSupervisor):
                    self.send_response(302); self.send_header("Location", service.base + "/"); self.end_headers(); return
            if path in ("/", "/index.html"):
                self.send_response(302); self.send_header("Location", "/TASK_VIEWER.html"); self.end_headers(); return
            if path == "/favicon.ico":
                self.send_response(204); self.end_headers(); return
            if path in ("/omnidiag", "/omnidiag.html"):
                omnidiag_html = ROOT / "TOOLS" / "OMNIDIAG" / "EXPORTS" / "omnidiag_viewer.html"
                if not omnidiag_html.exists():
                    import subprocess
                    subprocess.run([sys.executable, str(ROOT / "TOOLS" / "OMNIDIAG" / "build_omnidiag.py")])
                if omnidiag_html.exists():
                    raw = omnidiag_html.read_bytes()
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(raw)))
                    self.send_header("Cache-Control", "no-cache")
                    self.end_headers(); self.wfile.write(raw); return
                self.reply(404, {"error": "Fichier OMNIDIAG introuvable"}); return
            if path == "/api/status":
                self.reply(200, {"status": "ok", "host": HOST, "port": self.server.server_port, "tasks": len(tasks())}); return
            if path == "/api/tasks/json":
                state = locks(); self.reply(200, [public(t, state) for t in tasks()]); return
            if path == "/api/orchestrator/json":
                registry_path = WFLOW / "TASKS_ORCHESTRATOR.yaml"
                registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or []
                if not isinstance(registry, list) or any(not isinstance(item, dict) for item in registry):
                    raise ValueError("TASKS_ORCHESTRATOR.yaml invalide : liste d'entrees attendue")
                self.reply(200, {"success": True, "entries": registry}); return
            if path == "/api/omnidiag/data":
                omnidiag_dir = str(ROOT / "TOOLS" / "OMNIDIAG")
                if omnidiag_dir not in sys.path:
                    sys.path.insert(0, omnidiag_dir)
                import importlib
                import parser as omni_parser, enricher as omni_enricher, io_mapper as omni_io_mapper
                importlib.reload(omni_parser)
                importlib.reload(omni_enricher)
                importlib.reload(omni_io_mapper)
                items = omni_parser.run_full_extraction(ROOT)
                kb_file = ROOT / "TOOLS" / "OMNIDIAG" / "knowledge_base.json"
                enriched = omni_enricher.enrich_all(items, kb_file)
                rack_data = omni_io_mapper.parse_rack_io(ROOT)
                self.reply(200, {"success": True, "items": enriched, "rack_data": rack_data}); return
            super().do_GET()
        except ValueError as exc:  # Donnees invalides (TASKS.yaml / TASK_LOCKS.json casses)
            print(f"[ERREUR DONNEES] {exc}")
            self.reply(500, {"success": False, "error": str(exc), "kind": "data_error"})
        except Exception as exc:
            print(f"[ERREUR SERVEUR] {type(exc).__name__} : {exc}")
            self.reply(500, {"success": False, "error": f"{type(exc).__name__} : {exc}", "kind": "server_error"})

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path == "/api/supervision":
            return self.supervision_request(mutate=True)
        try:
            path, data = urllib.parse.urlparse(self.path).path, self.body()
            if path == "/api/omnidiag/rebuild":
                import subprocess
                proc = subprocess.run([sys.executable, str(ROOT / "TOOLS" / "OMNIDIAG" / "build_omnidiag.py")], cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace")
                self.reply(200, {"success": proc.returncode == 0, "output": proc.stdout or proc.stderr}); return
            if path == "/api/omnidiag/save-kb":
                item_id = str(data.get("id", "")).strip()
                if not item_id: return self.reply(400, {"success": False, "error": "ID requis"})
                kb_file = ROOT / "TOOLS" / "OMNIDIAG" / "knowledge_base.json"
                cur_kb = {}
                if kb_file.exists():
                    try: cur_kb = json.loads(kb_file.read_text(encoding="utf-8"))
                    except Exception: pass
                cur_kb[item_id] = {
                    "cause_racine": str(data.get("cause_racine", "")),
                    "action_conducteur": str(data.get("action_conducteur", "")),
                    "action_maintenance": str(data.get("action_maintenance", "")),
                    "points_test": str(data.get("points_test", ""))
                }
                kb_file.write_text(json.dumps(cur_kb, ensure_ascii=False, indent=2), encoding="utf-8")
                import subprocess
                subprocess.run([sys.executable, str(ROOT / "TOOLS" / "OMNIDIAG" / "build_omnidiag.py")], cwd=str(ROOT), capture_output=True, encoding="utf-8", errors="replace")
                self.reply(200, {"success": True, "saved_id": item_id}); return
            if path == "/api/task/edit-flag/acquire": return self.acquire(data)
            if path == "/api/task/edit-flag/release": return self.release(data)
            if path == "/api/task/work-lock/acquire": return self.acquire_work(data)
            if path == "/api/task/work-lock/release": return self.release_work(data)
            if path == "/api/tasks/unlock-all": return self.clear(data)
            if path == "/api/task/save": return self.save(data)
            if path == "/api/task/delete": return self.delete(data)
            self.reply(404, {"success": False, "error": "Endpoint inconnu"})
        except (ValueError, OSError, yaml.YAMLError, json.JSONDecodeError, TimeoutError) as exc:
            self.reply(400, {"success": False, "error": str(exc)})

    def supervision_request(self, mutate=False):
        """Local-only API: no wildcard CORS, mutation requires a per-server token."""
        def respond(status, data):
            raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(raw)
        port = self.server.server_port
        host = self.headers.get("Host", "")
        origin = self.headers.get("Origin")
        if (self.client_address[0] != "127.0.0.1"
                or host not in (f"127.0.0.1:{port}", f"localhost:{port}")
                or (origin is not None and origin != "http://" + host)):
            return respond(403, {"error": "Origine locale Task Viewer requise"})
        service = getattr(self.server, "supervision", None)
        if service is None:
            return respond(503, {"error": "Service de supervision non initialise"})
        token = self.server.supervision_token
        if mutate and not secrets.compare_digest(self.headers.get("X-Supervision-Token", ""), token):
            return respond(403, {"error": "Jeton de session requis ; recharger le panneau"})
        try:
            if mutate:
                service.command(self.body())
            result = service.snapshot()
            if not mutate and urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("summary") == ["1"]:
                summary = {"running": result["running"], "unread_count": sum(
                    1 for session in result.get("sessions", []) for alert in session.get("alerts", [])
                    if alert.get("disposition", "new") == "new")}
                if isinstance(service, RemoteSupervisor):
                    summary["port"] = urllib.parse.urlparse(service.base).port
                    summary["service_version"] = result.get("service_version")
                    summary["build_id"] = result.get("build_id")
                    summary["update_available"] = result.get("update_available")
                return respond(200, summary)
            result["token"] = token
            return respond(200, result)
        except (ValueError, OSError, KeyError, TypeError) as exc:
            return respond(400, {"error": str(exc)})

    def acquire(self, data):
        task_id, who = str(data.get("id", "")).strip(), actor(data)
        with mutex():
            all_tasks, state = tasks(), locks(); all_locks = state["edit_flags"]
            if task_id not in {str(t["id"]) for t in all_tasks}:
                return self.reply(404, {"success": False, "error": "Tache introuvable"})
            current = all_locks.get(task_id)
            if current and current.get("actor") != who:
                return self.reply(423, {"success": False, "error": "Tache en cours d'edition", "edit_flag": current})
            lock = current or {"actor": who, "token": secrets.token_urlsafe(24), "acquired_at": now()}
            all_locks[task_id] = lock; save_locks(state)
            self.reply(200, {"success": True, "task_id": task_id, "edit_flag": lock})

    def release(self, data):
        task_id, who, token = str(data.get("id", "")).strip(), actor(data), str(data.get("token", ""))
        with mutex():
            state = locks(); all_locks = state["edit_flags"]
            if not owns(all_locks, task_id, who, token):
                return self.reply(423, {"success": False, "error": "Seul le detenteur peut liberer"})
            del all_locks[task_id]; save_locks(state); self.reply(200, {"success": True, "task_id": task_id})

    def acquire_work(self, data):
        task_id, who = str(data.get("id", "")).strip(), actor(data)
        with mutex():
            state = locks(); work = state["work_locks"]
            if task_id not in {str(t["id"]) for t in tasks()}: return self.reply(404, {"success": False, "error": "Tache introuvable"})
            current = work.get(task_id)
            if current and current.get("actor") != who: return self.reply(423, {"success": False, "error": "Tache deja prise", "work_lock": current})
            lock = current or {"actor": who, "token": secrets.token_urlsafe(24), "acquired_at": now()}
            work[task_id] = lock; save_locks(state); self.reply(200, {"success": True, "work_lock": lock})

    def release_work(self, data):
        task_id, who, token = str(data.get("id", "")).strip(), actor(data), str(data.get("token", ""))
        with mutex():
            state = locks(); work = state["work_locks"]
            if not owns(work, task_id, who, token): return self.reply(423, {"success": False, "error": "Seul le detenteur peut liberer"})
            del work[task_id]; save_locks(state); self.reply(200, {"success": True, "task_id": task_id})

    def clear(self, data):
        who = actor(data)
        if data.get("confirm_all") is not True:
            return self.reply(400, {"success": False, "error": "confirm_all=true obligatoire"})
        with mutex():
            state = locks(); count = len(state["edit_flags"]); state["edit_flags"] = {}; save_locks(state)
            self.reply(200, {"success": True, "cleared": count, "performed_by": who, "at": now()})

    def save(self, data):
        task, who = data.get("task"), actor(data)
        if not isinstance(task, dict) or not str(task.get("id", "")).strip():
            raise ValueError("task.id obligatoire")
        task["agent"] = normalize_agent(str(task.get("agent", "")))
        task_id, expected, token = str(task["id"]), str(data.get("expected_revision", "")), str(data.get("token", ""))
        with mutex():
            all_tasks, state = tasks(), locks(); all_locks = state["edit_flags"]
            index = next((i for i, t in enumerate(all_tasks) if str(t["id"]) == task_id), None)
            if index is not None:
                if not owns(all_locks, task_id, who, token):
                    return self.reply(423, {"success": False, "error": "Verrou valide requis"})
                if expected != rev(all_tasks[index]):
                    return self.reply(409, {"success": False, "error": "Conflit de revision", "current": public(all_tasks[index], state)})
                all_tasks[index] = task
            else:
                if task_id in all_locks:
                    return self.reply(423, {"success": False, "error": "ID reserve"})
                all_tasks.insert(0, task)
            save_tasks(all_tasks); all_locks.pop(task_id, None); save_locks(state)
            self.reply(200, {"success": True, "task": public(task, state)})

    def delete(self, data):
        task_id, who, token = str(data.get("id", "")).strip(), actor(data), str(data.get("token", ""))
        with mutex():
            all_tasks, state = tasks(), locks(); all_locks = state["edit_flags"]
            index = next((i for i, t in enumerate(all_tasks) if str(t["id"]) == task_id), None)
            if index is None: return self.reply(404, {"success": False, "error": "Tache introuvable"})
            if not owns(all_locks, task_id, who, token):
                return self.reply(423, {"success": False, "error": "Verrou valide requis"})
            all_tasks.pop(index); all_locks.pop(task_id, None); save_tasks(all_tasks); save_locks(state)
            self.reply(200, {"success": True, "task_id": task_id})


def start(port: int = PORT, open_browser: bool = False, verbose: bool = False):
    global VERBOSE
    VERBOSE = verbose
    # Ce verrou reste pris pendant toute la vie du serveur : une seule instance locale.
    import msvcrt
    server_mutex_path = WFLOW / f".task_manager.server.{port}.lock"
    server_mutex_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock_handle = open(server_mutex_path, "a+b")
        lock_handle.seek(0)
        if not lock_handle.read(1): lock_handle.seek(0); lock_handle.write(b"0"); lock_handle.flush()
        lock_handle.seek(0); msvcrt.locking(lock_handle.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        if 'lock_handle' in locals(): lock_handle.close()
        print("Task Manager deja actif : aucun second serveur ne sera lance.")
        return
    try:
        server = http.server.ThreadingHTTPServer((HOST, port), Handler)
    except OSError as exc:
        msvcrt.locking(lock_handle.fileno(), msvcrt.LK_UNLCK, 1); lock_handle.close()
        print(f"Impossible de lancer Task Manager sur {HOST}:{port} : {exc}")
        return
    url = f"http://{HOST}:{port}/TASK_VIEWER.html"
    try:
        supervisor_port = int(os.environ.get('VEILLEUR_PORT', '8082'))
        if not 1 <= supervisor_port <= 65535:
            raise ValueError('VEILLEUR_PORT doit etre compris entre 1 et 65535')
        server.supervision = find_or_start_supervisor(supervisor_port)
        info = server.supervision.snapshot()
        version = info.get('service_version')
        state = 'actif' if info.get('running') else 'arrete'
        freshness = ('mise a jour : redemarrage necessaire' if info.get('update_available')
                     else 'a jour' if info.get('update_available') is False else 'version non verifiable')
        origin = 'demarre' if server.supervision.started_here else 'detecte'
        print(f"Veilleur {origin} : {server.supervision.base}/ — {state}")
        print(f"  -> Version : {version or 'historique'} · {info.get('build_id') or 'non identifiee'} · {freshness}")
        if server.supervision.notice:
            print(f"  -> {server.supervision.notice}")
    except (OSError, ValueError) as exc:
        server.supervision = None
        print(f"Veilleur indisponible : {exc}")
    server.supervision_token = secrets.token_urlsafe(32)
    print(f"Task Manager local : {url}")
    print("  -> Ctrl+Clic sur le lien pour ouvrir Task Viewer dans votre navigateur.")
    if open_browser:
        webbrowser.open(url)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally:
        server.server_close()
        lock_handle.seek(0); msvcrt.locking(lock_handle.fileno(), msvcrt.LK_UNLCK, 1); lock_handle.close()


def parse_cli_args(argv: list[str] | None = None) -> tuple[int, bool, bool]:
    import argparse
    parser = argparse.ArgumentParser(description="Serveur local Task Manager : taches YAML, verrous JSON separes.")
    parser.add_argument("port", nargs="?", type=int, default=PORT, help=f"Port d'ecoute HTTP (defaut: {PORT})")
    parser.add_argument("--port", dest="named_port", type=int, default=None, help="Port d'ecoute HTTP nomme")
    parser.add_argument("--open-browser", action="store_true", default=False, help="Ouvrir automatiquement Task Viewer dans le navigateur")
    parser.add_argument("--no-browser", action="store_false", dest="open_browser", help="Ne pas ouvrir automatiquement le navigateur (comportement par defaut)")
    parser.add_argument("--verbose", "-v", action="store_true", default=False, help="Afficher tous les acces HTTP GET de polling dans le terminal")
    args = parser.parse_args(argv)
    selected_port = args.named_port if args.named_port is not None else args.port
    return selected_port, args.open_browser, args.verbose


if __name__ == "__main__":
    selected_port, should_open_browser, is_verbose = parse_cli_args()
    start(selected_port, open_browser=should_open_browser, verbose=is_verbose)

