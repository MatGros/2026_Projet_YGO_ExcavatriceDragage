# POC : retours annotés pour guider le juge

## Contrat défini avant les appels

Comparer le même juge Ollama avec et sans deux exemples de retours humains synthétiques. Aucun entraînement ni modification des poids. Les exemples fournis au modèle sont distincts des quatre situations de test et ne contiennent pas les attendus de celles-ci. Les situations ont été fixées avant l'appel : réponse d'attente après alerte déjà vue (pas d'alerte), nouvelle relance après interdiction (alerte), pivot demandé par l'utilisateur (pas d'alerte), clôture sans contrôle exigé (alerte).

Chaque situation est évaluée une fois par variante. Le modèle doit renvoyer `alert`, `no_alert` ou `ambiguous`, et pour une alerte citer exactement un message assistant et son ID. Enregistrer requêtes, réponses brutes, temps, tokens, faux positifs, faux négatifs, ambiguïtés et citations invalides. Une réponse invalide ou indisponible est distincte d'un succès. Les données sont entièrement synthétiques et `deepseek-v4.1-flash:cloud` consomme des tokens Ollama.

Critère : décrire les différences observées ; aucun gain n'est établi si les deux variantes obtiennent le même résultat. Un corpus limité et des exemples fabriqués ne mesurent pas la qualité générale ni un apprentissage continu. Les retours ne sont pas transmis dans la variante témoin.

Commande : `python -B TOOLS/AGENT_SUPERVISOR/poc/retours/replay.py`. Chaque passage produit un fichier JSON unique à côté du script, sans remplacer une preuve antérieure.

## Résultat du premier passage

Dans `results-20261105T034853Z-2826cc53.json`, 8 réponses sur 8 sont disponibles, avec 4 cas sur 4 conformes aux attendus dans chacune des deux variantes. Aucune fausse alerte, aucun cas ambigu et aucune citation invalide sur ces quatre cas ; la variante avec retours a consommé 1 220 tokens d'entrée contre 668 sans retours. Le temps cumulé est de 3,268 s contre 2,665 s, dans cet ordre d'exécution. Ollama rapporte respectivement 310 et 302 tokens de sortie ; cela ne constitue pas un prix facturé.

L'inspection des requêtes confirme que les métadonnées `expected` et `expected_event` ne sont pas transmises ; les critères normatifs généraux du juge sont communiqués aux deux variantes. Sur ce jeu, les retours n'améliorent pas le score, déjà maximal dans la variante témoin. La variation de temps sur quatre appels et la différence de taille de prompt ne permettent pas d'estimer le coût ou la latence en production. Les exemples et cas restent artificiels et limités ; aucun apprentissage de poids n'a eu lieu.
