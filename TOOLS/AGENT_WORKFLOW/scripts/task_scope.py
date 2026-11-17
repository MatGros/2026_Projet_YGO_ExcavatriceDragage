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
import fnmatch
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
    "TOOLS/AGENT_WORKFLOW/scripts/hook_shell_scope_guard.py",
    "TOOLS/AGENT_WORKFLOW/scripts/trace_log.py",
    "TOOLS/AGENT_WORKFLOW/scripts/miss_log.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_workflow_attest.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_pre_edit.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_post_edit.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_stop.py",
    "TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py",
)

# Interdiction DURE (T427 P1, GO exploitant 2026-11-15) : aucune DEROGATION ne la leve.
# Seul le perimetre EPINGLE d'un contrat valide (ex. tache PLC sur CODE/) l'autorise.
HARD_DENY = (
    "CODE/**",
    "CODE_XML/**",
    "PRJ_CODESYS/**",
    "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_scope_guard.py",
    "TOOLS/AGENT_WORKFLOW/scripts/hook_shell_scope_guard.py",
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


def _components(text: str) -> list[str]:
    """Composants canonises d'un chemin (minuscules, sans lecteur, sans point final).

    Un point ou un espace final est retire : sous Windows, `CODE.` designe le meme
    dossier que `CODE`, et laisser passer cette variante ouvrirait la deny-list.
    """
    parts: list[str] = []
    for raw in str(text or "").replace("\\", "/").split("/"):
        comp = raw.strip().lower()
        if not comp or comp == ".":
            continue
        if len(comp) >= 2 and comp[1] == ":":
            comp = comp[2:].strip()
            if not comp:
                continue
        comp = comp.rstrip(". ").strip()
        if comp:
            parts.append(comp)
    return parts


SHORT_NAME = re.compile(r"^(.{1,6})~\d+$")
_COMPONENTS_CACHE: dict[str, list[str]] = {}


def _deny_components(prefix: str) -> list[str]:
    """Composants d'un motif de deny-list, calcules une seule fois par motif."""
    cached = _COMPONENTS_CACHE.get(prefix)
    if cached is None:
        clean = str(prefix or "").replace("\\", "/").rstrip("/")
        base = clean[:-3] if clean.endswith("/**") else clean
        cached = _components(base)
        _COMPONENTS_CACHE[prefix] = cached
    return cached


def _short_stem(comp: str) -> str | None:
    """Racine d'un nom court 8.3, avec ou sans extension (`AGENT_~1`, `TASK_S~1.PY`)."""
    main, _dot, _ext = comp.partition(".")
    match = SHORT_NAME.match(main)
    return match.group(1) if match else None


def _comp_matches(window: str, pattern: str, strict: bool = False) -> bool:
    """Un composant correspond-il au motif ? Egalite, joker, ou alias court 8.3.

    Le nom court Windows tronque la racine a six caracteres : `AGENT_~1` pour
    `AGENT_WORKFLOW`, et `TASK_S~1.PY` pour `task_scope.py` (l'extension suit le
    tilde). Verifie le 2026-11-17 : `TOOLS/AGENT_~1/scripts/task_scope.py` et le
    vrai fichier de garde sont le meme (samefile).

    `strict=True` desactive l'alias court : la comparaison sert alors a une liste
    d'AUTORISATION, ou une tolerance transformerait un perimetre epingle en passe-droit.
    """
    if any(ch in pattern for ch in "*?["):
        return fnmatch.fnmatch(window, pattern)
    if window == pattern:
        return True
    if strict:
        return False
    stem = _short_stem(window)
    if stem and (pattern.startswith(stem) or stem.startswith(pattern)):
        return True
    # Forme large : `SCRIPTS~1`. NTFS ne produit pas ce nom, mais refuser la forme
    # coute moins cher que dependre de la facon dont le volume a nomme le dossier.
    window_stem = window.partition(".")[0]
    return window_stem.startswith(pattern.partition(".")[0] + "~")


def _matches_anywhere(relative: str, prefixes: list[str], strict: bool = False) -> bool:
    """Le motif est-il present dans le chemin, quel que soit la racine ?

    Indispensable : un chemin ABSOLU hors depot (C:/autre/CODE/x.st) doit tomber
    dans la meme deny-list qu'un chemin relatif du depot.

    Comparaison par COMPOSANTS ENTIERS, jamais par sous-chaine (correctif 2026-11-17) :
    `codex_notes.md` ou `DOC/code_review/` ne doivent pas etre refuses parce qu'ils
    contiennent les lettres « code » ; `.../CODE/x.st` doit l'etre parce qu'un de ses
    composants EST `code`.
    """
    parts = _components(relative)
    if not parts:
        return False
    for prefix in prefixes:
        want = _deny_components(str(prefix or ""))
        if not want:
            continue
        span = len(want)
        for start_index in range(len(parts) - span + 1):
            window = parts[start_index:start_index + span]
            if all(_comp_matches(win, pat, strict) for win, pat in zip(window, want)):
                return True
    return False


def is_absolute_denied(relative: str, pinned_allowed: list[str] | None = None) -> bool:
    """Chemin protege : interdit SAUF si le perimetre EPINGLE l'autorisait deja.

    Regle : la protection porte sur ce que la session N'A PAS obtenu avant de commencer.
    Un contrat PLC legitime (CODE/) declare avant la session reste valable ; un
    auto-elargissement en cours de session est bloque (empreinte divergente).

    La liste d'autorisation est comparee en mode STRICT : sans cela, un nom court
    comme `CODE/MA~1/x.st` serait reconnu comme `CODE/MAIN` et ouvrirait une
    ecriture que le contrat n'a jamais autorisee (revue 2026-11-17).
    """
    if "\x00" in str(relative or ""):
        return True  # octet nul : jamais legitime, refuse avant toute autre analyse
    allowed = list(pinned_allowed or [])
    if matches(relative, allowed) or _matches_anywhere(relative, allowed, strict=True):
        return False  # le perimetre epingle l autorisait deja
    return (matches(relative, list(ABSOLUTE_DENY))
            or _matches_anywhere(relative, list(ABSOLUTE_DENY)))


def is_hard_denied(relative: str) -> bool:
    """Chemin qu'aucune derogation ne peut ouvrir (CODE/, sources automate, garde-fous)."""
    if "\x00" in str(relative or ""):
        return True
    return matches(relative, list(HARD_DENY)) or _matches_anywhere(relative, list(HARD_DENY))


def classify(relative: str, product: list[str], forbidden: list[str], process: list[str],
             pinned_allowed: list[str] | None = None) -> str:
    """produit | processus | hors.

    T427 P1 : le perimetre EPINGLE du contrat est transmis, sinon un chemin protege que le
    contrat autorise (ex. skills/orchestrator/) etait classe hors et exigeait une derogation.
    """
    if is_absolute_denied(relative, pinned_allowed) or matches(relative, forbidden):
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


class DerogationRefusee(ValueError):
    """Derogation refusee : motif absent, citation introuvable ou chemin a interdiction dure."""


def _user_messages(transcript) -> list:
    """Textes des messages humains du transcript (jsonl Claude Code)."""
    texts = []
    if not transcript:
        return texts
    try:
        with open(transcript, "r", encoding="utf-8", errors="replace") as stream:
            for line in stream:
                if '"user"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if entry.get("type") != "user":
                    continue
                content = (entry.get("message") or {}).get("content")
                if isinstance(content, str):
                    texts.append(content)
                elif isinstance(content, list):
                    texts.extend(str(c.get("text", "")) for c in content
                                 if isinstance(c, dict) and c.get("type") == "text")
    except OSError:
        return []
    return texts


def citation_from_user(transcript, citation: str) -> bool:
    """Vrai si la citation figure MOT POUR MOT dans un message humain (aucune reformulation)."""
    cite = " ".join(str(citation or "").split())
    if len(cite) < 2:
        return False
    return any(cite in " ".join(text.split()) for text in _user_messages(transcript))


def write_derogation(session_id: str, path: str, motif: str, ttl_days: int = 30,
                     transcript=None) -> dict:
    """Derogation ACCORDEE mais DATEDE (GLM 2026-11-13) : pas d'arrimage eternel.

    T427 P1 : motif OBLIGATOIRE, copie mot pour mot d'un message humain du transcript.

    2026-11-18 : plus d'interdiction sans issue. Un chemin protege (CODE/, CODE_XML/,
    PRJ_CODESYS/, fichiers de garde) s'ouvre par une citation EXACTE de l'exploitant,
    verifiee dans le transcript : l'agent ne peut pas l'inventer, l'exploitant garde la
    cle. Le refus reste le defaut, et il persiste tant que la phrase n'a pas ete dite.
    """
    if not str(motif or "").strip():
        raise DerogationRefusee("motif obligatoire : citer mot pour mot le message de l'exploitant")
    if not citation_from_user(transcript, motif):
        raise DerogationRefusee("citation introuvable dans les messages humains du transcript : "
                                "le motif doit etre copie mot pour mot, sans reformulation")
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
    """Une derogation vaut pour un chemin exact ou pour un prefixe marque '.../**'.

    2026-11-18 : vaut aussi pour un chemin protege, des lors que l'exploitant l'a
    accorde par une citation exacte (voir `write_derogation`).
    """
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
    p_derog.add_argument("--motif", required=True, help="citation EXACTE du message de l exploitant")
    p_derog.add_argument("--transcript", default="", help="transcript de la session (sinon CLAUDE_TRANSCRIPT_PATH)")

    args = parser.parse_args(argv)

    if args.command == "scope":
        scope = scope_for_session(args.session)
        print(json.dumps(scope, ensure_ascii=False, indent=2))
        return 0

    if args.command == "deroge":
        transcript = args.transcript or os.environ.get("CLAUDE_TRANSCRIPT_PATH", "")
        try:
            entry = write_derogation(args.session, args.path, args.motif, transcript=transcript)
        except DerogationRefusee as exc:
            print(f"Dérogation REFUSÉE : {exc}")
            return 2
        print(f"Dérogation enregistrée : {entry['path']} — {entry['motif']}")
        return 0

    transcript = args.transcript or os.environ.get("CLAUDE_TRANSCRIPT_PATH", "")
    if not transcript:
        print(json.dumps({"error": "transcript absent : passer --transcript"}, ensure_ascii=False))
        return 2
    print(json.dumps(metric(args.session, transcript, args.window), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
