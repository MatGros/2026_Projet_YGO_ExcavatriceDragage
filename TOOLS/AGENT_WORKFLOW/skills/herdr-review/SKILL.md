---
name: herdr-review
description: Délègue une revue read-only ciblée à un ou deux agents Herdr (selon criticité) et restitue les constats sans modifier ni committer le projet.
---

# Revue Herdr

## C2-C3 — Revue simple (1 agent)

1. Lire le `TASK_CONTEXT` et limiter le scope.
2. Vérifier `herdr status` avant délégation.
3. Utiliser `herdr_delegate` avec un prompt autonome et read-only.
4. Demander un rapport structuré : bloquants, risques, DOC/CODE, tests, conclusion.
5. Comparer le rapport avec les gates Python.
6. Ne jamais appliquer automatiquement une modification proposée.

## C4 — Double revue parallèle A/B (obligatoire)

Déclenché si `dual_review_required: true` dans le TASK_CONTEXT.
S'applique à : TEST_DESIGN, ST généré, toute revue safety C4.

1. Lire le `TASK_CONTEXT` et préparer le prompt de revue commun.
2. Lancer **Agent A** via `herdr_delegate` (pane A) — prompt read-only complet.
3. Lancer **Agent B** via `herdr_delegate` (pane B) — **même prompt exactement**, sans voir A.
4. Attendre les 2 résultats (`herdr_wait_agent` sur chaque pane).
5. Comparer les 2 rapports :
   - **Consensus** (aucun point contradictoire) → synthèse unique présentée à l'humain.
   - **Divergence** (≥1 point contradictoire) → 🚨 alerte humain + tableau A vs B côte à côte.
6. L'humain tranche. Aucun agent ne valide la safety.
7. Ne jamais fusionner automatiquement les avis ou choisir l'un sur l'autre sans alerte.

## Règles communes

- Rapport structuré : bloquants 🔴 / risques 🟠 / observations 🟡 / OK ✅ / hors-scope ⚫.
- Ponytail interdit pour toute analyse safety, normative ou de redondance.
- Pour C4, présenter le résultat à l'automaticien : Herdr ne valide jamais la safety.
