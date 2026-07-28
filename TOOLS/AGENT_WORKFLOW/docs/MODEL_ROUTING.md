# Routage des modèles

## Règle générale — Pas de multi-modèle systématique

Le multi-modèle n'est **pas** la règle par défaut. Il est réservé aux cas où le risque le justifie.

| Voie | Modèle | Multi-modèle |
|---|---|---|
| C0-C1 Fast Lane | Pi seul | ❌ Non |
| C2 Standard Lane | Pi (modèle fort) | ❌ Non par défaut — 1 avis ciblé seulement si utile |
| C3 Standard Lane | Pi (modèle fort) | ❌ Non — 1 Pi Subagent read-only si le risque le justifie |
| C4 Safety Lane | Pi (modèle fort, High Effort) | ✅ Oui — Double avis A/B Pi Subagents obligatoire |
| C4 + opinion divergente | Pi + humain | L'humain tranche ; Herdr seulement sur demande explicite |

## 🔴 Double revue parallèle A/B (C4 uniquement)

**Déclencheur** : TEST_DESIGN, ST généré, toute revue safety C4.

**Méthode** :
1. Agent A Pi Subagent reçoit le contexte complet (TASK_CONTEXT + code/design), en read-only.
2. Agent B Pi Subagent reçoit exactement le même contexte — **sans voir le résultat de A**, en read-only.
3. Pi attend, lit puis compare les 2 rapports :
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
| C2 | Pi modèle fort | avis ciblé optionnel | — |
| C3 | Pi modèle fort | 1 Pi Subagent read-only si utile | — |
| C4 | Pi modèle fort High Effort | 2 Pi Subagents A/B read-only parallèles | ✅ obligatoire |

## Fournisseurs

Le modèle de revue privilégié est `omni/cc/claude-sonnet-5` lorsqu'il est disponible. Les
sous-agents héritent sinon du modèle courant de Pi ; le modèle réellement exécuté est rapporté.

OpenRouter et Ollama sont des fournisseurs optionnels. Les clés ne sont jamais stockées dans le dépôt.
