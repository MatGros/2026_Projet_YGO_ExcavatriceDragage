"""
sync_tasks.py — Synchronisation & Gestionnaire du Catalogue TASKS.yaml

Rôles :
1. Centralise et normalise toutes les tâches dans DOC/WFLOW/TASKS.yaml (compatible Data Preview).
2. Fournit une vue tableur instantanée, filtrable, triable et modifiable.
3. Lie automatiquement les contrats unitaires dans DOC/WFLOW/CONTRACTS/*.yaml.
"""

import os
import re
import sys
import yaml
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
WFLOW_DIR = BASE_DIR / "DOC" / "WFLOW"
CONTRACTS_DIR = WFLOW_DIR / "CONTRACTS"
TASKS_YAML = WFLOW_DIR / "TASKS.yaml"
PLAN_TASK_MD = WFLOW_DIR / "PLAN_TASK.md"


def parse_plan_task_md(md_path: Path):
    """Extrait fidèlement toutes les tâches du document Markdown."""
    if not md_path.exists():
        return []

    with open(md_path, "r", encoding="utf-8") as f:
        text = f.read()

    tasks = []
    seen = set()

    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|") or "---" in line or "| Ordre |" in line or "| Sous-tâche |" in line or "| #" in line:
            continue
        cols = [c.strip() for c in line.split("|")[1:-1]]
        if not cols:
            continue

        col0 = cols[0].replace("*", "").strip()
        if re.match(r"^T\d+", col0):
            t_id = col0
            if t_id in seen:
                continue
            seen.add(t_id)

            if len(cols) == 6:
                # | Txx | Titre | Domaine | Statut | Lock Agent | Détails |
                titre = cols[1].replace("**", "").replace("`", "")
                domaine = cols[2].replace("`", "")
                statut = cols[3].replace("`", "")
                agent = cols[4].replace("`", "")
                desc = cols[5].replace("`", "")
            elif len(cols) == 7:
                # | T122-A | Phase 1 | Description | Contrat | Statut | Lock | Valid |
                titre = f"{cols[1]} — {cols[2]}".replace("**", "").replace("`", "")
                domaine = "Refactor"
                statut = cols[4].replace("`", "")
                agent = cols[5].replace("`", "")
                desc = f"Contrat: {cols[3]} | Valid: {cols[6]}".replace("`", "")
            else:
                continue

            # Détection de criticité
            criticite = "C2"
            if "C4" in titre or "C4" in desc or "Sécurité" in domaine or "AU" in titre:
                criticite = "C4"
            elif "C3" in titre or "C3" in desc:
                criticite = "C3"
            elif "C1" in titre or "Doc" in domaine or "Convention" in domaine or "Commentaires" in titre:
                criticite = "C1"

            # Recherche d'un contrat associé existant
            contrat_rel = ""
            for contract_file in CONTRACTS_DIR.glob(f"*{t_id}*.yaml"):
                contrat_rel = f"DOC/WFLOW/CONTRACTS/{contract_file.name}"
                break

            # Détection de parent_id pour hiérarchie parent / enfant
            parent_id = ""
            if "-" in t_id:
                # Ex: T122-A -> parent T122, T146-P1 -> parent T146
                parent_id = t_id.split("-")[0]
            elif "." in t_id:
                parent_id = t_id.split(".")[0]

            # Horodatage ISO 8601 étendu (reconnu automatiquement par Data Preview)
            # YYYY-MM-DDTHH:MM:SS
            now_iso = "2026-08-22T21:05:00"
            locked_at = now_iso if agent and agent != "—" else ""
            completed_at = now_iso if statut == "✅" else ""

            tasks.append({
                "id": t_id,
                "parent_id": parent_id,
                "titre": titre,
                "domaine": domaine,
                "criticite": criticite,
                "statut": statut,
                "agent": agent,
                "locked_at": locked_at,
                "updated_at": now_iso,
                "completed_at": completed_at,
                "bloque_par": [],
                "contrat": contrat_rel,
                "description": desc
            })


    return tasks


def save_tasks_yaml(tasks, output_path: Path):
    """Sauvegarde le catalogue normalisé pour Data Preview."""
    header = (
        "# ==============================================================================\n"
        "# 🗂️ CATALOGUE OFFICIEL DES TÂCHES — PROJET EXCAVATRICE DE DRAGAGE\n"
        "# ==============================================================================\n"
        "# Compatible extension VS Code 'Data Preview' (Random Fractals Inc.)\n"
        "# Visualisation : Clic-droit sur ce fichier -> 'Data Preview' ou icône grille.\n\n"
    )
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(header)
        yaml.dump(tasks, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def main():
    print("=" * 60)
    print("🔄 GÉNÉRATION DU CATALOGUE OFFICIEL (TASKS.yaml)")
    print("=" * 60)

    tasks = parse_plan_task_md(PLAN_TASK_MD)
    save_tasks_yaml(tasks, TASKS_YAML)
    print(f"✅ {len(tasks)} tâches structurées exportées avec succès dans :")
    print(f"   {TASKS_YAML}")
    print("\n💡 Ouvrez le fichier avec 'Data Preview' pour profiter de la grille de gestion.")


if __name__ == "__main__":
    main()
