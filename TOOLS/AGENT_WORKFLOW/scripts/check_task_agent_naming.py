#!/usr/bin/env python3
"""Garde-fou mécanique de nomenclature du champ agent dans TASKS.yaml et TASK_LOCKS.json.

Règle canonique (AGENTS.md & task-planner/SKILL.md) :
  Format strict : Trigramme / Digramme + 2 chiffres (01..99), HUM ou — (max 6 caractères).
  Exemples valides : CC01, AGY01, CDX01, DSH01, OPC01, HUM, —
  Interdit : libellés longs, texte libre, parenthèses.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_task_agent_naming.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
TASKS_PATH = REPO / "DOC" / "WFLOW" / "TASKS.yaml"
LOCKS_PATH = REPO / "DOC" / "WFLOW" / "TASK_LOCKS.json"

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

AGENT_REGEX = re.compile(r"^(CC|AGY|CDX|DSH|OPC)[0-9]{2}$|^HUM$|^—$")


def check_tasks() -> list[tuple[str, str]]:
    errors = []
    text = TASKS_PATH.read_text(encoding="utf-8")
    current_id = ""
    for line in text.splitlines():
        m_id = re.match(r"^-\s+id:\s*(\S+)", line)
        if m_id:
            current_id = m_id.group(1)
        m_agent = re.match(r"^\s*agent:\s*(.*)$", line)
        if m_agent:
            raw = m_agent.group(1).strip().strip("'\"")
            if not AGENT_REGEX.match(raw):
                errors.append((current_id, raw))
    return errors


def check_locks() -> list[tuple[str, str]]:
    errors = []
    if not LOCKS_PATH.exists():
        return errors
    try:
        data = json.loads(LOCKS_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        return [("LOCKS_JSON", f"invalide : {exc}")]
    for tid, lock in data.get("work_locks", {}).items():
        act = str(lock.get("acteur", "")).strip()
        if not AGENT_REGEX.match(act):
            errors.append((tid, act))
    return errors


def main() -> int:
    task_errors = check_tasks()
    lock_errors = check_locks()

    if not task_errors and not lock_errors:
        print("✅ Nomenclature du champ agent : 100% CONFORME (TASKS.yaml + TASK_LOCKS.json)")
        return 0

    print("❌ Erreurs de nomenclature du champ agent détectées :")
    for tid, val in task_errors:
        print(f"  - TASKS.yaml [Tâche {tid}] : '{val}' non conforme (attendu : CC01, AGY01, CDX01, DSH01, OPC01, HUM, —)")
    for tid, val in lock_errors:
        print(f"  - TASK_LOCKS.json [Lock {tid}] : acteur '{val}' non conforme")
    return 1


if __name__ == "__main__":
    sys.exit(main())
