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

# Deny-list GLOBALE : aucun contrat de tache ne peut la lever (revue DeepSeek 2026-11-13,
# point le plus grave). Seul l exploitant peut deroger chemin par chemin, avec un motif.
ABSOLUTE_DENY = (
    "CODE/**",
    "CODE_XML/**",
    "PRJ_CODESYS/**",
    ".claude/settings.json",
    ".claude/settings.local.json",
    ".claude/settings*.json",
    ".claude/hooks/**",
    "TOOLS/AGENT_WORKFLOW/hooks/**",
    "TOOLS/AGENT_WORKFLOW/skills/**",
    ".claude/skills/**",
    ".agents/skills/**",
    ".dsh/skills/**",
    # Les gardes eux-memes : les reecrire, c'est se desarmer.
    "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_scope_guard.py",
    "TOOLS/AGENT_WORKFLOW/scripts/trace_log.py",
    "TOOLS/AGENT_WORKFLOW/scripts/miss_log.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_workflow_attest.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_pre_edit.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_post_edit.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_stop.py",
    "TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py",
)
TAIL_BYTES = 512_000  # lecture de queue : le transcript peut faire plusieurs Mo


def normalize(path: str) -> str:
    """Chemin absolu -> relatif POSIX au depot, ou absolu normalise hors depot."""
    text = str(path or "").replace("\\", "/")
    try:
        return Path(text).resolve().relative_to(ROOT).as_posix()
    except (ValueError, OSError):
        return text


def task_id_for_session(session_id: str) -> str | None:
    """Tâche de la session.

    Source prioritaire : le champ `task_id` stocke par le Superviseur a la connexion.
    Repli : l'alias (T429-MMX01 -> T429) si le champ n'est pas renseigne.
    """
    if not session_id:
        return None
    try:
        with urllib.request.urlopen(SUPERVISOR_SUMMARY_URL, timeout=1.5) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (OSError, ValueError):
        return None
    for item in data.get("sessions", []):
        if str(item.get("native_id") or "") == session_id:
            stored = str(item.get("task_id") or "").strip()
            if stored:
                return stored.upper()
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
    """Comparaison par composants de chemin ; les motifs '*' sont acceptes.

    "TOOLS/AGENT_SUPERVISOR/**" -> le dossier et tout son contenu
    ".claude/settings*.json"    -> les fichiers correspondants
    """
    import fnmatch
    for prefix in prefixes:
        clean = str(prefix).replace("\\", "/").rstrip("/")
        if not clean:
            continue
        if relative == clean or relative.startswith(clean + "/"):
            return True
        if clean.endswith("/**"):
            base = clean[:-3]
            if relative == base or relative.startswith(base + "/"):
                return True
        if "*" in clean:
            if fnmatch.fnmatch(relative, clean):
                return True
            if fnmatch.fnmatch(relative, clean + "/*"):
                return True
    return False


# Espace provisoire de l agent : ce n est pas du travail projet (il vit hors depot et
# n entre pas dans la metrique). Autorise, mais JAMAIS dans le perimetre produit.
SCRATCH_PREFIXES = (
    str(LOCAL_APP / "Temp").replace("\\", "/").lower(),
    "/tmp/",
    "c:/users/zedvictus/appdata/local/temp/",
)


def is_inside_repo(relative: str) -> bool:
    """Le chemin est-il dans le depot (relatif) ? Un chemin absolu est hors depot."""
    text = str(relative or "").replace("\\", "/")
    if not text:
        return False
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        return False
    return True


def is_scratch(relative: str) -> bool:
    """Fichier provisoire (hors depot) : autorise, non compte comme travail projet."""
    text = str(relative or "").replace("\\", "/").lower()
    if not text:
        return False
    if text.startswith("/tmp/") or text.startswith("tmp/"):
        return True
    return any(text.startswith(prefix) for prefix in SCRATCH_PREFIXES)


