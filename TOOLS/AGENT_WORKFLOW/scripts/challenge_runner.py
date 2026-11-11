#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🥊 CHALLENGE RUNNER — Arène Dialectique, Idées Émergentes & Devil's Advocate
===========================================================================
Permet de soumettre une idée, un choix d'architecture ou un problème à un challenge
contradictoire structuré :
  Étape 0 : Challenge & Cadrage préalable du Prompt (Anti-Garbage-In)
  Étape 1 : Arène A (Innovateur / Proposant) vs B (Red Team / Risques Indirects)
  Étape 2 : Synthèse Arbitrée (Pépites Émergentes, Pièges Écartés, Décision Recommandée)

Usage :
  # 1. Vérifier et durcir le prompt d'abord :
  python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "Comment accélérer le cycle ?" --check-prompt

  # 2. Lancer le challenge complet :
  python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "Asservir l'ouverture de benne à la vitesse chariot" --target CODE/M_MAIN/PRG_05_Translation.st

  # 3. Intégré à une tâche (Archivage automatique T279) :
  python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "Refonte synchronisme treuils" --task T429
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
CHALLENGER_SPEC = os.path.join(os.path.dirname(__file__), "..", "specialists", "FB_Agent_Challenger.md")
PREAMBLE_PATH = os.path.join(os.path.dirname(__file__), "..", "prompts", "subagent_preamble.md")

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "deepseek-v4-flash:cloud"
DEFAULT_NUM_CTX = 16384
DEFAULT_TIMEOUT_S = 360


def validate_output_path(output_path: str):
    """Garde-fou mécanique Norme T279 & règle '1 tâche = 1 dossier'."""
    abs_path = os.path.abspath(output_path)
    try:
        rel = os.path.relpath(abs_path, REPO_ROOT).replace("\\", "/")
    except ValueError:
        rel = output_path.replace("\\", "/")

    t279_pattern = r"^DOC/WFLOW/TASKS/T[0-9]+[^/]*/(PREUVES|ARCHIVES)/.+"
    if not re.match(t279_pattern, rel, re.IGNORECASE):
        print("=" * 72)
        print(f"⛔ [BLOQUÉ NORME T279] Chemin de sortie non conforme : '{output_path}'")
        print("=" * 72)
        print("Règles obligatoires (AGENTS.md & STRUCTURE_AND_CLEANUP.md) :")
        print("  1. Interdit d'écrire des fichiers à la racine du dépôt ou dans DOC/WFLOW/.")
        print("  2. Règle '1 tâche = 1 dossier' : classer sous :")
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

    return os.path.join(tasks_dir, f"{clean_id}_CHALLENGE_REVIEW")


def extract_yaml_payload(response_text: str) -> tuple[dict | None, str]:
    """Extrait le bloc YAML challenge_evaluation."""
    yaml_match = re.search(r"```(?:ya?ml)?\s*(challenge_evaluation:.*?)```", response_text, re.DOTALL)
    raw_yaml = ""
    if yaml_match:
        raw_yaml = yaml_match.group(1).strip()
    else:
        direct_match = re.search(r"(challenge_evaluation:.*)", response_text, re.DOTALL)
        if direct_match:
            raw_yaml = direct_match.group(1).strip()

    if not raw_yaml:
        return None, "Bloc 'challenge_evaluation' non trouvé."

    try:
        parsed = yaml.safe_load(raw_yaml)
        if isinstance(parsed, dict) and "challenge_evaluation" in parsed:
            return parsed, ""
        return None, "Clé 'challenge_evaluation' manquante."
    except Exception as e:
        return None, f"Erreur de syntaxe YAML : {e}"


