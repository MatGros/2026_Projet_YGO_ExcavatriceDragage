import json
import os
from pathlib import Path
import threading
from urllib.request import urlopen
import pytest

from TOOLS.AGENT_SUPERVISOR.scripts import connect_session
from TOOLS.AGENT_SUPERVISOR.scripts.connect_session import (
    connect, lookup_task_title, resolve_task_title, session_id_for, validate_local_base_url,
)
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
        attached = connect("claude", session_id, "T417-C-AGY02", "T417-C", "Mission de test", base)
        assert attached["status"] == "attached"
        assert attached["task_id"] == "T417-C"
        assert attached["agent_id"] == "AGY02"
        assert attached["task_title"] == lookup_task_title("T417-C")
        assert attached["native_id"] == session_id
        assert Path(attached["source"]).name == f"{session_id}.jsonl"
        repeated = connect("claude", session_id, "T417-C-AGY02", "T417-C", "Mission de test", base)
        assert repeated["status"] == "already_assigned"
        try:
            connect("claude", session_id, "T417-C-CC02", "T417-C", "Mission de test", base)
        except ValueError as exc:
            assert "déjà reliée" in str(exc)
        else:
            raise AssertionError("a linked session must not silently accept a different alias")

        existing_session = server.supervision.sessions[attached["assignment_id"]]
        existing_session["initial_mission"] = (
            "T417-C-AGY02 Ancien titre\nTâche / sujet : T417-C Ancien titre\nMission de test"
        )
        server.supervision._persist()
        with pytest.raises(ValueError, match="tâche/titre différents"):
            connect("claude", session_id, "T417-C-AGY02", "T417-C", "Mission de test", base)
        with urlopen(base + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assert sum(s["native_id"] == session_id for s in snapshot["sessions"]) == 1
        with urlopen(base + "/api/supervision/summary") as response:
            summary = json.loads(response.read().decode("utf-8"))
        assert summary["sessions"][0]["display_title"] == f"T417-C-AGY02 {lookup_task_title('T417-C')}"
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
        connect("claude", sid_a, "T423-CC01", "T423", "Mission A", base)
        try:
            connect("claude", sid_b, "T423-CC02", "T423", "Mission B", base)
        except ValueError as exc:
            assert "déjà suivie" in str(exc)
            assert "--reassign" in str(exc)
        else:
            raise AssertionError("a formal task cannot be monitored by two sessions")
        # AC-F1.7 Handover : avec reassign=True, la session existante est reassignee sans doublon
        reassigned = connect("claude", sid_b, "T423-CC02", "T423", "Mission B", base, reassign=True)
        assert reassigned["status"] == "reassigned"
        assert reassigned["native_id"] == sid_b
        assert reassigned["previous_alias"] == "T423-CC01"
        with urlopen(base + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assert len(snapshot["sessions"]) == 1
        assert snapshot["sessions"][0]["native_id"] == sid_b
    finally:
        server.supervision.close()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


def test_connect_rejects_unknown_task_incoherent_alias_and_wrong_title(monkeypatch):
    def unexpected_api(*_args, **_kwargs):
        raise AssertionError("la validation doit refuser avant tout appel API")

    monkeypatch.setattr(connect_session, "api_json", unexpected_api)

    with pytest.raises(ValueError, match="ne correspond pas à --task"):
        connect("claude", "native-id", "T424-CC01", "T423", "Mission")

    with pytest.raises(ValueError, match="absente de TASKS.yaml"):
        connect("claude", "native-id", "T999-CC01", "T999", "Mission")

    official_title = lookup_task_title("T423")
    with pytest.raises(ValueError, match="différent du titre officiel"):
        connect("claude", "native-id", "T423-CC01", "T423", "Mission", task_title="Titre inventé")

    with pytest.raises(ValueError, match="Titre explicite requis"):
        connect("claude", "native-id", "T000-CDX02", "T000", "Exploration")

    assert official_title


def test_connect_no_formal_task_requires_confirmed_t000_id_agent_and_title(tmp_path):
    native_id = "c1234567-b89c-40d1-a234-567890abcdef"
    claude_root = tmp_path / "claude"
    claude_root.mkdir()
    (claude_root / f"{native_id}.jsonl").write_text("{}\n", encoding="utf-8")

    server = create_server(port=0, state_path=tmp_path / "state.json")
    server.supervision.roots = {"claude": [claude_root], "codex": [], "agy": [], "dsh": []}
    server.supervision.command({"action": "start"})
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        with pytest.raises(ValueError, match="confirmation explicite requise"):
            connect("claude", native_id, "T000-CC03", "SANS TACHE FORMELLE", "Exploration",
                    base, task_title="Session naming")

        result = connect("claude", native_id, "T000-CC03", "SANS TACHE FORMELLE", "Exploration",
                         base, task_title="Session naming", confirm_without_task=True)
        assert result["status"] == "attached"
        assert result["task_id"] == "T000"
        assert result["agent_id"] == "CC03"
        assert result["task_title"] == "Session naming"
        assert result["mission_structure_loaded"] is False

        with urlopen(base + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assignment = next(item for item in snapshot["sessions"] if item["native_id"] == native_id)
        assert assignment["mission"].startswith("T000-CC03 Session naming\nTâche / sujet : T000 Session naming\n")
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
    assert task_reference("T417-C — sous-tâche") == "T417-C"
    assert task_reference("Tâche / sujet : T417-C — titre", anywhere=True) == "T417-C"
    assert task_reference("T417-C-AGY02 titre", anywhere=True) == "T417-C"
    try:
        validate_local_base_url("https://example.com")
    except ValueError as exc:
        assert "loopback" in str(exc)
    else:
        raise AssertionError("remote endpoint must be rejected")


def test_task_title_resolution_refuses_missing_or_duplicate_titles():
    assert resolve_task_title([{"id": "T423", "titre": "IHM Pack 1"}], "T423") == "IHM Pack 1"
    assert resolve_task_title([{"id": "T423", "titre": ""}], "T423") is None
    with pytest.raises(ValueError, match="ID de tâche ambigu"):
        resolve_task_title(
            [{"id": "T423", "titre": "IHM Pack 1"}, {"id": "T423", "titre": "Autre titre"}],
            "T423",
        )
