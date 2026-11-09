# Brief de délégation — Challenge A (DeepSeek V4.1) : Notifications, Audio et Clic de carte (AC-F3.5 / AC-F3.9)

## Mission

- **Utilisateur / besoin d'origine :** L'exploitant demande une validation rigoureuse de la tâche T429 (Agent Supervisor) avec revue indépendante des objectifs mesurables.
- **Objectif de cette sous-tâche :** Examiner de manière critique et exhaustive l'implémentation de la chaîne de notification bureau, sonore, toast VS Code et interaction au clic (AC-F3.5 et AC-F3.9).
- **Historique utile et preuves disponibles :** 
  - Dans `TOOLS/AGENT_SUPERVISOR/ui/index.html` (l. 472-478), la notification bureau est déclenchée lors de nouveaux Warning/Alarm.
  - Le handler actuel de notification bureau est : `note.onclick = () => { window.focus(); note.close(); };`.
  - Le critère AC-F3.5 stipule : « Un nouveau Warning ou Alarm declenche une seule notification bureau, un son et un toast VS Code ; le clic ouvre la bonne session et la bonne carte. »
  - Dans `TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/extension.js` (l. 136-139), le clic sur le toast appelle `openTarget(target.session.id, target.alert.id)` qui ouvre l'URL `http://127.0.0.1:8082/?session=...&alert=...`.
  - Dans `ui/index.html` (l. 171, 599, 610), les paramètres `?session=&alert=` sont gérés au chargement initial (`requestedSupervisorSession` / `requestedSupervisorAlert`).
- **Décision que le résultat doit permettre :** Déterminer si `note.onclick` dans l'IHM et la gestion sonore respectent 100 % des exigences de AC-F3.5, ou si un correctif chirurgical est requis.
- **Critères d'acceptation de la review :**
  1. Verdict clair (PASS / FAIL / PARTIEL) sur AC-F3.5 et AC-F3.9 avec justification technique ligne par ligne.
  2. Analyse précise du comportement de `note.onclick` dans `index.html` lorsque la page est déjà ouverte en arrière-plan.
  3. Analyse de la politique audio (AudioContext suspendu par le navigateur) et proposition d'amélioration si nécessaire.
  4. Proposition de patch direct si un écart est démontré.

## Rôle et autorisations

- **Rôle :** Reviewer technique indépendant (Lecture seule).
- **Périmètre autorisé :** `TOOLS/AGENT_SUPERVISOR/ui/index.html`, `TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/extension.js`, contrat T429.
- **Actions interdites :** Aucune écriture de code, aucun commit, aucune modification d'état.
- **Responsable :** Orchestrateur Antigravity AGY01.

## Méthode et restitution

Rendre un rapport markdown structuré :
1. Résumé exécutif (3 lignes).
2. Analyse détaillée des points 1, 2, 3.
3. Risques résiduels et faux positifs potentiels.
4. Patch recommandé (diff unifié précis).
