"""Coherence des commandes de role (T427, constat de revue n°3).

`ROLE.md` et `COORDINATOR.md` annoncent des commandes dediees. Ce test verifie
qu'elles existent reellement et qu'elles passent par le script canonique : une
documentation qui promet une commande inexistante est un defaut, pas un detail
(un utilisateur a signale « je n'ai toujours pas acces a workflow-orchestrator »).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
COMMANDS = ROOT / ".claude" / "commands"
SKILLS = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "skills"
CANONICAL = "workflow_state.py"
CITED = re.compile(r"/workflow-[a-z-]+")

ROLE_COMMANDS = (("workflow-project-orchestrator", "cmd 1"),
                 ("workflow-project-coordinator", "cmd 2"))


def _cited_commands() -> set[str]:
    cited: set[str] = set()
    for path in SKILLS.glob("*/*.md"):
        cited.update(m.group(0).lstrip("/") for m in CITED.finditer(path.read_text(encoding="utf-8")))
    return cited


def test_toute_commande_citee_existe() -> None:
    """Aucune doc de skill ne doit citer une commande absente de `.claude/commands/`."""
    missing = sorted(name for name in _cited_commands() if not (COMMANDS / f"{name}.md").is_file())
    assert missing == [], f"commandes citees mais absentes : {missing}"


def test_commandes_de_role_appellent_le_script_canonique() -> None:
    for name, voie in ROLE_COMMANDS:
        text = (COMMANDS / f"{name}.md").read_text(encoding="utf-8")
        assert CANONICAL in text, f"{name} ne passe pas par le script canonique"
        assert voie in text, f"{name} ne selectionne pas la voie « {voie} »"


def test_commandes_de_role_entrent_avant_de_choisir() -> None:
    """Sans entree prealable, la voie ne peut pas etre selectionnee (etat non actif)."""
    for name, _ in ROLE_COMMANDS:
        text = (COMMANDS / f"{name}.md").read_text(encoding="utf-8")
        assert "enter resume" in text, f"{name} doit entrer dans le workflow avant de choisir"
        assert text.index("enter resume") < text.index("cmd "), f"{name} : ordre inverse"
