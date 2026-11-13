#!/usr/bin/env python3
"""Génère DOC/WFLOW/TASKS_ACTIVE_SUMMARY.md à partir du catalogue et des verrous.

T427-I2 : le résumé doit être mécanique, sinon il devient « PÉRIMÉ » au premier
changement de `TASKS.yaml` et le bandeau de démarrage annonce un état faux.

Sortie : le fichier est écrit (une seule fois, écriture atomique) ; l'en-tête porte
le sha256 du catalogue lu, ce qui permet à `workflow_state.py` de dire À JOUR ou
PÉRIMÉ sans relire le catalogue.

Usage : python TOOLS/AGENT_WORKFLOW/scripts/generate_tasks_summary.py [--check]
  --check : n'écrit rien, sort en 1 si le résumé est périmé (contrôle CI).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / "DOC" / "WFLOW" / "TASKS.yaml"
LOCKS = ROOT / "DOC" / "WFLOW" / "TASK_LOCKS.json"
SUMMARY = ROOT / "DOC" / "WFLOW" / "TASKS_ACTIVE_SUMMARY.md"

STATUS_ORDER = ("⏳", "⏸️", "⛔")  # lignes detaillees : en cours, en pause, bloque
TITLE_MAX = 90


def load_tasks() -> list[dict]:
    try:
        import yaml
        data = yaml.safe_load(CATALOG.read_text(encoding="utf-8")) or []
    except (OSError, ValueError, ImportError) as exc:
        raise SystemExit(f"Catalogue illisible : {exc}")
    if isinstance(data, dict):
        data = data.get("tasks", [])
    return [item for item in data if isinstance(item, dict)]


def load_locks() -> dict:
    try:
        data = json.loads(LOCKS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    locks = data.get("work_locks") if isinstance(data, dict) else None
    return locks if isinstance(locks, dict) else {}


def catalog_digest() -> str:
    return hashlib.sha256(CATALOG.read_bytes()).hexdigest()


def build(tasks: list[dict], locks: dict) -> str:
    counts: dict[str, int] = {}
    for task in tasks:
        status = str(task.get("statut", "⬜"))
        counts[status] = counts.get(status, 0) + 1
    verrous = len(locks)
    detail = []
    for task in tasks:
        if str(task.get("statut", "⬜")) in STATUS_ORDER:
            detail.append(task)
    detail.sort(key=lambda item: str(item.get("date") or ""), reverse=True)

    lines = [
        "# TASKS_ACTIVE_SUMMARY — résumé du catalogue pour le démarrage de session",
        f"<!-- sha256(TASKS.yaml)={catalog_digest()} | genere={datetime.now().strftime('%Y-%m-%dT%H:%M:%S')} "
        "| generateur=TOOLS/AGENT_WORKFLOW/scripts/generate_tasks_summary.py -->",
        "",
        f"**Compteurs** : 🔒 {verrous} · ⏳ {counts.get('⏳', 0)} · ⏸️ {counts.get('⏸️', 0)} · "
        f"⬜ {counts.get('⬜', 0)} · ⛔ {counts.get('⛔', 0)} "
        f"(✅ {counts.get('✅', 0)} · ❌ {counts.get('❌', 0)} · total {len(tasks)})",
        "",
        "**Verrous 🔒** : " + (", ".join(f"{key} ({value.get('actor', '—')})" for key, value in locks.items()) or "aucun"),
        "",
        "**Tâches ⏳ / ⏸️ / ⛔**",
        "",
        "| ID | Statut | Agent | Titre |",
        "|---|---|---|---|",
    ]
    for task in detail:
        title = " ".join(str(task.get("titre") or "").split())
        if len(title) > TITLE_MAX:
            title = title[: TITLE_MAX - 1] + "…"
        lines.append(f"| {task.get('id', '—')} | {task.get('statut', '⬜')} | {task.get('agent', '—')} | {title} |")
    lines += [
        "",
        "> Ne pas lire `TASKS.yaml` en entier au démarrage. Détail d'une tâche : Task Manager ou lecture ciblée de sa fiche.",
        "",
    ]
    return "\n".join(lines)


def write_atomic(text: str) -> None:
    folder = SUMMARY.parent
    folder.mkdir(parents=True, exist_ok=True)
    handle, tmp_name = tempfile.mkstemp(dir=str(folder), suffix=".tmp")
    with os.fdopen(handle, "w", encoding="utf-8") as stream:
        stream.write(text)
    os.replace(tmp_name, SUMMARY)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="n'ecrit rien ; sort en 1 si perime")
    args = parser.parse_args(argv)

    tasks = load_tasks()
    text = build(tasks, load_locks())
    if args.check:
        current = SUMMARY.read_text(encoding="utf-8") if SUMMARY.is_file() else ""
        fresh = f"sha256(TASKS.yaml)={catalog_digest()}" in current
        print("Résumé à jour" if fresh else "Résumé PÉRIMÉ — python TOOLS/AGENT_WORKFLOW/scripts/generate_tasks_summary.py")
        return 0 if fresh else 1
    write_atomic(text)
    print(f"Résumé écrit : {SUMMARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
