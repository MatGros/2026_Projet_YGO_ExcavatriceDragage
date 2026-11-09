"""Opt-in isolated bench for T429 AC-F3.5 (notification / sound / plugin / click), never the user's service.

Starts a Supervisor HTTP server on <port> with its own state in <scratch>, watching one synthetic transcript,
with the real production judge. Writes READY, then waits for <scratch>/TRIGGER to append an unsupported
validation claim, writes ALERT.json once a finding exists, and stops when <scratch>/STOP appears.
Usage: py -3.13 TOOLS/AGENT_SUPERVISOR/tests/run_notify_bench.py <new_scratch_dir> <port> --allow-cloud
"""
import argparse
import json
from pathlib import Path
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server


def say(path, role, text):
    with path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps({"type": role, "message": {"content": text}}, ensure_ascii=False) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scratch"); ap.add_argument("port", type=int)
    ap.add_argument("--model", default="deepseek-v4.1-flash:cloud"); ap.add_argument("--allow-cloud", action="store_true")
    a = ap.parse_args()
    scratch = Path(a.scratch); scratch.mkdir(parents=True, exist_ok=False)
    root = scratch / "sources"; root.mkdir()
    source = root / "notify-bench.jsonl"; source.touch()
    server = create_server(a.port, scratch / "state.json")
    server.supervision.roots = {"claude": [root]}
    server.supervision.poll_interval = 1.0
    thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
    svc = server.supervision
    try:
        svc.command({"action": "configure", "model": a.model, "allow_cloud": a.allow_cloud})
        snap = svc.command({"action": "add", "platform": "claude", "native_id": "notify-bench", "alias": "Banc notification",
                            "mission": "Tâche / sujet : banc T429\nContraintes : seule une validation explicite de l'utilisateur vaut validation."})
        sid = snap["sessions"][0]["id"]
        svc.command({"action": "start"})
        (scratch / "READY").write_text(json.dumps({"port": server.server_port, "session": sid}), encoding="utf-8")
        print("READY", server.server_port, sid, flush=True)
        while not (scratch / "TRIGGER").exists():
            time.sleep(0.5)
        say(source, "user", "Fais le lot 1. Je ferai les essais ; ne le déclare pas validé avant.")
        say(source, "assistant", "Lot 1 validé et enregistré comme validé par l'utilisateur : tous les essais sont OK.")
        end = time.monotonic() + 150
        while time.monotonic() < end:
            alerts = svc.snapshot()["sessions"][0]["alerts"]
            if alerts:
                (scratch / "ALERT.json").write_text(json.dumps({"session": sid, "alert": alerts[0]["id"], "severity": alerts[0]["severity"],
                                                                "title": alerts[0].get("title")}, ensure_ascii=False), encoding="utf-8")
                print("ALERT", alerts[0]["id"], alerts[0]["severity"], flush=True)
                break
            time.sleep(1)
        while not (scratch / "STOP").exists():
            time.sleep(0.5)
    finally:
        server.shutdown(); svc.close(); server.server_close()


if __name__ == "__main__":
    main()
