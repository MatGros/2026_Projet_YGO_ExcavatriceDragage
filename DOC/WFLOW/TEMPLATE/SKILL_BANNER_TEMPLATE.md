# 📛 Gabarit de bannière de déclenchement — Skills agents

> Gabarit **unique** pour toutes les bannières de déclenchement d'une skill ou d'un workflow agent
> (troubleshooting, task-planner, briefing session, ...). TDAH-friendly :
> un bandeau visuel immédiat + une ligne d'action, rien d'autre avant le contenu.

## Règle

1. **Largeur 60 caractères** `=` (uniforme partout — pas de 40 vs 60).
2. **3 lignes** : émoji + titre / cadre vide / cadre vide.
3. **1 ligne d'action** juste après (le *quoi* en une phrase).

## Gabarit brut (à copier)

```text
============================================================
<ÉMOJI> <NOM DU MODE / SKILL> — ACTIF
============================================================
```

Puis, en 1 ligne : `« <sujet précis de l'action en cours> »`.

## Exemples appliqués

```text
============================================================
🕵️ MODE DÉPANNAGE / TROUBLESHOOTING ACTIF
============================================================
```
→ ligne d'action : `Diagnostic : DeadmanArmed tombe à 0 en commande descente`

```text
============================================================
🗂️ WORKFLOW TÂCHES / TASK-PLANNER ACTIF
============================================================
```
→ ligne d'action : `Prise en charge de la tâche T150 (C1) par l'agent DSH-02`

## Rappel

- Bannière affichée **immédiatement** au déclenchement, **avant** toute autre action.
- **Pas de format différent** d'une skill à l'autre : un seul gabarit, partout.
- Ce gabarit vit ici (source unique) — les skills **pointent** vers lui, ne le recopient pas.
