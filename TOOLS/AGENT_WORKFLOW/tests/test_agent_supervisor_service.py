import json
import threading
import time
from pathlib import Path

import pytest

from TOOLS.AGENT_WORKFLOW.scripts.agent_supervisor_service import Supervisor, normalize


def eventually(predicate, timeout=3):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.01)
    assert predicate(), "condition not reached before timeout"


def append(source, role, text):
    with source.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps({"type": role, "message": {"content": [{"type": "text", "text": text}]}}) + "\n")


@pytest.fixture
def setup(tmp_path):
    services = []
    root = tmp_path / "sources"
    root.mkdir()
    def create(judge=lambda model, messages: {"alert": False}, name="state.json", chat=None):
        service = Supervisor(tmp_path/name, roots={"claude": [root]}, judge=judge, poll_interval=.02, chat=chat)
        services.append(service)
        return service
    yield root, create
    for service in services:
        service.close()


def add_started(service, root, sid="session-a"):
    source = root / (sid + ".jsonl")
    source.touch()
    value = service.command(dict(action="add", platform="claude", native_id=sid, alias=sid, mission="Verifier les contradictions et les preuves de cette session"))
    assignment = next(x["id"] for x in value["sessions"] if x["native_id"] == sid)
    service.command({"action": "start"})
    eventually(lambda: next(x for x in service.snapshot()["sessions"] if x["id"] == assignment)["state"] == "active")
    return source, assignment


def test_assignment_lifecycle_and_restore_paused(setup):
    root, create = setup
    service = create()
    source, sid = add_started(service, root)
    append(source, "assistant", "PRIVATE BODY")
    eventually(lambda: service.snapshot()["sessions"][0]["analysis_state"] == "no_alert")
    assert "PRIVATE BODY" not in service.state_path.read_text()
    service.command({"action": "pause", "id": sid})
    assert service.snapshot()["sessions"][0]["state"] == "paused"
    service.command({"action": "resume", "id": sid})
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "active")
    service.command({"action": "stop"})
    assert not service.snapshot()["running"]
    service.command({"action": "start"})
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "active")
    restored = create()
    assert not restored.snapshot()["running"]
    assert restored.snapshot()["sessions"][0]["state"] == "paused"
    service.command({"action": "remove", "id": sid})
    assert service.snapshot()["sessions"] == []


def test_reply_arriving_immediately_after_attach_is_not_lost(setup):
    root, create = setup
    calls = []
    source = root / "session-a.jsonl"
    source.touch()
    service = create(lambda model, messages: calls.append(messages) or {"alert": False})
    value = service.command(dict(action="add", platform="claude", native_id="session-a",
                                 alias="session-a", mission="Check new assistant replies"))
    assignment = value["sessions"][0]["id"]
    # Model a reply arriving before the first background collector tick.
    append(source, "assistant", "FIRST_REPLY_AFTER_ATTACH")
    service.command({"action": "start"})
    eventually(lambda: next(x for x in service.snapshot()["sessions"] if x["id"] == assignment)["analysis_state"] == "no_alert")
    assert any(message["text"] == "FIRST_REPLY_AFTER_ATTACH" for message in calls[0])


def test_cloud_model_selection_is_separate_from_transcript_consent(setup):
    root, create = setup
    service = create()
    with pytest.raises(ValueError):
        service.command(dict(action="configure", model="deepseek:cloud", allow_cloud="false"))
    service.command(dict(action="configure", model="deepseek-v4.1-flash:cloud", allow_cloud=False))
    assert service.snapshot()["model"] == "deepseek-v4.1-flash:cloud"
    assert not service.snapshot()["allow_cloud"]
    service.command(dict(action="configure", model="deepseek-v4.1-flash:cloud", allow_cloud=True))
    assert service.snapshot()["allow_cloud"]
    service.command(dict(action="configure", model="qwen3.8:27b", allow_cloud=False))
    assert not service.snapshot()["allow_cloud"]


@pytest.mark.parametrize("failure", ["timeout", "malformed", "fabricated_quote"])
def test_judge_errors_are_visible_not_success(setup, failure):
    root, create = setup
    def judge(model, messages):
        if failure == "timeout":
            raise TimeoutError()
        if failure == "malformed":
            return "not-json"
        return dict(alert=True, severity="warning", reason="issue", evidence="NEVER PRESENT")
    service = create(judge)
    source, _ = add_started(service, root)
    append(source, "assistant", "Observed sentence")
    eventually(lambda: service.snapshot()["sessions"][0]["analysis_state"] == "unavailable")
    assert service.snapshot()["alerts"] == []
    assert service.snapshot()["sessions"][0]["state"] == "active"