def run_prompt_check(prompt: str, targets: list[str] = None, model: str = DEFAULT_MODEL) -> str:
    """Étape 0 : Cadrage & Challenge du Prompt seul."""
    system_prompt = (
        "Tu es l'Arbitre Étape 0 de FB_Agent_Challenger. Ta mission est de CHALLENGER LE PROMPT avant tout débat.\n"
        "Règles strictes :\n"
        "1. Détecte les biais, postulats implicites non prouvés et présupposés dans la question posée.\n"
        "2. Reformule l'Objectif Mesurable précis (Target Goal).\n"
        "3. Définis les Non-Goals stricts (ce qu'il est interdit de dégrader ou de toucher).\n"
        "4. Indique les critères d'acceptation testables.\n"
        "5. Restitue sous forme TDAH-Friendly avec le bandeau 'CADRAGE & CHALLENGE DU PROMPT'. Sois concis, direct, percutant."
    )

    user_query = f"PROMPT SOUMIS AU CHALLENGE :\n« {prompt} »\n\n"
    if targets:
        for idx, target in enumerate(targets, 1):
            target_path = os.path.join(REPO_ROOT, target) if not os.path.isabs(target) else target
            if os.path.exists(target_path):
                with open(target_path, "r", encoding="utf-8", errors="ignore") as f:
                    user_query += f"=== CONTEXTE ({idx}/{len(targets)}) : {target} ===\n{f.read()[:4000]}\n\n"

    user_query += (
        "Livre ton analyse Étape 0 : Biais démasqués, Objectif recadré mesurable, Non-Goals, Critères de validation."
    )

    print("\n" + "=" * 72)
    print("🎯 ÉTAPE 0 : CHALLENGE & CADRAGE PRÉALABLE DU PROMPT (Anti-Garbage-In)")
    print("=" * 72)
    
    t0 = time.time()
    res = execute_llm_query(system_prompt, user_query, model)
    duration = time.time() - t0
    now_iso = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n⏱️ Durée exécution : {duration:.1f}s | 🕒 {now_iso}")
    return res


def run_full_challenge(prompt: str, targets: list[str] = None, task_id: str = None,
                       output_file: str = None, model: str = DEFAULT_MODEL) -> int:
    """Étape 0 + 1 + 2 : Débat dialectique A/B complet avec synthèse arbitrée."""
    # Charger la spec challenger
    spec_content = ""
    if os.path.exists(CHALLENGER_SPEC):
        with open(CHALLENGER_SPEC, "r", encoding="utf-8") as f:
            spec_content = f.read()

    full_system = f"{spec_content}\n\n"
    if os.path.exists(PREAMBLE_PATH):
        with open(PREAMBLE_PATH, "r", encoding="utf-8") as f:
            full_system += f.read() + "\n"

    user_query = f"DEMANDE DE CHALLENGE COMPLET :\n« {prompt} »\n\n"
    if task_id:
        user_query += f"Tâche associée : {task_id}\n"

    if targets:
        for idx, target in enumerate(targets, 1):
            target_path = os.path.join(REPO_ROOT, target) if not os.path.isabs(target) else target
            if os.path.exists(target_path):
                with open(target_path, "r", encoding="utf-8", errors="ignore") as f:
                    user_query += f"=== FICHIER CONTEXTE ({idx}/{len(targets)}) : {target} ===\n{f.read()[:6000]}\n\n"

    user_query += (
        "Exécute le protocole complet en 3 phases :\n"
        "1. Étape 0 : Recadrage du prompt, postulats implicites, objectif mesurable et Non-Goals.\n"
        "2. Étape 1 : Arène A vs B (Agent A = Innovation/Opportunité ; Agent B = Red Team/Risques indirects non évidents).\n"
        "3. Étape 2 : Synthèse décisionnelle de l'Arbitre C (Pépites validées, Pièges éliminés, Action recommandée).\n"
        "Termine obligatoirement par le bloc YAML 'challenge_evaluation' conforme à FB_Agent_Challenger.md."
    )

    # Auto-routage T279 si --task
    if not output_file and task_id:
        task_folder = resolve_task_folder(task_id)
        now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        date_folder = datetime.datetime.now().strftime("%Y%m%d") + "_SESSION_CHALLENGE"
        preuves_dir = os.path.join(task_folder, "PREUVES", date_folder)
        os.makedirs(preuves_dir, exist_ok=True)
        output_file = os.path.join(preuves_dir, f"{task_id.upper()}_CHALLENGE_{now_str}_v1.0.yaml")
        print(f"[AUTO-ROUTAGE T279] Sortie assignée : {output_file}")

    if output_file:
        validate_output_path(output_file)

    print("\n" + "=" * 72)
    print("🥊 LANCEMENT DU CHALLENGE TECHNIQUE (Cadrage ➔ A vs B ➔ Arbitrage C)")
    print("=" * 72)

    t0 = time.time()
    response_text = execute_llm_query(full_system, user_query, model)
    duration = time.time() - t0
    now_iso = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if not response_text:
        return 1

    print(f"\n⏱️ Durée exécution : {duration:.1f}s | 🕒 {now_iso}")

    if output_file:
        os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
        with open(output_file, "w", encoding="utf-8") as out:
            out.write(response_text)
        print(f"✅ Rapport de challenge consigné dans : {output_file}")

    print("\n=== RESTITUTION DU CHALLENGE ===")
    print(response_text)
    print("=" * 72 + "\n")

    parsed, err = extract_yaml_payload(response_text)
    if err:
        print(f"⚠️ [AVERTISSEMENT YAML] {err}")
        return 0

    verdict = parsed.get("challenge_evaluation", {}).get("verdict", "PASS")
    print(f"🎯 Verdict Arbitre : {verdict}")
    if verdict == "BLOCK":
        return 2
    return 0


