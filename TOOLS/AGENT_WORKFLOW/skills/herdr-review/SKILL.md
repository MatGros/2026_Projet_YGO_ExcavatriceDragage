---
name: herdr-review
description: Délègue une revue read-only ciblée à un agent visible Herdr et restitue les constats sans modifier ni committer le projet. Utiliser pour les reviews C2/C3 et les avis consultatifs C4.
---

# Revue Herdr

1. Lire le `TASK_CONTEXT` et limiter le scope.
2. Vérifier `herdr status` avant délégation.
3. Utiliser `herdr_delegate` avec un prompt autonome et read-only.
4. Demander un rapport structuré : bloquants, risques, DOC/CODE, tests, conclusion.
5. Comparer le rapport avec les gates Python.
6. Ne jamais appliquer automatiquement une modification proposée.
7. Pour C4, présenter le résultat à l'automaticien : Herdr ne valide pas la safety.

Ponytail est interdit pour toute analyse safety, normative ou de redondance.
