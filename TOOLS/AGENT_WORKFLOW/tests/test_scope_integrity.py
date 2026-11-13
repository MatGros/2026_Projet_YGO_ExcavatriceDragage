"""Integrite du perimetre et du journal (consensus DeepSeek + GLM, 2026-11-13)."""
import json
import sys
import time
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import check_task_contract
import task_scope
import trace_log


def test_absolute_deny_blocks_the_machine_code_regardless_of_the_contract():
    assert task_scope.is_absolute_denied("CODE/PRG_00.st")
    assert task_scope.is_absolute_denied("CODE_XML/CODE_Bundle.xml")
    assert task_scope.is_absolute_denied(".claude/settings.json")
    assert task_scope.is_absolute_denied("TOOLS/AGENT_WORKFLOW/skills/x/SKILL.md")
    assert not task_scope.is_absolute_denied("TOOLS/AGENT_SUPERVISOR/scripts/x.py")


def test_contract_lint_refuses_an_allowed_that_touches_the_global_deny():
    problems = check_task_contract.check_absolute_deny(
        {"contract": {"scope": {"allowed": ["CODE/**", "TOOLS/AGENT_SUPERVISOR/**"]}}})
    assert problems and "CODE" in problems[0]


def test_contract_lint_accepts_a_clean_scope():
    assert check_task_contract.check_absolute_deny(
        {"contract": {"scope": {"allowed": ["TOOLS/AGENT_SUPERVISOR/**"]}}}) == []


def test_pinned_scope_is_written_by_the_notary_and_read_back(monkeypatch, tmp_path):
    monkeypatch.setattr(task_scope, "SCOPE_DIR", tmp_path / "scopes")
    monkeypatch.setattr(task_scope, "scope_for_task", lambda _task: {
        "allowed": ["TOOLS/AGENT_SUPERVISOR/**"], "forbidden": ["CODE/**"],
        "digest": "DIGEST", "contract": "c.yaml"})

    task_scope.write_pinned("s1", "T429")
    pinned = task_scope.pinned_scope("s1")

    assert pinned["digest"] == "DIGEST"
    assert pinned["task_id"] == "T429"


def test_verify_scope_detects_a_contract_modified_during_the_session(monkeypatch, tmp_path):
    monkeypatch.setattr(task_scope, "SCOPE_DIR", tmp_path / "scopes")
    monkeypatch.setattr(task_scope, "scope_for_task", lambda _task: {
        "allowed": ["CODE/**"], "forbidden": [], "digest": "NOUVEAU", "contract": "c.yaml"})
    task_scope.write_pinned("s1", "T429")
    monkeypatch.setattr(task_scope, "scope_for_task", lambda _task: {
        "allowed": ["CODE/**"], "forbidden": [], "digest": "ANCIEN", "contract": "c.yaml"})

    check = task_scope.verify_scope("s1")

    assert check["ok"] is False
    assert check["pinned_digest"] == "NOUVEAU"
    assert check["current_digest"] == "ANCIEN"


def test_derogation_expires(monkeypatch, tmp_path):
    monkeypatch.setattr(task_scope, "DEROG_DIR", tmp_path)
    task_scope.write_derogation("s1", "TOOLS/X.py", "motif", ttl_days=1)
    assert task_scope.is_derogated("s1", "TOOLS/X.py")

    entries = task_scope.read_derogations("s1")
    entries[0]["expires_at"] = time.time() - 10
    task_scope.derogations_path("s1").write_text(json.dumps(entries), encoding="utf-8")

    assert not task_scope.is_derogated("s1", "TOOLS/X.py")


def test_trace_chain_detects_a_tampered_line(monkeypatch, tmp_path):
    monkeypatch.setattr(trace_log, "TRACE_DIR", tmp_path)
    monkeypatch.setattr(trace_log, "TRACE_PATH", tmp_path / "trace.jsonl")

    trace_log.emit("workflow", session="s1", etat="ACTIF")
    trace_log.emit("titre", session="s1", target="T", verified=True)
    assert trace_log.verify_chain()["intact"] is True

    lines = (tmp_path / "trace.jsonl").read_text(encoding="utf-8").splitlines()
    entry = json.loads(lines[0])
    entry["etat"] = "OFF"  # falsification
    lines[0] = json.dumps(entry, ensure_ascii=False)
    (tmp_path / "trace.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")

    verdict = trace_log.verify_chain()
    assert verdict["intact"] is False
    assert verdict["break"]["reason"] == "empreinte invalide"


def test_trace_chain_detects_a_truncation(monkeypatch, tmp_path):
    monkeypatch.setattr(trace_log, "TRACE_DIR", tmp_path)
    monkeypatch.setattr(trace_log, "TRACE_PATH", tmp_path / "trace.jsonl")

    for index in range(3):
        trace_log.emit("titre", session="s1", target=f"T{index}")
    lines = (tmp_path / "trace.jsonl").read_text(encoding="utf-8").splitlines()
    (tmp_path / "trace.jsonl").write_text("\n".join(lines[1:]) + "\n", encoding="utf-8")

    verdict = trace_log.verify_chain()
    assert verdict["intact"] is False
    assert verdict["break"]["reason"] == "sequence rompue"
