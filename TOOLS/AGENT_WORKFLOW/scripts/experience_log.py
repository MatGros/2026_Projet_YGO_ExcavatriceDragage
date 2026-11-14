#!/usr/bin/env python3
"""Journal d'EXPERIENCE par poste de traitement (demande exploitant 2026-11-13).

Le journal de manquements (miss_log) dit ce que la surveillance aurait du dire.
Ce journal dit ce que chaque POSTE a appris : un pattern d'echanges qui a mene a un
echec, une incomprehension, une fin de tour, et l'hypothese de correction.

Postes : le juge / le superviseur, chaque agent (CC01, AGY01, ...), le plugin,
l'IHM, l'exploitant. Un poste ecrit SA propre experience ; le superviseur ecrit
lui-meme ce qu'il a observe chez les autres.

Entree : poste, type (constat | auto-retrospective), pattern (ce qui s est enchaine),
hypothese (pourquoi), action (ce qu on propose de changer : prompt, program, regle),
refs (les sources : event_id, fichier, ligne), et la session concernee.

C'est un CORPUS machine : il est relu periodiquement pour.update les regles.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
EXPERIENCE_DIR = LOCAL_APP / "ExcavatriceDragage" / "experience"
POSTES = ("superviseur", "juge", "exploitant", "plugin", "ihm", "agent")

TYPES = ("constat", "auto-retrospective", "proposition", "incident")


def log_path(session_id: str) -> Path:
    safe = "".join(c for c in str(session_id or "global") if c.isalnum() or c in "-_")[:80]
    return EXPERIENCE_DIR / f"{safe}.jsonl"


def all_log() -> Path:
    return EXPERIENCE_DIR / "all.jsonl"


def write(poste: str, type_: str, pattern: str, hypothese: str = "", action: str = "",
          session_id: str = "", refs=None) -> dict:
    """Ecrit une experience. Refuse les entrees vides (une experience sans motif ne sert a rien)."""
    poste = str(poste or "").strip().lower()
    type_ = str(type_ or "").strip().lower()
    pattern = str(pattern or "").strip()
    if not poste or not pattern:
        raise ValueError("poste et pattern obligatoires : une experience sans motif ne sert a rien")
    if type_ not in TYPES:
        type_ = "constat"
    entry = {
        "poste": poste,
        "type": type_,
        "pattern": pattern[:2000],
        "hypothese": str(hypothese or "").strip()[:1000],
        "action": str(action or "").strip()[:1000],
        "session_id": str(session_id or ""),
        "refs": [str(ref)[:200] for ref in (refs or [])][:20],
        "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "ts": time.time(),
    }
    try:
        EXPERIENCE_DIR.mkdir(parents=True, exist_ok=True)
        line = json.dumps(entry, ensure_ascii=False)
        with log_path(session_id).open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")
        with all_log().open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")
    except OSError:
        pass
    return entry


def read(session_id: str | None = None, poste: str | None = None, limit: int = 200) -> list:
    path = log_path(session_id) if session_id else all_log()
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
            entry = json.loads(line)
        except ValueError:
            continue
        if poste and str(entry.get("poste")) != str(poste).lower():
            continue
        entries.append(entry)
    return entries[-limit:] if limit else entries


def review(limit: int = 50) -> str:
    """Revue : ce que chaque poste a appris, et les hypotheses recurrentes."""
    entries = read(limit=0)
    if not entries:
        return "Aucune experience consignee."
    par_poste = Counter(entry.get("poste", "?") for entry in entries)
    par_type = Counter(entry.get("type", "?") for entry in entries)
    lignes = [
        "Postes : " + ", ".join(f"{poste}={count}" for poste, count in sorted(par_poste.items())),
        "Types : " + ", ".join(f"{type_}={count}" for type_, count in sorted(par_type.items())),
        "",
    ]
    for poste in sorted(par_poste):
        lignes.append(f"── {poste}")
        for entry in [e for e in entries if e.get("poste") == poste][-limit:]:
            lignes.append(f"   [{entry.get('type')}] {entry.get('pattern')[:160]}")
            if entry.get("hypothese"):
                lignes.append(f"       hypothese : {entry['hypothese'][:200]}")
            if entry.get("action"):
                lignes.append(f"       action    : {entry['action'][:200]}")
            if entry.get("refs"):
                lignes.append(f"       refs      : {', '.join(str(r)[:80] for r in entry['refs'][:5])}")
    return "\n".join(lignes)


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p_write = sub.add_parser("write")
    p_write.add_argument("--poste", required=True)
    p_write.add_argument("--type", default="constat", choices=list(TYPES))
    p_write.add_argument("--pattern", required=True)
    p_write.add_argument("--hypothese", default="")
    p_write.add_argument("--action", default="")
    p_write.add_argument("--session", default="")
    p_write.add_argument("--ref", action="append", default=[])
    p_read = sub.add_parser("read")
    p_read.add_argument("--session", default=None)
    p_read.add_argument("--poste", default=None)
    p_read.add_argument("--limit", type=int, default=50)
    sub.add_parser("review")
    args = parser.parse_args(argv)

    if args.command == "write":
        entry = write(args.poste, args.type, args.pattern, args.hypothese, args.action,
                      args.session, args.ref)
        print(f"Experience consignee : poste {entry['poste']} · {entry['pattern'][:90]}")
        return 0
    if args.command == "read":
        for entry in read(args.session, args.poste, args.limit):
            print(json.dumps(entry, ensure_ascii=False))
        return 0
    print(review())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
