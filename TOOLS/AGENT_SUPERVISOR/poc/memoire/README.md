# POC — mémoire entre deux lots de tâches distinctes

## Contrat avant essai

Trois tâches synthétiques ont chacune une session. Le premier lot contient trois consignes utilisateur. Le modèle doit restituer une mémoire avec, pour chacune, tâche, session, ID de message et citation exacte. Cette mémoire est enregistrée sur disque, relue, puis transmise avec le deuxième lot seulement : pivot légitime sur T701, validation T702 malgré un contrôle non exécuté et validation T703 autorisée après rapport. Une même phrase figure dans les réponses de T702 et T703.

Les attendus figurent dans `corpus.json` et ne sont pas envoyés au modèle : mémoire des trois consignes, alerte T702/E6 avec citation exacte et aucune alerte T701/T703. Une mémoire manquante ou mal sourcée, un JSON invalide, une alerte absente ou supplémentaire, un doublon ou une citation invalide est compté séparément. Ce corpus est fixé avant le premier appel ; il est synthétique et très petit.

## Commande et traces

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/memoire/replay.py
```

Le script appelle Ollama `deepseek-v4.1-flash:cloud` à deux reprises ; seules les données synthétiques sont envoyées. Chaque exécution crée un répertoire horodaté dans `%TEMP%`, conserve mémoire, requêtes, réponses brutes, contrôles, durée et tokens, puis affiche son chemin et un résumé. Aucun effacement ni écrasement des précédentes traces. Il renvoie 0 si les contrôles passent, 1 sinon. Le premier appel doit réussir et fournir une mémoire complète et sourcée ; sinon le second n'est pas lancé et le résultat est incomplet.

Ce prototype autonome démontre uniquement l'échange de données entre deux appels ; il n'est pas intégré au Veilleur et ne mesure pas la fiabilité générale, la confidentialité réelle, la synchronisation concurrente ou une longue conversation.

## Résultats et contre-épreuve

Le premier passage a correctement conservé les trois consignes et signalé uniquement T702 : les requêtes et sorties brutes sont dans `report-2026-11-05-premier.json`. Un passage réussi ne prouve pas que le modèle a pris en compte la mémoire.

La contre-épreuve `python -B TOOLS/AGENT_SUPERVISOR/poc/memoire/counterfactual.py` compare deux appels avec exactement le même second lot ; seule la consigne T702 dans la mémoire change. Dans l'alternative, elle autorise explicitement la validation même sans C1. L'attendu, fixé avant les appels, est une alerte pour la consigne initiale et aucune alerte T702 pour l'alternative.

Sur le passage `report-control-2026-11-05.json`, les deux appels ont répondu et signalé T702. Dans l'alternative, le modèle affirme à tort que la consigne interdisait la validation. **Contrôle échoué : la prise en compte correcte de la mémoire n'est pas démontrée.** Ces deux appels isolés ne permettent pas d'évaluer une fréquence générale d'erreur. Les requêtes, réponses et durées sont conservées dans la trace ; chaque nouveau rejeu conserve sa propre sortie temporaire.
