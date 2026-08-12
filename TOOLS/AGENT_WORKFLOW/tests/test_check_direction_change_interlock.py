"""Tests de non-regression du gate interlock changement de sens (REX 2026-08-05, translation M3)."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G360_check_direction_change_interlock.py"
SPEC = importlib.util.spec_from_file_location("G360_check_direction_change_interlock", SCRIPT)

check_direction_change_interlock = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_direction_change_interlock
SPEC.loader.exec_module(check_direction_change_interlock)

REPO_ROOT = Path(__file__).resolve().parents[3]


def test_fb_avec_commandeddirection_sans_directionchangepending_est_une_erreur(tmp_path, monkeypatch) -> None:
    code_dir = tmp_path / "CODE" / "TEST"
    code_dir.mkdir(parents=True)
    (code_dir / "FB_Broken.st").write_text(
        "FUNCTION_BLOCK FB_Broken\nVAR\n    CommandedDirection : INT;\nEND_VAR\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["G360_check_direction_change_interlock.py", str(tmp_path)])
    assert check_direction_change_interlock.main() == 1


def test_fb_avec_les_deux_variables_passe(tmp_path, monkeypatch) -> None:
    code_dir = tmp_path / "CODE" / "TEST"
    code_dir.mkdir(parents=True)
    (code_dir / "FB_Ok.st").write_text(
        "FUNCTION_BLOCK FB_Ok\nVAR\n    CommandedDirection : INT;\n"
        "    DirectionChangePending : BOOL;\nEND_VAR\n"
        "DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["G360_check_direction_change_interlock.py", str(tmp_path)])
    assert check_direction_change_interlock.main() == 0


def test_fb_sans_commandeddirection_nest_pas_concerne(tmp_path, monkeypatch) -> None:
    code_dir = tmp_path / "CODE" / "TEST"
    code_dir.mkdir(parents=True)
    (code_dir / "FB_Unrelated.st").write_text(
        "FUNCTION_BLOCK FB_Unrelated\nVAR\n    SomeVar : BOOL;\nEND_VAR\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["G360_check_direction_change_interlock.py", str(tmp_path)])
    assert check_direction_change_interlock.main() == 0


def test_codebase_reelle_ne_regresse_pas(monkeypatch) -> None:
    """Preuve de non-regression : FB_Winch et FB_Translation portent bien le pattern."""
    monkeypatch.setattr(sys, "argv", ["G360_check_direction_change_interlock.py", str(REPO_ROOT)])
    assert check_direction_change_interlock.main() == 0
