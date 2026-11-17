"""Garde-fous P1 (T427, GO exploitant 2026-11-15) : correction du garde de perimetre.

Contrat : (1) CODE/** refuse sans exception, derogation comprise ; (2) motif obligatoire,
copie mot pour mot d'un message humain ; (3) perimetre du contrat respecte ; (4) tests.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import task_scope  # noqa: E402


def _transcript(tmp_path, *messages):
    path = tmp_path / "transcript.jsonl"
    path.write_text("".join(json.dumps({"type": "user", "message": {"content": m}}) + "\n"
                            for m in messages), encoding="utf-8")
    return path


@pytest.fixture(autouse=True)
def _registre_isole(tmp_path, monkeypatch):
    monkeypatch.setattr(task_scope, "DEROG_DIR", tmp_path / "derog")


def test_P1_code_refuse_sans_derogation():
    """(1) sans derogation, CODE/ reste refuse par la deny-list."""
    assert task_scope.is_derogated("s", "CODE/MAIN/PRG_01.st") is False
    assert task_scope.is_absolute_denied("CODE/MAIN/PRG_01.st", []) is True


def test_code_derogation_accordee_par_citation_humaine(tmp_path):
    """2026-11-18 : CODE/ s'ouvre par une citation exacte de l'exploitant, pas autrement."""
    phrase = "GO CODE/MAIN/PRG_01.st"
    entry = task_scope.write_derogation("s", "CODE/MAIN/PRG_01.st", phrase,
                                        transcript=_transcript(tmp_path, phrase))
    assert entry["path"] == "CODE/MAIN/PRG_01.st"
    assert task_scope.is_derogated("s", "CODE/MAIN/PRG_01.st") is True


def test_garde_derogation_exige_une_citation_humaine(tmp_path):
    """Un fichier de garde s'ouvre aussi, mais seulement sur ces mots exacts."""
    with pytest.raises(task_scope.DerogationRefusee):
        task_scope.write_derogation("s", "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py", "oui",
                                    transcript=_transcript(tmp_path, "bonjour"))
    phrase = "GO TOOLS/AGENT_WORKFLOW/scripts/task_scope.py"
    task_scope.write_derogation("s", "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py", phrase,
                                transcript=_transcript(tmp_path, phrase))
    assert task_scope.is_derogated("s", "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py") is True


def test_P1_skills_autorise_par_le_contrat_sans_derogation():
    """(3) un chemin protege que le perimetre epingle du contrat autorise est classe produit."""
    pinned = ["TOOLS/AGENT_WORKFLOW/skills/orchestrator/"]
    kind = task_scope.classify("TOOLS/AGENT_WORKFLOW/skills/orchestrator/ROLE.md",
                               pinned, [], [], pinned_allowed=pinned)
    assert kind == "produit"


def test_P1_contrat_plc_epingle_reste_valable():
    """Un contrat PLC valide (CODE/ dans le perimetre epingle) n'est pas casse par P1."""
    assert task_scope.is_absolute_denied("CODE/MAIN/PRG_01.st", ["CODE/MAIN/"]) is False


def test_P1_motif_vide_refuse(tmp_path):
    with pytest.raises(task_scope.DerogationRefusee):
        task_scope.write_derogation("s", "TOOLS/X.py", "   ", transcript=_transcript(tmp_path, "oui"))


def test_P1_derogation_sans_motif_refusee_en_cli(tmp_path, capsys):
    """(4) la CLI exige --motif."""
    with pytest.raises(SystemExit):
        task_scope.main(["deroge", "--session", "s", "--path", "TOOLS/X.py"])


def test_P1_citation_reformulee_refusee(tmp_path):
    """(2) un motif qui ne figure pas mot pour mot dans un message humain est refuse."""
    tr = _transcript(tmp_path, "Je te rappelle que tu es le responsable. C'est toi qui décides là, non ?")
    with pytest.raises(task_scope.DerogationRefusee):
        task_scope.write_derogation("s", "TOOLS/X.py", "c'est toi qui decides", transcript=tr)


def test_P1_citation_exacte_acceptee(tmp_path):
    tr = _transcript(tmp_path, "GO P1 avrec /worglow")
    entry = task_scope.write_derogation("s", "TOOLS/X.py", "GO P1 avrec /worglow", transcript=tr)
    assert entry["motif"] == "GO P1 avrec /worglow"
    assert task_scope.is_derogated("s", "TOOLS/X.py")
