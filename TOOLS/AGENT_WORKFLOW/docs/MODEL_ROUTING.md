# Routage des modèles

> 🔧 **Révisé 2026-07-29.** La version précédente annonçait `omni/cc/claude-sonnet-5` comme
> modèle de revue privilégié. Les 53 tâches réellement exécutées disaient autre chose
> (`omni/cx/gpt-5.6-terra` en tête, 18×). Une règle de routage écrite mais jamais vérifiée
> ne route rien — d'où le garde-fou `check_model_routing.py`, qui relit ce qui a *réellement* tourné.

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

Aujourd'hui le `scout` tourne sur `nemotron-550b:low` ou `claude-sonnet-5:low` : on paie un très
gros modèle bridé pour faire du repérage. Un modèle rapide n'est pas un compromis sur ce poste,
c'est **le bon outil**.

| Usage | Modèle |
|---|---|
| `scout` — repérage, cartographie | `flash-medium` |
| Résumé, reformulation doc, C0–C1 non-safety | `flash-medium` |
| Pré-lecture avant une revue coûteuse (débroussaillage) | `flash-high` |
| **Revue A/B C4, safety, normes, redondance** | ⛔ **interdit** |

L'interdiction safety n'est pas un jugement sur le modèle : c'est la règle existante du projet
(Ponytail déjà banni du safety) appliquée par cohérence à toute la famille rapide.

## 🔀 Multi-modèle — pas la règle par défaut

| Voie | Analyse | Revue | Double A/B |
|---|---|---|---|
| C0–C1 Fast | Pi seul | — | — |
| C2 Standard | modèle fort | avis ciblé optionnel | — |
| C3 Standard | modèle fort | 1 Pi Subagent read-only si le risque le justifie | — |
| C4 Safety | modèle fort **High Effort** | 2 Pi Subagents A/B read-only parallèles | ✅ **obligatoire** |
| C4 + divergence | Pi + humain | l'humain tranche ; Herdr sur demande explicite | — |

## 🔴 Double revue parallèle A/B (C4 uniquement)

**Déclencheur** : TEST_DESIGN, ST généré, toute revue safety C4.

1. Agent A reçoit le contexte complet (contrat de tâche + code), en read-only.
2. Agent B reçoit **exactement le même contexte**, sans voir le résultat de A.
3. Pi attend, lit, compare :
   - consensus → synthèse présentée à l'humain ;
   - divergence (≥1 point contradictoire) → 🚨 alerte + positions A/B côte à côte.

**Règles** : pas de fusion automatique · aucun agent ne commit ni ne valide la safety ·
Ponytail et famille rapide interdits sur toute analyse safety/normative/redondance.

## ✅ Vérification — le routage est contrôlé, plus seulement déclaré

Chaque `.pi-subagents/artifacts/*_meta.json` enregistre le modèle **réellement exécuté**.
La preuve est donc déjà dans le dépôt ; il suffit de la lire.

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G220_check_model_routing.py            # gate (bloquant)
python TOOLS/AGENT_WORKFLOW/scripts/G220_check_model_routing.py --inventory # qui a fait quoi
```

| Contrôle | Détecte |
|---|---|
| `M1` | famille rapide sur un rôle de jugement — **erreur** (mention renforcée si sujet safety) |
| `M2` | effort réduit sur un rôle de jugement — avertissement |
| `M4` | fournisseur hors catalogue — routage non maîtrisé |

📌 Les modèles autorisés d'une tâche se déclarent dans son **contrat de tâche**
(`models_allowed`), pas dans un réglage séparé — voir `templates/task_contract.yaml`.

## 🔌 Fournisseurs

Catalogue connu : `omni/` · `nvidia/` · `antigravity/` · `gh/` · `openrouter/` · `ollama/`.
Les clés ne sont **jamais** stockées dans le dépôt.