def test_two_contexts_are_isolated_and_duplicate_claims_not_replayed(setup):
    root, create = setup
    calls = []
    def judge(model, messages):
        calls.append(messages)
        return dict(alert=True, severity="warning", reason="Review this claim", evidence=messages[-1]["text"])
    service = create(judge)
    a, _ = add_started(service, root, "session-a")
    b, _ = add_started(service, root, "session-b")
    append(a, "assistant", "ONLY_A")
    append(b, "assistant", "ONLY_B")
    eventually(lambda: len(service.snapshot()["alerts"]) == 2)
    assert all(not ({"ONLY_A", "ONLY_B"} <= {m["text"] for m in ctx}) for ctx in calls)
    count = len(calls)
    time.sleep(.35)
    assert len(calls) == count
    assert len(service.snapshot()["alerts"]) == 2


@pytest.mark.parametrize("action", ["pause", "remove", "stop", "configure"])
def test_collector_does_not_wait_for_judge_and_stale_results_are_discarded(setup, action):
    root, create = setup
    started, release, finished = threading.Event(), threading.Event(), threading.Event()
    def judge(model, messages):
        started.set()
        release.wait(3)
        finished.set()
        return dict(alert=True, severity="warning", reason="old result", evidence=messages[-1]["text"])
    service = create(judge)
    source, sid = add_started(service, root)
    append(source, "assistant", "FIRST")
    assert started.wait(2)
    original = service.snapshot()["sessions"][0]["last_event"]
    append(source, "user", "SECOND WHILE JUDGE BLOCKED")
    eventually(lambda: service.snapshot()["sessions"][0]["last_event"] != original)
    service.command(dict(action=action, id=sid, model="gemma4:e4b", allow_cloud=False))
    release.set()
    assert finished.wait(2)
    time.sleep(.05)
    assert service.snapshot()["alerts"] == []


def test_normalization_uses_only_canonical_records():
    assert normalize("agy", {"type": "PLANNER_RESPONSE", "content": "hello"}) == ("assistant", "hello")
    assert normalize("agy", {"type": "USER_INPUT", "content": "hi"}) == ("user", "hi")
    assert normalize("codex", {"type": "event_msg", "payload": {"type": "agent_message", "message": "duplicate"}}) is None
    assert normalize("codex", {"type": "response_item", "payload": {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "ok"}]}}) == ("assistant", "ok")


def test_unknown_or_wildcard_assignment_rejected(setup):
    root, create = setup
    service = create()
    for platform, sid in [("claude", "*"), ("other", "session-a")]:
        with pytest.raises(ValueError):
            service.command(dict(action="add", platform=platform, native_id=sid))
    assert service.snapshot()["sessions"] == []


def test_source_reset_stays_visible_until_explicit_resume(setup):
    root, create = setup
    service = create()
    source, sid = add_started(service, root)
    append(source, "user", "old")
    eventually(lambda: service.snapshot()["sessions"][0]["last_event"] is not None)
    source.write_text('{"type":"user","message":{"content":"replacement content longer than old record"}}\n')
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "source_reset")
    service.command(dict(action="resume", id=sid))
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "active")


@pytest.mark.parametrize("function_name", ["ollama_judge", "ollama_chat"])
@pytest.mark.parametrize("metadata", [
    {"models": [{"name": "alias:latest", "remote_model": "deepseek", "remote_host": "https://ollama.com"}]},
    {"models": []},
])
def test_cloud_alias_or_unknown_model_never_receives_transcript(monkeypatch, metadata, function_name):
    from TOOLS.AGENT_WORKFLOW.scripts import agent_supervisor_service as module
    calls = []
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def read(self, *args): return json.dumps(metadata).encode()
    def urlopen(request, **kwargs):
        calls.append(request.full_url)
        assert request.data is None
        return Response()
    monkeypatch.setattr(module.urllib.request, "urlopen", urlopen)
    with pytest.raises(ValueError):
        getattr(module, function_name)("alias:latest", [{"role": "user", "text": "PRIVATE"}])
    assert calls == ["http://127.0.0.1:11434/api/tags"]


