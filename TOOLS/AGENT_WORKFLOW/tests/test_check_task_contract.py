"""Tests du gate contrat de tache.

Le contrat existe pour une raison mesuree : sur 53 taches deleguees, les
criteres d'acceptation etaient 3 phrases generiques. Ces tests verifient que
le gate refuse bien ce type de critere.
"""

from __future__ import annotations

import os
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


def run(path: Path, *args: str, disable_pyyaml: bool = False) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    if disable_pyyaml:
        env["CHECK_TASK_CONTRACT_DISABLE_PYYAML"] = "1"
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(path), *args],
        capture_output=True,
        text=True,
        env=env,
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
    """Le boilerplate reellement observe dans les 53 taches deleguees."""
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


MAIN_PROGRAM_SCOPE = """\
contract:
  task_id: LOT_08_PROGRAMME
  criticality: C3
  strategy: patch
  objective: "Rendre la page programme lisible dans CODESYS."
  acceptance:
    - id: AC1
      statement: "Le nom de fichier est identique au nom de POU declare."
      verified_by: "python TOOLS/AGENT_WORKFLOW/scripts/G310_check_code_structure.py"
    - id: AC2
      statement: "Le suffixe de langage correspond au langage genere dans le bundle."
      verified_by: "python TOOLS/AGENT_WORKFLOW/scripts/G310_check_code_structure.py"
  scope:
    allowed:
      - CODE/MAIN/PRG_08_Modes_CFC.xml
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
  evidence_required:
    - check_linkage
"""


def test_t8_programme_main_sans_criteres_structurels_refuse(tmp_path: Path) -> None:
    bad = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "Le CFC contient les trois instances attendues."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "Les trois instances sont appelees une fois par scan."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T8" in result.stderr
    assert "nom de fichier = nom de POU" in result.stderr
    assert "suffixe = langage genere dans le bundle" in result.stderr


def test_t8_programme_main_sans_critere_suffixe_refuse(tmp_path: Path) -> None:
    bad = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "Les sorties physiques restent dans la barriere Ladder."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T8" in result.stderr
    assert "suffixe = langage genere dans le bundle" in result.stderr


def test_t8_accepte_la_formulation_fichier_pou_equivalente(tmp_path: Path) -> None:
    equivalent = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "Chaque fichier declare un POU dont le nom est identique au nom du fichier."',
    )
    result = run(write(tmp_path, equivalent))
    assert result.returncode == 0, result.stdout + result.stderr


def test_t8_programme_main_avec_deux_criteres_structurels_passe(tmp_path: Path) -> None:
    result = run(write(tmp_path, MAIN_PROGRAM_SCOPE))
    assert result.returncode == 0, result.stdout + result.stderr


def test_t8_ne_s_applique_pas_a_une_tache_documentaire(tmp_path: Path) -> None:
    documentation = MAIN_PROGRAM_SCOPE.replace(
        "CODE/MAIN/PRG_08_Modes_CFC.xml",
        "DOC/AF_Partie-02_Architecture_Programme_v3.0.md",
    ).replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "La documentation reference le sample CFC reel."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "La table de nommage indique le format source."',
    )
    result = run(write(tmp_path, documentation))
    assert result.returncode == 0, result.stdout + result.stderr


def test_t8_raw_forbidden_code_main_ne_declenche_pas_le_controle(tmp_path: Path) -> None:
    documentation = MAIN_PROGRAM_SCOPE.replace(
        "CODE/MAIN/PRG_08_Modes_CFC.xml",
        "DOC/AF_Partie-02_Architecture_Programme_v3.0.md",
    ).replace(
        "      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export",
        "      - CODE/MAIN/PRG_08_Modes_CFC.xml",
    ).replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "La documentation reference le sample CFC reel."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "La table de nommage indique le format source."',
    )
    result = run(write(tmp_path, documentation), disable_pyyaml=True)
    assert result.returncode == 0, result.stdout + result.stderr


def test_t8_raw_code_main_sans_relations_structurelles_refuse(tmp_path: Path) -> None:
    bad = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "La page contient les blocs requis."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "Les connexions sont visibles dans CODESYS."',
    )
    result = run(write(tmp_path, bad), disable_pyyaml=True)
    assert result.returncode == 1
    assert "T8" in result.stderr


def test_t8_decorative_terms_sans_relation_sont_refuses(tmp_path: Path) -> None:
    bad = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "Le fichier, le nom et le POU sont documentes dans la revue."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "Le suffixe, le langage et le bundle sont documentes dans la revue."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T8" in result.stderr


def test_t8_relation_decorative_scattered_refusee(tmp_path: Path) -> None:
    """Une relation hors des termes structures ne satisfait jamais T8."""
    bad = MAIN_PROGRAM_SCOPE.replace(
        'statement: "Le nom de fichier est identique au nom de POU declare."',
        'statement: "Le fichier est identique dans la revue ; le POU est documente."',
    ).replace(
        'statement: "Le suffixe de langage correspond au langage genere dans le bundle."',
        'statement: "Le suffixe est identique dans la revue ; le langage et le bundle sont documentes."',
    )
    result = run(write(tmp_path, bad))
    assert result.returncode == 1
    assert "T8" in result.stderr


def test_t8_raw_relations_structurelles_explicites_acceptes(tmp_path: Path) -> None:
    result = run(write(tmp_path, MAIN_PROGRAM_SCOPE), disable_pyyaml=True)
    assert result.returncode == 0, result.stdout + result.stderr


def test_raw_scope_allowed_empty_refuse(tmp_path: Path) -> None:
    """Le repli doit appliquer T5 comme le parseur PyYAML."""
    bad = VALID.replace("    allowed:\n      - CODE/TREUILS/FB_Winch.st\n", "    allowed: []\n")
    result = run(write(tmp_path, bad), disable_pyyaml=True)
    assert result.returncode == 1
    assert "T5" in result.stderr


def test_campaign_raw_fallback(tmp_path: Path) -> None:
    """Les contrats avec champs YAML replies (> et |) restent valides sans PyYAML."""
    folded = VALID.replace(
        'statement: "BrakeCmd reste FALSE tant que BrakeCommandOpenConfirmed est FALSE."',
        'statement: >\n        BrakeCmd reste FALSE\n        tant que BrakeCommandOpenConfirmed est FALSE.',
    )
    result = run(write(tmp_path, folded), disable_pyyaml=True)
    assert result.returncode == 0, f"{result.stdout}{result.stderr}"
