# Routage des modèles

## Règle générale — Pas de multi-modèle systématique

Le multi-modèle n'est **pas** la règle par défaut. Il est réservé aux cas où le risque le justifie.

| Voie | Modèle | Multi-modèle |
|---|---|---|
| C0-C1 Fast Lane | Pi seul | ❌ Non |
| C2-C3 Standard Lane | Pi (modèle fort) | ❌ Non — 1 seul agent Herdr en revue |
| C4 Safety Lane | Pi (modèle fort, High Effort) | ✅ Oui — Double revue A/B obligatoire |
| C4 + opinion divergente | Pi + 1 délégation Herdr | Seulement si vraie incertitude non résolue par A/B |

## 🔴 Double revue parallèle A/B (C4 uniquement)

**Déclencheur** : TEST_DESIGN, ST généré, toute revue safety C4.

**Méthode** :
1. Agent A reçoit le contexte complet (TASK_CONTEXT + code/design).
2. Agent B reçoit exactement le même contexte — **sans voir le résultat de A**.
3. Pi compare les 2 rapports :
   - Consensus → synthèse présentée à l'humain.
   - Divergence (≥1 point contradictoire) → 🚨 alerte + résumé A vs B côte à côte.

**Règles** :
- Pas de fusion automatique des avis.
- Aucun agent ne modifie, ne commit, ne valide la safety.
- Ponytail interdit pour toute analyse safety/normative/redondance.

## Routage par criticité — récapitulatif

| Criticité | Analyse | Revue | Double A/B |
|---|---|---|---|
| C0 | Pi seul | — | — |
| C1 | Pi seul | — | — |
| C2 | Pi modèle fort | 1 Herdr read-only | — |
| C3 | Pi modèle fort | 1 Herdr read-only | — |
| C4 | Pi modèle fort High Effort | 1 Herdr A + 1 Herdr B parallèles | ✅ obligatoire |

## Fournisseurs

OpenRouter et Ollama sont des fournisseurs optionnels. Les clés ne sont jamais stockées dans le dépôt.
