# POC classificateur local

Les cas et catégories attendues figurent dans `cases.json` ; ils ont été définis avant l'exécution. Ils sont synthétiques. Le script charge en local CPU un modèle NLI préentraîné déjà présent dans `%TEMP%/veilleur-poc-nli`, sans réseau et sans entraînement. Il choisit une des quatre étiquettes proposées et en déduit une alerte pour répétition ou absence de preuve.

Commande :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/classificateur/replay.py
```

Le modèle doit déjà être présent en cache ; sinon le script échoue explicitement. `results.json` conserve les entrées, les scores et temps du passage réalisé. Les scores sont relatifs aux quatre options, sans calibration. Les résultats ne permettent pas de conclure sur la qualité en production ni sur l'apprentissage à partir des retours utilisateur.
