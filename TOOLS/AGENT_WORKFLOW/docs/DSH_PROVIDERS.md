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

### Outil `ollama_subagent.py` (Local Ollama / DeepSeek — Zéro quota cloud)

Pour déléguer directement à l'instance locale Ollama (`deepseek-v4-flash:cloud`, `qwen3.8:27b`, etc.) :
```bash
python TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py --prompt "Analyse de sécurité..." --model deepseek-v4-flash:cloud
python TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py --file CONTRAT.md --output RESULTAT.md --num-ctx 16384 --timeout 400
```
⚠️ **`num_ctx` par défaut d'Ollama ≈ 4k tokens → TRONQUE SILENCIEUSEMENT le prompt d'entrée** (REX 2026-08-28) :
un gros contrat/diff arrive amputé et l'auditeur croit qu'il manque des infos. Le runner force `num_ctx=8192`
par défaut et **avertit** si l'entrée dépasse 90 % du contexte. Options : `--num-ctx N` (fenêtre),
`--num-predict N` (sortie), `--timeout S`. Env : `OLLAMA_NUM_CTX`, `OLLAMA_TIMEOUT_S`.
(`num_predict: -1` fait échouer certains endpoints en HTTP 400 → n'est envoyé que si > 0.)

### Outil `omniroute_subagent.py` (Fallback — gateway OpenAI-compatible `omniroute`)

Même rôle, mais via le gateway `omniroute` (`http://localhost:20128/v1`, API OpenAI `chat/completions`).
À utiliser quand `ollama_subagent.py` (endpoint natif `/api/generate`) échoue ou timeout, ou pour un
modèle non-Ollama (`codex/gpt-5.6-*`, `ollamacloud/glm-5.2`, `auto/best-reasoning`, `claude/claude-sonnet-5`).
```bash
set OMNIROUTE_API_KEY=sk-...            # jamais en dur dans le repo (cf. ~/.dsh/.credentials.yaml)
python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --list-models
python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --file CONTRAT.md --model codex/gpt-5.6-terra-high --output RESULTAT.md
```
Timeout via `OMNIROUTE_TIMEOUT_S` (défaut 300). Injecte `subagent_preamble.md` comme les autres runners.

---

## ✅ Vérifié (REX 2026-08-16)

- ✅ `workflow` + `provider: "omniroute"` + `model: "codex/gpt-5.6-luna"` → agent lancé, réponse reçue.
- ✅ `ollama_subagent.py` + `model: "deepseek-v4-flash:cloud"` → réponse locale instantanée reçue.
- ❌ `omni-route` / `omni_cloud` / `omniRoute` / `omni-cloud` → échec (mauvais nom de route).

---

## 📌 Règles de délégation (rappel AGENTS.md)

- Coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de chaque tâche déléguée (automatique via `ollama_subagent.py`).
- La **validation finale** reste à l'orchestrateur (lecture du `git diff` réel).
- ⚠️ **Aucun commit sans validation humaine explicite**.

