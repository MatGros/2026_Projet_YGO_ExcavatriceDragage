"""Garde-fous : le journal d'experience par poste (demande exploitant 2026-11-13)."""
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import experience_log


def test_write_and_read_per_post(tmp_path, monkeypatch):
    monkeypatch.setattr(experience_log, "EXPERIENCE_DIR", tmp_path)
    monkeypatch.setattr(experience_log, "log_path", lambda _s: tmp_path / "s1.jsonl")
    monkeypatch.setattr(experience_log, "all_log", lambda: tmp_path / "all.jsonl")

    experience_log.write("superviseur", "constat", "user: coupe -> agent: continue quand meme",
                          "l attente n etait pas tranchee", "bloquer la cloture", "s1", ["e42"])
    experience_log.write("CC01", "auto-retrospective", "j ai repondu sans preuve",
                          "regle 9 non appliquee", "sortie brute obligatoire", "s1")

    entries = experience_log.read("s1")
    assert len(entries) == 2
    assert entries[0]["poste"] == "superviseur"
    assert entries[0]["refs"] == ["e42"]
    assert entries[1]["type"] == "auto-retrospective"

    assert len(experience_log.read("s1", poste="CC01")) == 1


def test_an_empty_pattern_is_refused(tmp_path, monkeypatch):
    monkeypatch.setattr(experience_log, "EXPERIENCE_DIR", tmp_path)
    monkeypatch.setattr(experience_log, "log_path", lambda _s: tmp_path / "s2.jsonl")
    monkeypatch.setattr(experience_log, "all_log", lambda: tmp_path / "all.jsonl")

    try:
        experience_log.write("superviseur", "constat", "")
    except ValueError as exc:
        assert "motif" in str(exc)
    else:
        raise AssertionError("une experience sans motif ne doit pas etre consignee")


def test_review_groups_by_post(tmp_path, monkeypatch):
    monkeypatch.setattr(experience_log, "EXPERIENCE_DIR", tmp_path)
    monkeypatch.setattr(experience_log, "log_path", lambda _s: tmp_path / "s3.jsonl")
    monkeypatch.setattr(experience_log, "all_log", lambda: tmp_path / "all.jsonl")

    experience_log.write("juge", "constat", "pattern A", "hypothese A", "action A", "s3")
    experience_log.write("juge", "constat", "pattern B", "hypothese B", "action B", "s3")

    report = experience_log.review()
    assert "juge=2" in report
    assert "pattern A" in report and "hypothese A" in report
