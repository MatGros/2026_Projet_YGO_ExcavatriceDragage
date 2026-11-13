#!/usr/bin/env python3
"""Journal interne des etats et des ecritures (trace unique, append-only).

Un seul flux, several emetteurs : workflow_state (entree/sortie/voie/etape),
terminal_title (ecriture + verification du titre), hook_workflow_attest (attestation
de conformite), hook_scope_guard (ecritures + perimeter), miss_log (manquements),
supervisor_service (transitions d'etat, constats, erreur de source).

Le journal n'est JAMAIS affiche : il est lu par l'analyseur (incoherences) et par les
tests (non-regression). Un etat incoherent devient un fait, pas une impression.

CLI : python TOOLS/AGENT_WORKFLOW/scripts/trace_log.py report [--session <id>]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
TRACE_DIR = LOCAL_APP / "ExcavatriceDragage" / "trace"
TRACE_PATH = TRACE_DIR / "trace.jsonl"

KINDS = (
    "workflow",      # entree / sortie / voie / etape
    "titre",         # ecriture + verification du titre
    "attestation",   # conformite d'un tour (bandeau + pied)
    "ecriture",      # ecriture de fichier + verdict de perimetre
    "manquement",    # signature M1..M9
    "superviseur",   # transitions d'etat, constats, erreur de source
)


def emit(kind: str, **fields) -> dict:
    """Ajoute un evenement au journal interne (jamais affiche)."""
    entry = {"ts": time.time(), "at": time.strftime("%Y-%m-%dT%H:%M:%S"), "kind": kind}
    entry.update({key: value for key, value in fields.items() if value is not None})
    try:
        TRACE_DIR.mkdir(parents=True, exist_ok=True)
        with TRACE_PATH.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(entry, ensure_ascii=False, default=str) + "\n")
    except OSError:
        pass
    return entry


def query(kind: str | None = None, session: str | None = None, limit: int = 500,
          since: float | None = None) -> list[dict]:
    """Evenements filtrés (debug, tests, analyse)."""
    try:
        raw = TRACE_PATH.read_text(encoding="utf-8", errors="replace")
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
        if kind and entry.get("kind") != kind:
            continue
        if session and entry.get("session") != session:
            continue
        if since and float(entry.get("ts", 0)) < since:
            continue
        entries.append(entry)
    return entries[-limit:] if limit else entries


def inconsistencies(session: str | None = None, window: int = 400) -> list[dict]:
    """Derive les incoherences depuis le journal. Heuristiques, chacune traceable.

    Chaque anomalie porte ses preuves (les evenements concernes) : elle est
    verifiable, pas_opinee.
    """
    entries = query(session=session, limit=window)
    found: list[dict] = []

    def note(code, why, evidence):
        found.append({"code": code, "why": why, "evidence": evidence})

    # 1. workflow declare actif mais aucun tour conforme
    workflow = [e for e in entries if e.get("kind") == "workflow"]
    attest = [e for e in entries if e.get("kind") == "attestation"]
    last_decl = None
    for event in workflow:
        if event.get("etat") in ("ACTIF", "OFF"):
            last_decl = event
    if last_decl and last_decl.get("etat") == "ACTIF":
        since = float(last_decl.get("ts", 0))
        after = [e for e in attest if float(e.get("ts", 0)) >= since]
        if after and not any(e.get("conform") for e in after):
            note("workflow_declare_non_entree",
                 "workflow declare actif, aucun tour conforme atteste depuis",
                 [{"at": last_decl.get("at")}, {"tours_non_conformes": len(after)}])

    # 2. titres : ecriture non verifiee, ou titre reecrit par un autre
    titres = [e for e in entries if e.get("kind") == "titre"]
    for event in titres:
        if event.get("verified") is False:
            note("titre_non_verifie", "ecriture du titre non relue conforme",
                 [{"at": event.get("at"), "target": event.get("target"), "readback": event.get("readback")}])
    targets = [e.get("target") for e in titres]
    for previous, current in zip(targets, targets[1:]):
        if previous and current and previous != current:
            note("titre_change", "le titre du terminal a change",
                 [{"avant": previous}, {"apres": current}])

    # 3. ecritures hors perimetre sans derogation
    for event in entries:
        if event.get("kind") == "ecriture" and event.get("kind_verdict") == "hors" and not event.get("derogation"):
            note("ecriture_hors_perimetre", "ecriture hors perimetre sans derogation",
                 [{"at": event.get("at"), "path": event.get("path")}])

    # 4. attente annoncee puis action
    for event in entries:
        if event.get("kind") == "manquement" and event.get("signature") == "M5":
            note("attente_annoncee_puis_action", "attente annoncee puis ecriture",
                 [{"at": event.get("at"), "signature": event.get("signature")}])

    # 5. superviseur muet alors que le workflow est actif
    if last_decl and last_decl.get("etat") == "ACTIF":
        for event in entries:
            if event.get("kind") == "superviseur" and event.get("etat") not in (None, "active"):
                note("superviseur_muet", f"superviseur en etat {event.get('etat')} pendant un workflow actif",
                     [{"at": event.get("at"), "etat": event.get("etat")}])

    return found


def report(session: str | None = None, limit: int = 20) -> str:
    lines = []
    counts: dict[str, int] = {}
    for entry in query(session=session, limit=limit):
        counts[entry.get("kind", "?")] = counts.get(entry.get("kind", "?"), 0) + 1
    lines.append("Evenements : " + (", ".join(f"{kind}={count}" for kind, count in sorted(counts.items())) or "aucun"))
    anomalies = inconsistencies(session=session)
    lines.append(f"Incoherences : {len(anomalies)}")
    for anomaly in anomalies[:limit]:
        lines.append(f"  - [{anomaly['code']}] {anomaly['why']}")
        lines.append(f"      preuves : {json.dumps(anomaly['evidence'], ensure_ascii=False)[:220]}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p_report = sub.add_parser("report")
    p_report.add_argument("--session", default=None)
    p_report.add_argument("--limit", type=int, default=20)
    p_query = sub.add_parser("query")
    p_query.add_argument("--kind", default=None, choices=KINDS)
    p_query.add_argument("--session", default=None)
    p_query.add_argument("--limit", type=int, default=50)
    args = parser.parse_args(argv)

    if args.command == "report":
        print(report(args.session, args.limit))
        return 0
    for entry in query(kind=args.kind, session=args.session, limit=args.limit):
        print(json.dumps(entry, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
