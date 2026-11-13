#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🤖 SPECIALIST RUNNER — Invocateur de Personas Agents Spécialisés (OOA)
=====================================================================
Permet d'appeler les Function Blocks Agents spécialisés en mode autonome (CLI/Slash command)
ou intégré au workflow (Orchestrateur C3/C4).

Rôles disponibles :
  - safety    : FB_Agent_Safety (Sécurité machine ISO 13849, chaîne AU, anti-chute, mou de câble)
  - plc       : FB_Agent_PLC (Automatisme CODESYS, variateurs, séquencement frein, timing)
  - hmi       : FB_Agent_HMI (Ergonomie exploitant, bannières max 42 cars, alarmes démasquées)
  - testing   : FB_Agent_Testing (Dualité tests +/- et hystérésis, syntaxe native STruCpp)
  - standards : FB_Agent_Standards (Norme T279, nomenclature, PascalCase, hygiène)

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --role safety --target CODE/M_MAIN/PRG_04_Treuils_Benne.st --prompt "Vérifier le réarmement"
  python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --role hmi --target CODE/M_MAIN/PRG_07_Supervision.st --task T429
  python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --list-roles
"""

import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
import yaml

sys.stdout.reconfigure(encoding='utf-8')

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SPECIALISTS_DIR = os.path.join(os.path.dirname(__file__), "..", "specialists")
PREAMBLE_PATH = os.path.join(os.path.dirname(__file__), "..", "prompts", "subagent_preamble.md")

ROLE_MAP = {
    "safety": "FB_Agent_Safety.md",
    "plc": "FB_Agent_PLC.md",
    "hmi": "FB_Agent_HMI.md",
    "testing": "FB_Agent_Testing.md",
    "standards": "FB_Agent_Standards.md",
    "challenger": "FB_Agent_Challenger.md",
}

PROMPTS_DIR = os.path.join(REPO_ROOT, "DOC", "WFLOW", "PROMPTS", "SPECIALISTS")

PROMPT_FILE_MAP = {
    "safety": "PROMPT_FB_Agent_Safety.md",
    "plc": "PROMPT_FB_Agent_PLC.md",
    "hmi": "PROMPT_FB_Agent_HMI.md",
    "testing": "PROMPT_FB_Agent_Testing.md",
    "standards": "PROMPT_FB_Agent_Standards.md",
    "challenger": "PROMPT_FB_Agent_Challenger.md",
}

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "deepseek-v4.1-flash:cloud"
DEFAULT_NUM_CTX = 16384
DEFAULT_TIMEOUT_S = 300


def validate_output_path(output_path: str):
    """Garde-fou mécanique Norme T279 & règle '1 tâche = 1 dossier'."""
    abs_path = os.path.abspath(output_path)
    try:
        rel = os.path.relpath(abs_path, REPO_ROOT).replace("\\", "/")
    except ValueError:
        rel = output_path.replace("\\", "/")

    # Whitelist stricte T279 : sous DOC/WFLOW/TASKS/T<ID>.../(PREUVES|ARCHIVES)/
    t279_pattern = r"^DOC/WFLOW/TASKS/T[0-9]+[^/]*/(PREUVES|ARCHIVES)/.+"
    if not re.match(t279_pattern, rel, re.IGNORECASE):
        print("=" * 72)
        print(f"⛔ [BLOQUÉ NORME T279] Chemin de sortie non conforme : '{output_path}'")
        print("=" * 72)
        print("Règles obligatoires (AGENTS.md & STRUCTURE_AND_CLEANUP.md) :")
        print("  1. Interdit d'écrire des fichiers à la racine du dépôt ou dans DOC/WFLOW/.")
        print("  2. Règle '1 tâche = 1 dossier' : classer obligatoirement sous :")
        print("     DOC/WFLOW/TASKS/T<ID>_<NOM>/PREUVES/<session>/ ou ARCHIVES/")
        print("=" * 72)
        sys.exit(1)


def resolve_task_folder(task_id: str) -> str:
    """Retrouve le dossier de la tâche sous DOC/WFLOW/TASKS/."""
    tasks_dir = os.path.join(REPO_ROOT, "DOC", "WFLOW", "TASKS")
    clean_id = task_id.upper().strip()
    if not clean_id.startswith("T"):
        clean_id = "T" + clean_id

    if os.path.exists(tasks_dir):
        for entry in os.listdir(tasks_dir):
            if entry.upper().startswith(clean_id + "_") or entry.upper() == clean_id:
                return os.path.join(tasks_dir, entry)

    # Repli par défaut
    return os.path.join(tasks_dir, f"{clean_id}_SPECIALIST_REVIEW")


def list_roles():
    print("=" * 70)
    print("🤖 PANEL D'AGENTS SPÉCIALISÉS DU PROJET (Orientés Objet)")
    print("=" * 70)
    for role, filename in ROLE_MAP.items():
        filepath = os.path.join(SPECIALISTS_DIR, filename)
        desc = "Fiche non trouvée"
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("> **Rôle** :"):
                        desc = line.replace("> **Rôle** :", "").strip()
                        break
        print(f"  • {role:<12} -> {desc}")
    print("=" * 70)


def list_prompts():
    print("=" * 72)
    print("📚 CATALOGUE DES PROMPTS SYSTÈME DES PERSONAS SPÉCIALISÉS")
    print("📂 Répertoire de référence : DOC/WFLOW/PROMPTS/SPECIALISTS/")
    print("=" * 72)
    for role, filename in PROMPT_FILE_MAP.items():
        filepath = os.path.join(PROMPTS_DIR, filename)
        exists_str = "✅ Présent" if os.path.exists(filepath) else "❌ Manquant"
        print(f"  • {role:<12} -> {filename:<32} [{exists_str}]")
    print("=" * 72)


def show_prompt(role: str):
    filename = PROMPT_FILE_MAP.get(role.lower())
    if not filename:
        print(f"[ERREUR] Rôle inconnu '{role}'. Rôles valides : {', '.join(PROMPT_FILE_MAP.keys())}")
        sys.exit(1)
    filepath = os.path.join(PROMPTS_DIR, filename)
    if not os.path.exists(filepath):
        print(f"[ERREUR] Fichier de prompt introuvable : {filepath}")
        sys.exit(1)

    print("=" * 72)
    print(f"📖 PROMPT SYSTÈME DU PERSONA [{role.upper()}]")
    print(f"📄 Fichier source : {os.path.relpath(filepath, REPO_ROOT)}")
    print("=" * 72)
    with open(filepath, "r", encoding="utf-8") as f:
        print(f.read())
    print("=" * 72)


def load_persona(role: str) -> str:
    filename = ROLE_MAP.get(role.lower())
    if not filename:
        print(f"[ERREUR] Rôle inconnu '{role}'. Rôles valides : {', '.join(ROLE_MAP.keys())}")
        sys.exit(1)

    filepath = os.path.join(SPECIALISTS_DIR, filename)
    if not os.path.exists(filepath):
        print(f"[ERREUR] Fiche persona introuvable : {filepath}")
        sys.exit(1)

    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


def extract_and_validate_yaml(response_text: str) -> tuple[dict | None, str]:
    """Extrait le bloc specialist_evaluation ou agent_evaluation et le valide."""
    pattern = r"```(?:ya?ml)?\s*((?:specialist|agent|challenge)_evaluation:.*?)```"
    yaml_match = re.search(pattern, response_text, re.DOTALL)
    raw_yaml = ""
    if yaml_match:
        raw_yaml = yaml_match.group(1).strip()
    else:
        direct_match = re.search(r"((?:specialist|agent|challenge)_evaluation:.*)", response_text, re.DOTALL)
        if direct_match:
            raw_yaml = direct_match.group(1).strip()

    if not raw_yaml:
        return None, "Bloc YAML d'évaluation introuvable dans la réponse du modèle."

    try:
        parsed = yaml.safe_load(raw_yaml)
        if not isinstance(parsed, dict):
            return None, "Contenu YAML non structuré en dictionnaire."

        root_key = None
        for candidate in ("specialist_evaluation", "agent_evaluation", "challenge_evaluation"):
            if candidate in parsed:
                root_key = candidate
                break

        if not root_key:
            return None, "Clé racine d'évaluation manquante (specialist_evaluation ou agent_evaluation)."

        spec = parsed[root_key]
        if not isinstance(spec, dict) or "verdict" not in spec:
            return None, "Schéma YAML invalide : clé 'verdict' manquante."
        # Normalisation pour accès uniforme
        parsed["_root_key"] = root_key
        parsed["_verdict"] = str(spec["verdict"]).upper().strip()
        return parsed, ""
    except Exception as e:
        return None, f"Erreur de syntaxe YAML : {e}"


def query_specialist(role: str, targets: list[str] = None, prompt: str = None, task_id: str = None,
                      output_file: str = None, model: str = DEFAULT_MODEL) -> int:
    """Interroge le spécialiste et renvoie le code de sortie (0=PASS/ADVISORY, 1=ERREUR, 2=BLOCK)."""
    persona_content = load_persona(role)
    
    full_system = ""
    if os.path.exists(PREAMBLE_PATH):
        with open(PREAMBLE_PATH, "r", encoding="utf-8") as f:
            full_system += f.read() + "\n\n"
    full_system += f"=== SPECIFICATION DU PERSONA SPÉCIALISÉ ===\n{persona_content}\n"

    user_query = f"DEMANDE D'EXPERTISE [{role.upper()}]\n"
    if task_id:
        user_query += f"Tâche parente : {task_id}\n"
    if prompt:
        user_query += f"Question / Stimulus : {prompt}\n\n"

    if targets:
        for idx, target in enumerate(targets, 1):
            target_path = os.path.join(REPO_ROOT, target) if not os.path.isabs(target) else target
            if os.path.exists(target_path):
                with open(target_path, "r", encoding="utf-8", errors="ignore") as f:
                    code_content = f.read()
                user_query += f"\n=== FICHIER SOURCE AUDITÉ ({idx}/{len(targets)}) : {target} ===\n{code_content}\n"
            else:
                print(f"[ATTENTION] Cible introuvable : {target}")

    # Contrôle overflow contexte (estimation 1 token ~= 3.5 caractères)
    total_chars = len(full_system) + len(user_query)
    approx_tokens = total_chars / 3.5
    if approx_tokens > (0.9 * DEFAULT_NUM_CTX):
        print(f"⚠️ [AVERTISSEMENT CONTEXTE] Taille estimée ~{int(approx_tokens)} tokens (num_ctx = {DEFAULT_NUM_CTX}). Risque de troncature !")

    # Génération automatique du chemin de sortie si --task est fourni sans --output
    if not output_file and task_id:
        task_folder = resolve_task_folder(task_id)
        now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        date_folder = datetime.datetime.now().strftime("%Y%m%d") + "_SESSION_SPECIALIST"
        preuves_dir = os.path.join(task_folder, "PREUVES", date_folder)
        os.makedirs(preuves_dir, exist_ok=True)
        output_file = os.path.join(preuves_dir, f"{task_id.upper()}_REVUE_{role.upper()}_{now_str}_v1.0.yaml")
        print(f"[AUTO-ROUTAGE T279] Sortie assignée : {output_file}")

    if output_file:
        validate_output_path(output_file)

    url = f"{OLLAMA_HOST}/api/generate"
    payload = {
        "model": model,
        "prompt": user_query,
        "system": full_system,
        "stream": False,
        "options": {"num_ctx": DEFAULT_NUM_CTX},
    }

    req_data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=req_data, headers={"Content-Type": "application/json"})

    print(f"\n[SPECIALIST] Sollicitation de {role.upper()} ({model})...")
    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=DEFAULT_TIMEOUT_S) as resp:
            elapsed_s = round(time.time() - start_time, 2)
            data = json.loads(resp.read().decode('utf-8'))
            response_text = data.get("response", "")
            done_reason = data.get("done_reason")
            if done_reason and done_reason != "stop":
                print(f"⚠️ [AVERTISSEMENT TRONCATURE] Génération terminée avec motif : '{done_reason}'")

            print(f"⏱️ Durée d'exécution : {elapsed_s}s | 🕒 Horodatage : {datetime.datetime.now().isoformat()}")

            if output_file:
                os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
                with open(output_file, "w", encoding="utf-8") as out:
                    out.write(response_text)
                print(f"✅ Résultat consigné dans : {output_file}")

            print(f"\n=== RESTITUTION EXPERT [{role.upper()}] ===")
            print(response_text)
            print("=" * 50 + "\n")

            # Validation du contrat YAML et code de sortie
            parsed, err = extract_and_validate_yaml(response_text)
            if err:
                print(f"⚠️ [AVERTISSEMENT CONTRAT] {err}")
                return 1

            verdict = parsed.get("_verdict", "")
            print(f"🎯 Verdict Spécialiste : {verdict}")
            if verdict == "BLOCK":
                print("🛑 [BLOQUANT] L'agent spécialiste a émis une objection de niveau BLOCK.")
                return 2
            elif verdict in ("PASS", "ADVISORY"):
                print("✅ [VALIDE] L'évaluation du spécialiste permet de poursuivre.")
                return 0
            else:
                print(f"⚠️ [VERDICT INCONNU] '{verdict}' n'est pas dans [PASS, ADVISORY, BLOCK].")
                return 1

    except urllib.error.URLError as e:
        print(f"\n[ERREUR RESEAU OLLAMA] Impossible de joindre le serveur Ollama sur {OLLAMA_HOST}.")
        print(f"Détail : {e}")
        print("💡 Conseils de dépannage :")
        print("  1. Vérifier qu'Ollama est démarré (`ollama serve` ou application en tâche de fond).")
        print("  2. Vérifier la variable d'environnement OLLAMA_HOST si le serveur est distant.")
        return 1
    except Exception as e:
        print(f"\n[ERREUR] Échec de consultation du spécialiste : {e}")
        return 1


def main():
    parser = argparse.ArgumentParser(description="Specialist Persona Runner")
    parser.add_argument("--role", "-r", choices=list(ROLE_MAP.keys()), help="Rôle spécialisé à invoquer")
    parser.add_argument("--target", "-t", nargs="+", help="Un ou plusieurs fichiers code/doc à auditer")
    parser.add_argument("--prompt", "-p", help="Consigne ou question d'expertise")
    parser.add_argument("--task", help="ID de la tâche active (ex: T429)")
    parser.add_argument("--output", "-o", help="Chemin du fichier de sortie")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Modèle LLM (défaut: {DEFAULT_MODEL})")
    parser.add_argument("--list-roles", "-l", action="store_true", help="Lister les spécialistes disponibles")
    parser.add_argument("--list-prompts", "-lp", action="store_true", help="Lister les fichiers prompts .md des personas")
    parser.add_argument("--show-prompt", "-sp", choices=list(ROLE_MAP.keys()), help="Afficher le prompt système d'un persona")

    args = parser.parse_args()

    # R15 (2026-11-13) : chaque invocation de persona est TRACEE (journal interne) ->
    # l usage reel des 6 agents specialises devient un fait, pas une impression.
    try:
        import os as _os, sys as _sys
        _scripts_dir = str(Path(__file__).resolve().parent)
        if _scripts_dir not in _sys.path:
            _sys.path.insert(0, _scripts_dir)
        import trace_log
        trace_log.emit("persona", role=args.role, target=args.target, task=args.task,
                       session=_os.environ.get("CLAUDE_CODE_SESSION_ID"),
                       prompt_len=len(args.prompt or ""))
    except Exception:
        pass

    if args.list_roles:
        list_roles()
        sys.exit(0)

    if args.list_prompts:
        list_prompts()
        sys.exit(0)

    if args.show_prompt:
        show_prompt(args.show_prompt)
        sys.exit(0)

    if not args.role:
        print("Erreur : --role requis (ex: --role safety). Tapez --list-roles pour voir la liste.")
        sys.exit(1)

    exit_code = query_specialist(role=args.role, targets=args.target, prompt=args.prompt,
                                 task_id=args.task, output_file=args.output, model=args.model)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
