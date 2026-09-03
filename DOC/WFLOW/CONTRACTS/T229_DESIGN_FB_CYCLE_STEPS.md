# T229 — FB_Cycle : une config treuil unique par étape (note de conception)

> **STUB** créé rapidement pendant la MES 2026-09-02. À compléter.
> Contrat : `TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml`
> État actuel figé (référence non-régression) : `BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md`

---

## 1. Problème constaté

`X11_OPEN_DUMP` commande **au même scan** :
- M1 + M2 en **descente couplée** palier 1
- l'**ouverture benne** (`instBucket` → `Lifecycle.Busy = TRUE`)

L'ouverture benne = M2 déroule du câble par rapport à M1 → **écart M1/M2 volontaire** pendant une descente réelle.

Comme `instBucket.Lifecycle.Busy = TRUE`, `FB_WinchSync` est **entièrement désarmé** (via `AND NOT instBucket.Lifecycle.Busy` dans `PRG_04 instWinchSync.Enable`) :
- ✅ `FB_SyncContactor` (concordance ordres) coupé → correct (différentiel benne assumé)
- ⚠️ `FB_SyncDeviation` (écart position, avec `ActiveOffsetM`) coupé aussi → **perte de la détection d'un écart grossier** (treuil qui cale, frein collé, glissement) pendant une descente couplée réelle. Filet restant : `StepMaxTimer` 60 s + œil opérateur + homme-mort. Risque faible mais non nul sur machine noyée.

Réserve **pré-existante** (le terme `AND NOT Lifecycle.Busy` est antérieur au fix synchro unitaire `dd7ba1d5`).

---

## 2. Table étape → configuration treuil (état actuel, issue analyse agent)

| Étape | Treuils | Benne | `Lifecycle.Busy` | Synchro attendue |
|---|---|---|---|---|
| X0 PREPARATION | aucun | fermée | FALSE | sans objet |
| X1 HOMING | M1+M2 montée lente St1 | fermée | FALSE (`HomingLifecycle.Busy`=TRUE) | non (positions non fiables) |
| X2 WORK_POS_SELECT | aucun (translation M3) | fermée | FALSE | sans objet |
| X3 OPEN_BUCKET | aucun (`RunRequest:=FALSE`) | ouverture (différentiel) | **TRUE** | contacteurs NON ; écart souhaitable |
| X4 DESCEND_OPEN | **M1+M2 synchro St3** | ouverte fixe | FALSE | **OUI — anti-télescopage critique** |
| X5 BOTTOM_CONFIRMED | M1+M2 synchro St1 | ouverte | FALSE | OUI |
| X6 CLOSE_BUCKET | aucun | fermeture (différentiel) | **TRUE** | contacteurs NON ; écart souhaitable |
| X7 CTRL_ASCENT | **M1+M2 synchro St1** | ± fermée | FALSE | OUI (+ `SpeedMismatch` dédié) |
| X8 ASCENT_LOADED | **M1+M2 synchro St4** | fermée | FALSE | OUI |
| X9 DRAIN_PAUSE | aucun (`RunRequest:=FALSE`) | fermée | FALSE | sans objet |
| X10 TRANSLATE_DUMP | aucun (translation M3) | fermée | FALSE | sans objet |
| **X11 OPEN_DUMP** | **M1+M2 descente St1 + ouverture benne** | ouverture (différentiel) | **TRUE** | **contacteurs NON ; écart grossier souhaitable ⚠️** |
| X13 DONE_SYNC | aucun | ouverte | FALSE | sans objet |
| STABILIZING | aucun (repli défaut) | — | FALSE | sans objet |

**Seule X11 (et marginalement X3) mélange descente couplée + différentiel benne.**

---

## 3. Cible — split X11 en sous-étapes à config unique

1. **X11a — arrivée trémie** : arrêt treuils, M3 positionné trémie.
2. **X11b — ouverture benne** : M2 piloté seul (sélecteur logique « M2 seul » côté cycle), M1 tenu. `FB_SyncContactor` off, `FB_SyncDeviation` sans objet (M1 arrêté).
3. **X11c — repositionnement couplé (optionnel)** : sur demande opérateur (bit IHM à trancher — Q1), M1+M2 montée/descente **synchro** joystick, `FB_WinchSync` **actif** (écart + contacteurs). Validation opérateur → retour X11b.
4. Fin ouverture → cycle repart vers P1 (X2).

