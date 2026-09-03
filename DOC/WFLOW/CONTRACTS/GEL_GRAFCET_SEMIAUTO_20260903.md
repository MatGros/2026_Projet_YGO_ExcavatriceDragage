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
| **AX0_REPOS** (0) *(ex-`X0_PREPARATION`)* | 🟦 step repos / park | toutes commandes **0** · `Lifecycle.Busy/Done := FALSE` · `WaitingForOperator` · `SampleCountDone := FALSE` (état neutre, aucun ordre) |
| **AT0** | ⬇️ *(démarrer le GRAFCET)* | `Enable (= Mode SEMI_AUTO)` **ET** `(StartEdge.Q OR DeadmanArmedEdge.Q)` **ET** `NOT Fault.Latched` → **AX1** |
| **AX1_INIT** (1) *(ex-`X1_HOMING`)* | 🟩 step — 🚫 mvt, **vérif conditions initiales** | `Lifecycle.Busy := TRUE` · **aucun ordre mouvement, aucun référencement** · calcule `InitConditionsOk` = codeurs M1/M2 référencés **ET** `NOT Fault.Latched` **ET** treuils au **FDC logiciel haut** (`TopPositionSensor`) **ET** posture de départ (`InitPositionOk`, `PRG_03`) : **chariot M3 PAS à droite de P1** (`NOT M3_AtMaintenanceStable`) **ET** treuils dans ±`CST_CycleInitWindowM` = 0,4 m autour du FDC haut. Positionnement fin sur P1 = AX2. |
| **AT1a** | ⬇️ | `InitConditionsOk` → **AX2** *(franchie sans mouvement)* |
| **AT1b** | *(hold)* | `NOT (HomedM1 AND HomedM2)` → msg « Machine non referencee : passer en maintenance » |
| **AT1c** | *(hold)* | autres conditions KO → msg « Amener les treuils au FDC haut. » |
| **AX2_TRANSLATE_P1** (2) *(ex-`X2_WORK_POS_SELECT`)* | 🟩 step — 🚚 translation P1 | **le cycle n'émet AUCUNE commande M3** (translation pilotée par l'opérateur au joystick + `PRG_05` : ralenti PV + arrêt FDC P1). On demande à l'opérateur de **pousser le joystick vers la droite** (axe Trémie—P2—P1—Maintenance : P1 est à droite de la trémie), `ExpectedDirection := +1`. **Traceurs treuils** : M1/M2 doivent RESTER au FDC logiciel haut (fenêtre `CST_CycleInitWindowM`) — surveillance permanente. `TranslationCmd.PositionTgt := 3` = repère `PRG_05` (info). `SelectedWorkTarget` **supprimé** (Q6). |
| **AT2a** | ⬇️ | `Translation_At_P1` **stabilisé** (`M3_AtP1Stable`) → **AX3** |
| **AT2b** | ⚠️ *(défaut)* | treuils M1/M2 **quittent le FDC haut** (hors fenêtre) → **stop, sortie cycle sur défaut latché** (le contrôle « chariot pas à droite de P1 » est fait en **AX1_INIT**, pas ici) |
| **AT2c** | *(maintien)* | sinon : consigne « pousser le joystick vers la droite », maintien requis |
| **AX3_OPEN_BUCKET** (3) | 🟩 step — 🪣 benne seule | treuils **0** · msg « **joystick poussé** : ouverture benne » · `BucketCmd.ReqOpen := CycleMotionPermit` — ouverture jusqu'au **FDC logiciel « benne ouverte »** (seuil) |
| **AT3** | ⬇️ *(fluide — sans temps mort)* | `JoystickDeflected AND Benne_Done AND Benne_IsOpen` → `ReqOpen := FALSE` → **AX4** *(enchaînement direct si joystick maintenu poussé + armé)* |
| **AX4_DESCEND_OPEN** (4) | 🟩 step — 🌊 plongée couplée + **recherche de couche** | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit`, `ExpectedDirection := -1`. **Cycle diving intégré** : `StepTgt` **borné palier 4 mini ET 4 maxi** (`CST_StepDive := 4`). **Palier 5 interdit** en AX4 → **sortie cycle sur défaut latché**. La **tempo de séquencement des contacteurs de vitesse est conservée** (montée progressive 1→4, pas de saut direct au palier 4). |
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
| 7 | **treuils quittent le FDC haut pendant la translation** (`ABS(M1/M2 − CfgCableLimitAscent_M) > CST_CycleInitWindowM`) | `AX2` |
| 8 | **palier vitesse > 4 demandé pendant la plongée** (palier 5 interdit) | `AX4` |

---

## 4️⃣ ❓ Questions ouvertes

| Q | Statut | Décision |
|---|---|---|
| **Q1** | ✅ | Pas de step ajoute ni de renumerotation. `X0_PREPARATION` (valeur 0) devient **`AX0_REPOS`** (repos / park, aucun ordre). `AT0` = `Enable (SEMI_AUTO) AND (StartEdge OR DeadmanArmedEdge) AND NOT Fault.Latched` → AX1. |
| **Q2** | ✅ | `AX1_HOMING` → **`AX1_INIT`** : vérif des **conditions initiales** (Homed M1/M2, benne référencée, aucun défaut, treuils au FDC logiciel haut, chariot en posture de départ ±0,4 m). Aucun mouvement, aucun référencement. |
| **Q3** | ✅ | `AX0_REPOS` garde son contenu de park (mise a 0 des ordres + Lifecycle idle + `SampleCountDone := FALSE`). |
| **Q4** | 🟡 défaut | `AX13 → AX0` **direct** (rebouclage) sur `StartEdge`. |
| **Q5** | ✅ | `E_CycleStep` → **`E_AutoCycleStep`** ; toutes valeurs `X*` → `AX*` (valeurs numeriques inchangees). |
| **Q6** | ✅ | `AX2` = pas de selection. `SelectedWorkTarget` **supprime** de l'interface. |
| **Q7** | ✅ | Posture de départ (`InitPositionOk`) vérifiée en **`AX1_INIT`** (pas sur AT0) : `PRG_03` calcule chariot P1 **ET** `ABS(M1_CablePosM − CfgCableLimitAscent_M) ≤ 0,4 m` **ET** idem M2. Constante `CST_CycleInitWindowM := 0,4` dans `PRG_03`. |
| **Q8** | 🟡 | « benne référencée » en AX1_INIT : quelle entrée ? (`FB_CycleSemiAuto` n'a pas de flag benne-datum ; proxy = `MachineHomed` via gate FB_Modes, ou ajouter un input dédié). |
| **Q9** | ✅ | **Cycle diving intégré dans AX4** : `StepTgt` borné **palier 4 mini ET maxi** — `CST_StepDive` passe de 3 à **4** (`CST_StepDive := 4`). Palier 5 en AX4 → défaut latché (cause 8). Tempo de séquencement des contacteurs de vitesse **conservée** (montée progressive, pas de saut direct). |
| **Q10** | ✅ | **AX2 sans commande M3** : le cycle ne pilote pas la translation (opérateur + `PRG_05`). Surveillance treuils au FDC haut → sortie défaut (cause 7). Contrôle « chariot pas à droite de P1 » = **AX1_INIT** uniquement (l'ancien `AT2b` msg maintenance est supprimé). |

---

_Brouillon 2026-09-03. Signale les erreurs, je corrige._
