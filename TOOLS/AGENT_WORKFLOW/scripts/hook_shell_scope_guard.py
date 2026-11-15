#!/usr/bin/env python3
"""Hook PreToolUse : garde de perimetre des commandes shell (T427 lot 2).

Trou ferme : `hook_scope_guard.py` n'est branche que sur `Edit|Write|MultiEdit`
(voir `.claude/settings.json`). Une ecriture faite par `Bash` ou `PowerShell` —
`> CODE/x.st`, `Set-Content`, `cp`, `Remove-Item`, `git apply` — ne passait donc
jamais par le garde.

PORTEE : la deny-list du projet uniquement (code machine, reglages, hooks,
gardes, skills). Le perimetre produit de la tache n'est PAS applique ici : sur
une ligne de commande, lecture et ecriture ne se distinguent pas de facon
fiable, et un garde qui crie a tort finit desactive.

LIMITE ASSUMEE : analyse lexicale de la commande. Elle ferme la negligence et
l'accident, pas le contournement delibere (variable, base64, sous-processus,
script tiers). Pour l'etancheite reelle : ACL Windows ou compte restreint.

Modes : `TASK_SCOPE_GUARD` = block (defaut) | report.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import task_scope  # noqa: E402  (chemin local du script)

SHELL_TOOLS = ("Bash", "PowerShell")

# Verbes dont TOUS les arguments positionnels designent un chemin touche.
ALL_POSITIONAL = frozenset({
    "rm", "rmdir", "del", "erase", "touch", "truncate", "tee", "clear-content",
    "remove-item", "set-itemproperty",
})
# Verbes dont le DERNIER argument positionnel est la destination.
LAST_POSITIONAL = frozenset({"cp", "mv", "install", "copy-item", "move-item", "rename-item"})
# Verbes dont le PREMIER argument positionnel est la cible.
FIRST_POSITIONAL = frozenset({"set-content", "add-content", "out-file", "tee-object", "new-item"})

VERB = re.compile(
    r"\b(?P<verb>Set-Content|Add-Content|Clear-Content|New-Item|Remove-Item|"
    r"Move-Item|Copy-Item|Rename-Item|Tee-Object|Out-File|Set-ItemProperty|"
    r"truncate|touch|install|rmdir|tee|rm|mv|cp|del|erase)\b(?P<args>[^;|&\n]*)",
    re.I,
)
REDIRECT = re.compile(r"(?<![0-9&<>])>{1,2}\s*(?P<p>\"[^\"]+\"|'[^']+'|[^\s;|&<>]+)")
FLAG_PATH = re.compile(
    r"-(?:FilePath|LiteralPath|Path|Destination|OutFile)\s+(?P<p>\"[^\"]+\"|'[^']+'|[^\s;|&]+)",
    re.I,
)
DD_OUT = re.compile(r"\bof=(?P<p>[^\s;|&]+)")
GIT_APPLY = re.compile(r"\bgit\s+apply\b(?P<args>[^;|&\n]*)", re.I)
GIT_MUTATE = re.compile(r"\bgit\s+(?:checkout|restore|clean)\b(?P<args>[^;|&\n]*)", re.I)
PATCH_PATH = re.compile(r"^(?:\+\+\+|---)\s+[ab]/(?P<p>.+?)\s*$")
PATCH_MAX_BYTES = 2_000_000


def mode() -> str:
    """Refus ACTIF par defaut. 'report' = simple signalement."""
    value = (os.environ.get("TASK_SCOPE_GUARD") or "block").strip().lower()
    return value if value in ("report", "block") else "block"


def _clean(token: str) -> str:
    text = str(token or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1]
    return text.strip()


def _is_path_token(token: str) -> bool:
    text = _clean(token)
    if not text or text.startswith("-"):
        return False
    if text.startswith("$") or text.startswith("%") or text in ("&1", "&2", "nul", "NUL"):
        return False
    return True


def _positionals(args: str) -> list[str]:
    return [_clean(t) for t in re.split(r"\s+", str(args or "").strip()) if _is_path_token(t)]


def _patch_targets(patch: str) -> list[str]:
    """Chemins declares par un patch git (`+++ b/...` / `--- a/...`). Vide si illisible."""
    try:
        path = Path(patch)
        if not path.is_file() or path.stat().st_size > PATCH_MAX_BYTES:
            return []
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    found = []
    for line in raw.splitlines():
        match = PATCH_PATH.match(line)
        if match:
            candidate = match.group("p").strip()
            if candidate and candidate != "/dev/null":
                found.append(candidate)
    return found


def written_paths(command: str) -> list[str]:
    """Chemins ecrits PAR la commande. Best-effort : liste vide si rien de reconnu."""
    text = str(command or "")
    found: list[str] = []

    for match in REDIRECT.finditer(text):
        found.append(_clean(match.group("p")))
    if REDIRECT.search(text) or DD_OUT.search(text) or VERB.search(text) or GIT_APPLY.search(text) or GIT_MUTATE.search(text):
        for match in FLAG_PATH.finditer(text):
            found.append(_clean(match.group("p")))
    for match in DD_OUT.finditer(text):
        found.append(_clean(match.group("p")))

    for match in VERB.finditer(text):
        verb = match.group("verb").lower()
        tokens = _positionals(match.group("args"))
        if not tokens:
            continue
        if verb in LAST_POSITIONAL:
            found.append(tokens[-1])  # source en lecture : seule la destination compte
        elif verb in FIRST_POSITIONAL:
            found.append(tokens[0])
        elif verb in ALL_POSITIONAL:
            found.extend(tokens)

    for match in GIT_MUTATE.finditer(text):
        found.extend(_positionals(match.group("args")))

    # `git apply <patch>` : le patch nomme ses cibles, on les lit.
    for match in GIT_APPLY.finditer(text):
        for candidate in _positionals(match.group("args")):
            found.extend(_patch_targets(candidate))

    seen = []
    for item in found:
        if item and item not in seen:
            seen.append(item)
    return seen


def evaluate(command: str, session_id: str = "") -> dict:
    """Refuse une commande qui ecrit sur un chemin de la deny-list. Pur, sans effet de bord."""
    pinned_allowed: list[str] = []
    if session_id:
        try:
            pinned_allowed = list((task_scope.pinned_scope(session_id) or {}).get("allowed") or [])
        except Exception:
            pinned_allowed = []

    hits: list[str] = []
    for raw in written_paths(command):
        relative = task_scope.normalize(raw)
        if task_scope.is_scratch(relative):
            continue
        if task_scope.is_absolute_denied(relative, pinned_allowed):
            if relative not in hits:
                hits.append(relative)

    if hits:
        return {"decision": "block", "hits": hits, "pinned": pinned_allowed}
    return {"decision": "allow", "hits": [], "pinned": pinned_allowed}


def _record(session_id: str, verdict: dict) -> None:
    """Journalisation best-effort : jamais bloquante, rien sans session."""
    if not session_id:
        return
    try:
        import trace_log
        trace_log.emit("ecriture-shell", session=session_id, decision=verdict["decision"],
                       hits=verdict["hits"])
    except Exception:
        pass
    if verdict["decision"] != "block":
        return
    try:
        import miss_log
        miss_log.record(session_id, "M10",
                        "Ecriture shell sur un chemin interdit : " + ", ".join(verdict["hits"]),
                        "deny-list globale (garde shell)")
    except Exception:
        pass


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("tool_name") not in SHELL_TOOLS:
        return 0

    session_id = str(payload.get("session_id") or "").strip()
    command = str((payload.get("tool_input") or {}).get("command") or "").strip()
    if not command:
        return 0

    try:
        verdict = evaluate(command, session_id)
    except Exception:
        return 0  # infrastructure : on ne bloque jamais sur un probleme d'outillage

    _record(session_id, verdict)
    if verdict["decision"] == "allow":
        return 0

    message = (
        "ECRITURE INTERDITE PAR LA REGLE DU PROJET (commande shell) :\n"
        + "\n".join(f"  - {entry}" for entry in verdict["hits"])
        + "\n\nLe garde ne voit ici que la deny-list globale : code machine, sources automate,\n"
        "reglages, hooks, gardes et skills. Aucune derogation script ne l ouvre.\n"
        "Corrige la commande (ecris ailleurs, ou passe par un outil dedie),\n"
        "ou demande a l exploitant de le faire hors de l agent.\n"
    )
    print(message, file=sys.stderr)
    if mode() == "report":
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
