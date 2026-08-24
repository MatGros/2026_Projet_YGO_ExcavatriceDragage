"""Tests de non-regression du gate anti-derive des skills agents (T150-A, stub + canonique).

NB : les fixtures `tmp_path` (sous %TEMP%) sont inaccessibles au sandbox Windows de l'environnement
de dev DSH. On construit donc un arbre de travail dans le workspace sous `tests/.skill_stubs_tmp/`,
nettoyé en fin de test (garde-fou try/finally).
"""

from __future__ import annotations

import importlib.util
import shutil
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_skill_stubs.py"
SPEC = importlib.util.spec_from_file_location("check_skill_stubs", SCRIPT)

check_skill_stubs = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_skill_stubs
SPEC.loader.exec_module(check_skill_stubs)

REPO_ROOT = Path(__file__).resolve().parents[3]
WORK_TMP = Path(__file__).resolve().parent / ".tmp_stubs"


def _make_work() -> Path:
    if WORK_TMP.exists():
        shutil.rmtree(WORK_TMP)
    WORK_TMP.mkdir(parents=True)
    return WORK_TMP


def _stub() -> str:
    return (
        "---\nname: skill-x\ndescription: test\n---\n\n"
        "Stub de test.\n\n"
        "> Charger la canonique : `TOOLS/AGENT_WORKFLOW/skills/skill-x/SKILL.md`\n"
    )


def test_stub_pointant_vers_canonique_existante_passe(monkeypatch) -> None:
    w = _make_work()
    try:
        (w / ".claude" / "skills" / "skill-x").mkdir(parents=True)
        (w / ".claude" / "skills" / "skill-x" / "SKILL.md").write_text(_stub(), encoding="utf-8")
        canon = w / "TOOLS" / "AGENT_WORKFLOW" / "skills" / "skill-x"
        canon.mkdir(parents=True)
        (canon / "SKILL.md").write_text("Contenu canonique complet.\n", encoding="utf-8")
        monkeypatch.setattr(sys, "argv", ["check_skill_stubs.py", str(w)])
        assert check_skill_stubs.main() == 0
    finally:
        shutil.rmtree(w, ignore_errors=True)


def test_stub_pointant_canonique_inexistante_echoue(monkeypatch) -> None:
    w = _make_work()
    try:
        (w / ".claude" / "skills" / "skill-x").mkdir(parents=True)
        (w / ".claude" / "skills" / "skill-x" / "SKILL.md").write_text(_stub(), encoding="utf-8")
        monkeypatch.setattr(sys, "argv", ["check_skill_stubs.py", str(w)])
        assert check_skill_stubs.main() == 1
    finally:
        shutil.rmtree(w, ignore_errors=True)


def test_stub_trop_long_est_signale(monkeypatch) -> None:
    w = _make_work()
    try:
        (w / ".claude" / "skills" / "skill-x").mkdir(parents=True)
        long_stub = _stub() + "\n" + "\n".join(f"# ligne {i} — contenu duplique" for i in range(60))
        (w / ".claude" / "skills" / "skill-x" / "SKILL.md").write_text(long_stub, encoding="utf-8")
        canon = w / "TOOLS" / "AGENT_WORKFLOW" / "skills" / "skill-x"
        canon.mkdir(parents=True)
        (canon / "SKILL.md").write_text("Contenu canonique complet.\n", encoding="utf-8")
        monkeypatch.setattr(sys, "argv", ["check_skill_stubs.py", str(w)])
        assert check_skill_stubs.main() == 1
    finally:
        shutil.rmtree(w, ignore_errors=True)


def test_doublon_complet_claude_dsh_est_une_erreur(monkeypatch) -> None:
    w = _make_work()
    try:
        full = "\n".join(f"# ligne {i} du contenu complet" for i in range(80))
        for tool in ("claude", "dsh"):
            d = w / f".{tool}" / "skills" / "skill-x"
            d.mkdir(parents=True)
            (d / "SKILL.md").write_text(full, encoding="utf-8")
        monkeypatch.setattr(sys, "argv", ["check_skill_stubs.py", str(w)])
        assert check_skill_stubs.main() == 1
    finally:
        shutil.rmtree(w, ignore_errors=True)


def test_repo_reel_ne_regresse_pas(monkeypatch) -> None:
    """Preuve sur le depot reel : le pilote troubleshooting est conforme (stub + canonique)."""
    monkeypatch.setattr(sys, "argv", ["check_skill_stubs.py", str(REPO_ROOT)])
    assert check_skill_stubs.main() == 0
