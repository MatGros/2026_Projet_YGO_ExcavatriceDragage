"""R29 (demande exploitant 2026-11-22) : MEMOIRE LONGUE DURABLE, interrogeable.
Les messages bruts sont archives INTEGRALEMENT en JSONL (une ligne par message,
format grep-able, texte non tronque), quasi sans limite ; les agents/juges ne lisent
jamais tout : ils QUESTIONNENT (recherche plein texte) quand ils en ont besoin.

Emplacement : %LOCALAPPDATA%/ExcavatriceDragage/agent-memory/<session_id>.jsonl
Schéma d'une ligne : {"at": iso, "role": str, "text": str INTEGRAL, "event_id": str,
"event_index": int, "generation": int}
"""
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(os.environ.get('LOCALAPPDATA', Path.home() / '.local/share')) / 'ExcavatriceDragage'
MEMORY_DIR = ROOT / 'agent-memory'


def archive_path(session_id: str) -> Path:
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    safe = ''.join(ch for ch in str(session_id) if ch.isalnum() or ch in '-_')[:80] or 'session'
    return MEMORY_DIR / f'{safe}.jsonl'


def append(session_id: str, entries) -> int:
    """Ajoute des entrees (liste de dict) ; texte INTEGRAL, jamais tronque ici.
    Retourne le nombre de lignes ecrites. Ne leve pas : l'archive est best-effort
    (une panne disque ne doit pas tuer la collecte), mais elle est tracee par l'appelant."""
    if not entries:
        return 0
    path = archive_path(session_id)
    written = 0
    try:
        with open(path, 'a', encoding='utf-8') as handle:
            for entry in entries:
                handle.write(json.dumps({
                    'at': str(entry.get('observed_at') or entry.get('at') or ''),
                    'role': str(entry.get('role') or '?'),
                    'text': str(entry.get('text') or ''),
                    'event_id': str(entry.get('event_id') or ''),
                    'event_index': entry.get('event_index'),
                    'generation': entry.get('generation'),
                }, ensure_ascii=False) + '\n')
                written += 1
    except OSError:
        return 0
    return written


def search(session_id: str, query: str = '', limit: int = 20, since: str = '') -> dict:
    """Recherche PLEIN TEXTE dans l'archive (insensible a la casse). Ne charge jamais
    tout en memoire : parcourt le fichier en flux et s'arrete a `limit` correspondances."""
    path = archive_path(session_id)
    needle = str(query or '').casefold().strip()
    since = str(since or '').strip()
    matches = []
    scanned = 0
    if not path.exists():
        return {'matches': [], 'scanned': 0, 'total_lines': 0, 'archive': str(path)}
    try:
        for line in _iter_lines(path):
            scanned += 1
            if since and str(line.get('at') or '') < since:
                continue
            text = str(line.get('text') or '')
            if needle and needle not in text.casefold():
                continue
            index = text.casefold().find(needle) if needle else 0
            start = max(0, index - 80)
            snippet = text[start:index + len(needle) + 160]
            matches.append({'at': line.get('at'), 'role': line.get('role'),
                            'event_id': line.get('event_id'), 'snippet': snippet})
            if len(matches) >= max(1, int(limit)):
                break
    except OSError:
        pass
    return {'matches': matches, 'scanned': scanned, 'archive': str(path)}


def stats(session_id: str) -> dict:
    """Compteurs de l'archive SANS la charger : lignes, caracteres, plus ancien/recent."""
    path = archive_path(session_id)
    if not path.exists():
        return {'lines': 0, 'chars': 0, 'oldest': None, 'newest': None, 'bytes': 0, 'archive': str(path)}
    lines = chars = 0
    oldest = newest = None
    try:
        for line in _iter_lines(path):
            lines += 1
            chars += len(str(line.get('text') or ''))
            at = str(line.get('at') or '')
            if at:
                oldest = oldest or at
                newest = at
        size = path.stat().st_size
    except OSError:
        size = 0
    return {'lines': lines, 'chars': chars, 'oldest': oldest, 'newest': newest,
            'bytes': size, 'archive': str(path)}


def archived_event_ids(session_id: str, limit: int = 500) -> set:
    """Identifiants deja archives (fin de fichier) — sert a une migration idempotente."""
    path = archive_path(session_id)
    seen = set()
    if not path.exists():
        return seen
    try:
        for line in _iter_lines(path):
            ident = str(line.get('event_id') or '')
            if ident:
                seen.add(ident)
    except OSError:
        pass
    return seen


def _iter_lines(path: Path):
    with open(path, 'r', encoding='utf-8', errors='replace') as handle:
        for raw in handle:
            raw = raw.strip()
            if not raw:
                continue
            try:
                value = json.loads(raw)
            except ValueError:
                continue
            if isinstance(value, dict):
                yield value
