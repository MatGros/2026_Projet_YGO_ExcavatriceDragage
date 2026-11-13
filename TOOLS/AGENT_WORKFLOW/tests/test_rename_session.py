"""
Tests unitaires déterministes pour rename_session.py
Couvre tous les invariants arrêtés avec le Challenger :
- Validation des repères TXXX (ancrage strict)
- Rejet des caractères interdits et espaces/tirets initiaux
- Normalisation Unicode NFC
- Idempotence
- Format WAL INTENT/COMMIT dans le journal d'audit
"""

import sys
import os
import json
import pytest
from pathlib import Path

# Ajouter le dossier scripts au PYTHONPATH
REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import rename_session

def test_sanitize_and_validate_nominal():
    task_id, alias, desc = rename_session.sanitize_and_validate("T123-AGY01 Mon Titre De Test")
    assert task_id == "T123-AGY01"
    assert alias == "T123-AGY01 Mon Titre De Test"
    assert desc == "Mon Titre De Test"

def test_sanitize_and_validate_accented():
    task_id, alias, desc = rename_session.sanitize_and_validate("T429-AGY01 Fiabilisation Mémoire Données")
    assert task_id == "T429-AGY01"
    assert "Mémoire" in alias
    assert desc == "Fiabilisation Mémoire Données"

def test_sanitize_reject_empty():
    with pytest.raises(ValueError, match="vide"):
        rename_session.sanitize_and_validate("")

def test_sanitize_reject_leading_dash_or_space():
    with pytest.raises(ValueError, match="tiret ou un espace"):
        rename_session.sanitize_and_validate("-T123-AGY01 Titre")

    with pytest.raises(ValueError, match="tiret ou un espace"):
        rename_session.sanitize_and_validate(" T123-AGY01 Titre")

def test_sanitize_reject_invalid_task_id():
    # TXXX non ancré ou invalide
    with pytest.raises(ValueError, match="syntaxe canonique"):
        rename_session.sanitize_and_validate("T123xyz Titre")

    with pytest.raises(ValueError, match="syntaxe canonique"):
        rename_session.sanitize_and_validate("MonTitre SansTaskID")

def test_sanitize_rejects_short_actor_prefix_without_rewriting():
    # AG02 must not silently become AG02-AGY01.
    with pytest.raises(ValueError, match="T000-AGY02"):
        rename_session.sanitize_and_validate("T000-AG02 GEMINI 4 HYDRO CHALLENGE SIMU M3")

    task_id, alias, description = rename_session.sanitize_and_validate("T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3")
    assert task_id == "T000-AGY02"
    assert alias == "T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3"
    assert description == "GEMINI 4 HYDRO CHALLENGE SIMU M3"

