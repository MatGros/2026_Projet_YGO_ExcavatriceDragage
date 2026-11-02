"""Controlled new-session JSONL capture; never attaches to a user's session.

Runs a reply-only canned prompt in a fresh system-temp directory. Claude tools
are disabled; Codex/AGY use their sandbox/plan flags and a no-tools instruction.
User hooks/configuration can still run. Timeout cleanup covers the direct PID
only, not backend tasks or descendants. Raw stdout and
stderr remain there. The evidence file contains timing/schema/identity metadata.
This proves a print-mode capture path only, not an interactive TUI adapter.
"""
from __future__ import annotations

import argparse
import json
import queue
import shutil
import subprocess
import tempfile
import threading
import time
import uuid
from pathlib import Path

try:
    from .agent_session_watch_poc import JsonlAppendWatcher, resolve_jsonl_source
except ImportError:
    from agent_session_watch_poc import JsonlAppendWatcher, resolve_jsonl_source


def run(platform: str, timeout: float = 120) -> dict:
    executable = shutil.which(platform)
    if not executable:
        return {"platform": platform, "state": "cli_missing"}
    session = str(uuid.uuid4())
    marker = "OBSERVATION_PROBE_" + uuid.uuid4().hex
    prompt = f"Reply with exactly {marker}. Do not use tools, read files, run commands or delegate."
    args = {
        "claude": ["--tools", "", "--permission-mode", "plan", "--max-turns", "1", "--session-id", session, "--verbose", "--output-format", "stream-json", "-p", prompt],
        "codex": ["exec", "--skip-git-repo-check", "--json", "--sandbox", "read-only", prompt],
        "agy": ["--output-format", "stream-json", "--mode", "plan", "--sandbox", "--print-timeout", f"{int(timeout)}s", "-p=" + prompt],
    }[platform]
    directory = Path(tempfile.mkdtemp(prefix="agent_capture_"))
    events = []
    source_events = []
    source_states = []
    watcher = None
    native_id = session if platform == "claude" else None
    roots = {
        "claude": [Path.home() / ".claude" / "projects"],
        "codex": [Path.home() / ".codex" / "sessions"],
        "agy": [Path.home() / ".gemini" / name / "brain" for name in ("antigravity", "antigravity-cli", "antigravity-ide")],
    }[platform]
    received = queue.Queue()
    started = time.monotonic()
    with (directory / "stderr.log").open("wb") as stderr:
        process = subprocess.Popen([executable, *args], cwd=directory, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=stderr)
        def reader():
            for line in process.stdout:
                received.put((time.monotonic(), process.poll() is None, line))
            received.put(None)
        thread = threading.Thread(target=reader, daemon=True)
        thread.start()
        def poll_source():
            nonlocal watcher
            if native_id is None:
                return
            if watcher is None:
                matches = [resolve_jsonl_source(root, native_id, platform=platform) for root in roots]
                paths = [m.path for m in matches if m.state == "ready"]
                if len(paths) != 1 or any(m.state == "ambiguous" for m in matches):
                    return
                watcher = JsonlAppendWatcher(paths[0], start_at_end=False)
            result = watcher.poll()
            if not source_states or source_states[-1] != result.state:
                source_states.append(result.state)
            for value in result.events:
                source_events.append({"seconds": time.monotonic()-started, "alive": process.poll() is None, "type": value.get("type", value.get("event")), "contains_marker": marker in json.dumps(value)})
        timed_out = False
        with (directory / "stdout.jsonl").open("wb") as raw:
            while True:
                remaining = timeout - (time.monotonic() - started)
                if remaining <= 0:
                    timed_out = True
                    process.kill()
                    break
                try:
                    item = received.get(timeout=min(remaining, .25))
                except queue.Empty:
                    poll_source()
                    continue
                if item is None:
                    break
                observed, alive, line = item
                raw.write(line)
                try:
                    value = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    events.append({"seconds": observed-started, "alive": alive, "invalid_json": True})
                    continue
                ids = {}
                def collect(v):
                    if isinstance(v, dict):
                        for k, x in v.items():
                            if k in ("session_id", "sessionId", "conversation_id", "conversationId", "thread_id", "threadId") and isinstance(x, str):
                                ids[k] = x
                            collect(x)
                    elif isinstance(v, list):
                        for x in v:
                            collect(x)
                collect(value)
                if native_id is None and ids:
                    native_id = next(iter(ids.values()))
                events.append({"seconds": observed-started, "alive": alive, "keys": sorted(value) if isinstance(value, dict) else [], "type": value.get("type", value.get("event")) if isinstance(value, dict) else None, "ids": ids, "contains_marker": marker in line.decode("utf-8", errors="replace")})
                poll_source()
        process.wait(timeout=10)
        thread.join(timeout=5)
        poll_source()
    return {"platform": platform, "executable": executable, "cwd": str(directory), "pid": process.pid, "marker": marker, "expected_session_id": session if platform == "claude" else None, "native_id": native_id, "source_path": str(watcher.path) if watcher else None, "source_states": source_states, "source_events": source_events, "timeout_cleanup_scope": "direct_pid_only", "state": "timeout" if timed_out else "exited", "exit_code": process.returncode, "duration_seconds": time.monotonic()-started, "events": events, "raw_output": str(directory/"stdout.jsonl"), "stderr": str(directory/"stderr.log")}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("claude", "codex", "agy"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    if args.output.exists():
        parser.error("evidence output already exists; choose a new filename")
    result = run(args.platform, args.timeout)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k not in ("events", "source_events")}))
