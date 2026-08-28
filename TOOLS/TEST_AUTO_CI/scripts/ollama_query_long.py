#!/usr/bin/env python3
"""Requête Ollama à timeout long — contournement du runner standard.

`ollama_subagent.py` (TOOLS/AGENT_WORKFLOW) impose timeout=180s codé en dur : un modèle
lourd (qwen3.8:27b) chargé et générant une réponse d'audit structurée dépasse ce budget.
Ce wrapper (zone TEST_AUTO_CI) rejoue la MÊME chaîne de délégation — preamble injecté,
modèle local, zéro quota cloud — avec un timeout configurable.

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/ollama_query_long.py \
        --file PROMPT.md --model qwen3.8:27b --output REPONSE.md [--timeout 900]
    python TOOLS/TEST_AUTO_CI/scripts/ollama_query_long.py --list-models
"""

import argparse
import json
import os
import pathlib
import sys
import urllib.request

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
PREAMBLE = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "prompts" / "subagent_preamble.md"
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", "-f", help="Fichier markdown contenant le prompt")
    parser.add_argument("--prompt", "-p", help="Prompt en ligne")
    parser.add_argument("--model", "-m", default="deepseek-v4-flash:cloud")
    parser.add_argument("--output", "-o", help="Fichier de sortie de la réponse")
    parser.add_argument("--timeout", type=int, default=900,
                        help="Timeout génération en secondes (défaut 900)")
    parser.add_argument("--num-predict", type=int, default=2048,
                        help="Budget de tokens de génération (défaut 2048)")
    parser.add_argument("--num-ctx", type=int, default=8192,
                        help="Fenêtre de contexte tokens (défaut 8192 — le défaut Ollama tronque le prompt)")
    parser.add_argument("--list-models", action="store_true")
    args = parser.parse_args()

    try:
        req = urllib.request.Request(f"{OLLAMA_HOST}/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            models = [m.get("name") for m in json.loads(resp.read().decode("utf-8")).get("models", [])]
        if args.list_models:
            print("=== Modèles Ollama disponibles ===")
            for m in models:
                print(f"  • {m}")
            return 0
    except Exception as exc:
        print(f"[ERREUR] Impossible de joindre Ollama sur {OLLAMA_HOST} : {exc}")
        return 1

    if args.file:
        prompt_text = pathlib.Path(args.file).read_text(encoding="utf-8")
    elif args.prompt:
        prompt_text = args.prompt
    else:
        print("[ERREUR] fournir --file ou --prompt")
        return 1

    full_system = ""
    if PREAMBLE.exists():
        full_system = PREAMBLE.read_text(encoding="utf-8") + "\n\n"

    payload = {
        "model": args.model,
        "prompt": prompt_text,
        "system": full_system,
        "stream": False,
        "keep_alive": "30m",
        # Réponses d'audit structurées longues : le défaut Ollama (~128 tokens) tronque
        # en pleine phrase — fixé ici, et documenté comme limite du runner standard.
        # num_ctx : le défaut (~4k tokens) TRONQUE LE PROMPT en entrée (11.7 KB d'audit
        # ≈ 3.5-4.5k tokens) — le modèle "ne voit pas" le cahier des charges. 8192 minimum.
        "options": {"num_predict": args.num_predict, "num_ctx": args.num_ctx, "temperature": 0.2},
    }
    print(f"[OLLAMA-LONG] modèle='{args.model}' prompt={len(prompt_text)} chars · timeout={args.timeout}s · num_predict={args.num_predict} · num_ctx={args.num_ctx}")
    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        response_text = data.get("response", "")
        if not response_text.strip():
            print("[ERREUR] Réponse vide du modèle")
            return 1
        if args.output:
            pathlib.Path(args.output).write_text(response_text, encoding="utf-8")
            print(f"[OK] Réponse ({len(response_text)} chars) -> {args.output}")
        else:
            print(response_text)
        return 0
    except Exception as exc:
        print(f"[ERREUR] Exécution Ollama : {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())