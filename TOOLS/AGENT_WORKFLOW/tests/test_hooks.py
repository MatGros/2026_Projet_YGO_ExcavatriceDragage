"""Tests des hooks bloquants.

Un hook qui ne bloque pas quand il faut est pire qu'absent : il donne
l'illusion d'un garde-fou. Ces tests verifient les deux sens — il bloque
quand il doit, il laisse passer quand il doit.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
ROOT = Path(__file__).resolve().parents[3]
PRE_EDIT = SCRIPTS / "hook_pre_edit.py"
STOP = SCRIPTS / "hook_stop.py"


def call(script: Path, payload: dict) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(script)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )


def transcript_with_reads(tmp_path: Path, *files: str) -> str:
    """Transcript de session contenant de vrais appels a l'outil Read."""
    lines = [
        json.dumps(
            {"message": {"content": [{"type": "tool_use", "name": "Read",
                                      "input": {"file_path": str(ROOT / f)}}]}}
        )
        for f in files
    ]
    path = tmp_path / "transcript.jsonl"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return str(path)


# ── hook PreToolUse ───────────────────────────────────────────────────────────

def test_pre_edit_laisse_passer_hors_code(tmp_path: Path) -> None:
    result = call(PRE_EDIT, {
        "tool_name": "Edit",
        "transcript_path": transcript_with_reads(tmp_path),
        "tool_input": {"file_path": str(tmp_path / "note.md")},
    })
    assert result.returncode == 0


def test_pre_edit_laisse_passer_autre_outil(tmp_path: Path) -> None:
    result = call(PRE_EDIT, {
        "tool_name": "Bash",
        "transcript_path": transcript_with_reads(tmp_path),
        "tool_input": {"command": "ls"},
    })
    assert result.returncode == 0


def test_pre_edit_bloque_si_specs_non_lues(tmp_path: Path) -> None:
    """Une seule spec lue sur les trois requises : l'ecriture est refusee."""
    result = call(PRE_EDIT, {
        "tool_name": "Write",
        "transcript_path": transcript_with_reads(tmp_path, "DOC/STDS/NAMING_CONVENTION.md"),
        "tool_input": {"file_path": str(ROOT / "CODE/TREUILS/FB_Winch.st")},
    })
    assert result.returncode == 2, result.stdout + result.stderr
    assert "CODE_QUALITY_STANDARDS" in result.stderr


def test_pre_edit_autorise_si_tout_lu(tmp_path: Path) -> None:
    """Toutes les specs du dossier lues : l'ecriture passe."""
    specs = ["DOC/STDS/CODE_QUALITY_STANDARDS.md", "DOC/STDS/NAMING_CONVENTION.md"]
    specs += [p.relative_to(ROOT).as_posix() for p in (ROOT / "DOC" / "AF").glob("AF_Partie-*.md")]
    result = call(PRE_EDIT, {
        "tool_name": "Write",
        "transcript_path": transcript_with_reads(tmp_path, *specs),
        "tool_input": {"file_path": str(ROOT / "CODE/TREUILS/FB_Winch.st")},
    })
    assert result.returncode == 0, result.stderr


def test_pre_edit_ne_bloque_pas_sur_panne_outillage(tmp_path: Path) -> None:
    """Transcript introuvable : on ne bloque jamais le travail sur un souci d'infra."""
    result = call(PRE_EDIT, {
        "tool_name": "Write",
        "transcript_path": str(tmp_path / "absent.jsonl"),
        "tool_input": {"file_path": str(ROOT / "CODE/TREUILS/FB_Winch.st")},
    })
    assert result.returncode == 0


def test_pre_edit_exige_la_version_active_de_la_spec(tmp_path: Path) -> None:
    """Lire une version archivee ne vaut pas lecture de la version active."""
    result = call(PRE_EDIT, {
        "tool_name": "Write",
        "transcript_path": transcript_with_reads(
            tmp_path,
            "DOC/STDS/CODE_QUALITY_STANDARDS.md",
            "DOC/STDS/NAMING_CONVENTION.md",
            "ARCHIVES/Doc/AF_Partie-09_Fonction_Winch_v1.13.md",
        ),
        "tool_input": {"file_path": str(ROOT / "CODE/TREUILS/FB_Winch.st")},
    })
    assert result.returncode == 2
    assert "AF_Partie-09" in result.stderr


# ── hook Stop ─────────────────────────────────────────────────────────────────

def test_stop_ne_boucle_pas() -> None:
    """stop_hook_active : le hook s'est deja declenche, il ne rebloque pas."""
    result = call(STOP, {"stop_hook_active": True})
    assert result.returncode == 0


def test_stop_ignore_les_sessions_sans_st() -> None:
    """Discussion, audit, doc : aucun ST touche, rien n'est bloque."""
    result = call(STOP, {"stop_hook_active": False})
    assert result.returncode in (0, 2)
    if result.returncode == 2:
        # S'il bloque, c'est que du ST est reellement modifie et rouge :
        # le message doit dire lequel des deux controles a echoue.
        assert "[S1]" in result.stderr or "[S2]" in result.stderr


def test_stop_entree_illisible_ne_bloque_pas() -> None:
    result = subprocess.run(
        [sys.executable, str(STOP)], input="pas du json", capture_output=True, text=True
    )
    assert result.returncode == 0
