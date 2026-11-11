#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🛡️ SPECIALIST SUPERVISOR RUNNER — Passerelle Spécialistes & Superviseur
=====================================================================
Permet à l'agent superviseur (ou à l'opérateur via la commande /ask-specialist-supervisor)
d'interroger un persona spécialisé tout en préservant le contexte du Superviseur.

Rôles supportés :
  - safety    : FB_Agent_Safety (Sécurité machine ISO 13849, AU, anti-chute, mou de câble)
  - plc       : FB_Agent_PLC (Automatisme CODESYS, preuve couple frein, ordonnancement)
  - hmi       : FB_Agent_HMI (Ergonomie, bannières max 42 cars, zéro refus silencieux)
  - testing   : FB_Agent_Testing (Dualité +/- et hystérésis, syntaxe native STruCpp)
  - standards : FB_Agent_Standards (Norme T279, nomenclature, conformité outillage projet)
  - challenger: FB_Agent_Challenger (Arène dialectique, cadrage prompt, idées émergentes)

Usage :
  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --role safety --prompt "Le réarmement sur front montant est-il respecté ?" --target CODE/M_MAIN/PRG_04_Treuils_Benne.st
  py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --role standards --target CODE/M_MAIN/PRG_04_Treuils_Benne.st
"""

import argparse
import sys
import os

sys.stdout.reconfigure(encoding='utf-8')

# Import depuis le moteur canonique
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, REPO_ROOT)

from TOOLS.AGENT_WORKFLOW.scripts.specialist_runner import (
    query_specialist,
    list_roles,
    list_prompts,
    show_prompt,
    ROLE_MAP,
    DEFAULT_MODEL
)


def main():
    parser = argparse.ArgumentParser(description="Specialist Runner for Supervisor")
    parser.add_argument("--role", "-r", choices=list(ROLE_MAP.keys()), help="Rôle spécialisé à invoquer")
    parser.add_argument("--target", "-t", nargs="+", help="Fichier(s) source ou doc à auditer")
    parser.add_argument("--prompt", "-p", help="Consigne ou question d'expertise")
    parser.add_argument("--task", help="ID de la tâche active (ex: T429) pour auto-archivage T279")
    parser.add_argument("--output", "-o", help="Chemin du fichier de sortie")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Modèle LLM (défaut: {DEFAULT_MODEL})")
    parser.add_argument("--list-roles", "-l", action="store_true", help="Lister les spécialistes disponibles")
    parser.add_argument("--list-prompts", "-lp", action="store_true", help="Lister les prompts des spécialistes sous DOC/WFLOW/PROMPTS/SPECIALISTS/")
    parser.add_argument("--show-prompt", "-sp", choices=list(ROLE_MAP.keys()), help="Afficher le prompt d'un spécialiste")

    args = parser.parse_args()

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

    print(f"\n[SUPERVISOR] Invocateur Spécialiste : {args.role.upper()}")
    exit_code = query_specialist(role=args.role, targets=args.target, prompt=args.prompt,
                                 task_id=args.task, output_file=args.output, model=args.model)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
