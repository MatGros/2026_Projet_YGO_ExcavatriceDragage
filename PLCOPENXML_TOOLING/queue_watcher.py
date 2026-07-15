import os
import time
import sys

QUEUE_FILE = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\DOC\AGENT_HANDOFF\QUEUE.md"

print("Watcher started for:", QUEUE_FILE, flush=True)

def get_todo_tasks():
    if not os.path.exists(QUEUE_FILE):
        return []
    tasks = []
    try:
        with open(QUEUE_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        for line in content.splitlines():
            if "|" in line:
                parts = [p.strip() for p in line.split("|")]
                if len(parts) >= 5:
                    task_id = parts[1]
                    title = parts[2]
                    assigned = parts[3].lower()
                    status = parts[4].lower()
                    if "gemini" in assigned and "todo" in status:
                        tasks.append(f"{task_id} - {title}")
    except Exception as e:
        print(f"Error reading queue: {e}", flush=True)
    return tasks

last_mtime = 0
last_tasks = []

while True:
    try:
        if os.path.exists(QUEUE_FILE):
            mtime = os.path.getmtime(QUEUE_FILE)
            if mtime != last_mtime:
                last_mtime = mtime
                current_tasks = get_todo_tasks()
                # Find new tasks
                new_tasks = [t for t in current_tasks if t not in last_tasks]
                if new_tasks:
                    print(f"🚨 [WATCHER] Nouvelle(s) tâche(s) détectée(s) : {', '.join(new_tasks)}", flush=True)
                last_tasks = current_tasks
    except Exception as e:
        print(f"Watcher error: {e}", flush=True)
    time.sleep(2)
