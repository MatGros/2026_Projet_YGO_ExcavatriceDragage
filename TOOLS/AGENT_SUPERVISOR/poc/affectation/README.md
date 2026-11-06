# POC affectation — preuve reproductible

Objectif : tester la découverte et l'affectation sur sources synthétiques isolées, puis vérifier la règle souhaitée « une tâche par session ».

Commande depuis la racine du dépôt :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/affectation/replay.py
```

Le script crée un dossier unique dans le temp système et le conserve. Il n'utilise aucun transcript réel, réseau, Task Manager ou service en cours. `results.json` est la sortie brute d'une exécution. Le code de sortie 1 indique l'échec d'au moins un critère attendu ; c'est le cas de l'exclusivité de tâche.

Sur la base `2ae79f2b`, les trois formats synthétiques sont découverts et acceptés ; la même session est refusée deux fois, l'ID inconnu et la source ambiguë sont refusés, une mission vide passe en `context_required`. Trois sessions distinctes partageant le texte de mission `T999` sont acceptées : critère d'exclusivité non satisfait. La tâche est ici du texte libre, aucune identité formelle ni interrogation Task Manager n'existe dans cet essai. Il ne démontre pas l'affectation automatique ni la compatibilité d'une session réelle.
