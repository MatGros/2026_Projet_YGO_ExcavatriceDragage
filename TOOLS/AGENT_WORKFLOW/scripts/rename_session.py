#!/usr/bin/env python3
"""
TOOLS/AGENT_WORKFLOW/scripts/rename_session.py
Commande robuste et atomique pour renommer une session de travail multi-CLI (Antigravity, Claude Code, etc.).
Spécification durcie Cycle 3 validée par le Challenger (WAL INTENT/COMMIT, NFC, Whitelist déterministe).
"""

import sys
import os
import re
import json
import time
import queue
import subprocess
import threading
import unicodedata
import urllib.request
import urllib.parse
from pathlib import Path
from datetime import datetime, timezone

# Racine projet et chemins
REPO_ROOT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
APP_DATA = Path(r"C:\Users\ZEDVICTUS\.gemini\antigravity-cli")
AUDIT_LOG_FILE = REPO_ROOT / "DOC" / "WFLOW" / "SESSION_RENAME_AUDIT.log"
DIRTY_MARKER_FILE = REPO_ROOT / "DOC" / "WFLOW" / "SESSION_DIRTY_ALIASES.json"


class SupervisorSessionNotLinked(RuntimeError):
    """Rename was requested for a session not explicitly attached to Supervisor."""


def resolve_supervisor_session_id(session_id: str, platform: str,
                                  base_url: str = "http://127.0.0.1:8082",
                                  timeout: float = 1.0) -> str | None:
    """Return the unique existing assignment ID; never create or guess an assignment."""
    request = urllib.request.Request(
        f"{base_url}/api/supervision/summary",
        headers={"Accept": "application/json"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            summary = json.loads(response.read().decode("utf-8"))
    except Exception:
        return None
    linked = [
        item for item in summary.get("sessions", [])
        if item.get("platform") == platform and item.get("native_id") == session_id
    ]
    if not linked:
        raise SupervisorSessionNotLinked(
            f"Session {platform}:{session_id} non reliée au Superviseur ; lance /connect-session-supervisor d'abord"
        )
    if len(linked) != 1:
        raise SupervisorSessionNotLinked(
            f"Plusieurs affectations Superviseur correspondent à {platform}:{session_id} ; aucun renommage appliqué"
        )
    assignment_id = linked[0].get("id")
    if not assignment_id:
        raise SupervisorSessionNotLinked("Affectation Superviseur trouvée sans identifiant interne")
    return assignment_id

# Whitelist stricte et déterministe post-NFC : alphanumérique latin étendu, tiret, underscore, espace
# Interdiction formelle de démarrer par '-' ou espace (évite flags CLI et splitting)
RE_VALID_STRING = re.compile(r"^[A-Za-z0-9_À-ÖØ-öø-ÿ][A-Za-z0-9_ \-À-ÖØ-öø-ÿ]*$")
RE_TASK_ID = re.compile(r"^T\d+(?:-[0-9A-Z]+)*$")

def log_audit(action_type: str, session_id: str, old_alias: str, new_alias: str, status_code: int = 0):
    """Écriture atomique en mode append avec INTENT/COMMIT (Write-Ahead Logging)."""
    try:
        AUDIT_LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        now_iso = datetime.now(timezone.utc).isoformat()
        line = f"[{now_iso}] [{action_type}] [{session_id}] '{old_alias}' -> '{new_alias}' (code={status_code})\n"
        # Garanti atomique en append sur fichier local
        with open(AUDIT_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line)
            f.flush()
    except Exception as e:
        sys.stderr.write(f"[WARN] Impossible d'écrire l'audit log : {e}\n")

def mark_dirty_supervisor(session_id: str, alias: str, display_title: str = ""):
    """Enregistre une synchronisation en attente si le Superviseur est indisponible."""
    try:
        DIRTY_MARKER_FILE.parent.mkdir(parents=True, exist_ok=True)
        records = {}
        if DIRTY_MARKER_FILE.exists():
            try:
                with open(DIRTY_MARKER_FILE, "r", encoding="utf-8") as f:
                    records = json.load(f)
            except Exception:
                records = {}
        records[session_id] = {
            "alias": alias,
            "display_title": display_title or alias,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        with open(DIRTY_MARKER_FILE, "w", encoding="utf-8") as f:
            json.dump(records, f, indent=2)
    except Exception:
        pass

def sanitize_and_validate(raw_input: str) -> tuple[str, str, str]:
    """Valide et normalise l'entrée selon les critères stricts arrêtés.
    Retourne (task_id, alias_complet, description) ou lève ValueError."""
    if not raw_input:
        raise ValueError("L'entrée est vide. Usage: rename_session.py <TXXX[-ACTEUR]> <Description>")

    # 1. Normalisation Unicode NFC
    normalized = unicodedata.normalize("NFC", raw_input)

    # 2. Rejet si commence par un tiret ou espace
    if normalized.startswith("-") or normalized.startswith(" "):
        raise ValueError("Le nom ne peut pas commencer par un tiret ou un espace.")

    normalized = normalized.strip()
    if not normalized:
        raise ValueError("L'entrée est vide. Usage: rename_session.py <TXXX[-ACTEUR]> <Description>")

    # 3. Vérification whitelist déterministe
    if not RE_VALID_STRING.match(normalized):
        raise ValueError(
            f"Caractères non autorisés détectés dans : '{normalized}'. "
            "Seuls les caractères alphanumériques, tirets, underscores et espaces sont acceptés."
        )

    # 4. Extraction du premier token pour validation TXXX
    parts = normalized.split(maxsplit=1)
    task_token = parts[0]
    description = parts[1] if len(parts) > 1 else ""

    if not RE_TASK_ID.match(task_token):
        raise ValueError(
            f"Le repère de tâche '{task_token}' est invalide. "
            "Il doit respecter strictement la syntaxe canonique (ex: T123, T123-AGY01, T000-AGY00)."
        )

    actor_match = re.fullmatch(r"(AG|CD|DS|OP)(\d{2})", task_token.rsplit("-", 1)[-1])
    if actor_match:
        canonical_prefix = {"AG": "AGY", "CD": "CDX", "DS": "DSH", "OP": "OPC"}[actor_match.group(1)]
        corrected_task_token = f"{task_token.rsplit('-', 1)[0]}-{canonical_prefix}{actor_match.group(2)}"
        raise ValueError(
            f"Le repere acteur '{task_token}' n'est pas canonique. "
            f"Utilisez '{corrected_task_token}' pour eviter toute modification implicite."
        )

    return task_token, normalized, description

def resolve_session_task_folder(session_ref: str) -> str | None:
    """Renvoie le dossier dont le README lie explicitement la session, sans deviner par préfixe."""
    tasks_dir = REPO_ROOT / "DOC" / "WFLOW" / "TASKS"
    if not tasks_dir.is_dir():
        return None

    session_pattern = re.compile(
        rf"\bsession\s+[`'\"]?{re.escape(session_ref)}\b",
        re.IGNORECASE,
    )
    matches = []
    for task_dir in tasks_dir.iterdir():
        readme = task_dir / "README.md"
        if not task_dir.is_dir() or not readme.is_file():
            continue
        try:
            if session_pattern.search(readme.read_text(encoding="utf-8")):
                matches.append(task_dir.name)
        except OSError:
            continue

    # Une liaison absente ou dupliquée ne sélectionne jamais un dossier arbitraire.
    return matches[0] if len(matches) == 1 else None

def resolve_task_title(alias: str) -> str:
    """Titre officiel de la tâche déduite de l'alias (T429-MMX01 -> titre de T429).

    Lecture ciblée du catalogue : aucun dossier arbitraire, aucun fichier entier lu.
    Renvoyé vide si la tâche est inconnue, hors catalogue (T000) ou le catalogue illisible.
    """
    match = re.match(r"^(T\d{3})", (alias or "").strip(), re.IGNORECASE)
    if not match:
        return ""
    task_id = match.group(1).upper()
    if task_id == "T000":
        return ""
    catalog = REPO_ROOT / "DOC" / "WFLOW" / "TASKS.yaml"
    try:
        import yaml
        data = yaml.safe_load(catalog.read_text(encoding="utf-8")) or []
    except (OSError, ValueError, ImportError):
        return ""
    if isinstance(data, dict):
        data = data.get("tasks", [])
    for item in data if isinstance(data, list) else []:
        if isinstance(item, dict) and str(item.get("id", "")).upper() == task_id:
            return " ".join(str(item.get("titre") or "").split())
    return ""


def notify_supervisor(session_id: str, alias: str, mission_text: str = "", platform: str = "claude", base_url: str = "http://127.0.0.1:8082", timeout: float = 1.0) -> bool:
    """Notifie l'API locale du Superviseur de la mise à jour de l'alias via POST /api/supervision.
    Une session absente n'est jamais créée ici : seul connect_session.py peut l'attacher."""
    try:
        # 1. Précondition explicite : utiliser une liaison exacte déjà existante.
        supervisor_id = resolve_supervisor_session_id(session_id, platform, base_url, timeout)
        if not supervisor_id:
            return False

        # 2. Récupération du token de supervision.
        req_get = urllib.request.Request(f"{base_url}/api/supervision", headers={"Accept": "application/json"}, method="GET")
        with urllib.request.urlopen(req_get, timeout=timeout) as resp:
            if resp.status != 200:
                return False
            data = json.loads(resp.read().decode("utf-8"))
            token = data.get("token", "")

        # Le même nom lisible est conservé dans le chat et la mission Superviseur.
        # T429 (2026-11-13) : le TITRE de la tâche (officiel, catalogue) doit figurer dans
        # le titre de session Superviseur — la désignation libre de l'exploitant passe en
        # corps de mission (elle décrit la session, pas la tâche).
        task_title = resolve_task_title(alias)
        designation = mission_text.strip()
        folder_name = resolve_session_task_folder(alias)
        if task_title:
            # Une seule ligne : le titre de session reste lisible partout (terminal,
            # notifications) et la désignation de l'exploitant n'est pas perdue.
            mission = f"{alias} · {task_title}"
            if designation:
                mission += f" ({designation})"
            if folder_name:
                mission += f" — Dossier: {folder_name}"
        else:
            # T000 / tache inconnue : format historique inchange.
            mission = f"{alias} {designation}".strip()
            if folder_name:
                mission += f" — Dossier: {folder_name}"
            elif not designation:
                mission = alias

        # 3. Mise à jour de l'affectation déjà liée.
        payload = json.dumps({"action": "set_alias", "id": supervisor_id, "alias": alias}).encode("utf-8")
        req_post = urllib.request.Request(
            f"{base_url}/api/supervision",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-Supervision-Token": token,
                "Accept": "application/json"
            },
            method="POST"
        )
        try:
            with urllib.request.urlopen(req_post, timeout=timeout) as resp:
                if resp.status in (200, 204):
                    # Mettre à jour la mission si le titre, le dossier ou T000 le demande.
                    if mission_text.strip() or folder_name or alias.startswith("T000"):
                        m_payload = json.dumps({"action": "set_mission", "id": supervisor_id, "mission": mission}).encode("utf-8")
                        req_m = urllib.request.Request(f"{base_url}/api/supervision", data=m_payload, headers={"Content-Type": "application/json", "X-Supervision-Token": token, "Accept": "application/json"}, method="POST")
                        try:
                            with urllib.request.urlopen(req_m, timeout=timeout) as mission_resp:
                                if mission_resp.status not in (200, 204):
                                    return False
                        except Exception:
                            return False
                    return True
        except urllib.error.HTTPError:
            return False
    except SupervisorSessionNotLinked:
        raise
    except Exception:
        return False

def update_vscode_tab_title(title_text: str):
    """Pousse la séquence d'échappement console OSC 0 sur CONOUT$ et Win32."""
    if os.name == "nt":
        try:
            import ctypes
            ctypes.windll.kernel32.SetConsoleTitleW(str(title_text))
        except Exception:
            pass
    osc_seq = f"\x1b]0;{title_text}\x07\x1b]2;{title_text}\x07"
    try:
        if os.name == "nt":
            with open("CONOUT$", "w", encoding="utf-8", errors="replace") as tty:
                tty.write(osc_seq)
                tty.flush()
        else:
            with open("/dev/tty", "w", encoding="utf-8", errors="replace") as tty:
                tty.write(osc_seq)
                tty.flush()
    except Exception:
        pass


def update_claude_transcript_title(session_id: str, new_title: str):
    """Met à jour le titre 'ai-title' dans le transcript Claude Code pour que /status affiche le bon nom."""
    try:
        projects_dir = Path.home() / ".claude" / "projects"
        if not projects_dir.exists():
            return
        matches = list(projects_dir.glob(f"**/{session_id}.jsonl"))
        for transcript_path in matches:
            line_payload = json.dumps({"type": "ai-title", "aiTitle": new_title, "sessionId": session_id}, ensure_ascii=False) + "\n"
            with open(transcript_path, "a", encoding="utf-8") as f:
                f.write(line_payload)
                f.flush()
    except Exception:
        pass


def update_codex_thread_title(thread_id: str, new_title: str, timeout: float = 4.0) -> bool:
    """Renomme le titre de chat Codex par son API app-server locale, puis vérifie l'index."""
    try:
        process = subprocess.Popen(
            ["codex", "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            bufsize=1,
        )
        output_lines: queue.Queue[str | None] = queue.Queue()

        def read_stdout():
            try:
                for line in process.stdout:
                    output_lines.put(line)
            finally:
                output_lines.put(None)

        threading.Thread(target=read_stdout, daemon=True).start()

        def send(payload: dict):
            process.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
            process.stdin.flush()

        def read_response(expected_id: int) -> dict:
            deadline = time.monotonic() + timeout
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("Codex app-server n'a pas répondu à temps")
                line = output_lines.get(timeout=remaining)
                if line is None:
                    raise RuntimeError("Codex app-server a fermé le flux avant la réponse")
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if message.get("id") == expected_id:
                    if message.get("error"):
                        raise RuntimeError(str(message["error"]))
                    return message

        send({
            "id": 1,
            "method": "initialize",
            "params": {"clientInfo": {"name": "rename-session", "title": "Rename Session", "version": "1.0.0"}},
        })
        read_response(1)
        send({"method": "initialized", "params": {}})
        send({"id": 2, "method": "thread/name/set", "params": {"threadId": thread_id, "name": new_title}})
        read_response(2)
        process.stdin.close()
        process.wait(timeout=timeout)

        index_path = Path.home() / ".codex" / "session_index.jsonl"
        if not index_path.is_file():
            return False
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                rows = [json.loads(line) for line in index_path.read_text(encoding="utf-8").splitlines() if line.strip()]
                match = next((row for row in reversed(rows) if row.get("id") == thread_id), None)
                if match and match.get("thread_name") == new_title:
                    return True
            except Exception:
                pass
            time.sleep(0.05)
        return False
    except Exception:
        try:
            process.terminate()
            process.wait(timeout=1)
        except Exception:
            pass
        return False

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("❌ Erreur : Paramètre manquant.\n")
        sys.stderr.write("Usage : rename_session.py <TXXX[-ACTEUR]> <Description>\n")
        sys.stderr.write("Exemple : rename_session.py T123-AGY01 Mon Titre De Session\n")
        sys.exit(2)

    preflight_only = "--preflight" in sys.argv[1:]
    control_flags = {"--preflight"}
    raw_args = " ".join(arg for arg in sys.argv[1:] if arg not in control_flags)

    # 1. Validation & Assainissement
    try:
        task_id, target_alias, description = sanitize_and_validate(raw_args)
    except ValueError as e:
        sys.stderr.write(f"❌ Erreur de validation : {e}\n")
        sys.exit(2)

    # 2. Détection de la session courante via session_statusline
    sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))
    parent_pid = None
    parent_name = ""
    try:
        import session_statusline
        parent_pid, parent_name = session_statusline.get_ancestor_cli_process()
        conv_id = session_statusline.find_current_conversation_id(parent_name, parent_pid)
        if not conv_id:
            raise ValueError("ID natif non résolu")
        current_alias, _ = session_statusline.get_session_info(conv_id, parent_name)
    except Exception as e:
        sys.stderr.write(f"❌ Session courante non identifiée : {e}\n")
        sys.exit(3)

    if not conv_id:
        sys.stderr.write("❌ Session courante non identifiée ; aucun renommage appliqué. Vérifie l'ID natif du CLI.\n")
        sys.exit(3)

    parent_lower = (parent_name or "").lower()
    if not any(cli in parent_lower for cli in ("claude", "agy", "dsh", "codex")):
        sys.stderr.write(f"❌ CLI courant non reconnu ({parent_name or 'inconnu'}) ; aucun renommage appliqué.\n")
        sys.exit(3)

    # 3. Alias machine canonique, identique dans le Superviseur et le préfixe du chat.
    actor = "AGY01" if "agy" in parent_lower else ("CC01" if "claude" in parent_lower else ("DSH01" if "dsh" in parent_lower else "CDX01"))
    if re.fullmatch(r"^T\d+(-[0-9A-Z]+)?-(CC|AGY|CDX|DSH|OPC|GLM|MMX|QWN)\d{2}$", task_id):
        machine_alias = task_id
    else:
        machine_alias = f"{task_id}-{actor}"
    # T429 (2026-11-13) : le titre canonique porte le titre officiel de la tache ;
    # la designation libre de l'exploitant reste visible entre parentheses.
    task_title = resolve_task_title(task_id)
    if task_title:
        canonical_title = f"{machine_alias} · {task_title}"
        if description:
            canonical_title += f" ({description})"
    else:
        canonical_title = f"{machine_alias} {description}".strip()
    platform_code = "claude" if "claude" in parent_lower else ("agy" if "agy" in parent_lower else ("dsh" if "dsh" in parent_lower else "codex"))

    if preflight_only:
        try:
            assignment_id = resolve_supervisor_session_id(conv_id, platform_code, timeout=1.0)
        except SupervisorSessionNotLinked as e:
            sys.stderr.write(f"❌ Prévol refusé : {e}. Aucun titre ni alias modifié.\n")
            sys.exit(4)
        if not assignment_id:
            sys.stderr.write("❌ Prévol impossible : Superviseur indisponible ; aucun titre ni alias modifié.\n")
            sys.exit(1)
        print(f"✅ Prévol PASS : {platform_code}:{conv_id} reliée ; cible '{canonical_title}'. Aucun changement appliqué.")
        sys.exit(0)

    # 4. Idempotence sur le titre canonique réellement synchronisé.
    # Toujours rejouer les cibles : le terminal peut avoir été réinitialisé même
    # si l'alias et le titre du chat sont déjà conformes.

    # 5. Étape WAL : journaliser l'alias machine prévu avant les effets de bord.
    log_audit("INTENT", conv_id, current_alias or "NONE", machine_alias, status_code=0)

    # 6. Vérifier et mettre à jour la liaison Superviseur avant les autres cibles.
    try:
        sup_ok = notify_supervisor(conv_id, machine_alias, mission_text=description, platform=platform_code, timeout=1.0)
    except SupervisorSessionNotLinked as e:
        log_audit("REJECTED", conv_id, current_alias or "NONE", machine_alias, status_code=4)
        sys.stderr.write(f"❌ {e}. Aucun renommage appliqué ; relance après la liaison explicite.\n")
        sys.exit(4)
    if not sup_ok:
        mark_dirty_supervisor(conv_id, machine_alias, canonical_title)
        log_audit("FAILED", conv_id, current_alias or "NONE", machine_alias, status_code=1)
        sys.stderr.write("❌ Superviseur indisponible ou mise à jour refusée ; aucune autre cible modifiée. Réessaie après diagnostic.\n")
        sys.exit(1)

    codex_title_ok = None
    if "codex" in parent_lower:
        codex_title_ok = update_codex_thread_title(conv_id, canonical_title)
        if not codex_title_ok:
            log_audit("PARTIAL", conv_id, current_alias or "NONE", machine_alias, status_code=1)
            sys.stderr.write("❌ Alias Superviseur mis à jour, mais le titre du chat Codex n'a pas été confirmé dans session_index.jsonl.\n")
            sys.exit(1)

    boot_name = "🚀 AGY"
    if "claude" in parent_lower:
        boot_name = "🧠 CC"
    elif "codex" in parent_lower:
        boot_name = "🤖 CDX"
    elif "dsh" in parent_lower:
        boot_name = "DSH"

    tab_title = f"{canonical_title} {boot_name}"
    update_vscode_tab_title(tab_title)

    # 5bis. Injection dans les stockages natifs selon le CLI
    if "claude" in parent_lower and conv_id:
        update_claude_transcript_title(conv_id, canonical_title)
    elif "agy" in parent_lower and conv_id:
        try:
            import sqlite3
            db_path = APP_DATA / "conversation_summaries.db"
            if db_path.exists():
                with sqlite3.connect(str(db_path), timeout=1.0) as conn:
                    conn.execute("UPDATE conversation_summaries SET title = ? WHERE conversation_id = ?", (canonical_title, conv_id))
                    conn.commit()
        except Exception:
            pass

    # 7. Validation finale après succès de la cible Superviseur et émission des cibles locales.
    log_audit("COMMIT", conv_id, current_alias or "NONE", machine_alias, status_code=0)
    print(f"✅ Alias Superviseur mis à jour : {machine_alias}")
    print(f"   Titre lisible : {canonical_title}")
    print(f"   Titre terminal demandé : {tab_title} (confirmation visuelle requise)")
    if codex_title_ok:
        print("   Titre du chat Codex : confirmé par app-server et session_index.jsonl")
    sys.exit(0)

if __name__ == "__main__":
    main()
