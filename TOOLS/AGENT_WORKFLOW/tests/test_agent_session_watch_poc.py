from __future__ import annotations

import json
from pathlib import Path

from TOOLS.AGENT_WORKFLOW.scripts.agent_session_watch_poc import (
    JsonlAppendWatcher,
    resolve_jsonl_source,
)


def _line(value: dict) -> str:
    return json.dumps(value, separators=(",", ":")) + "\n"


def test_source_resolution_requires_exact_unique_session_id(tmp_path: Path) -> None:
    root = tmp_path / "claude-projects"
    one = root / "project-a" / "session-123.jsonl"
    one.parent.mkdir(parents=True)
    one.touch()

    found = resolve_jsonl_source(root, "session-123")
    assert found.state == "ready"
    assert found.path == one
    assert resolve_jsonl_source(root, "session").state == "source_missing"
    assert resolve_jsonl_source(root, "../session-123").state == "invalid_id"

    duplicate = root / "project-b" / "session-123.jsonl"
    duplicate.parent.mkdir(parents=True)
    duplicate.touch()
    result = resolve_jsonl_source(root, "session-123")
    assert result.state == "ambiguous"
    assert result.path is None
    assert result.matches == 2


def test_attach_starts_at_end_and_emits_each_new_record_once(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"text": "old"}), encoding="utf-8")
    watcher = JsonlAppendWatcher(source)

    assert watcher.poll().events == []
    with source.open("a", encoding="utf-8") as stream:
        stream.write(_line({"text": "new"}))
    result = watcher.poll()
    assert result.state == "active"
    assert result.events == [{"text": "new"}]
    assert watcher.poll().events == []


def test_partial_jsonl_record_is_buffered_until_newline(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.touch()
    watcher = JsonlAppendWatcher(source)

    with source.open("ab") as stream:
        stream.write(b'{"text":"part')
    assert watcher.poll().events == []

    with source.open("ab") as stream:
        stream.write(b'ial"}\n')
    result = watcher.poll()
    assert result.state == "active"
    assert result.events == [{"text": "partial"}]


def test_two_explicit_instances_keep_events_and_loss_states_separate(tmp_path: Path) -> None:
    root = tmp_path / "sessions"
    session_a = root / "project-a" / "session-a.jsonl"
    session_b = root / "project-b" / "session-b.jsonl"
    session_a.parent.mkdir(parents=True)
    session_b.parent.mkdir(parents=True)
    session_a.touch()
    session_b.touch()
    source_a = resolve_jsonl_source(root, "session-a")
    source_b = resolve_jsonl_source(root, "session-b")
    watcher_a = JsonlAppendWatcher(source_a.path)
    watcher_b = JsonlAppendWatcher(source_b.path)

    with session_a.open("a", encoding="utf-8") as stream:
        stream.write(_line({"instance": "a"}))
    with session_b.open("a", encoding="utf-8") as stream:
        stream.write(_line({"instance": "b"}))

    assert watcher_a.poll().events == [{"instance": "a"}]
    assert watcher_b.poll().events == [{"instance": "b"}]
    session_a.unlink()
    assert watcher_a.poll().state == "source_missing"
    assert watcher_b.poll().state == "active"


def test_truncation_is_reported_then_new_records_can_be_read(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"text": "long historical record"}), encoding="utf-8")
    watcher = JsonlAppendWatcher(source)
    source.write_text("", encoding="utf-8")

    reset = watcher.poll()
    assert reset.state == "source_reset"
    assert reset.events == []

    watcher.reattach()
    with source.open("a", encoding="utf-8") as stream:
        stream.write(_line({"text": "after reset"}))
    assert watcher.poll().events == [{"text": "after reset"}]


def test_replaced_source_is_reported_and_not_replayed(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"text": "old"}), encoding="utf-8")
    watcher = JsonlAppendWatcher(source)
    replacement = tmp_path / "replacement.jsonl"
    replacement.write_text(_line({"text": "replacement history"}), encoding="utf-8")
    replacement.replace(source)

    result = watcher.poll()
    assert result.state == "source_reset"
    assert result.events == []


