#!/usr/bin/env python3
"""État déterministe de la commande /workflow-project (T427 I1c).

Sous-commandes :
  enter [fresh|resume]  -> workflow ACTIF pour cette session
  off                   -> workflow INACTIF pour cette session
  status                -> lit l'état, n'écrit rien

Règles :
  * État PAR SESSION : clé = --session, sinon variable CLAUDE_CODE_SESSION_ID.
    Sans clé -> INDÉTERMINÉ, aucune écriture (jamais d'état supposé).
  * Fichier hors dépôt : %LOCALAPPDATA%/ExcavatriceDragage/workflow/<clé>.json
    (zéro impact sur git, routage T279 et .gitignore).
  * Écriture atomique (tmp + os.replace). Fichier absent ou illisible -> INDÉTERMINÉ.
  * Sans argument, `enter` = `fresh`. Aucune question, aucun dialogue.
  * Ne touche jamais au catalogue, aux verrous ni au code.

Sortie : bloc déterministe (lignes mécaniques + 3 champs laissés à l'agent).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trace_log  # noqa: E402  (journal interne)

ROOT = Path(__file__).resolve().parents[3]
TASKS = ROOT / "DOC" / "WFLOW" / "TASKS.yaml"
SUMMARY = ROOT / "DOC" / "WFLOW" / "TASKS_ACTIVE_SUMMARY.md"
AGENTS = ROOT / "AGENTS.md"
VALID_MODES = ("fresh", "resume")


def state_dir() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / ".local" / "share")
    return Path(base) / "ExcavatriceDragage" / "workflow"


def session_key(arg: str | None) -> str | None:
    key = (arg or os.environ.get("CLAUDE_CODE_SESSION_ID") or "").strip()
    if not key or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", key):
        return None
    return key


def read_state(key: str) -> dict | None:
    path = state_dir() / f"{key}.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if data.get("session_id") != key or data.get("etat") not in ("ACTIF", "OFF"):
        return None
    return data


VOIES = {"1": "Orchestrateur", "2": "Tâche", "3": "Troubleshooting"}
# Ligne d'etape du projet (AGENTS.md § "Ligne d'etape").
ETAPES = ("CADRAGE", "ÉTUDE", "RÉALISATION", "TEST", "RESTITUTION", "DIAGNOSTIC", "ARRÊT")


def write_state(key: str, etat: str, mode: str | None, voie: str | None = None,
                etape: str | None = None) -> dict:
    prev = read_state(key) or {}
    data = {
        "session_id": key,
        "etat": etat,
        "mode": mode or prev.get("mode", "fresh"),
        "voie": voie,
        "etape": etape or prev.get("etape"),
        "seq": int(prev.get("seq", 0)) + 1,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    folder = state_dir()
    folder.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=folder, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False)
    os.replace(tmp, folder / f"{key}.json")
    return data


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summary_status() -> tuple[str, str]:
    """Retourne (ligne compteurs, état de fraîcheur) depuis TASKS_ACTIVE_SUMMARY.md."""
    if not SUMMARY.is_file():
        return "résumé absent", "ABSENT"
    text = SUMMARY.read_text(encoding="utf-8", errors="replace")
    head = re.search(r"sha256\(TASKS\.yaml\)=([0-9a-f]{64})", text)
    counts = re.search(r"\*\*Compteurs\*\*\s*:\s*(.+)", text)
    if not head or not TASKS.is_file():
        return (counts.group(1).strip() if counts else "compteurs inconnus"), "INCONNUE"
    fresh = "À JOUR" if head.group(1) == sha256(TASKS) else "PÉRIMÉ (régénérer)"
    return (counts.group(1).strip() if counts else "compteurs inconnus"), fresh


SUPERVISOR_URL = "http://127.0.0.1:8082/api/supervision/summary"


def supervisor_alias(key: str) -> str | None:
    """Alias de la session dans le Superviseur (ex. T427-CC02), ou None si non rattachée/injoignable."""
    import urllib.request
    try:
        with urllib.request.urlopen(SUPERVISOR_URL, timeout=1.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (OSError, ValueError):
        return None
    for item in data.get("sessions", []):
        if item.get("native_id") == key:
            return str(item.get("alias") or "") or None
    return None


def task_of_alias(alias: str | None) -> str | None:
    """TXXX extrait de l'alias (T427-CC02 -> T427). T000 ou absent = hors catalogue."""
    m = re.match(r"^(T\d{3}(?:-[A-Z0-9]+)?)-", alias or "")
    if not m or m.group(1).startswith("T000"):
        return None
    return m.group(1)


