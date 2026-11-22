"""Routage inter-CLI et refus des mauvaises identités avant toute écriture."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import workflow_role as role


@pytest.fixture(autouse=True)
def clean_identity(monkeypatch):
    for name in ("CLAUDE_CODE_SESSION_ID", "CODEX_THREAD_ID", "CODEX_SESSION_ID",
                 "GEMINI_SESSION_ID", "AGY_SESSION_ID", "DSH_SESSION_ID"):
        monkeypatch.delenv(name, raising=False)


def test_codex_duplicate_env_names_are_one_identity(monkeypatch):
    monkeypatch.setenv("CODEX_THREAD_ID", "session-codex-001")
    monkeypatch.setenv("CODEX_SESSION_ID", "session-codex-001")
    assert role.native_session() == "session-codex-001"


def test_inherited_other_cli_identity_refused_before_state_write(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "session-claude-001")
    monkeypatch.setenv("CODEX_THREAD_ID", "session-codex-001")
    monkeypatch.setattr(role.workflow_state, "main", lambda args: pytest.fail("Unexpected state write"))
    assert role.main(["coordinator"]) == 2


@pytest.mark.parametrize("entry,route", [("orchestrator", "1"), ("coordinator", "2")])
def test_explicit_native_session_selects_expected_role(monkeypatch, entry, route):
    calls = []
    monkeypatch.setattr(role.workflow_state, "main", lambda args: calls.append(args) or 0)
    assert role.main([entry, "--session", "session-explicit-001"]) == 0
    assert calls == [["voie", route, "--session", "session-explicit-001"]]


def test_no_identity_refuses_without_guessing(monkeypatch):
    monkeypatch.setattr(role.workflow_state, "main", lambda args: pytest.fail("Unexpected state write"))
    assert role.main(["coordinator"]) == 2


def test_real_transition_preserves_explicit_session(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    monkeypatch.setenv("WORKFLOW_TRACE_DIR", str(tmp_path / "trace"))
    monkeypatch.setenv("CODEX_THREAD_ID", "isolated-codex-session-001")
    monkeypatch.setattr(role.workflow_state, "supervisor_alias", lambda key: None)
    monkeypatch.setattr(role.workflow_state, "criticality_for_session", lambda key: "C2")
    assert role.main(["coordinator"]) == 0
    state = role.workflow_state.read_state("isolated-codex-session-001")
    assert state["etat"] == "ACTIF"
    assert state["voie"] == "Tâche"
    assert "Coordinateur de tâche" in capsys.readouterr().out
