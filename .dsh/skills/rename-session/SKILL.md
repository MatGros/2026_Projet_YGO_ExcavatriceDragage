---
name: rename-session
description: Renomme robustement la session courante (alias machine, onglet terminal et notification Superviseur).
user-invocable: true
disable-model-invocation: true
---

# Renommer la session courante (DSH)

Cette commande `/rename-session` met à jour l'alias machine dans le Superviseur local, journalise l'opération en WAL dans `DOC/WFLOW/SESSION_RENAME_AUDIT.log` et met à jour le titre de l'onglet du terminal VS Code.

## Usage

`/rename-session <TXXX[-ACTEUR]> [Description]`

### Exemples
- `/rename-session T429-DSH01 Fiabilisation Superviseur`
- `/rename-session T423-DSH01`
- `/rename-session T000-DSH01 Exploration libre`

## Exécution

Depuis la racine du dépôt, appelle le script avec PowerShell :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/rename_session.py $args
```
