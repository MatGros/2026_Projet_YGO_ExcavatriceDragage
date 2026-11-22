"""Veille explicite par session : changements de fichiers, échéances et boîte durable.

Les événements informent le coordinateur, sans lancer de commande ni attribuer de tâche.
La base est hors dépôt ; les événements restent disponibles jusqu'à acquittement.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import time


def database():
    root = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / ".local/share")))
    path = root / "ExcavatriceDragage" / "coordinator_events.sqlite3"
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def connect(path):
    db = sqlite3.connect(path, timeout=5)
    db.execute("CREATE TABLE IF NOT EXISTS watches (session TEXT, path TEXT, digest TEXT, deadline REAL, expired INTEGER DEFAULT 0, PRIMARY KEY(session,path))")
    db.execute("CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, session TEXT, path TEXT, kind TEXT, observed REAL, acknowledged INTEGER DEFAULT 0)")
    return db


def digest(path):
    try:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    except FileNotFoundError:
        return "missing"
    except OSError as exc:
        return "error:" + type(exc).__name__


def add_watch(db, session, path, deadline=None):
    path = str(Path(path).resolve())
    with db:
        db.execute("INSERT INTO watches(session,path,digest,deadline) VALUES(?,?,?,?) ON CONFLICT(session,path) DO UPDATE SET deadline=excluded.deadline,expired=0",
                   (session, path, digest(path), deadline))
    return path


def poll(db, session, now=None):
    now = time.time() if now is None else now
    # Transaction de réservation : deux processus ne produisent pas le même événement.
    db.execute("BEGIN IMMEDIATE")
    try:
        for path, previous, deadline, expired in db.execute(
                "SELECT path,digest,deadline,expired FROM watches WHERE session=?", (session,)).fetchall():
            current = digest(path)
            if current != previous:
                kind = "source_error" if current.startswith("error:") else "source_missing" if current == "missing" else "file_changed"
                db.execute("INSERT INTO events(session,path,kind,observed) VALUES(?,?,?,?)", (session, path, kind, now))
                db.execute("UPDATE watches SET digest=? WHERE session=? AND path=?", (current, session, path))
            if deadline is not None and now >= deadline and not expired:
                db.execute("INSERT INTO events(session,path,kind,observed) VALUES(?,?,?,?)", (session, path, "deadline", now))
                db.execute("UPDATE watches SET expired=1 WHERE session=? AND path=?", (session, path))
        db.commit()
    except Exception:
        db.rollback()
        raise
    return pending(db, session)


def pending(db, session):
    return [dict(zip(("id", "path", "kind", "observed_at"), row)) for row in db.execute(
        "SELECT id,path,kind,observed FROM events WHERE session=? AND acknowledged=0 ORDER BY id", (session,))]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    add = sub.add_parser("add")
    add.add_argument("path")
    add.add_argument("--deadline-seconds", type=float)
    sub.add_parser("poll")
    ack = sub.add_parser("ack")
    ack.add_argument("id", type=int)
    wait = sub.add_parser("wait")
    wait.add_argument("--duration", type=float, default=30)
    wait.add_argument("--interval", type=float, default=5)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", args.session):
        parser.error("Identifiant natif exact requis")
    if args.command == "wait" and (args.duration < 0 or args.duration > 60 or args.interval <= 0):
        parser.error("Attente de 0 à 60 secondes, intervalle strictement positif")
    with connect(database()) as db:
        if args.command == "add":
            if args.deadline_seconds is not None and args.deadline_seconds < 0:
                parser.error("Échéance négative refusée")
            deadline = time.time() + args.deadline_seconds if args.deadline_seconds is not None else None
            result = {"watching": add_watch(db, args.session, args.path, deadline)}
        elif args.command == "ack":
            with db:
                cursor = db.execute("UPDATE events SET acknowledged=1 WHERE id=? AND session=? AND acknowledged=0", (args.id, args.session))
            result = {"acknowledged": cursor.rowcount == 1}
        else:
            end = time.monotonic() + (args.duration if args.command == "wait" else 0)
            while True:
                result = poll(db, args.session)
                if result or time.monotonic() >= end:
                    break
                time.sleep(min(args.interval, max(0, end - time.monotonic())))
        print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
