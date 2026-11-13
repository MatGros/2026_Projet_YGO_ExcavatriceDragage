"""Garde-fous statusline : workflow attesté par le harnais + repère git compact (13/11/2026)."""
import json
import os
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import session_statusline
import statusline_indicators
import workflow_state


def _write_state(folder: Path, key: str, **fields):
    folder.mkdir(parents=True, exist_ok=True)
    payload = {"session_id": key, "etat": "ACTIF", "mode": "fresh", "seq": 1}
    payload.update(fields)
    (folder / f"{key}.json").write_text(json.dumps(payload), encoding="utf-8")


def _write_attestation(folder: Path, key: str, **fields):
    payload = {"session_id": key, "turns": 4, "conform_turns": 4, "conform": True,
               "banner": True, "footer": True, "task": "T429", "etape": "ÉTUDE",
               "voie": "Orchestrateur"}
    payload.update(fields)
    (folder / f"{key}.attest.json").write_text(json.dumps(payload), encoding="utf-8")


def test_workflow_badge_shows_attested_step_and_route(monkeypatch, tmp_path):
    """Le badge affiche ce que le hook Stop (harnais) a constate."""
    key = "session-id-1234"
    _write_state(tmp_path, key, etat="ACTIF", etape="ÉTUDE", voie="Orchestrateur")
    _write_attestation(tmp_path, key)
    monkeypatch.setattr(statusline_indicators, "WORKFLOW_STATE_DIR", tmp_path)

    badge = session_statusline.get_workflow_badge(key)

    assert "🛣️ ●" in badge
    assert "ÉTUDE" in badge
    assert "Orchestrateur" in badge


def test_workflow_badge_is_plain_when_workflow_is_off(monkeypatch, tmp_path):
    """Demande exploitant 2026-11-13 : la couleur s'allume UNIQUEMENT quand le workflow est
    ACTIF et ATTESTE. Hors ACTIF, texte plain — pas de gris, pas de vert."""
    key = "session-id-5678"
    _write_state(tmp_path, key, etat="OFF")
    monkeypatch.setattr(statusline_indicators, "WORKFLOW_STATE_DIR", tmp_path)

    badge = session_statusline.get_workflow_badge(key)

    assert "🛣️ ○" in badge
    assert "\033[" not in badge


def test_workflow_badge_never_guesses_a_state(monkeypatch, tmp_path):
    monkeypatch.setattr(statusline_indicators, "WORKFLOW_STATE_DIR", tmp_path)

    badge = session_statusline.get_workflow_badge("session-id-9999")

    assert "non démarré" in badge
    assert "ACTIF" not in badge


def test_workflow_state_is_a_binary_switch(monkeypatch, tmp_path):
    """Machine a deux etats : entree -> ACTIF, sortie -> OFF. L'attestation n'est pas
    l'interrupteur : elle constate, elle ne commande rien."""
    key = "session-idem-01"
    _write_state(tmp_path, key, etat="ACTIF", etape="ÉTUDE", voie="libre")
    monkeypatch.setattr(statusline_indicators, "WORKFLOW_STATE_DIR", tmp_path)

    assert "🛣️ ●" in statusline_indicators.get_workflow_badge(key)

    _write_state(tmp_path, key, etat="OFF")
    assert "🛣️ ○" in statusline_indicators.get_workflow_badge(key)


def test_attestation_is_kept_but_does_not_drive_the_badge(monkeypatch, tmp_path):
    """Le hook constate la conformite (fichier .attest.json) sans commander l'etat affiche."""
    key = "session-idem-02"
    _write_state(tmp_path, key, etat="ACTIF", etape="ÉTUDE")
    _write_attestation(tmp_path, key, conform=False, conform_turns=3, turns=4)
    monkeypatch.setattr(statusline_indicators, "WORKFLOW_STATE_DIR", tmp_path)

    badge = statusline_indicators.get_workflow_badge(key)

    assert "🛣️ ●" in badge
    attestation = json.loads((tmp_path / f"{key}.attest.json").read_text(encoding="utf-8"))
    assert attestation["conform"] is False
    assert attestation["conform_turns"] == 3


