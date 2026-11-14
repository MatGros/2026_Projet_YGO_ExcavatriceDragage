"""
Script de statusline et titre de terminal dynamique pour Antigravity CLI (agy), Claude Code et Codex.
Le titre terminal reprend le titre lisible validé par /rename-session, puis l'identifiant du CLI.
La ligne de statut affiche l'état de liaison au Superviseur.
Deuxième ligne (2026-11-13) : état du workflow projet (ACTIF/OFF + voie) et repère git
(branche, worktree, écart avec l'upstream, fichiers modifiés).
Garanti sans plantage (exit 0) et robuste aux encodages Windows.
"""
import sys
import os
import json
import re
import sqlite3
import urllib.request
import ctypes
from ctypes import wintypes
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import terminal_title  # noqa: E402  (chemin local du script)
from statusline_indicators import (  # noqa: E402  (chemin local du script)
    STATUSLINE_INDENT, get_git_badge, get_progress_badge, get_scope_badge,
    get_socle_badge, get_workflow_badge,
)

# Forcer UTF-8 avec fallback sur remplacement si le terminal est en cp1252
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
APP_DATA = Path(r"C:\Users\ZEDVICTUS\.gemini\antigravity-cli")


DEBUG_LOG = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local")) / "Temp" / "session_statusline_debug.log"

def log_debug(msg: str):
    try:
        with open(DEBUG_LOG, "a", encoding="utf-8") as f:
            f.write(f"[{os.getpid()}] {msg}\n")
    except Exception:
        pass

def set_terminal_title(title_text: str):
    """Met à jour le titre du terminal :
    1. Via l'API Win32 SetConsoleTitleW (prioritaire pour la console Windows).
    2. Via les séquences ANSI OSC 0 et OSC 2 directement sur CONOUT$/tty.
    3. Via stdout en fallback."""
    # 1. Win32 API SetConsoleTitleW
    win32_res = None
    if os.name == "nt":
        try:
            win32_res = ctypes.windll.kernel32.SetConsoleTitleW(str(title_text))
        except Exception as e:
            win32_res = f"err:{e}"

    # 2. Séquences ANSI OSC 0 et OSC 2 directement sur le descripteur console
    conout_ok = False
    osc_seq = f"\x1b]0;{title_text}\x07\x1b]2;{title_text}\x07"
    try:
        if os.name == "nt":
            with open("CONOUT$", "w", encoding="utf-8", errors="replace") as tty:
                tty.write(osc_seq)
                tty.flush()
                conout_ok = True
        else:
            with open("/dev/tty", "w", encoding="utf-8", errors="replace") as tty:
                tty.write(osc_seq)
                tty.flush()
                conout_ok = True
    except Exception as e:
        conout_ok = f"err:{e}"

    log_debug(f"set_terminal_title target='{title_text}' SetConsoleTitleW={win32_res} CONOUT$={conout_ok}")

def get_ancestor_cli_process():
    """Remonte l'arbre des processus pour trouver le PID de l'exécutable CLI parent (agy, claude, codex).
    Indispensable sous Windows car Python est lancé via un sous-shell intermédiaire (cmd.exe)."""
    try:
        TH32CS_SNAPPROCESS = 0x00000002
        class PROCESSENTRY32(ctypes.Structure):
            _fields_ = [
                ('dwSize', wintypes.DWORD),
                ('cntUsage', wintypes.DWORD),
                ('th32ProcessID', wintypes.DWORD),
                ('th32DefaultHeapID', ctypes.POINTER(ctypes.c_ulong)),
                ('th32ModuleID', wintypes.DWORD),
                ('cntThreads', wintypes.DWORD),
                ('th32ParentProcessID', wintypes.DWORD),
                ('pcPriClassBase', wintypes.LONG),
                ('dwFlags', wintypes.DWORD),
                ('szExeFile', ctypes.c_char * 260)
            ]

        kernel32 = ctypes.windll.kernel32
        hSnapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        parents = {}
        names = {}
        entry = PROCESSENTRY32()
        entry.dwSize = ctypes.sizeof(PROCESSENTRY32)
        success = kernel32.Process32First(hSnapshot, ctypes.byref(entry))
        while success:
            parents[entry.th32ProcessID] = entry.th32ParentProcessID
            names[entry.th32ProcessID] = entry.szExeFile.decode('utf-8', errors='ignore')
            success = kernel32.Process32Next(hSnapshot, ctypes.byref(entry))
        kernel32.CloseHandle(hSnapshot)

        curr = os.getpid()
        while curr in parents and parents[curr] != 0:
            p = parents[curr]
            name = names.get(p, '').lower()
            if any(cli in name for cli in ('agy', 'claude', 'codex', 'dsh')):
                return p, name
            curr = p
    except Exception:
        pass
    return os.getppid(), "unknown"

