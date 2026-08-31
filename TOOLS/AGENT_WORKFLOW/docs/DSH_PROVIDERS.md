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

## 🔌 Provider `opencode-go` (validé 2026-08-31)

| Info | Valeur |
|---|---|
| **Nom de la route** | `opencode-go` |
| **Clé API** | `OPENCODE_GO_API_KEY` |
| **Modèle validé** | `glm-5.2` (test PONG via `workflow`, override `provider`/`model`) |

- ✅ `provider: "opencode-go"` + `model: "glm-5.2"` → réponse reçue (2026-08-31). Usages :
  **réflexion / second avis** et **test comparatif** (ex. vs `deepseek-v4-flash:cloud` local).
- ❌ `glm-5.2` via `omniroute` (`ollamacloud/glm-5.2`) → échec (2 tentatives 2026-08-31) :
  pour glm-5.2, la route est **`opencode-go`**, pas omniroute.
- ✅ **Prompt lourd mesuré 2026-08-31** (test réel) : préambule + contrat 5 objectifs + FB ST
  intégral 426 lignes (~7k tokens) → analyse safety structurée reçue, **sans timeout**. Qualité :
  constats concordants avec l'analyse de référence de l'orchestrateur + trouvailles propres
  (ex. contacteur tardif sous alarme, Reset annulant le lockout) ; hypothèses déclarées, pas
  devinées. **Utilisable pour revue/audit.**
- ⚠️ Limite observée : grille de criticité C0..C4 non fournie inline → échelle improvisée
  (correctement signalée par l'agent). Inclure la grille ou un pointeur dans les futures
  délégations d'analyse.

---

## 🧠 Modèles utilisables pour les sous-agents (matrice 2026-08-28)

> Testé sur un **prompt court** (« PONG ») + un **prompt lourd de ~7,6k tokens** (taille d'une revue de
> code FB réelle). Le critère `omniroute_subagent.py` : réponse non vide **avant le timeout** (300 s
> par défaut ; les entrées ci-dessous sont mesurées à `TMO=95..180 s`).
> ⚠️ Un modèle « OK sur prompt court » mais qui **timeout sur prompt lourd** est **inutilisable pour une
> revue/audit** — c'est le cas d'usage principal.

### ✅ Catalogue retenu (planning / orchestration / gros refactors — agents de codage & sous-agents)

| ID (`--model`) | Endpoint | Prompt lourd | Rôle |
|---|---|---|---|
| `auto/best-reasoning` | omniroute | ✅ **~15 s** | ⭐ **défaut** — planning, orchestration, arbitrage, audit |
| `auto/best-coding` | omniroute | ✅ ~15 s | revue / refactor / génération de code |
| `auto/best-fast` | omniroute | ✅ ~16 s | itération rapide, passes légères |
| `codex/gpt-5.6-terra-medium` | omniroute | ✅ ~90 s | revue profonde (plus lent, à réserver aux gros lots) |

> Hors catalogue mais **techniquement viables** en dépannage (plus lents, non retenus par défaut) :
> `codex/gpt-5.6-sol-medium` (~140 s), `deepseek-v4-flash:cloud` natif `:11434` (~130 s, `--num-ctx 16384`).

### ❌ À NE PAS utiliser — timeout systématique sur prompt lourd

| ID | Endpoint | Raison |
|---|---|---|
| `codex/gpt-5.6-terra-high`, `codex/gpt-5.6-sol-max`, `codex/gpt-5.6-luna-high` | omniroute | > 180 s (raisonnement « high » trop lent) |
| `ollamacloud/glm-5.2`, `ollamacloud/deepseek-v4-flash` | omniroute | > 95 s |
| `claude/claude-sonnet-5` | omniroute | > 95 s (route omniroute lente — pour Sonnet, utiliser l'agent natif Claude Code) |
| `kc/stepfun/step-3.7-flash:free` | omniroute | > 95 s |
| `nvidia/nvidia/nemotron-3-super-120b-a12b` | omniroute | > 95 s |
| `qwen3:8b`, `qwen3.8:27b`, `gemma4:e4b`, `gemma4:latest` | natif local | > 100 s (modèles locaux : OK prompt court seulement) |

> Les variantes `-high` / `-max` répondent si on relève le timeout à ~420 s, mais un sous-agent qui met
> 5–7 min n'est pas exploitable en boucle de revue. Préférer `auto/best-reasoning` (même qualité observée
> sur les revues T167-CR, en 15 s).

---

## 🚀 Méthode : lancer un agent sur un autre modèle

### Outil `workflow` (recommandé — override `provider`/`model` natif)

```js
const resultat = await agent("Ta tâche ici", {
  provider: "omniroute",
  model: "auto/best-reasoning",
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
modèle non-Ollama. Défaut = `auto/best-reasoning` (cf. matrice ci-dessus).
```bash
set OMNIROUTE_API_KEY=sk-...            # jamais en dur dans le repo (cf. ~/.dsh/.credentials.yaml)
python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --list-models
python TOOLS/AGENT_WORKFLOW/scripts/omniroute_subagent.py --file CONTRAT.md --model auto/best-reasoning --output RESULTAT.md
```
Timeout via `OMNIROUTE_TIMEOUT_S` (défaut 300). Injecte `subagent_preamble.md` comme les autres runners.

---

## ✅ Vérifié (REX 2026-08-16)

- ✅ `workflow` + `provider: "opencode-go"` + `model: "glm-5.2"` → PONG prompt court + **analyse safety FB 426 lignes (~7k tokens) reçue structurée, sans timeout** (2026-08-31) — validé revue/audit.
- ✅ `workflow` + `provider: "omniroute"` + `model: "auto/best-reasoning"` → réponse en ~15 s sur prompt lourd (matrice 2026-08-28).
- ⚠️ `codex/gpt-5.6-*-high` / `*-max`, `ollamacloud/*`, `claude/claude-sonnet-5` (via omniroute) : **timeout** sur prompt lourd (matrice 2026-08-28).
- ✅ `ollama_subagent.py` + `model: "deepseek-v4-flash:cloud"` → réponse locale instantanée reçue.
- ❌ `omni-route` / `omni_cloud` / `omniRoute` / `omni-cloud` → échec (mauvais nom de route).

---

## 📌 Règles de délégation (rappel AGENTS.md)

- Coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de chaque tâche déléguée (automatique via `ollama_subagent.py`).
- La **validation finale** reste à l'orchestrateur (lecture du `git diff` réel).
- ⚠️ **Aucun commit sans validation humaine explicite**.

