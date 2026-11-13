"""Garde-fous : la sequence d'ecriture du titre du terminal est verifiee et consignee."""
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import terminal_title


import pytest
import trace_log


@pytest.fixture(autouse=True)
def _trace_isolated(tmp_path, monkeypatch):
    """Les tests n'ecrivent jamais dans le journal interne de production."""
    monkeypatch.setattr(trace_log, "TRACE_DIR", tmp_path / "trace")
    monkeypatch.setattr(trace_log, "TRACE_PATH", tmp_path / "trace" / "trace.jsonl")


def test_write_title_reports_a_verified_write(monkeypatch):
    """Ecrire -> relire -> verifier : le resultat est un constat, pas une impression."""
    target = "T429-MMX01 ESSAI"
    monkeypatch.setattr(terminal_title, "_console_title", lambda: target)

    result = terminal_title.write_title(target, attempts=3, delay=0)

    assert result["verified"] is True
    assert result["readback"] == target
    assert result["attempts"] == 1
    assert result["target"] == target


def test_write_title_retries_then_reports_the_failure(monkeypatch):
    """Si un concurrent ecrase le titre, la sequence reessaie puis DECLARE l'echec."""
    monkeypatch.setattr(terminal_title, "_console_title", lambda: "AUTRE TITRE")

    result = terminal_title.write_title("CIBLE", attempts=3, delay=0)

    assert result["verified"] is False
    assert result["attempts"] == 3
    assert result["readback"] == "AUTRE TITRE"


def test_ledger_records_the_verification(tmp_path, monkeypatch):
    monkeypatch.setattr(terminal_title, "TITLE_DIR", tmp_path)

    terminal_title.record("session-1", {"target": "T", "verified": True, "attempts": 2})
    stored = terminal_title.read("session-1")

    assert stored["target"] == "T"
    assert stored["verified"] is True
    assert stored["session_id"] == "session-1"
    assert (tmp_path / "session-1.json").is_file()


def test_ledger_of_unknown_session_is_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(terminal_title, "TITLE_DIR", tmp_path)
    assert terminal_title.read("inconnu") == {}


def test_empty_title_is_not_written(monkeypatch):
    result = terminal_title.write_title("")
    assert result["verified"] is False
    assert result["attempts"] == 0


def test_internal_log_is_append_only_and_never_printed(tmp_path, monkeypatch, capsys):
    """Le journal interne sert aux tests et au debug ; il ne s'affiche pas."""
    monkeypatch.setattr(terminal_title, "TITLE_DIR", tmp_path)
    monkeypatch.setattr(terminal_title, "LOG_PATH", tmp_path / "title-writes.jsonl")
    monkeypatch.setattr(terminal_title, "_console_title", lambda: "TITRE")

    terminal_title.refresh("s1", "TITRE")
    terminal_title.refresh("s1", "TITRE")
    terminal_title.refresh("s2", "TITRE")

    entries = terminal_title.recent(limit=10)
    assert len(entries) == 3
    assert [entry["session_id"] for entry in entries] == ["s1", "s1", "s2"]
    assert all(entry["verified"] is True for entry in entries)
    assert all("duration_ms" in entry for entry in entries)
    assert capsys.readouterr().out == "", "le journal interne ne doit rien afficher"


def test_internal_log_records_the_failure(tmp_path, monkeypatch):
    monkeypatch.setattr(terminal_title, "TITLE_DIR", tmp_path)
    monkeypatch.setattr(terminal_title, "LOG_PATH", tmp_path / "title-writes.jsonl")
    monkeypatch.setattr(terminal_title, "_console_title", lambda: "ECRASE")

    result = terminal_title.refresh("s1", "CIBLE")

    assert result["verified"] is False
    entries = terminal_title.recent(limit=5, session_id="s1")
    assert entries and entries[-1]["verified"] is False
    assert entries[-1]["attempts"] == terminal_title.ATTEMPTS


def test_internal_log_can_be_filtered_by_session(tmp_path, monkeypatch):
    monkeypatch.setattr(terminal_title, "TITLE_DIR", tmp_path)
    monkeypatch.setattr(terminal_title, "LOG_PATH", tmp_path / "title-writes.jsonl")
    monkeypatch.setattr(terminal_title, "_console_title", lambda: "T")

    terminal_title.refresh("s1", "T")
    terminal_title.refresh("s2", "T")

    assert len(terminal_title.recent(session_id="s1")) == 1
    assert len(terminal_title.recent(session_id="s2")) == 1
