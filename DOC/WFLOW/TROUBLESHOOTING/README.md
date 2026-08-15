# Dossier de Depannage & Fiches d Incidents (Troubleshooting)

Ce dossier regroupe les gabarits et fiches d analyse de resolution d incidents / depannages reels survenus sur le banc d essais ou sur la machine.

---

## Contenu

| Fichier | Role / Description |
|---|---|
| [TEMPLATE_Troubleshooting.md](TEMPLATE_Troubleshooting.md) | Gabarit standardise pour toute nouvelle fiche d incident / depannage |
| [TROUBLESHOOTING_DeadmanArmed_2026-08-15.md](TROUBLESHOOTING_DeadmanArmed_2026-08-15.md) | Fiche d analyse : Invariant Safety DeadmanArmed (ISO 13849) & confort banc de simulation |

---

## Methodologie d Analyse
Toute nouvelle fiche de depannage doit etre creee a partir de [TEMPLATE_Troubleshooting.md](TEMPLATE_Troubleshooting.md) et renseigner :
1. **Symptome & Contexte** (Comportement observe, variables CODESYS incriminees).
2. **Chaine causale & Diagnostic racine** (Analyse de code ST / Safety).
3. **Impacts & Decision Safety** (Respect ISO 13849 vs Confort de banc).
4. **Action corrective & Garde-fous** (Regle ix: + guard:).
