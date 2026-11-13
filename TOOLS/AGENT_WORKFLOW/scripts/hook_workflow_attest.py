#!/usr/bin/env python3
"""Hook Stop (attestation, non bloquant) : constate l'application du workflow projet.

Pourquoi : l'indicateur de statusline ne peut pas se fier à ce que l'agent DÉCLARE de
lui-même (auto-certification). Ce hook est exécuté par le harnais à la fin de chaque
tour : il relève, dans le transcript, la présence du bandeau de ligne d'étape et du
pied « ➡️ Choix », puis dépose une attestation (fichier) que la statusline lit.

Il ne bloque JAMAIS : l'utilisateur a explicitement rejeté le blocage pendant le WIP
(REX 2026-08-23). Il constate, il n'interdit pas.

Sortie : code 0 toujours. Aucun bruit en sortie standard.
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
STATE_DIR = LOCAL_APP / "ExcavatriceDragage" / "workflow"
TAIL_BYTES = 512_000


def state_path(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.json"


def attest_path(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.attest.json"


def read_state(session_id: str) -> dict | None:
    try:
        data = json.loads(state_path(session_id).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if str(data.get("etat", "")).upper() == "ACTIF" else None


def last_assistant_text(transcript: Path) -> str:
    """Texte du dernier message assistant (lecture de queue)."""
    try:
        size = transcript.stat().st_size
        with transcript.open("rb") as stream:
            if size > TAIL_BYTES:
                stream.seek(size - TAIL_BYTES)
                stream.readline()
            raw = stream.read().decode("utf-8", errors="replace")
    except OSError:
        return ""
    text = ""
    for line in reversed(raw.splitlines()):
        line = line.strip()
        if not line or '"assistant"' not in line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") != "assistant":
            continue
        message = entry.get("message") or {}
        if message.get("role") != "assistant":
            continue
        content = message.get("content")
        blocks = []
        if isinstance(content, str):
            blocks = [content]
        elif isinstance(content, list):
            blocks = [b.get("text", "") for b in content
                      if isinstance(b, dict) and b.get("type") == "text"]
        if blocks:
            text = "\n".join(blocks)
            break
    return text


def parse_banner(text: str) -> tuple[str, str, str] | None:
    """(tâche, étape, voie) depuis la PREMIÈRE ligne — le bandeau doit être en tête."""
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        return None
    first = lines[0].strip()
    if not first.startswith("━━") or "━" not in first:
        return None
    parts = [part.strip() for part in first.strip("━ ").split("·")]
    if len(parts) < 3:
        return None
    task = parts[0].split()[-1] if parts[0].split() else ""
    etape, voie = parts[1], " · ".join(parts[2:])
    return (task, etape, voie) if task and etape else None


def write_attestation(path: Path, payload: dict) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        handle, tmp_name = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False)
        os.replace(tmp_name, path)
    except OSError:
        pass


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    session_id = str(payload.get("session_id") or "").strip()
    transcript = payload.get("transcript_path")
    if not session_id or not transcript:
        return 0
    if read_state(session_id) is None:
        return 0  # workflow inactif : rien à constater

    text = last_assistant_text(Path(transcript))
    banner = parse_banner(text)
    has_footer = "➡️ Choix" in text or "➡️ Choix :" in text
    conform = bool(banner) and has_footer

    previous = {}
    try:
        previous = json.loads(attest_path(session_id).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        previous = {}
    turns = int(previous.get("turns", 0)) + 1
    conform_turns = int(previous.get("conform_turns", 0)) + (1 if conform else 0)

    write_attestation(attest_path(session_id), {
        "session_id": session_id,
        "turns": turns,
        "conform_turns": conform_turns,
        "conform": conform,
        "banner": bool(banner),
        "footer": has_footer,
        "task": banner[0] if banner else "",
        "etape": banner[1] if banner else "",
        "voie": banner[2] if banner else "",
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    })
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
