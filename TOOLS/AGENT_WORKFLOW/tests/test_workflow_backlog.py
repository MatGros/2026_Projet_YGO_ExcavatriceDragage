"""Tests standardisés du backlog T427 §12 (un test par identifiant B<n>).

Convention :
- chaque point du backlog a au moins un test, nommé test_B<n>_<sujet> ;
- un point NON réalisé a son test marqué xfail(strict=True) : il passera au vert le jour où
  le point est fait (xfail strict = le test doit alors être retiré de xfail) ;
- aucun test n'écrit dans le journal réel (WORKFLOW_TRACE_DIR isolé).
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
ROOT = Path(__file__).resolve().parents[3]


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ws = _load("workflow_state")
KEY_A = "backlog-session-aaaa"
KEY_B = "backlog-session-bbbb"


@pytest.fixture(autouse=True)
def isolated(tmp_path, monkeypatch):
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    monkeypatch.setenv("WORKFLOW_TRACE_DIR", str(tmp_path / "trace"))
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    monkeypatch.setattr(ws, "supervisor_alias", lambda key: None)
    monkeypatch.setattr(ws, "SOURCE", "cli")
    return tmp_path


def _state(tmp_path: Path, key: str) -> dict:
    return json.loads((tmp_path / "ExcavatriceDragage" / "workflow" / f"{key}.json").read_text(encoding="utf-8"))


# ── 🔴 Priorité 1 : fiabilité du journal et de l'état ─────────────────────────

@pytest.mark.xfail(strict=True, reason="B2 CONFIRMÉ : 20 écritures simultanées -> 13 entrées, seq dupliqués")
def test_B2_ecritures_concurrentes_seq_uniques(tmp_path):
    """B2 — deux émetteurs simultanés ne produisent pas le même seq."""
    import threading
    trace = _load("trace_log")
    threads = [threading.Thread(target=trace.emit, args=("workflow",), kwargs={"n": i}) for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    lines = (tmp_path / "trace" / "trace.jsonl").read_text(encoding="utf-8").splitlines()
    seqs = [json.loads(l)["seq"] for l in lines if l.strip()]
    assert len(seqs) == len(set(seqs)) == 20


@pytest.mark.xfail(strict=True, reason="B3 : --session détourne une autre session (à corriger)")
def test_B3_session_detournee(tmp_path):
    """B3 — enter --session KEY_B depuis KEY_A ne doit pas modifier KEY_B."""
    ws.main(["enter", "--session", KEY_B])
    before = _state(tmp_path, KEY_B)
    ws.main(["enter", "--session", KEY_B], )  # appel depuis la session KEY_A simulée :
    import os
    os.environ["CLAUDE_CODE_SESSION_ID"] = KEY_A
    try:
        ws.main(["off", "--session", KEY_B])
    finally:
        os.environ.pop("CLAUDE_CODE_SESSION_ID", None)
    assert _state(tmp_path, KEY_B)["etat"] == before["etat"]


def test_B4_echec_ecriture_laisse_trace(tmp_path):
    """B4 — une écriture ratée est consignée dans echecs.log, rien n'est silencieux."""
    trace = _load("trace_log")
    (tmp_path / "trace").mkdir()
    (tmp_path / "trace" / "trace.jsonl").mkdir()  # le journal est un dossier : écriture impossible
    trace.emit("workflow", n=1)
    assert (tmp_path / "trace" / "echecs.log").is_file()


# ── 🟠 Priorité 2 : sécurité de la commande ──────────────────────────────────

def test_B5_argument_injecte_rien_n_est_execute(capsys, tmp_path):
    """B5 — un argument contenant ; ou | n'exécute rien et est refusé."""
    assert ws.main(["cmd", "1;calc"]) == 2
    assert not (tmp_path / "ExcavatriceDragage" / "workflow").exists() or not list(
        (tmp_path / "ExcavatriceDragage" / "workflow").glob("*.json"))


@pytest.mark.xfail(strict=True, reason="B6 : nom d'utilisateur codé en dur dans trace_log.py")
def test_B6_pas_de_nom_utilisateur_en_dur():
    text = (SCRIPTS / "trace_log.py").read_bytes().decode("utf-8")
    assert "ZEDVICTUS" not in text


