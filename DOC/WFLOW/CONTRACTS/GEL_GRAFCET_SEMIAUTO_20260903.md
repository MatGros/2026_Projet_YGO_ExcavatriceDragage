# 🧊 GEL GRAFCET — Cycle SEMI_AUTO (`FB_Cycle` → `FB_CycleSemiAuto`)

> **But** : figer **steps + actions + transitions** du séquenceur SEMI_AUTO AVANT le renommage.
> Même démarche + **même vocabulaire** que le homing machine (T233).
>
> - **Date** : 2026-09-03 · **Branche** : `backup/mes-septembre-20260902`
> - **Contrat** : [T237](TASK_CONTRACT_T237_FB_CYCLESEMIAUTO_GEL_RENOMMAGE.yaml) · reprend [T229](TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml)
> - **Source** : `CODE/G_CYCLE/FB_Cycle.st` · `CODE/G_CYCLE/_TYPES/E_CycleStep.st`
> - **AF** : `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`
> - **Statut** : 🟡 BROUILLON — questions ouvertes §4 (Q1/Q5/Q6/Q7 tranchées, Q2/Q3/Q4 par défaut)

---

## 0️⃣ Convention de nommage (homogène projet)

| Séquenceur | Type enum | Steps | Transitions |
|---|---|---|---|
| **Homing machine** | `E_MachineHomingTxState` | `HX0_REPOS`, `HX1_CHOICE` … `HXF_FAILED` | `HT0`, `HT1a` … |
| **SEMI_AUTO** *(cible)* | **`E_AutoCycleStep`** *(ex-`E_CycleStep`)* | **`AX_REPOS`**, `AX0_PREPARATION`, `AX1_HOMING` … `AX13_DONE_SYNC`, `AX_STAB` | `AT0`, `AT2a` … |

→ **P2 T237** : renommage `E_CycleStep` → `E_AutoCycleStep` + toutes les valeurs `X*` → `AX*`, + ajout
`AX_REPOS := 99` (initiale pure). Ripple : `FB_Hmi_BannerFormatter`, `FB_TroubleshootingView`,
`PRG_03`, `PRG_07`, `ST_ChainCycleSemiAuto`, XML, `test_fb_cyclesemiauto.st`.

---

## 1️⃣ Principes GRAFCET (tranchés)

1. **Étape initiale = pure** : aucune action, aucune affectation. `AX0_PREPARATION` (ex-`X0`) fait du
   housekeeping → reste l'étape **1** ; **`AX_REPOS`** (=99) pure est ajoutée en amont.
2. **Coexistence** : GRAFCET SEMI_AUTO et homing tournent en parallèle.
3. **Continuité joystick (C1)** : manche défléchi + homme-mort armé du début à la fin.
   `CycleMotionPermit = JoystickDeflected AND DeadmanArmed` ne retombe jamais entre étapes ;
   `RunRequest := FALSE` seulement sur arrêt réellement voulu (fond, butée, fin). Une seule
   inversion de sens (pousser → tirer).
4. **C1e** : AX6→AX7 sans temps mort (M1 lancé le même scan que la sortie AX6).
5. **C3 / C3.1** : le cycle **ne pilote jamais** un déplacement autonome de M3 ; il fournit la
   consigne cible + surveille l'arrivée ; ralenti PV + arrêt FDC par `PRG_05`. Départ **toujours P1**.
6. **SEMI_AUTO homed-only** : gate `FB_Modes §3.2bis` (T226-AC1). Le cycle présuppose `HomedM1 AND HomedM2`.
7. **Jamais de redémarrage auto après défaut** : `ErrorEdge → AX_STAB` ; sortie sur `Reset` conscient.
   Reprise après pause (`WaitingResume`) sur `StartEdge` conscient uniquement.

---

## 2️⃣ Séquence — steps 🟦🟩🟥 / transitions ⬇️⬆️

