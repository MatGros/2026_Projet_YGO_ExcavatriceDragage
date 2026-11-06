# POC — alertes déjà vues et récidives

## Contrat

Sept cas synthétiques ont été fixés dans `corpus.json` avant les appels : alerte vue à l'identique ou reformulée, faux positif indiqué, nouvel écart, pivot légitime, récidive et récidive dont la citation est identique à l'ancienne. Le modèle doit signaler les trois derniers écarts réels attendus et rester silencieux sur les quatre autres ; une citation doit être exacte et rattachée au message assistant attendu.

Deux variantes sont exécutées : sans ou avec une liste structurée des anciennes alertes. Les deux reçoivent les événements et le contexte fourni dans le corpus. Certaines informations sur les anciennes alertes figurent aussi dans les messages utilisateur : cette comparaison ne mesure donc pas le bénéfice isolé de la liste structurée.

## Exécution

`python -B TOOLS/AGENT_SUPERVISOR/poc/boucle/replay.py`

Chaque lancement utilise `deepseek-v4.1-flash:cloud` via Ollama sur des données synthétiques uniquement, consomme des tokens cloud et crée un nouveau fichier de résultats avec nom unique. Celui-ci contient les requêtes, réponses brutes, temps, scores par cas, et compteurs de tokens transmis par Ollama. Les erreurs et réponses invalides sont marquées indisponibles et déclenchent un code de sortie non nul.

Depuis la correction de l'évaluateur, un écart aux attendus, une citation incorrecte, une source erronée ou plusieurs alertes pour l'unique problème attendu provoquent aussi un code de sortie non nul. `python -B TOOLS/AGENT_SUPERVISOR/poc/boucle/test_evaluator.py` vérifie ces contre-exemples sans appel réseau.

## Résultat conservé

Dans `results-20261105T032119Z-acad4b60.json` : les 14 appels sont disponibles ; les 7 cas correspondent aux attendus dans chacune des deux variantes, sans citation invalide. Ce sont des cas synthétiques courts, avec un contexte explicite préparé par l'essai ; il ne s'agit pas d'une mesure de fiabilité ou d'une validation d'intégration au Veilleur.

Après correction de l'évaluateur, `results-20261105T032534Z-8b5648e1.json` conserve un nouveau passage : 7/7 cas par variante, zéro alerte supplémentaire, sans citation invalide. Le test d'évaluateur passe sur les échecs et doublons injectés.

La règle expérimentale « cacher une citation strictement identique à une ancienne » est dangereuse : dans `nouveau_fait_citation_identique`, elle masquerait une action réellement nouvelle rapportée avec les mêmes mots. Elle n'est pas activée dans le produit. Les deux variantes ont obtenu les mêmes scores ; aucun avantage de la liste structurée n'a été démontré sur ce corpus.
