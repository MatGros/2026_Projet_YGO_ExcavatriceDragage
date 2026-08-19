# DSH — Providers & Délégation multi-modèles

> 🎯 **But** : ne plus redécouvrir les noms de provider/modèles à chaque session.
> Tout agent DSH qui veut lancer un sous-agent sur un **autre modèle** lit ce fichier.

---

## 🔌 Provider DSH configuré

| Info | Valeur |
|---|---|
| **Nom de la route** | `omniroute` (sans tiret, sans underscore) |
| **Base URL** | `http://localhost:20128/v1` |
| **Clé API** | `OMNIROUTE_API_KEY` (dans `~/.dsh/.credentials.yaml`) |
| **Type** | Provider configurable pi-ai (`llm-pi-ai`) |

⚠️ Le nom de route est **`omniroute`**, PAS `omni-route` / `omni_cloud` / `omniRoute` / `omni-cloud`.
C'est la cause n°1 d'échec d'override (REX 2026-08-16).

---

## 🧠 Modèles disponibles (catalogue `omniroute`)

> L'**ID** est ce qu'on passe à l'override `model`. Le **display name** ne sert qu'à l'affichage.
> ⚠️ Catalogue à **`réfetch`** dans la GUI si un ID ci-dessous 404 — l'ID exact prime toujours.

### ⚡ Rapides — raisonnement rapide, recherche, modif de code

| ID (à utiliser) | Statut (test 2026-08-16) |
|---|---|
| `codex/gpt-5.6-luna` | ✅ répond |
| `kc/stepfun/step-3.7-flash:free` | ✅ répond (gratuit — raisonnement rapide) |
| `ollamacloud/glm-5.2` | ✅ répond · ⭐ **recommandé** (qualité validée utilisateur) |
| `nvidia/nvidia/nemotron-3-super-120b-a12b` | ✅ répond |

### 🛠️ Profonds — raisonnement agentique, codage profond, refactoring

| ID (à utiliser) | Statut (test 2026-08-16) |
|---|---|
| `claude/claude-sonnet-5` | ✅ répond (préfixe `claude/`) |
| `codex/gpt-5.6-terra` | ✅ répond |
| `codex/gpt-5.6-sol` | ✅ répond |

> ✅ **Seuls les modèles ci-dessus sont confirmés utilisables** via le harness.
> ⚠️ D'autres modèles existent côté gateway mais ne sont **pas** dans le catalogue harness
> `omniroute` → `LlmError('UNKNOWN_MODEL')` → **non utilisables** tant qu'ils ne sont pas ajoutés
> dans la GUI DSH (settings provider). Ne pas les intégrer tels quels.

---

## 🚀 Méthode : lancer un agent sur un autre modèle

### Outil `workflow` (recommandé — override `provider`/`model` natif)

```js
const resultat = await agent("Ta tâche ici", {
  provider: "omniroute",
  model: "codex/gpt-5.6-luna",
  label: "mon-agent"
});
```

- `provider` et `model` sont **indépendants** : on peut n'override que l'un des deux.
- Le résultat revient à l'orchestrateur qui **valide** (jamais l'agent producteur seul).

### Outil `subagent` / `subagent_fork` (délégation simple)

- Délégation 1–2 tâches ; le modèle cible dépend de la config, pas d'un paramètre direct.
- Pour forcer un modèle précis → préférer `workflow`.

---

## ✅ Vérifié (REX 2026-08-16)

- ✅ `workflow` + `provider: "omniroute"` + `model: "codex/gpt-5.6-luna"` → agent lancé, réponse reçue.
- ❌ `omni-route` / `omni_cloud` / `omniRoute` / `omni-cloud` → échec (mauvais nom de route).

---

## 📌 Règles de délégation (rappel AGENTS.md)

- Coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de chaque tâche déléguée.
- La **validation finale** reste à l'orchestrateur (lecture du `git diff` réel).
- ⚠️ **Aucun commit sans validation humaine explicite**.
