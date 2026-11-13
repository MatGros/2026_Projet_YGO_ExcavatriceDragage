#!/usr/bin/env python3
"""Journal de manquements : ce que la surveillance aurait dû dire (T429, plan §3ter).

Concept : à chaque tour, les mécanismes (hooks, attestation, journal des écritures)
consignent les **signatures** qu'ils ont détectées — un Superviseur muet, un workflow
déclaré mais non entré, une attente annoncée puis violée, une écriture hors périmètre.

Ce journal est un **corpus machine**, pas un rapport : il est relu périodiquement et
transformé en contre-mesures (règles, prompts, détecteurs). Voir T431 (« audits
asynchrones, mémoire sourcée ») pour la revue.

Format : une ligne JSON par signature, par session, plus un journal agrégé.

CLI :
  record --session <id> --kind <M1..Mn> --signature "<texte>" [--evidence "<texte>"]
  list   [--session <id>] [--limit N]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
MISS_DIR = LOCAL_APP / "ExcavatriceDragage" / "misses"
KINDS = {
    "M1": "superviseur muet (erreur ou arret) pendant une session active",
    "M2": "workflow declare actif mais debut non effectue (pas de bandeau, pas de voie)",
    "M3": "ecriture hors perimetre de la tache",
    "M4": "role affirme non ancre dans l'etat du workflow",
    "M5": "attente annoncee puis action quand meme",
    "M6": "attribution inventee (l'agent impute a l'exploitant une action non demandee)",
    "M7": "cause avancee sans preuve",
    "M8": "handoff orphelin (point ecrit dans le mauvais dossier de tache)",
}


def session_log(session_id: str) -> Path:
    return MISS_DIR / f"{session_id}.jsonl"


def all_log() -> Path:
    return MISS_DIR / "all.jsonl"


def record(session_id: str, kind: str, signature: str, evidence: str = "") -> dict:
    entry = {
        "session_id": session_id,
        "kind": kind,
        "kind_label": KINDS.get(kind, "signature inconnue"),
        "signature": str(signature or "")[:500],
        "evidence": str(evidence or "")[:800],
        "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "ts": time.time(),
    }
    try:
        MISS_DIR.mkdir(parents=True, exist_ok=True)
        line = json.dumps(entry, ensure_ascii=False)
        with session_log(session_id).open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")
        with all_log().open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")
    except OSError:
        pass
    return entry


def list_misses(session_id: str | None = None, limit: int = 50) -> list[dict]:
    path = session_log(session_id) if session_id else all_log()
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    entries = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except ValueError:
            continue
    return entries[-limit:] if limit else entries


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p_record = sub.add_parser("record")
    p_record.add_argument("--session", required=True)
    p_record.add_argument("--kind", required=True)
    p_record.add_argument("--signature", default="")
    p_record.add_argument("--evidence", default="")
    p_list = sub.add_parser("list")
    p_list.add_argument("--session", default=None)
    p_list.add_argument("--limit", type=int, default=50)
    args = parser.parse_args(argv)

    if args.command == "record":
        entry = record(args.session, args.kind, args.signature, args.evidence)
        print(f"Manquement consigné : {entry['kind']} — {entry['kind_label']}")
        return 0

    entries = list_misses(args.session, args.limit)
    if not entries:
        print("Aucun manquement consigné.")
        return 0
    counts: dict[str, int] = {}
    for entry in entries:
        counts[entry.get("kind", "?")] = counts.get(entry.get("kind", "?"), 0) + 1
    print("Manquements : " + ", ".join(f"{kind}×{count}" for kind, count in sorted(counts.items())))
    for entry in entries[-10:]:
        print(f"  {entry.get('at')} {entry.get('kind')} {entry.get('signature')[:120]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
