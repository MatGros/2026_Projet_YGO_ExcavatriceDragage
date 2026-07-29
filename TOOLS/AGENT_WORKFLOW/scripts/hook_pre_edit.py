#!/usr/bin/env python3
"""Hook PreToolUse : interdit d'ecrire dans CODE/ sans avoir lu les regles.

Classe de bug couverte (audit 2026-07-29) : `pre_edit_gate.py` fonctionnait par
`--mark-read`, c'est-a-dire que l'agent se certifiait LUI-MEME d'avoir lu les
specs. Il pouvait lancer la commande sans rien lire, et il n'etait branche a
aucun hook. Un garde-fou que le fautif peut cocher lui-meme n'en est pas un.

Ici la preuve n'est pas declarative : on relit le TRANSCRIPT de la session et on
exige un vrai appel a l'outil `Read` sur les documents requis. L'agent ne peut
pas la falsifier sans reellement lire.

Documents exiges :
  * toujours  : CODE_QUALITY_STANDARDS (declaration, liaison, POO) + NAMING_CONVENTION
  * selon le dossier CODE/ touche : la spec metier active, resolue automatiquement
    (aucun numero de version en dur — c'est ce qui pourrissait l'ancien gate)

Ne s'applique QU'AUX ecritures dans `CODE/**/*.st`. Tout le reste passe.
Echec d'infrastructure (transcript illisible) = on laisse passer : on ne bloque
jamais le travail sur un probleme d'outillage.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / "DOC"

VERSIONED = re.compile(r"^AF_Partie-(?P<num>\d{2})_.+_v(?P<major>\d+)\.(?P<minor>\d+)\.md$")

ALWAYS_REQUIRED = ["DOC/CODE_QUALITY_STANDARDS.md", "DOC/NAMING_CONVENTION.md"]

# Dossier reel de CODE/ -> numeros de partie AF a avoir lus.
# Aucune VERSION ici : elle est resolue au moment du controle.
SPEC_MAP: dict[str, list[int]] = {
    "CODE/AU/": [1, 3],
    "CODE/CODEURS/": [10, 3],
    "CODE/COMMUN/": [3, 6],
    "CODE/CYCLE/": [4],
    "CODE/DIAG/": [2],
    "CODE/JOYSTICK/": [8],
    "CODE/MAIN/": [2, 6],
    "CODE/MODES/": [5],
    "CODE/SIMULATION/": [13],
    "CODE/SUPERVISION/": [7],
    "CODE/TESTS/": [3],
    "CODE/TRANSLATION/": [11, 3],
    "CODE/TREUILS/": [9, 3, 12],
}


def latest_spec(partie: int) -> str | None:
    best: tuple[tuple[int, int], str] | None = None
    for entry in DOC.glob("*.md"):
        match = VERSIONED.match(entry.name)
        if not match or int(match.group("num")) != partie:
            continue
        version = (int(match.group("major")), int(match.group("minor")))
        if best is None or version > best[0]:
            best = (version, f"DOC/{entry.name}")
    return best[1] if best else None


def required_specs(target: str) -> list[str]:
    required = list(ALWAYS_REQUIRED)
    for prefix, parties in SPEC_MAP.items():
        if target.startswith(prefix):
            for partie in parties:
                spec = latest_spec(partie)
                if spec and spec not in required:
                    required.append(spec)
    return required


def files_actually_read(transcript: Path) -> set[str]:
    """Chemins passes a l'outil Read dans cette session — preuve non falsifiable."""
    seen: set[str] = set()
    try:
        with transcript.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if '"Read"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                for block in _tool_uses(entry):
                    if block.get("name") != "Read":
                        continue
                    path = (block.get("input") or {}).get("file_path")
                    if path:
                        seen.add(str(path).replace("\\", "/"))
    except OSError:
        return set()
    return seen


def _tool_uses(entry: dict):
    message = entry.get("message") or {}
    content = message.get("content")
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                yield block


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("tool_name") not in {"Edit", "Write", "MultiEdit"}:
        return 0

    target = str((payload.get("tool_input") or {}).get("file_path") or "").replace("\\", "/")
    if not target.endswith(".st"):
        return 0

    try:
        relative = Path(target).resolve().relative_to(ROOT).as_posix()
    except (ValueError, OSError):
        relative = target
    if not relative.startswith("CODE/"):
        return 0

    required = required_specs(relative)

    transcript = payload.get("transcript_path")
    if not transcript:
        return 0  # infrastructure : pas de preuve disponible, on ne bloque pas
    read = files_actually_read(Path(transcript))
    if not read:
        return 0  # transcript illisible : idem

    missing = [spec for spec in required if not any(r.endswith(spec) for r in read)]
    if not missing:
        return 0

    print(
        f"Ecriture refusee dans {relative} : les regles applicables n'ont pas ete lues "
        f"dans cette session.\n\n"
        "A lire avec l'outil Read avant d'ecrire :\n"
        + "\n".join(f"  - {spec}" for spec in missing)
        + "\n\nCe controle relit le transcript : le declarer lu ne suffit pas, "
        "il faut l'avoir ouvert.",
        file=sys.stderr,
    )
    return 2  # refuse l'appel d'outil, le message revient a l'agent


if __name__ == "__main__":
    raise SystemExit(main())
