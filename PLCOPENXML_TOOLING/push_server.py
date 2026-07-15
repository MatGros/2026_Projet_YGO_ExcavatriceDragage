"""
push_server.py — Smart Queue Watcher + Push Notification Server
================================================================
• Thread HTTP  : écoute port 9090 → /wake (appelé directement par Claude après validation
  utilisateur, sans attendre de commit — hook git post-commit gardé en filet de sécurité)
• Thread POLL  : vérifie QUEUE.md toutes les POLL_INTERVAL secondes (0 token IA)
• Si changement ET tâche Gemini TODO → écrit WAKE_FLAG.txt + réveille Gemini via agy CLI
• Tokens IA consommés SEULEMENT si tâche réelle détectée — 0 token sur checks vides
"""

import http.server
import socketserver
import subprocess
import threading
import time
import os
import sys
import json
from datetime import datetime

# ── Config ──────────────────────────────────────────────────────────────────
POLL_INTERVAL  = 10  # secondes entre chaque check QUEUE.md (0 token IA)
HTTP_PORT      = 9090

PROJECT_ROOT   = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage"
QUEUE_FILE     = os.path.join(PROJECT_ROOT, "DOC", "AGENT_HANDOFF", "QUEUE.md")
WAKE_FLAG      = os.path.join(PROJECT_ROOT, "DOC", "AGENT_HANDOFF", "WAKE_FLAG.txt")
WAKE_STATUS    = os.path.join(PROJECT_ROOT, "DOC", "AGENT_HANDOFF", "WAKE_STATUS.json")
AGY_TIMEOUT_S  = 180  # 🆕 REX 2026-07-15 : 30s trop court, un appel réel a dépassé 60s

# ── Stdout UTF-8 (Windows) ───────────────────────────────────────────────────
sys.stdout.reconfigure(encoding="utf-8")

# ── Helpers ──────────────────────────────────────────────────────────────────
def ts():
    """Timestamp lisible."""
    return datetime.now().strftime("%H:%M:%S")


def get_gemini_todo_tasks():
    """Lit QUEUE.md et retourne la liste des tâches Gemini avec Status TODO.
    Pure Python stdlib — 0 token IA."""
    if not os.path.exists(QUEUE_FILE):
        return []
    tasks = []
    try:
        with open(QUEUE_FILE, "r", encoding="utf-8") as f:
            for line in f:
                if "|" not in line:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 6:
                    continue
                raw_task_id = parts[1]
                # Nettoie les liens markdown ex: [TASK-0002](...) -> TASK-0002
                task_id = raw_task_id.lstrip("[").split("]")[0]
                
                title    = parts[2]
                assigned = parts[3].lower()
                status   = parts[4].lower()
                if "gemini" in assigned and "todo" in status and task_id.startswith("TASK-"):
                    tasks.append(f"{task_id} — {title}")
    except Exception as e:
        print(f"[{ts()}] ⚠️  Erreur lecture QUEUE.md : {e}", flush=True)
    return tasks


def write_wake_flag(tasks: list[str], source: str):
    """Écrit WAKE_FLAG.txt avec les tâches détectées."""
    content_lines = [
        f"# WAKE FLAG — {datetime.now().isoformat()}",
        f"Source  : {source}",
        f"Port    : {HTTP_PORT}",
        f"Tâches  : {len(tasks)}",
        "",
        "## Tâches Gemini TODO :",
    ] + [f"  • {t}" for t in tasks] + [
        "",
        "→ Lire DOC/AGENT_HANDOFF/QUEUE.md puis les fichiers tasks/ correspondants.",
    ]
    try:
        with open(WAKE_FLAG, "w", encoding="utf-8") as f:
            f.write("\n".join(content_lines) + "\n")
        print(f"[{ts()}] 📝 WAKE_FLAG.txt écrit ({len(tasks)} tâche(s))", flush=True)
    except Exception as e:
        print(f"[{ts()}] ⚠️  Erreur écriture WAKE_FLAG.txt : {e}", flush=True)