def get_boot_terminal_name(cli_name: str = "agy"):
    """Détermine le nom de base configuré dans Terminal Keeper selon le CLI parent."""
    cli = (cli_name or "").lower()
    if "claude" in cli:
        return "🧠 CC"
    elif "codex" in cli:
        return "🤖 CDX"
    elif "dsh" in cli:
        return "DSH"
    return "🚀 AGY"

def find_current_conversation_id(cli_name: str = "agy", parent_pid: int = None, stdin_session_id: str = None):
    """Détecte l'identifiant exact de conversation pour CE terminal spécifique."""
    cli = (cli_name or "").lower()

    # 0. Si passé directement par stdin (ex: Claude Code)
    if stdin_session_id:
        return stdin_session_id.strip()

    # 1. Détection Claude Code via ~/.claude/sessions/<pid>.json
    if "claude" in cli and parent_pid:
        claude_sess_dir = Path.home() / ".claude" / "sessions"
        sess_file = claude_sess_dir / f"{parent_pid}.json"
        if sess_file.exists():
            try:
                with open(sess_file, "r", encoding="utf-8") as f:
                    sdata = json.load(f)
                    sid = sdata.get("sessionId")
                    if sid:
                        return sid
            except Exception:
                pass

    # 2. Détection Antigravity par log de PID (prioritaire sur les variables d'environnement héritées)
    if "agy" in cli and parent_pid:
        try:
            log_dir = APP_DATA / "log"
            if log_dir.exists():
                log_files = sorted(log_dir.glob("cli-*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
                for log_file in log_files:
                    try:
                        with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
                            head = f.read(500)
                            if f"pid {parent_pid}" in head:
                                f.seek(0)
                                content = f.read()
                                matches = re.findall(r"conversation update stream for ([a-f0-9\-]+)", content)
                                if matches:
                                    return matches[-1]
                                matches2 = re.findall(r"Streaming conversation ([a-f0-9\-]+)", content)
                                if matches2:
                                    return matches2[-1]
                    except Exception:
                        pass
        except Exception:
            pass

    # 3. Fallback sur variables d'environnement (si non résolu par PID)
    if "claude" in cli:
        cid = os.environ.get("CLAUDE_CODE_SESSION_ID", "").strip()
        if cid:
            return cid
    elif "dsh" in cli:
        cid = os.environ.get("DSH_SESSION_ID", "").strip()
        if cid:
            return cid
    elif "codex" in cli:
        codex_ids = {
            os.environ.get("CODEX_THREAD_ID", "").strip(),
            os.environ.get("CODEX_SESSION_ID", "").strip(),
        } - {""}
        # Ne jamais réutiliser l'ID Antigravity hérité dans le processus Codex.
        # En cas de conflit ou de format inattendu, échouer fermé.
        if len(codex_ids) == 1:
            codex_id = codex_ids.pop()
            if re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", codex_id):
                return codex_id
        return None
    else:
        cid = os.environ.get("ANTIGRAVITY_CONVERSATION_ID", "").strip()
        if cid:
            return cid

    return None

def get_session_info(conv_id, cli_name: str = "agy"):
    raw_title = ""
    actor = "AGY01" if "agy" in (cli_name or "") else ("CC01" if "claude" in (cli_name or "") else "CDX01")

    # 1. Si session rattachée au Superviseur : l'alias vérifié est prioritaire
    if conv_id:
        try:
            req = urllib.request.Request("http://127.0.0.1:8082/api/supervision/summary")
            with urllib.request.urlopen(req, timeout=0.15) as resp:
                data = json.load(resp)
                for s in data.get("sessions", []):
                    if s.get("native_id") == conv_id:
                        alias = s.get("alias", "")
                        if alias:
                            alias = alias.strip()
                            raw_title = s.get("display_title", "").strip() or alias
                            break
        except Exception:
            pass

    # 2. Si Claude Code : lire le dernier ai-title dans le transcript
    if not raw_title and "claude" in (cli_name or "").lower() and conv_id:
        try:
            projects_dir = Path.home() / ".claude" / "projects"
            if projects_dir.exists():
                for tp in projects_dir.glob(f"**/{conv_id}.jsonl"):
                    with open(tp, "r", encoding="utf-8") as f:
                        for line in f:
                            try:
                                d = json.loads(line)
                                if d.get("type") == "ai-title" and d.get("aiTitle"):
                                    raw_title = d.get("aiTitle").strip()
                            except Exception:
                                pass
                    if raw_title:
                        break
        except Exception:
            pass

    # 3. Si Antigravity : vérifier si /rename dans SQLite est plus récent
    if not raw_title and "agy" in (cli_name or "").lower():
        db_file = APP_DATA / "conversation_summaries.db"
        if db_file.exists():
            try:
                conn = sqlite3.connect(str(db_file), timeout=0.15)
                cur = conn.cursor()
                if conv_id:
                    cur.execute("SELECT title FROM conversation_summaries WHERE conversation_id = ?", (conv_id,))
                    row = cur.fetchone()
                    if row and row[0]:
                        raw_title = row[0].strip()
                conn.close()
            except Exception:
                pass

    return raw_title, actor

def get_supervisor_status(conv_id):
    """Vérifie si la conversation est rattachée et active dans le Superviseur,
    et renvoie le badge riche avec l'état et les compteurs réels (alarmes, warnings)."""
    dim = "\033[90m"
    bold = "\033[1m"
    green = "\033[1;32m"
    yellow = "\033[1;33m"
    red = "\033[1;31m"
    reset = "\033[0m"

    if not conv_id:
        return f"{dim}🛡️ Supervisor : Not Linked{reset}"
    try:
        req = urllib.request.Request("http://127.0.0.1:8082/api/supervision/summary")
        with urllib.request.urlopen(req, timeout=0.15) as resp:
            data = json.load(resp)
            for s in data.get("sessions", []):
                if s.get("native_id") == conv_id:
                    state = s.get("state", "active")
                    counts = s.get("counts", {})
                    alarms = counts.get("alarms", 0)
                    warnings = counts.get("warnings", 0)

                    # 'Linked (Active)' affiché en vert sobre
                    # T429 M1 : un observateur en erreur doit crier, pas passer en jaune discret.
                    if state == "active":
                        state_str = f"🛡️ Supervisor : {green}Linked (Active){reset}"
                    elif state in ("source_error", "source_missing", "ambiguous", "state_error"):
                        state_str = f"🛡️ Supervisor : {red}EN ERREUR ({state}) — il n'observe plus{reset}"
                    else:
                        state_str = f"🛡️ Supervisor : {yellow}Linked ({state}){reset}"

                    badges = []
                    if alarms > 0:
                        badges.append(f"{red}{bold}🚨 {alarms} alarme{'' if alarms == 1 else 's'}{reset}")
                    if warnings > 0:
                        badges.append(f"{yellow}{bold}⚠️ {warnings} warning{'' if warnings == 1 else 's'}{reset}")
                    if not alarms and not warnings:
                        # 0 alerte en gris/dim neutre pour ne pas flasher inutilement en vert
                        badges.append(f"{dim}0 alerte{reset}")

                    return f"{state_str} [{' '.join(badges)}]"
            return f"{dim}🛡️ Supervisor : Not Linked{reset}"
    except Exception:
        return f"{dim}🛡️ Supervisor : Offline{reset}"

def main():
    try:
        # Lire stdin s'il est alimenté (ex: Claude Code envoie du JSON contenant session_id)
        stdin_session_id = None
        stdin_transcript = None
        if not sys.stdin.isatty():
            try:
                stdin_data = sys.stdin.read()
                if stdin_data:
                    parsed = json.loads(stdin_data)
                    stdin_session_id = parsed.get("session_id") or parsed.get("sessionId")
                    stdin_transcript = parsed.get("transcript_path")
            except Exception:
                pass

        # Déterminer le mode d'appel (--mode title ou --mode statusline)
        mode = "statusline"
        if "--mode" in sys.argv:
            try:
                idx = sys.argv.index("--mode")
                mode = sys.argv[idx + 1].lower()
            except Exception:
                pass

        parent_pid, parent_name = get_ancestor_cli_process()
        conv_id = find_current_conversation_id(parent_name, parent_pid, stdin_session_id)
        raw_title, actor = get_session_info(conv_id, parent_name)
        boot_name = get_boot_terminal_name(parent_name)

        # Extraire le repère canonique de tâche (TXXX ou TXXX-ACTEUR ex: T423 ou T423-AGY01 ou T000-AGY00)
        task_id = None
        if raw_title:
            m = re.match(r"^(T\d+(?:-[0-9A-Z]+)*)", raw_title, re.IGNORECASE)
            if not m:
                m = re.search(r"\b(T\d+(?:-[0-9A-Z]+)*)\b", raw_title, re.IGNORECASE)
            if m:
                task_id = m.group(1).upper()

        tab_title = f"{raw_title.strip()} {boot_name}" if raw_title else boot_name
        # T429 : ecriture VERIFIEE (ecrire -> relire -> reessayer -> consigner).
        # Le statusline revient apres les commandes outil : reappliquer le titre ici
        # resiste au titre du shell enfant, et la verification prouve le resultat.
        try:
            terminal_title.refresh(conv_id, tab_title)
        except Exception:
            set_terminal_title(tab_title)

        # Sortie pour la commande :
        if mode == "title":
            # Mode 'title' : uniquement le repère et le nom de boot épuré
            print(tab_title)
        else:
            # Mode 'statusLine' CLI : stylé avec couleurs ANSI selon les conventions du projet
            # TXXX-ACTEUR : Bleu vif / Cyan
            # Désignation : Violet pastel clair / lavande (haute lisibilité sur fond sombre)
            # Couleurs d'identification stricte par famille d'agent :
            # CC : Rouge / Corail
            # AGY : Bleu azur (Gemini / Antigravity)
            # CDX : Vert émeraude (Codex)
            # DSH : Cyan / Bleu turquoise (DeepSeek baleine)
            # GLM : Magenta / Violet (GLM-4 / GLM-5)
            # MMX : Jaune ambre (MiniMax)
            # OPC : Vert menthe (OpenCode)
            # HUM : Magenta vif (Humain)
            AGENT_COLORS = {
                "CC": "\033[1;31m",
                "AGY": "\033[1;34m",
                "CDX": "\033[1;32m",
                "DSH": "\033[1;36m",
                "GLM": "\033[1;35m",
                "MMX": "\033[1;33m",
                "OPC": "\033[38;2;45;212;191m",
                "HUM": "\033[1;35m"
            }

            def colorize_task_id(full_tid: str) -> str:
                # full_tid ex: T000-CC01 ou T429-AGY02 ou T423
                # Colore la partie tâche (TXXX) en blanc/gris et l'acteur dans sa couleur dédiée
                m_agent = re.search(r"-(CC|AGY|CDX|DSH|GLM|MMX|OPC|HUM)(\d{2})?$", full_tid)
                if m_agent:
                    prefix = full_tid[:m_agent.start()]
                    actor_key = m_agent.group(1)
                    actor_suffix = m_agent.group(0)[1:] # CC01, AGY, etc.
                    actor_color = AGENT_COLORS.get(actor_key, blue_bold)
                    return f"\033[1;37m{prefix}\033[0m-\033[1m{actor_color}{actor_suffix}\033[0m"
                return f"{blue_bold}{full_tid}{reset}"

            blue_bold = "\033[1;36m"
            pastel_purple = "\033[38;2;216;180;254m\033[1m"
            dim = "\033[90m"
            reset = "\033[0m"

            status_text = raw_title if raw_title else tab_title
            # Découper le repère de tâche (TXXX ou TXXX-AGY01) et le reste
            m_parts = re.match(r"^(T\d+(?:-[0-9A-Z]+)*)(.*)$", status_text, re.IGNORECASE)
            if m_parts:
                tid = m_parts.group(1).upper()
                colored_tid = colorize_task_id(tid)
                raw_rest = m_parts.group(2)
                if raw_rest.startswith("_"):
                    colored_label = f"{colored_tid}{pastel_purple}{raw_rest.upper()}{reset}"
                elif raw_rest.strip():
                    colored_label = f"{colored_tid} {pastel_purple}{raw_rest.strip().upper()}{reset}"
                else:
                    colored_label = colored_tid
            else:
                colored_label = f"{pastel_purple}{status_text.upper()}{reset}"

            sup_badge = get_supervisor_status(conv_id)
            print(f"{colored_label} {dim}│{reset} {sup_badge}")
            # 2026-11-13 : deuxième ligne compacte — état du workflow + repère git.
            scope_badge = get_scope_badge(conv_id, stdin_transcript)
            socle_badge = get_socle_badge(conv_id)
            alias = ""
            try:
                alias = str((raw_title or "")).split()[0] if raw_title else ""
            except Exception:
                alias = ""
            progress_badge = get_progress_badge(alias)
            scope_part = f" │ {progress_badge}{socle_badge}{scope_badge}" if (progress_badge or socle_badge or scope_badge) else ""
            print(f"{STATUSLINE_INDENT}{get_workflow_badge(conv_id)}{scope_part} │ {get_git_badge()}")
    except Exception:
        # Filet de sécurité absolu : ne JAMAIS crasher en code 1
        print("🚀 AGY Antigravity")

if __name__ == "__main__":
    main()