def test_missing_source_is_never_reported_as_active(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.touch()
    watcher = JsonlAppendWatcher(source)
    source.unlink()

    result = watcher.poll()
    assert result.state == "source_missing"
    assert result.events == []


def test_malformed_record_latches_error_without_replaying_valid_events(tmp_path: Path) -> None:
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"text": "good"}) + "not-json\n", encoding="utf-8")
    watcher = JsonlAppendWatcher(source, start_at_end=False)

    result = watcher.poll()
    assert result.state == "parse_error"
    assert result.events == [{"text": "good"}]
    repeated = watcher.poll()
    assert repeated.state == "parse_error"
    assert repeated.events == []


def test_glob_ids_never_select_a_conversation(tmp_path):
    (tmp_path / "session-1.jsonl").touch()
    for sid in ("*", "session-?", "session-[1]", "", "../session-1"):
        assert resolve_jsonl_source(tmp_path, sid).state == "invalid_id"


def test_in_place_regrowth_requires_explicit_reattachment(tmp_path):
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": "x" * 60}))
    watcher = JsonlAppendWatcher(source)
    source.write_text(_line({"new": "y" * 100}))
    assert watcher.poll().state == "source_reset"
    assert watcher.poll().state == "source_reset"
    watcher.reattach()
    assert watcher.poll().events == []


def test_missing_source_created_later_does_not_replay_history(tmp_path):
    source = tmp_path / "session.jsonl"
    watcher = JsonlAppendWatcher(source)
    assert watcher.poll().state == "source_missing"
    source.write_text(_line({"old": 1}))
    assert watcher.poll().events == []


def test_equal_size_rewrite_is_detected(tmp_path):
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"value": 1}))
    watcher = JsonlAppendWatcher(source)
    source.write_text(_line({"value": 9}))
    assert watcher.poll().state == "source_reset"


def test_attachment_access_denied_recovers_on_next_poll(tmp_path, monkeypatch):
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": 1}))
    original = Path.open
    with monkeypatch.context() as m:
        m.setattr(Path, "open", lambda *a, **k: (_ for _ in ()).throw(PermissionError(32, "locked")))
        watcher = JsonlAppendWatcher(source)
        assert watcher.poll().state == "source_error"
    assert watcher.poll().events == []
    with original(source, "a") as stream:
        stream.write(_line({"new": 2}))
    assert watcher.poll().events == [{"new": 2}]


class _InterceptRead:
    def __init__(self, stream, callback):
        self.stream, self.callback = stream, callback
    def __enter__(self):
        return self
    def __exit__(self, *args):
        self.stream.close()
    def __getattr__(self, name):
        return getattr(self.stream, name)
    def read(self, *args):
        result = self.stream.read(*args)
        self.callback()
        return result


def test_io_failure_does_not_consume_unemitted_events(tmp_path, monkeypatch):
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": 1}))
    watcher = JsonlAppendWatcher(source)
    with source.open("a") as stream:
        stream.write(_line({"new": 2}))
    old_offset, old_digest = watcher.offset, watcher._digest
    original = Path.open
    calls = 0
    def fail_after_chunk():
        nonlocal calls
        calls += 1
        if calls == 2:
            raise PermissionError(32, "transient read failure")
    with monkeypatch.context() as m:
        m.setattr(Path, "open", lambda path, *a, **k: _InterceptRead(original(path, *a, **k), fail_after_chunk))
        assert watcher.poll().state == "source_error"
    assert (watcher.offset, watcher._digest) == (old_offset, old_digest)
    assert watcher.poll().events == [{"new": 2}]
    assert watcher.poll().events == []


def test_mutation_during_read_is_rejected_without_advancing(tmp_path, monkeypatch):
    import os
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": 1}))
    watcher = JsonlAppendWatcher(source)
    old_offset = watcher.offset
    original = Path.open
    mutated = False
    def rewrite_after_prefix():
        nonlocal mutated
        if not mutated:
            mutated = True
            with original(source, "w") as stream:
                stream.write(_line({"old": 9}) + _line({"new": 2}))
            stat = source.stat()
            os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1000000))
    with monkeypatch.context() as m:
        m.setattr(Path, "open", lambda path, *a, **k: _InterceptRead(original(path, *a, **k), rewrite_after_prefix))
        result = watcher.poll()
    assert result.state in ("source_error", "source_reset")
    assert result.events == []
    assert watcher.offset == old_offset
    assert watcher.poll().state == "source_reset"


