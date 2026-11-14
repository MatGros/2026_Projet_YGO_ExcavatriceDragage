"""Tests déterministes de workflow_state.py (T427 I1c). Aucun hook, aucun modèle."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "workflow_state.py"
spec = importlib.util.spec_from_file_location("workflow_state", SCRIPT)
ws = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ws)

KEY_A = "session-aaaa-1111"
KEY_B = "session-bbbb-2222"


@pytest.fixture(autouse=True)
def isolated_state(tmp_path, monkeypatch):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    # Superviseur simulé : jamais le service réel (tests déterministes).
    # Journal de test isolé : jamais le journal réel.
    monkeypatch.setenv("WORKFLOW_TRACE_DIR", str(tmp_path / "trace"))
    monkeypatch.setattr(ws, "SOURCE", "cli")
    monkeypatch.setattr(ws, "supervisor_alias", lambda key: {KEY_A: "T427-CC02", KEY_B: "T000-CC10"}.get(key))
    monkeypatch.setattr(ws, "task_title", lambda task_id: f"Titre de {task_id}")
    return tmp_path


def test_identite_tache_affichee(capsys):
    ws.main(["enter", "--session", KEY_A])
    out = capsys.readouterr().out
    assert "🎯 Tâche : T427 — Titre de T427" in out
    assert "🆔 Session : T427-CC02" in out
    assert "🟢 T427 · WORKFLOW ACTIF" in out


def test_hors_catalogue_T000_dit_aucune_tache(capsys):
    ws.main(["enter", "--session", KEY_B])
    out = capsys.readouterr().out
    assert "🎯 Tâche : aucune · hors catalogue" in out
    assert "🆔 Session : T000-CC10" in out


def test_superviseur_injoignable_le_dit(monkeypatch, capsys):
    monkeypatch.setattr(ws, "supervisor_alias", lambda key: None)
    ws.main(["enter", "--session", "session-cccc-3333"])
    out = capsys.readouterr().out
    assert "non rattachée au Superviseur" in out
    assert "🎯 Tâche : aucune (non rattachée)" in out


def test_enter_puis_status_ACTIF(capsys):
    assert ws.main(["enter", "fresh", "--session", KEY_A]) == 0
    assert "WORKFLOW ACTIF" in capsys.readouterr().out
    ws.main(["status", "--session", KEY_A])
    assert "WORKFLOW ACTIF" in capsys.readouterr().out


def test_off_puis_status_OFF(capsys):
    ws.main(["enter", "--session", KEY_A])
    ws.main(["off", "--session", KEY_A])
    capsys.readouterr()
    ws.main(["status", "--session", KEY_A])
    assert "WORKFLOW OFF" in capsys.readouterr().out


def test_retour_apres_off_reste_OFF(capsys):
    """Cas exploitant : quitter puis revenir sans nouvelle commande = toujours OFF."""
    ws.main(["enter", "--session", KEY_A])
    ws.main(["off", "--session", KEY_A])
    capsys.readouterr()
    ws.main(["status", "--session", KEY_A])
    out = capsys.readouterr().out
    assert "WORKFLOW OFF" in out
    assert "WORKFLOW ACTIF" not in out


def test_sans_argument_enter_vaut_fresh(capsys):
    ws.main(["enter", "--session", KEY_A])
    assert "Mode : fresh" in capsys.readouterr().out


def test_sessions_isolees(capsys):
    ws.main(["enter", "--session", KEY_A])
    ws.main(["enter", "--session", KEY_B])
    ws.main(["off", "--session", KEY_B])
    capsys.readouterr()
    ws.main(["status", "--session", KEY_A])
    assert "WORKFLOW ACTIF" in capsys.readouterr().out


def test_sans_cle_indetermine_et_aucune_ecriture(isolated_state, capsys):
    assert ws.main(["enter"]) == 0
    assert "INDÉTERMINÉ" in capsys.readouterr().out
    folder = isolated_state / "ExcavatriceDragage" / "workflow"
    assert not folder.exists() or list(folder.glob("*.json")) == []


def test_cle_depuis_environnement(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "resume"])
    out = capsys.readouterr().out
    assert "WORKFLOW ACTIF" in out
    assert "Mode : resume" in out


def test_json_corrompu_est_indetermine(isolated_state, capsys):
    folder = isolated_state / "ExcavatriceDragage" / "workflow"
    folder.mkdir(parents=True)
    (folder / f"{KEY_A}.json").write_text("{pas du json", encoding="utf-8")
    ws.main(["status", "--session", KEY_A])
    assert "INDÉTERMINÉ" in capsys.readouterr().out


def test_session_id_incoherent_refuse(isolated_state, capsys):
    folder = isolated_state / "ExcavatriceDragage" / "workflow"
    folder.mkdir(parents=True)
    (folder / f"{KEY_A}.json").write_text(
        json.dumps({"session_id": KEY_B, "etat": "ACTIF", "seq": 1}), encoding="utf-8")
    ws.main(["status", "--session", KEY_A])
    assert "INDÉTERMINÉ" in capsys.readouterr().out


def test_mode_inconnu_refuse(capsys):
    assert ws.main(["enter", "banane", "--session", KEY_A]) == 2


def test_seq_croit_a_chaque_commande(isolated_state):
    ws.main(["enter", "--session", KEY_A])
    ws.main(["off", "--session", KEY_A])
    data = json.loads((isolated_state / "ExcavatriceDragage" / "workflow" / f"{KEY_A}.json").read_text(encoding="utf-8"))
    assert data["seq"] == 2 and data["etat"] == "OFF"


def test_aucun_fichier_dans_le_depot(tmp_path):
    """Le script ne doit jamais écrire dans le dépôt (routage T279)."""
    root = ws.ROOT
    before = {p for p in root.rglob("*.json") if ".git" not in p.parts and "worktrees" not in p.parts}
    ws.main(["enter", "--session", KEY_A])
    after = {p for p in root.rglob("*.json") if ".git" not in p.parts and "worktrees" not in p.parts}
    assert before == after


def _journal(tmp_path):
    import json
    path = tmp_path / "trace" / "trace.jsonl"
    if not path.is_file():
        return []
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def test_source_slash_enregistree(tmp_path, capsys, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["cmd", "resume", "--source", "slash"])
    evts = [e for e in _journal(tmp_path) if e.get("kind") == "workflow"]
    assert evts and all(e.get("source") == "slash" for e in evts)


def test_choix_inconnu_journalise(tmp_path, capsys, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    assert ws.main(["cmd", "4"]) == 2
    evts = _journal(tmp_path)
    assert any(e.get("action") == "choix_inconnu" and e.get("texte") == "4" for e in evts)


def test_menu_affiche_journalise(tmp_path, capsys):
    ws.main(["enter", "--session", KEY_A])
    evts = _journal(tmp_path)
    assert any(e.get("action") == "menu_affiche" for e in evts)


def test_journal_reel_non_touche(tmp_path, capsys):
    import trace_log
    reel = trace_log.TRACE_PATH
    avant = reel.stat().st_mtime_ns if reel.is_file() else None
    ws.main(["enter", "--session", KEY_A])
    apres = reel.stat().st_mtime_ns if reel.is_file() else None
    assert avant == apres
