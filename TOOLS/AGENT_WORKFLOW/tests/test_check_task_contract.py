"""Tests du gate contrat de tache.

Le contrat existe pour une raison mesuree : sur 53 taches deleguees, les
criteres d'acceptation etaient 3 phrases generiques. Ces tests verifient que
le gate refuse bien ce type de critere.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_task_contract.py"

VALID = """\
contract:
  task_id: LOT_07_FREIN_M1
  criticality: C3
  strategy: patch
  objective: >
    Le frein M1 ne doit plus se desserrer tant que le retour contacteur
    n'est pas confirme, pour supprimer le glissement benne constate en essai.
  acceptance:
    - id: AC1
      statement: "BrakeCmd reste FALSE tant que BrakeCommandOpenConfirmed est FALSE."
      verified_by: "PRG_Test_FinalBrakePowerInterlock, cas 3"
    - id: AC2
      statement: "Un defaut de retour contacteur leve ErrorId bit 4 en moins de 200 ms."
      verified_by: "python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py"
  scope:
    allowed:
      - CODE/TREUILS/FB_Winch.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
  evidence_required:
    - check_linkage
    - run_all_gates
"""


def run(path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(path), *args], capture_output=True, text=True
    )


def write(tmp_path: Path, content: str) -> Path:
    path = tmp_path / "TASK_CONTEXT.yaml"
    path.write_text(content, encoding="utf-8")
    return path


def test_contrat_complet_passe(tmp_path: Path) -> None:
    result = run(write(tmp_path, VALID))
    assert result.returncode == 0, result.stdout + result.stderr


def test_t1_contrat_absent(tmp_path: Path) -> None:
    result = run(write(tmp_path, "criticality: C3\nnotes: rien\n"))
    assert result.returncode == 1
    assert "T1" in result.stderr


def test_t4_critere_generique_refuse(tmp_path: Path) -> None:
    """Le boilerplate reellement observe dans les 53 taches Pi."""
    bad = VALID.replace(
        '"BrakeCmd reste FALSE tant que BrakeCommandOpenConfirmed est FALSE."',
        '"Implement the requested change without widening scope."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T4" in result.stderr


def test_t4_critere_vague_francais_refuse(tmp_path: Path) -> None:
    bad = VALID.replace(
        '"Un defaut de retour contacteur leve ErrorId bit 4 en moins de 200 ms."',
        '"Le code fonctionne."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T4" in result.stderr


def test_t3_critere_sans_moyen_de_verification(tmp_path: Path) -> None:
    bad = VALID.replace('      verified_by: "PRG_Test_FinalBrakePowerInterlock, cas 3"\n', "")
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "verified_by" in result.stderr


def test_t6_rebuild_sans_contrat_de_conservation(tmp_path: Path) -> None:
    """Reconstruire sans ecrire ce qui doit survivre = refuse."""
    bad = VALID.replace("strategy: patch", "strategy: rebuild")
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T6" in result.stderr


def test_t6_rebuild_avec_conservation_passe(tmp_path: Path) -> None:
    good = VALID.replace("strategy: patch", "strategy: rebuild") + """\
  conservation:
    must_survive:
      - "Le timeout de desserrage frein reste a 800 ms."
    dropped_on_purpose:
      - "L'ancien bit de diagnostic 12, remplace par ErrorId bit 4."
"""
    result = run(write(tmp_path, good))
    assert result.returncode == 0, result.stdout + result.stderr


def test_t5_perimetre_absent(tmp_path: Path) -> None:
    bad = VALID.replace("      - CODE/TREUILS/FB_Winch.st\n", "")
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T5" in result.stderr


def test_gabarit_non_rempli_refuse(tmp_path: Path) -> None:
    """Le gabarit livre ne doit jamais passer tel quel."""
    template = Path(__file__).resolve().parents[1] / "templates" / "task_contract.yaml"
    result = run(template)
    assert result.returncode == 1
    assert "gabarit" in result.stderr
