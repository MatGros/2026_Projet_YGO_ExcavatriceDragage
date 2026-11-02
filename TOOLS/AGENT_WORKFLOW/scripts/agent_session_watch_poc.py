#!/usr/bin/env python3
"""Read-only, explicitly attached JSONL session watcher POC.

This is a file adapter, not a background service. It never discovers or reads
conversation files until the caller supplies an exact native session ID/path.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
import hashlib
import os
import re
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class SourceResolution:
    state: str
    path: Path | None
    matches: int


def resolve_jsonl_source(root: Path, session_id: str, *, platform: str = "claude") -> SourceResolution:
    """Resolve a complete native ID using literal platform layouts; never guess by recency."""
    if platform not in ("claude", "codex", "agy"):
        return SourceResolution("invalid_platform", None, 0)
    if not re.fullmatch(r"[A-Za-z0-9_-]+", session_id):
        return SourceResolution("invalid_id", None, 0)
    if platform == "codex" and not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", session_id):
        return SourceResolution("invalid_id", None, 0)
    if not root.is_dir():
        return SourceResolution("root_missing", None, 0)
    try:
        def matches_id(path):
            if platform == "codex":
                return path.name.endswith("-" + session_id + ".jsonl")
            if platform == "agy":
                return path.name == "transcript.jsonl" and path.parent.name == session_id
            return path.name == session_id + ".jsonl"
        if platform == "agy":
            candidates = (root / session_id / "transcript.jsonl",
                          root / session_id / ".system_generated" / "logs" / "transcript.jsonl")
            matches = [p for p in candidates if p.is_file()]
        else:
            matches = [p for p in root.rglob("*.jsonl") if matches_id(p)]
    except OSError:
        return SourceResolution("source_error", None, 0)
    if not matches:
        return SourceResolution("source_missing", None, 0)
    if len(matches) != 1:
        return SourceResolution("ambiguous", None, len(matches))
    if not matches[0].is_file():
        return SourceResolution("source_missing", None, 0)
    return SourceResolution("ready", matches[0], 1)


@dataclass
class PollResult:
    state: str
    events: list[dict[str, Any]]
    error: str | None = None


class JsonlAppendWatcher:
    """Read complete JSONL records appended after explicit attachment."""

    def __init__(self, path: Path, *, start_at_end: bool = True) -> None:
        self.path = path
        self._suspended = False
        self._start_at_end = start_at_end
        self.offset = 0
        self._identity = None
        self._pending = b""
        self._parse_error = None
        self._attach_error = None
        self._digest = hashlib.sha256().digest()
        try:
            with path.open("rb") as stream:
                before = os.fstat(stream.fileno())
                target = before.st_size if start_at_end else 0
                digest = hashlib.sha256()
                remaining = target
                while remaining:
                    chunk = stream.read(min(remaining, 65536))
                    if not chunk:
                        raise OSError("source changed during attachment")
                    digest.update(chunk)
                    remaining -= len(chunk)
                after = os.fstat(stream.fileno())
                if (before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                    raise OSError("source changed during attachment")
                self.offset = target
                self._digest = digest.digest()
                self._identity = (after.st_dev, after.st_ino)
        except FileNotFoundError:
            self.offset = 0
        except OSError as exc:
            self.offset = 0
            self._attach_error = type(exc).__name__

    def reattach(self, *, start_at_end=True):
        """Explicitly acknowledge a continuity break and choose replay policy."""
        self.__init__(self.path, start_at_end=start_at_end)

    def poll(self) -> PollResult:
        if self._parse_error:
            return PollResult("parse_error", [], self._parse_error)
        if self._suspended:
            return PollResult("source_reset", [])
        try:
            file_stat = self.path.stat()
        except FileNotFoundError:
            return PollResult("source_missing", [])
        except OSError as exc:
            return PollResult("source_error", [], type(exc).__name__)

        size = file_stat.st_size
        identity = (file_stat.st_dev, file_stat.st_ino)
        changed = self._identity is not None and (
            identity != self._identity or size < self.offset)
        if changed:
            self._suspended = True
            return PollResult("source_reset", [])
        if self._identity is None and self._start_at_end:
            # A missing source is not permission to replay an existing history.
            self.reattach(start_at_end=True)
            if self._attach_error:
                return PollResult("source_error", [], self._attach_error)
            if self._identity is None:
                return PollResult("source_missing", [])
            return PollResult("active", [])
        self._identity = identity

        try:
            with self.path.open("rb") as stream:
                before = os.fstat(stream.fileno())
                digest = hashlib.sha256()
                remaining = self.offset
                while remaining:
                    part = stream.read(min(remaining, 65536))
                    if not part:
                        break
                    digest.update(part)
                    remaining -= len(part)
                if remaining or digest.digest() != self._digest:
                    self._suspended = True
                    return PollResult("source_reset", [])
                chunk = stream.read()
                new_offset = stream.tell()
                digest.update(chunk)
                after = os.fstat(stream.fileno())
                if (before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                    return PollResult("source_error", [], "source_changed_during_read")
                if (after.st_dev, after.st_ino) != self._identity:
                    self._suspended = True
                    return PollResult("source_reset", [])
                self.offset = new_offset
                self._digest = digest.digest()
        except FileNotFoundError:
            return PollResult("source_missing", [])
        except OSError as exc:
            return PollResult("source_error", [], type(exc).__name__)

        buffer = self._pending + chunk
        rows = buffer.split(b"\n")
        self._pending = rows.pop()
        events: list[dict[str, Any]] = []
        for row in rows:
            if not row.strip():
                continue
            try:
                value = json.loads(row.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                self._parse_error = type(exc).__name__
                return PollResult("parse_error", events, self._parse_error)
            if not isinstance(value, dict):
                self._parse_error = "record_not_object"
                return PollResult("parse_error", events, self._parse_error)
            events.append(value)
        return PollResult("active", events)


def main():
    """Explicit, bounded read-only attachment. Content output requires opt-in."""
    import argparse
    import time
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--platform", choices=("claude", "codex", "agy"), required=True)
    parser.add_argument("--duration", type=float, default=60)
    parser.add_argument("--interval", type=float, default=.25)
    parser.add_argument("--from-beginning", action="store_true")
    parser.add_argument("--include-content", action="store_true")
    args = parser.parse_args()
    if args.duration <= 0 or args.interval <= 0:
        parser.error("duration and interval must be positive")
    resolution = resolve_jsonl_source(args.root, args.session_id, platform=args.platform)
    print(json.dumps({"session_id": args.session_id, "state": resolution.state,
                      "source": str(resolution.path) if resolution.path else None}), flush=True)
    if resolution.state != "ready":
        return 2
    watcher = JsonlAppendWatcher(resolution.path, start_at_end=not args.from_beginning)
    deadline = time.monotonic() + args.duration
    previous_state = None
    while time.monotonic() < deadline:
        result = watcher.poll()
        if result.state != previous_state or result.events:
            events = result.events if args.include_content else [
                {"type": e.get("type", e.get("event"))} for e in result.events]
            print(json.dumps({"session_id": args.session_id, "state": result.state,
                              "error": result.error, "events": events}), flush=True)
        previous_state = result.state
        if result.state in ("source_reset", "parse_error"):
            return 3
        time.sleep(min(args.interval, max(0, deadline-time.monotonic())))
    return 0 if previous_state == "active" else 2


if __name__ == "__main__":
    raise SystemExit(main())
