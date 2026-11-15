"""Hook UserPromptSubmit (Claude Code) : fiche de connaissance minimale, une fois par session.

Affiche une fiche courte (environ 10 lignes) au premier message d'une session.
Ne lit aucun document en entier. Ne bloque jamais (fail-open : toute erreur = silence).

Légende des marqueurs (une case chacun, sans emoji, pour rester sélectionnable) :
  ● OK, validé      ▲ attention, à vérifier      ■ bloqué, ne pas toucher
  ◆ information     → étape suivante
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SUMMARY = REPO / "DOC" / "WFLOW" / "TASKS_ACTIVE_SUMMARY.md"
TASKS = REPO / "DOC" / "WFLOW" / "TASKS.yaml"

_EMOJI_RE = re.compile("[\U0001F000-\U0001FAFF☀-➿⌀-⏿⬀-⯿️‍]+")


def _flag_dir() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / ".cache")
    return Path(base) / "ExcavatriceDragage" / "workflow" / "brief"


def _summary_state() -> str:
    """Compare l'empreinte de TASKS.yaml à celle inscrite dans le résumé."""
    try:
        head = SUMMARY.read_text(encoding="utf-8").splitlines()[1]
        expected = head.split("sha256(TASKS.yaml)=", 1)[1].split(" ", 1)[0]
        actual = hashlib.sha256(TASKS.read_bytes()).hexdigest()
        return "à jour" if actual == expected else "PÉRIMÉ"
    except Exception:
        return "absent"


def _counters() -> str:
    try:
        for line in SUMMARY.read_text(encoding="utf-8").splitlines():
            if line.startswith("**Compteurs**"):
                return line.replace("**Compteurs** : ", "").strip()
    except Exception:
        pass
    return "indisponibles"


def _clean(text: str) -> str:
    """Garde-fou : retire tout emoji résiduel."""
    return _EMOJI_RE.sub("", text)


def build_brief() -> str:
    lines = [
        "◆ FICHE PROJET (1re réponse de cette session)",
        f"● Lu par le hook : TASKS_ACTIVE_SUMMARY.md (empreinte {_summary_state()}).",
        "▲ À citer dans ta réponse : les documents lus, avec l'heure.",
        "◆ Projet : automate CODESYS 3.5, machine de dragage (sécurité machine réelle).",
        f"◆ Catalogue : {_counters()}.",
        "◆ Rôle : aucun pour l'instant (pas de commande de lancement).",
        "→ Commandes utiles :",
        "    /workflow-project-orchestrator ou /workflow-project-coordinator : démarrage guidé (tâche, dépannage, cadrage)",
        "    « état des tâches » : lecture du catalogue",
        "    « cherche le blocage » : dépannage",
        "    /connect-session-supervisor : rattacher la session au Superviseur",
        "    /review-session-supervisor : examiner les constats ouverts",
        "    /rename-session <Txxx-ACTEUR> <titre> : renommer la session",
    ]
    return _clean("\n".join(lines))


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except Exception:
        payload = {}
    session_id = str(payload.get("session_id") or "").strip()
    if not session_id:
        return 0  # sans identifiant, pas de déduplication possible : silence
    try:
        flag_dir = _flag_dir()
        flag_dir.mkdir(parents=True, exist_ok=True)
        flag = flag_dir / f"{session_id}.flag"
        if flag.exists():
            return 0
        flag.write_text("1", encoding="utf-8")
        text = (build_brief() + "\n").encode("utf-8")
        out = getattr(sys.stdout, "buffer", None)
        if out is not None:
            out.write(text)
            out.flush()
        else:
            sys.stdout.write(text.decode("utf-8"))
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
