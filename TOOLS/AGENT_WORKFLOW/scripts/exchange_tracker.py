#!/usr/bin/env python3
"""Suivi des echanges entre sessions (T427 lot 3).

Outille les conventions de T427 v0.3 (section 3) qui n'etaient que du texte :

- **identifiant canonique** : sha256 des 8 champs de la consigne. Deux emissions
  identiques portent le meme id -> idempotence (UC-11).
- **echeance effective** : la date promise dans l accuse `RECU`, sinon l echeance
  de la consigne. Le declenchement porte sur l ABSENCE DE REPONSE : un `RECU`
  sans reponse vaut un silence total (correction du cycle 2).
- **journal par emetteur** : un fichier par emetteur, une sequence propre a
  chacun. Aucune ecriture concurrente sur un meme fichier : le defaut B2 ne se
  reproduit pas dans le remede. La fusion detecte les trous de sequence.

Usage :
  python exchange_tracker.py send --from T427-CC02 --to T000-CC10 --task T427 \
      --objet "..." --demande "..." --preuve "..." --echeance 2026-11-16T10:00+01:00 \
      --ref 27b657
  python exchange_tracker.py ack --task T427 --id <id> --when 2026-11-16T12:00+01:00
  python exchange_tracker.py list --task T427 --overdue 2026-11-17T00:00+01:00

Le suivi est LOCAL au depot : il ne joint aucune session, il ne fait qu ecrire
et relire des traces.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
EXCHANGES = "ECHANGES"

# Les 8 champs du format de consigne (AGENTS.md, « Format d'une consigne »).
FIELDS = ("from", "to", "task", "objet", "demande", "preuve", "echeance", "ref")
KINDS = ("consigne", "recu", "reponse", "clos")
ANSWERED = ("reponse", "clos")


def canonical_id(entry: dict) -> str:
    """Identifiant stable d'une consigne : meme contenu = meme id (UC-11)."""
    payload = "|".join(str(entry.get(field, "")).strip() for field in FIELDS)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:12]


def exchanges_dir(task: str, root: Path | None = None) -> Path:
    return Path(root or ROOT) / "DOC" / "WFLOW" / "TASKS" / str(task) / EXCHANGES


def emitter_path(task: str, emitter: str, root: Path | None = None) -> Path:
    safe = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in str(emitter))
    return exchanges_dir(task, root) / f"{safe}.jsonl"


def _last_seq(path: Path) -> int:
    if not path.is_file():
        return 0
    last = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            last = max(last, int(json.loads(line).get("seq") or 0))
        except (ValueError, TypeError):
            continue
    return last


def append(entry: dict, root: Path | None = None, at: str = "") -> dict:
    """Ajoute un evenement au journal de son emetteur, avec sa sequence propre."""
    kind = str(entry.get("kind") or "")
    if kind not in KINDS:
        raise ValueError(f"kind inconnu : {kind!r} (attendu : {', '.join(KINDS)})")
    task = str(entry.get("task") or "").strip()
    emitter = str(entry.get("from") or "").strip()
    if not task or not emitter:
        raise ValueError("champs obligatoires : task, from")

    record = dict(entry)
    record["kind"] = kind
    record["id"] = str(entry.get("id") or canonical_id(entry))
    record["at"] = at or datetime.now().astimezone().isoformat(timespec="seconds")

    path = emitter_path(task, emitter, root)
    path.parent.mkdir(parents=True, exist_ok=True)
    record["seq"] = _last_seq(path) + 1
    with path.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
    return record