def _matches_anywhere(relative: str, prefixes: list[str]) -> bool:
    """Le motif est-il present dans le chemin, quel que soit le racine ?

    Indispensable : un chemin ABSOLU hors depot (C:/autre/CODE/x.st) doit tomber
    dans la meme deny-list qu'un chemin relatif du depot.
    """
    import fnmatch
    text = str(relative or "").replace("\\", "/")
    lowered = text.lower()
    for prefix in prefixes:
        clean = str(prefix).replace("\\", "/").rstrip("/")
        if not clean:
            continue
        base = clean[:-3] if clean.endswith("/**") else clean
        if "*" in base:
            pattern = base.lower()
            for index in range(len(lowered) - len(pattern) + 1):
                chunk = lowered[index:index + len(pattern)]
                if fnmatch.fnmatch(chunk, pattern):
                    return True
            continue
        marker = "/" + base.lower()
        if lowered.startswith(base.lower() + "/") or lowered == base.lower():
            return True
        if marker in lowered:
            # n'importe quelle occurrence du motif dans le chemin (CODE/, scripts/, ...)
            return True
    return False


def is_absolute_denied(relative: str, pinned_allowed: list[str] | None = None) -> bool:
    """Chemin protege : interdit SAUF si le perimetre EPINGLE l'autorisait deja.

    Regle : la protection porte sur ce que la session N'A PAS obtenu avant de commencer.
    Un contrat PLC legitime (CODE/) declare avant la session reste valable ; un
    auto-elargissement en cours de session est bloque (empreinte divergente).
    """
    allowed = list(pinned_allowed or [])
    if matches(relative, allowed) or _matches_anywhere(relative, allowed):
        return False  # le perimetre epingle l autorisait deja
    return (matches(relative, list(ABSOLUTE_DENY))
            or _matches_anywhere(relative, list(ABSOLUTE_DENY)))


def classify(relative: str, product: list[str], forbidden: list[str], process: list[str]) -> str:
    """produit | processus | hors."""
    if is_absolute_denied(relative) or matches(relative, forbidden):
        return "hors"
    if matches(relative, product):
        return "produit"
    if matches(relative, process):
        return "processus"
    return "hors"


