"""Garde-fous P2 (T427 lot 2) : les ecritures par commande shell passent par le garde.

Trou : `hook_scope_guard.py` n'est branche que sur `Edit|Write|MultiEdit`, donc
`> CODE/x.st`, `Set-Content` ou `git apply` contournaient la deny-list. Ce hook la
referme pour `Bash` et `PowerShell`, sur la seule deny-list globale.
"""
import io
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import hook_shell_scope_guard as guard  # noqa: E402


def _decision(command: str) -> str:
    return str(guard.evaluate(command)["decision"])


@pytest.mark.parametrize("command", [
    "echo x > CODE/M_MAIN/PRG_00_Init.st",
    "echo x >> CODE_XML/CODE_Bundle.xml",
    "Set-Content -Path CODE/A_COMMUN/FB_X.st -Value 1",
    "Out-File CODE/A_COMMUN/FB_X.st",
    "cp /tmp/src.st CODE/A_COMMUN/FB_X.st",
    "rm -rf CODE/A_COMMUN",
    "echo x > .claude/settings.json",
    "Set-Content TOOLS/AGENT_WORKFLOW/scripts/task_scope.py -Value 1",
    "echo x > PRJ_CODESYS/PRJ.project",
])
def test_ecriture_sur_chemin_protege_refusee(command: str) -> None:
    assert _decision(command) == "block"


@pytest.mark.parametrize("command", [
    "cat CODE/M_MAIN/PRG_00_Init.st",
    "grep -rn FB_Winch CODE/",
    "git status -- CODE/",
    "cp CODE/A_COMMUN/FB_X.st /tmp/copie.st",
    "ls -la CODE",
    "python -m pytest TOOLS/AGENT_WORKFLOW/tests -q",
])
def test_lecture_ou_ecriture_hors_deny_non_bloquee(command: str) -> None:
    assert _decision(command) == "allow"


def test_git_apply_sur_patch_qui_touche_code_refuse(tmp_path) -> None:
    patch = tmp_path / "p.patch"
    patch.write_text("--- a/CODE/A_COMMUN/FB_X.st\n+++ b/CODE/A_COMMUN/FB_X.st\n",
                     encoding="utf-8")
    assert _decision(f"git apply {patch.as_posix()}") == "block"


def test_git_apply_sur_patch_documentaire_autorise(tmp_path) -> None:
    patch = tmp_path / "d.patch"
    patch.write_text("--- a/DOC/x.md\n+++ b/DOC/x.md\n", encoding="utf-8")
    assert _decision(f"git apply {patch.as_posix()}") == "allow"


def _run(monkeypatch, payload: dict) -> int:
    monkeypatch.setattr(sys, "stdin", io.StringIO(json.dumps(payload)))
    return guard.main()


def test_outil_non_shell_laisse_passer(monkeypatch) -> None:
    code = _run(monkeypatch, {"tool_name": "Edit", "tool_input": {"file_path": "CODE/x.st"}})
    assert code == 0


def test_commande_interdite_bloque(monkeypatch, capsys) -> None:
    code = _run(monkeypatch, {"tool_name": "PowerShell", "session_id": "",
                              "tool_input": {"command": "echo x > CODE/x.st"}})
    assert code == 2
    assert "ECRITURE INTERDITE" in capsys.readouterr().err


def test_mode_report_ne_bloque_pas(monkeypatch, capsys) -> None:
    monkeypatch.setenv("TASK_SCOPE_GUARD", "report")
    code = _run(monkeypatch, {"tool_name": "Bash", "session_id": "",
                              "tool_input": {"command": "echo x > CODE/x.st"}})
    assert code == 0
    assert "ECRITURE INTERDITE" in capsys.readouterr().err


def test_entree_illisible_laisse_passer(monkeypatch) -> None:
    monkeypatch.setattr(sys, "stdin", io.StringIO("pas du json"))
    assert guard.main() == 0
