# MANDAT AGENT B : BLUE TEAM / ARBITRAGE ET FINALISATION OPÉRATIONNELLE DU CONTRAT C1

Tu es l'Architecte en Chef et Arbitre du projet ExcavatriceDragage / Agent Supervisor.
L'Agent A (Red Team) a livré une critique impitoyable du contrat C1 (consignée ci-dessous).

## LE RAPPORT DE L'AGENT A :
Consulte le rapport complet dans `DOC/WFLOW/REVIEWS/REVIEW_CHALLENGE_AGENT_A_CONTRAT_C1.md`.
En synthèse, l'Agent A relève :
1. Les 8 cas sont des récits vagues, pas des fixtures JSON réelles au format du Veilleur (`role`, `event_id`, `text`).
2. Risque de surapprentissage (overfitting sur 8 cas publics) si on ne met pas de garde anti-hardcode et si on n'éprouve pas le prompt sur des cas de travail bénin.
3. Le format de sortie du juge doit être normé (sévérité, catégorie, citation exacte, motif).
4. La matrice de confusion (coût des erreurs : ALARM manquée = critique, faux positif ALARM sur bénin = inacceptable).
5. Éviter l'usine à gaz : garder une exécution ultra-rapide sur le modèle local Ollama (`deepseek-v4.1-flash:cloud`).

## TA MISSION :
1. **Arbitrer les critiques de l'Agent A** :
   - Qu'est-ce qui est INDISPENSABLE et non négociable pour que le lot soit évaluable ?
   - Qu'est-ce qui est SUR-DIMENSIONNÉ (théorique, excessif pour une tâche de prompt) et qu'il faut simplifier pour rester pragmatique ?
2. **Fournir le CONTRAT C1.1 DÉFINITIF ET PRÊT À L'EMPLOI** :
   - Rédiger le contrat final complet, sans trous, que l'utilisateur donnera à son agent.
   - Inclure la structure exacte de la fixture Python/JSON (compatible avec `supervisor_service.py`).
   - Fixer les seuils de succès/échec chiffrés.
   - Fournir les consignes anti-hardcode.

Reste concis, pragmatique, direct et orienté résultat.
