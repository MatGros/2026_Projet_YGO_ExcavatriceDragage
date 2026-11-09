"""Opt-in [REEL] continuity walk-through (T429 AC-F1.1 to AC-F1.4) on a NEW Claude test session.

Isolated: own server on a free port, own state file in the scratch directory, Claude run from
the scratch directory without tools. Never touches the user service (8082) nor any existing
conversation. Usage:
    py -3.13 TOOLS/AGENT_SUPERVISOR/tests/run_recovery_live.py <new_scratch_dir> [--model M --allow-cloud]
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server

MISSION = "Essai synthetique T429 : l'agent repond par des phrases courtes demandees ; aucune modification de fichier."


class Bench:
    def __init__(self, scratch, model, allow_cloud):
        self.scratch, self.model, self.allow_cloud = scratch, model, allow_cloud
        self.cli = shutil.which("claude")
        if not self.cli:
            raise RuntimeError("Claude Code introuvable")
        self.work = scratch / "cwd"; self.work.mkdir()
        self.state = scratch / "state.json"
        self.server = None
        self.steps = []

    # ── service ──
    def start_server(self):
        self.server = create_server(0, self.state)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"
        self.token = self.get()["token"]

    def stop_server(self):
        self.server.shutdown(); self.server.supervision.close(); self.server.server_close(); self.thread.join(timeout=5)

    def get(self):
        with urlopen(self.base + "/api/supervision", timeout=10) as r:
            return json.load(r)

    def cmd(self, payload):
        req = Request(self.base + "/api/supervision", data=json.dumps(payload).encode(),
                      headers={"Content-Type": "application/json", "X-Supervision-Token": self.token})
        try:
            with urlopen(req, timeout=15) as r:
                return json.load(r)
        except HTTPError as exc:
            return {"error": json.load(exc).get("error"), "status": exc.code}

    def session(self, sid):
        return next(s for s in self.get()["sessions"] if s["id"] == sid)

    def wait(self, sid, predicate, timeout=90):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            s = self.session(sid)
            if predicate(s):
                return s
            time.sleep(0.5)
        return self.session(sid)

    # ── Claude ──
    def claude(self, prompt, resume=None):
        args = [self.cli, "-p", prompt, "--tools", "", "--output-format", "json"]
        if resume:
            args += ["--resume", resume]
        p = subprocess.run(args, cwd=self.work, capture_output=True, text=True, encoding="utf8", errors="replace",
                           timeout=120, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if p.returncode:
            raise RuntimeError("Claude en echec : " + p.stderr[-400:])
        data = json.loads(p.stdout)
        return data["session_id"], data.get("result", "")

    def record(self, ac, name, ok, **details):
        self.steps.append(dict(ac=ac, step=name, result="PASS" if ok else "FAIL", **details))
        print(("PASS " if ok else "FAIL ") + ac + " " + name + " " + json.dumps(details, ensure_ascii=False)[:400], flush=True)


def source_events(s):
    return [e for e in s.get("events", []) if str(e.get("kind", "")).startswith("source_")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scratch")
    ap.add_argument("--model", default="deepseek-v4.1-flash:cloud")
    ap.add_argument("--allow-cloud", action="store_true")
    a = ap.parse_args()
    scratch = Path(a.scratch); scratch.mkdir(parents=True, exist_ok=False)
    b = Bench(scratch, a.model, a.allow_cloud)
    started = time.monotonic()
    native, _ = b.claude("Essai T429. Reponds uniquement : Pret.")
    b.start_server()
    try:
        r = b.cmd({"action": "configure", "model": a.model, "allow_cloud": a.allow_cloud})
        if r.get("error"):
            raise RuntimeError("configure: " + r["error"])
        r = b.cmd({"action": "add", "platform": "claude", "native_id": native, "alias": "T429 recette F1", "mission": MISSION})
        if r.get("error"):
            raise RuntimeError("add: " + r["error"])
        sid = next(s["id"] for s in r["sessions"] if s["native_id"] == native)
        b.cmd({"action": "start"})
        b.wait(sid, lambda s: s["state"] == "active", 30)
        b.claude("Reponds uniquement : Etape un.", native)
        s = b.wait(sid, lambda s: s.get("messages_observed", 0) >= 2 and s["analysis_state"] not in ("queued", "analyzing", "waiting"))
        b.record("AC-F1.0", "collecte directe", s.get("messages_observed", 0) >= 2,
                 messages_observed=s.get("messages_observed"), analysis_state=s["analysis_state"], analysis_error=s.get("analysis_error"))

        # AC-F1.1 : pause → 3 echanges → reprise annonce exactement 6 messages
        b.cmd({"action": "pause", "id": sid})
        for i in ("deux", "trois", "quatre"):
            b.claude(f"Reponds uniquement : Etape {i}.", native)
        before_index = b.session(sid)["recovery"]
        r = b.cmd({"action": "resume", "id": sid})
        s = b.session(sid)
        rec = s["recovery"]
        b.record("AC-F1.1", "intervalle annonce", rec.get("status") == "gap_available" and rec.get("message_count") == 6,
                 recovery={k: rec.get(k) for k in ("status", "message_count", "event_range", "characters", "batch_count")}, error=r.get("error"))

        # AC-F1.3 : redemarrage avec delta en attente
        keep = {k: s.get(k) for k in ("id", "native_id", "alias", "mission", "alerts")}
        keep_rec = {k: rec.get(k) for k in ("status", "message_count", "event_range")}
        b.stop_server(); b.start_server()
        s2 = b.session(sid)
        same = all(s2.get(k) == v for k, v in keep.items())
        rec2 = {k: s2["recovery"].get(k) for k in ("status", "message_count", "event_range")}
        b.record("AC-F1.3", "redemarrage avec delta en attente", same and rec2 == keep_rec and not s2["enabled"],
                 recovery_after=rec2, recovery_before=keep_rec, identity_preserved=same, enabled=s2["enabled"])
        b.cmd({"action": "start"})

        # AC-F1.2a : reprise avec historique → 6 evenements source uniques, analyse complete
        before_src = len(source_events(s2))
        r = b.cmd({"action": "resume", "id": sid, "mode": "history"})
        s = b.wait(sid, lambda s: s["recovery"].get("status") in ("complete", "error"), 180)
        src = source_events(s)
        ids = [e.get("source_id") for e in src]
        b.record("AC-F1.2", "reprise avec historique", s["recovery"].get("status") == "complete" and len(src) - before_src == 6 and len(ids) == len(set(ids)),
                 recovery=s["recovery"].get("status"), last_error=s["recovery"].get("last_error"), new_source_events=len(src) - before_src,
                 duplicates=len(ids) - len(set(ids)), analysis_state=s["analysis_state"], error=r.get("error"))

        # AC-F1.2b : reprise normale → delta ignore explicitement, aucun evenement source ajoute
        b.cmd({"action": "pause", "id": sid})
        b.claude("Reponds uniquement : Etape cinq.", native)
        n_before = len(source_events(b.session(sid)))
        b.cmd({"action": "resume", "id": sid})
        r = b.cmd({"action": "resume", "id": sid, "mode": "normal"})
        s = b.session(sid)
        time.sleep(2)
        s = b.session(sid)
        b.record("AC-F1.2", "reprise normale", s["recovery"].get("status") == "skipped" and s["recovery"].get("message_count") == 2 and len(source_events(s)) == n_before,
                 recovery={k: s["recovery"].get(k) for k in ("status", "message_count", "reason")}, source_events_added=len(source_events(s)) - n_before, error=r.get("error"))

        # AC-F1.4 [REEL] : source deplacee pendant la pause → rupture visible, pas de substitution
        b.cmd({"action": "pause", "id": sid})
        src_path = Path(b.session(sid)["source"])
        moved = src_path.with_suffix(".jsonl.t429moved")
        src_path.rename(moved)
        try:
            r = b.cmd({"action": "resume", "id": sid})
            s = b.session(sid)
            ok = s["recovery"].get("status") == "unverified" and not s["enabled"] and s.get("error") == "continuity_unverified"
            b.record("AC-F1.4", "source deplacee", ok, recovery={k: s["recovery"].get(k) for k in ("status", "reason")},
                     state=s["state"], error_field=s.get("error"), enabled=s["enabled"], cmd_error=r.get("error"))
        finally:
            moved.rename(src_path)
    finally:
        try:
            b.stop_server()
        except Exception:
            pass
    out = dict(contract="T429", kind="REEL claude -p session d'essai", native_id=native, model=a.model,
               seconds=round(time.monotonic() - started, 1), steps=b.steps,
               passed=sum(x["result"] == "PASS" for x in b.steps), total=len(b.steps))
    (scratch / "evidence.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps({k: out[k] for k in ("passed", "total", "seconds")}), flush=True)
    return 0 if out["passed"] == out["total"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
