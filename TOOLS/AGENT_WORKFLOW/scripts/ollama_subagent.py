#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🤖 OLLAMA SUBAGENT RUNNER
=========================
Délégation de réflexion, audit, challenge ou génération de code vers les modèles locaux Ollama
sans consommer de quota cloud.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py --prompt "Ton prompt"
  python TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py --file chemin/vers/prompt.md --model deepseek-v4-flash:cloud
  python TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py --list-models
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

sys.stdout.reconfigure(encoding='utf-8')

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "deepseek-v4-flash:cloud"
# num_ctx par defaut d'Ollama ~= 4k tokens : il TRONQUE SILENCIEUSEMENT le prompt d'entree (REX 2026-08-28
# B3). Fenetre par defaut relevee a 8192 ; ajuster --num-ctx pour un gros contrat/diff.
DEFAULT_NUM_CTX = int(os.environ.get("OLLAMA_NUM_CTX", "8192"))
DEFAULT_NUM_PREDICT = int(os.environ.get("OLLAMA_NUM_PREDICT", "-1"))   # -1 = remplit le contexte restant (B2)
DEFAULT_TIMEOUT_S = int(os.environ.get("OLLAMA_TIMEOUT_S", "300"))       # B1
PREAMBLE_PATH = os.path.join(os.path.dirname(__file__), "..", "prompts", "subagent_preamble.md")


def list_models():
    url = f"{OLLAMA_HOST}/api/tags"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            models = data.get("models", [])
            print("=== Modèles Ollama disponibles ===")
            for m in models:
                name = m.get("name")
                size = m.get("size", 0) / (1024 * 1024 * 1024)
                print(f"  • {name:<30} ({size:.1f} GB)")
    except Exception as e:
        print(f"[ERREUR] Impossible de joindre Ollama sur {url} : {e}")


def query_ollama(prompt, model=DEFAULT_MODEL, system_prompt=None, output_file=None,
                 num_ctx=DEFAULT_NUM_CTX, num_predict=DEFAULT_NUM_PREDICT, timeout_s=DEFAULT_TIMEOUT_S):
    full_system = ""
    if os.path.exists(PREAMBLE_PATH):
        with open(PREAMBLE_PATH, "r", encoding="utf-8") as f:
            full_system += f.read() + "\n\n"

    if system_prompt:
        full_system += system_prompt

    url = f"{OLLAMA_HOST}/api/generate"
    options = {"num_ctx": num_ctx}
    if num_predict and num_predict > 0:
        options["num_predict"] = num_predict
    payload = {
        "model": model,
        "prompt": prompt,
        "system": full_system,
        "stream": False,
        "options": options,
    }

    # Garde-fou troncature silencieuse : ~4 caracteres/token. Si l'entree depasse ~90% de num_ctx,
    # une partie du prompt sera perdue cote Ollama -> avertir et suggerer --num-ctx.
    approx_in_tokens = (len(prompt) + len(full_system)) // 4
    if approx_in_tokens > int(num_ctx * 0.9):
        print(f"[ATTENTION] Entree ~{approx_in_tokens} tokens > 90% de num_ctx ({num_ctx}) : "
              f"risque de TRONCATURE du prompt. Relancer avec --num-ctx {((approx_in_tokens // 2048) + 2) * 2048}.")

    req_data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=req_data, headers={"Content-Type": "application/json"})

    print(f"[OLLAMA] Envoi de la requête au modèle '{model}' ({len(prompt)} caractères, "
          f"num_ctx={num_ctx}, timeout={timeout_s}s)...")
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            response_text = data.get("response", "")
            
            if output_file:
                os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
                with open(output_file, "w", encoding="utf-8") as out:
                    out.write(response_text)
                print(f"[OLLAMA] Réponse enregistrée dans : {output_file}")
            
            print("\n=== RÉPONSE DU SOUS-AGENT OLLAMA ===")
            print(response_text)
            print("=====================================\n")
            return response_text
    except urllib.error.URLError as e:
        print(f"[ERREUR] Échec de connexion à Ollama : {e}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERREUR] Exécution Ollama : {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Ollama Subagent Runner")
    parser.add_argument("--prompt", "-p", help="Texte du prompt à envoyer")
    parser.add_argument("--file", "-f", help="Fichier markdown contenant le prompt")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Modèle Ollama (défaut: {DEFAULT_MODEL})")
    parser.add_argument("--system", "-s", help="Prompt système additionnel")
    parser.add_argument("--output", "-o", help="Fichier de sortie où enregistrer la réponse")
    parser.add_argument("--list-models", "-l", action="store_true", help="Lister les modèles Ollama installés")
    parser.add_argument("--num-ctx", type=int, default=DEFAULT_NUM_CTX,
                        help=f"Fenêtre de contexte Ollama (défaut {DEFAULT_NUM_CTX} ; le défaut Ollama ~4k tronque le prompt)")
    parser.add_argument("--num-predict", type=int, default=DEFAULT_NUM_PREDICT,
                        help="Longueur max de sortie (-1 = remplit le contexte restant)")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S, help=f"Timeout requête en s (défaut {DEFAULT_TIMEOUT_S})")

    args = parser.parse_args()
    
    if args.list_models:
        list_models()
        return
        
    prompt_text = ""
    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            prompt_text = f.read()
    elif args.prompt:
        prompt_text = args.prompt
    else:
        print("Erreur : Spécifiez --prompt '...' ou --file chemin/vers/fichier.md")
        sys.exit(1)
        
    query_ollama(prompt=prompt_text, model=args.model, system_prompt=args.system, output_file=args.output,
                 num_ctx=args.num_ctx, num_predict=args.num_predict, timeout_s=args.timeout)


if __name__ == "__main__":
    main()