def task_title(task_id: str) -> str:
    """Titre officiel depuis TASKS.yaml (lecture ciblée, sans affichage du fichier entier)."""
    try:
        import yaml
        tasks = yaml.safe_load(TASKS.read_text(encoding="utf-8")) or []
    except (OSError, ValueError, ImportError):
        return "titre indisponible"
    if isinstance(tasks, dict):
        tasks = tasks.get("tasks", [])
    for item in tasks:
        if isinstance(item, dict) and str(item.get("id")) == task_id:
            return " ".join(str(item.get("titre") or "sans titre").split())
    return "tâche absente du catalogue"


def identity_lines(key: str, alias: str | None) -> list[str]:
    """Session + tâche, toujours affichées avec leur nom."""
    short = key[:8]
    if alias is None:
        return [
            f"🆔 Session : {short}… · non rattachée au Superviseur (ou Superviseur injoignable)",
            "🎯 Tâche : aucune (non rattachée)",
        ]
    task = task_of_alias(alias)
    if task is None:
        return [
            f"🆔 Session : {alias} · {short}…",
            f"🎯 Tâche : aucune · hors catalogue (session {alias})",
        ]
    return [
        f"🆔 Session : {alias} · {short}…",
        f"🎯 Tâche : {task} — {task_title(task)}",
    ]


def render(etat: str, mode: str | None, seq: int | None, key: str = "", alias: str | None = None,
           voie: str | None = None, etape: str | None = None) -> str:
    counts, fresh = summary_status()
    agents_ok = "présent" if AGENTS.is_file() else "ABSENT — arrêt"
    token = f"{etat}/{seq}" if seq is not None else etat
    head_id = task_of_alias(alias) or (alias or "sans session")
    lines = [
        f"{'🟢' if etat == 'ACTIF' else '🔴' if etat == 'OFF' else '⚪'} "
        f"{head_id} · WORKFLOW {etat} · token {token}",
    ]
    if key:
        lines += identity_lines(key, alias)
    lines += [
        f"🧭 Mode : {mode or '—'}",
        f"🪜 Étape : {etape or '— (non renseignée)'}",
        f"📊 Projet : {counts} · résumé {fresh}",
        f"📚 AGENTS.md : {agents_ok}",
    ]
    # Fin de bloc FIGÉE : menu numéroté, pas de question libre, pas de choix rédigé par le LLM.
    if etat == "ACTIF":
        lines += [
            f"🧭 Voie : {voie or 'aucune (libre = réponse directe)'}",
            "",
            "Choix :",
            "1 · Orchestrateur (piloter un lot, valider avant code)",
            "2 · Tâche (prendre une tâche du catalogue, verrous)",
            "3 · Troubleshooting (diagnostiquer un incident)",
            "0 · Quitter le workflow",
            "Tape le numéro : /workflow-project 1 · 2 · 3 · 0",
            "Ou écris ta demande : elle reste une réponse directe.",
        ]
    elif etat == "OFF":
        lines.append("⏹️ Workflow quitté. Pour revenir : /workflow-project")
    else:
        lines.append("⚠️ État inconnu : aucune supposition. Relancer avec /workflow-project.")
    return "\n".join(lines)