def test_local_metadata_checked_before_generate_and_cloud_opt_in_skips_check(monkeypatch):
    from TOOLS.AGENT_WORKFLOW.scripts import agent_supervisor_service as module
    calls = []
    class Response:
        def __init__(self, payload): self.payload = payload
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def read(self, *args): return json.dumps(self.payload).encode()
    def urlopen(request, **kwargs):
        calls.append(request.full_url)
        if request.full_url.endswith("/tags"):
            return Response({"models": [{"name": "local:latest"}]})
        assert json.loads(request.data)["prompt"]
        return Response({"response": '{"alert":false}'})
    monkeypatch.setattr(module.urllib.request, "urlopen", urlopen)
    assert module.ollama_judge("local:latest", [{"text": "one"}]) == {"alert": False}
    assert calls == ["http://127.0.0.1:11434/api/tags", "http://127.0.0.1:11434/api/generate"]
    calls.clear()
    assert module.ollama_judge("remote:cloud", [{"text": "two"}], allow_cloud=True) == {"alert": False}
    assert calls == ["http://127.0.0.1:11434/api/generate"]


def test_close_waits_for_bounded_judge_and_leaves_no_threads(setup):
    root, create = setup
    started = threading.Event()
    def judge(model, messages):
        started.set()
        time.sleep(.2)
        return {"alert": False}
    service = create(judge)
    source, _ = add_started(service, root)
    append(source, "assistant", "message")
    assert started.wait(2)
    assert service.close(timeout=2)
    assert all(not thread.is_alive() for thread in service._threads)
    assert service.snapshot()["alerts"] == []


def test_context_budget_is_bounded(setup):
    root, create = setup
    calls = []
    def judge(model, messages):
        calls.append(messages)
        return {"alert": False}
    service = create(judge)
    source, _ = add_started(service, root)
    for index in range(20):
        append(source, "user", str(index) + "x" * 1000)
    append(source, "assistant", "FINAL")
    eventually(lambda: bool(calls))
    assert sum(len(message["text"]) for message in calls[-1] if message["role"] not in ("mission", "context_notice")) <= 6000
    assert len([m for m in calls[-1] if m["role"] not in ("mission", "context_notice")]) <= 12
    assert calls[-1][-1]["text"] == "FINAL"
    assert service.snapshot()["sessions"][0]["context_truncated"] is True


@pytest.mark.parametrize("action", ["configure", "add", "pause", "resume", "remove"])
def test_persistence_failure_rolls_back_all_in_memory_changes(setup, monkeypatch, action):
    root, create = setup
    service = create()
    value = service.command(dict(action="add", platform="claude", native_id="session-a", alias="A"))
    sid = value["sessions"][0]["id"]
    before = service.snapshot()
    persisted_before = service.state_path.read_text()
    epoch_before = service._epoch
    def reject():
        raise OSError("disk unavailable")
    monkeypatch.setattr(service, "_persist", reject)
    with pytest.raises(OSError):
        service.command(dict(action=action, id=sid, platform="claude", native_id="session-b", model="remote:cloud", allow_cloud=True))
    assert service.snapshot() == before
    assert service._epoch == epoch_before
    assert service.state_path.read_text() == persisted_before


def test_resolution_access_error_is_not_hidden_by_ready_other_root(setup, monkeypatch):
    root, create = setup
    from TOOLS.AGENT_WORKFLOW.scripts import agent_supervisor_service as module
    from TOOLS.AGENT_WORKFLOW.scripts.agent_session_watch_poc import SourceResolution
    service = create()
    second = root / "other"
    second.mkdir()
    service.roots["claude"].append(second)
    original = module.resolve_jsonl_source
    def resolve(path, sid, **kwargs):
        if path == second:
            return SourceResolution("source_error", None, 0)
        return original(path, sid, **kwargs)
    monkeypatch.setattr(module, "resolve_jsonl_source", resolve)
    (root / "session-a.jsonl").touch()
    service.command(dict(action="add", platform="claude", native_id="session-a"))
    service.command(dict(action="start"))
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "source_error")
    session = service.snapshot()["sessions"][0]
    assert session["error"] == "source_resolution_error"
    assert session["source"] is None