@pytest.mark.xfail(strict=True, reason="B7 : origine non authentifiée, à documenter dans le journal")
def test_B7_limite_origine_documentee():
    text = (SCRIPTS / "trace_log.py").read_bytes().decode("utf-8")
    assert "non authentifi" in text.lower()


# ── 🟡 Priorité 3 : lisibilité du bloc ───────────────────────────────────────

def test_B8a_emoji_suivi_d_un_espace(monkeypatch, capsys):
    """B8a — aucun emoji collé au texte qui suit (ligne par ligne)."""
    import re
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    out = capsys.readouterr().out
    assert not re.search(r"^\S*[🌀-🫿☀-➿]\S", out, re.M)


@pytest.mark.xfail(strict=True, reason="B8b : aération du bloc, séparation des sections (à réaliser)")
def test_B8b_aeration_sections(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    out = capsys.readouterr().out
    assert out.count("\n\n") >= 3


@pytest.mark.xfail(strict=True, reason="B9 : identifiant et titre séparés, champ Objectif (à réaliser)")
def test_B9_champ_objectif(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    assert "Objectif" in capsys.readouterr().out


@pytest.mark.xfail(strict=True, reason="B10 : « Mode : fresh » à reformuler (à réaliser)")
def test_B10_mode_lisible(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    assert "Mode : fresh" not in capsys.readouterr().out


@pytest.mark.xfail(strict=True, reason="B11 : « Étape : non renseignée » à remplacer (à réaliser)")
def test_B11_etape_lisible(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    assert "non renseignée" not in capsys.readouterr().out


@pytest.mark.xfail(strict=True, reason="B12 : légende des symboles absente ou répétée (à réaliser)")
def test_B12_legende_une_seule_fois(monkeypatch, capsys):
    """La légende des symboles doit exister, et apparaître une seule fois."""
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    out = capsys.readouterr().out
    assert "Légende" in out
    assert out.count("Légende") == 1


@pytest.mark.xfail(strict=True, reason="B13 : consigne « Agent : » visible par l'utilisateur (à retirer)")
def test_B13_consigne_agent_non_affichee(monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    assert "Agent :" not in capsys.readouterr().out


# ── 🟢 Priorité 4 : démarrage et lecture ─────────────────────────────────────

@pytest.mark.xfail(strict=True, reason="B14 : haut du bloc = tâche active, dernier point, validation en attente")
def test_B14_haut_du_bloc_utile(monkeypatch, capsys):
    """Le haut du bloc doit dire où on en est, pas un décompte global."""
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", KEY_A)
    ws.main(["enter", "--session", KEY_A])
    assert "Validation en attente" in capsys.readouterr().out


@pytest.mark.xfail(strict=True, reason="B15 : lecture minimale avant le menu, à challenger par agents")
def test_B15_lecture_minimale_avant_menu():
    script = (SCRIPTS / "workflow_state.py").read_bytes().decode("utf-8").lower()
    assert "lecture minimale" in script


@pytest.mark.xfail(strict=True, reason="B16 : après choix Orchestrateur, lecture approfondie avec grille")
def test_B16_lecture_approfondie_orchestrateur():
    role = (ROOT / "TOOLS/AGENT_WORKFLOW/skills/orchestrator/ROLE.md").read_bytes().decode("utf-8")
    assert "lecture approfondie" in role.lower()


@pytest.mark.xfail(strict=True, reason="B17 : accueil de la voie Tâche (à valider, à réaliser)")
def test_B17_accueil_tache_demande_tache_et_resultat():
    text = (ROOT / "TOOLS/AGENT_WORKFLOW/skills/task-planner/SKILL.md").read_bytes().decode("utf-8")
    assert "résultat attendu" in text.lower()


# ── Cohérence des textes (commande, skill, AGENTS.md) ────────────────────────

def test_coherence_commande_et_script():
    for nom, voie in (("workflow-project-orchestrator", "cmd 1"), ("workflow-project-coordinator", "cmd 2")):
        cmd = (ROOT / ".claude/commands" / f"{nom}.md").read_bytes().decode("utf-8")
        assert f"workflow_state.py {voie} --source slash" in cmd


def test_coherence_regle_agent_identique():
    """La règle « Agent : … » est écrite une seule fois, dans le script."""
    script = (SCRIPTS / "workflow_state.py").read_bytes().decode("utf-8")
    assert script.count("--source agent") >= 1
    assert "Pas de question sur le choix de voie" not in script