def dispatch(text: str) -> tuple[str, str | None] | None:
    """Traduit le texte tapé après /workflow-project en (commande, mode). None si inconnu."""
    word = text.strip().lower()
    if word in ("", "fresh"):
        return "enter", "fresh"
    if word == "resume":
        return "enter", "resume"
    if word in ("0", "off"):
        return "off", None
    if word in VOIES:
        return "voie", word
    return None


def main(argv: list[str] | None = None) -> int:
    # Windows (cp1252) ne sait pas afficher les emojis : sortie forcée en UTF-8.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "cmd":
        # Mode commande : `cmd <texte tapé>` (ex. "resume", "off", vide = fresh). Déterministe.
        text = " ".join(a for a in argv[1:] if not a.startswith("--"))
        routed = dispatch(text)
        if routed is None:
            print(f"ERREUR : argument inconnu « {text} » (attendu : resume | fresh | off, ou rien).")
            return 2
        argv = [routed[0]] + ([routed[1]] if routed[1] else [])
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("enter", "off", "status", "voie", "etape"))
    parser.add_argument("mode", nargs="?", default=None, help="fresh | resume (pour enter)")
    parser.add_argument("--session", default=None, help="clé de session (sinon CLAUDE_CODE_SESSION_ID)")
    args = parser.parse_args(argv)

    if args.command == "enter" and args.mode is not None and args.mode not in VALID_MODES:
        print(f"ERREUR : mode inconnu « {args.mode} » (attendu : fresh | resume).", file=sys.stderr)
        return 2

    key = session_key(args.session)
    if key is None:
        print(render("INDÉTERMINÉ", None, None))
        print("⚠️ Aucune clé de session : rien n'est enregistré. Relancer avec --session <id>.")
        return 0

    alias = supervisor_alias(key)

    if args.command == "etape":
        cur = read_state(key)
        if cur is None or cur.get("etat") != "ACTIF":
            print("⚠️ Workflow non actif : tape /workflow-project d'abord.")
            return 0
        wanted = (args.mode or "").strip().upper()
        if wanted not in ETAPES:
            print(f"ERREUR : étape inconnue « {wanted} » (attendu : {', '.join(ETAPES)}).", file=sys.stderr)
            return 2
        data = write_state(key, "ACTIF", cur.get("mode"), voie=cur.get("voie"), etape=wanted)
        trace_log.emit("workflow", session=key, etat="ACTIF", voie=data.get("voie"),
                       etape=data.get("etape"), seq=data.get("seq"))
        print(render(data["etat"], data["mode"], data["seq"], key, alias, data.get("voie"), data.get("etape")))
        return 0

    if args.command == "status":
        data = read_state(key)
        if data is None:
            print(render("INDÉTERMINÉ", None, None, key, alias))
            print("⚠️ Pas d'état lisible pour cette session : traiter comme INACTIF, rien n'est supposé.")
            return 0
        print(render(data["etat"], data.get("mode"), data.get("seq"), key, alias, data.get("voie"), data.get("etape")))
        return 0

    if args.command == "voie":
        cur = read_state(key)
        if cur is None or cur.get("etat") != "ACTIF":
            print("⚠️ Workflow non actif : tape /workflow-project d'abord, puis le numéro.")
            return 0
        data = write_state(key, "ACTIF", cur.get("mode"), voie=VOIES[args.mode])
        trace_log.emit("workflow", session=key, etat="ACTIF", voie=data.get("voie"),
                       etape=data.get("etape"), seq=data.get("seq"))
        print(render(data["etat"], data["mode"], data["seq"], key, alias, data["voie"], data.get("etape")))
        return 0

    if args.command == "enter":
        data = write_state(key, "ACTIF", args.mode or "fresh")
    else:
        data = write_state(key, "OFF", None)
    trace_log.emit("workflow", session=key, etat=data["etat"], mode=data.get("mode"),
                   voie=data.get("voie"), etape=data.get("etape"), seq=data.get("seq"))
    print(render(data["etat"], data["mode"], data["seq"], key, alias, data.get("voie"), data.get("etape")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
