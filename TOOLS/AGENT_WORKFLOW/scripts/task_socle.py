#!/usr/bin/env python3
"""Le socle d'une tâche : la petite liste de documents à lire AVANT d'agir.

Le point d'entrée `/connect-session-supervisor` exige ce socle ; le hook d'attestation
relit le transcript et constate ce qui a réellement été lu. Une règle « se lire » ne se
déclare pas : elle se relit (même motif que le contrôle `CODE/`).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
GLOBAL_SOCLE = (
    "AGENTS.md",
    "DOC/WFLOW/TASKS_ACTIVE_SUMMARY.md",
)


def task_id_from_alias(alias: str) -> str | None:
    """TXXX tire de l alias de session (T429-MMX01 -> T429)."""
    import re as _re
    match = _re.match(r"^(T\d{3})", str(alias or "").strip(), _re.IGNORECASE)
    return match.group(1).upper() if match else None


def task_folder(task_id: str) -> Path | None:
    if not task_id:
        return None
    for folder in sorted(TASKS_DIR.glob(f"{task_id}*")):
        if folder.is_dir():
            return folder
    return None


def socle_for(task_id: str, extra=()) -> list[str]:
    """Documents à lire pour cette tâche (chemins relatifs au dépôt)."""
    socle = [path for path in GLOBAL_SOCLE if (ROOT / path).is_file()]
    folder = task_folder(task_id)
    if folder is None:
        return socle
    relative = folder.relative_to(ROOT).as_posix()
    # le contrat, puis le plan, puis les notes de la tache (ordre de lecture)
    for pattern in ("*CONTRAT*.yaml", "*PLAN*.md", "*NOTE*.md", "README.md"):
        for candidate in sorted(folder.glob(pattern)):
            path = candidate.relative_to(ROOT).as_posix()
            if path not in socle:
                socle.append(path)
    for path in extra or ():
        if path and path not in socle and (ROOT / path).is_file():
            socle.append(path)
    return socle


def read_status(transcript_path, socle) -> dict:
    """Ce qui a été réellement lu (relit du transcript) vs le socle attendu."""
    expected = [str(item) for item in socle or []]
    read = set()
    try:
        path = Path(transcript_path)
        size = path.stat().st_size
        with path.open("rb") as stream:
            if size > 4_000_000:
                stream.seek(size - 4_000_000)
                stream.readline()
            raw = stream.read().decode("utf-8", errors="replace")
    except (OSError, ValueError):
        return {"lu": [], "manquants": expected, "total": len(expected), "complet": False}
    for line in raw.splitlines():
        if '"tool_use"' not in line or '"Read"' not in line:
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        message = record.get("message") or {}
        content = message.get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if str(block.get("name")) != "Read":
                continue
            target = str((block.get("input") or {}).get("file_path") or "").replace("\\", "/")
            if not target:
                continue
            try:
                relative = Path(target).resolve().relative_to(ROOT).as_posix()
            except (ValueError, OSError):
                relative = target
            read.add(relative)
    missing = [path for path in expected if path not in read]
    return {"lu": sorted(read & set(expected)), "manquants": missing,
            "total": len(expected), "complet": not missing and bool(expected)}