def write_wake_status(data: dict):
    """Écrit l'état du dernier réveil (WAKE_STATUS.json) — consultable via GET /wake_status."""
    try:
        with open(WAKE_STATUS, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[{ts()}] ⚠️  Erreur écriture WAKE_STATUS.json : {e}", flush=True)


def _agy_watcher(proc: subprocess.Popen, tasks: list[str], started_at: datetime):
    """Attend la fin réelle du process agy (ou timeout) et journalise le résultat vrai
    (returncode, stdout/stderr, durée) — remplace le fire-and-forget aveugle précédent."""
    log_path = os.path.join(PROJECT_ROOT, "DOC", "AGENT_HANDOFF", "agy_wake.log")
    try:
        stdout, stderr = proc.communicate(timeout=AGY_TIMEOUT_S)
        duration = (datetime.now() - started_at).total_seconds()
        status = "completed" if proc.returncode == 0 else "failed"
        print(f"[{ts()}] {'✅' if status == 'completed' else '⚠️ '} agy CLI {status} "
              f"(code={proc.returncode}, {duration:.1f}s)", flush=True)
    except subprocess.TimeoutExpired:
        duration = float(AGY_TIMEOUT_S)
        status = "timeout"
        stdout, stderr = "", f"Pas de réponse après {AGY_TIMEOUT_S}s (pid={proc.pid} toujours actif, non tué)"
        print(f"[{ts()}] ⚠️  agy CLI timeout après {AGY_TIMEOUT_S}s (pid={proc.pid})", flush=True)
    except Exception as e:
        duration = (datetime.now() - started_at).total_seconds()
        status = "error"
        stdout, stderr = "", str(e)
        print(f"[{ts()}] ⚠️  agy CLI erreur watcher : {e}", flush=True)

    write_wake_status({
        "started_at": started_at.isoformat(),
        "finished_at": datetime.now().isoformat(),
        "duration_s": round(duration, 1),
        "tasks": tasks,
        "agy_status": status,
        "agy_pid": proc.pid,
        "returncode": proc.returncode if status != "timeout" else None,
        "stdout_tail": (stdout or "")[-2000:],
        "stderr_tail": (stderr or "")[-2000:],
    })
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"\n[{datetime.now().isoformat()}] status={status} code={proc.returncode} duration={duration:.1f}s\n")
            if stdout:
                f.write(f"--- stdout ---\n{stdout}\n")
            if stderr:
                f.write(f"--- stderr ---\n{stderr}\n")
    except Exception as e:
        print(f"[{ts()}] ⚠️  Erreur écriture agy_wake.log : {e}", flush=True)