→ chaque sous-étape a UNE config treuil → gating synchro trivial, écart grossier surveillé pendant toute descente réellement couplée.

Généraliser le principe à tout le cycle : **aucune étape ne commande M1/M2 asymétrique hors d'une phase benne explicitement signée**.

---

## 4. Périmètre & garde-fous

- **Scope** : `FB_Cycle` + `E_CycleStep` + `PRG_03` (arbitrage éventuel bit IHM). `GVL_IHM` / `_TYPES/3_CYCLE_ET_MODES` pour le bit option.
- **Interdit** : `PRG_04` / `PRG_05` / `FB_Modes` / `H_TREUILS_BENNE/`. Le cycle reste producteur des commandes ; PRG_04/05 restent consommateurs de `WinchMxCmd` / `Auth`.
- **Hors scope T229** : renommage `SelJoystickWinch` → `SelWinchPilot` (utilisé par la MAINT unitaire **en service** → impact IHM ; tâche dédiée + `IHM_VARIABLES_MIGRATION.md` si un jour nécessaire).

---

## 5. Questions ouvertes (à trancher avant impl)

| # | Question |
|---|---|
| Q1 | Bit IHM « option repositionnement en X11 » (pause pilotée) souhaité, ou l'opérateur agit seulement au joystick + validation ? |
| Q2 | Le découpage vaut-il aussi pour X3 / X6 (déjà `Busy=TRUE`, déjà couvert) ou seulement X11 ? |
| Q3 | Renommage sélecteur treuil confirmé HORS scope T229 ? |
| Q4 | T229 dépend-il de T226 (refonte homing ↔ SEMI_AUTO) ou indépendant ? |

---

## 5bis. État d'implémentation (2026-09-03)

| Item | État |
|---|---|
| Split `X11_OPEN_DUMP` | ✅ FAIT — `X11A_DUMP_ARRIVE` (11, treuils arrêtés) → `X11B_DUMP_OPEN` (15, ouverture benne, **les 2 treuils arrêtés** : plus de descente couplée simultanée à l'ouverture → plus d'écart M1/M2 ni de faux SafeStop concordance). `X11C_DUMP_REPOSITION` (16) **réservée, non implémentée** (repositionnement couplé optionnel = feature séparée). |
| Config treuil explicite par étape | ✅ Partiel — étapes benne-seule (X3, X6, X11A, X11B) et X2 neutralisent **explicitement** les 2 treuils (4 champs). Pas de DUT `ST_CycleStepWinchProfile` ni de gate statique : discipline par inspection + revue. |
| C3.1 translation | ✅ FAIT — X2 : plus de `SelTarget` (départ **toujours P1**), `TranslationCmd.PositionTgt := 3` figé, `ReqStart` gaté homme-mort ; ralenti PV + arrêt FDC P1 = `PRG_05/FB_Translation` (inchangé). Au-delà de P1 côté maintenance → message « sortir du semi-auto, revenir à P1 ». X10 idem vers trémie. |
| Réserve `FB_SyncDeviation` coupé pendant X11 | ✅ Résolue par construction : X11B ne fait plus de descente couplée (les 2 treuils arrêtés). |
| Backstop anti-télescopage | ✅ FAIT (Zone E) — `instCauses[6]` : `ABS(M1-M2) > 0,5 m` en X4/X5/X8 → STABILIZING. |
| Bouton IHM repositionnement (Q1) | ⬜ non fait (X11C réservée). |

⚠️ **Hors scope traité malgré tout** (enum rename oblige) : `FB_Hmi_BannerFormatter.st` (3 arms `X11_OPEN_DUMP` → `X11A_DUMP_ARRIVE`/`X11B_DUMP_OPEN`). `PRG_05` **non touché** (le M3 en SEMI_AUTO reste piloté par `TranslationCmd` du cycle ; un vrai jog joystick M3 en SEMI_AUTO = tâche dédiée touchant `FB_TranslationCmdArbitrationM3`).

## 6. À compléter

- Détail des transitions de sous-étapes (conditions, timeouts)
- Chronogrammes X11a→X11b→X11c→X11b
- Table complète étape → config treuil **cible** (colonne « après T229 »)
- Arbitrage bit IHM dans `FB_Modes` ou `PRG_03`
- Impact tests CI séquenceur existants
