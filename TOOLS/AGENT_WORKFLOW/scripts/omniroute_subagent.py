#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🌐 OMNIROUTE SUBAGENT RUNNER (fallback endpoint OpenAI-compatible)
================================================================
Meme role que ollama_subagent.py, mais via un endpoint OpenAI-compatible
(chat/completions + cle Bearer). A utiliser quand l'endpoint natif Ollama
(/api/generate) echoue ou timeout.

Config (variables d'environnement, JAMAIS en dur dans le repo) :
  OMNIROUTE_BASE_URL   defaut : http://localhost:20128/v1  (gateway omniroute pi-ai ; voir DSH_PROVIDERS.md)
  OMNIROUTE_API_KEY    OBLIGATOIRE (cle Bearer)
  OMNIROUTE_TIMEOUT_S  defaut : 300

Usage :
  set OMNIROUTE_API_KEY=sk-...
  python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --file prompt.md --model auto/best-reasoning --output rep.md
  python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --list-models

Modeles VIABLES sur gros prompt (matrice 2026-08-28, voir DSH_PROVIDERS.md) :
  auto/best-reasoning (defaut, ~15s), auto/best-coding, auto/best-fast,
  codex/gpt-5.6-terra-medium (~90s), codex/gpt-5.6-sol-medium (~140s).
  NE PAS utiliser : *-high / *-max, ollamacloud/*, claude/claude-sonnet-5 via omniroute -> timeout sur prompt lourd.
Fallback : si l'endpoint natif Ollama (ollama_subagent.py, /api/generate) echoue/timeout.
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = os.environ.get("OMNIROUTE_BASE_URL", "http://localhost:20128/v1").rstrip("/")
API_KEY = os.environ.get("OMNIROUTE_API_KEY", "")
DEFAULT_MODEL = "auto/best-reasoning"
TIMEOUT_S = int(os.environ.get("OMNIROUTE_TIMEOUT_S", "300"))
PREAMBLE_PATH = os.path.join(os.path.dirname(__file__), "..", "prompts", "subagent_preamble.md")


def _headers():
    if not API_KEY:
        print("[ERREUR] OMNIROUTE_API_KEY non definie (variable d'environnement).")
        sys.exit(2)
    return {"Content-Type": "application/json", "Authorization": f"Bearer {API_KEY}"}


def list_models():
    url = f"{BASE_URL}/models"
    try:
        req = urllib.request.Request(url, headers=_headers())
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print("=== Modeles OmniRoute disponibles ===")
            for m in data.get("data", []):
                print(f"  - {m.get('id')}")
    except Exception as e:
        print(f"[ERREUR] Impossible de joindre {url} : {e}")
        sys.exit(1)


def query(prompt, model=DEFAULT_MODEL, system_prompt=None, output_file=None):
    full_system = ""
    if os.path.exists(PREAMBLE_PATH):
        with open(PREAMBLE_PATH, "r", encoding="utf-8") as f:
            full_system += f.read() + "\n\n"
    if system_prompt:
        full_system += system_prompt

    url = f"{BASE_URL}/chat/completions"
    messages = []
    if full_system.strip():
        messages.append({"role": "system", "content": full_system})
    messages.append({"role": "user", "content": prompt})
    payload = {"model": model, "messages": messages, "stream": False, "temperature": 0.2}

    req_data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=req_data, headers=_headers())

    print(f"[OMNIROUTE] Requete modele '{model}' via {BASE_URL} ({len(prompt)} caracteres, timeout {TIMEOUT_S}s)...")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        choices = data.get("choices", [])
        text = choices[0].get("message", {}).get("content", "") if choices else ""
        if not text:
            print(f"[ERREUR] Reponse vide. Payload retour : {json.dumps(data)[:500]}")
            sys.exit(1)
        if output_file:
            os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
            with open(output_file, "w", encoding="utf-8") as out:
                out.write(text)
            print(f"[OMNIROUTE] Reponse enregistree : {output_file}")
        print("\n=== REPONSE SOUS-AGENT OMNIROUTE ===")
        print(text)
        print("====================================\n")
        return text
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', 'replace')[:800]
        print(f"[ERREUR] HTTP {e.code} : {body}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERREUR] Execution OmniRoute : {e}")
        sys.exit(1)


def main():
    p = argparse.ArgumentParser(description="OmniRoute Subagent Runner (fallback OpenAI-compatible)")
    p.add_argument("--prompt", "-p")
    p.add_argument("--file", "-f")
    p.add_argument("--model", "-m", default=DEFAULT_MODEL)
    p.add_argument("--system", "-s")
    p.add_argument("--output", "-o")
    p.add_argument("--list-models", "-l", action="store_true")
    args = p.parse_args()

    if args.list_models:
        list_models()
        return

    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            prompt_text = f.read()
    elif args.prompt:
        prompt_text = args.prompt
    else:
        print("Erreur : --prompt '...' ou --file chemin.md")
        sys.exit(1)

    query(prompt=prompt_text, model=args.model, system_prompt=args.system, output_file=args.output)


if __name__ == "__main__":
    main()
