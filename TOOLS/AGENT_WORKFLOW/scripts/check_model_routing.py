#!/usr/bin/env python3
"""Garde-fou du routage modele : verifie a posteriori QUI a reellement travaille.

Classe de bug couverte (audit 2026-07-29) : `MODEL_ROUTING.md` annoncait
`omni/cc/claude-sonnet-5` comme modele de revue privilegie. Les 53 taches
reellement executees montraient `omni/cx/gpt-5.6-terra` en tete (18x). Une regle
de routage ecrite mais jamais verifiee ne route rien.

La preuve existe deja dans le depot : chaque `.pi-subagents/artifacts/*_meta.json`
enregistre le modele reellement execute. Ce script la lit.

Deux notions a ne pas confondre :
  * FAMILLE rapide (flash, mini, nano, haiku) = petit modele, concu pour la vitesse ;
  * EFFORT reduit (`:low`) = gros modele bride.
Un `scout` qui repere des fichiers ne juge rien : les deux lui vont. Un `reviewer`
juge : la famille rapide lui est interdite, l'effort reduit est signale.

Controles :
  M1  famille rapide sur un role de jugement (worker/reviewer/oracle)
  M2  effort reduit sur un role de jugement (gros modele bride pour juger)
  M4  modele inconnu du catalogue (routage non maitrise)

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_model_routing.py
  python TOOLS/AGENT_WORKFLOW/scripts/check_model_routing.py --inventory
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

# FAMILLE rapide : excellente pour reperer, resumer, debroussailler.
# Jamais pour juger. Meme traitement que Ponytail, deja banni du safety.
FAST_FAMILY = re.compile(r"(flash|mini|nano|haiku)", re.IGNORECASE)
# EFFORT reduit : gros modele bride. Legitime en reconnaissance, discutable en jugement.
LOW_EFFORT = re.compile(r":low\b", re.IGNORECASE)

# Roles ou un modele rapide est legitime : reconnaissance et collecte.
FAST_ALLOWED_ROLES = {"scout", "researcher"}

# Roles de jugement : analyse, production, revue. Modele fort obligatoire.
JUDGEMENT_ROLES = {"reviewer", "oracle", "worker"}

# Catalogue des fournisseurs connus. Un modele hors catalogue signale un
# routage non maitrise, pas forcement une faute.
KNOWN_PROVIDERS = ("omni/", "nvidia/", "antigravity/", "gh/", "openrouter/", "ollama/")

SAFETY_HINTS = re.compile(
    r"\b(safety|safestop|powercutoff|interlock|frein|brake|contacteur|"
    r"arret d'urgence|redondance|C4)\b",
    re.IGNORECASE,
)


def meta_files(root: Path) -> list[Path]:
    return sorted((root / ".pi-subagents" / "artifacts").glob("*_meta.json"))


def read_meta(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except (json.JSONDecodeError, OSError):
        return {}


def model_of(meta: dict) -> str:
    return str(
        meta.get("model")
        or meta.get("modelId")
        or (meta.get("config") or {}).get("model")
        or ""
    )


def role_of(meta: dict) -> str:
    return str(meta.get("agent") or meta.get("role") or "").lower()


def task_text(path: Path) -> str:
    """Enonce de la tache, pour deviner si le sujet est safety."""
    candidate = Path(str(path).replace("_meta.json", "_input.md"))
    if candidate.is_file():
        return candidate.read_text(encoding="utf-8", errors="replace")
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--inventory", action="store_true", help="Lister le routage observe et sortir")
    args = parser.parse_args()

    root = args.root.resolve()
    files = meta_files(root)
    if not files:
        print("Model routing check: PASS (aucun artefact Pi a analyser)")
        return 0

    errors: list[str] = []
    warnings: list[str] = []
    inventory: Counter[tuple[str, str]] = Counter()

    for path in files:
        meta = read_meta(path)
        model, role = model_of(meta), role_of(meta)
        if not model:
            continue
        inventory[(role or "?", model)] += 1

        judges = role in JUDGEMENT_ROLES

        # M1 — famille rapide sur un role de jugement
        if FAST_FAMILY.search(model) and judges:
            safety = bool(SAFETY_HINTS.search(task_text(path)))
            suffix = " Sujet SAFETY : interdiction absolue." if safety else ""
            errors.append(
                f"[M1] {path.name}: role `{role}` execute sur `{model}` (famille rapide). "
                f"Les roles de jugement exigent un modele fort ; la famille rapide est "
                f"reservee a {', '.join(sorted(FAST_ALLOWED_ROLES))}.{suffix}"
            )

        # M2 — effort reduit sur un role de jugement (signale, pas bloquant)
        elif LOW_EFFORT.search(model) and judges:
            warnings.append(
                f"[M2] {path.name}: role `{role}` execute sur `{model}` — gros modele bride "
                f"pour une tache de jugement. Verifier que c'etait voulu."
            )

        # M4 — fournisseur hors catalogue
        if not model.startswith(KNOWN_PROVIDERS):
            warnings.append(f"[M4] {path.name}: modele hors catalogue `{model}` — routage non maitrise")

    if args.inventory:
        print("Routage observe (role x modele) :")
        for (role, model), count in inventory.most_common():
            print(f"  {count:3}x  {role:12} {model}")
        return 0

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(
        f"\nModel routing check: {'FAIL' if errors else 'PASS'} "
        f"({len(errors)} erreur(s), {len(warnings)} avertissement(s), "
        f"{len(files)} artefact(s) analyse(s))"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
