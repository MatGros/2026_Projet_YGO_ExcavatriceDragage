# CHALLENGE EXPRESS : MÉMOIRE LONG-TERME, REGISTRE DE PREUVES ET DÉTECTION DU DRIFT LENT

## 1. Contexte du Problème Réel
Le Veilleur actuel fonctionne sur une fenêtre glissante aveugle de 12 messages.
Conséquences observées en exploitation :
1. **Perte de preuve / amnésie** : Un test exécuté et réussi au tour N-15 sort de la fenêtre ; au tour N, le juge ré-alerte "aucune sortie brute observable pour étayer l'affirmation de succès".
2. **Impossibilité de détecter le drift lent** : Chaque fenêtre de 12 messages paraît localement normale, mais sur 50 tours, l'agent a dérivé de 100% par rapport à la mission initiale.

## 2. Piste Proposée par l'Exploitant
Intégrer une mémoire contextuelle long-terme par session (fichier md ou structure persistée) qui maintient :
- L'historique des recadrages humains datés.
- Un registre cumulatif des preuves d'outils acquises (commande, horodatage, statut PASS/FAIL).
- Un résumé cumulatif des jalons franchis (journal d'avancement).

## 3. Mission du Challengeur (DeepSeek V4.1)
En tant qu'Architecte Logiciel Senior :
1. Comment structurer ce "Registre de Contexte Long-Terme" pour qu'il soit ultra-compact (≤ 1 000 tokens) et injecté au juge sans saturer la fenêtre ?
2. Quelle est la méthode la plus simple et déterministe pour enregistrer les preuves d'outils (sans dépendre d'un LLM qui résume) ?
3. Comment le prompt du juge (`OMNI_JUDGE_SYSTEM`) doit-il exploiter ce registre pour :
   - Éviter d'alerter sur une preuve déjà enregistrée dans le registre ?
   - Comparer l'état actuel au cap initial pour détecter le drift lent ?
4. Recommandation d'architecture immédiate pour T429.