> Palier : `CST_StepSlow` = 1 · `CST_StepDive` = 3 · `CST_StepLoaded` = 4.

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **AX_REPOS** (99) | 🟦 step initiale pure | *rien* — aucune action, aucune affectation |
| **AT_INIT** | ⬇️ | `Enable (= Mode SEMI_AUTO)` → **AX0** *(Q1)* |
| **AX0_PREPARATION** (0) | 🟩 step — housekeeping + vérif posture départ | treuils / translation / benne **0** · `Lifecycle.Busy/Done := FALSE` · `WaitingForOperator` · `SampleCountDone := FALSE` · vérifie **posture de départ** : treuils M1/M2 au **capteur haut** (plage `CfgStartTopWindowM`, Q7) |
| **AT0-ok** | ⬇️ | `(StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Latched` **ET** treuils M1/M2 au capteur haut (plage) → **AX1** |
| **AT0-nok** | *(hold)* | treuils PAS en haut → msg « Amener les treuils en position haute (capteur haut) en maintenance avant de lancer » — reste AX0 |
| **AX1_HOMING** (1) | 🟩 step — 🚫 mvt, vérif référence | `Lifecycle.Busy := TRUE` · **aucun ordre mouvement, aucun référencement** |
| **AT1a** | ⬇️ | `HomedM1 AND HomedM2` → **AX2** *(toujours vrai car homed-only — Q2 : garde redondante)* |
| **AT1b** | *(hold)* | sinon : msg « Machine non referencee : passer en maintenance » |
| **AX2_TRANSLATE_P1** (2) *(ex-`X2_WORK_POS_SELECT`)* | 🟩 step — 🚚 translation P1 | treuils **0** · **PAS de sélection** — comme en maintenance : l'opérateur amène M3 à P1 au joystick, `PRG_05` fait ralenti PV + arrêt FDC. Le cycle **surveille** `Translation_At_P1`. `TranslationCmd.PositionTgt := 3` = repère `PRG_05`. `SelectedWorkTarget` **supprimé** (Q6). |
| **AT2a** | ⬇️ | `Translation_At_P1` → **AX3** |
| **AT2b** | *(hold)* | `Translation_At_Maintenance` → msg « Abandon cycle, revenir a P1 en maintenance » |
| **AT2c** | *(maintien)* | sinon : consigne « joystick vers P1 », maintien requis |
| **AX3_OPEN_BUCKET** (3) | 🟩 step — 🪣 benne seule | treuils **0** · `BucketCmd.ReqOpen := CycleMotionPermit` |
| **AT3** | ⬇️ | `Benne_IsOpen` (ou `JoystickDeflected AND Benne_Done AND Benne_IsOpen`) → `ReqOpen := FALSE` → **AX4** |
| **AX4_DESCEND_OPEN** (4) | 🟩 step — 🌊 plongée couplée | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `StepTgt := CST_StepDive` · `BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit` · `ExpectedDirection := -1` |
| **AT4** | ⬇️ | `JoystickDeflected AND KoboldContactFond` → treuils **0** · `TouchPositionM := M1_CablePosM` · `RaiseTargetM := TouchPositionM + 0,5` (borné legal) → **AX5** |
| **AX5_BOTTOM_CONFIRMED** (5) | 🟩 step — ⬆️ montée lente | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepSlow` · `ExpectedDirection := 1` *(inversion de sens)* |
| **AT5** | ⬇️ | `JoystickDeflected AND M1&M2 ≥ RaiseTargetM` → treuils **0** → **AX6** |
| **AX6_CLOSE_BUCKET** (6) | 🟩 step — 🪣 benne seule | M1+M2 **explicitement 0** · `BucketCmd.ReqClose := CycleMotionPermit` |
| **AT6** | ⬇️ *(C1e — sans temps mort)* | `JoystickDeflected AND Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)` → `ReqClose := FALSE` → **AX7** |
| **AX7_CTRL_ASCENT** (7) | 🟩 step — 🐌 montée contrôle | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepSlow` · surveillance écart vitesse M1/M2 (§3) |
| **AT7** | ⬇️ | `JoystickDeflected AND M1&M2 ≥ TouchPositionM + CtrlAscentDistM AND ABS(M1−M2) ≤ CtrlAscentToleranceM` → **AX8** |
| **AX8_ASCENT_LOADED** (8) | 🟩 step — ⬆️ montée en charge | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CST_StepLoaded` |
| **AT8** | ⬇️ | `JoystickDeflected AND M1_CablePosM ≥ CableLimitM1AscentM` → treuils **0** → **AX9** |
| **AX9_DRAIN_PAUSE** (9) | 🟩 step — 💧 égouttage | treuils **0** · `WaitingForProcess` · tempo `DrainingTimer` (gate `State = AX9`, `PT := DrainTimeEff`) |
| **AT9** | ⬇️ | `JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q)` → **AX10** |
| **AX10_TRANSLATE_DUMP** (10) | 🟩 step — 🚚 translation trémie | `TranslationCmd.PositionTgt := 1` (Trémie) · `ReqStart := CycleMotionPermit` · `ExpectedDirection := -1` |
| **AT10** | ⬇️ | `JoystickDeflected AND Translation_At_Tremie` → `ReqStart := FALSE` → **AX11A** |
| **AX11A_DUMP_ARRIVE** (11) | 🟩 step — 🛑 treuils arrêtés | M1+M2 **0** · attente geste |
| **AT11A** | ⬇️ | `JoystickDeflected` → **AX11B** |
| **AX11B_DUMP_OPEN** (15) | 🟩 step — 🪣 benne seule, treuils 0 | M1+M2 **0** · `BucketCmd.ReqOpen := CycleMotionPermit` |
| **AT11B-c** | ⬇️ *(option)* | `RepositionRequest` → **AX11C** |
| **AT11B** | ⬇️ | `JoystickDeflected AND Benne_Done AND Benne_IsOpen` → `ReqOpen := FALSE` → **AX13** |
| **AX11C_DUMP_REPOSITION** (16) | 🟩 step — 🔁 descente couplée option | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `StepTgt := CST_StepSlow` (symétrique) · `BucketCmd.ReqOpen := CycleMotionPermit AND NOT Benne_IsOpen` |
| **AT11C** | ⬆️ | `NOT RepositionRequest` → treuils **0** → **AX11B** |
| **AX13_DONE_SYNC** (13) | 🟩 step — ✅ fin | treuils / translation **0** · `Lifecycle.Done := TRUE`, `Busy := FALSE` · `SampleCount + 1` + `LastCycleDuration := CurrentCycleElapsed` (cadré `SampleCountDone`) |
| **AT13** | ⬇️ | `StartEdge.Q` → `SampleCountDone := FALSE` → **AX0** *(rebouclage direct — Q4)* |
| **AX_STAB** (14) *(ex-`STABILIZING`)* | 🟥 step — repli défaut | tout **0** · `BucketCmd.ReqKoboldMeasureEnable := FALSE` · msg « acquitter le defaut » |

### ⬆️ Transverses (hors CASE, chaque scan)

| Rep. | Déclencheur | Effet |
|---|---|---|
| **GT-safe** | `NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent` | neutralise tout ; si cycle en cours (`State ∉ {AX0, AX13, AX_STAB}`) → `PausedState := State`, `WaitingResume := TRUE` ; `RETURN` |
| **GT-resume** | `WaitingResume` | `StartEdge.Q` → `State := PausedState` ; sinon *hold* + msg « Reprendre : StartCycle » |
| **GT-fault** | `ErrorEdge.Q` | `CycleStepAtError := State` → **AX_STAB** · `WaitingResume := FALSE` |
| **GT-reset** | `ResetEdge.Q` | si `State = AX_STAB` → **AX0** ; `SavedState := AX0` |
| **GT-abort** | `AbortEdge.Q` | → **AX0** · `WaitingResume := FALSE` · `PausedState := AX0` |
| **GT-permit** | relâche manche **OU** homme-mort pendant `Lifecycle.Busy` | commandes coupées, **étape conservée**, **pas de défaut** |

---

## 3️⃣ Causes de défaut latchées (§1 FB, → AX_STAB)

| # | Cause | Condition |
|---|---|---|
| 0 | `LimitLegalReached` | `AX4` seul |
| 1 | `WinchSyncError` | hors `AX0` / `AX_STAB` |
| 2 | `SpeedMismatchConfirmed` (écart vitesse M1/M2, 500 ms) | `AX7` |
| 3 | `NOT HeartbeatIhmOk` | hors `AX0` / `AX_STAB` |
| 4 | `StepMaxTimer.Q` (backstop durée d'étape, réarmé au changement d'étape) | hors `AX_STAB` |
| 5 | stabilisation / tolérance écart codeurs | `AX7` |
| 6 | anti-télescopage `ABS(M1_CablePosM − M2_CablePosM) > CST_CoupledPosBacklashM` | `AX4 / AX5 / AX8 / AX11C` |

---

## 4️⃣ ❓ Questions ouvertes

| Q | Statut | Décision |
|---|---|---|
| **Q1** | ✅ | `AX_REPOS := 99` initiale pure · `AT_INIT` : `Enable (= Mode SEMI_AUTO)` → AX0 |
| **Q2** | 🟡 défaut | `AX1_HOMING` **gardé** (garde de position redondante, ripple minimal). Fusion AX0→AX2 = plus tard si besoin. |
| **Q3** | 🟡 défaut | `AX0` garde tout son housekeeping actuel (dont `SampleCountDone := FALSE`). `AX_REPOS` n'écrit rien. |
| **Q4** | 🟡 défaut | `AX13 → AX0` **direct** (rebouclage). `AX_REPOS` seulement au boot / première entrée SEMI_AUTO. |
| **Q5** | ✅ | `E_CycleStep` → **`E_AutoCycleStep`** ; toutes valeurs `X*` → `AX*`. |
| **Q6** | ✅ | `AX2` = pas de sélection. `SelectedWorkTarget` **supprimé** de l'interface. |
| **Q7** | 🟡 | `CfgStartTopWindowM` : proposé **0,10 m** sous le capteur haut, **constante** (`CST_StartTopWindowM`) pour commencer, à ajuster banc. Message figé : « Amener les treuils en position haute (capteur haut) en maintenance avant de lancer le cycle ». |

---

_Brouillon 2026-09-03. Signale les erreurs, je corrige._
