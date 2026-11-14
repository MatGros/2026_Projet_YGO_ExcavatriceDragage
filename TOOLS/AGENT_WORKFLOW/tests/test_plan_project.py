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
