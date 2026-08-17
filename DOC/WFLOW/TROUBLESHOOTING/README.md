# Dossier de Depannage & Fiches d Incidents (Troubleshooting)

Ce dossier regroupe les gabarits et fiches d analyse de resolution d incidents / depannages reels survenus sur le banc d essais ou sur la machine.

---

## Contenu

| Fichier | Role / Description |
|---|---|
| [TEMPLATE_Troubleshooting.md](TEMPLATE_Troubleshooting.md) | Gabarit standardise pour toute nouvelle fiche d incident / depannage |
| [GUIDE_Troubleshooting.md](GUIDE_Troubleshooting.md) | Documentation complete : comment remplir chaque section, exemples, cas limites CODESYS |
| [FICHES/TROUBLESHOOTING_DeadmanArmed_20260815.md](FICHES/TROUBLESHOOTING_DeadmanArmed_20260815.md) | Fiche d analyse : Invariant Safety DeadmanArmed (ISO 13849) & confort banc de simulation |
| [FICHES/TROUBLESHOOTING_NonReference_DescenteBloquee_20260816.md](FICHES/TROUBLESHOOTING_NonReference_DescenteBloquee_20260816.md) | Fiche d analyse : Blocage de descente benne non référencée |

---

## Methodologie d Analyse
Toute nouvelle fiche de depannage doit etre creee a partir de [TEMPLATE_Troubleshooting.md](TEMPLATE_Troubleshooting.md) et renseigner :
1. **Symptome & Contexte** (Comportement observe, variables CODESYS incriminees).
2. **Chaine causale & Diagnostic racine** (Analyse de code ST / Safety).
3. **Impacts & Decision Safety** (Respect ISO 13849 vs Confort de banc).
4. **Action corrective & Garde-fous** (Regle ix: + guard:).

---

## 🕵️ Skill & Prompt associes

- **Skill** : `.dsh/skills/troubleshooting/SKILL.md` (DeepSeek Harness) et `.claude/skills/troubleshooting/SKILL.md` (Claude Code) — declenchee par « cherche le blocage » / « pourquoi ca bloque » / « diagnostic » / « troubleshooting ».
- **Methode complete** : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` (contexte fige, arbre des causes 6 categories, tracage inverse, critere d'arret, cas limites CODESYS).
- **Workflow** : etape « Diagnostic / Recherche de blocage » dans `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`.

