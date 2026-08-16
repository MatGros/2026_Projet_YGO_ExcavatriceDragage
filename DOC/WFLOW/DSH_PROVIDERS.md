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

## 🧠 Modèles disponibles

| ID (à utiliser) | Display name (affichage GUI) |
|---|---|
| `codex/gpt-5.6-luna` | codex/GPT 5.6 Luna |
| `codex/gpt-5.6-sol` | codex/GPT 5.6 Sol |
| *(à compléter après `réfetch` dans la GUI)* | |

> L'**ID** est ce qu'on passe à l'override `model`. Le **display name** ne sert qu'à l'affichage.

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
