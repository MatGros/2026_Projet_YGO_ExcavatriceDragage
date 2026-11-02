#!/usr/bin/env python3
"""Read-only inventory of local AI-agent conversation sources.

This POC reports paths and file metadata only. It never opens transcript bodies,
starts an agent, edits a database, or changes hooks/configuration.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Callable


def _env_path(env: dict[str, str], key: str, fallback: Path) -> Path:
    value = env.get(key)
    return Path(value).expanduser() if value else fallback


def _walk_count(root: Path, filename: str | None = None, suffix: str | None = None) -> tuple[int, int | None]:
    """Count matching file metadata without reading any file content."""
    count = 0
    newest_ns: int | None = None
    if not root.exists():
        return count, newest_ns
    for parent, _, names in os.walk(root):
        for name in names:
            if filename is not None and name != filename:
                continue
            if suffix is not None and not name.endswith(suffix):
                continue
            path = Path(parent) / name
            try:
                stat = path.stat()
            except OSError:
                continue
            count += 1
            newest_ns = max(newest_ns or 0, stat.st_mtime_ns)
    return count, newest_ns


def _opencode_db_path(home: Path, env: dict[str, str], which: Callable[[str], str | None]) -> tuple[Path, str]:
    override = env.get("OPENCODE_DB")
    if override:
        candidate = Path(override).expanduser()
        if not candidate.is_absolute():
            data_home = Path(env.get("XDG_DATA_HOME", home / ".local" / "share")).expanduser()
            candidate = data_home / "opencode" / candidate
        return candidate, "OPENCODE_DB override"
    executable = which("opencode")
    if executable:
        try:
            result = subprocess.run(
                [executable, "db", "path"], capture_output=True, text=True, timeout=5, check=False
            )
            candidate = result.stdout.strip()
            if result.returncode == 0 and candidate:
                return Path(candidate), "opencode db path"
        except (OSError, subprocess.SubprocessError):
            pass
    data_home = Path(env.get("XDG_DATA_HOME", home / ".local" / "share")).expanduser()
    return data_home / "opencode" / "opencode.db", "default path fallback"


def build_inventory(
    home: Path | None = None,
    env: dict[str, str] | None = None,
    which: Callable[[str], str | None] = shutil.which,
    scan: bool = False,
) -> list[dict[str, object]]:
    home = home or Path.home()
    env = os.environ if env is None else env

    claude_home = _env_path(env, "CLAUDE_CONFIG_DIR", home / ".claude")
    codex_home = _env_path(env, "CODEX_HOME", home / ".codex")
    gemini_home = home / ".gemini"
    dsh_home = _env_path(env, "DSH_HOME", home / ".dsh")
    opencode_db, opencode_resolution = _opencode_db_path(home, env, which)
    cli_paths = {name: which(name) for name in ("claude", "codex", "agy", "dsh", "opencode")}

    claude_root = claude_home / "projects"
    codex_root = codex_home / "sessions"
    agy_roots = [
        gemini_home / "antigravity" / "brain",
        gemini_home / "antigravity-ide" / "brain",
        gemini_home / "antigravity-cli" / "brain",
    ]
    dsh_root = dsh_home / "sessions"

    if scan:
        claude_count, claude_mtime = _walk_count(claude_root, suffix=".jsonl")
        codex_count, codex_mtime = _walk_count(codex_root, suffix=".jsonl")
        agy_results = [(_walk_count(root, filename="transcript.jsonl"), root) for root in agy_roots]
        agy_count = sum(count for (count, _), _root in agy_results)
        agy_mtimes = [mtime for (count, mtime), _root in agy_results if count and mtime]
        dsh_count, dsh_mtime = _walk_count(dsh_root, filename="session.jsonl.zstd")
    else:
        claude_count = codex_count = agy_count = dsh_count = None
        claude_mtime = codex_mtime = dsh_mtime = None
        agy_mtimes = []

    opencode_count = 1 if opencode_db.is_file() else 0
    opencode_mtime = opencode_db.stat().st_mtime_ns if opencode_count else None
    opencode_bytes = opencode_db.stat().st_size if opencode_count else None

    return [
        {
            "platform": "Claude Code",
            "cli": "claude",
            "cli_path": cli_paths["claude"],
            "source_kind": "JSONL transcript files",
            "paths": [str(claude_root)],
            "exists": claude_root.is_dir(),
            "pattern": "**/*.jsonl (subagent transcripts may be nested)",
            "files_found": claude_count,
            "new_session_capture": "claude -p --output-format stream-json --include-partial-messages --verbose",
            "existing_session_capture": "tail the session JSONL; parse records, do not scrape terminal text",
            "newest_mtime_ns": claude_mtime,
        },
        {
            "platform": "Codex CLI",
            "cli": "codex",
            "cli_path": cli_paths["codex"],
            "source_kind": "JSONL session rollouts",
            "paths": [str(codex_root)],
            "exists": codex_root.is_dir(),
            "pattern": "**/*.jsonl",
            "files_found": codex_count,
            "new_session_capture": "codex exec --json --sandbox read-only",
            "existing_session_capture": "tail the session JSONL; --json applies to a newly run exec, not an already-running TUI",
            "newest_mtime_ns": codex_mtime,
        },
        {
            "platform": "Antigravity (AGY)",
            "cli": "agy",
            "cli_path": cli_paths["agy"],
            "source_kind": "per-conversation transcript files",
            "paths": [str(root) for root in agy_roots],
            "exists": [root.is_dir() for root in agy_roots],
            "pattern": "**/transcript.jsonl",
            "files_found": agy_count,
            "new_session_capture": "agy --output-format stream-json --mode plan --sandbox -p=\"<prompt>\"",
            "existing_session_capture": "tail the conversation transcript; the CLI stream flags only control a launched print-mode session",
            "newest_mtime_ns": max(agy_mtimes) if agy_mtimes else None,
        },
        {
            "platform": "DSH",
            "cli": "dsh",
            "cli_path": cli_paths["dsh"],
            "source_kind": "workspace-scoped, compressed JSONL session files",
            "paths": [str(dsh_root)],
            "exists": dsh_root.is_dir(),
            "pattern": "**/session.jsonl.zstd",
            "files_found": dsh_count,
            "new_session_capture": "dsh --profile headless <prompt> (prints final answer; no stream/JSON flag documented by installed CLI)",
            "existing_session_capture": "watch file growth and decode appended Zstandard frames before parsing JSONL; plain tail is invalid",
            "newest_mtime_ns": dsh_mtime,
        },
        {
            "platform": "OpenCode",
            "cli": "opencode",
            "cli_path": cli_paths["opencode"],
            "source_kind": "SQLite session database",
            "paths": [str(opencode_db)],
            "exists": bool(opencode_count),
            "path_resolution": opencode_resolution,
            "pattern": "opencode.db (messages and sessions are stored in SQLite)",
            "files_found": opencode_count,
            "bytes": opencode_bytes,
            "new_session_capture": "opencode run --format json --agent plan",
            "existing_session_capture": "opencode serve event stream or export by session; the event stream is live-only and has no replay",
            "newest_mtime_ns": opencode_mtime,
        },
    ]


def render_text(inventory: list[dict[str, object]]) -> str:
    lines = ["AI agent data source POC (metadata only)", "=" * 40]
    for item in inventory:
        lines.append(f"\n{item['platform']} | {item['source_kind']}")
        if item["cli_path"]:
            lines.append(f"  CLI: {item['cli']} ({item['cli_path']})")
        else:
            lines.append(f"  CLI: {item['cli']} (not found on PATH)")
        exists = item["exists"]
        for index, path in enumerate(item["paths"]):
            path_exists = exists[index] if isinstance(exists, list) else exists
            lines.append(f"  Data: {path} [exists={path_exists}]")
        if isinstance(item["files_found"], int):
            count_text = f"{item['files_found']} item(s)"
        else:
            count_text = "use --scan for file counts"
        lines.append(f"  Format/count: {item['pattern']} | {count_text}")
        if "bytes" in item:
            lines.append(f"  Database bytes: {item['bytes']} (path via {item['path_resolution']})")
        lines.append(f"  New CLI run: {item['new_session_capture']}")
        lines.append(f"  Existing run: {item['existing_session_capture']}")
    lines.append("\nNo transcript body or database row was read.")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--scan", action="store_true", help="recursively count matching files (metadata only; may take longer)")
    args = parser.parse_args(argv)
    inventory = build_inventory(scan=args.scan)
    if args.json:
        print(json.dumps(inventory, ensure_ascii=False, indent=2))
    else:
        print(render_text(inventory))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
