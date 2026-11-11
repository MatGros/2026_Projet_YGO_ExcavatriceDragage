---
name: connect-session-supervisor
description: Connecte explicitement la conversation DSH courante au Superviseur local.
user-invocable: true
disable-model-invocation: true
---

# Connecter cette session au Superviseur

Cette commande `/connect-session-supervisor` ne transmet aucun message à l’agent surveillé et ne crée aucune tâche.

1. Vérifie si une tâche formelle unique est identifiable dans le contexte ou le Task Manager. N’invente pas un ID, un verrou, un contrat ni un état. Si la tâche ou son support n’est pas vérifiable, dis-le en une phrase, rappelle le risque d’un travail sans cadrage et demande à l’utilisateur s’il confirme un suivi sans tâche formelle. Attends sa réponse avant d’appeler le script. Une session peut être surveillée sans tâche seulement après cette confirmation explicite.
2. Utilise l’identifiant exact fourni par l’environnement du shell DSH (`DSH_SESSION_ID`). N’utilise pas `DSH_SESSION_JSONL` comme identité ; c’est seulement un chemin. Ne cherche jamais la session la plus récente.
3. L'alias DOIT respecter strictement la convention canonique : `TXXX[-X]-AGENT Désignation courte` (ex: `T429-DSH01 Fiabilisation Superviseur`, `T428-1-DSH01 Cartes de flux`). Prépare une mission courte et fidèle au cadrage courant ; une seule session active correspond à une seule tâche. Si la tâche est déjà suivie dans le Superviseur par une session en pause (passage de relais / reprise), demande confirmation à l'utilisateur avant de transférer l'écoute, puis ajoute `--reassign`.
4. Depuis la racine du dépôt, appelle le client local avec PowerShell :

```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py --platform dsh --alias "<TXXX-DSH01 Désignation>" --task "<ID et titre vérifiés, ou SANS TÂCHE FORMELLE après confirmation>" --mission "<mission courte>" [--reassign]
```

Le client lit `DSH_SESSION_ID` dans l’environnement du shell d’outil. Si l’environnement ne le fournit pas, demande l’ID exact `session-<UUID>` puis passe `--session-id`.
Si l’utilisateur a confirmé le suivi sans tâche formelle, ajoute `--confirm-without-task` ; sinon, le script le refuse.
5. Ne réessaie pas en changeant d’ID si l’API refuse. Rapporte le résultat JSON, l’alias, l’ID exact et l’état (`attached`, `already_assigned` ou erreur). Une affectation en pause doit être reprise dans l’interface.

Le client n’accepte que l’API Superviseur locale `127.0.0.1:8082`, exige une source unique et n’envoie pas le transcript lors du rattachement. Le collecteur lit le fichier DSH Zstandard local et suit uniquement les nouvelles trames ; une troncature ou réécriture suspend le suivi. Le partage du texte avec un modèle reste contrôlé séparément par le réglage de consentement cloud.