def wake_gemini_agent(tasks: list[str]):
    """Réveille Gemini via agy CLI — appelé UNIQUEMENT si tâches réelles détectées.
    1 seul appel IA, 0 token sur checks vides.
    🆕 REX 2026-07-15 : --continue (reprend la conversation la plus récente) au lieu d'un
    --conversation <ID figé> — l'ID changeait à chaque nouvelle session Gemini et n'était pas
    remis à jour, donc l'appel partait dans le vide (silencieusement, returncode 0 malgré tout).
    🆕 REX 2026-07-15 (bis) : le fire-and-forget (Popen + DEVNULL) ne donnait AUCUNE visibilité
    sur le résultat réel (succès/échec/timeout) — un test manuel a montré que l'appel peut
    dépasser 60s. Popen reste non-bloquant pour l'HTTP handler, mais un thread watcher
    daemon capture maintenant stdout/stderr/returncode/durée réels dans WAKE_STATUS.json.
    🆕 REX 2026-07-15 (ter) : bug connu d'Antigravity CLI — en mode --print (non-TTY, appelé
    depuis un subprocess), un prompt d'approbation d'écriture fichier ne peut jamais s'afficher
    → hang silencieux (cf. github.com/google-antigravity/antigravity-cli issues #76).
    --dangerously-skip-permissions (confirmé par `agy --help`) auto-approuve pour éviter ce
    blocage ; --print-timeout aligné sur AGY_TIMEOUT_S pour que agy lui-même coupe court."""
    task_list = "\n".join(f"  • {t}" for t in tasks)
    message = (
        f"🚨 [WATCHER] Nouvelle(s) tâche(s) Gemini TODO détectée(s) dans QUEUE.md :\n"
        f"{task_list}\n\n"
        f"→ Lire DOC/AGENT_HANDOFF/QUEUE.md et les fichiers tasks/ correspondants."
    )
    started_at = datetime.now()
    write_wake_status({
        "started_at": started_at.isoformat(),
        "finished_at": None,
        "duration_s": None,
        "tasks": tasks,
        "agy_status": "pending",
        "agy_pid": None,
        "returncode": None,
        "stdout_tail": "",
        "stderr_tail": "",
    })
    try:
        proc = subprocess.Popen(
            [
                "agy", "--continue", "--print", message,
                "--dangerously-skip-permissions",
                "--print-timeout", f"{AGY_TIMEOUT_S}s",
            ],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        print(f"[{ts()}] 🚀 agy CLI lancé (pid={proc.pid}) — suivi en fond, max {AGY_TIMEOUT_S}s", flush=True)
        threading.Thread(target=_agy_watcher, args=(proc, tasks, started_at), daemon=True).start()
    except FileNotFoundError:
        print(f"[{ts()}] ⚠️  agy CLI introuvable — réveil manuel requis", flush=True)
        write_wake_status({
            "started_at": started_at.isoformat(), "finished_at": datetime.now().isoformat(),
            "duration_s": 0, "tasks": tasks, "agy_status": "not_found",
            "agy_pid": None, "returncode": None, "stdout_tail": "", "stderr_tail": "",
        })
    except Exception as e:
        print(f"[{ts()}] ⚠️  wake_gemini_agent erreur : {e}", flush=True)
        write_wake_status({
            "started_at": started_at.isoformat(), "finished_at": datetime.now().isoformat(),
            "duration_s": 0, "tasks": tasks, "agy_status": "error",
            "agy_pid": None, "returncode": None, "stdout_tail": "", "stderr_tail": str(e),
        })


# ── Polling thread (0 token) ─────────────────────────────────────────────────
def polling_loop():
    """Vérifie QUEUE.md toutes les POLL_INTERVAL secondes.
    N'appelle JAMAIS l'IA — pur Python stdlib."""
    last_mtime  = 0
    last_tasks  = []

    print(f"[{ts()}] 🔄 Polling QUEUE.md toutes les {POLL_INTERVAL}s ...", flush=True)

    while True:
        try:
            if os.path.exists(QUEUE_FILE):
                mtime = os.path.getmtime(QUEUE_FILE)
                if mtime != last_mtime:
                    last_mtime = mtime
                    current_tasks = get_gemini_todo_tasks()

                    new_tasks = [t for t in current_tasks if t not in last_tasks]
                    if new_tasks:
                        print(f"\n[{ts()}] 🚨 Nouvelle(s) tâche(s) détectée(s) :", flush=True)
                        for t in new_tasks:
                            print(f"         → {t}", flush=True)
                        write_wake_flag(current_tasks, source="poll-QUEUE.md")
                        wake_gemini_agent(new_tasks)
                    elif current_tasks != last_tasks:
                        # Changement mais pas de nouvelles tâches (ex: statut mis à jour)
                        print(f"[{ts()}] ℹ️  QUEUE.md modifié — pas de nouvelle tâche TODO Gemini", flush=True)

                    last_tasks = current_tasks
        except Exception as e:
            print(f"[{ts()}] ⚠️  Erreur polling : {e}", flush=True)

        time.sleep(POLL_INTERVAL)


# ── HTTP server (réception hook git /wake) ───────────────────────────────────
class WakeHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Silencer les logs HTTP verbeux

    def _handle_wake(self):
        # 🆕 REX 2026-07-15 : réponse enrichie AVANT tout appel agy — dit ce qui a été
        # trouvé (pas juste "reçu"), pour distinguer "requête HTTP reçue" de "agy a répondu".
        tasks = get_gemini_todo_tasks()
        payload = {
            "status": "received",
            "timestamp": datetime.now().isoformat(),
            "todo_tasks_found": len(tasks),
            "tasks": tasks,
            "note": "Ceci confirme la réception HTTP uniquement. Voir GET /wake_status "
                    "pour le résultat réel de l'appel agy (succès/échec/timeout).",
        }
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload, ensure_ascii=False).encode("utf-8"))

        print(f"\n[{ts()}] ⚡ /wake reçu", flush=True)
        if tasks:
            print(f"[{ts()}] 🚨 {len(tasks)} tâche(s) Gemini TODO :", flush=True)
            for t in tasks:
                print(f"         → {t}", flush=True)
            write_wake_flag(tasks, source="http /wake")
            wake_gemini_agent(tasks)
        else:
            print(f"[{ts()}] ✅ Pas de tâche Gemini TODO — aucun flag écrit", flush=True)
            write_wake_status({
                "started_at": datetime.now().isoformat(), "finished_at": datetime.now().isoformat(),
                "duration_s": 0, "tasks": [], "agy_status": "no_task",
                "agy_pid": None, "returncode": None, "stdout_tail": "", "stderr_tail": "",
            })

    def _handle_wake_status(self):
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        if os.path.exists(WAKE_STATUS):
            with open(WAKE_STATUS, "r", encoding="utf-8") as f:
                self.wfile.write(f.read().encode("utf-8"))
        else:
            self.wfile.write(json.dumps({"agy_status": "never_called"}).encode())

    def do_GET(self):
        if self.path == "/wake":
            self._handle_wake()
        elif self.path == "/wake_status":
            self._handle_wake_status()
        elif self.path == "/status":
            tasks = get_gemini_todo_tasks()
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"tasks": tasks, "count": len(tasks)}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/wake":
            self._handle_wake()
        else:
            self.send_response(404)
            self.end_headers()


