"""Tests de non-regression du gate documentaire.

Chaque test rejoue une derive reellement constatee le 2026-07-29.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_doc_links.py"


def run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        capture_output=True,
        text=True,
    )


def make(tmp_path: Path, files: dict[str, str]) -> Path:
    for rel, content in files.items():
        target = tmp_path / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    return tmp_path


def test_lien_valide_passe(tmp_path: Path) -> None:
    root = make(
        tmp_path,
        {
            "DOC/AF_Partie-09_Fonction_Winch_v1.14.md": "# Winch\n",
            "AGENTS.md": "# Agents\nVoir DOC/AF_Partie-09_Fonction_Winch_v1.14.md\n",
        },
    )
    result = run(root)
    assert result.returncode == 0, result.stderr


def test_d1_lien_mort(tmp_path: Path) -> None:
    root = make(tmp_path, {"DOC/README.md": "# Doc\n", "AGENTS.md": "# A\nDOC/Absent.md\n"})
    result = run(root)
    assert result.returncode == 1
    assert "lien mort" in result.stderr


def test_d2_version_perimee_detectee_et_corrigee(tmp_path: Path) -> None:
    """AGENTS.md pointait _v1.12 alors que _v1.14 etait la version active."""
    files = {
        "DOC/AF_Partie-09_Fonction_Winch_v1.12.md": "# Winch ancien\n",
        "DOC/AF_Partie-09_Fonction_Winch_v1.14.md": "# Winch actif\n",
        "AGENTS.md": "# A\nVoir DOC/AF_Partie-09_Fonction_Winch_v1.12.md\n",
    }
    root = make(tmp_path, files)
    assert run(root).returncode == 1

    fixed = run(root, "--fix")
    assert fixed.returncode == 0, fixed.stderr
    assert "v1.14" in (root / "AGENTS.md").read_text(encoding="utf-8")
    assert "v1.12" not in (root / "AGENTS.md").read_text(encoding="utf-8")


def test_d3_deux_versions_actives_avertissent(tmp_path: Path) -> None:
    root = make(
        tmp_path,
        {
            "DOC/AF_Partie-06_IO_Conditioning_v1.7.md": "# IO\n",
            "DOC/AF_Partie-06_IO_Conditioning_v1.8.md": "# IO\n",
        },
    )
    result = run(root)
    assert result.returncode == 0  # avertissement, pas blocage
    assert "2 versions actives" in result.stdout


def test_d4_fichier_deplace_est_retrouve(tmp_path: Path) -> None:
    root = make(
        tmp_path,
        {
            "CODE/JOYSTICK/FB_Joystick.st": "FUNCTION_BLOCK FB_Joystick\n",
            "DOC/README.md": "# Doc\nVoir CODE/FB_Joystick.st\n",
        },
    )
    assert run(root).returncode == 1
    assert run(root, "--fix").returncode == 0
    assert "CODE/JOYSTICK/FB_Joystick.st" in (root / "DOC/README.md").read_text(encoding="utf-8")


def test_d6_document_decapite(tmp_path: Path) -> None:
    """REX : NAMING_CONVENTION.md avait perdu titre + principes sans etre vu."""
    root = make(
        tmp_path,
        {"DOC/NAMING_CONVENTION.md": "| `Req` | Requete brute | exemple |\n| `Ref` | Consigne | x |\n"},
    )
    result = run(root)
    assert result.returncode == 1
    assert "sans titre H1" in result.stderr


def test_frontmatter_skill_non_signale(tmp_path: Path) -> None:
    root = make(
        tmp_path,
        {
            "DOC/README.md": "# Doc\n",
            ".claude/skills/x.md": "---\nname: x\n---\n\n# Titre\ncorps\n",
        },
    )
    assert run(root).returncode == 0
