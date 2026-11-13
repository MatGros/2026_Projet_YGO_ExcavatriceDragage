---
name: rename-session
description: Renomme la session courante avec vérification du Superviseur et des titres natifs disponibles.
user-invocable: true
disable-model-invocation: true
---

# Renommer la session courante (DSH)

Cette commande `/rename-session` met à jour l'alias et le titre lisible d'une session déjà reliée au Superviseur, puis journalise le résultat. Elle ne crée jamais de liaison : si la session n'est pas reliée, elle s'arrête sans modifier les autres titres. Lance `/connect-session-supervisor` séparément, puis réessaie.

Le script ne garantit pas que l'onglet terminal VS Code a changé : il indique une demande de titre, et l'affichage doit être vérifié dans VS Code. Ne pas annoncer que l'onglet est à jour sans observation.

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
