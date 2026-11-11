# 📚 Répertoire des Prompts Système des Personas Spécialisés

> **Dossier Canonique** : `DOC/WFLOW/PROMPTS/SPECIALISTS/`  
> **Gouvernance** : Chaque persona dispose de son fichier prompt `.md` dédié, synchronisé avec les spécifications Fonctionnelles Blocs (`OOA`) sous `TOOLS/AGENT_WORKFLOW/specialists/`.

---

## 📋 Index des Fichiers de Prompts

| Rôle | Persona FB | Fichier Prompt Markdown | Spécification Complète |
|---|---|---|---|
| `safety` | `FB_Agent_Safety` | [`PROMPT_FB_Agent_Safety.md`](PROMPT_FB_Agent_Safety.md) | [`FB_Agent_Safety.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_Safety.md) |
| `plc` | `FB_Agent_PLC` | [`PROMPT_FB_Agent_PLC.md`](PROMPT_FB_Agent_PLC.md) | [`FB_Agent_PLC.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_PLC.md) |
| `hmi` | `FB_Agent_HMI` | [`PROMPT_FB_Agent_HMI.md`](PROMPT_FB_Agent_HMI.md) | [`FB_Agent_HMI.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_HMI.md) |
| `testing` | `FB_Agent_Testing` | [`PROMPT_FB_Agent_Testing.md`](PROMPT_FB_Agent_Testing.md) | [`FB_Agent_Testing.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_Testing.md) |
| `standards` | `FB_Agent_Standards` | [`PROMPT_FB_Agent_Standards.md`](PROMPT_FB_Agent_Standards.md) | [`FB_Agent_Standards.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_Standards.md) |
| `challenger` | `FB_Agent_Challenger` | [`PROMPT_FB_Agent_Challenger.md`](PROMPT_FB_Agent_Challenger.md) | [`FB_Agent_Challenger.md`](../../../TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_Challenger.md) |

---

## ⚡ Commandes CLI de Visualisation

Pour afficher directement les prompts système depuis le terminal :

```powershell
# 1. Lister tous les prompts et leurs fichiers .md :
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --list-prompts

# 2. Afficher le prompt système complet d'un spécialiste :
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --show-prompt safety
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --show-prompt standards
```