def scope_digest(allowed: list[str], forbidden: list[str]) -> str:
    """Empreinte stable du perimetre (canonique : trie, sans blancs)."""
    import hashlib
    payload = json.dumps({"allowed": sorted(str(x).strip() for x in allowed),
                          "forbidden": sorted(str(x).strip() for x in forbidden)},
                         ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def scope_for_task(task_id: str) -> dict:
    """Perimetre lu SUR LE DISQUE (etat courant) + son empreinte."""
    contract = contract_for_task(task_id) if task_id else None
    allowed, forbidden = _scope_lists(contract) if contract else ([], [])
    return {"allowed": allowed, "forbidden": forbidden,
            "digest": scope_digest(allowed, forbidden),
            "contract": str(contract.relative_to(ROOT).as_posix()) if contract else ""}


SCOPE_DIR = LOCAL_APP / "ExcavatriceDragage" / "scopes"


def pinned_path(session_id: str) -> Path:
    safe = "".join(char for char in str(session_id or "session") if char.isalnum() or char in "-_")[:80]
    return SCOPE_DIR / f"{safe}.json"


def write_pinned(session_id: str, task_id: str, native_id: str = "") -> dict:
    """Ecrit le perimetre epingle (appele par le service a l'affectation)."""
    scope = scope_for_task(task_id) if task_id else {"allowed": [], "forbidden": [], "digest": ""}
    payload = {"session_id": session_id, "native_id": native_id or session_id,
               "task_id": task_id, "allowed": scope.get("allowed", []),
               "forbidden": scope.get("forbidden", []), "digest": scope.get("digest", ""),
               "contract": scope.get("contract", ""),
               "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    try:
        SCOPE_DIR.mkdir(parents=True, exist_ok=True)
        # La CLE du fichier est l ID NATIF de session : c'est celle que lit le hook.
        pinned_path(native_id or session_id).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass
    return payload


def pinned_scope(session_id: str) -> dict:
    """Perimetre EPINGLE (fichier du service, puis API en repli)."""
    try:
        data = json.loads(pinned_path(session_id).read_text(encoding="utf-8"))
        if data.get("digest"):
            return data
    except (OSError, ValueError):
        pass
    try:
        with urllib.request.urlopen(SUPERVISOR_SUMMARY_URL, timeout=1.5) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (OSError, ValueError):
        return {}
    for item in data.get("sessions", []):
        if str(item.get("native_id") or "") == session_id:
            snapshot = item.get("scope_snapshot")
            return snapshot if isinstance(snapshot, dict) else {}
    return {}


def verify_scope(session_id: str) -> dict:
    """Compare le perimetre courant (disque) au perimetre epingle (service).

    Divergence -> le contrat a ete modifie en session : tentative d'auto-elargissement,
    elle doit etre signalee, pas appliquee.
    """
    pinned = pinned_scope(session_id)
    if not pinned or not pinned.get("digest"):
        return {"ok": True, "reason": "aucun perimetre epingle"}
    task_id = pinned.get("task_id") or ""
    current = scope_for_task(task_id) if task_id else {"digest": ""}
    ok = current.get("digest") == pinned.get("digest")
    return {"ok": ok, "pinned_digest": pinned.get("digest"), "current_digest": current.get("digest"),
            "task_id": task_id, "reason": "identique" if ok else "perimetre modifie en session",
            "allowed": pinned.get("allowed", []), "forbidden": pinned.get("forbidden", [])}


def effective_scope(session_id: str) -> dict:
    """Perimetre EFFECTIF de la session : l'EPINGLE s'il existe, sinon le contrat courant.

    Le contrat du disque peut avoir ete elargi en cours de session : le perimetre
    epingle (fige par le service a l affectation) reste, lui, le reference.
    """
    scope = scope_for_session(session_id)
    pinned = pinned_scope(session_id)
    if pinned.get("digest"):
        scope = dict(scope)
        scope["produit"] = list(pinned.get("allowed") or [])
        scope["interdits"] = list(pinned.get("forbidden") or [])
        scope["pinned"] = True
        scope["digest"] = pinned.get("digest")
    return scope


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


def write_derogation(session_id: str, path: str, motif: str, ttl_days: int = 30) -> dict:
    """Derogation ACCORDEE mais DATEDE (GLM 2026-11-13) : pas d'arrimage eternel."""
    entries = read_derogations(session_id)
    entry = {"path": normalize(path), "motif": str(motif or "").strip()[:300],
             "granted_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
             "expires_at": time.time() + max(1, int(ttl_days)) * 86400,
             "ttl_days": int(ttl_days)}
    if not any(item.get("path") == entry["path"] for item in entries):
        entries.append(entry)
    DEROG_DIR.mkdir(parents=True, exist_ok=True)
    derogations_path(session_id).write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    return entry


def is_derogated(session_id: str, relative: str) -> bool:
    """Une derogation vaut pour un chemin exact ou pour un prefixe marque '.../**'."""
    now = time.time()
    for item in read_derogations(session_id):
        granted = str(item.get("path") or "")
        if not granted:
            continue
        expiry = item.get("expires_at")
        if isinstance(expiry, (int, float)) and expiry < now:
            continue  # derogation expiree
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


def git_modified_paths(root=None) -> list[str]:
    """Fichiers modifies / ajoutes dans le depot (git status --porcelain)."""
    import subprocess
    base = str(root or ROOT)
    try:
        done = subprocess.run(["git", "status", "--porcelain"], cwd=base, capture_output=True,
                              text=True, timeout=5, encoding="utf-8", errors="replace")
    except (OSError, subprocess.SubprocessError):
        return []
    if done.returncode != 0:
        return []
    paths = []
    for line in done.stdout.splitlines():
        if len(line) < 4:
            continue
        raw = line[3:].strip().strip('"')
        if " -> " in raw:
            raw = raw.split(" -> ")[-1]
        paths.append(normalize(raw))
    return paths


def untracked_writes(session_id: str, root=None) -> list[str]:
    """Ecritures reellement faites (git) mais ABSENTES du journal des ecritures."""
    logged = set(logged_paths(session_id, window=0))
    return [path for path in git_modified_paths(root) if path and path not in logged]


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
