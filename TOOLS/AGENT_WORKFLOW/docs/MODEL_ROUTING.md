# Routage des modèles

> 🔧 **Révisé 2026-08-17.** Pi Subagents/Herdr abandonnés. Le gate `G220_check_model_routing.py`
> lisait `.pi-subagents/artifacts/*_meta.json` (modèle réellement exécuté) — ce dossier n'existe
> plus, et ni antigravity ni Codex ne déposent d'équivalent structuré dans le dépôt. Le gate est
> archivé (`ARCHIVES/Tools/AGENT_WORKFLOW/scripts/README.md`) plutôt que laissé à faire semblant
> de vérifier (même décision que l'abandon de `PLC_TESTS` le 2026-07-26, `docs/TASK_CONTEXT.md`).
> Ce document garde les principes de choix de modèle (toujours valides) et documente franchement
> que le respect de ces principes n'est **plus vérifié automatiquement** — seulement par la
> validation humaine et la double revue A/B (`SAFETY_POLICY.md`).

## 🧭 Deux notions à ne pas confondre

| Notion | Exemple | Ce que ça change |
|---|---|---|
| **Famille rapide** | `gemini-3.5-flash`, `*-mini`, `*-nano`, `haiku` | Petit modèle conçu pour la vitesse |
| **Effort réduit** | `claude-sonnet-5:low`, `nemotron-550b:low` | Gros modèle **bridé** |

Un `scout` qui repère des fichiers ne juge rien : les deux lui conviennent.
Un `reviewer` juge : la famille rapide lui est **interdite**, l'effort réduit est **signalé**.

## 👤 Rôles et modèles

| Rôle | Ce qu'il fait | Famille rapide | Effort |
|---|---|---|---|
| `scout` | Repérage, cartographie, « où est X » | ✅ **recommandée** | `:low` |
| `researcher` | Collecte, lecture documentaire | ✅ autorisée | `:medium` |
| `worker` | Produit du code | ⛔ interdite | `:high` |
| `reviewer` | Juge le travail | ⛔ interdite | `:high` |
| `oracle` | Tranche une question de conception | ⛔ interdite | `:high` |

### 🆕 Modèles rapides — où ils gagnent vraiment

`antigravity/gemini-3.5-flash-medium` · `antigravity/gemini-3.5-flash-high`

Pour un `scout` (repérage, cartographie), un modèle rapide n'est pas un compromis, c'est **le bon
outil** — inutile de payer un gros modèle bridé pour du repérage.

| Usage | Modèle |
|---|---|
| `scout` — repérage, cartographie | `flash-medium` |
| Résumé, reformulation doc, C0–C1 non-safety | `flash-medium` |
| Pré-lecture avant une revue coûteuse (débroussaillage) | `flash-high` |
| **Revue A/B C4, safety, normes, redondance** | ⛔ **interdit** |

L'interdiction safety n'est pas un jugement sur le modèle : c'est la règle existante du projet
(Ponytail déjà banni du safety) appliquée par cohérence à toute la famille rapide.

## 🔀 Multi-modèle — pas la règle par défaut

Voie exécutée par l'**orchestrateur** (agent Claude Code) qui délègue selon le besoin, via les
agents natifs disponibles : **antigravity**, **Codex**, ou un **fork Claude Code**.

| Voie | Analyse | Revue | Double A/B |
|---|---|---|---|
| C0–C1 Fast | orchestrateur seul | — | — |
| C2 Standard | modèle fort | avis ciblé optionnel (1 agent natif read-only) | — |
| C3 Standard | modèle fort | 1 agent natif read-only si le risque le justifie | — |
| C4 Safety | modèle fort **High Effort** | 2 agents natifs A/B read-only parallèles | ✅ **obligatoire** |
| C4 + divergence | orchestrateur + humain | l'humain tranche | — |

## 🔴 Double revue parallèle A/B (C4 uniquement)

**Déclencheur** : TEST_DESIGN, ST généré, toute revue safety C4.

1. Agent A (ex. antigravity) reçoit le contexte complet (contrat de tâche + code), en read-only.
2. Agent B (ex. Codex, ou un fork Claude Code) reçoit **exactement le même contexte**, sans voir
   le résultat de A.
3. L'orchestrateur attend, lit, compare :
   - consensus → synthèse présentée à l'humain ;
   - divergence (≥1 point contradictoire) → 🚨 alerte + positions A/B côte à côte.

**Règles** : pas de fusion automatique · aucun agent ne commit ni ne valide la safety ·
Ponytail et famille rapide interdits sur toute analyse safety/normative/redondance.

## ⚠️ Vérification — non automatique, tracée dans le contrat de tâche

Sans artefact structuré équivalent à celui de Pi Subagents, le respect de ces règles **n'est plus
contrôlé par un gate**. La garantie repose sur :

- `models_allowed` déclaré dans le `TASK_CONTEXT` de la tâche (`templates/task_contract.yaml`) ;
- `human_validation_required` — l'automaticien vérifie que la voie suivie (simple/double revue)
  correspond à la criticité annoncée, avant tout chargement CODESYS ;
- le devoir d'alerte de l'orchestrateur si un agent délégué s'écarte de ces règles.

Si un futur outil de délégation dépose un artefact structuré (modèle/rôle réellement exécuté),
`ARCHIVES/Tools/AGENT_WORKFLOW/scripts/G220_check_model_routing.py` est réutilisable comme base :
seule sa source de données (`.pi-subagents/`) est morte, sa logique de détection reste valide.

## 🔌 Fournisseurs

Catalogue connu : `antigravity/` · `openai/` (Codex) · `nvidia/` · `omni/` · `gh/` ·
`openrouter/` · `ollama/`.
Les clés ne sont **jamais** stockées dans le dépôt.