def test_attachment_rejects_mutation_during_snapshot(tmp_path, monkeypatch):
    import os
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": 1}))
    original = Path.open
    mutated = False
    def mutate():
        nonlocal mutated
        if not mutated:
            mutated = True
            with original(source, "w") as stream:
                stream.write(_line({"old": 9}) + _line({"new": 2}))
            stat = source.stat()
            os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1000000))
    with monkeypatch.context() as m:
        m.setattr(Path, "open", lambda path, *a, **k: _InterceptRead(original(path, *a, **k), mutate))
        watcher = JsonlAppendWatcher(source)
    assert watcher._identity is None
    assert watcher.poll().events == []


def test_windows_exclusive_share_lock_recovers(tmp_path):
    import ctypes
    import sys
    import pytest
    if sys.platform != "win32":
        pytest.skip("Windows sharing semantics")
    source = tmp_path / "session.jsonl"
    source.write_text(_line({"old": 1}))
    watcher = JsonlAppendWatcher(source)
    with source.open("a") as stream:
        stream.write(_line({"new": 2}))
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.restype = ctypes.c_void_p
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_void_p]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.CreateFileW(str(source), 0x80000000, 0, None, 3, 0x80, None)
    assert handle != ctypes.c_void_p(-1).value
    try:
        result = watcher.poll()
        assert result.state == "source_error"
        assert result.error == "PermissionError"
    finally:
        kernel.CloseHandle(handle)
    assert watcher.poll().events == [{"new": 2}]
    assert watcher.poll().events == []


def test_platform_filename_layouts_require_literal_native_ids(tmp_path):
    codex_id = "01a199fa-f501-7313-bea5-6db39f54df1a"
    codex = tmp_path / ("rollout-2026-11-02T02-58-43-" + codex_id + ".jsonl")
    codex.touch()
    agy = tmp_path / "session-123" / "transcript.jsonl"
    agy.parent.mkdir()
    agy.touch()
    assert resolve_jsonl_source(tmp_path, codex_id, platform="codex").path == codex
    assert resolve_jsonl_source(tmp_path, "session-123", platform="agy").path == agy
    assert resolve_jsonl_source(tmp_path, "123", platform="agy").state == "source_missing"
    assert resolve_jsonl_source(tmp_path, "session-*", platform="codex").state == "invalid_id"
    assert resolve_jsonl_source(tmp_path, "session-123", platform="unknown").state == "invalid_platform"


def test_agy_nested_log_layout_is_exact_and_detects_duplicates(tmp_path):
    nested = tmp_path / "session-123" / ".system_generated" / "logs" / "transcript.jsonl"
    nested.parent.mkdir(parents=True)
    nested.touch()
    assert resolve_jsonl_source(tmp_path, "session-123", platform="agy").path == nested
    (tmp_path / "session-123" / "transcript.jsonl").touch()
    assert resolve_jsonl_source(tmp_path, "session-123", platform="agy").state == "ambiguous"


def test_codex_native_id_suffixes_are_rejected(tmp_path):
    sid = "01a199fa-f501-7313-bea5-6db39f54df1a"
    (tmp_path / ("rollout-2026-11-02T02-58-43-" + sid + ".jsonl")).touch()
    assert resolve_jsonl_source(tmp_path, sid, platform="codex").state == "ready"
    for suffix in [sid[1:], sid[9:], sid[14:], sid[19:], sid[24:]]:
        assert resolve_jsonl_source(tmp_path, suffix, platform="codex").state == "invalid_id"


def test_cli_content_requires_explicit_opt_in(tmp_path, monkeypatch, capsys):
    import sys
    from TOOLS.AGENT_WORKFLOW.scripts.agent_session_watch_poc import main
    (tmp_path / "session-123.jsonl").write_text(_line({"type": "assistant", "secret": "MESSAGE_CONTENT"}))
    argv = ["watch", "--root", str(tmp_path), "--session-id", "session-123", "--platform", "claude", "--duration", "0.01", "--interval", "0.005", "--from-beginning"]
    monkeypatch.setattr(sys, "argv", argv)
    assert main() == 0
    assert "MESSAGE_CONTENT" not in capsys.readouterr().out
    monkeypatch.setattr(sys, "argv", argv + ["--include-content"])
    assert main() == 0
    assert "MESSAGE_CONTENT" in capsys.readouterr().out
