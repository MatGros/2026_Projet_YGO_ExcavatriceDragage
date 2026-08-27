#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===============================================================================
TOOLS / TASK_MANAGER — Serveur local avec synchronisation granulaire par tâche
===============================================================================
Fonctionnalités :
1. Lecture et écriture granulaire unitaire (par ID de tâche) dans TASKS.yaml
2. Gestion du verrouillage 🔒 / déverrouillage 🔓 unitaire
3. Fusion atomique : aucun écrasement mutuel entre l'humain et les agents IA
4. Serveur statique pour TASK_VIEWER.html avec rafraîchissement temps réel
===============================================================================
"""

import http.server
import socketserver
import os
import sys
import json
import webbrowser
import urllib.parse
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Configuration encodage console Windows
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

# Chemins du projet
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
WFLOW_DIR = PROJECT_ROOT / "DOC" / "WFLOW"
TASKS_YAML_PATH = WFLOW_DIR / "TASKS.yaml"
TASK_VIEWER_PATH = WFLOW_DIR / "TASK_VIEWER.html"

DEFAULT_PORT = 8080


def get_current_iso_time():
    """Retourne l'horodatage ISO 8601 local (UTC+2 été)."""
    now = datetime.now()
    return now.strftime("%Y-%m-%dT%H:%M:%S")


def parse_yaml_tasks_raw(yaml_text):
    """Parseur YAML tolérant pour extraire la liste des dictionnaires de tâches."""
    lines = yaml_text.splitlines()
    task_list = []
    current_task = None
    current_list_key = None

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if stripped.startswith("- id:"):
            if current_task:
                task_list.append(current_task)
            val = stripped[5:].strip().strip('"').strip("'")
            current_task = {
                "id": val,
                "parent_id": "",
                "statut": "⬜",
                "criticite": "C2",
                "domaine": "GÉNÉRAL",
                "agent": "—",
                "date": "",
                "titre": "",
                "contexte": "",
                "description": "",
                "contrat": "",
                "objectifs": [],
                "bloque_par": []
            }
            current_list_key = None
            continue

        if not current_task:
            continue

        if stripped.startswith("- ") and current_list_key:
            item_val = stripped[2:].strip().strip('"').strip("'")
            if isinstance(current_task.get(current_list_key), list):
                current_task[current_list_key].append(item_val)
            continue

        if ":" in stripped:
            parts = stripped.split(":", 1)
            key = parts[0].strip()
            val = parts[1].strip()
            current_list_key = None

            if val == "[]":
                current_task[key] = []
            elif val in ("", ">-", ">", "|"):
                if key in ("objectifs", "bloque_par"):
                    current_task[key] = []
                    current_list_key = key
                else:
                    current_task[key] = ""
            else:
                val = val.strip('"').strip("'")
                current_task[key] = val

    if current_task:
        task_list.append(current_task)
    return task_list


def dump_yaml_tasks(tasks):
    """Génère le texte complet TASKS.yaml normé avec commentaires d'en-tête."""
    yaml = "# ============================================================\n"
    yaml += "# CATALOGUE OFFICIEL DES TÂCHES — EXCAVATRICE DE DRAGAGE\n"
    yaml += "# ============================================================\n"
    yaml += "# 💡 Modifiable dans TASK_VIEWER.html ou directement ici.\n"
    yaml += "# 🔄 Synchronisé automatiquement.\n\n"
    yaml += "tasks:\n"

    for t in tasks:
        yaml += f"  - id: \"{t.get('id', '')}\"\n"
        yaml += f"    parent_id: \"{t.get('parent_id', '')}\"\n"
        yaml += f"    statut: \"{t.get('statut', '⬜')}\"\n"
        yaml += f"    criticite: \"{t.get('criticite', 'C2')}\"\n"
        yaml += f"    domaine: \"{t.get('domaine', 'GÉNÉRAL')}\"\n"
        yaml += f"    agent: \"{t.get('agent', '—')}\"\n"
        yaml += f"    date: \"{t.get('date', '')}\"\n"
        yaml += f"    titre: {json.dumps(t.get('titre', ''), ensure_ascii=False)}\n"
        yaml += f"    contexte: {json.dumps(t.get('contexte', ''), ensure_ascii=False)}\n"
        yaml += f"    description: {json.dumps(t.get('description', ''), ensure_ascii=False)}\n"
        yaml += f"    contrat: \"{t.get('contrat', '')}\"\n"
        
        objs = t.get("objectifs", [])
        if objs:
            yaml += "    objectifs:\n"
            for o in objs:
                yaml += f"      - {json.dumps(o, ensure_ascii=False)}\n"
        else:
            yaml += "    objectifs: []\n"

        bloqs = t.get("bloque_par", [])
        if bloqs:
            yaml += "    bloque_par:\n"
            for b in bloqs:
                yaml += f"      - {json.dumps(b, ensure_ascii=False)}\n"
        else:
            yaml += "    bloque_par: []\n\n"

    return yaml


