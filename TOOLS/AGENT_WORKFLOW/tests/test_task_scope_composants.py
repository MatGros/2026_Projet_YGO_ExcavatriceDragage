"""Garde de perimetre : comparaison par composants entiers (T427, 2026-11-17).

Defaut corrige : `_matches_anywhere` cherchait `"/code"` comme sous-chaine.
Tout chemin contenant `/codex`, `/codesys` ou `/code_review` etait refuse —
un chemin ABSOLU vers `codex_notes.md` etait bloque alors que le chemin relatif
passait. La comparaison porte desormais sur des composants entiers.

Ces tests verrouillent les deux cotes : plus de faux positif, et aucune
regression de protection sur CODE/, les sources automate et les fichiers de garde.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

import task_scope  # noqa: E402

RACINE = ROOT.as_posix()  # racine reelle du depot, quel que soit le poste


def test_faux_positifs_relatifs_ne_sont_plus_refuses() -> None:
    """Un nom qui contient « code » sans etre le dossier CODE/ reste autorise."""
    for chemin in ("codex_notes.md",
                   "DOC/code_review/rapport.md",
                   "TOOLS/codesys_console/x.py",
                   "DOC/codes/etude.md"):
        assert task_scope.is_absolute_denied(chemin) is False, chemin


def test_faux_positifs_absolus_ne_sont_plus_refuses() -> None:
    """Le meme chemin en absolu doit se comporter comme en relatif."""
    for chemin in (f"{RACINE}/codex_notes.md",
                   f"{RACINE}/DOC/code_review/rapport.md",
                   f"{RACINE}/TOOLS/codesys_console/x.py"):
        assert task_scope.is_absolute_denied(chemin) is False, chemin


def test_code_reste_refuse_absolu_ou_relatif() -> None:
    """La protection de CODE/ ne depend pas de la racine du chemin."""
    assert task_scope.is_absolute_denied("CODE/M_MAIN/PRG_03_Modes_Cycle.st") is True
    assert task_scope.is_absolute_denied(f"{RACINE}/CODE/M_MAIN/PRG_03_Modes_Cycle.st") is True
    assert task_scope.is_absolute_denied("C:/autre/depot/CODE/x.st") is True


def test_code_xml_et_sources_automate_restent_refuses() -> None:
    assert task_scope.is_absolute_denied("CODE_XML/CODE_Bundle.xml") is True
    assert task_scope.is_absolute_denied("PRJ_CODESYS/Projet.project") is True


def test_fichiers_de_garde_restent_refuses() -> None:
    for chemin in ("TOOLS/AGENT_WORKFLOW/scripts/task_scope.py",
                   "TOOLS/AGENT_WORKFLOW/scripts/hook_scope_guard.py",
                   ".claude/settings.json",
                   "TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md"):
        assert task_scope.is_absolute_denied(chemin) is True, chemin


def test_point_final_sur_le_dossier_code_reste_refuse() -> None:
    """`CODE.` designe le meme dossier que `CODE` : Windows retire le point final."""
    assert task_scope.is_absolute_denied("CODE./x.st") is True


def test_nom_court_du_dossier_code_reste_refuse() -> None:
    """`CODE~1` n'existe pas (CODE tient deja en 8.3), mais la forme reste refusee.

    Refuser la forme coute moins cher que dependre de la facon dont le volume a
    nomme le dossier. Le cas REELLEMENT observe est celui des noms longs, teste
    plus bas (`AGENT_~1`, `TASK_S~1.PY`).
    """
    assert task_scope.is_absolute_denied("CODE~1/x.st") is True


def test_nom_court_sur_un_fichier_protege() -> None:
    """`TASK_S~1.PY` est le nom court 8.3 de `task_scope.py`."""
    assert task_scope.is_absolute_denied("TOOLS/AGENT_WORKFLOW/scripts/TASK_S~1.PY") is True


def test_perimetre_epingle_ne_s_ouvre_pas_par_nom_court() -> None:
    """Un nom court ne doit pas transformer un perimetre epingle en passe-droit."""
    assert task_scope.is_absolute_denied("CODE/MA~1/x.st", ["CODE/MAIN"]) is True


def test_composants_canonises() -> None:
    assert task_scope._components("C:/Depot/CODE/x.st") == ["depot", "code", "x.st"]
    assert task_scope._components("CODE./x.st") == ["code", "x.st"]
    assert task_scope._components("") == []


def test_perimetre_epingle_ouvre_toujours() -> None:
    """Un contrat a perimetre epingle reste prioritaire sur la deny-list."""
    assert task_scope.is_absolute_denied("CODE/MAIN/PRG_01.st", ["CODE/MAIN/"]) is False


def test_alias_court_sur_composant_intermediaire() -> None:
    """`AGENT_~1` est le nom court de `AGENT_WORKFLOW` : le garde doit le voir.

    Verifie en reel le 2026-11-17 : `TOOLS/AGENT_~1/scripts/task_scope.py` et
    `TOOLS/AGENT_WORKFLOW/scripts/task_scope.py` sont le meme fichier (samefile).
    Sans ce cas, le garde se laissait contourner en nommant le dossier en 8.3.
    """
    assert task_scope.is_absolute_denied("TOOLS/AGENT_~1/scripts/task_scope.py") is True
    assert task_scope.is_absolute_denied("TOOLS/AGENT_WORKFLOW/SCRIPTS~1/task_scope.py") is True


def test_octet_nul_refuse() -> None:
    """Un chemin contenant un octet nul n'est jamais legitime."""
    assert task_scope.is_absolute_denied("CODE\x00/x.st") is True
    assert task_scope.is_hard_denied("CODE\x00/x.st") is True


def test_flux_alternatif_windows_refuse() -> None:
    """`fichier::$DATA` doit rester dans la deny-list de son dossier."""
    assert task_scope.is_absolute_denied("CODE/x.st::$DATA") is True


def test_dossiers_voisins_ne_sont_pas_confondus() -> None:
    """`CODE2` et `CODE-X` ne sont pas `CODE` : pas de refus par prefixe de chaine."""
    assert task_scope.is_absolute_denied("C:/depot/CODE2/x.st") is False
    assert task_scope.is_absolute_denied("C:/depot/CODE-X/x.st") is False
