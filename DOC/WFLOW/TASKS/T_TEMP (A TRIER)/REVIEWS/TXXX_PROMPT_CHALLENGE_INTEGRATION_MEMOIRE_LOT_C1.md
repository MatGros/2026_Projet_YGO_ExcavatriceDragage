# AUDIT D'OPPORTUNITÉ : INTÉGRATION DE LA MÉMOIRE LONG-TERME DANS LE LOT C1 ?

## 1. Contexte
L'exploitant propose d'intégrer dans le Lot C1 la gestion de la mémoire long-terme de session :
- Le prompt sait lire un document mémoire et émettre une mise à jour d'état (`state_update`).
- Une cadence mécanique (tous les 8 messages) déclenche un audit de trajectoire (Cap initial vs Mémoire des jalons).

## 2. Analyse des Risques et Périmètres
- Le Lot C1 est actuellement confié à un agent externe avec écriture exclusive sur `judge_prompt.py` et `test_judge_behavior.py`.
- `supervisor_service.py` gère le moteur d'exécution et le dispatch des messages.

## 3. Question du Challenge
Faut-il :
- OPTION 1 : Tout intégrer dans C1 (Prompt + Moteur Python dans `supervisor_service.py`) ?
- OPTION 2 : Séparer strictement le rôle :
  - Lot C1 (Agent utilisateur) : Formule et teste le Prompt pour qu'il sache lire la section mémoire et émettre `state_update` (100% dans `judge_prompt.py`).
  - Lot C2 / Moteur (Orchestrateur) : Implémente le compteur de tours et la persistance du document mémoire dans `supervisor_service.py`.
- OPTION 3 : Reporter après la validation du Golden Dataset initial.

Évalue la faisabilité, les risques de conflit Git et la charge cognitive pour l'agent.
