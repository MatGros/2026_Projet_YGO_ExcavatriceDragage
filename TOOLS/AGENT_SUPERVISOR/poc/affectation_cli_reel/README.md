# POC — découverte et affectation du transcript AGY réellement créé pour un essai

## Objectif et attendus définis avant exécution

À partir du seul UUID de session synthétique établi par le préflight `poc/agy_routage/preflight_e0afb6eb9c7d4f569ec6e147df5e90ec.json`, le résolveur doit trouver une source AGY non ambiguë, la découverte doit proposer cet UUID, puis l'ajout strict doit attacher exactement cette source à un `Supervisor` isolé. Toute source absente, ambiguë, candidate manquante, ou affectation erronée fait échouer l'essai.

Le script vérifie avant toute recherche que le préflight indique `synthetic_only`, l'absence de cible préexistante, un retour réussi et la réponse attendue. Il recherche uniquement cet UUID. Pour la découverte, il restreint dans son processus la descente d'`os.walk` à cet UUID avant appel de `Supervisor.candidates()` ; **il ne teste donc pas une découverte globale non filtrée**. Il ne récupère pas les contenus du transcript dans le rapport. L'attachement initial calcule l'empreinte du transcript synthétique ; l'état et la note de session sont écrits dans un nouveau dossier temporaire. Aucun service actif n'est démarré ou modifié, aucun appel LLM ni message à une conversation n'est fait. Le préflight avait créé cette session ; les échanges ultérieurs du POC AGY restent des données synthétiques.

## Exécuter

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/affectation_cli_reel/replay.py
```

Chaque exécution conserve un nouveau JSON de preuve au nom unique et un nouveau dossier de travail temporaire ; aucun nettoyage automatique. La commande dépend de la présence inchangée du préflight et du transcript AGY local qu'il a créé.

## Résultat observé

Dans `evidence-20261105T033747Z-1b82d8ad.json`, une seule des trois racines prévues contient le transcript : `antigravity-cli/brain/<UUID>/.system_generated/logs/transcript.jsonl`. Le résolveur retourne `ready` avec une correspondance, la découverte restreinte retourne la même session AGY et l'ajout strict l'attache avec le bon chemin. Les trois contrôles sont vrais et le code de sortie vaut 0.

Ce résultat vérifie **une session AGY réelle de test**, dont l'identifiant était déjà connu. Il ne démontre ni l'identification automatique d'une conversation inconnue, ni la lecture de nouveaux messages, ni la découverte sans filtre, ni le fonctionnement pour Claude ou Codex. Aucun lien avec une tâche formelle n'est vérifié dans cet essai.
