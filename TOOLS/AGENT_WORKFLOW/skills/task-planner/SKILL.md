---
name: task-planner
description: Pilotage du catalogue DOC/WFLOW/TASKS.yaml, contrats et coordination multi-acteurs.
---

# Task-Planner — règle canonique

Au déclenchement, afficher :

```text
============================================================
🗂️ WORKFLOW TÂCHES / TASK-PLANNER ACTIF
============================================================
```

## Concepts strictement séparés

| Élément | Rôle |
|---|---|
| `statut` (`⬜`, `⏳`, `✅`, `⏸️`, `❌`) | avancement métier |
| 🔒 `work_locks` | tâche attribuée à un acteur jusqu'à sa remise |
| 🚩 `edit_flags` | édition temporaire d'une tâche précise |

## Protocole obligatoire avant toute écriture dans TASKS.yaml

1. Lire `DOC/WFLOW/TASK_LOCKS.json` et la tâche cible.
2. Si un 🚩 appartient à un autre acteur : **STOP**, aucune écriture.
3. Poser ou vérifier le 🔒 de travail si l'acteur prend réellement la tâche.
4. Poser le 🚩 d'édition avant l'écriture, avec son identité d'acteur.
5. Modifier uniquement la tâche ciblée, mettre à jour son champ `date` ISO 8601, puis relire la tâche.
6. Retirer le 🚩 dès la fin de l'édition, même en cas d'erreur.

Le 🔒 reste jusqu'à la remise réelle du travail. La RAZ IHM ne supprime que les 🚩.

Les commandes et outils éventuels sont optionnels : la procédure prime. L'agent ne contourne jamais un 🚩 déjà posé par un autre acteur.

## Règles catalogue

- Toute tâche manipulée actualise `date` au format `YYYY-MM-DDTHH:MM:SS`.
- Une sous-tâche possède `parent_id`; avant clôture du parent, vérifier ses enfants ouverts.
- Dès C2, le contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_<id>.yaml` est obligatoire.
- Ne jamais utiliser `git reset --hard`, `git checkout .` ou `git restore .` sans validation humaine explicite et snapshot préalable.
