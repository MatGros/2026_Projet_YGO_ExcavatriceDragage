# T430 — Étude : organisation documentaire par tâche

**Version :** v1.0 · **Date :** 2026-11-15 · **Responsable :** CDX04  
**État :** étude et challenge réalisés ; application partielle, coordination inter-tâches requise.

## Question étudiée

Comment ranger les documents pour qu’en ouvrant le dossier d’une tâche, son étude, son plan, sa fiche d’entrée, ses contrats et ses preuves soient retrouvables sans créer de dossiers concurrents ni rompre les références du Task Manager.

## Faits établis

- La cible utilisateur demande un dossier par tâche réutilisant l’existant, avec trois documents racine datés/versionnés : `T<ID>_TASK_STUDY_DOCUMENT_<AAAAMMJJ>_v<X.Y>.md`, `T<ID>_TASK_PLAN_<AAAAMMJJ>_v<X.Y>.md`, `T<ID>_TASK_<AAAAMMJJ>_v<X.Y>.md`.
- Le Task Viewer appelle `contrat` « Lien Contrat YAML ». `audit_tasks_contracts.py` et `check_task_contract.py` traitent ce champ comme un fichier ; G530 ne garantit pas la détection d’un dossier donné comme chemin. Le lien exact du YAML reste donc la voie compatible.
- La convention historique `TASK_CONTRACT_<id>.yaml` ne suit pas l’ordre tâche-type-désignation demandé. Les outils de découverte doivent accepter le nouveau nommage sans abandonner les fichiers historiques.
- T432 a déjà un dossier `T432/` et son contrat est sous `CONTRACTS/`, mais les trois documents racine ne sont pas présents. Le nom d’exemple proposé est `T432_COMMANDS_SESSION_SUPERVISOR/`.
- T417-C a déjà un dossier dédié et ses répertoires `ARCHIVES/` et `PREUVES/`. Son contrat apparaît déplacé vers `CONTRACTS/`; une référence de contexte catalogue cite encore l’ancien chemin et le README mentionne AGY03 alors que l’attribution/verrou catalogue indique AGY02.
- Le dossier T432 est verrouillé CDX02 ; T417-C est verrouillé AGY02. Leurs propriétaires ou l’orchestrateur doivent coordonner toute écriture.

## Analyse et arbitrages

1. Les trois documents racine ont des fonctions séparées : l’étude conserve le raisonnement initial, le plan pilote les étapes, la fiche `TASK` sert d’index vers les éléments de référence. Le YAML conserve les critères formels ; les preuves vont dans `PREUVES/`.
2. Le champ `contrat` conserve le chemin exact du YAML sous `CONTRACTS/`. Un lien vers la racine n’est pas pris en charge de façon vérifiable actuellement.
3. Réutiliser T432 signifie normaliser le dossier existant en place si le propriétaire valide le renommage et met à jour les références ; ne pas créer un second dossier.
4. Le renommage d’un fichier ou dossier conserve son ancien contenu dans Git. Les archives et preuves historiques ne sont pas supprimées.

## Avis indépendants

Trois reviewers de la plateforme ont examiné le cadrage et les diffs en lecture seule. Ils convergent sur le lien exact YAML, le manque de documents racine T432, les références/noms à harmoniser et le respect des verrous. Deux appels au runner `deepseek-v4.1-flash:cloud` ont produit une sortie vide : aucun avis DeepSeek n’est revendiqué.

## Références

- Plan d’application actuel : [T430_TASK_PLAN_20261116_v1.2.md](T430_TASK_PLAN_20261116_v1.2.md)
- Contrat d’application : [T430_CONTRACT_ORGANISATION_DOCUMENTAIRE_20261115_v1.1.yaml](CONTRACTS/T430_CONTRACT_ORGANISATION_DOCUMENTAIRE_20261115_v1.1.yaml)
