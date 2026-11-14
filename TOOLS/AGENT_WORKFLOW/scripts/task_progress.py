#!/usr/bin/env python3
"""Avancement reel d'une tache, lu dans son contrat (T429, 2026-11-13).

Le taux n'est pas une impression : il compte les criteres d'acceptation declares dans
`contract.acceptance` et ceux dont la preuve est consignee dans `tracking` (les
lignes qui citent le critere et une preuve). Le reste n'est pas compte : pas de preuve,
pas de point.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
CRITERION = re.compile(r"\bAC-[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*(?:\.[A-Za-z0-9]+)*\b")
PROOF_WORDS = ("PASS", "prouve", "prove", "valide", "verifie", "verified")


def task_id_from_alias(alias: str) -> str | None:
    match = re.match(r"^(T\d{3})", str(alias or "").strip(), re.IGNORECASE)
    return match.group(1).upper() if match else None


def contract_path(task_id: str) -> Path | None:
    if not task_id:
        return None
    for folder in sorted(TASKS_DIR.glob(f"{task_id}*")):
        if not folder.is_dir():
            continue
        for candidate in sorted(folder.glob("*.yaml")):
            if "CONTRAT" in candidate.name.upper():
                return candidate
    return None


def progress(task_id: str) -> dict:
    """{task_id, total, valides, part, contrat} — 0 si le contrat est introuvable."""
    empty = {"task_id": task_id, "total": 0, "valides": 0, "part": None, "contrat": ""}
    path = contract_path(task_id)
    if path is None:
        return empty
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, ValueError, ImportError):
        return empty
    acceptance = ((data.get("contract") or {}).get("acceptance") or [])
    if not isinstance(acceptance, list):
        return empty
    total = len([item for item in acceptance if isinstance(item, dict)])
    declared = {str(item.get("id")) for item in acceptance if isinstance(item, dict)}
    proved = set()
    tracking = data.get("tracking") or {}
    lines = tracking.get("established") or []
    if isinstance(lines, str):
        lines = [lines]
    for line in lines:
        text = str(line)
        if not any(word in text for word in PROOF_WORDS):
            continue
        # un critere compte comme prouve si la ligne le cite ET porte une preuve
        for match in CRITERION.finditer(text):
            if match.group(0) in declared:
                proved.add(match.group(0))
    return {"task_id": task_id, "total": total, "valides": len(proved),
            "part": round(len(proved) / total, 3) if total else None,
            "contrat": path.relative_to(ROOT).as_posix()}


def progress_for_alias(alias: str) -> dict:
    return progress(task_id_from_alias(alias) or "")