# ── Main ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60, flush=True)
    print("  🤖 Smart Queue Watcher — Excavatrice de Dragage", flush=True)
    print(f"  📋 QUEUE   : {QUEUE_FILE}", flush=True)
    print(f"  🚩 FLAG    : {WAKE_FLAG}", flush=True)
    print(f"  🔄 Polling : toutes les {POLL_INTERVAL}s (0 token IA)", flush=True)
    print(f"  🌐 HTTP    : port {HTTP_PORT}  (/wake  /wake_status  /status)", flush=True)
    print("=" * 60, flush=True)

    # 🆕 REX 2026-07-15 : allow_reuse_address=True laissait Windows empiler plusieurs process
    # sur le même port sans erreur (10 zombies constatés) — un seul serveur doit exister.
    # Bind AVANT de démarrer le polling : si le port est pris, on n'active RIEN (pas de
    # fallback polling-only silencieux) — arrêt franc, message clair, exit 1.
    try:
        httpd = socketserver.TCPServer(("", HTTP_PORT), WakeHandler)
    except OSError as e:
        print(f"[{ts()}] ❌ Port {HTTP_PORT} déjà utilisé ({e})", flush=True)
        print(f"[{ts()}]    → Une instance tourne probablement déjà. Script non démarré.", flush=True)
        sys.exit(1)

    # Lancer le polling dans un thread daemon (uniquement si le port a été obtenu)
    poll_thread = threading.Thread(target=polling_loop, daemon=True)
    poll_thread.start()

    try:
        with httpd:
            print(f"[{ts()}] ✅ Serveur prêt — en attente...\n", flush=True)
            httpd.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{ts()}] 🛑 Arrêt propre.", flush=True)
