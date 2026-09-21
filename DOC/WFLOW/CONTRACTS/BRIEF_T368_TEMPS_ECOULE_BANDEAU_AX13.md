=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

`FB_CycleSemiAuto.st:151-152` (T347) expose déjà `CurrentCycleElapsed_Min`/
`_S` (temps écoulé du cycle en cours, calculé `:344-345`), mais ces champs
ne sont câblés vers **aucun affichage** actuellement.

Demande utilisateur 2026-09-21, 2 volets :

1. Afficher le temps écoulé (min/s) **à côté du bandeau mode**
   (`[SIMULATION][SEMI-AUTO][CYCLE AUTO]`), format `09min05s`.
2. Le message de l'étape AX13 (égouttage godet) doit inclure le temps —
   actuellement `CycleStateStr := 'AX13 - Egouttage du godet en cours'`
   (`FB_CycleSemiAuto.st:1431`), sans aucune indication de durée.

## 2. Objectif

1. **Bandeau mode** : trouver où vit l'affichage `[MODE]` actuel (chercher
   dans `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` ou `GVL_IHM`),
   ajouter le temps écoulé formaté `MMminSSs` juste à côté, actif
   uniquement pendant un cycle en cours (`Lifecycle.Busy`).
2. **Message AX13** : enrichir `CycleStateStr` (`:1431`) pour inclure le
   temps écoulé (`CurrentCycleElapsed_Min`/`_S`) OU le temps restant
   (`DrainTimeRemaining`, déjà existant `:155` — à choisir : écoulé ou
   restant, préciser dans la restitution lequel a été retenu et pourquoi).
3. Vérifier `G408` (messages IHM <= 70 caractères) après modification.

## 3. Devoir de challenge

- Ne pas dupliquer un calcul déjà existant (`CurrentCycleElapsed_Min`/`_S`,
  `DrainTimeRemaining`) — réutiliser, pas recalculer.
- Vérifier que l'affichage du bandeau mode n'est actif que pendant un cycle
  réellement en cours (pas affiché à l'arrêt, ni figé à une vieille valeur).

## 4. Livrables

- Diff réel (fichiers exacts à déterminer par l'agent après lecture).
- Preuve CI de non-régression + test du nouvel affichage.
- Bundle + diff bundle + G200 --report + gates palier C (G408 notamment).
- Contrat `TASK_CONTRACT_T368_*.yaml` (C2).

## 5. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
