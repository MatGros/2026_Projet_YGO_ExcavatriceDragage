"""Opt-in [REEL] collection walk-through per CLI (T429 AC-F4.3) on NEW test sessions only.

For each platform: create a fresh session from a scratch directory, attach it to an isolated Supervisor
(own state file, real read-only transcript roots), resume the same session once, then check on the
Supervisor side that >= 1 message is collected with the right platform and native id. No existing
conversation is targeted; no judge call is needed (model left unconfigured -> analysis may be unavailable).
Usage: py -3.13 TOOLS/AGENT_SUPERVISOR/tests/run_platforms_live.py <new_scratch_dir> [--only codex,agy,dsh,claude]
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor

NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def run(args, cwd, timeout=180):
    p = subprocess.run(args, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=timeout, creationflags=NO_WINDOW)
    return p.returncode, p.stdout, p.stderr


def codex(cwd, prompt, resume=None):
    exe = shutil.which("codex") or "codex"
    args = [exe, "exec", "--skip-git-repo-check", "-s", "read-only", "--json"] + (["resume", resume] if resume else []) + [prompt]
    code, out, err = run(args, cwd)
    match = re.search(r'"type"\s*:\s*"thread.started"\s*,\s*"thread_id"\s*:\s*"([0-9a-f-]+)"', out)
    return code, (match.group(1) if match else resume), err[-300:]


def agy(cwd, prompt, resume=None):
    exe = shutil.which("agy") or "agy"
    args = [exe, "--mode", "plan", "--sandbox", "--print-timeout", "90s", "--output-format", "json"] + (["--conversation", resume] if resume else []) + ["--print", prompt]
    code, out, err = run(args, cwd, 150)
    try:
        native = json.loads(out).get("conversation_id")
    except (json.JSONDecodeError, AttributeError):
        native = None
    return code, native or resume, err[-300:]


def claude(cwd, prompt, resume=None):
    exe = shutil.which("claude") or "claude"
    args = [exe, "-p", prompt, "--tools", "", "--output-format", "json"] + (["--resume", resume] if resume else [])
    code, out, err = run(args, cwd)
    try:
        native = json.loads(out).get("session_id")
    except json.JSONDecodeError:
        native = None
    return code, native or resume, err[-300:]


def dsh(cwd, prompt, resume=None):
    exe = shutil.which("dsh.cmd") or shutil.which("dsh") or "dsh"
    before = {p: p.stat().st_mtime for p in (Path.home() / ".dsh/sessions").rglob("*.zstd")}
    args = [exe, "--profile", "headless"] + (["--resume", resume] if resume else []) + [prompt]
    code, out, err = run(["powershell", "-NoProfile", "-Command", "& '" + exe + "' " + " ".join("'" + a.replace("'", "''") + "'" for a in args[1:])], cwd, 240)
    native = resume
    if not resume:
        changed = [p for p in (Path.home() / ".dsh/sessions").rglob("*.zstd") if before.get(p) != p.stat().st_mtime]
        names = [re.search(r"(session-[0-9a-f-]{36})", str(p)) for p in changed]
        ids = sorted({m.group(1) for m in names if m})
        native = ids[0] if len(ids) == 1 else None
    return code, native, (err or out)[-300:]


CLIS = {"codex": codex, "agy": agy, "dsh": dsh, "claude": claude}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scratch")
    ap.add_argument("--only", default="codex,agy,dsh,claude")
    a = ap.parse_args()
    scratch = Path(a.scratch); scratch.mkdir(parents=True, exist_ok=False)
    svc = Supervisor(scratch / "state.json", poll_interval=1.0, strict_assignments=True)
    results = []
    try:
        svc.command({"action": "start"})
        for platform in a.only.split(","):
            cwd = scratch / platform; cwd.mkdir()
            row = dict(platform=platform)
            started = time.monotonic()
            try:
                code, native, err = CLIS[platform](cwd, "Essai T429 Supervisor. Réponds uniquement : PRET. N'utilise aucun outil.")
                row.update(create_code=code, native_id=native, create_err=err if code else "")
                if code or not native:
                    raise RuntimeError("création de session non confirmée")
                snap = svc.command({"action": "add", "platform": platform, "native_id": native, "alias": "T429 " + platform,
                                    "mission": "Essai T429 de collecte ; aucune modification."})
                sid = next(s["id"] for s in snap["sessions"] if s["native_id"] == native)
                time.sleep(3)
                code2, _n, err2 = CLIS[platform](cwd, "Second message T429 : réponds uniquement : RECU.", resume=native)
                row.update(resume_code=code2, resume_err=err2 if code2 else "")
                end = time.monotonic() + 60
                s = None
                while time.monotonic() < end:
                    s = next(x for x in svc.snapshot()["sessions"] if x["id"] == sid)
                    if s.get("messages_observed", 0) >= 1:
                        break
                    time.sleep(1)
                ok = bool(s) and s.get("messages_observed", 0) >= 1 and s["platform"] == platform and s["native_id"] == native
                row.update(result="PASS" if ok else "FAIL", messages_observed=s.get("messages_observed") if s else None,
                           state=s.get("state") if s else None, error=s.get("error") if s else None, source=s.get("source") if s else None)
            except Exception as exc:  # documented limit, never a silent pass
                row.update(result="LIMIT", reason=f"{type(exc).__name__}: {str(exc)[:200]}")
            row["seconds"] = round(time.monotonic() - started, 1)
            results.append(row)
            print(json.dumps(row, ensure_ascii=False)[:700], flush=True)
    finally:
        svc.close()
    (scratch / "evidence.json").write_text(json.dumps(dict(contract="T429", ac="AC-F4.3", results=results), ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if all(r["result"] == "PASS" for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
