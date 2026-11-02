from __future__ import annotations

from pathlib import Path
import subprocess
from unittest.mock import patch

from TOOLS.AGENT_WORKFLOW.scripts import agent_data_source_poc
from TOOLS.AGENT_WORKFLOW.scripts.agent_data_source_poc import build_inventory, render_text


def _source(inventory, platform):
    return next(item for item in inventory if item["platform"] == platform)


def test_inventory_resolves_sessions_and_counts_metadata_only(tmp_path: Path) -> None:
    home = tmp_path / "user"
    files = {
        home / ".claude" / "projects" / "p" / "s.jsonl": "PRIVATE TRANSCRIPT BODY",
        home / ".codex" / "sessions" / "2026" / "s.jsonl": "PRIVATE CODEX BODY",
        home / ".gemini" / "antigravity" / "brain" / "id" / "transcript.jsonl": "PRIVATE AGY BODY",
        home / ".dsh" / "sessions" / "workspace" / "id" / "session.jsonl.zstd": "opaque bytes",
        home / ".local" / "share" / "opencode" / "opencode.db": "opaque db bytes",
    }
    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    inventory = build_inventory(home, {}, which=lambda _name: None, scan=True)
    assert _source(inventory, "Claude Code")["files_found"] == 1
    assert _source(inventory, "Codex CLI")["files_found"] == 1
    assert _source(inventory, "Antigravity (AGY)")["files_found"] == 1
    assert _source(inventory, "DSH")["files_found"] == 1
    assert _source(inventory, "OpenCode")["files_found"] == 1
    assert "--verbose" in _source(inventory, "Claude Code")["new_session_capture"]
    assert "-p=\"<prompt>\"" in _source(inventory, "Antigravity (AGY)")["new_session_capture"]

    rendered = render_text(inventory)
    assert "PRIVATE TRANSCRIPT BODY" not in rendered
    assert "PRIVATE CODEX BODY" not in rendered
    assert "PRIVATE AGY BODY" not in rendered
    assert "No transcript body or database row was read." in rendered


def test_inventory_honors_home_overrides_and_opencode_db_override(tmp_path: Path) -> None:
    home = tmp_path / "user"
    claude_home = tmp_path / "custom-claude"
    codex_home = tmp_path / "custom-codex"
    database = tmp_path / "custom-opencode.sqlite"
    transcript = claude_home / "projects" / "session.jsonl"
    transcript.parent.mkdir(parents=True)
    transcript.touch()
    codex_session = codex_home / "sessions" / "session.jsonl"
    codex_session.parent.mkdir(parents=True)
    codex_session.touch()
    database.touch()

    inventory = build_inventory(
        home,
        {
            "CLAUDE_CONFIG_DIR": str(claude_home),
            "CODEX_HOME": str(codex_home),
            "OPENCODE_DB": str(database),
        },
        which=lambda _name: None,
    )
    assert _source(inventory, "Claude Code")["paths"] == [str(claude_home / "projects")]
    assert _source(inventory, "Codex CLI")["paths"] == [str(codex_home / "sessions")]
    opencode = _source(inventory, "OpenCode")
    assert opencode["paths"] == [str(database)]
    assert opencode["path_resolution"] == "OPENCODE_DB override"


def test_relative_opencode_db_override_is_relative_to_app_data_dir(tmp_path: Path) -> None:
    inventory = build_inventory(
        tmp_path / "user",
        {"OPENCODE_DB": "instance.db"},
        which=lambda _name: None,
    )
    opencode = _source(inventory, "OpenCode")
    expected = tmp_path / "user" / ".local" / "share" / "opencode" / "instance.db"
    assert opencode["paths"] == [str(expected)]


def test_missing_data_roots_and_missing_clis_are_reported_without_crashing(tmp_path: Path) -> None:
    inventory = build_inventory(tmp_path / "empty-user", {}, which=lambda _name: None, scan=True)

    assert all(item["cli_path"] is None for item in inventory)
    assert all(item["files_found"] == 0 for item in inventory)
    assert all(item["exists"] is False or item["exists"] == [False, False, False] for item in inventory)

    rendered = render_text(inventory)
    assert "not found on PATH" in rendered
    assert "No transcript body or database row was read." in rendered


def test_metadata_scan_does_not_open_transcript_files(tmp_path: Path, monkeypatch) -> None:
    home = tmp_path / "user"
    transcript = home / ".claude" / "projects" / "p" / "session.jsonl"
    transcript.parent.mkdir(parents=True)
    transcript.write_text('{"private":"conversation text"}', encoding="utf-8")

    def fail_if_opened(*_args, **_kwargs):
        raise AssertionError("metadata inventory must not read file bodies")

    monkeypatch.setattr(Path, "open", fail_if_opened)
    monkeypatch.setattr("builtins.open", fail_if_opened)
    inventory = build_inventory(home, {}, which=lambda _name: None, scan=True)

    assert _source(inventory, "Claude Code")["files_found"] == 1


def test_opencode_path_command_timeout_uses_fallback_without_claiming_discovery(tmp_path: Path) -> None:
    home = tmp_path / "user"
    with patch.object(
        agent_data_source_poc.subprocess,
        "run",
        side_effect=subprocess.TimeoutExpired(cmd="opencode db path", timeout=5),
    ):
        inventory = build_inventory(home, {}, which=lambda name: "opencode" if name == "opencode" else None)

    opencode = _source(inventory, "OpenCode")
    assert opencode["paths"] == [str(home / ".local" / "share" / "opencode" / "opencode.db")]
    assert opencode["path_resolution"] == "default path fallback"
    assert opencode["exists"] is False