def test_missing_mission_collects_but_never_calls_semantic_judge(setup):
    root, create = setup
    calls = []
    service = create(lambda model, messages: calls.append(messages))
    source = root / "session-a.jsonl"
    source.touch()
    service.command(dict(action="add", platform="claude", native_id="session-a"))
    service.command(dict(action="start"))
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "active")
    append(source, "assistant", "UNREVIEWED CLAIM")
    eventually(lambda: service.snapshot()["sessions"][0]["last_event"] is not None)
    assert service.snapshot()["sessions"][0]["analysis_state"] == "context_required"
    assert calls == []


def test_mission_persists_and_disk_failure_rolls_back_context(setup, monkeypatch):
    root, create = setup
    service = create()
    _, sid = add_started(service, root)
    service.command(dict(action="set_mission", id=sid, mission="Verify task X only"))
    assert create().snapshot()["sessions"][0]["mission"] == "Verify task X only"
    service.command(dict(action="pause", id=sid))
    before = service.snapshot()
    monkeypatch.setattr(service, "_persist", lambda: (_ for _ in ()).throw(OSError("disk")))
    with pytest.raises(OSError):
        service.command(dict(action="set_mission", id=sid, mission="different"))
    assert service.snapshot() == before


def test_evidence_must_quote_actual_assistant_not_user_or_mission(setup):
    root, create = setup
    def judge(model, messages):
        assert messages[0]["role"] == "mission"
        return dict(alert=True, severity="warning", reason="bad citation", evidence="USER ONLY")
    service = create(judge)
    source, _ = add_started(service, root)
    append(source, "user", "USER ONLY")
    append(source, "assistant", "ASSISTANT DIFFERENT")
    eventually(lambda: service.snapshot()["sessions"][0]["analysis_state"] == "unavailable")
    assert service.snapshot()["alerts"] == []


def test_acknowledged_repeat_updates_count_without_new_alert(setup):
    root, create = setup
    def judge(model, messages):
        return dict(alert=True, severity="warning", reason="Check claim", evidence="CLAIM")
    service = create(judge)
    source, sid = add_started(service, root)
    append(source, "assistant", "CLAIM")
    eventually(lambda: len(service.snapshot()["alerts"]) == 1)
    alert = service.snapshot()["alerts"][0]
    service.command(dict(action="acknowledge", id=sid, alert_id=alert["id"], disposition="false_positive"))
    append(source, "assistant", "CLAIM")
    eventually(lambda: service.snapshot()["alerts"][0]["occurrences"] == 2)
    alerts = service.snapshot()["alerts"]
    assert len(alerts) == 1
    assert alerts[0]["id"] == alert["id"]
    assert alerts[0]["disposition"] == "false_positive"
    assert service.snapshot()["sessions"][0]["analysis_state"] == "alert_acknowledged"
    with pytest.raises(ValueError):
        service.command(dict(action="acknowledge", id=sid, alert_id=alert["id"], disposition="resolved"))


def test_chat_selected_session_only_and_global_no_transcripts(setup):
    root, create = setup
    calls = []
    def chat(model, messages):
        calls.append(messages)
        return "Consultative answer"
    service = create(chat=chat)
    a, a_id = add_started(service, root, "session-a")
    b, _ = add_started(service, root, "session-b")
    append(a, "user", "SECRET_A_TRANSCRIPT")
    append(b, "user", "SECRET_B_TRANSCRIPT")
    eventually(lambda: all(s["last_event"] for s in service.snapshot()["sessions"]))
    service.command(dict(action="chat", session_id=a_id, text="Discuss this session"))
    eventually(lambda: service.snapshot()["chat"]["state"] == "idle")
    assert "SECRET_A_TRANSCRIPT" in json.dumps(calls[0])
    assert "SECRET_B_TRANSCRIPT" not in json.dumps(calls[0])
    service.command(dict(action="chat", text="Global status"))
    eventually(lambda: len(calls) == 2 and service.snapshot()["chat"]["state"] == "idle")
    assert "SECRET_A_TRANSCRIPT" not in json.dumps(calls[1])
    assert "SECRET_B_TRANSCRIPT" not in json.dumps(calls[1])
    assert "SECRET_A_TRANSCRIPT" not in service.state_path.read_text()
    assert "Global status" not in service.state_path.read_text()


