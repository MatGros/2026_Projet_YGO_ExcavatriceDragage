from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "plan_project.py"
SPEC = importlib.util.spec_from_file_location("plan_project", SCRIPT)
plan_project = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = plan_project
SPEC.loader.exec_module(plan_project)


def test_report_separates_done_from_accepted(tmp_path, monkeypatch):
    monkeypatch.setattr(plan_project, "ROOT", tmp_path)
    plan = tmp_path / "plan.md"
    plan.write_text('''---
plan_project:
  milestones:
    - id: M1
      title: Essai réel
      execution: DONE
      execution_by: AGY01
      evidence: "capture et commande"
      validation: ACCEPTED
      validated_by: HUM
      validated_at: "2026-11-14"
    - id: M2
      title: Revue
      execution: DONE
      validation: ACCEPTED
      validated_by: ""
      validated_at: ""
---
''', encoding="utf-8")
    result = plan_project.render({"id": "T427", "titre": "Test", "statut": "⏸️", "agent": "CC01"}, plan)
    assert "2/2 DONE" in result
    assert "1/2 acceptée(s) avec auteur+date" in result
    assert "ACCEPTED_INCOMPLETE" in result


def test_legacy_plan_ne_infers_validation(tmp_path):
    plan = tmp_path / "T427_PLAN.md"
    plan.write_text("## 4. Étapes\n| # | Étape | Fait quand | État |\n|---|---|---|---|\n| 1 | Implémentation | Gate vert | ✅ fait |\n", encoding="utf-8")
    result = plan_project.render({"id": "T427", "titre": "Test", "statut": "⏸️", "agent": "CC01"}, plan)
    assert "validation=NOT_RECORDED" in result
    assert "0/1 acceptée(s)" in result


def test_legacy_mermaid_lists_milestones_without_inventing_state(tmp_path):
    plan = tmp_path / "T427_PLAN.md"
    plan.write_text('## 4. Jalons\n```mermaid\nflowchart LR\n  M0["M0 cadrage"] --> M1["M1 essais"]\n```\n', encoding="utf-8")
    result = plan_project.render({"id": "T427", "titre": "Test", "statut": "pause", "agent": "CC01"}, plan)
    assert "0/2 DONE" in result
    assert "2 sans état explicite" in result
    assert "M1 — M1 essais | exécution=NOT_RECORDED | validation=NOT_RECORDED" in result


def test_creation_genere_un_plan_avec_execution_et_validation_separees(tmp_path, monkeypatch):
    monkeypatch.setattr(plan_project, "ROOT", tmp_path)
    folder = tmp_path / "DOC" / "WFLOW" / "TASKS" / "T427_TEST"
    folder.mkdir(parents=True)
    plan = plan_project.new_plan({"id": "T427", "titre": "Test déterministe"}, folder)
    content = plan.read_text(encoding="utf-8")
    assert "execution: NOT_STARTED" in content
    assert "validation: NOT_REVIEWED" in content
    assert "validated_by: \"\"" in content


# ── Garde-fous B18 / B19 (retour T417-C-AGY03, 2026-11-15) ──────────────────

def test_B18_sous_tache_acceptee_par_la_validation(capsys):
    """B18 — un ID de sous-tâche (T417-C) passe la validation ; un ID tronqué est refusé."""
    import re
    motif = r"T\d{3}(?:-[0-9A-Z]+)*"
    assert re.fullmatch(motif, "T417-C")
    assert re.fullmatch(motif, "T428-1")
    assert not re.fullmatch(motif, "T41")
    assert not re.fullmatch(motif, "T417-")
    assert plan_project.main(["T41"]) == 2
    assert "indéterminée" in capsys.readouterr().err


def test_B19_dossier_absent_message_guidant(tmp_path, monkeypatch):
    """B19 — dossier absent : message avec le chemin attendu, aucune création."""
    import pytest
    monkeypatch.setattr(plan_project, "ROOT", tmp_path)
    monkeypatch.setattr(plan_project, "TASKS_DIR", tmp_path / "DOC" / "WFLOW" / "TASKS")
    (tmp_path / "DOC" / "WFLOW" / "TASKS").mkdir(parents=True)
    with pytest.raises(ValueError) as exc:
        plan_project.task_folder({"id": "T417-C", "contrat": ""})
    assert "T417-C_<NOM>" in str(exc.value)
    assert list((tmp_path / "DOC" / "WFLOW" / "TASKS").iterdir()) == []


def test_B19_tache_mere_ne_capture_pas_la_sous_tache(tmp_path, monkeypatch):
    """B19 — « T417 » ne doit pas trouver le dossier « T417-C_… »."""
    import pytest
    tasks = tmp_path / "DOC" / "WFLOW" / "TASKS"
    (tasks / "T417-C_CHALLENGE").mkdir(parents=True)
    monkeypatch.setattr(plan_project, "ROOT", tmp_path)
    monkeypatch.setattr(plan_project, "TASKS_DIR", tasks)
    assert plan_project.task_folder({"id": "T417-C", "contrat": ""}).name == "T417-C_CHALLENGE"
    with pytest.raises(ValueError):
        plan_project.task_folder({"id": "T417", "contrat": ""})
