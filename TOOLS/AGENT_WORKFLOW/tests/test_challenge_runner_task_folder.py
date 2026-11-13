import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import challenge_runner


def test_resolve_task_folder_refuses_ambiguous_prefixes(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    tasks_dir.mkdir(parents=True)
    (tasks_dir / "T000_ORCHESTRATION_MULTI_TACHES").mkdir()
    (tasks_dir / "T000_CHALLENGE_M3_SIMULATION").mkdir()
    monkeypatch.setattr(challenge_runner, "REPO_ROOT", str(tmp_path))

    with pytest.raises(ValueError, match="Dossier ambigu pour T000"):
        challenge_runner.resolve_task_folder("T000")


def test_resolve_task_folder_returns_the_unique_exact_prefix_match(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    tasks_dir.mkdir(parents=True)
    expected = tasks_dir / "T427_WORKFLOW_AGENTS"
    expected.mkdir()
    monkeypatch.setattr(challenge_runner, "REPO_ROOT", str(tmp_path))

    assert Path(challenge_runner.resolve_task_folder("T427")) == expected


def test_resolve_task_folder_fails_when_no_mapping_exists(tmp_path, monkeypatch):
    tasks_dir = tmp_path / "DOC" / "WFLOW" / "TASKS"
    tasks_dir.mkdir(parents=True)
    monkeypatch.setattr(challenge_runner, "REPO_ROOT", str(tmp_path))

    with pytest.raises(FileNotFoundError, match="Aucun dossier explicite"):
        challenge_runner.resolve_task_folder("T999")
