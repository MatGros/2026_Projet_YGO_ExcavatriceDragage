import sys
import json
import sqlite3
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import session_statusline
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import Supervisor


def _mock_supervisor_sessions(monkeypatch, sessions):
    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def read(self):
            return json.dumps({"sessions": sessions}).encode("utf-8")

    monkeypatch.setattr(
        session_statusline.urllib.request,
        "urlopen",
        lambda *_args, **_kwargs: FakeResponse(),
    )


def _create_antigravity_title_db(app_data, title):
    app_data.mkdir(parents=True, exist_ok=True)
    db_path = app_data / "conversation_summaries.db"
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            "CREATE TABLE conversation_summaries (conversation_id TEXT, title TEXT)"
        )
        conn.execute(
            "INSERT INTO conversation_summaries (conversation_id, title) VALUES (?, ?)",
            ("conversation-id", title),
        )


def test_statusline_reapplies_full_explicit_terminal_title(monkeypatch, capsys):
    title_writes = []
    monkeypatch.setattr(session_statusline.sys, "stdin", type("Input", (), {"isatty": lambda self: True})())
    monkeypatch.setattr(session_statusline.sys, "argv", ["session_statusline.py"])
    monkeypatch.setattr(session_statusline, "get_ancestor_cli_process", lambda: (123, "agy.exe"))
    monkeypatch.setattr(session_statusline, "find_current_conversation_id", lambda *_args: "conversation-id")
    monkeypatch.setattr(
        session_statusline,
        "get_session_info",
        lambda *_args: ("T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3", "AGY02"),
    )
    monkeypatch.setattr(session_statusline, "get_supervisor_status", lambda *_args: "Supervisor: Linked")
    monkeypatch.setattr(session_statusline, "set_terminal_title", lambda title: title_writes.append(title))

    session_statusline.main()

    assert title_writes == [
        f"T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3 {session_statusline.get_boot_terminal_name('agy')}"
    ]
    output = capsys.readouterr().out
    assert "T000" in output
    assert "AGY02" in output
    assert "GEMINI 4 HYDRO CHALLENGE SIMU M3" in output


def test_supervisor_display_title_restores_the_full_session_title(monkeypatch):
    class FakeResponse:
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def read(self):
            return (
                b'{"sessions":[{"native_id":"conversation-id",'
                b'"alias":"T000-CDX02",'
                b'"display_title":"T000-CDX02 FABLE 5-2 CHALLENGE M3 SIMULATION"}]}'
            )

    monkeypatch.setattr(
        session_statusline.urllib.request,
        "urlopen",
        lambda *_args, **_kwargs: FakeResponse(),
    )

    title, _actor = session_statusline.get_session_info("conversation-id", "codex.exe")

    assert title == "T000-CDX02 FABLE 5-2 CHALLENGE M3 SIMULATION"


def test_supervisor_title_wins_over_stale_antigravity_sqlite_title(monkeypatch, tmp_path):
    supervisor_title = "T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3"
    monkeypatch.setattr(session_statusline, "APP_DATA", tmp_path)
    _create_antigravity_title_db(tmp_path, "Gemini 4 Hydro Test And Project Workflow")
    _mock_supervisor_sessions(
        monkeypatch,
        [{
            "native_id": "conversation-id",
            "alias": "T000-AGY02",
            "display_title": supervisor_title,
        }],
    )

    title, _actor = session_statusline.get_session_info("conversation-id", "agy.exe")

    assert title == supervisor_title


def test_antigravity_sqlite_title_remains_fallback_without_supervisor_title(
    monkeypatch, tmp_path
):
    sqlite_title = "Gemini 4 Hydro Test And Project Workflow"
    monkeypatch.setattr(session_statusline, "APP_DATA", tmp_path)
    _create_antigravity_title_db(tmp_path, sqlite_title)
    _mock_supervisor_sessions(monkeypatch, [])

    title, _actor = session_statusline.get_session_info("conversation-id", "agy.exe")

    assert title == sqlite_title


def test_supervisor_title_wins_over_stale_claude_transcript_title(monkeypatch, tmp_path):
    supervisor_title = "T000-CC10 MULTITASK ORCHESTRATOR AGENT"
    project_dir = tmp_path / ".claude" / "projects" / "project"
    project_dir.mkdir(parents=True)
    transcript = project_dir / "conversation-id.jsonl"
    transcript.write_text(
        json.dumps({"type": "ai-title", "aiTitle": "Old Claude title"}) + "\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(session_statusline.Path, "home", lambda: tmp_path)
    _mock_supervisor_sessions(
        monkeypatch,
        [{
            "native_id": "conversation-id",
            "alias": "T000-CC10",
            "display_title": supervisor_title,
        }],
    )

    title, _actor = session_statusline.get_session_info("conversation-id", "claude.exe")

    assert title == supervisor_title


def test_claude_transcript_title_remains_fallback_without_supervisor_title(
    monkeypatch, tmp_path
):
    transcript_title = "Old Claude title"
    project_dir = tmp_path / ".claude" / "projects" / "project"
    project_dir.mkdir(parents=True)
    transcript = project_dir / "conversation-id.jsonl"
    transcript.write_text(
        json.dumps({"type": "ai-title", "aiTitle": transcript_title}) + "\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(session_statusline.Path, "home", lambda: tmp_path)
    _mock_supervisor_sessions(monkeypatch, [])

    title, _actor = session_statusline.get_session_info("conversation-id", "claude.exe")

    assert title == transcript_title


def test_supervisor_summary_exposes_only_rename_title(tmp_path):
    service = Supervisor(state_path=tmp_path / "state.json")
    service.sessions["session-id"] = service._new_session(
        "session-id",
        "codex",
        "conversation-id",
        "T000-CC10",
        False,
        "T000-CC10 MULTITASK ORCHESTRATOR AGENT — Dossier: T000_ORCHESTRATION_MULTI_TACHES",
    )

    entry = service.notification_snapshot()["sessions"][0]

    assert entry["display_title"] == "T000-CC10 MULTITASK ORCHESTRATOR AGENT"
    assert "mission" not in entry
    service.sessions["session-id"]["mission"] = "T000-CC10 Mission context\nConstraints: private details"
    assert service.notification_snapshot()["sessions"][0]["display_title"] == "T000-CC10"


def test_codex_session_detection_uses_only_consistent_codex_ids(monkeypatch):
    thread_id = "11111111-2222-4333-8444-555555555555"
    monkeypatch.setenv("CODEX_THREAD_ID", thread_id)
    monkeypatch.setenv("CODEX_SESSION_ID", thread_id)
    monkeypatch.setenv("ANTIGRAVITY_CONVERSATION_ID", "wrong-platform-session")

    assert session_statusline.find_current_conversation_id("codex.exe") == thread_id

    monkeypatch.setenv("CODEX_SESSION_ID", "99999999-2222-4333-8444-555555555555")
    assert session_statusline.find_current_conversation_id("codex.exe") is None