def test_resolve_session_task_folder_uses_exact_readme_binding(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    tasks_dir.mkdir(parents=True)
    (tasks_dir / "T000_ORCHESTRATION_MULTI_TACHES").mkdir()
    (tasks_dir / "T000_CHALLENGE_M3_SIMULATION").mkdir()
    matching_dir = tasks_dir / "T000_CHALLENGE_M3_SIMULATION_AGY02"
    matching_dir.mkdir()
    (matching_dir / "README.md").write_text(
        "# T000-AGY02 — Challenge simulation M3\n\nSession `T000-AGY02`.\n",
        encoding="utf-8",
    )
    unrelated_dir = tasks_dir / "T000_OTHER_AGY02"
    unrelated_dir.mkdir()
    (unrelated_dir / "README.md").write_text("Session `T000-CC02`.\n", encoding="utf-8")
    monkeypatch.setattr(rename_session, "REPO_ROOT", tmp_path)

    assert rename_session.resolve_session_task_folder("T000-AGY02") == "T000_CHALLENGE_M3_SIMULATION_AGY02"

def test_resolve_session_task_folder_does_not_guess_or_pick_duplicate(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    tasks_dir.mkdir(parents=True)
    for name in ("T000_CHALLENGE_M3_SIMULATION_AGY02", "T000_OTHER_AGY02"):
        task_dir = tasks_dir / name
        task_dir.mkdir()
        (task_dir / "README.md").write_text("Session `T000-AGY02`.\n", encoding="utf-8")
    monkeypatch.setattr(rename_session, "REPO_ROOT", tmp_path)

    assert rename_session.resolve_session_task_folder("T000-AGY02") is None
    assert rename_session.resolve_session_task_folder("T000-CC02") is None

def test_sanitize_reject_forbidden_chars():
    # Caractères d'échappement ou symboles interdits
    with pytest.raises(ValueError, match="non autorisés"):
        rename_session.sanitize_and_validate("T123-AGY01 Titre; rm -rf /")

    with pytest.raises(ValueError, match="non autorisés"):
        rename_session.sanitize_and_validate("T123-AGY01 Titre\033]0;pwned\007")

def test_wal_audit_logging(tmp_path, monkeypatch):
    test_audit_file = tmp_path / "AUDIT_TEST.log"
    monkeypatch.setattr(rename_session, "AUDIT_LOG_FILE", test_audit_file)

    session_id = "test-uuid-1234"
    rename_session.log_audit("INTENT", session_id, "OLD_ALIAS", "NEW_ALIAS", 0)
    rename_session.log_audit("COMMIT", session_id, "OLD_ALIAS", "NEW_ALIAS", 0)

    lines = test_audit_file.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 2
    assert "[INTENT] [test-uuid-1234] 'OLD_ALIAS' -> 'NEW_ALIAS'" in lines[0]
    assert "[COMMIT] [test-uuid-1234] 'OLD_ALIAS' -> 'NEW_ALIAS'" in lines[1]

def test_notify_supervisor_nominal(monkeypatch):
    class FakeResponse:
        def __init__(self, data, status=200):
            self.data = data
            self.status = status
        def read(self):
            return self.data
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass

    calls = []
    def fake_urlopen(req, timeout=1.0):
        calls.append(req)
        if req.get_method() == "GET":
            if req.full_url.endswith("/summary"):
                return FakeResponse(b'{"sessions":[{"id":"supervisor-id","platform":"claude","native_id":"sess-123"}]}', 200)
            return FakeResponse(b'{"token": "test-token-xyz"}', 200)
        elif req.get_method() == "POST":
            return FakeResponse(b'{"status": "updated"}', 200)

    import urllib.request
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    res = rename_session.notify_supervisor("sess-123", "T429-AGY01")
    assert res is True
    assert len(calls) == 3
    assert calls[0].get_method() == "GET"
    assert calls[1].get_method() == "GET"
    assert calls[2].get_method() == "POST"
    assert calls[2].headers.get("X-supervision-token") == "test-token-xyz" or calls[2].headers.get("X-Supervision-Token") == "test-token-xyz"

def test_notify_supervisor_does_not_attach_an_unlinked_session(monkeypatch):
    import urllib.error
    import urllib.request

    calls = []
    class FakeResponse:
        status = 200
        def __init__(self, body=b'{"token":"test-token"}'):
            self.body = body
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def read(self):
            return self.body

    def fake_urlopen(req, timeout=1.0):
        calls.append(req)
        if req.get_method() == "GET":
            if req.full_url.endswith("/summary"):
                return FakeResponse(b'{"sessions":[]}')
            return FakeResponse()
        raise urllib.error.HTTPError(req.full_url, 400, "Affectation inconnue", {}, None)

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    with pytest.raises(rename_session.SupervisorSessionNotLinked, match="connect-session-supervisor"):
        rename_session.notify_supervisor("native-id", "T000-CDX02", platform="codex")
    assert len(calls) == 1
    assert not [call for call in calls if call.data]

def test_main_fails_closed_when_current_session_id_is_missing(monkeypatch, capsys):
    monkeypatch.setattr(rename_session.sys, "argv", ["rename_session.py", "T000-CDX02", "SESSION TEST"])

    class FakeStatusline:
        @staticmethod
        def get_ancestor_cli_process():
            return 123, "codex.exe"
        @staticmethod
        def find_current_conversation_id(*_args):
            return None
        @staticmethod
        def get_session_info(*_args):
            raise AssertionError("Ne doit pas lire une session sans ID")

    monkeypatch.setitem(sys.modules, "session_statusline", FakeStatusline)

    with pytest.raises(SystemExit) as result:
        rename_session.main()

    assert result.value.code == 3
    assert "ID natif non résolu" in capsys.readouterr().err

def test_notify_supervisor_keeps_chat_name_and_explicit_folder_together(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    task_dir = tasks_dir / "T000_CHALLENGE_M3_SIMULATION_AGY02"
    task_dir.mkdir(parents=True)
    (task_dir / "README.md").write_text("Session `T000-AGY02`.\n", encoding="utf-8")
    monkeypatch.setattr(rename_session, "REPO_ROOT", tmp_path)

    class FakeResponse:
        status = 200
        def __init__(self, data=b'{"schema_version":1,"running":true,"sessions":[]}'):
            self.data = data
        def read(self):
            return self.data
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass

    calls = []
    def fake_urlopen(req, timeout=1.0):
        calls.append(req)
        if req.get_method() == "GET":
            if req.full_url.endswith("/summary"):
                return FakeResponse(b'{"sessions":[{"id":"supervisor-id","platform":"agy","native_id":"conversation-id"}]}')
            return FakeResponse(b'{"token":"test-token"}')
        return FakeResponse()

    import urllib.request
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    result = rename_session.notify_supervisor(
        "conversation-id",
        "T000-AGY02",
        mission_text="GEMINI 4 HYDRO CHALLENGE SIMU M3",
        platform="agy",
    )

    assert result is True
    assert len(calls) == 4
    alias_payload = json.loads(calls[2].data.decode("utf-8"))
    assert alias_payload["id"] == "supervisor-id"
    mission_payload = json.loads(calls[3].data.decode("utf-8"))
    assert mission_payload["action"] == "set_mission"
    assert mission_payload["id"] == "supervisor-id"
    assert mission_payload["mission"] == (
        "T000-AGY02 GEMINI 4 HYDRO CHALLENGE SIMU M3 — "
        "Dossier: T000_CHALLENGE_M3_SIMULATION_AGY02"
    )

@pytest.mark.parametrize(("platform", "actor"), [("claude", "CC"), ("codex", "CDX")])
def test_rename_uses_real_supervisor_assignment_id_for_alias_and_mission(tmp_path, platform, actor):
    """Reproduit connect puis rename contre le vrai serveur local isolé."""
    import threading
    from urllib.request import urlopen

    from TOOLS.AGENT_SUPERVISOR.scripts.connect_session import connect
    from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_server import create_server

    native_id = "a1234567-b89c-40d1-a234-567890abcdef"
    source_root = tmp_path / platform
    source_root.mkdir()
    source_name = f"{native_id}.jsonl" if platform == "claude" else f"rollout-2026-11-13T00-00-00-{native_id}.jsonl"
    (source_root / source_name).write_text("{}\n", encoding="utf-8")

    server = create_server(port=0, state_path=tmp_path / "supervisor-state.json")
    server.supervision.roots = {"claude": [], "codex": [], "agy": [], "dsh": []}
    server.supervision.roots[platform] = [source_root]
    server.supervision.command({"action": "start"})
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base_url = f"http://127.0.0.1:{server.server_port}"
    try:
        alias = f"T999-{actor}01"
        linked = connect(platform, native_id, alias, "T999 — test", "Mission initiale", base_url)
        assert linked["status"] == "attached"

        assert rename_session.notify_supervisor(
            native_id,
            alias,
            mission_text="Hydro M3",
            platform=platform,
            base_url=base_url,
        ) is True

        with urlopen(base_url + "/api/supervision") as response:
            snapshot = json.loads(response.read().decode("utf-8"))
        assignment = next(item for item in snapshot["sessions"] if item["native_id"] == native_id)
        assert assignment["id"] == linked["assignment_id"]
        assert assignment["alias"] == alias
        assert assignment["mission"] == f"{alias} Hydro M3"
    finally:
        server.supervision.close()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)

def test_notify_supervisor_offline(monkeypatch):
    import urllib.request
    def fake_urlopen_fail(req, timeout=1.0):
        raise ConnectionRefusedError("Offline")
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen_fail)

    res = rename_session.notify_supervisor("sess-123", "T429-AGY01")
    assert res is False

