import sys
import json
import os
import re

def is_multi_agent_active():
    queue_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\DOC\AGENT_HANDOFF\QUEUE.md"
    if not os.path.exists(queue_path):
        return False
    try:
        with open(queue_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Sépare la partie active de l'archive historique
        parts = re.split(r'#+\s+Archive', content, flags=re.IGNORECASE)
        active_part = parts[0]
        
        # Si une tâche TASK-XXXX est trouvée dans la section active
        if re.search(r'\|\s*\[?TASK-\d+\]?', active_part):
            return True
    except Exception:
        return True # Sécurité : assume actif en cas d'erreur de lecture
    return False

def main():
    try:
        # Read the stdin JSON payload
        payload = json.loads(sys.stdin.read())
        
        tool_call = payload.get("toolCall", {})
        tool_name = tool_call.get("name")
        args = tool_call.get("args", {})
        
        # Si le workflow multi-agent n'est pas actif, on laisse passer (mode normal)
        multi_active = is_multi_agent_active()
        
        if multi_active:
            # --- MODE MULTI-AGENT ACTIF ---
            
            # 1. Bloque les commits
            if tool_name == "run_command":
                cmd = args.get("CommandLine", "").strip()
                if re.search(r'\bgit\s+commit\b', cmd, re.IGNORECASE):
                    print(json.dumps({
                        "allow_tool": False,
                        "deny_reason": "🚨 [RULE VIOLATION] Workflow multi-agent actif : Gemini n'a pas le droit de commiter directement. Le commit/merge est réservé à Claude ou à l'utilisateur."
                    }), flush=True)
                    sys.exit(0)
                    
            # 2. Vérifie le scope de la tâche active
            if tool_name in ["replace_file_content", "multi_replace_file_content", "write_to_file"]:
                target_file = args.get("TargetFile", "")
                if target_file:
                    target_file_normalized = os.path.normpath(target_file).lower()
                    
                    # Exclusions de métadonnées
                    is_meta = any(target_file_normalized.endswith(meta) for meta in [
                        "queue.md", "plan_task_v1.0.md", "version_history.md", "claude.md", "hooks.json"
                    ]) or "agent_handoff\\tasks\\" in target_file_normalized or "\\scratch\\" in target_file_normalized
                    
                    if not is_meta:
                        # Recherche de la tâche IN_PROGRESS de Gemini
                        queue_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\DOC\AGENT_HANDOFF\QUEUE.md"
                        in_progress_task = None
                        if os.path.exists(queue_path):
                            with open(queue_path, "r", encoding="utf-8") as f:
                                content = f.read()
                            for line in content.splitlines():
                                if "|" in line and "gemini" in line.lower() and "in_progress" in line.lower():
                                    match = re.search(r'\[(TASK-\d+)\]\((tasks/[^)]+)\)', line)
                                    if match:
                                        in_progress_task = match.group(2)
                                        break
                                        
                        if in_progress_task:
                            task_abs_path = os.path.normpath(os.path.join(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\DOC\AGENT_HANDOFF", in_progress_task))
                            if os.path.exists(task_abs_path):
                                with open(task_abs_path, "r", encoding="utf-8") as f:
                                    task_content = f.read()
                                
                                # Extrait le bloc ## 📂 Scope
                                scope_lines = []
                                in_scope = False
                                for line in task_content.splitlines():
                                    if "## 📂 Scope" in line:
                                        in_scope = True
                                    elif line.startswith("## ") and in_scope:
                                        break
                                    elif in_scope:
                                        m = re.search(r'-\s+`([^`]+)`', line)
                                        if m:
                                            scope_lines.append(m.group(1).lower())
                                
                                scope_paths = [os.path.normpath(os.path.join(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage", p)).lower() for p in scope_lines]
                                
                                if target_file_normalized not in scope_paths:
                                    print(json.dumps({
                                        "allow_tool": False,
                                        "deny_reason": f"🚨 [RULE VIOLATION] Hors-scope pour la tâche active ! Fichiers autorisés : {', '.join(scope_lines)}"
                                    }), flush=True)
                                    sys.exit(0)
                                    
        # Si multi_active = False, ou si l'action est valide
        print(json.dumps({"allow_tool": True}), flush=True)
        
    except Exception as e:
        print(json.dumps({"allow_tool": True, "error": str(e)}), flush=True)

if __name__ == "__main__":
    main()
