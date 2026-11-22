"""Cas utilisateur : sessions simultanées, lenteur et ambiguïté d'affectation."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import session_status_snapshot as snapshot


def configure(monkeypatch, sessions, stale=False):
    status = snapshot.status
    monkeypatch.setattr(status, "fetch_supervisor_summary", lambda: ({"sessions": sessions}, None))
    monkeypatch.setattr(status, "resolve_summary", lambda sid, data, error: (data, error, stale))
    monkeypatch.setattr(status, "get_workflow_badge", lambda sid: "TEST")
    monkeypatch.setattr(status, "get_git_badge", lambda: "main")


def test_concurrent_cli_sessions_keep_their_own_identity(monkeypatch):
    sessions = [dict(native_id="one", alias="T432-CDX02", display_title="COMMANDES", state="active"),
                dict(native_id="two", alias="T427-CC02", display_title="WORKFLOW", state="paused")]
    configure(monkeypatch, sessions)
    for cli in ("codex", "claude", "agy"):
        data = snapshot.collect("one", cli)
        assert data["title"] == "COMMANDES"
        assert data["alias"] == "T432-CDX02"
        assert data["supervisor"]["state"] == "active"
        assert "\x1b" not in data["supervisor"]["text"]


def test_delayed_supervisor_never_hides_stale_data(monkeypatch):
    configure(monkeypatch, [dict(native_id="one", alias="T432-CDX02", state="active")], stale=True)
    assert snapshot.collect("one", "codex")["supervisor"]["stale"] is True


def test_duplicate_native_id_refuses_arbitrary_assignment(monkeypatch):
    configure(monkeypatch, [dict(native_id="one"), dict(native_id="one")])
    with pytest.raises(ValueError, match="ambigu"):
        snapshot.collect("one", "codex")
