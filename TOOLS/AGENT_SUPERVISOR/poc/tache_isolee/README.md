# POC — garde d'affectation par tâche

## Question et attendu

Une tâche formelle peut-elle être proposée au suivi seulement si elle existe, est ouverte, est attribuée au même agent et possède son verrou ? Une tâche déjà suivie par une autre session, ou une session déjà liée à une autre tâche, doit être refusée. Un registre indisponible doit rester indéterminé, jamais être traité comme vide.

Le corpus `corpus.json` fixe 10 cas synthétiques et leurs résultats attendus avant le replay.

## Exécution et preuve

Depuis la racine du dépôt :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/tache_isolee/replay.py
```

Le script redirige le Task Manager vers des fichiers temporaires, démarre son handler HTTP sur un port éphémère et ne fait qu'un `GET /api/tasks/json`. Il compare les empreintes des fixtures avant/après, n'affecte aucune session et ne modifie aucun catalogue réel.

Passage du 5 novembre 2026 : **10/10 cas PASS**, HTTP 200, fixtures inchangées. Trace : `result-20261105T042344Z-8a49caab.json`.

## Limites

- La décision d'affectation est un prototype consultatif dans `replay.py`, pas une route du Veilleur.
- Le registre des sessions est synthétique et fourni au prototype : Task Manager ne donne pas ici de preuve d'une liaison réelle session↔tâche.
- `identity_verified` reste volontairement faux, même quand les champs déclaratifs concordent.
- Ce POC démontre le contrôle des conflits à partir des sources fournies ; il ne démontre ni persistance, ni verrouillage atomique, ni concurrence entre processus.

**Verdict : faisabilité du contrôle de cohérence démontrée sur fixture ; intégration et unicité en production non démontrées.**
