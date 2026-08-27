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
LOCAL_MUTEX = threading.Lock()


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


def tasks() -> list[dict]:
    data = yaml.safe_load(TASKS_PATH.read_text(encoding="utf-8")) or {}
    result = data.get("tasks")
    if not isinstance(result, list):
        raise ValueError("TASKS.yaml invalide : cle tasks absente")
    ids = [str(t.get("id", "")) for t in result if isinstance(t, dict)]
    if len(ids) != len(result) or not all(ids) or len(ids) != len(set(ids)):
        raise ValueError("TASKS.yaml invalide : IDs absents ou dupliques")
    return result


def save_tasks(value: list[dict]) -> None:
    atomic_write(TASKS_PATH, yaml.safe_dump({"tasks": value}, allow_unicode=True, sort_keys=False, width=120))


def locks() -> dict[str, dict[str, dict]]:
    if not LOCKS_PATH.exists():
        return {"work_locks": {}, "edit_flags": {}}
    data = json.loads(LOCKS_PATH.read_text(encoding="utf-8"))
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

    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def reply(self, status: int, data: dict | list):
        raw = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers(); self.wfile.write(raw)

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
        try:
            if path in ("/", "/index.html"):
                self.send_response(302); self.send_header("Location", "/TASK_VIEWER.html"); self.end_headers(); return
            if path == "/api/status":
                self.reply(200, {"status": "ok", "host": HOST, "port": self.server.server_port, "tasks": len(tasks())}); return
            if path == "/api/tasks/json":
                state = locks(); self.reply(200, [public(t, state) for t in tasks()]); return
            super().do_GET()
        except Exception as exc:
            self.reply(500, {"success": False, "error": str(exc)})

    def do_POST(self):
        try:
            path, data = urllib.parse.urlparse(self.path).path, self.body()
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


def start(port: int = PORT):
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
    print(f"Task Manager local : {url}")
    webbrowser.open(url)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally:
        server.server_close()
        lock_handle.seek(0); msvcrt.locking(lock_handle.fileno(), msvcrt.LK_UNLCK, 1); lock_handle.close()


if __name__ == "__main__":
    start(int(sys.argv[1]) if len(sys.argv) > 1 else PORT)
