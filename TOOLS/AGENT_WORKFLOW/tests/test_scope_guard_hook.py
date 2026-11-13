"""Garde-fous du hook de périmètre (T429 R9)."""
import io
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import hook_scope_guard
import task_scope


import pytest
import trace_log


@pytest.fixture(autouse=True)
def _trace_isolated(tmp_path, monkeypatch):
    """Les tests n'ecrivent jamais dans le journal interne de production."""
    monkeypatch.setattr(trace_log, "TRACE_DIR", tmp_path / "trace")
    monkeypatch.setattr(trace_log, "TRACE_PATH", tmp_path / "trace" / "trace.jsonl")

SCOPE = {
    "session_id": "s", "task_id": "T429", "contract": "c.yaml",
    "produit": ["TOOLS/AGENT_SUPERVISOR/**"], "interdits": ["CODE/**"],
    "processus": ["AGENTS.md", "DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR"],
}


def _payload(path):
    return json.dumps({"tool_name": "Edit", "session_id": "s", "tool_input": {"file_path": path}})


def test_product_path_is_allowed(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    verdict = hook_scope_guard.evaluate("s", "TOOLS/AGENT_SUPERVISOR/ui/index.html")
    assert verdict["decision"] == "allow"


def test_process_path_is_allowed(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    verdict = hook_scope_guard.evaluate("s", "AGENTS.md")
    assert verdict["decision"] == "allow"


def test_outside_path_is_blocked_with_a_reason(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)
    verdict = hook_scope_guard.evaluate("s", "TOOLS/AGENT_WORKFLOW/scripts/x.py")
    assert verdict["decision"] == "block"
    assert "TOOLS/AGENT_WORKFLOW/scripts/x.py" in verdict["reason"]


def test_forbidden_path_is_never_allowed(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)
    assert hook_scope_guard.evaluate("s", "CODE/PRG_00.st")["decision"] == "block"


def test_derogation_allows_the_write(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: True)
    assert hook_scope_guard.evaluate("s", "TOOLS/AGENT_WORKFLOW/scripts/x.py")["decision"] == "allow"


def test_no_declared_scope_means_allow(monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: dict(SCOPE, produit=[]))
    assert hook_scope_guard.evaluate("s", "n'importe/quoi.py")["decision"] == "allow"


def test_hook_reports_but_does_not_block_in_report_mode(monkeypatch, capsys):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)
    monkeypatch.setenv("TASK_SCOPE_GUARD", "report")
    monkeypatch.setattr(sys, "stdin", io.StringIO(_payload("TOOLS/AGENT_WORKFLOW/scripts/x.py")))

    assert hook_scope_guard.main() == 0
    assert "garde de perimetre" in capsys.readouterr().err


def test_hook_blocks_in_block_mode(monkeypatch, capsys):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)
    monkeypatch.setenv("TASK_SCOPE_GUARD", "block")
    monkeypatch.setattr(sys, "stdin", io.StringIO(_payload("TOOLS/AGENT_WORKFLOW/scripts/x.py")))

    assert hook_scope_guard.main() == 2
    assert "hors perimetre" in capsys.readouterr().err


def test_hook_ignores_read_only_tools(monkeypatch):
    monkeypatch.setattr(sys, "stdin", io.StringIO(json.dumps({
        "tool_name": "Read", "session_id": "s", "tool_input": {"file_path": "CODE/x.st"}})))
    assert hook_scope_guard.main() == 0


def test_absolute_deny_is_checked_before_any_derogation(monkeypatch):
    """La deny-list globale ne s'ouvre PAS par une derogation ecrite par l'agent."""
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: True)  # meme derogue

    verdict = hook_scope_guard.evaluate("s", "CODE/PRG_00.st")

    assert verdict["decision"] == "block"
    assert verdict["kind"] == "interdit"


def test_absolute_deny_ignores_the_contract(monkeypatch):
    """Meme si le contrat autorise, le chemin interdit reste refuse."""
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: dict(SCOPE, produit=["CODE/**"]))
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)

    assert hook_scope_guard.evaluate("s", "CODE/PRG_00.st")["decision"] == "block"


def test_default_mode_is_block(monkeypatch):
    monkeypatch.delenv("TASK_SCOPE_GUARD", raising=False)
    assert hook_scope_guard.mode() == "block"
    monkeypatch.setenv("TASK_SCOPE_GUARD", "report")
    assert hook_scope_guard.mode() == "report"


def test_end_to_end_deny_returns_exit_code_two(monkeypatch, capsys):
    """Test de BOUT EN BOUT : le hook rend 2 (refus reel) sur un chemin protege."""
    import io

    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "effective_scope", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "pinned_scope", lambda _s: {})
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: True)
    monkeypatch.setattr(sys, "stdin", io.StringIO(json.dumps({
        "tool_name": "Edit", "session_id": "s",
        "tool_input": {"file_path": "C:/repo/CODE/PRG_00.st"}})))

    assert hook_scope_guard.main() == 2
    assert "INTERDITE" in capsys.readouterr().err


def test_end_to_end_protected_path_allowed_when_pinned(monkeypatch, capsys):
    """Un contrat qui declarait deja le chemin (epingle) reste autorise."""
    import io

    monkeypatch.setattr(task_scope, "scope_for_session", lambda _s: SCOPE)
    monkeypatch.setattr(task_scope, "effective_scope", lambda _s: dict(SCOPE, produit=["CODE/**"]))
    monkeypatch.setattr(task_scope, "pinned_scope",
                        lambda _s: {"allowed": ["CODE/**"], "digest": "d"})
    monkeypatch.setattr(task_scope, "is_derogated", lambda _s, _p: False)
    monkeypatch.setattr(sys, "stdin", io.StringIO(json.dumps({
        "tool_name": "Edit", "session_id": "s",
        "tool_input": {"file_path": "C:/repo/CODE/PRG_00.st"}})))

    assert hook_scope_guard.main() == 0
