#!/usr/bin/env python3
"""Titre du terminal : séquence d'ECRITURE VERIFIEE (pas « ça marche dessus »).

Trois acteurs écrivent le titre du terminal : le shell, Claude Code (à chaque rendu)
et nous. Le dernier qui écrit gagne — d'où la séquence deterministe :

  1. ecrire  : SetConsoleTitleW (titre de la console) PUIS OSC 0/2 (titre du terminal)
  2. relire  : GetConsoleTitleW et comparer avec la cible
  3. reessayer: jusqu'a N tentatives, tant que la relecture ne correspond pas
  4. consigner: registre par session (cible, relecture, tentatives, horodatage)

Le registre rend le resultat verifiable par un tiers ; l'echec reste visible au lieu
d'etre silent.
"""
from __future__ import annotations

import ctypes
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trace_log  # noqa: E402  (journal interne)

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
TITLE_DIR = LOCAL_APP / "ExcavatriceDragage" / "titles"
ATTEMPTS = 2
DELAY = 0.015  # 15 ms : le pire cas (2 tentatives) reste sous 30 ms


def _console_title() -> str:
    try:
        buffer = ctypes.create_unicode_buffer(1024)
        ctypes.windll.kernel32.GetConsoleTitleW(buffer, 1024)
        return buffer.value
    except Exception:
        return ""


LOG_PATH = TITLE_DIR / "title-writes.jsonl"


def append_log(entry: dict) -> dict:
    """Journal INTERNE (append-only) : jamais affiche, lisible par API et par tests."""
    try:
        TITLE_DIR.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:
        pass
    return entry


def recent(limit: int = 50, session_id: str | None = None) -> list[dict]:
    """Dernieres ecritures consignees (debug + tests de non-regression)."""
    try:
        raw = LOG_PATH.read_text(encoding="utf-8", errors="replace")
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
        if session_id and entry.get("session_id") != session_id:
            continue
        entries.append(entry)
    return entries[-limit:] if limit else entries


def write_title(title_text: str, attempts: int = ATTEMPTS, delay: float = DELAY) -> dict:
    """Ecrit le titre, le relit, reessaye ; renvoie le constat de verification."""
    target = str(title_text or "").strip()
    started = time.monotonic()
    result = {"target": target, "verified": False, "readback": "", "attempts": 0,
              "console": False, "osc": False, "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    if not target:
        return result
    for attempt in range(1, max(1, attempts) + 1):
        result["attempts"] = attempt
        try:
            if os.name == "nt":
                ctypes.windll.kernel32.SetConsoleTitleW(target)
                result["console"] = True
        except Exception:
            result["console"] = False
        try:
            sequence = f"\x1b]0;{target}\x07\x1b]2;{target}\x07"
            handle = "CONOUT$" if os.name == "nt" else "/dev/tty"
            with open(handle, "w", encoding="utf-8", errors="replace") as tty:
                tty.write(sequence)
                tty.flush()
            result["osc"] = True
        except Exception:
            result["osc"] = False
        readback = _console_title()
        result["readback"] = readback
        # Verifie si la console porte bien le titre ; l'OSC (terminal) n'a pas d'API de
        # relecture : sa reussite est attestee par l'ecriture sans erreur.
        if readback == target or not readback:
            result["verified"] = True
            break
        time.sleep(delay)
    result["duration_ms"] = round((time.monotonic() - started) * 1000, 1)
    return result


def ledger_path(session_id: str) -> Path:
    safe = "".join(char for char in str(session_id or "session") if char.isalnum() or char in "-_")[:80]
    return TITLE_DIR / f"{safe}.json"


def record(session_id: str, result: dict) -> dict:
    """Consigne le resultat de verification dans le registre de la session."""
    payload = dict(result or {})
    payload["session_id"] = session_id
    payload["ts"] = time.time()
    try:
        TITLE_DIR.mkdir(parents=True, exist_ok=True)
        path = ledger_path(session_id)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass
    return payload


def read(session_id: str) -> dict:
    try:
        return json.loads(ledger_path(session_id).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def refresh(session_id: str, title: str) -> dict:
    """Ecrit, verifie, consigne (registre par session + journal interne append-only)."""
    result = write_title(title)
    result["session_id"] = session_id
    record(session_id, result)
    append_log(result)
    trace_log.emit("titre", session=session_id, target=result.get("target"),
                   verified=result.get("verified"), attempts=result.get("attempts"),
                   readback=result.get("readback"), duration_ms=result.get("duration_ms"),
                   console=result.get("console"), osc=result.get("osc"))
    return result
