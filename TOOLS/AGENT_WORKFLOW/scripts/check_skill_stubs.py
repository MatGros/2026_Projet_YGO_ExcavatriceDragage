#!/usr/bin/env python3
"""Garde-fou anti-dérive des skills agents (T150-A, pattern stub + canonique).

Principe (cf. AGENTS.md : « une règle écrite deux fois dérive toujours ») :
chaque skill découvrable par un outil (`.claude/skills/*/SKILL.md`, `.dsh/skills/*/SKILL.md`)
doit être soit la source canonique, soit un STUB court qui pointe vers une source canonique.
On ne duplique jamais le contenu complet.

Règles vérifiées :
  1. Tout stub (.claude/.dsh) qui référence un chemin canonique doit le référencer vers un
     fichier qui EXISTE sur disque.
  2. Tout stub doit être court (seuil STUB_MAX_LINES) — une copie complète est une dérive.
  3. AUCUNE copie complète en double entre .claude et .dsh pour une même skill (hash identique
     et longueur > seuil) — signalé comme duplication.

Renvoie 0 si PASS, 1 si au moins un défaut.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

STUB_MAX_LINES = 40
FULL_MIN_LINES = 60  # en-deçà on ne considère pas une "copie complète"
CANONICAL_REF = re.compile(r"TOOLS/AGENT_WORKFLOW/skills/([\w\-]+)/SKILL\.md")


def _hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    errors = 0
    all_skills: dict[str, dict] = {}  # basename skill -> {path, nlines, hash, canonical}
    full_paths: list[Path] = []       # chemins des fichiers considérés "complets" (anti-doublon)

    def scan(prefix: Path, tool: str) -> None:
        nonlocal errors
        if not prefix.exists():
            return
        for sk in prefix.glob("*/SKILL.md"):
            text = sk.read_text(encoding="utf-8", errors="replace")
            nlines = len(text.splitlines())
            m = CANONICAL_REF.search(text)
            canonical = m.group(1) if m else None
            base = sk.parent.name
            all_skills[f"{tool}:{base}"] = {
                "path": sk, "nlines": nlines, "hash": _hash(text), "canonical": canonical,
            }
            if canonical:
                # 1. la canonique pointée doit exister
                canon_path = root / "TOOLS" / "AGENT_WORKFLOW" / "skills" / canonical / "SKILL.md"
                if not canon_path.is_file():
                    print(f"[ERROR] {sk.relative_to(root)}: stub -> canonique inexistante "
                          f"TOOLS/AGENT_WORKFLOW/skills/{canonical}/SKILL.md", file=sys.stderr)
                    errors += 1
                # 2. un stub ne doit pas être une copie complète
                if nlines > STUB_MAX_LINES:
                    print(f"[ERROR] {sk.relative_to(root)}: {nlines} lignes (seuil {STUB_MAX_LINES}) "
                          f"— un stub doit rester court (copie complète = dérive)", file=sys.stderr)
                    errors += 1
            elif nlines >= FULL_MIN_LINES:
                full_paths.append(sk)

    scan(root / ".claude" / "skills", "claude")
    scan(root / ".dsh" / "skills", "dsh")

    # Détection des doublons complets entre .claude et .dsh
    by_hash: dict[str, list] = {}
    for p in full_paths:
        h = _hash(p.read_text(encoding="utf-8", errors="replace"))
        by_hash.setdefault(h, []).append(p)
    for h, paths in by_hash.items():
        if len(paths) > 1:
            names = ", ".join(str(p.relative_to(root)) for p in paths)
            print(f"[ERROR] copie complète dupliquée ({len(paths)} exemplaires, {paths[0].name} lignes) : {names}",
                  file=sys.stderr)
            errors += 1

    print(f"Skill stubs check: {'FAIL' if errors else 'PASS'} ({errors} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