def load_tasks_from_disk():
    """Lit et parse les tâches fraîches du disque."""
    if not TASKS_YAML_PATH.exists():
        return []
    with open(TASKS_YAML_PATH, "r", encoding="utf-8") as f:
        content = f.read()
    return parse_yaml_tasks_raw(content)


def write_tasks_to_disk(tasks):
    """Écrit la liste complète des tâches de façon atomique."""
    yaml_text = dump_yaml_tasks(tasks)
    tmp_path = TASKS_YAML_PATH.with_suffix(".tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(yaml_text)
    if TASKS_YAML_PATH.exists():
        os.replace(tmp_path, TASKS_YAML_PATH)
    else:
        os.rename(tmp_path, TASKS_YAML_PATH)


class TaskManagerHandler(http.server.SimpleHTTPRequestHandler):
    """Gestionnaire HTTP avec endpoints granulaires unitaire par tâche."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WFLOW_DIR), **kwargs)

    def log_message(self, format, *args):
        try:
            sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")
            sys.stdout.flush()
        except Exception:
            pass

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        if path in ("/", "/index.html"):
            self.send_response(302)
            self.send_header("Location", f"/TASK_VIEWER.html?v={int(datetime.now().timestamp())}")
            self.end_headers()
            return

        # 1. API: Récupération de l'ensemble des tâches en JSON
        if path == "/api/tasks/json":
            tasks = load_tasks_from_disk()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(tasks, ensure_ascii=False).encode("utf-8"))
            return

        # 2. API: Lecture brute du fichier TASKS.yaml
        if path == "/api/tasks":
            if not TASKS_YAML_PATH.exists():
                self.send_error(404, "Fichier TASKS.yaml introuvable")
                return
            with open(TASKS_YAML_PATH, "r", encoding="utf-8") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/yaml; charset=utf-8")
            self.end_headers()
            self.wfile.write(content.encode("utf-8"))
            return

        # 3. API: Statut de santé
        if path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            tasks = load_tasks_from_disk()
            payload = {
                "status": "ok",
                "server": "TaskManager-Granular-Python",
                "tasks_count": len(tasks),
                "tasks_path": str(TASKS_YAML_PATH)
            }
            self.wfile.write(json.dumps(payload).encode("utf-8"))
            return

        super().do_GET()

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        content_length = int(self.headers.get("Content-Length", 0))

        if content_length <= 0:
            self.send_error(400, "Corps de requête vide")
            return

        try:
            raw_data = self.rfile.read(content_length)
            
            # --- 1. MODIFICATION / AJOUT GRANULAIRE D'UNE TÂCHE UNIQUE ---
            if path == "/api/task/save":
                task_data = json.loads(raw_data.decode("utf-8"))
                task_id = str(task_data.get("id", "")).strip()

                if not task_id:
                    self.send_error(400, "Identifiant 'id' manquant")
                    return

                # Rechargement frais depuis le disque pour éviter d'écraser les autres
                tasks = load_tasks_from_disk()
                idx = next((i for i, t in enumerate(tasks) if t["id"] == task_id), -1)

                # Si la tâche existe déjà, préserver les champs non spécifiés
                if idx >= 0:
                    existing = tasks[idx]
                    for k, v in task_data.items():
                        existing[k] = v
                    tasks[idx] = existing
                    action_name = "Mise à jour"
                else:
                    # Nouvelle tâche insérée en tête
                    tasks.insert(0, task_data)
                    action_name = "Création"

                write_tasks_to_disk(tasks)
                print(f"[GRANULAR SAVE] {action_name} de la tâche {task_id} (Total : {len(tasks)} tâches)")

                response = {"success": True, "action": action_name, "task_id": task_id, "total": len(tasks)}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode("utf-8"))
                return

            # --- 2. SUPPRESSION GRANULAIRE D'UNE TÂCHE UNIQUE ---
            if path == "/api/task/delete":
                req_json = json.loads(raw_data.decode("utf-8"))
                task_id = str(req_json.get("id", "")).strip()
                force = bool(req_json.get("force", False))

                tasks = load_tasks_from_disk()
                target_task = next((t for t in tasks if t["id"] == task_id), None)

                if not target_task:
                    self.send_error(404, f"Tâche {task_id} introuvable")
                    return

                # Règle de sécurité : interdiction de supprimer une tâche verrouillée sans force=True
                if target_task.get("statut") == "🔒" and not force:
                    self.send_response(423) # 423 Locked
                    self.send_header("Content-Type", "application/json; charset=utf-8")
                    self.end_headers()
                    err = {"success": False, "error": f"La tâche {task_id} est actuellement verrouillée (🔒). Déverrouillez-la d'abord ou forcez la suppression."}
                    self.wfile.write(json.dumps(err).encode("utf-8"))
                    return

                tasks = [t for t in tasks if t["id"] != task_id]
                write_tasks_to_disk(tasks)
                print(f"[GRANULAR DELETE] Suppression de la tâche {task_id} (Total restant : {len(tasks)})")

                response = {"success": True, "task_id": task_id, "total": len(tasks)}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode("utf-8"))
                return

            # --- 3. DÉVERROUILLAGE D'UNE TÂCHE (FORCE UNLOCK) ---
            if path == "/api/task/unlock":
                req_json = json.loads(raw_data.decode("utf-8"))
                task_id = str(req_json.get("id", "")).strip()

                tasks = load_tasks_from_disk()
                idx = next((i for i, t in enumerate(tasks) if t["id"] == task_id), -1)

                if idx == -1:
                    self.send_error(404, f"Tâche {task_id} introuvable")
                    return

                tasks[idx]["statut"] = "⬜"
                tasks[idx]["agent"] = "—"
                tasks[idx]["date"] = get_current_iso_time()

                write_tasks_to_disk(tasks)
                print(f"[GRANULAR UNLOCK] Tâche {task_id} déverrouillée et libérée")

                response = {"success": True, "task_id": task_id, "statut": "⬜", "agent": "—"}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode("utf-8"))
                return

            # --- 4. VERROUILLAGE D'UNE TÂCHE (LOCK) ---
            if path == "/api/task/lock":
                req_json = json.loads(raw_data.decode("utf-8"))
                task_id = str(req_json.get("id", "")).strip()
                agent_name = str(req_json.get("agent", "HUM")).strip()

                tasks = load_tasks_from_disk()
                idx = next((i for i, t in enumerate(tasks) if t["id"] == task_id), -1)

                if idx == -1:
                    self.send_error(404, f"Tâche {task_id} introuvable")
                    return

                tasks[idx]["statut"] = "🔒"
                tasks[idx]["agent"] = agent_name
                tasks[idx]["date"] = get_current_iso_time()

                write_tasks_to_disk(tasks)
                print(f"[GRANULAR LOCK] Tâche {task_id} verrouillée par {agent_name}")

                response = {"success": True, "task_id": task_id, "statut": "🔒", "agent": agent_name}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode("utf-8"))
                return

            # --- 5. SAUVEGARDE GLOBALE (BACKUP / BULK) ---
            if path == "/api/save":
                yaml_text = raw_data.decode("utf-8")
                if "tasks:" not in yaml_text:
                    self.send_error(400, "YAML invalide (clé tasks: absente)")
                    return

                tmp_path = TASKS_YAML_PATH.with_suffix(".tmp")
                with open(tmp_path, "w", encoding="utf-8") as f:
                    f.write(yaml_text)
                if TASKS_YAML_PATH.exists():
                    os.replace(tmp_path, TASKS_YAML_PATH)
                else:
                    os.rename(tmp_path, TASKS_YAML_PATH)

                count = yaml_text.count("- id:")
                print(f"[BULK SAVE] TASKS.yaml synchronisé ({count} tâches)")
                response = {"success": True, "task_count": count}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode("utf-8"))
                return

        except Exception as e:
            print(f"[ERREUR POST] {str(e)}", file=sys.stderr)
            self.send_error(500, f"Erreur serveur : {str(e)}")
            return

        self.send_error(404, "Endpoint non reconnu")


def start_server(port=DEFAULT_PORT, auto_open=True):
    handler = TaskManagerHandler
    server = None
    actual_port = port

    for p in range(port, port + 10):
        try:
            socketserver.TCPServer.allow_reuse_address = True
            server = socketserver.TCPServer(("", p), handler)
            actual_port = p
            break
        except OSError:
            continue

    if not server:
        print(f"Erreur : Impossible de démarrer le serveur sur les ports {port}..{port+9}")
        sys.exit(1)

    url = f"http://localhost:{actual_port}/TASK_VIEWER.html?v={int(datetime.now().timestamp())}"
    print("=" * 65)
    print("📋 TASK MANAGER — SERVEUR GRANULAIRE ACTIF")
    print("=" * 65)
    print(f"📍 URL Web            : {url}")
    print(f"📁 Fichier Cible      : {TASKS_YAML_PATH}")
    print("🔒 Verrouillage fin   : OUI (Protection unitaire anti-écrasement)")
    print("⚡ Sauvegarde auto    : OUI (Granulaire par tâche)")
    print("💡 Pour arrêter       : Appuyez sur Ctrl + C")
    print("=" * 65)

    if auto_open:
        try:
            webbrowser.open(url)
        except Exception:
            pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Arrêt du serveur Task Manager.")
    finally:
        server.server_close()


if __name__ == "__main__":
    port_arg = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port_arg = int(sys.argv[1])
        except ValueError:
            pass
    start_server(port=port_arg)