def read_all(task: str, root: Path | None = None) -> list[dict]:
    """Tous les evenements de la tache, tous emetteurs confondus, tries."""
    rows: list[dict] = []
    directory = exchanges_dir(task, root)
    if not directory.is_dir():
        return rows
    for path in sorted(directory.glob("*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except ValueError:
                continue
            row["_emitter_file"] = path.name
            rows.append(row)
    rows.sort(key=lambda row: (str(row.get("at") or ""), int(row.get("seq") or 0)))
    return rows


def gaps(task: str, root: Path | None = None) -> dict[str, list[int]]:
    """Numeros de sequence manquants, par emetteur. Un trou = une perte probable."""
    directory = exchanges_dir(task, root)
    missing: dict[str, list[int]] = {}
    if not directory.is_dir():
        return missing
    for path in sorted(directory.glob("*.jsonl")):
        seen = []
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                seen.append(int(json.loads(line).get("seq") or 0))
            except (ValueError, TypeError):
                continue
        if not seen:
            continue
        trous = [n for n in range(1, max(seen) + 1) if n not in seen]
        if trous:
            missing[path.stem] = trous
    return missing


def _parse(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


def threads(task: str, root: Path | None = None) -> dict[str, dict]:
    """Regroupe les evenements par identifiant de consigne."""
    grouped: dict[str, dict] = {}
    for row in read_all(task, root):
        key = str(row.get("id") or "")
        thread = grouped.setdefault(key, {"id": key, "consigne": None, "recu": None,
                                          "reponse": None, "clos": None})
        kind = str(row.get("kind") or "")
        if kind in thread and thread[kind] is None:
            thread[kind] = row
        elif kind == "recu" and thread["recu"] is None:
            thread["recu"] = row
    return grouped


def effective_deadline(thread: dict) -> str:
    """Echeance effective : la date promise dans RECU, sinon celle de la consigne."""
    recu = thread.get("recu") or {}
    consigne = thread.get("consigne") or {}
    return str(recu.get("when") or consigne.get("echeance") or "").strip()


def overdue(task: str, now: str, root: Path | None = None) -> list[dict]:
    """Echanges sans reponse dont l echeance effective est depassee."""
    instant = _parse(now)
    if instant is None:
        raise ValueError("--overdue attend une date ISO 8601")
    late: list[dict] = []
    for thread in threads(task, root).values():
        consigne = thread.get("consigne")
        if not consigne:
            continue
        if thread.get("reponse") or thread.get("clos"):
            continue
        deadline = _parse(effective_deadline(thread))
        if deadline is None:
            continue
        if instant > deadline:
            late.append({"id": thread["id"], "objet": consigne.get("objet", ""),
                         "to": consigne.get("to", ""), "echeance_effective": deadline.isoformat(),
                         "recu": bool(thread.get("recu"))})
    return late


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Suivi des echanges entre sessions")
    sub = parser.add_subparsers(dest="cmd", required=True)

    send = sub.add_parser("send", help="enregistre une consigne")
    for field in FIELDS:
        send.add_argument(f"--{field}", required=True)
    send.add_argument("--at", default="")

    ack = sub.add_parser("ack", help="enregistre un accuse RECU")
    ack.add_argument("--task", required=True)
    ack.add_argument("--id", required=True)
    ack.add_argument("--from", dest="emitter", required=True)
    ack.add_argument("--when", required=True, help="date promise, ISO 8601")

    listing = sub.add_parser("list", help="etat des echanges")
    listing.add_argument("--task", required=True)
    listing.add_argument("--overdue", default="", help="date ISO 8601 de reference")

    args = parser.parse_args(argv)

    if args.cmd == "send":
        entry = {field: getattr(args, field) for field in FIELDS}
        entry["kind"] = "consigne"
        record = append(entry, at=args.at)
        print(f"CONSIGNE id={record['id']} seq={record['seq']}")
        return 0

    if args.cmd == "ack":
        record = append({"kind": "recu", "from": args.emitter, "task": args.task,
                         "id": args.id, "when": args.when})
        print(f"RECU id={record['id']} seq={record['seq']} promis={args.when}")
        return 0

    late = overdue(args.task, args.overdue) if args.overdue else []
    trous = gaps(args.task)
    print(f"echanges={len(threads(args.task))} en_retard={len(late)} trous={trous or 'aucun'}")
    for item in late:
        marque = "RECU sans reponse" if item["recu"] else "aucun accuse"
        print(f"  [{item['id']}] -> {item['to']} · echeance {item['echeance_effective']} · {marque} · {item['objet']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