@pytest.mark.parametrize("action", ["reset_chat", "configure", "stop"])
def test_chat_busy_and_stale_results_discarded(setup, action):
    root, create = setup
    started, release, finished = threading.Event(), threading.Event(), threading.Event()
    def chat(model, messages):
        started.set()
        release.wait(2)
        finished.set()
        return "STALE ANSWER"
    service = create(chat=chat)
    _, sid = add_started(service, root)
    session_ids = [s["id"] for s in service.snapshot()["sessions"]]
    service.command(dict(action="chat", text="Question", session_id=sid))
    assert started.wait(2)
    with pytest.raises(ValueError, match="occupe"):
        service.command(dict(action="chat", text="duplicate"))
    service.command(dict(action=action, model="gemma4:e4b", allow_cloud=False))
    release.set()
    assert finished.wait(2)
    time.sleep(.05)
    value = service.snapshot()
    assert not any(m["text"] == "STALE ANSWER" for m in value["chat"]["messages"])
    assert [s["id"] for s in value["sessions"]] == session_ids
    if action == "reset_chat":
        assert value["chat"]["messages"] == []


def test_chat_timeout_visible_and_size_validated(setup):
    root, create = setup
    def chat(model, messages):
        raise TimeoutError()
    service = create(chat=chat)
    service.command(dict(action="start"))
    for text in ["", "x" * 2001]:
        with pytest.raises(ValueError):
            service.command(dict(action="chat", text=text))
    service.command(dict(action="chat", text="Question"))
    eventually(lambda: service.snapshot()["chat"]["state"] == "unavailable")
    assert service.snapshot()["chat"]["error"] == "TimeoutError"
    assert not any(m["role"] == "assistant" for m in service.snapshot()["chat"]["messages"])


def test_exchange_path_uses_assignment_uuid_not_alias_or_native_id(setup):
    root, create = setup
    service = create()
    snapshot = service.command(dict(action="add", platform="claude", native_id="session-a", alias="../../CODE/<script>"))
    assignment = snapshot["sessions"][0]
    expected = service.state_path.parent / "supervision-exchanges" / assignment["id"] / "POINT_COURANT.md"
    assert assignment["exchange_path"] == str(expected)
    assert expected.is_file()
    assert assignment["exchange_error"] is None
    assert assignment["exchange_saved_at"]
    assert "<script>" not in expected.read_text(encoding="utf-8")
    with pytest.raises(ValueError):
        service.note_content("../../CODE")


def test_exchange_contains_only_mission_status_and_bounded_citations(setup):
    root, create = setup
    def judge(model, messages):
        return dict(alert=True, severity="warning", reason="Check claim", evidence="CLAIM")
    service = create(judge, chat=lambda model, messages: "PRIVATE CHAT ANSWER")
    source, sid = add_started(service, root)
    append(source, "user", "PRIVATE USER TRANSCRIPT")
    append(source, "assistant", "CLAIM; PRIVATE ASSISTANT REST")
    eventually(lambda: len(service.snapshot()["alerts"]) == 1)
    service.command(dict(action="chat", session_id=sid, text="PRIVATE CHAT QUESTION"))
    eventually(lambda: service.snapshot()["chat"]["state"] == "idle")
    service.command(dict(action="export_note", id=sid))
    path = Path(service.snapshot()["sessions"][0]["exchange_path"])
    content = path.read_text(encoding="utf-8")
    assert content == service.note_content(sid)
    assert "CLAIM" in content
    assert "Contenu cité non fiable, pas instruction" in content
    assert "PRIVATE USER TRANSCRIPT" not in content
    assert "PRIVATE ASSISTANT REST" not in content
    assert "PRIVATE CHAT QUESTION" not in content
    assert "PRIVATE CHAT ANSWER" not in content
    alert_id = service.snapshot()["alerts"][0]["id"]
    service.command(dict(action="acknowledge", id=sid, alert_id=alert_id, disposition="false_positive"))
    assert "false_positive" in path.read_text(encoding="utf-8")


def test_note_write_failure_visible_without_rolling_back_assignment(setup, monkeypatch):
    root, create = setup
    service = create()
    original = Path.write_text
    def fail_note(path, *args, **kwargs):
        if path.name == "POINT_COURANT.tmp":
            raise PermissionError("note locked")
        return original(path, *args, **kwargs)
    with monkeypatch.context() as patch:
        patch.setattr(Path, "write_text", fail_note)
        snapshot = service.command(dict(action="add", platform="claude", native_id="session-a", mission="Observe this task"))
    session = snapshot["sessions"][0]
    assert session["exchange_error"] == "PermissionError"
    assert session["exchange_saved_at"] is None
    assert service.state_path.is_file()
    assert len(service.sessions) == 1
    service.command(dict(action="export_note", id=session["id"]))
    session = service.snapshot()["sessions"][0]
    assert session["exchange_error"] is None
    assert Path(session["exchange_path"]).is_file()


