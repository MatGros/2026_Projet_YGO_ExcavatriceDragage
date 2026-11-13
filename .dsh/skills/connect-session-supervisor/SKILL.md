---
name: connect-session-supervisor
description: Rattache explicitement la session CLI courante au Superviseur local avec tâche, agent et titre vérifiés.
user-invocable: true
disable-model-invocation: true
---

# Connecter cette session au Superviseur

Cette commande rattache une session existante au Superviseur local. Elle n'envoie aucun message à l'agent surveillé et ne crée pas de tâche dans le Task Manager.

## Champs obligatoires

1. **ID natif exact** de la conversation courante. Utilise seulement les métadonnées fiables du runtime ou l'ID fourni par l'utilisateur. Ne cherche jamais la session la plus récente et ne confonds pas ID de conversation et ID agent.
2. **ID tâche** `T###` et **ID agent de session** encodé dans l'alias canonique, par exemple `T427-CC02`. La partie tâche de l'alias doit être identique à `--task`. L'ID agent de session est distinct du champ agent propriétaire de la tâche dans `TASKS.yaml`.
3. **Titre lisible** : pour une tâche formelle, le script le résout depuis `TASKS.yaml` et refuse si la tâche ou son titre est absent ou ambigu. Pour `T000`, fournir `--task-title`. `--mission` est le contexte de travail et ne remplace jamais le titre.

Si l'utilisateur confirme un suivi sans tâche formelle, utiliser l'alias `T000-<AGENT>`, `--task "SANS TACHE FORMELLE"`, un `--task-title` explicite et `--confirm-without-task`. La liaison sera enregistrée sous l'identifiant provisoire `T000`.

Si la même session native est déjà reliée avec une tâche, un agent ou un titre différent, ne réattribue rien silencieusement. Pour une affectation de tâche portée par une autre session, demande confirmation avant `--reassign`.

## Exécution

Depuis la racine du dépôt, utilise le client local :

```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py --platform <claude|codex|agy|dsh> --session-id "<ID natif exact>" --alias "<T427-CC02>" --task "T427" --mission "<contexte court>" [--reassign]
```

Pour une session T000, ajoute `--task-title "<titre lisible explicite>"`.
Pour un suivi confirmé sans tâche formelle, ajoute aussi `--task-title "<titre lisible>" --confirm-without-task` et utilise `--task "SANS TACHE FORMELLE"` avec un alias `T000-<AGENT>`.

Dans Codex, cette skill projet se trouve sous `.agents/skills/`. Elle peut être invoquée avec `$connect-session-supervisor` ou depuis `/skills` ; ne présume pas qu'un alias slash personnalisé existe.

Ne réessaie pas avec un autre ID si l'API refuse. Rapporte le JSON de résultat, l'ID natif exact, l'ID tâche, l'ID agent, le titre et l'état (`attached`, `already_assigned`, `reassigned` ou erreur). Une affectation en pause doit être reprise dans l'interface.

Le client n'accepte que l'API locale `127.0.0.1:8082`, exige une source unique et n'envoie pas le transcript lors du rattachement. Le service lit ensuite uniquement les nouveaux événements. Le partage du texte avec un modèle est régi par le réglage de consentement cloud.
