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

def mark_dirty_supervisor(session_id: str, alias: str):
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
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        with open(DIRTY_MARKER_FILE, "w", encoding="utf-8") as f:
            json.dump(records, f, indent=2)
    except Exception:
        pass

def sanitize_and_validate(raw_input: str) -> tuple[str, str]:
    """Valide et normalise l'entrée selon les critères stricts arrêtés.
    Retourne (task_id, description_complete) ou lève ValueError."""
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

    return task_token, normalized

def notify_supervisor(session_id: str, alias: str, timeout: float = 0.5) -> bool:
    """Notifie l'API locale du Superviseur de la mise à jour de l'alias."""
    try:
        req = urllib.request.Request(
            f"http://127.0.0.1:8082/api/supervision/session/{session_id}/alias",
            data=json.dumps({"alias": alias}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status in (200, 204)
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

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("❌ Erreur : Paramètre manquant.\n")
        sys.stderr.write("Usage : rename_session.py <TXXX[-ACTEUR]> <Description>\n")
        sys.stderr.write("Exemple : rename_session.py T123-AGY01 Mon Titre De Session\n")
        sys.exit(2)

    raw_args = " ".join(sys.argv[1:])

    # 1. Validation & Assainissement
    try:
        task_id, target_alias = sanitize_and_validate(raw_args)
    except ValueError as e:
        sys.stderr.write(f"❌ Erreur de validation : {e}\n")
        sys.exit(2)

    # 2. Détection de la session courante via session_statusline
    sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))
    try:
        import session_statusline
        parent_pid, parent_name = session_statusline.get_ancestor_cli_process()
        conv_id = session_statusline.find_current_conversation_id(parent_name, parent_pid)
        current_alias, _ = session_statusline.get_session_info(conv_id, parent_name)
    except Exception as e:
        conv_id = os.environ.get("ANTIGRAVITY_CONVERSATION_ID") or "default-session"
        current_alias = ""

    if not conv_id:
        conv_id = f"pid-{parent_pid or os.getpid()}"

    # 3. Idempotence : si le nom est déjà identique (forme NFC), no-op sans log redondant
    if current_alias and unicodedata.normalize("NFC", current_alias) == target_alias:
        print(f"ℹ️ Aucun changement : La session porte déjà l'alias '{target_alias}'.")
        sys.exit(0)

    # 4. Étape WAL : Journalisation d'intention (INTENT)
    log_audit("INTENT", conv_id, current_alias or "NONE", target_alias, status_code=0)

    # 5. Application locale du renommage
    # Titre d'onglet court sans info Superviseur
    boot_name = "🚀 AGY Antigravity"
    if "claude" in (parent_name or "").lower():
        boot_name = "🧠 Claude Code"
    elif "codex" in (parent_name or "").lower():
        boot_name = "🤖 Codex (OpenAI)"
    elif "dsh" in (parent_name or "").lower():
        boot_name = "DSH"

    tab_title = f"{task_id} {boot_name}"
    update_vscode_tab_title(tab_title)

    # 6. Notification Superviseur
    sup_ok = notify_supervisor(conv_id, target_alias, timeout=0.5)
    if not sup_ok:
        mark_dirty_supervisor(conv_id, target_alias)
        sys.stderr.write("⚠️ Note : Superviseur non joignable (alias marqué pour réconciliation ultérieure).\n")

    # 7. Étape WAL : Validation finale (COMMIT)
    log_audit("COMMIT", conv_id, current_alias or "NONE", target_alias, status_code=0)

    print(f"✅ Session renommée avec succès : {target_alias}")
    print(f"   Onglet terminal : {tab_title}")
    sys.exit(0)

if __name__ == "__main__":
    main()
