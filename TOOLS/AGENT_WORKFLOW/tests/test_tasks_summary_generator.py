"""Garde-fous du résumé de catalogue (T427-I2) : il doit refléter le catalogue réel."""
import hashlib
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import generate_tasks_summary as generator


def test_generated_summary_carries_the_live_catalog_digest():
    text = generator.build(generator.load_tasks(), generator.load_locks())

    digest = hashlib.sha256(generator.CATALOG.read_bytes()).hexdigest()
    assert f"sha256(TASKS.yaml)={digest}" in text


def test_counters_match_the_catalog_and_the_locks():
    tasks = generator.load_tasks()
    locks = generator.load_locks()
    text = generator.build(tasks, locks)

    counts = {}
    for task in tasks:
        counts[str(task.get("statut", "⬜"))] = counts.get(str(task.get("statut", "⬜")), 0) + 1
    assert f"🔒 {len(locks)}" in text
    assert f"⏳ {counts.get('⏳', 0)}" in text
    assert f"⏸️ {counts.get('⏸️', 0)}" in text
    assert f"⬜ {counts.get('⬜', 0)}" in text
    assert f"total {len(tasks)}" in text


def test_locks_are_listed_with_their_actor():
    locks = generator.load_locks()
    text = generator.build(generator.load_tasks(), locks)

    for task_id, lock in locks.items():
        assert f"{task_id} ({lock.get('actor', '—')})" in text


def test_check_mode_detects_a_stale_summary(tmp_path, monkeypatch):
    stale = tmp_path / "TASKS_ACTIVE_SUMMARY.md"
    stale.write_text("# vide\n", encoding="utf-8")
    monkeypatch.setattr(generator, "SUMMARY", stale)

    assert generator.main(["--check"]) == 1


def test_check_mode_accepts_a_fresh_summary(tmp_path, monkeypatch):
    fresh = tmp_path / "TASKS_ACTIVE_SUMMARY.md"
    fresh.write_text(generator.build(generator.load_tasks(), generator.load_locks()), encoding="utf-8")
    monkeypatch.setattr(generator, "SUMMARY", fresh)

    assert generator.main(["--check"]) == 0
