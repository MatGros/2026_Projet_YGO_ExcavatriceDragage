"""Regression T430 : couverture des contrats ranges et chemins non tronques."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/G530_check_contract_refs.py"
SPEC = importlib.util.spec_from_file_location("g530_t430", SCRIPT)
assert SPEC and SPEC.loader
G530 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G530)

CORPUS = "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/CONTRACTS"
TARGET = f"{CORPUS}/T213_CONTRAT_DIAGNOSTIC_HOMING_M2.yaml"


def put(root: Path, relative: str, text: str = "") -> Path:
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")
    return target


def run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(root), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PYTHONIOENCODING": "utf-8"},
    )


@pytest.mark.parametrize(
    "text",
    [
        TARGET,
        f"{chr(96)}{TARGET}{chr(96)}",
        f"[contrat](<{TARGET}>)",
        f"contrat: '{TARGET}'",
        TARGET.replace("/", "\\"),
        f"Voir {TARGET} puis DOC/AF/Autre.md.",
    ],
)
def test_extract_complete_path_with_spaces_and_parentheses(text: str) -> None:
    assert TARGET in G530.extract_paths(text)


def test_extract_does_not_swallow_folder_prose_or_backup() -> None:
    assert G530.extract_paths("DOC/AF dossier puis DOC/Cible.md") == {"DOC/Cible.md"}
    assert G530.extract_paths("DOC/CONTRACTS/*.yaml") == set()
    assert G530.extract_paths("DOC/Ancien.yaml.bak_v1") == set()
    assert G530.extract_paths("CODE/ : aucun fichier ecrit (FB_Cycle.st)") == set()
    assert G530.extract_paths("CODE/ VIDE + registry.yaml") == set()
    assert G530.extract_paths("CODE/) : FB_CycleSemiAuto.st") == set()


@pytest.mark.parametrize("option", ["-p test_task_tracking.py", "-m unittest.py", "--pattern test_task_tracking.py"])
def test_extract_does_not_cross_command_line_option(option: str) -> None:
    command = f"python -m unittest discover -s TOOLS/AGENT_WORKFLOW/tests {option}"
    assert G530.extract_paths(command) == set()
    # Une reference reellement nommee apres l'option reste controlee.
    assert G530.extract_paths(f"{command} et DOC/Absent.md") == {"DOC/Absent.md"}


@pytest.mark.parametrize(
    "text",
    [
        "CODE/M_MAIN (une seule ligne de cablage dans PRG_02_Acquisition.st",
        "CODE/M_MAIN modifies (PRG_02_Acquisition.st",
    ],
)
def test_extract_does_not_turn_unclosed_prose_into_path(text: str) -> None:
    assert G530.extract_paths(text) == set()


def test_extract_preserves_real_spaces_parentheses_and_spaced_dash() -> None:
    path = "DOC/Plan - preuve (revue)/Contrat final (copie).yaml"
    assert G530.extract_paths(f"'{path}'") == {path}


@pytest.mark.parametrize(
    "field",
    [
        f"    contrat: '{TARGET}'\n",
        f'    contrat: "{TARGET}"\n',
        "    contrat: >-\n      DOC/WFLOW/TASKS/T_TEMP\n"
        "      (A TRIIER)/CONTRACTS/T213_CONTRAT_DIAGNOSTIC_HOMING_M2.yaml\n",
        "    contrat: 'DOC/WFLOW/TASKS/T_TEMP (A\n"
        "      TRIIER)/CONTRACTS/T213_CONTRAT_DIAGNOSTIC_HOMING_M2.yaml'\n",
    ],
)
def test_yaml_catalogue_field_is_reconstructed(tmp_path: Path, field: str) -> None:
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", "tasks:\n  - id: T213\n" + field)
    put(tmp_path, TARGET, "contract:\n  task_id: T213\n")
    assert G530.catalogue_paths(tmp_path) == {TARGET}
    assert run(tmp_path).returncode == 0


def test_discovery_keeps_full_historical_corpus_and_active_contracts(tmp_path: Path) -> None:
    expected = {
        f"{CORPUS}/T213_CONTRAT_STANDARD.yaml",
        f"{CORPUS}/T273_CONTRAT_LEGACY.yaml",
        f"{CORPUS}/T262_CONTEXTE.yaml",
        f"{CORPUS}/T401_CATALOGUE_SIGNAUX.yaml",
        f"{CORPUS}/TXXX_CONTRAT_REEL.yaml",
        "DOC/WFLOW/TASKS/T500_REEL/T500_CONTRAT_ESSAI_v1.0.yaml",
        "DOC/WFLOW/TASKS/T501_REEL/FICHE.yaml",
        "DOC/WFLOW/TASKS/T502_REEL/REFERENCE_EXPLICITE.yaml",
        "DOC/WFLOW/CONTRACTS/ANCIEN.yaml",
    }
    for rel in expected:
        put(tmp_path, rel, "metadata: disponible\n")
    put(tmp_path, f"{CORPUS}/T273_CONTRAT_LEGACY.yaml",
        "task_id: T273\nobjectifs_testables: []\n")
    put(tmp_path, "DOC/WFLOW/TASKS/T501_REEL/FICHE.yaml", "contract:\n  task_id: T501\n")
    put(tmp_path, "DOC/WFLOW/TASKS.yaml",
        "tasks:\n  - id: T502\n"
        "    contrat: DOC/WFLOW/TASKS/T502_REEL/REFERENCE_EXPLICITE.yaml\n")
    for rel in [
        "DOC/WFLOW/TASKS/TXXX/TXXX_CONTRAT_EXEMPLE.yaml",
        f"{CORPUS}/ARCHIVES/T213_CONTRAT_ARCHIVE.yaml",
        "DOC/WFLOW/TASKS/T500_REEL/ARCHIVES/ANCIEN_CONTRAT.yaml",
        "DOC/WFLOW/TASKS/T500_REEL/T500_CONTRAT.yaml.bak_v1",
        "DOC/WFLOW/TASKS/T500_REEL/CONFIG_APPLICATION.yaml",
    ]:
        put(tmp_path, rel, "contract:\n  task_id: T999\n" if "EXEMPLE" in rel else "other: rien\n")
    actual = {p.relative_to(tmp_path).as_posix() for p in G530.discover_sources(tmp_path)}
    assert actual == expected
    assert set(G530.collect_references(tmp_path)) == expected | {"DOC/WFLOW/TASKS.yaml"}


def test_missing_referenced_source_fails_even_if_another_contract_survives(tmp_path: Path) -> None:
    put(tmp_path, TARGET, "contract:\n  task_id: T213\n")
    put(tmp_path, f"{CORPUS}/T214_CONTRAT_RESTANT.yaml", "contract:\n  task_id: T214\n")
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", f"tasks:\n  - id: T213\n    contrat: '{TARGET}'\n")
    assert run(tmp_path).returncode == 0
    (tmp_path / TARGET).unlink()  # mutation du seul fichier cree par ce test
    result = run(tmp_path)
    assert result.returncode == 1
    assert TARGET in result.stdout


def test_catalogue_alone_cannot_claim_coverage_or_update_baseline(tmp_path: Path) -> None:
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", "tasks: []\n")
    result = run(tmp_path, "--update-baseline")
    assert result.returncode == 1
    assert "catalogue seul" in result.stdout
    assert not (tmp_path / G530.BASELINE_PATH).exists()


def test_folded_path_inside_contract_is_checked(tmp_path: Path) -> None:
    put(tmp_path, f"{CORPUS}/T213_CONTRAT_SOURCE.yaml",
        "contract:\n  source: >-\n    DOC/WFLOW/TASKS/T_TEMP\n"
        "    (A TRIIER)/CONTRACTS/T214_CONTRAT_CIBLE.yaml\n")
    result = run(tmp_path)
    assert result.returncode == 1
    assert f"{CORPUS}/T214_CONTRAT_CIBLE.yaml" in result.stdout


def test_invalid_catalogue_or_contract_does_not_pass_silently(tmp_path: Path) -> None:
    put(tmp_path, TARGET, "contract:\n  task_id: T213\n")
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", "tasks: [\n")
    assert run(tmp_path).returncode == 1
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", "tasks: []\n")
    put(tmp_path, TARGET, "contract: [\n")
    result = run(tmp_path)
    assert result.returncode == 1
    assert "YAML inexploitable" in result.stdout


def test_known_debt_stays_visible_without_rewriting_baseline(tmp_path: Path) -> None:
    missing = "CODE/Ancien.st"
    put(tmp_path, TARGET, f"contract:\n  source: {missing}\n")
    baseline = put(tmp_path, G530.BASELINE_PATH, json.dumps({"known_missing": [missing]}))
    before = baseline.read_bytes()
    result = run(tmp_path)
    assert result.returncode == 0
    assert "WARN" in result.stdout and missing in result.stdout
    assert run(tmp_path, "--strict").returncode == 1
    assert baseline.read_bytes() == before


def test_catalogue_does_not_read_unrelated_text_fields_as_contract_refs(tmp_path: Path) -> None:
    put(tmp_path, TARGET, "contract:\n  task_id: T213\n")
    put(tmp_path, "DOC/WFLOW/TASKS.yaml",
        f"tasks:\n  - id: T213\n    contrat: '{TARGET}'\n"
        "    contexte: Citation historique DOC/Ancien.md\n")
    assert G530.catalogue_paths(tmp_path) == {TARGET}
    assert run(tmp_path).returncode == 0
