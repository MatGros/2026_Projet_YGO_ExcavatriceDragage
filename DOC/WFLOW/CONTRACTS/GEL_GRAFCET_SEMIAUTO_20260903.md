# 🧊 GEL GRAFCET — Cycle SEMI_AUTO (`FB_Cycle` → `FB_CycleSemiAuto`)

> **But** : figer **steps + actions + transitions** du séquenceur SEMI_AUTO AVANT le renommage
> et l'ajout de l'étape initiale pure. Même démarche que le homing machine (T233).
> Brouillon de travail — itéré avec l'utilisateur.
>
> - **Date** : 2026-09-03 · **Branche** : `backup/mes-septembre-20260902`
> - **Contrat** : [T237](TASK_CONTRACT_T237_FB_CYCLESEMIAUTO_GEL_RENOMMAGE.yaml) · reprend [T229](TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml)
> - **Source** : `CODE/G_CYCLE/FB_Cycle.st` (commit courant) · `CODE/G_CYCLE/_TYPES/E_CycleStep.st`
> - **AF** : `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`
> - **Statut** : 🟡 BROUILLON — questions ouvertes §4

---

## 0️⃣ Principes GRAFCET (tranchés)

1. **Étape initiale = étape pure** : aucune action, aucune affectation. Les sorties retombent par
   absence d'étape qui les commande. `X0_PREPARATION` **n'est pas** une étape initiale pure
   (elle force treuils/translation/benne à 0, `WaitingForOperator`, `SampleCountDone := FALSE`) →
   devient l'étape **1** (préparation active), une **`CX_INIT`** pure est ajoutée en amont *(Q1)*.
2. **Coexistence** : GRAFCET SEMI_AUTO et GRAFCET homing tournent en parallèle ; être en étape
   initiale de l'un pendant que l'autre bouge est normal.
3. **Continuité joystick (C1)** : en nominal l'opérateur **maintient le manche défléchi + homme-mort
   armé du début à la fin**. `CycleMotionPermit = JoystickDeflected AND DeadmanArmed` ne retombe
   jamais entre étapes ; une transition ne force `RunRequest := FALSE` que sur **arrêt réellement
   voulu** (fond, butée, fin). Une seule inversion de sens sur tout le cycle (pousser→tirer).
4. **C1e** : X6→X7 sans temps mort (M1 lancé le même scan que la sortie de X6).
5. **C3 / C3.1** : le cycle **ne pilote jamais** un déplacement autonome de M3. Il fournit la
   consigne cible + surveille l'arrivée ; le ralenti PV et l'arrêt FDC sont assurés par `PRG_05`.
   Départ **toujours P1**.
6. **SEMI_AUTO homed-only** : gate `FB_Modes §3.2bis` (T226-AC1) — SEMI_AUTO refusé + expulsion
   MAINT_N1 si `NOT MachineHomed`. Le cycle **présuppose** `HomedM1 AND HomedM2`.
7. **Jamais de redémarrage auto après défaut** : `ErrorEdge → STABILIZING` ; sortie sur `Reset`
   conscient. Reprise après pause (`WaitingResume`) sur `StartEdge` conscient uniquement.

---

## 1️⃣ Séquence — steps 🟦🟩🟥 / transitions ⬇️⬆️

> Palier : `CST_StepSlow` = 1 · `CST_StepDive` = 3 · `CST_StepLoaded` = 4.
> `CycleMotionPermit` = manche défléchi + homme-mort armé.