def execute_llm_query(system: str, prompt: str, model: str) -> str:
    """Envoie la requête à Ollama avec contrôle de débordement."""
    total_chars = len(system) + len(prompt)
    approx_tokens = total_chars / 3.5
    if approx_tokens > (0.9 * DEFAULT_NUM_CTX):
        print(f"⚠️ [AVERTISSEMENT CONTEXTE] Taille estimée ~{int(approx_tokens)} tokens (num_ctx = {DEFAULT_NUM_CTX}). Risque de troncature !")

    url = f"{OLLAMA_HOST}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "options": {"num_ctx": DEFAULT_NUM_CTX},
    }

    req_data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=req_data, headers={"Content-Type": "application/json"})

    print(f"[CHALLENGER] Consultation modèle ({model})...")
    try:
        with urllib.request.urlopen(req, timeout=DEFAULT_TIMEOUT_S) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            response_text = data.get("response", "")
            done_reason = data.get("done_reason")
            if done_reason and done_reason != "stop":
                print(f"⚠️ [AVERTISSEMENT TRONCATURE] Génération terminée avec motif : '{done_reason}'")
            return response_text
    except urllib.error.URLError as e:
        print(f"\n[ERREUR RESEAU OLLAMA] Impossible de joindre le serveur Ollama sur {OLLAMA_HOST}.")
        print(f"Détail : {e}")
        print("💡 Vérifiez qu'Ollama est actif (`ollama serve`).")
        return ""
    except Exception as e:
        print(f"\n[ERREUR] Échec du challenge : {e}")
        return ""


def main():
    parser = argparse.ArgumentParser(description="Challenger Dialectic & Devil's Advocate Runner")
    parser.add_argument("--prompt", "-p", required=True, help="Question, idée ou sujet soumis au challenge")
    parser.add_argument("--check-prompt", action="store_true", help="Étape 0 seule : Cadrer et challenger le prompt avant tout débat")
    parser.add_argument("--target", "-t", nargs="+", help="Fichier(s) source ou de spec en appui")
    parser.add_argument("--task", help="ID de la tâche active (ex: T429) pour auto-archivage T279")
    parser.add_argument("--output", "-o", help="Chemin du fichier de sortie")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Modèle LLM (défaut: {DEFAULT_MODEL})")

    args = parser.parse_args()

    if args.check_prompt:
        res = run_prompt_check(prompt=args.prompt, targets=args.target, model=args.model)
        if res:
            print(res)
            sys.exit(0)
        sys.exit(1)

    exit_code = run_full_challenge(prompt=args.prompt, targets=args.target, task_id=args.task,
                                   output_file=args.output, model=args.model)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