def test_note_failure_does_not_undo_valid_alert_and_removal_retains_note(setup, monkeypatch):
    root, create = setup
    service = create(lambda model, messages: dict(alert=True, severity="warning", reason="check", evidence="CLAIM"))
    source, sid = add_started(service, root)
    path = Path(service.snapshot()["sessions"][0]["exchange_path"])
    with monkeypatch.context() as patch:
        patch.setattr(service, "_note_path", lambda sid: (_ for _ in ()).throw(OSError("disk")))
        append(source, "assistant", "CLAIM")
        eventually(lambda: len(service.snapshot()["alerts"]) == 1)
        assert service.snapshot()["sessions"][0]["exchange_error"] == "OSError"
        assert service.snapshot()["sessions"][0]["analysis_state"] == "alert"
    service.command(dict(action="remove", id=sid))
    assert path.is_file()


def test_note_quotes_cannot_escape_markdown_fence(setup):
    root, create = setup
    service = create()
    value = service.command(dict(action="add", platform="claude", native_id="session-a", mission="```\n<script>bad</script>"))
    text = service.note_content(value["sessions"][0]["id"])
    assert "````text\n```\n<script>bad</script>\n````" in text


def test_failed_mission_persistence_leaves_current_note_unchanged(setup, monkeypatch):
    root, create = setup
    service = create()
    _, sid = add_started(service, root)
    path = Path(service.snapshot()["sessions"][0]["exchange_path"])
    before = path.read_text(encoding="utf-8")
    monkeypatch.setattr(service, "_persist", lambda: (_ for _ in ()).throw(OSError("disk")))
    with pytest.raises(OSError):
        service.command(dict(action="set_mission", id=sid, mission="NEW MISSION MUST NOT SAVE"))
    assert path.read_text(encoding="utf-8") == before


def test_malformed_normalized_records_are_ignored():
    assert normalize("codex", {"type": "response_item", "payload": "wrong"}) is None
    assert normalize("claude", {"type": "assistant", "message": {"content": [{"type": "text", "text": 42}]}}) == ("assistant", "")


def test_invalid_persistent_state_fails_closed(setup):
    root, create = setup
    service = create()
    service.state_path.write_text("[]")
    restored = create()
    assert restored.snapshot()["load_error"] == "ValueError"
    assert not restored.snapshot()["running"]
    assert not restored.snapshot()["allow_cloud"]
    assert restored.snapshot()["sessions"] == []


def test_source_reset_discards_inflight_judge_result(setup):
    root, create = setup
    started, release, finished = threading.Event(), threading.Event(), threading.Event()
    def judge(model, messages):
        started.set()
        release.wait(2)
        finished.set()
        return dict(alert=True, severity="warning", reason="stale", evidence="FIRST")
    service = create(judge)
    source, _ = add_started(service, root)
    append(source, "assistant", "FIRST")
    assert started.wait(2)
    source.write_text("{}\n")
    eventually(lambda: service.snapshot()["sessions"][0]["state"] == "source_reset")
    release.set()
    assert finished.wait(2)
    time.sleep(.05)
    assert service.snapshot()["alerts"] == []


def test_idle_service_does_not_open_sources_or_call_judge(setup, monkeypatch):
    root, create = setup
    calls = []
    service = create(lambda *a: calls.append(a))
    import TOOLS.AGENT_WORKFLOW.scripts.agent_supervisor_service as module
    monkeypatch.setattr(module, "resolve_jsonl_source", lambda *a, **k: pytest.fail("unassigned source opened"))
    service.command({"action": "start"})
    time.sleep(.08)
    assert service.snapshot()["running"]
    assert not service.snapshot()["sessions"] and calls == []


def test_unchanged_source_is_not_reopened_or_rejudged(setup, monkeypatch):
    root, create = setup
    calls = []
    service = create(lambda model, messages: calls.append(messages) or {"alert": False})
    source, sid = add_started(service, root)
    append(source, "assistant", "Une reponse nouvelle")
    eventually(lambda: len(calls) == 1)
    time.sleep(.08)
    assert len(calls) == 1
    watcher = service.sessions[sid]["watcher"]
    monkeypatch.setattr(watcher, "poll", lambda: pytest.fail("unchanged file was reread"))
    time.sleep(.08)
    assert len(calls) == 1
