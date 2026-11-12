import json
import os
from pathlib import Path
import threading
from urllib.request import urlopen

from TOOLS.AGENT_SUPERVISOR.scripts.connect_session import connect, session_id_for, validate_local_base_url
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server


def test_cli_session_id_uses_current_runtime_and_rejects_mismatch(monkeypatch):
    monkeypatch.setenv("DSH_SESSION_ID", "session-12345678-1234-1234-1234-123456789abc")
    assert session_id_for("dsh") == os.environ["DSH_SESSION_ID"]
    try:
        session_id_for("dsh", "session-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    except ValueError as exc:
        assert "ne correspond pas" in str(exc)
    else:
        raise AssertionError("mismatch must be rejected")


def test_connect_registers_one_exact_local_source_and_reports_existing(tmp_path):
    session_id = "a1234567-b89c-40d1-a234-567890abcdef"
    root = tmp_path / "claude"
    root.mkdir()
    (root / f"{session_id}.jsonl").write_text("{}\n", encoding="utf-8")
    server = create_server(port=0, state_path=tmp_path / "state.json")
    server.supervision.roots = {"claude": [root], "codex": [], "agy": [], "dsh": []}
    server.supervision.command({"action": "start"})
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        attached = connect("claude", session_id, "T999-CC01", "T999 — test", "Mission de test", base)
        assert attached["status"] == "attached"
        assert attached["native_id"] == session_id
        assert Path(attached["source"]).name == f"{session_id}.jsonl"
        repeated = connect("claude", session_id, "T999-CC02", "T999 — test", "Mission de test", base)
        assert repeated["status"] == "already_assigned"
        with urlopen(base + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assert sum(s["native_id"] == session_id for s in snapshot["sessions"]) == 1
    finally:
        server.supervision.close()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


def test_connect_refuses_a_second_session_for_the_same_formal_task(tmp_path):
    sid_a = "a1234567-b89c-40d1-a234-567890abcdef"
    sid_b = "b1234567-b89c-40d1-a234-567890abcdef"
    root = tmp_path / "claude"
    root.mkdir()
    for sid in (sid_a, sid_b):
        (root / f"{sid}.jsonl").write_text("{}\n", encoding="utf-8")
    server = create_server(port=0, state_path=tmp_path / "state.json")
    server.supervision.roots = {"claude": [root], "codex": [], "agy": [], "dsh": []}
    server.supervision.command({"action": "start"})
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        connect("claude", sid_a, "T217-CC01", "T217 — audit", "Mission A", base)
        try:
            connect("claude", sid_b, "T217-CC02", "T217 — audit", "Mission B", base)
        except ValueError as exc:
            assert "déjà suivie" in str(exc)
            assert "--reassign" in str(exc)
        else:
            raise AssertionError("a formal task cannot be monitored by two sessions")
        # AC-F1.7 Handover : avec reassign=True, la session existante est reassignee sans doublon
        reassigned = connect("claude", sid_b, "T217-CC02", "T217 — audit", "Mission B", base, reassign=True)
        assert reassigned["status"] == "reassigned"
        assert reassigned["native_id"] == sid_b
        assert reassigned["previous_alias"] == "T217-CC01"
        with urlopen(base + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assert len(snapshot["sessions"]) == 1
        assert snapshot["sessions"][0]["native_id"] == sid_b
    finally:
        server.supervision.close()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


def test_connect_provisional_t000_and_auto_title_lookup():
    from TOOLS.AGENT_SUPERVISOR.scripts.connect_session import validate_alias, lookup_task_title

    # 1. Alias pur et strict
    assert validate_alias("T423-AGY01") == "T423-AGY01"
    assert validate_alias("T000-CC01") == "T000-CC01"
    assert validate_alias("T428-1-CDX01") == "T428-1-CDX01"

    # Rejet des alias avec texte libre invente
    try:
        validate_alias("T423-AGY01 Texte Invente")
    except ValueError as exc:
        assert "format strict" in str(exc)
    else:
        raise AssertionError("alias with free text must be rejected")

    # 2. Lookup automatique du titre officiel dans TASKS.yaml
    title = lookup_task_title("T423")
    assert title is not None
    assert "IHM Pack 1" in title

    from TOOLS.AGENT_SUPERVISOR.scripts.connect_session import is_no_task, task_reference

    assert is_no_task("SANS TÂCHE FORMELLE")
    assert is_no_task("Sans tache formelle")
    assert not is_no_task("T217 — sujet")
    assert task_reference("T217 — sujet") == "T217"
    assert task_reference("Tâche / sujet : T217 — sujet", anywhere=True) == "T217"
    try:
        validate_local_base_url("https://example.com")
    except ValueError as exc:
        assert "loopback" in str(exc)
    else:
        raise AssertionError("remote endpoint must be rejected")
