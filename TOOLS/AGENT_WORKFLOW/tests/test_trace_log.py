"""Garde-fous du journal interne : emission, append-only, detection d incoherences."""
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import trace_log


def _use_tmp(tmp_path, monkeypatch):
    monkeypatch.setattr(trace_log, "TRACE_DIR", tmp_path)
    monkeypatch.setattr(trace_log, "TRACE_PATH", tmp_path / "trace.jsonl")


def test_emit_appends_jsonl_and_never_prints(tmp_path, monkeypatch, capsys):
    _use_tmp(tmp_path, monkeypatch)

    trace_log.emit("workflow", session="s1", etat="ACTIF", voie="Tâche")
    trace_log.emit("titre", session="s1", target="TITRE", verified=True)

    lines = (tmp_path / "trace.jsonl").read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 2
    first = json.loads(lines[0])
    assert first["kind"] == "workflow" and first["session"] == "s1"
    assert first["etat"] == "ACTIF"
    assert capsys.readouterr().out == "", "le journal interne ne doit rien afficher"


def test_query_filters_by_kind_and_session(tmp_path, monkeypatch):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("workflow", session="s1", etat="ACTIF")
    trace_log.emit("titre", session="s1", target="T")
    trace_log.emit("titre", session="s2", target="T")

    assert len(trace_log.query(kind="titre")) == 2
    assert len(trace_log.query(kind="titre", session="s1")) == 1
    assert len(trace_log.query(session="s2")) == 1


def test_detects_workflow_declared_but_not_entered(tmp_path, monkeypatch):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("workflow", session="s1", etat="ACTIF", voie="Tâche")
    trace_log.emit("attestation", session="s1", conform=False, banner=False, footer=False)

    found = trace_log.inconsistencies(session="s1")
    codes = [item["code"] for item in found]

    assert "workflow_declare_non_entree" in codes


def test_detects_unverified_title_write(tmp_path, monkeypatch):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("titre", session="s1", target="T", verified=False, readback="AUTRE")

    codes = [item["code"] for item in trace_log.inconsistencies(session="s1")]

    assert "titre_non_verifie" in codes


def test_detects_write_outside_scope_without_derogation(tmp_path, monkeypatch):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("ecriture", session="s1", path="CODE/x.st", kind_verdict="hors", derogation=False)
    trace_log.emit("ecriture", session="s1", path="TOOLS/Y.py", kind_verdict="hors", derogation=True)

    found = [item for item in trace_log.inconsistencies(session="s1") if item["code"] == "ecriture_hors_perimetre"]

    assert len(found) == 1
    assert "CODE/x.st" in json.dumps(found, ensure_ascii=False)


def test_detects_silent_supervisor(tmp_path, monkeypatch):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("workflow", session="s1", etat="ACTIF")
    trace_log.emit("superviseur", session="s1", etat="source_error")

    codes = [item["code"] for item in trace_log.inconsistencies(session="s1")]

    assert "superviseur_muet" in codes


def test_report_lists_counts_and_inconsistencies(tmp_path, monkeypatch, capsys):
    _use_tmp(tmp_path, monkeypatch)
    trace_log.emit("workflow", session="s1", etat="ACTIF")
    trace_log.emit("attestation", session="s1", conform=False)

    out = trace_log.report(session="s1")

    assert "Evenements :" in out
    assert "workflow=1" in out
    assert "Incoherences :" in out
    assert "workflow_declare_non_entree" in out
