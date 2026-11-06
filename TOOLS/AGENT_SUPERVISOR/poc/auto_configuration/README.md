# POC — proposition d'affectation depuis un transcript synthétique

## Contrat fixé avant exécution

À partir d'un UUID choisi explicitement, le prototype doit résoudre la source AGY, normaliser ses messages et demander à Ollama une proposition de configuration. La proposition doit citer exactement les messages d'origine pour l'alias, la tâche et la mission. Pour ce POC, la mission elle-même est une citation exacte, pas un résumé libre.

Le corpus `corpus.json` définit cinq cas et leurs attendus, **non transmis au modèle** :

1. Tâche formelle T501 rapportée : proposer T501 et son alias avec preuves.
2. Aucune tâche rapportée : ne pas inventer d'ID et demander si l'utilisateur veut créer une tâche ou suivre sans tâche.
3. Indications T601/T602 contradictoires : ne choisir aucune tâche, citer les deux indications et demander une clarification.
4. Deux fichiers pour le même UUID : refuser la source ambiguë, sans appel modèle.
5. UUID absent : refuser, sans appel modèle.

L'essai prévoit une simulation de confirmation : aucun cas n'autorise l'affectation avant confirmation ; le cas sans tâche nécessite également le choix explicite « suivre sans tâche » ; une source ou une proposition ambiguë reste refusée. Le script ne crée **aucune affectation réelle**, même dans le cas où la simulation indique qu'une confirmation serait suffisante.

## Commandes et preuves

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/auto_configuration/test_evaluator.py
python -B TOOLS/AGENT_SUPERVISOR/poc/auto_configuration/replay.py
```

La première commande teste sans réseau les citations inventées, ID de tâche inventé, sources de preuve manquantes ou erronées, ambiguïté et garde de confirmation. La seconde crée des transcripts fictifs dans un nouveau dossier temporaire, appelle `deepseek-v4.1-flash:cloud` via Ollama pour les trois cas dont la source est unique, puis conserve les entrées exactes, requêtes, réponses brutes, sorties, erreurs, temps et compteurs de tokens dans un nouveau fichier JSON au nom unique. Elle consomme des tokens cloud et ne nettoie aucun artefact. Code de sortie non nul si un cas attendu échoue ou si le modèle est indisponible.

## Résultat observé

Dans `result-20261105T035130Z-ec959538.json`, les cinq cas satisfont leurs critères. Ollama propose T501 avec citations, formule pour le cas sans tâche « créer une tâche formelle … ou … suivre cette conversation sans tâche ? », et demande de choisir entre T601 et T602 pour les indications contradictoires. Les deux UUID absents ou ambigus n'ont entraîné aucun appel au modèle. Aucune affectation n'a été effectuée et la simulation n'en autorise aucune sans confirmation. Les trois appels ont pris respectivement 0,772 s, 0,748 s et 0,749 s ; Ollama a rapporté 1 276 tokens d'entrée et 457 de sortie au total. Le coût financier réel n'a pas été mesuré.

## Limites

Ce POC n'est pas intégré au Veilleur. Il ne vérifie pas le Task Manager, l'attribution ou l'existence réelle d'une tâche : une « tâche formelle » est uniquement **rapportée dans le transcript**. Les alias et objectifs sont explicites dans ces messages fictifs ; les conversations longues, instructions ambiguës, sorties d'outils, citations partielles, cas de recadrage et conflits avec une attribution réelle ne sont pas évalués. Le validateur compare ici la proposition à une vérité de référence connue du corpus : cette comparaison ne serait pas disponible pour une session inconnue. Il démontre donc une faisabilité sur ces cas, sans prouver une auto-configuration fiable en production.
