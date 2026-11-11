"""T430 : couverture effective des documents deplaces, pas seulement du regex."""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/G340_check_doc_links.py"


def load():
    spec = importlib.util.spec_from_file_location("g340_t430", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def put(root, name, text="# Document\n"):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def run(root):
    return subprocess.run([sys.executable, "-X", "utf8", str(SCRIPT), str(root)], capture_output=True, text=True, encoding="utf-8")


def test_spaces_parentheses_and_real_txxx_missing_target(tmp_path):
    target = "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/AUDITS/TXXX_RAPPORT_v1.0.md"
    path = put(tmp_path, target)
    put(tmp_path, "DOC/INDEX.md", f"# Index\nVoir [{target}](<{target}>)\n")
    assert run(tmp_path).returncode == 0
    path.unlink()  # Mutation dans la fixture, jamais dans le depot.
    result = run(tmp_path)
    assert result.returncode == 1
    assert target in result.stderr


def test_version_control_reaches_workflow_subdirectories(tmp_path):
    prefix = "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/AUDITS/"
    old = prefix + "T123_PLAN_v1.0.md"
    newest = prefix + "T123_PLAN_v1.1.md"
    put(tmp_path, old)
    put(tmp_path, newest)
    put(tmp_path, "DOC/INDEX.md", f"# Index\n`{old}`\n")
    result = run(tmp_path)
    assert result.returncode == 1
    assert "perime" in result.stderr
    assert newest in result.stderr


def test_versions_and_numbering_exclude_archives_and_exact_example(tmp_path):
    put(tmp_path, "DOC/WFLOW/TASKS/T123/T123_PLAN_v1.0.md")
    put(tmp_path, "DOC/WFLOW/TASKS/T123/ARCHIVES/T123_PLAN_v9.0.md")
    put(tmp_path, "DOC/WFLOW/TASKS/TXXX/T123_PLAN_v8.0.md")
    module = load()
    versions = module.all_versions(tmp_path / "DOC")
    assert versions["T123_PLAN"] == ["WFLOW/TASKS/T123/T123_PLAN_v1.0.md"]
    assert module.latest_versions(tmp_path / "DOC")["T123_PLAN"][0] == (1, 0)


def test_historical_numbering_does_not_exempt_the_whole_staging_area(tmp_path):
    put(tmp_path, "DOC/AF/AF_Partie-01_Socle_v1.0.md")
    historical = put(tmp_path, "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/AUDITS/TXXX_HISTORIQUE.md", "# Rapport\nAncienne AF99.\n")
    assert run(tmp_path).returncode == 0
    put(tmp_path, "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/TESTS/T123_PLAN.md", "# Plan\nAF99.\n")
    result = run(tmp_path)
    assert result.returncode == 1
    assert "AF99" in result.stderr
    assert str(historical.name) not in result.stderr


def test_historical_document_still_checks_active_links(tmp_path):
    put(tmp_path, "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/CONTRACTS/T123_NOTE.md", "# Note\nDOC/inexistant.md\n")
    result = run(tmp_path)
    assert result.returncode == 1
    assert "inexistant.md" in result.stderr


def test_adjacent_paths_remain_separate():
    text = "DOC/a.md et DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/T123_PLAN.md:12"
    assert [m.group("path") for m in load().LINK.finditer(text)] == [
        "DOC/a.md", "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/T123_PLAN.md"
    ]


def test_directory_citation_does_not_swallow_a_real_reference(tmp_path):
    put(tmp_path, "DOC/Cible.md")
    put(tmp_path, "DOC/INDEX.md", "# Index\nDOC/AF dossier puis DOC/Cible.md\nCODE/ : voir DOC/Cible.md\n")
    result = run(tmp_path)
    assert result.returncode == 0, result.stderr
    assert [m.group("path") for m in load().LINK.finditer("DOC/AF dossier puis DOC/Cible.md")] == ["DOC/Cible.md"]
