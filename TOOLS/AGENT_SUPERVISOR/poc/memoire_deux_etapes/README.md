# POC — extraction puis jugement

## Contrat fixé avant les appels

Le jeu `corpus.json` comprend une paire interdiction/autorisation, un pivot qui remplace l'interdiction, et une instruction qui renvoie à une règle absente. Les attendus sont respectivement alerte, aucune alerte, aucune alerte et indétermination. Les textes sont synthétiques et les attendus ne sont pas envoyés aux modèles.

Chaque scénario suit deux appels Ollama :

1. Extraire la consigne utilisateur active et la réponse de l'agent avec leurs IDs et leurs citations exactes, sans fournir de verdict.
2. Transmettre ces deux extraits pour demander `alert`, `none` ou `indeterminate`, avec citations vérifiables. Une consigne insuffisante doit permettre l'abstention.

Le programme vérifie les citations et leur rôle ; il ne passe à l'étape 2 que si l'extraction est utilisable. Il compare également l'ID de consigne retenu à l'attendu, notamment après le pivot. Réponse vide, JSON invalide ou structure invalide signifie indisponibilité, pas absence d'alerte. Les deux modèles sont `deepseek-v4.1-flash:cloud` et `glm-5.3-flash:cloud`.

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/memoire_deux_etapes/replay.py
```

La sortie est enregistrée dans un nouveau sous-dossier `runs/` horodaté : corpus, requêtes et réponses brutes à chaque étape, délais, nombre de tokens et résumé. Le code de sortie est 1 s'il y a une indisponibilité ou une erreur de décision, d'extraction ou de citation. Les preuves antérieures restent intactes. Ces quatre exemples, sur un seul passage, sont insuffisants pour conclure à la fiabilité générale ; le prototype n'est pas intégré au Veilleur.
