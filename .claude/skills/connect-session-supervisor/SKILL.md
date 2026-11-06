---
name: connect-session-supervisor
description: Connecte explicitement la conversation CLI courante au Veilleur local.
user-invocable: true
disable-model-invocation: true
---

# Connecter cette session au Veilleur

Cette commande `/connect-session-supervisor` ne transmet aucun message à l’agent surveillé et ne crée aucune tâche.

1. Vérifie si une tâche formelle unique est identifiable dans le contexte ou le Task Manager. N’invente pas un ID, un verrou, un contrat ni un état. Si la tâche ou son support n’est pas vérifiable, dis-le en une phrase, rappelle le risque d’un travail sans cadrage et demande à l’utilisateur s’il confirme un suivi sans tâche formelle. Attends sa réponse avant d’appeler le script. Une session peut être surveillée sans tâche seulement après cette confirmation explicite.
2. Utilise l’identifiant natif exact de la conversation courante fourni par l’environnement Claude Code (`CLAUDE_CODE_SESSION_ID`) ou déjà présent dans les métadonnées fiables du runtime. Ne cherche jamais la session la plus récente. Refuse un identifiant `session_…` de claude.ai.
3. Demande un alias si aucun alias adapté n’est évident. Prépare une mission courte et fidèle au cadrage courant ; une seule session correspond à une seule tâche.
4. Depuis la racine du dépôt, appelle le client local avec PowerShell :

```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py --platform claude --alias "<alias>" --task "<ID et titre vérifiés, ou SANS TÂCHE FORMELLE après confirmation>" --mission "<mission courte>"
```

Le client lit `CLAUDE_CODE_SESSION_ID` dans l’environnement du shell d’outil. Si l’environnement ne le fournit pas, demande l’UUID exact à l’utilisateur et passe `--session-id "<UUID exact>"`.
Si l’utilisateur a confirmé le suivi sans tâche formelle, ajoute `--confirm-without-task` ; sinon, le script le refuse.
5. Ne réessaie pas en changeant d’ID si l’API refuse. Rapporte le résultat JSON, l’alias, l’ID exact et l’état (`attached`, `already_assigned` ou erreur). Une affectation en pause doit être reprise dans l’interface.

Le client n’accepte que l’API Veilleur locale `127.0.0.1:8082`, exige une source unique et n’envoie pas le transcript lors du rattachement. Le service lit ensuite uniquement les nouveaux événements. Le partage du texte avec un modèle reste contrôlé séparément par le réglage de consentement cloud.
