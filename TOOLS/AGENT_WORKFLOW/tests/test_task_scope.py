"""Garde-fous du périmètre de tâche et de la métrique de dérive (T429 R8/R10)."""
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import task_scope


def test_matches_handles_glob_and_plain_prefixes():
    assert task_scope.matches("TOOLS/AGENT_SUPERVISOR/scripts/x.py", ["TOOLS/AGENT_SUPERVISOR/**"])
    assert task_scope.matches("TOOLS/AGENT_SUPERVISOR", ["TOOLS/AGENT_SUPERVISOR/**"])
    assert not task_scope.matches("TOOLS/AGENT_WORKFLOW/scripts/x.py", ["TOOLS/AGENT_SUPERVISOR/**"])
    assert task_scope.matches("AGENTS.md", ["AGENTS.md"])
    assert not task_scope.matches("AGENTS.md.bak", ["AGENTS.md"])


def test_classify_separates_product_process_and_outside():
    product = ["TOOLS/AGENT_SUPERVISOR/**"]
    forbidden = ["CODE/**"]
    process = ["AGENTS.md"]

    assert task_scope.classify("TOOLS/AGENT_SUPERVISOR/ui/index.html", product, forbidden, process) == "produit"
    assert task_scope.classify("AGENTS.md", product, forbidden, process) == "processus"
    assert task_scope.classify("TOOLS/AGENT_WORKFLOW/scripts/x.py", product, forbidden, process) == "hors"
    assert task_scope.classify("CODE/PRG_00.st", product, forbidden, process) == "hors"


def test_forbidden_wins_over_product():
    assert task_scope.classify("CODE/x.st", ["CODE/**"], ["CODE/**"], []) == "hors"


def test_contract_of_t429_declares_a_product_scope():
    contract = task_scope.contract_for_task("T429")
    assert contract is not None
    product, forbidden = task_scope._scope_lists(contract)
    assert any("TOOLS/AGENT_SUPERVISOR" in entry for entry in product)
    assert any(entry.startswith("CODE/") for entry in forbidden)


def test_scope_for_session_resolves_the_task_and_its_process_scope():
    scope = task_scope.scope_for_session("session-inexistante")
    # Sans Superviseur joignable : pas de tache, mais le perimetre processus global reste.
    assert scope["task_id"] is None
    assert "AGENTS.md" in scope["processus"]
    assert scope["produit"] == []


def test_transcript_paths_keeps_only_write_tools(tmp_path):
    transcript = tmp_path / "session.jsonl"
    rows = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read", "input": {"file_path": "CODE/lu.st"}}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": "TOOLS/X.py"}}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Write", "input": {"file_path": "DOC/Y.md"}}]}},
    ]
    transcript.write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in rows) + "\n", encoding="utf-8")

    paths = task_scope.transcript_paths(transcript)

    assert "CODE/lu.st" not in paths
    assert len(paths) == 2


def test_transcript_paths_respects_the_window(tmp_path):
    transcript = tmp_path / "session.jsonl"
    rows = [{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": f"F{index}.py"}}]}}
            for index in range(10)]
    transcript.write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in rows) + "\n", encoding="utf-8")

    paths = task_scope.transcript_paths(transcript, window=3)

    assert len(paths) == 3
    assert paths[-1].endswith("F9.py")


def test_metric_counts_product_process_and_outside(tmp_path, monkeypatch):
    monkeypatch.setattr(task_scope, "scope_for_session", lambda _session: {
        "session_id": "s", "task_id": "T000", "contract": "",
        "produit": ["TOOLS/AGENT_SUPERVISOR/**"], "interdits": ["CODE/**"],
        "processus": ["AGENTS.md"],
    })
    transcript = tmp_path / "session.jsonl"
    rows = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": "TOOLS/AGENT_SUPERVISOR/a.py"}}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": "AGENTS.md"}}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": "TOOLS/OTHER/b.py"}}]}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": "TOOLS/OTHER/c.py"}}]}},
    ]
    transcript.write_text("\n".join(json.dumps(row, ensure_ascii=False) for row in rows) + "\n", encoding="utf-8")

    result = task_scope.metric("s", transcript, window=10)

    assert result["counts"] == {"produit": 1, "processus": 1, "derogation": 0, "hors": 2}
    assert result["ratio_hors"] == 0.5
    assert result["total"] == 4


def test_derogation_covers_a_prefix(tmp_path, monkeypatch):
    monkeypatch.setattr(task_scope, "DEROG_DIR", tmp_path)
    task_scope.write_derogation("s", "TOOLS/AGENT_WORKFLOW/**", "accord")
    assert task_scope.is_derogated("s", "TOOLS/AGENT_WORKFLOW/scripts/x.py")
    assert not task_scope.is_derogated("s", "TOOLS/AUTRE/y.py")


def test_derogation_is_recorded_and_recognized(tmp_path, monkeypatch):
    monkeypatch.setattr(task_scope, "DEROG_DIR", tmp_path)

    task_scope.write_derogation("s", "TOOLS/OTHER/b.py", "accord exploitant")

    assert task_scope.is_derogated("s", "TOOLS/OTHER/b.py")
    assert not task_scope.is_derogated("s", "TOOLS/OTHER/c.py")
    assert task_scope.read_derogations("s")[0]["motif"] == "accord exploitant"