| Rep. | 🎬 | Contenu (variables réelles `FB_Cycle`) |
|---|---|---|
| **CX_INIT** *(à ajouter — nom/valeur Q1)* | 🟦 step initiale pure | *rien* — aucune action, aucune affectation |
| **CT_INIT** | ⬇️ | *(Q1)* : `Enable (= Mode SEMI_AUTO)` ? front d'entrée mode ? → **X0** |
| **X0_PREPARATION** (0) | 🟩 step — housekeeping + vérif posture départ | treuils / translation / benne **0** · `Lifecycle.Busy/Done := FALSE` · `WaitingForOperator` · `SampleCountDone := FALSE` · vérifie la **posture de départ** : treuils M1/M2 au **capteur haut** (FDC haut, avec **plage d'acceptation** `CfgStartTopWindowM` *(Q7)*) |
| **XT0-ok** | ⬇️ | `(StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Latched` **ET** treuils M1/M2 au capteur haut (dans la plage) → **X1** |
| **XT0-nok** | *(hold)* | treuils PAS en position haute → msg « Amener les treuils en position haute (capteur haut) en maintenance avant de lancer le cycle » — reste X0, cycle non lancé |
| **X1_HOMING** (1) | 🟩 step — 🚫 mvt, **vérif référence** | `Lifecycle.Busy := TRUE` · **aucun ordre mouvement, aucun référencement** (responsabilité `FB_MachineHomingCycle`) |
| **XT1a** | ⬇️ | `HomedM1 AND HomedM2` → **X2** *(franchie sans mouvement — toujours vrai car homed-only, Q2)* |
| **XT1b** | *(hold)* | sinon : msg « Machine non referencee : passer en maintenance » — reste X1 |
| **X2_TRANSLATE_P1** (2) *(ex-X2_WORK_POS_SELECT)* | 🟩 step — 🚚 translation vers P1 | treuils **0** · **PAS de sélection de cible** : fonctionnellement identique à la maintenance — l'opérateur amène M3 à P1 au joystick, `PRG_05` assure le ralenti PV + l'arrêt FDC P1. Le cycle **ne fournit que** la surveillance d'arrivée `Translation_At_P1`. `TranslationCmd.PositionTgt := 3` (P1) sert de repère à `PRG_05`. |
| **XT2a** | ⬇️ | `Translation_At_P1` → **X3** |
| **XT2b** | *(hold)* | `Translation_At_Maintenance` (au-delà de P1) → msg « Abandon cycle, revenir a P1 en maintenance » (le cycle ne ramène pas M3) |
| **XT2c** | *(maintien)* | sinon : consigne « joystick vers P1 », maintien requis |
| **X3_OPEN_BUCKET** (3) | 🟩 step — 🪣 benne seule | treuils **0** · `BucketCmd.ReqOpen := CycleMotionPermit` |
| **XT3** | ⬇️ | (`Benne_IsOpen`) **OU** (`JoystickDeflected AND Benne_Done AND Benne_IsOpen`) → `ReqOpen := FALSE` → **X4** |
| **X4_DESCEND_OPEN** (4) | 🟩 step — 🌊 plongée couplée | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `StepTgt := CST_StepDive` · `BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit` · `ExpectedDirection := -1` |
| **XT4** | ⬇️ | `JoystickDeflected AND KoboldContactFond` → treuils **0** · `TouchPositionM := M1_CablePosM` · `RaiseTargetM := TouchPositionM + 0,5` (borné legal) → **X5** |
| **X5_BOTTOM_CONFIRMED** (5) | 🟩 step — ⬆️ montée lente | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepSlow` · `ExpectedDirection := 1` *(inversion de sens)* |
| **XT5** | ⬇️ | `JoystickDeflected AND M1_CablePosM ≥ RaiseTargetM AND M2_CablePosM ≥ RaiseTargetM` → treuils **0** → **X6** |
| **X6_CLOSE_BUCKET** (6) | 🟩 step — 🪣 benne seule | M1+M2 **explicitement 0** (pas de résidu X5) · `BucketCmd.ReqClose := CycleMotionPermit` |
| **XT6** | ⬇️ *(C1e : sans temps mort)* | `JoystickDeflected AND Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)` → `ReqClose := FALSE` → **X7** |
| **X7_CTRL_ASCENT** (7) | 🟩 step — 🐌 montée contrôle | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepSlow` · surveillance écart vitesse M1/M2 (§1) + tempo stabilisation |
| **XT7** | ⬇️ | `JoystickDeflected AND M1&M2 ≥ TouchPositionM + CtrlAscentDistM AND ABS(M1−M2) ≤ CtrlAscentToleranceM` → **X8** |
| **X8_ASCENT_LOADED** (8) | 🟩 step — ⬆️ montée en charge | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepLoaded` |
| **XT8** | ⬇️ | `JoystickDeflected AND M1_CablePosM ≥ CableLimitM1AscentM` → treuils **0** → **X9** |
| **X9_DRAIN_PAUSE** (9) | 🟩 step — 💧 égouttage | treuils **0** · `WaitingForProcess` · tempo `DrainingTimer` (gate `State = X9`, `PT := DrainTimeEff`) |
| **XT9** | ⬇️ | `JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q)` → **X10** |
| **X10_TRANSLATE_DUMP** (10) | 🟩 step — 🚚 translation trémie | `TranslationCmd.PositionTgt := 1` (Trémie) · `TranslationCmd.ReqStart := CycleMotionPermit` · `ExpectedDirection := -1` |
| **XT10** | ⬇️ | `JoystickDeflected AND Translation_At_Tremie` → `ReqStart := FALSE` → **X11A** |
| **X11A_DUMP_ARRIVE** (11) | 🟩 step — 🛑 treuils arrêtés | M1+M2 **0** · attente geste |
| **XT11A** | ⬇️ | `JoystickDeflected` → **X11B** |
| **X11B_DUMP_OPEN** (15) | 🟩 step — 🪣 benne seule, treuils 0 | M1+M2 **0** · `BucketCmd.ReqOpen := CycleMotionPermit` |
| **XT11B-c** | ⬇️ *(option)* | `RepositionRequest` → **X11C** |
| **XT11B** | ⬇️ | `JoystickDeflected AND Benne_Done AND Benne_IsOpen` → `ReqOpen := FALSE` → **X13** |
| **X11C_DUMP_REPOSITION** (16) | 🟩 step — 🔁 descente couplée option | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `StepTgt := CST_StepSlow` (symétrique) · `BucketCmd.ReqOpen := CycleMotionPermit AND NOT Benne_IsOpen` |
| **XT11C** | ⬆️ | `NOT RepositionRequest` → treuils **0** → **X11B** |
| **X13_DONE_SYNC** (13) | 🟩 step — ✅ fin | treuils / translation **0** · `Lifecycle.Done := TRUE`, `Busy := FALSE` · `SampleCount + 1` + `LastCycleDuration := CurrentCycleElapsed` (cadré `SampleCountDone`) |
| **XT13** | ⬇️ | `StartEdge.Q` → `SampleCountDone := FALSE` → **X0** *(rebouclage)* |
| **STABILIZING** (14) | 🟥 step — repli défaut | tout **0** · `BucketCmd.ReqKoboldMeasureEnable := FALSE` · msg « acquitter le defaut » |

### ⬆️ Transverses (hors CASE, évaluées chaque scan)

| Rep. | Déclencheur | Effet |
|---|---|---|
| **GT-safe** | `NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent` | neutralise toutes demandes ; si cycle en cours (`State ∉ {X0, X13, STABILIZING}`) → `PausedState := State`, `WaitingResume := TRUE` ; `RETURN` |
| **GT-resume** | `WaitingResume` | `StartEdge.Q` → `State := PausedState` (reprise consciente) ; sinon *hold* + msg « Reprendre : StartCycle » |
| **GT-fault** | `ErrorEdge.Q` (front `Fault.Error`) | `CycleStepAtError := State` → **STABILIZING** · `WaitingResume := FALSE` |
| **GT-reset** | `ResetEdge.Q` | si `State = STABILIZING` → **X0** ; `SavedState := X0` |
| **GT-abort** | `AbortEdge.Q` | → **X0** · `WaitingResume := FALSE` · `PausedState := X0` |
| **GT-permit** | relâche manche **OU** homme-mort pendant `Lifecycle.Busy` | `CycleMotionPermit` retombe → toutes commandes coupées, **étape conservée** (pas de retour X0), **pas de défaut** |

---

## 2️⃣ Causes de défaut latchées (§1, → STABILIZING)

| # | Cause | Condition |
|---|---|---|
| 0 | `LimitLegalReached` | `X4` seul |
| 1 | `WinchSyncError` | hors `X0` / `STABILIZING` |
| 2 | `SpeedMismatchConfirmed` (écart vitesse M1/M2, 500 ms) | `X7` |
| 3 | `NOT HeartbeatIhmOk` | hors `X0` / `STABILIZING` |
| 4 | `StepMaxTimer.Q` (backstop durée d'étape, réarmé à chaque changement d'étape) | hors `STABILIZING` |
| 5 | stabilisation / tolérance écart codeurs | `X7` |
| 6 | anti-télescopage `ABS(M1_CablePosM − M2_CablePosM) > CST_CoupledPosBacklashM` | `X4 / X5 / X8 / X11C` (phases couplées) |

---

## 3️⃣ Contraintes non négociables reprises baseline

- **C1** continuité joystick · **C1e** X6→X7 sans temps mort · **C3/C3.1** translation P1 · homed-only.
- Split X11a/b/c + **gap à 12** conservés · anti-télescopage · `SampleCount` + durée cycle.

---

## 4️⃣ ❓ Questions ouvertes (🟡 → 🟢)

| Q | Sujet | Options |
|---|---|---|
| **Q1** | `CX_INIT` | nom + valeur enum (17 ? 99 ? négatif ?) · réceptivité `CT_INIT` (`Enable` ? front entrée mode ?) · renumérotation vs valeur hors-plage |
| **Q2** | **X1_HOMING** utilité | SEMI_AUTO est homed-only (gate FB_Modes) → `HomedM1/M2` est toujours vrai en X1 → X1 est franchie sans effet. **Garder X1** comme garde de position redondante, ou **fusionner X0→X2** ? |
| **Q3** | `X0` housekeeping vs `CX_INIT` | quelles affectations restent en `X0` (préparation active) une fois `CX_INIT` pure ajoutée ? `SampleCountDone := FALSE` reste en X0 ? |
| **Q4** | `X13 → X0` sur `StartEdge` | rebouclage direct, ou passer par `CX_INIT` ? |
| **Q5** | Renommage `E_CycleStep` ? | l'enum garde son nom (`E_CycleStep`) ou devient `E_CycleSemiAutoStep` (cohérence `FB_CycleSemiAuto`) ? ripple XML/registry. |
| **Q6** | ✅ tranché | `X2` = **pas de sélection**, comme en maintenance. `SelectedWorkTarget` = champ mort → **à retirer** de l'interface (`ST_SequencePublicState` / `ST_ChainCycleSemiAuto`). Renommage step `X2_WORK_POS_SELECT` → `X2_TRANSLATE_P1`. |
| **Q7** | Plage d'acceptation posture départ (XT0) | `CfgStartTopWindowM` : valeur (ex. ±0,10 m sous le capteur haut) ? config persistante ou constante ? Message exact « position haute » à figer. |

---

_Brouillon 2026-09-03. Ne pas coder tant que §4 n'est pas résolu et le doc validé._