def test_git_badge_reports_branch_upstream_dirty_and_worktree(monkeypatch):
    monkeypatch.setattr(statusline_indicators, "_git_facts", lambda: {
        "root": "C:/repo", "branch": "main", "upstream": "origin/main",
        "ahead": "2", "behind": "1", "dirty": 3, "worktree": "carte-flux",
    })

    badge = session_statusline.get_git_badge()

    assert "main" in badge and "↑2" in badge and "↓1" in badge
    assert "3 modifiés" in badge
    assert "WT:carte-flux" in badge


def test_git_badge_says_hors_depot_outside_a_repository(monkeypatch):
    monkeypatch.setattr(statusline_indicators, "_git_facts", lambda: {"root": ""})

    assert "hors dépôt" in session_statusline.get_git_badge()


def test_workflow_state_etape_command_writes_the_step(monkeypatch, tmp_path):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    key = "session-etape-01"

    assert workflow_state.main(["enter", "fresh", "--session", key]) == 0
    assert workflow_state.main(["etape", "RÉALISATION", "--session", key]) == 0

    state = json.loads((tmp_path / "ExcavatriceDragage" / "workflow" / f"{key}.json").read_text(encoding="utf-8"))
    assert state["etape"] == "RÉALISATION"
    assert state["etat"] == "ACTIF"


def test_workflow_state_etape_rejects_an_unknown_step(monkeypatch, tmp_path):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    key = "session-etape-02"
    workflow_state.main(["enter", "fresh", "--session", key])

    assert workflow_state.main(["etape", "N_IMPORTE_QUOI", "--session", key]) == 2


def test_attestation_hook_writes_conformity_counters(monkeypatch, tmp_path):
    """Le hook Stop constate le bandeau + le pied du dernier tour et tient un compteur."""
    import hook_workflow_attest

    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    key = "session-attest-01"
    workflow_state.main(["enter", "fresh", "--session", key])
    monkeypatch.setattr(hook_workflow_attest, "STATE_DIR", tmp_path / "ExcavatriceDragage" / "workflow")

    transcript = tmp_path / "session.jsonl"
    record = {"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "text", "text": "━━ 🟦 🔎 T429 · ÉTUDE · Orchestrateur ━━━\nContenu.\n➡️ Choix : a"}]}}
    transcript.write_text(json.dumps(record, ensure_ascii=False) + "\n", encoding="utf-8")

    import io
    payload = json.dumps({"session_id": key, "transcript_path": str(transcript)})
    monkeypatch.setattr(sys, "stdin", io.StringIO(payload))
    assert hook_workflow_attest.main() == 0

    attestation = json.loads((tmp_path / "ExcavatriceDragage" / "workflow" / f"{key}.attest.json").read_text(encoding="utf-8"))
    assert attestation["conform"] is True
    assert attestation["turns"] == 1 and attestation["conform_turns"] == 1
    assert attestation["etape"] == "ÉTUDE"


def test_attestation_hook_marks_a_turn_without_banner_as_non_conforme(monkeypatch, tmp_path):
    import io

    import hook_workflow_attest

    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    key = "session-attest-02"
    workflow_state.main(["enter", "fresh", "--session", key])
    monkeypatch.setattr(hook_workflow_attest, "STATE_DIR", tmp_path / "ExcavatriceDragage" / "workflow")

    transcript = tmp_path / "session.jsonl"
    record = {"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "text", "text": "Réponse sans bandeau ni pied."}]}}
    transcript.write_text(json.dumps(record, ensure_ascii=False) + "\n", encoding="utf-8")

    payload = json.dumps({"session_id": key, "transcript_path": str(transcript)})
    monkeypatch.setattr(sys, "stdin", io.StringIO(payload))
    assert hook_workflow_attest.main() == 0

    attestation = json.loads((tmp_path / "ExcavatriceDragage" / "workflow" / f"{key}.attest.json").read_text(encoding="utf-8"))
    assert attestation["conform"] is False
    assert attestation["banner"] is False
