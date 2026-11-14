---
name: task-planner
description: Pilotage du catalogue DOC/WFLOW/TASKS.yaml, contrats et coordination multi-acteurs.
---

# Task-Planner — règle canonique

Le choix des modèles et le budget de sous-agents sont communs aux workflows projet et tâche :
`TOOLS/AGENT_WORKFLOW/docs/MODEL_ROUTING.md`. Cette référence ne remplace pas les droits et rôles
de coordination définis dans cette skill.

Au déclenchement, afficher :

```text
🗂️ WORKFLOW TÂCHES / TASK-PLANNER ACTIF
```

## Concepts strictement séparés

| Élément | Rôle |
|---|---|
| `statut` (`⬜`, `⏳`, `✅`, `⏸️`, `❌`) | avancement métier |
| 🔒 `work_locks` | tâche attribuée à un acteur jusqu'à sa remise |
| 🚩 `edit_flags` | édition temporaire d'une tâche précise |

## Protocole de responsabilité

Le catalogue global n'est pas un fichier de travail partagé par tous les agents. Pour chaque
mission, **un orchestrateur/coordinateur désigné** en est l'unique éditeur et pilote les verrous
globaux. Le registre d'orchestration est facultatif et réservé aux délégations longues ou suivis
qui apportent une information absente du catalogue/contrat. Il édite par l'IHM Task Manager ou ses
endpoints serveur existants, jamais par une modification directe du YAML.

- L'exécutant délégué ne s'attribue pas la tâche et ne modifie pas `TASKS.yaml`, `TASK_LOCKS.json`
  ni `TASKS_ORCHESTRATOR.yaml` par défaut. Il rend son état et ses preuves au coordinateur.
- Le reviewer/challenger est en lecture seule.
- Sans coordinateur désigné, ne pas modifier le suivi global : demander au responsable de nommer
  un coordinateur. L'absence d'orchestrateur ne donne pas automatiquement le droit d'écriture.
- Si le responsable de la tâche est lui-même l'unique agent actif, il peut tenir le rôle de
  coordinateur si ce rôle lui est explicitement attribué dans le brief.

## Protocole obligatoire pour le coordinateur avant toute écriture dans TASKS.yaml

1. Lire `DOC/WFLOW/TASK_LOCKS.json` et la tâche cible.
2. Si un 🚩 appartient à un autre acteur : **STOP**, aucune écriture.
3. Poser ou vérifier le 🔒 de travail si l'acteur prend réellement la tâche.
4. Poser le 🚩 d'édition avant l'écriture, avec son identité d'acteur.
5. Modifier uniquement la tâche ciblée, mettre à jour son champ `date` ISO 8601, puis relire la tâche.
6. Retirer le 🚩 dès la fin de l'édition, même en cas d'erreur.

Le 🔒 reste jusqu'à la remise réelle du travail. La RAZ IHM ne supprime que les 🚩.

`TOOLS/TASK_MANAGER/task_lock.py` est un client facultatif des opérations de verrou/flag ; il ne
valide pas les fiches et ne remplace pas l'enregistrement d'une tâche par l'IHM/API. Ne pas créer
de scripts de validation ou de prise en parallèle. Cette répartition des rôles est procédurale :
le serveur vérifie le flag d'édition et la révision, mais son endpoint de sauvegarde ne vérifie pas
que l'acteur détient le `work_lock`. Ne pas présenter le cadenas de travail comme un contrôle d'accès
technique. Ne jamais contourner un 🚩 d'un autre acteur.

## Règles catalogue

- Toute tâche manipulée actualise `date` au format `YYYY-MM-DDTHH:MM:SS`.
- Une sous-tâche possède `parent_id`; avant clôture du parent, vérifier ses enfants ouverts.
- Dès C2, le contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_<id>.yaml` est obligatoire (dispenses : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md` § Contrat de tâche).
- Commandes destructives : voir `AGENTS.md` § Discipline de session, règle 6 (liste unique).

## 🏷️ Nomenclature stricte du champ `agent`

Le champ `agent` dans `TASKS.yaml` (et `acteur` dans `TASK_LOCKS.json`) identifie formellement l'agent ou l'humain responsable.
**Les libellés longs, noms complets ou textes descriptifs sont strictement interdits** (pas de `"Claude"`, `"Codex"`, `"DSH (orchestrateur)"`...).

Format canonique : **Trigramme / Digramme + numéro d'instance à 2 chiffres** (ou `HUM`, ou `—`) :

| Identifiant | Rôle / Outil | Convention d'incrémentation |
|---|---|---|
| `CC01`, `CC02`, ... | **Claude Code** | `CC01` = session/orchestrateur principal, `CC02`+ = sous-agent ou session concurrente |
| `AGY01`, `AGY02`, ... | **Antigravity** | `AGY01` = session principale, `AGY02`+ = sous-agent |
| `CDX01`, `CDX02`, ... | **Codex** | `CDX01` = session principale, `CDX02`+ = sous-agent |
| `DSH01`, `DSH02`, ... | **DeepSeek / DSH** | `DSH01` = session principale, `DSH02`+ = sous-agent |
| `OPC01`, `OPC02`, ... | **OpenCode** | `OPC01` = session principale, `OPC02`+ = sous-agent |
| `HUM` | **Opérateur humain** | Tâches de test terrain, validation physique ou arbitrage exclusif |
| `—` | **Non assigné** | Tiret cadratin (`—`), valeur par défaut pour toute tâche libre |

- **Longueur maximale** : 6 caractères.
- **Regex de validation** : `^(CC|AGY|CDX|DSH|OPC)[0-9]{2}$|^HUM$|^—$`

