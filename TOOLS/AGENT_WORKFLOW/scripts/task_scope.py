#!/usr/bin/env python3
"""Périmètre de tâche : prédicat déterministe + métrique de dérive (T429 R8/R10).

Principe (T429, plan §3bis) : une dérive se **prouve** par les chemins touchés, pas
par une impression. Ce module ne fait aucun jugement, aucun appel de modèle :

  * produit   : ensemble de chemins autorisés par le contrat de la tâche
                (`contract.scope.allowed`), moins les interdits (`scope.forbidden`)
  * processus : chemins de gestion de la tâche (dossier de la tâche, plan, contrat,
                règles du projet, résumé de catalogue) — licites mais **comptés à part**,
                car y passer son temps est précisément un signal de dérive
  * hors      : tout le reste

La métrique est un **comptage** sur la trace du transcript : les chemins y sont
enregistrés par les appels d'outils, donc le résultat est reproductible et non estimatif.

CLI :
  scope  --session <id>                     : périmètre produit / processus / interdits
  metric --session <id> [--window 10]       : décompte des derniers fichiers touchés
  deroge --session <id> --path <p> --motif  : dérogation durable (accord exploitant)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS_DIR = ROOT / "DOC" / "WFLOW" / "TASKS"
SUMMARY = ROOT / "DOC" / "WFLOW" / "TASKS_ACTIVE_SUMMARY.md"
SUPERVISOR_SUMMARY_URL = "http://127.0.0.1:8082/api/supervision/summary"
LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
DEROG_DIR = LOCAL_APP / "ExcavatriceDragage" / "workflow"

# Fichiers de regle du projet : licites en phase de tache, mais signales comme "processus".
PROCESS_GLOBAL = ("AGENTS.md", "CLAUDE.md", "DOC/WFLOW/TASKS_ACTIVE_SUMMARY.md")
WRITE_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")
TAIL_BYTES = 512_000  # lecture de queue : le transcript peut faire plusieurs Mo


def normalize(path: str) -> str:
    """Chemin absolu -> relatif POSIX au depot, ou absolu normalise hors depot."""
    text = str(path or "").replace("\\", "/")
    try:
        return Path(text).resolve().relative_to(ROOT).as_posix()
    except (ValueError, OSError):
        return text


def task_id_for_session(session_id: str) -> str | None:
    """Tâche de la session, déduite de son alias Superviseur (T429-MMX01 -> T429)."""
    if not session_id:
        return None
    try:
        with urllib.request.urlopen(SUPERVISOR_SUMMARY_URL, timeout=1.5) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (OSError, ValueError):
        return None
    for item in data.get("sessions", []):
        if str(item.get("native_id") or "") == session_id:
            alias = str(item.get("alias") or "")
            match = re.match(r"^(T\d{3})", alias, re.IGNORECASE)
            return match.group(1).upper() if match else None
    return None


def contract_for_task(task_id: str) -> Path | None:
    """Contrat YAML de la tâche (celui qui porte `contract.scope`)."""
    if not task_id:
        return None
    for folder in TASKS_DIR.glob(f"{task_id}*"):
        if not folder.is_dir():
            continue
        for candidate in sorted(folder.glob("*.yaml")) + sorted(folder.glob("*.yml")):
            try:
                import yaml
                data = yaml.safe_load(candidate.read_text(encoding="utf-8")) or {}
            except (OSError, ValueError, ImportError):
                continue
            contract = data.get("contract") if isinstance(data, dict) else None
            if isinstance(contract, dict) and isinstance(contract.get("scope"), dict):
                return candidate
    return None


def _scope_lists(contract: Path | None) -> tuple[list[str], list[str]]:
    if contract is None:
        return [], []
    try:
        import yaml
        data = yaml.safe_load(contract.read_text(encoding="utf-8")) or {}
    except (OSError, ValueError, ImportError):
        return [], []
    scope = ((data.get("contract") or {}).get("scope") or {}) if isinstance(data, dict) else {}
    allowed = scope.get("allowed") or []
    forbidden = scope.get("forbidden") or []
    return ([str(x) for x in allowed if isinstance(x, str)],
            [str(x) for x in forbidden if isinstance(x, str)])


def process_scope(task_id: str | None) -> list[str]:
    """Chemins de gestion de la tâche (licites, mais comptés séparément)."""
    paths = list(PROCESS_GLOBAL)
    if task_id:
        for folder in TASKS_DIR.glob(f"{task_id}*"):
            if folder.is_dir():
                paths.append(f"DOC/WFLOW/TASKS/{folder.name}")
    return paths


def matches(relative: str, prefixes: list[str]) -> bool:
    for prefix in prefixes:
        clean = str(prefix).replace("\\", "/").rstrip("/")
        if not clean:
            continue
        if relative == clean or relative.startswith(clean + "/"):
            return True
        # "TOOLS/AGENT_SUPERVISOR/**" -> prefixe du dossier
        if clean.endswith("/**"):
            base = clean[:-3]
            if relative == base or relative.startswith(base + "/"):
                return True
    return False


def classify(relative: str, product: list[str], forbidden: list[str], process: list[str]) -> str:
    """produit | processus | hors."""
    if matches(relative, forbidden):
        return "hors"
    if matches(relative, product):
        return "produit"
    if matches(relative, process):
        return "processus"
    return "hors"


def scope_for_session(session_id: str) -> dict:
    """Périmètre complet de la session : produit, interdits, processus, source."""
    task_id = task_id_for_session(session_id)
    contract = contract_for_task(task_id) if task_id else None
    product, forbidden = _scope_lists(contract)
    return {
        "session_id": session_id,
        "task_id": task_id,
        "contract": str(contract.relative_to(ROOT).as_posix()) if contract else "",
        "produit": product,
        "interdits": forbidden,
        "processus": process_scope(task_id),
    }


def derogations_path(session_id: str) -> Path:
    return DEROG_DIR / f"{session_id}.derogations.json"


def read_derogations(session_id: str) -> list[dict]:
    try:
        data = json.loads(derogations_path(session_id).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    return data if isinstance(data, list) else []


def write_derogation(session_id: str, path: str, motif: str) -> dict:
    entries = read_derogations(session_id)
    entry = {"path": normalize(path), "motif": str(motif or "").strip()[:300]}
    if not any(item.get("path") == entry["path"] for item in entries):
        entries.append(entry)
    DEROG_DIR.mkdir(parents=True, exist_ok=True)
    derogations_path(session_id).write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    return entry


def is_derogated(session_id: str, relative: str) -> bool:
    """Une derogation vaut pour un chemin exact ou pour un prefixe marque '.../**'."""
    for item in read_derogations(session_id):
        granted = str(item.get("path") or "")
        if not granted:
            continue
        if granted.endswith("/**"):
            base = granted[:-3]
            if relative == base or relative.startswith(base + "/"):
                return True
        elif granted == relative:
            return True
    return False


def transcript_paths(transcript_path: str | Path, window: int = 10) -> list[str]:
    """Chemins des derniers fichiers touchés (appels d'outils d'écriture), du plus ancien au plus récent.

    Lecture de queue uniquement : le transcript peut faire plusieurs Mo.
    """
    path = Path(transcript_path)
    try:
        size = path.stat().st_size
        with path.open("rb") as stream:
            if size > TAIL_BYTES:
                stream.seek(size - TAIL_BYTES)
                stream.readline()  # ligne tronquée : on la jette
            raw = stream.read().decode("utf-8", errors="replace")
    except OSError:
        return []
    found: list[str] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or '"tool_use"' not in line:
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
            if str(block.get("name") or "") not in WRITE_TOOLS:
                continue
            target = (block.get("input") or {}).get("file_path")
            if target:
                found.append(normalize(str(target)))
    return found[-window:] if window else found


def metric(session_id: str, transcript_path: str | Path, window: int = 10) -> dict:
    """Décompte des derniers fichiers touchés : produit / processus / hors."""
    scope = scope_for_session(session_id)
    paths = transcript_paths(transcript_path, window)
    return _metric_from_paths(scope, paths, window)


def _inside_repo(relative: str) -> bool:
    """Vrai si le chemin est relatif au depot (un scratch externe ne compte pas)."""
    text = str(relative or "").replace("\\", "/")
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        return False
    return True


def _metric_from_paths(scope: dict, paths: list[str], window: int) -> dict:
    counts = {"produit": 0, "processus": 0, "derogation": 0, "hors": 0}
    details = []
    for relative in paths:
        if not relative.startswith(("/", "\\")) and ":" not in relative.split("/")[0]:
            pass
        elif not _inside_repo(relative):
            # Fichiers temporaires / hors depot : ce n'est pas du travail projet.
            continue
        kind = classify(relative, scope["produit"], scope["interdits"], scope["processus"])
        if kind == "hors" and is_derogated(scope.get("session_id", ""), relative):
            kind = "derogation"
        counts[kind] += 1
        details.append({"path": relative, "kind": kind})
    total = sum(counts.values())  # seules les ecritures projet comptent
    hors = counts["hors"]
    return {
        "session_id": scope.get("session_id", ""),
        "task_id": scope.get("task_id"),
        "window": window,
        "total": total,
        "counts": counts,
        "ratio_hors": round(hors / total, 3) if total else 0.0,
        "details": details,
        "scope_known": bool(scope["produit"]),
        "contract": scope["contract"],
    }


# ── Journal des écritures (source vive de la métrique) ────────────────────────
# Chaque tentative d'écriture est tracee par le hook : le décompte ne relit donc pas
# le transcript (qui peut faire plusieurs Mo) et reste exact.
SCOPE_DIR = LOCAL_APP / "ExcavatriceDragage" / "scope"


def writes_log(session_id: str) -> Path:
    return SCOPE_DIR / f"{session_id}.writes.jsonl"


def record_write(session_id: str, path: str, kind: str) -> None:
    entry = {"path": normalize(path), "kind": kind, "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    try:
        SCOPE_DIR.mkdir(parents=True, exist_ok=True)
        with writes_log(session_id).open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:
        pass


def logged_paths(session_id: str, window: int = 10) -> list[str]:
    try:
        raw = writes_log(session_id).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    paths = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("path"):
            paths.append(str(entry["path"]))
    return paths[-window:] if window else paths


def metric_logged(session_id: str, window: int = 10) -> dict:
    """Métrique depuis le journal des écritures (rapide, exact)."""
    scope = scope_for_session(session_id)
    return _metric_from_paths(scope, logged_paths(session_id, window), window)


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_scope = sub.add_parser("scope")
    p_scope.add_argument("--session", required=True)
    p_metric = sub.add_parser("metric")
    p_metric.add_argument("--session", required=True)
    p_metric.add_argument("--transcript", default="")
    p_metric.add_argument("--window", type=int, default=10)
    p_derog = sub.add_parser("deroge")
    p_derog.add_argument("--session", required=True)
    p_derog.add_argument("--path", required=True)
    p_derog.add_argument("--motif", default="")

    args = parser.parse_args(argv)

    if args.command == "scope":
        scope = scope_for_session(args.session)
        print(json.dumps(scope, ensure_ascii=False, indent=2))
        return 0

    if args.command == "deroge":
        entry = write_derogation(args.session, args.path, args.motif)
        print(f"Dérogation enregistrée : {entry['path']} — {entry['motif'] or 'sans motif'}")
        return 0

    transcript = args.transcript or os.environ.get("CLAUDE_TRANSCRIPT_PATH", "")
    if not transcript:
        print(json.dumps({"error": "transcript absent : passer --transcript"}, ensure_ascii=False))
        return 2
    print(json.dumps(metric(args.session, transcript, args.window), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
