#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🟢 OPENCODE-GO SUBAGENT RUNNER (endpoint OpenAI-compatible)
==========================================================
Meme role que ollama_subagent.py / omniroute_subagent.py, mais via la
passerelle OpenCode Zen "opencode-go" (endpoint OpenAI-compatible,
chat/completions + cle Bearer sk-...).

Provider (models.dev) :
  opencode-go  -> https://opencode.ai/zen/go/v1
  opencode     -> https://opencode.ai/zen/v1        (--base-url pour basculer)

Config (variables d'environnement, JAMAIS de cle en dur dans le repo) :
  OPENCODE_GO_BASE_URL   defaut : https://opencode.ai/zen/go/v1
  OPENCODE_GO_API_KEY    cle Bearer. Si absente, on lit
                         ~/.local/share/opencode/auth.json -> cle "opencode-go" puis "opencode".
  OPENCODE_GO_TIMEOUT_S  defaut : 300

Usage :
  export OPENCODE_GO_API_KEY=sk-...
  python TOOLS/AGENT_WORKFLOW/scripts/opencode_go_subagent.py --list-models
  python TOOLS/AGENT_WORKFLOW/scripts/opencode_go_subagent.py --file prompt.md --model hy3 --output rep.md
  python TOOLS/AGENT_WORKFLOW/scripts/opencode_go_subagent.py -p "ping" -m deepseek-v4-flash
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

sys.stdout.reconfigure(encoding="utf-8")

DEFAULT_BASE_URL = os.environ.get("OPENCODE_GO_BASE_URL", "https://opencode.ai/zen/go/v1").rstrip("/")
DEFAULT_MODEL = os.environ.get("OPENCODE_GO_MODEL", "hy3")
TIMEOUT_S = int(os.environ.get("OPENCODE_GO_TIMEOUT_S", "300"))
PREAMBLE_PATH = os.path.join(os.path.dirname(__file__), "..", "prompts", "subagent_preamble.md")
_AUTH_JSON = os.path.expanduser("~/.local/share/opencode/auth.json")


def _resolve_key() -> str:
    key = os.environ.get("OPENCODE_GO_API_KEY", "").strip()
    if key:
        return key
    try:
        with open(_AUTH_JSON, encoding="utf-8") as f:
            auth = json.load(f)
        for prov in ("opencode-go", "opencode"):
            entry = auth.get(prov) or {}
            if entry.get("type") == "api" and entry.get("key"):
                print(f"[opencode-go] cle chargee depuis {_AUTH_JSON} (provider '{prov}')")
                return entry["key"].strip()
    except FileNotFoundError:
        pass
    except Exception as e:  # noqa: BLE001
        print(f"[opencode-go] lecture {_AUTH_JSON} impossible : {e}")
    print("[ERREUR] Aucune cle : definir OPENCODE_GO_API_KEY ou faire `/connect` dans opencode.")
    sys.exit(2)


def _headers() -> dict:
    # UA obligatoire : sans lui, Cloudflare renvoie 403 "error code: 1010" (ban signature urllib).
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {_resolve_key()}",
        "User-Agent": os.environ.get("OPENCODE_GO_UA", "opencode/1.0"),
    }


def list_models(base_url: str) -> None:
    url = f"{base_url}/models"
    try:
        req = urllib.request.Request(url, headers=_headers())
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"[ERREUR] HTTP {e.code} sur {url} : {e.read().decode('utf-8', 'replace')[:600]}")
        sys.exit(1)
    except Exception as e:  # noqa: BLE001
        print(f"[ERREUR] Impossible de joindre {url} : {e}")
        sys.exit(1)
    print(f"=== Modeles opencode-go ({base_url}) ===")
    for m in data.get("data", data if isinstance(data, list) else []):
        mid = m.get("id") if isinstance(m, dict) else m
        extra = ""
        if isinstance(m, dict):
            price = m.get("pricing") or {}
            if price:
                extra = f"  (in {price.get('prompt', '?')} / out {price.get('completion', '?')})"
            if m.get("free") or str(mid).endswith(":free"):
                extra += "  [FREE]"
        print(f"  - {mid}{extra}")


def query(prompt, model, base_url, system_prompt=None, output_file=None, temperature=0.2):
    full_system = ""
    if os.path.exists(PREAMBLE_PATH):
        with open(PREAMBLE_PATH, encoding="utf-8") as f:
            full_system += f.read() + "\n\n"
    if system_prompt:
        full_system += system_prompt

    messages = []
    if full_system.strip():
        messages.append({"role": "system", "content": full_system})
    messages.append({"role": "user", "content": prompt})
    payload = {"model": model, "messages": messages, "stream": False, "temperature": temperature}

    url = f"{base_url}/chat/completions"
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=_headers())
    print(f"[opencode-go] modele '{model}' via {base_url} ({len(prompt)} car., timeout {TIMEOUT_S}s)...")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"[ERREUR] HTTP {e.code} : {e.read().decode('utf-8', 'replace')[:800]}")
        sys.exit(1)
    except Exception as e:  # noqa: BLE001
        print(f"[ERREUR] Execution opencode-go : {e}")
        sys.exit(1)

    choices = data.get("choices", [])
    text = choices[0].get("message", {}).get("content", "") if choices else ""
    usage = data.get("usage", {})
    if not text:
        print(f"[ERREUR] Reponse vide. Retour : {json.dumps(data)[:600]}")
        sys.exit(1)
    if output_file:
        os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
        with open(output_file, "w", encoding="utf-8") as out:
            out.write(text)
        print(f"[opencode-go] reponse enregistree : {output_file}")
    print("\n=== REPONSE SOUS-AGENT OPENCODE-GO ===")
    print(text)
    print("======================================")
    if usage:
        print(f"[usage] {usage}")
    return text


def main():
    p = argparse.ArgumentParser(description="opencode-go Subagent Runner (OpenAI-compatible)")
    p.add_argument("--prompt", "-p")
    p.add_argument("--file", "-f")
    p.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"defaut: {DEFAULT_MODEL}")
    p.add_argument("--system", "-s")
    p.add_argument("--output", "-o")
    p.add_argument("--base-url", "-b", default=DEFAULT_BASE_URL, help=f"defaut: {DEFAULT_BASE_URL}")
    p.add_argument("--temperature", "-t", type=float, default=0.2)
    p.add_argument("--list-models", "-l", action="store_true")
    args = p.parse_args()

    base_url = args.base_url.rstrip("/")
    if args.list_models:
        list_models(base_url)
        return

    if args.file:
        with open(args.file, encoding="utf-8") as f:
            prompt_text = f.read()
    elif args.prompt:
        prompt_text = args.prompt
    else:
        print("Erreur : --prompt '...' ou --file chemin.md (ou --list-models)")
        sys.exit(1)

    query(prompt_text, args.model, base_url, system_prompt=args.system,
          output_file=args.output, temperature=args.temperature)


if __name__ == "__main__":
    main()
