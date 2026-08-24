---
name: task-planner
description: Gestion et pilotage des tâches du projet (DOC/WFLOW/TASKS.yaml et CONTRACTS/). Déclencher dès que l'utilisateur ou un agent veut consulter, ajouter, verrouiller (lock), mettre à jour l'état (statut/horodatage), ou clore une tâche de développement. Assure la synchronisation avec Data Preview et garantit zéro écrasement.
---

# 🗂️ Skill Task-Planner — Gestionnaire du Catalogue des Tâches & Contrats

Cette skill encadre la prise en charge, la création, la mise à jour et la clôture des tâches du projet.
Elle garantit que les métadonnées (`TASKS.yaml`) et les contrats de tâche unitaires (`CONTRACTS/`) sont synchronisés avec une précision chirurgicale, sans écrasement de travail.

---

## 🚨 BANNIÈRE DE DÉCLENCHEMENT (OBLIGATOIRE)

Dès que la skill est invoquée par l'utilisateur ou par un agent, **afficher immédiatement ce bandeau visuel** :

```text
============================================================
🗂️ WORKFLOW TÂCHES / TASK-PLANNER ACTIF
============================================================
```

Puis afficher en 1 ligne l'action effectuée (ex. *« Prise en charge de la tâche T146 (C4) par l'agent AGY-01 »*).

> 📛 Format standard : `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md` (gabarit unique, 60 `=`).

---

## 🕒 RÈGLE D'OR : HORODATAGE UNIQUE & COMPACT (`date`)

Chaque tâche possède un champ unique **`date`** au format ISO 8601 `YYYY-MM-DDTHH:MM:SS` (ex: `2026-08-22T21:24:00`).

**Règle stricte pour tout agent ou humain** :
Dès qu'une tâche est manipulée (prise en charge `🔒`, mise à jour de statut, ou clôture `✅`), **le champ `date` DOIT être actualisé avec la date et l'heure courantes**.
- Cela permet un **tri chronologique immédiat** dans Data Preview pour voir les dernières activités.
- L'état d'avancement de la tâche est porté par la colonne **`statut`** (`🔒`, `⏳`, `✅`, `⬜`, `⏸️`, `❌`), sans multiplier les colonnes superflues. `❌` = **Annulée / Abandonnée** (décision de ne pas la réaliser, ou tâche devenue sans objet) — distinct de `✅` (réalisée) et de `⏸️` (différée/bloquée).


---

## 📝 STRUCTURE DES TÂCHES : DESCRIPTION vs OBJECTIFS TECHNIQUES

Pour maximiser l'efficacité de l'agent et la clarté dans Data Preview, chaque tâche distingue :

1. **`description` (Le "Pourquoi" & Contexte)** :
   - Explication en français clair du besoin métier, du comportement attendu ou du problème rencontré (contexte, antécédents, scénarios de fonctionnement).
2. **`objectifs` (Le "Quoi" Technique & Vérifiable)** :
   - Liste directe et compacte des livrables concrets :
     - 🧱 **Blocs / DUTs** : FBs créés ou modifiés (ex: `FB_Encoder`, `ST_EncoderHw`).
     - 🎯 **Variables / Conditions** : Règles logiques précises (ex: `Homed = TRUE`, `Enable=FALSE`).
     - 🛡️ **Critères d'acceptation / Gates** : Portails à valider (`G200`, `G315`, `Palier C`).

---

## 🌳 HIÉRARCHIE DES SOUS-TÂCHES (`parent_id`)

- Si une tâche est une sous-étape (ex: `T146-A`, `T146-P1`), renseigner obligatoirement `parent_id: "T146"`.
- **Règle Anti-Oubli avant Clôture** : Avant d'annoncer qu'une tâche parente est finie, l'agent **DOIT scanner** dans `TASKS.yaml` toutes les tâches ayant ce `parent_id` pour s'assurer qu'aucune sous-tâche n'est restée ouverte.

---

## 🛡️ SÉCURITÉ GIT & ISOLATION MULTI-AGENTS

1. **Interdiction de destruction** : Ne JAMAIS exécuter `git checkout .`, `git reset --hard` ou `git restore .` sans validation humaine explicite ET création d'un snapshot préalable (`git stash create`).
2. **Isolation par Worktree** : En mode multi-agents, travailler dans un worktree dédié sous `.worktrees/<agent-id>/` pour éviter les collisions d'index et de hooks.
3. **Contrat unitaire borné** : L'agent ne lit que son contrat sous `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_<id>.yaml`.
4. **Visualisation & Outils natifs (Zéro script jetable)** : La consultation de `TASKS.yaml` se fait en lecture seule via les outils natifs (`view_file`, `grep_search`, `TASK_VIEWER.html`). **Ne JAMAIS créer de script ou fichier temporaire jetable** (`_tmp_*.py`, `tmp.sh`) pour afficher ou manipuler les données.


---

## 🔄 SYNCHRONISATION AUTOMATIQUE

Après toute modification manuelle ou par script :
```bash
python TOOLS/AGENT_WORKFLOW/scripts/sync_tasks.py
```
Ce script garantit la fraîcheur du catalogue `TASKS.yaml` (pour Data Preview) et met à jour `PLAN_TASK.md`.
