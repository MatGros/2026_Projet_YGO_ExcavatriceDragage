#!/usr/bin/env python3
"""Checkpoint de progression des sous-agents (fichiers d'etat partages).

Objectif (demande "tous les agents remontent leurs etats ~10s") :
contourner la limite de fond des agents LLM -- un sous-agent ne bat pas un
heartbeat 5s natif, il travaille par tours (penser -> outil -> attendre ->
penser ...). Un tour dure souvent 10-60s+. Ce script fournit donc un
**checkpoint explicite** : chaque agent append une ligne d'etat dans un
fichier partage a chaque etape. L'orchestrateur / l'humain suit en direct
via `watch`.

Deux sous-commandes :
  record  Agent (ou orchestrateur) : append une ligne d'etat.
  watch   Suivi en direct (tail) d'un ou tous les fichiers d'etat.
  init    Cree le dossier status/ (idempotent).

Les fichiers vivent dans <projet>/TOOLS/AGENT_WORKFLOW/status/ (git-ignore),
nommes  status/<session>.log  -- session = identifiant unique du sous-agent
ou du lot (ex. "tache-AF08", "PRG_04", date-heure).

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <session> <etape> <etat> [--msg "..." ] [--root PROJECT]
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch [session] [--root PROJECT] [--no-follow]
  python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py init [--root PROJECT]
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime
from pathlib import Path


def status_dir(root: Path) -> Path:
    return (root / "TOOLS" / "AGENT_WORKFLOW" / "status").resolve()


def resolve_root(root: str) -> Path:
    p = Path(root).resolve()
    if not (p / "TOOLS" / "AGENT_WORKFLOW").is_dir():
        # remonter vers la racine projet si lance depuis un sous-dossier
        for cand in p.parents:
            if (cand / "TOOLS" / "AGENT_WORKFLOW").is_dir():
                return cand
        print(f"[ERROR] racine projet introuvable depuis {p} "
              f"(pas de TOOLS/AGENT_WORKFLOW)", file=sys.stderr)
        sys.exit(2)
    return p


def now() -> str:
    return datetime.now().strftime("%H:%M:%S")


def cmd_init(args) -> int:
    d = status_dir(resolve_root(args.root))
    (d / ".gitkeep").parent.mkdir(parents=True, exist_ok=True)
    print(f"[OK] dossier d'etat pret : {d}")
    return 0


def cmd_record(args) -> int:
    d = status_dir(resolve_root(args.root))
    d.mkdir(parents=True, exist_ok=True)
    # nom de session -> fichier sur
    session = args.session.replace("/", "_").replace("\\", "_")
    log = d / f"{session}.log"
    msg = f" {args.msg}" if args.msg else ""
    line = f"{now()} [{args.agent}] {args.etape} -> {args.etat}{msg}"
    with open(log, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(f"[logged] {log.name}: {line}")
    return 0


def _tail(path: Path, from_byte: int) -> int:
    with open(path, encoding="utf-8", errors="replace") as f:
        f.seek(from_byte)
        data = f.read()
        if data:
            sys.stdout.write(data)
            if not data.endswith("\n"):
                sys.stdout.write("\n")
            sys.stdout.flush()
        return f.tell()


def cmd_watch(args) -> int:
    d = status_dir(resolve_root(args.root))
    # fichiers cibles
    if args.session:
        targets = [d / f"{args.session.replace('/', '_').replace(chr(92), '_')}.log"]
    else:
        targets = sorted(d.glob("*.log")) if d.is_dir() else []
    if not targets:
        print("[INFO] aucun fichier d'etat pour l'instant "
              "(les agents n'ont pas encore journalise).")
        if args.no_follow:
            return 0
        print("[INFO] en attente... Ctrl+C pour quitter.")

    offsets = {p: 0 for p in targets}
    try:
        while True:
            for p in list(offsets):
                if p.is_file():
                    offsets[p] = _tail(p, offsets[p])
            if args.no_follow:
                return 0
            time.sleep(1.0)
    except KeyboardInterrupt:
        print("\n[stop] suivi termine.")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    pr = sub.add_parser("record", help="append une ligne d'etat")
    pr.add_argument("--root", default=".",
                    help="racine projet (auto-resolue si en sous-dossier)")
    pr.add_argument("session")
    pr.add_argument("etape", help="nom de l'etape (ex. lecture-spec, generation-bundle)")
    pr.add_argument("etat", help="en_cours | ok | fail | attente_validation ...")
    pr.add_argument("--agent", default=os.environ.get("AGENT_NAME", "agent"))
    pr.add_argument("--msg")

    pw = sub.add_parser("watch", help="suivi en direct d'un ou tous les fichiers")
    pw.add_argument("--root", default=".",
                    help="racine projet (auto-resolue si en sous-dossier)")
    pw.add_argument("session", nargs="?")
    pw.add_argument("--no-follow", action="store_true",
                    help="affiche l'etat courant puis sort (ne boucle pas)")

    pi = sub.add_parser("init", help="cree le dossier status/ (idempotent)")
    pi.add_argument("--root", default=".",
                    help="racine projet (auto-resolue si en sous-dossier)")

    args = parser.parse_args()
    if args.cmd == "record":
        return cmd_record(args)
    if args.cmd == "watch":
        return cmd_watch(args)
    if args.cmd == "init":
        return cmd_init(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
