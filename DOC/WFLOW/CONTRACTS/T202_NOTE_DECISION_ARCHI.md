# T202 — Note de décision d'architecture (A1 / A2 / A6 / A7)

> Statut : **PROPOSITION — en attente de validation humaine.**
> Rédigée par Claude Code (orchestrateur), 2026-08-31.
> Aucune ligne de `CODE/` n'est modifiée tant que cette note n'est pas validée.

---

## Contexte

Audit `CODE/G_CYCLE` (2026-08-31). Le socle des 4 FB est conforme (contrats standard,
`ST_Fault`/`ST_Lifecycle`/`FB_FaultCore`, `Reset` sur front, repli `STABILIZING`, enum
`E_CycleStep` == AF-04 §4.2). Les points ci-dessous demandent un arbitrage **avant** patch.

`FB_Cycle` est `Enable = (Mode = SEMI_AUTO)`. `FB_DiveSearch`, `FB_ExtractionAssist` sont
`Enable = (Mode = MAINT_N1 OR MAINT_N2) AND TglEnable…`. `FB_MachineHomingCycle` tourne au
rang acquisition (PRG_02) et **gate** SEMI_AUTO via `FB_Modes` (`SemiAutoRefusedMachineHoming
:= SEMI_AUTO AND NOT MachineHomed`). Les chemins SEMI_AUTO et MAINT sont donc **mutuellement
exclusifs par mode**.

---

## A1 — Algorithmes dédoublés SEMI_AUTO (inline `FB_Cycle`) vs MAINT (FB assistants)

| Fonction | SEMI_AUTO (`FB_Cycle`) | MAINT (FB dédié) | Écart de robustesse |
|---|---|---|---|
| Recherche de fond | X4 `X4_DESCEND_OPEN` → X5 sur `KoboldContactFond` **brut** (L455). Aucune validation de fenêtre d'immersion, aucun timeout dédié. | `FB_DiveSearch` : fenêtre immersion `ImmersionUpper/Lower_M`, `CalculatedImmersion/BottomTimeout`, interdiction palier 5, fautes de cohérence de séquence. | **Élevé** — X4 ne détecte ni immersion aberrante ni blocage descente. |
| Fermeture + remontée contrôlée | X6/X7/X8 (`CLOSE_BUCKET` → `CTRL_ASCENT` → `ASCENT_LOADED`). X7 a déjà : tolérance écart codeurs `CtrlAscentToleranceM`, `StabilizationTimer`, écart de vitesse M1/M2 confirmé, `StepMaxTimer`. | `FB_ExtractionAssist` : `CLOSING_BUCKET` → `CONTROL_ASCENT` → `NOMINAL_ASCENT`, backstop fermeture, timeout décollage calculé, coupure même-scan sur défaut synchro/capteurs. | **Faible à moyen** — X7 couvre l'essentiel ; manque le backstop de fermeture benne. |
| Référencement | X1 `X1_HOMING` : `IF NOT HomedM1 OR NOT HomedM2` → montée lente + `HomingRequest`. | `FB_MachineHomingCycle` : producteur **unique** de la qualification machine (datum M1/M2 + commit benne atomique). | Branche X1 **quasi inatteignable** : SEMI_AUTO est refusé si `NOT MachineHomed`, donc `HomedM1 AND HomedM2` est vrai à l'entrée → X1 tombe directement en X2. |

### Options

- **Option 1 — Fusion complète** (rebuild du séquenceur autour de briques communes).
  ❌ Non recommandé : blast radius C4 sur machine réelle ; les machines d'état MAINT
  (confirmations opérateur, toggles bypass, plages `OperatorActionId` distinctes) ne sont
  pas isomorphes au pilotage joystick continu + homme-mort de SEMI_AUTO. Gain incertain,
  risque certain.

