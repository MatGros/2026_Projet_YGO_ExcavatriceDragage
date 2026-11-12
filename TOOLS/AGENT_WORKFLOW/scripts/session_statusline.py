"""
Script de statusline dynamique pour Antigravity CLI (agy).
Affiche en direct dans la barre de statut de la CLI :
- L'identifiant et l'acteur de la tâche active (ex: [T429-AGY01])
- L'intitulé court de la tâche ou de la session
- Met également à jour le titre de l'onglet du terminal (OSC escape sequence)
Robuste aux encodages Windows (cp1252/utf-8) et garanti sans plantage (exit 0).
"""
import sys
import os
import json
import re
import sqlite3
import urllib.request
from pathlib import Path

# Forcer UTF-8 avec fallback sur remplacement si le terminal est en cp1252
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
APP_DATA = Path(r"C:\Users\ZEDVICTUS\.gemini\antigravity-cli")

def get_session_info():
    task_id = "T429"
    task_title = "Fiabilisation Supervisor"
    actor = "AGY01"
    
    # 1. Vérifier TASK_LOCKS.json dans le projet
    locks_file = REPO_ROOT / "DOC" / "WFLOW" / "TASK_LOCKS.json"
    if locks_file.exists():
        try:
            with open(locks_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                locks = data.get("work_locks", {})
                for tid, lk in locks.items():
                    act = lk.get("actor", "")
                    if act in ("AGY01", "AGY02"):
                        task_id = tid
                        actor = act
                        break
        except Exception:
            pass

    # 2. Interroger le Superviseur local si actif (timeout ultra court 0.15s)
    try:
        req = urllib.request.Request("http://127.0.0.1:8082/api/supervision/summary")
        with urllib.request.urlopen(req, timeout=0.15) as resp:
            sdata = json.load(resp)
            for s in sdata.get("sessions", []):
                if s.get("platform") == "agy" and s.get("state") == "active":
                    alias = s.get("alias", "")
                    if alias:
                        # Extraire le sujet si l'alias est sous forme "T429-AGY01 Sujet"
                        m = re.match(r"^T\d+(-[0-9A-Z]+)?-[A-Z0-9]+\s+(.*)$", alias)
                        if m:
                            task_title = m.group(2).strip()
                        else:
                            task_title = alias.strip()
                        break
    except Exception:
        pass

    # 3. Chercher le titre de la conversation courante dans conversation_summaries.db
    db_file = APP_DATA / "conversation_summaries.db"
    conv_title = ""
    if db_file.exists():
        try:
            conn = sqlite3.connect(str(db_file), timeout=0.15)
            cur = conn.cursor()
            cur.execute("SELECT title FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1")
            row = cur.fetchone()
            if row and row[0]:
                conv_title = row[0].strip()
            conn.close()
        except Exception:
            pass

    return task_id, actor, task_title, conv_title

def main():
    try:
        task_id, actor, task_title, conv_title = get_session_info()
        
        # Formater le titre de terminal (OSC 0)
        tab_title = f"[{task_id}-{actor}] {task_title}"
        try:
            sys.stdout.write(f"\x1b]0;{tab_title}\x07")
        except Exception:
            pass
        
        # Formater la ligne de statut dans Antigravity CLI avec ANSI colors
        cyan = "\033[1;36m"
        yellow = "\033[1;33m"
        dim = "\033[90m"
        bold = "\033[1m"
        reset = "\033[0m"
        
        label = f"{cyan}{bold}[{task_id}-{actor}]{reset} {yellow}{task_title}{reset}"
        if conv_title and conv_title != task_title and conv_title.lower() != f"prend {task_id.lower()}":
            label += f" {dim}({conv_title}){reset}"
        
        print(label)
    except Exception:
        # Filet de sécurité absolu : ne JAMAIS crasher en code 1
        print("[T429-AGY01] Fiabilisation Supervisor")

if __name__ == "__main__":
    main()
