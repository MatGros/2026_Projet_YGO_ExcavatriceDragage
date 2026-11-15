#!/usr/bin/env python3
"""Registre des GO (T427, constat de revue n°2).

Un « GO » verbal se perd. L'interim des consignes agent (GO + copie datee dans le
dossier de tache) fonctionne, mais ne permet pas de repondre a « qui a donne quoi,
quand ». Ce registre est **append-only** : aucune entree n'est modifiee ni
supprimee, un GO retire est un nouvel evenement.

Champs obligatoires : task, emitter, ref, perimetre, text.
`ref` = l'identifiant du message de l'exploitant (horodatage, numero, citation
courte). Sans `ref`, l'entree est refusee : un GO non rattachable a un message
n'est pas un GO trace.

Usage :
  python go_registry.py add --task T427 --emitter exploitant \\
      --ref "2026-11-15 04:20 GO P1" --perimetre "garde de perimetre" --text "GO P1"
  python go_registry.py list --task T427
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
FILENAME = "GO_REGISTRY.jsonl"
REQUIRED = ("task", "emitter", "ref", "perimetre", "text")


def registry_path(task: str, root: Path | None = None) -> Path:
    return Path(root or ROOT) / "DOC" / "WFLOW" / "TASKS" / str(task) / FILENAME


def entries(task: str, root: Path | None = None) -> list[dict]:
    path = registry_path(task, root)
    if not path.is_file():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def record(entry: dict, root: Path | None = None, at: str = "") -> dict:
    """Ajoute un GO. Append-only : aucune reecriture, sequence croissante."""
    missing = [field for field in REQUIRED if not str(entry.get(field) or "").strip()]
    if missing:
        raise ValueError(f"champs obligatoires manquants : {', '.join(missing)}")

    task = str(entry["task"]).strip()
    rows = entries(task, root)
    item = {field: str(entry[field]).strip() for field in REQUIRED}
    item["seq"] = len(rows) + 1
    item["at"] = at or datetime.now().astimezone().isoformat(timespec="seconds")

    path = registry_path(task, root)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n")
    return item


def find(task: str, ref: str, root: Path | None = None) -> list[dict]:
    """GO dont la reference contient `ref` (recherche textuelle, casse ignoree)."""
    needle = str(ref).strip().lower()
    return [row for row in entries(task, root) if needle in str(row.get("ref", "")).lower()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Registre des GO (append-only)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    add = sub.add_parser("add", help="enregistre un GO")
    add.add_argument("--task", required=True)
    add.add_argument("--emitter", required=True)
    add.add_argument("--ref", required=True, help="identifiant du message d'origine")
    add.add_argument("--perimetre", required=True)
    add.add_argument("--text", required=True)
    add.add_argument("--at", default="")

    listing = sub.add_parser("list", help="liste les GO d'une tache")
    listing.add_argument("--task", required=True)

    args = parser.parse_args(argv)

    if args.cmd == "add":
        item = record({"task": args.task, "emitter": args.emitter, "ref": args.ref,
                       "perimetre": args.perimetre, "text": args.text}, at=args.at)
        print(f"GO seq={item['seq']} tache={item['task']} ref={item['ref']}")
        return 0

    rows = entries(args.task)
    print(f"GO enregistres pour {args.task} : {len(rows)}")
    for row in rows:
        print(f"  {row['seq']:>2} · {row['at']} · {row['emitter']} · {row['perimetre']} · {row['ref']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
