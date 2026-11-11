#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🥊 CHALLENGE SUPERVISOR RUNNER — Passerelle Arène Dialectique & Superviseur
========================================================================
Permet au superviseur ou à l'opérateur de lancer un challenge technique contradictoire :
  Étape 0 : Challenge & Cadrage préalable du Prompt (Anti-Garbage-In)
  Étape 1 : Arène A (Innovation) vs B (Red Team & Risques Indirects Cachés)
  Étape 2 : Synthèse Arbitrée (Pépites, Pièges écartés, Plan d'action)

Usage :
  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/challenge_supervisor.py --prompt "Optimiser l'accélération chariot M3" --check-prompt
  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/challenge_supervisor.py --prompt "Asservir la benne au peson" --task T429
"""

import argparse
import sys
import os

sys.stdout.reconfigure(encoding='utf-8')

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, REPO_ROOT)

from TOOLS.AGENT_WORKFLOW.scripts.challenge_runner import (
    run_prompt_check,
    run_full_challenge,
    DEFAULT_MODEL
)


def main():
    parser = argparse.ArgumentParser(description="Challenger Runner for Supervisor")
    parser.add_argument("--prompt", "-p", required=True, help="Question, idée ou sujet soumis au challenge")
    parser.add_argument("--check-prompt", action="store_true", help="Étape 0 seule : Cadrer et challenger le prompt avant tout débat")
    parser.add_argument("--target", "-t", nargs="+", help="Fichier(s) source ou de spec en appui")
    parser.add_argument("--task", help="ID de la tâche active (ex: T429) pour auto-archivage T279")
    parser.add_argument("--output", "-o", help="Chemin du fichier de sortie")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Modèle LLM (défaut: {DEFAULT_MODEL})")

    args = parser.parse_args()

    print("\n[SUPERVISOR] Session de Challenge Dialectique")
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