- **Option 2 — Séparation assumée + fermeture du seul écart critique** ✅ **RECOMMANDÉ**
  1. **Fond** : extraire la *qualification de fond Kobold* (fenêtre immersion + timeout +
     interdiction palier) dans une brique pure sans machine d'état de mode
     (ex. `FB_KoboldBottomQualifier`, ou sortie « headless » réutilisable de `FB_DiveSearch`),
     **appelée par les deux chemins**. `FB_Cycle` X4 consomme sa sortie `BottomConfirmed`
     au lieu du DI brut. → aligne aussi A2 (spec AF-04 §4.2 dit « fond validé (FB_DiveSearch) »).
  2. **Extraction** : garder X6/X7/X8 séparés. Ajouter uniquement le **backstop de fermeture
     benne** manquant dans X6 (parité avec `CfgBucketCloseTimeout`). Pas de fusion.
  3. **Référencement** : **supprimer** la branche morte `IF NOT HomedM1 OR NOT HomedM2` de
     X1_HOMING (garder X1 comme simple étape de passage / transition immédiate vers X2), ou
     retirer X1 du grafcet si AF-04 le permet. `FB_MachineHomingCycle` reste producteur unique.
  4. **Documenter** dans AF-04 que la séparation SEMI_AUTO / MAINT est volontaire et pourquoi.

- **Option 3 — Statu quo + doc uniquement.**
  ❌ Laisse l'écart de sécurité X4 (aucune validation immersion en descente automatique).

### Recommandation : **Option 2.**

---

## A2 — Non-conformités spec (traitées avec A1)

- **X5 vs AF-04 §4.2** : réglé par A1/Option 2 point 1 (X4 consomme la qualification de fond).
- **Nom `FB_ExtractionSequence` (spec) vs `FB_ExtractionAssist` (code)** : trancher un nom
  unique. Proposition : garder le **code** (`FB_ExtractionAssist`, déjà lié partout,
  `TglEnableExtractionSequence` mis à part) et corriger AF-04 §1/§10. → tâche T191 (doc) ou
  micro-patch ici.
- **Branche X1_HOMING** : voir A1 point 3.

---

## A6 — `SelTarget = 2` (P2) ignoré en X2

`X2_WORK_POS_SELECT` ne traite que `SelTarget ∈ {1, 3, 4}` (L397). `SelTarget = 2` est listé
dans le commentaire d'interface (L26 « 2=P2 ») mais aucune transition ne le consomme →
blocage silencieux en X2 (seul `StepMaxTimer` faute, et uniquement si joystick défléchi).

**Proposition** : P2 n'est pas une cible de cycle automatique (c'est un point de translation
manuel). → **retirer `2=P2` du commentaire d'interface** L26 et documenter que X2 n'accepte
que Trémie / P1 / Maintenance. Si au contraire P2 doit devenir une cible auto → spec AF-04 à
compléter d'abord (hors scope T202, remonter besoin).

---

## A7 — Hétérogénéité des interfaces dans `G_CYCLE`

3 conventions : `FB_Cycle` (~45 scalaires plats + sorties struct), `FB_ExtractionAssist`
(~20 scalaires plats), `FB_DiveSearch` / `FB_MachineHomingCycle` (bus struct `Inputs`/`Outputs`).

**Proposition** : **hors scope implémentation T202.** L'homogénéisation d'interface FB est
déjà le sujet de **T194** (O3/O4/O5). Recommandation : élargir T194 au dossier G_CYCLE plutôt
que dupliquer l'effort ici. T202 se limite à *noter* la cible (bus struct typé, AF-03 §3).

---

## Découpage T202 après validation de cette note

| Sous-tâche | Contenu | Dépend de | Comportement |
|---|---|---|---|
| **T202-A** | Cette note validée (A1/A2/A6/A7) | — | doc seule |
| **T202-B** | A4 — retrait code mort `FB_Cycle` + câblage PRG_03 | — | bit-identique |
| **T202-C** | A5 — 1 permis homme-mort + méthode `NeutralizeCommands` | — | bit-identique |
| **T202-D** | A3 — `WaitingResume`/`PausedState` en VAR_OUTPUT + conso `FB_TroubleshootingView` | — | corrige recalcul externe |
| **T202-E** | A1 Option 2 (brique fond partagée + backstop X6 + branche X1 morte) | T202-A | **change comportement** — tests + revue humaine |
| **T202-F** | Revue finale indépendante + non-régression (bundle, G200, 21 gates) | B, C, D, E | — |

B / C / D sont des nettoyages sans changement de comportement → parallélisables, faible risque.
E est le seul lot à impact machine → contrat dédié, tests STruCpp, revue humaine du diff.
