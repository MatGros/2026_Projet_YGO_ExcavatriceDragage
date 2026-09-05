# 🧊 GEL GRAFCET — Cycle SEMI_AUTO (`FB_Cycle` → `FB_CycleSemiAuto`)

> **But** : figer **steps + actions + transitions** du séquenceur SEMI_AUTO AVANT le renommage.
> Même démarche + **même vocabulaire** que le homing machine (T233).
>
> - **Date** : 2026-09-03 · **Branche** : `backup/mes-septembre-20260902`
> - **Contrat** : [T237](TASK_CONTRACT_T237_FB_CYCLESEMIAUTO_GEL_RENOMMAGE.yaml) · reprend [T229](TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml)
> - **Source** : `CODE/G_CYCLE/FB_Cycle.st` · `CODE/G_CYCLE/_TYPES/E_CycleStep.st`
> - **AF** : `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`
> - **Statut** : 🟡 BROUILLON — §4 : Q1–Q12, Q14, Q15 tranchées ; ouvertes : Q8 (input benne référencée), Q13 (timeout immersion/fond). `DiveStartMin_M` (3 ou 5 m) à confirmer. Garde « bascule couplage joystick centré » = `PRG_04`.

---

## 0️⃣ Convention de nommage (homogène projet)

| Séquenceur | Type enum | Steps | Transitions |
|---|---|---|---|
| **Homing machine** | `E_MachineHomingTxState` | `HX0_REPOS`, `HX1_CHOICE` … `HXF_FAILED` | `HT0`, `HT1a` … |
| **SEMI_AUTO** *(cible)* | **`E_AutoCycleStep`** *(ex-`E_CycleStep`)* | `AX0_REPOS`, `AX1_INIT` … `AX18_DONE_SYNC`, `AX_STAB`, `AX_DIVING_RETRY` | `AT0`, `AT2a` … |

→ **T237** : renommage `E_CycleStep` → `E_AutoCycleStep` + valeurs `X*` → `AX*`. **Renumérotation
assumée (refactor)** : le DIVING est décomposé en 5 steps de plein droit
(`AX4_DESCEND_DIVING`, `AX5_KOBOLD_INIT`, `AX6_SEARCH_IMMERSION`, `AX7_SEARCH_BOTTOM`,
`AX8_BOTTOM_CONFIRMED`) + step spécial `AX_DIVING_RETRY` ; l'EXTRACTION reprend les 4 steps
existants renommés (`AX9`…`AX12`) ; tout le reste décalé. Ripple : `FB_Hmi_BannerFormatter`,
`FB_TroubleshootingView`, `PRG_03`, `PRG_07`, `ST_ChainCycleSemiAuto`, XML, `test_fb_cyclesemiauto.st`.

---

## 1️⃣ Principes GRAFCET (tranchés)

1. **Étape initiale = pure** : `AX0_REPOS` (=0, ex-`X0_PREPARATION`) — aucun ordre, housekeeping
   (Lifecycle idle + `SampleCountDone := FALSE`). C'est l'étape initiale GRAFCET.
2. **Coexistence** : GRAFCET SEMI_AUTO et homing tournent en parallèle.
3. **Continuité joystick (C1)** : manche défléchi + homme-mort armé du début à la fin.
   `CycleMotionPermit = JoystickDeflected AND DeadmanArmed` ne retombe jamais entre étapes ;
   `RunRequest := FALSE` seulement sur arrêt réellement voulu (fond, butée, fin). Une seule
   inversion de sens (pousser → tirer).
4. **C1e** : AX10→AX11 sans temps mort (M1 lancé le même scan que la sortie `AX10_CLOSE_BUCKET`).
5. **C3 / C3.1** : le cycle **ne pilote jamais** un déplacement autonome de M3 ; il fournit la
   consigne cible + surveille l'arrivée ; ralenti PV + arrêt FDC par `PRG_05`. Départ **toujours P1**.
6. **SEMI_AUTO homed-only** : gate `FB_Modes §3.2bis` (T226-AC1). Le cycle présuppose `HomedM1 AND HomedM2`.
7. **Jamais de redémarrage auto après défaut** : `ErrorEdge → AX_STAB` ; sortie sur `Reset` conscient.
   Reprise après pause (`WaitingResume`) sur `StartEdge` conscient uniquement.

---

## 2️⃣ Séquence — steps 🟦🟩🟥 / transitions ⬇️⬆️

> Palier : `CST_StepSlow` = 1 · `CST_StepDive` = **4** (ex-3, GEL Q9) · `CST_StepLoaded` = 4.

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

### 🌊 DIVING (steps 4→8 + retry)

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **AX4_DESCEND_DIVING** (4) *(ex-`AX4_DESCEND_OPEN`)* | 🟩 step — 🌊 plongée couplée benne ouverte | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `ExpectedDirection := -1`. `StepTgt` **borné palier 4 mini ET maxi** (`CST_StepDive := 4`) ; palier 5 → défaut latché (cause 8). Tempo contacteurs conservée (1→4). **Kobold PAS enclenché.** |
| **AT4** | ⬇️ | `JoystickDeflected AND M1&M2 ≤ DiveStartMin_M` (altimétrie de lancement, ≈ **3 à 5 m** — valeur à confirmer) → **AX5** |
| **AX5_KOBOLD_INIT** (5) *(nouveau)* | 🟩 step — ⚡ activation Kobold « au vol » | descente couplée **maintenue palier 4**. **Enclenche le contacteur Kobold** (`BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit`). Vérifie **retour contacteur** cohérent. |
| **AT5** | ⬇️ | retour contacteur Kobold OK → **AX6** |
| **AX6_SEARCH_IMMERSION** (6) *(nouveau)* | 🟩 step — 💦 recherche entrée dans l'eau | descente **maintenue palier 4**. Attente **front DI Kobold 0→1** (immersion ; sous ≈ **0,5 m**, DI = 1 quelques ms après). Fenêtre / timeout `FB_DiveSearch`. |
| **AT6** | ⬇️ | `JoystickDeflected AND KoboldRiseEdge` (immersion confirmée) → **AX7** |
| **AX7_SEARCH_BOTTOM** (7) *(nouveau)* | 🟩 step — 🕳️ recherche du fond | descente **maintenue palier 4** sous l'eau. Attente **front DI Kobold 1→0** (fond). Fenêtre / timeout `FB_DiveSearch`. |
| **AT7** | ⬇️ *(fond touché)* | `JoystickDeflected AND KoboldFallEdge` → **AX8** |
| **AX8_BOTTOM_CONFIRMED** (8) *(nouveau)* | 🟩 step — 🛑 fond confirmé | **coupure instantanée** de toutes les commandes treuils (même scan) · **set** la variable d'info « fond touché » (`KoboldContactFond` / `Outputs.BottomConfirmed`) · `TouchPositionM := M1_CablePosM` · `RaiseTargetM := TouchPositionM + CfgRaiseOffBottom_M` (borné legal). **`CfgRaiseOffBottom_M` réglable IHM** (`GVL_IHM.Cycle.Cfg`), défaut **0,5 m** — à affiner aux essais. |
| **AT8** | ⬇️ | (immédiat) → **AX9** *(extraction)* |
| **GT-dive-retry** | ⤴️ *(transverse, actif en `AX5/AX6/AX7`)* | **erreur séquence Kobold** OU **joystick relâché** OU **palier ≠ 4 sur M1 ou M2** → **AX_DIVING_RETRY** |
| **AX_DIVING_RETRY** *(nouveau, step spécial)* | 🟥 step — ↩️ reprise diving | treuils **0** puis, sur maintien joystick, **remontée assistée palier lent jusqu'au FDC haut** · contacteur Kobold coupé · msg « Reprise plongée : remonter au FDC haut ». |
| **AT-retry** | ⤴️ | treuils au **FDC haut** → **AX4_DESCEND_DIVING** *(nouvelle tentative ; abandon = `GT-abort` → AX0)* |

### ⛏️ EXTRACTION (steps 9→12)

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **AX9_RAISE_OFF_BOTTOM** (9) *(ex-`AX5_BOTTOM_CONFIRMED`)* | 🟩 step — ⬆️ **retente les câbles** (palier 1) | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := **1**` (palier 1, doux) · `ExpectedDirection := 1` *(inversion de sens)*. **Sélecteur de couplage IHM** `BOTH` / `M1 seul` / `M2 seul` (Q15) — cas treuil bloqué / câble trop détendu, détection visuelle opérateur ; bascule joystick au centre uniquement (garde côté `PRG_04`). |
| **AT9** | ⬇️ | `JoystickDeflected AND M1&M2 ≥ RaiseTargetM` (câbles tendus, décollés du fond) → treuils **0** → **AX10** |
| **AX10_CLOSE_BUCKET** (10) *(ex-`AX6`)* | 🟩 step — 🪣 benne seule | M1+M2 **explicitement 0** · `BucketCmd.ReqClose := CycleMotionPermit`. Sélecteur de couplage `BOTH`/`M1`/`M2` accessible (Q15) pour rattraper un treuil bloqué avant fermeture. |
| **AT10** | ⬇️ *(C1e — sans temps mort)* | `JoystickDeflected AND Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)` → `ReqClose := FALSE` → **AX11** |
| **AX11_CTRL_ASCENT** (11) *(ex-`AX7_CTRL_ASCENT`)* | 🟩 step — 🐌 montée contrôle | M1+M2 `RunRequest := CycleMotionPermit`, `ReqAscent`, `StepTgt := CfgCtrlAscentMaxStep` (clamp FB **1..2**) — **palier max réglable IHM** (défaut **1 / P1**, autorisé jusqu'à **2 / P2** au besoin sur le moment) · surveillance écart vitesse M1/M2 (§3). Montée **benne mal fermée autorisée** (`Benne_IsRoughlyClosed`) jusqu'au FDC haut en P1. Sélecteur de couplage `BOTH`/`M1`/`M2` accessible (Q15) — dernier step où le rattrapage séparé est prévu. |
| **AT11** | ⬇️ | `JoystickDeflected AND M1&M2 ≥ TouchPositionM + CtrlAscentDistM AND ABS(M1−M2) ≤ CtrlAscentToleranceM` → **AX12** |
| **AX12_LOADED_ASCENT** (12) *(ex-`AX8_ASCENT_LOADED`)* | 🟩 step — ⬆️ montée en charge | **benne bien fermée** (`Benne_IsClosed`) → `StepTgt := CST_StepLoaded` (palier 4 max) ; **benne mal fermée** (`Benne_IsRoughlyClosed AND NOT Benne_IsClosed`) → `StepTgt := 1` (palier 1). `RunRequest := CycleMotionPermit`, `ReqAscent`. **Pas de ralentissement 1 m avant la position top** (montée franche jusqu'à `CableLimitM1AscentM`). |
| **AT12** | ⬇️ | `JoystickDeflected AND M1_CablePosM ≥ CableLimitM1AscentM` → treuils **0** → **AX13** |

### 🚚 DÉCHARGE (steps 13→18)

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **AX13_DRAIN_PAUSE** (13) *(ex-`AX9`)* | 🟩 step — 💧 égouttage | treuils **0** · `WaitingForProcess` · tempo `DrainingTimer` (gate `State = AX13`, `PT := DrainTimeEff`). **Durée réglable IHM** (`GVL_IHM.Cycle.Cfg.DrainTime`) **et bypass immédiat** (`BtnSkipDrain` → `SkipDrainEdge`). |
| **AT13** | ⬇️ | `JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q)` → **AX14** |
| **AX14_TRANSLATE_DUMP** (14) *(ex-`AX10`)* | 🟩 step — 🚚 translation trémie | `TranslationCmd.PositionTgt := 1` (Trémie) · `ReqStart := CycleMotionPermit` · `ExpectedDirection := -1` |
| **AT14** | ⬇️ | `JoystickDeflected AND Translation_At_Tremie` → `ReqStart := FALSE` → **AX15A** |
| **AX15A_DUMP_ARRIVE** (15) *(ex-`AX11A`)* | 🟩 step — 🛑 treuils arrêtés | M1+M2 **0** · attente geste |
| **AT15A** | ⬇️ | `JoystickDeflected` → **AX15B** |
| **AX15B_DUMP_OPEN** (16) *(ex-`AX11B`)* | 🟩 step — 🪣 **vidage** : ouverture benne au-dessus de la trémie, treuils 0 | M1+M2 **0** · `BucketCmd.ReqOpen := CycleMotionPermit` — ouverture complète pour **vider le contenu** dans la trémie |
| **AT15B-c** | ⬇️ *(option)* | `RepositionRequest` → **AX15C** |
| **AT15B** | ⬇️ | `JoystickDeflected AND Benne_Done AND Benne_IsOpen` (contenu vidé) → `ReqOpen := FALSE` → **AX18** |
| **AX15C_DUMP_REPOSITION** (17) *(ex-`AX11C`)* | 🟩 step — 🔁 descente couplée option | M1+M2 `RunRequest := CycleMotionPermit`, `ReqDescend`, `StepTgt := CST_StepSlow` (symétrique) · `BucketCmd.ReqOpen := CycleMotionPermit AND NOT Benne_IsOpen` |
| **AT15C** | ⬆️ | `NOT RepositionRequest` → treuils **0** → **AX15B** |
| **AX18_DONE_SYNC** (18) *(ex-`AX13_DONE_SYNC`)* | 🟩 step — ✅ fin de passe | treuils / translation **0** · `Lifecycle.Done := TRUE`, `Busy := FALSE` · `SampleCount + 1` + `LastCycleDuration := CurrentCycleElapsed` (cadré `SampleCountDone`) · msg « **Cycle terminé — aller en P1 pour recommencer** » |
| **AT18** | ⬇️ *(rebouclage — Q14)* | `StartEdge.Q OR JoystickDeflected` → `SampleCountDone := FALSE` → **AX2_TRANSLATE_P1** *(retour direct à la translation P1, pas par AX0 : la machine est déjà référencée et le cycle enchaîne)* |
| **AX_STAB** (19) *(ex-`STABILIZING`)* | 🟥 step — repli défaut | tout **0** · `BucketCmd.ReqKoboldMeasureEnable := FALSE` · msg « acquitter le defaut » |

### ⬆️ Transverses (hors CASE, chaque scan)

| Rep. | Déclencheur | Effet |
|---|---|---|
| **GT-safe** | `NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent` | neutralise tout ; si cycle en cours (`State ∉ {AX0, AX18_DONE_SYNC, AX_STAB}`) → `PausedState := State`, `WaitingResume := TRUE` ; `RETURN` |
| **GT-dive-retry** | `State ∈ {AX5, AX6, AX7}` **ET** (erreur séquence Kobold **OU** `NOT JoystickDeflected` **OU** palier appliqué ≠ 4 sur M1 ou M2) | → **AX_DIVING_RETRY** (pas un défaut latché) |
| **GT-resume** | `WaitingResume` | `StartEdge.Q` → `State := PausedState` ; sinon *hold* + msg « Reprendre : StartCycle » |
| **GT-fault** | `ErrorEdge.Q` | `CycleStepAtError := State` → **AX_STAB** · `WaitingResume := FALSE` |
| **GT-reset** | `ResetEdge.Q` | si `State = AX_STAB` → **AX0** ; `SavedState := AX0` |
| **GT-abort** | `AbortEdge.Q` | → **AX0** · `WaitingResume := FALSE` · `PausedState := AX0` |
| **GT-permit** | relâche manche **OU** homme-mort pendant `Lifecycle.Busy` | commandes coupées, **étape conservée**, **pas de défaut** |

---

## 3️⃣ Causes de défaut latchées (§1 FB, → AX_STAB)

| # | Cause | Condition |
|---|---|---|
| 0 | `LimitLegalReached` | `AX4 / AX5 / AX6 / AX7` (plongée) |
| 1 | `WinchSyncError` | hors `AX0` / `AX_STAB` |
| 2 | `SpeedMismatchConfirmed` (écart vitesse M1/M2, 500 ms) | `AX11` (montée contrôle) |
| 3 | `NOT HeartbeatIhmOk` | hors `AX0` / `AX_STAB` |
| 4 | `StepMaxTimer.Q` (backstop durée d'étape, réarmé au changement d'étape) | hors `AX_STAB` / `AX_DIVING_RETRY` |
| 5 | stabilisation / tolérance écart codeurs | `AX11` |
| 6 | anti-télescopage `ABS(M1_CablePosM − M2_CablePosM) > CST_CoupledPosBacklashM` | `AX4 / AX5 / AX6 / AX7 / AX9 / AX12 / AX15C` |
| 7 | **treuils quittent le FDC haut pendant la translation** (`ABS(M1/M2 − CfgCableLimitAscent_M) > CST_CycleInitWindowM`) | `AX2` |
| 8 | **palier vitesse ≠ 4 pendant la plongée** (palier 5 interdit) | `AX4 / AX5 / AX6 / AX7` |

> **DIVING** : `GT-dive-retry` (erreur Kobold / joystick relâché / palier ≠ 4 en `AX5..AX7`) = **reprise vers `AX_DIVING_RETRY` → `AX4`**, PAS un défaut latché. Timeout immersion / fond (`AX6` / `AX7`) : idem repli retry (à confirmer — Q13).

---

## 4️⃣ ❓ Questions ouvertes

| Q | Statut | Décision |
|---|---|---|
| **Q1** | ✅ *(révisé)* | **Renumérotation ASSUMÉE — c'est un refactor.** DIVING décomposé : `AX4_DESCEND_DIVING`, `AX5_KOBOLD_INIT`, `AX6_SEARCH_IMMERSION`, `AX7_SEARCH_BOTTOM`, `AX8_BOTTOM_CONFIRMED` + step spécial `AX_DIVING_RETRY`. EXTRACTION = `AX9_RAISE_OFF_BOTTOM`, `AX10_CLOSE_BUCKET`, `AX11_CTRL_ASCENT`, `AX12_LOADED_ASCENT`. DÉCHARGE = `AX13`…`AX15C` + `AX18_DONE_SYNC`. `AX_STAB` = 19. `AT0` = `Enable (SEMI_AUTO) AND (StartEdge OR DeadmanArmedEdge) AND NOT Fault.Latched` → AX1. Voir §2 pour la table valeur↔nom complète. |
| **Q2** | ✅ | `AX1_HOMING` → **`AX1_INIT`** : vérif des **conditions initiales** (Homed M1/M2, benne référencée, aucun défaut, treuils au FDC logiciel haut, chariot en posture de départ ±0,4 m). Aucun mouvement, aucun référencement. |
| **Q3** | ✅ | `AX0_REPOS` garde son contenu de park (mise a 0 des ordres + Lifecycle idle + `SampleCountDone := FALSE`). |
| **Q4** | ⛔ *(remplacé par Q14)* | ~~`AX_DONE → AX0` direct~~. |
| **Q5** | ✅ | `E_CycleStep` → **`E_AutoCycleStep`** ; toutes valeurs `X*` → `AX*` (valeurs numeriques inchangees). |
| **Q6** | ✅ | `AX2` = pas de selection. `SelectedWorkTarget` **supprime** de l'interface. |
| **Q7** | ✅ | Posture de départ (`InitPositionOk`) vérifiée en **`AX1_INIT`** (pas sur AT0) : `PRG_03` calcule chariot P1 **ET** `ABS(M1_CablePosM − CfgCableLimitAscent_M) ≤ 0,4 m` **ET** idem M2. Constante `CST_CycleInitWindowM := 0,4` dans `PRG_03`. |
| **Q8** | 🟡 | « benne référencée » en AX1_INIT : quelle entrée ? (`FB_CycleSemiAuto` n'a pas de flag benne-datum ; proxy = `MachineHomed` via gate FB_Modes, ou ajouter un input dédié). |
| **Q9** | ✅ | **Diving = 5 steps du GRAFCET** : `AX4_DESCEND_DIVING` (descente palier 4, Kobold OFF) → `AX5_KOBOLD_INIT` (active contacteur Kobold « au vol » à `DiveStartMin_M` ≈ 3–5 m, vérif retour) → `AX6_SEARCH_IMMERSION` (front DI Kobold 0→1, sous ≈ 0,5 m) → `AX7_SEARCH_BOTTOM` (front DI Kobold 1→0) → `AX8_BOTTOM_CONFIRMED` (coupure instantanée + set bit « fond touché » + `TouchPositionM`/`RaiseTargetM`). Palier 4 mini ET maxi sur `AX4..AX7` (`CST_StepDive` 3→**4**), palier ≠ 4 → cause 8. `FB_DiveSearch` réutilisable comme brique de détection dans `AX6`/`AX7`. |
| **Q10** | ✅ | **AX2 sans commande M3** : le cycle ne pilote pas la translation (opérateur + `PRG_05`). Surveillance treuils au FDC haut → sortie défaut (cause 7). Contrôle « chariot pas à droite de P1 » = **AX1_INIT** uniquement (l'ancien `AT2b` msg maintenance est supprimé). |
| **Q11** | ✅ | **Reprise diving = step spécial `AX_DIVING_RETRY`** (pas un repli sur `AX_STAB`). Transverse `GT-dive-retry` actif en `AX5/AX6/AX7` : **erreur séquence Kobold** OU **joystick relâché** OU **palier appliqué ≠ 4 sur M1 ou M2** → `AX_DIVING_RETRY`. Dans ce step : treuils 0 puis **remontée assistée palier lent jusqu'au FDC haut**, Kobold coupé. Treuils au FDC haut → **`AX4_DESCEND_DIVING`** (nouvelle tentative). Abandon → `GT-abort` → `AX0`. PAS de défaut latché. |
| **Q12** | ✅ | **Extraction = 4 steps** : `AX9_RAISE_OFF_BOTTOM` (décollement fond, montée lente, +0,5 m) · `AX10_CLOSE_BUCKET` (fermeture benne, treuils 0) · `AX11_CTRL_ASCENT` (montée contrôle palier lent + surveillance écart vitesse M1/M2) · `AX12_LOADED_ASCENT` (montée en charge palier 4 jusqu'à `CableLimitM1AscentM`). Reprise du contenu des ex-`AX5..AX8`, renommés. Pas de sous-init / retry propre à l'extraction (à challenger si besoin). |
| **Q13** | 🟡 | **Timeout immersion / fond** (`AX6` / `AX7`, calculs `FB_DiveSearch`) : repli `AX_DIVING_RETRY` (comme joystick relâché) ou défaut latché `AX_STAB` ? — à trancher. |
| **Q14** | ✅ *(remplace Q4)* | **Rebouclage après vidage** : `AX18_DONE_SYNC` (compteur + durée) → msg « aller en P1 » → `AT18` (`StartEdge` ou joystick maintenu) → **`AX2_TRANSLATE_P1`** directement (PAS retour `AX0` : machine déjà référencée, la passe suivante enchaîne sur la translation P1). `AX0_REPOS` n'est atteint que par `GT-abort` / `GT-reset` / arrêt mode. |
| **Q16** | ✅ | **Paramètres réglables IHM pour essais** (`GVL_IHM.Cycle.Cfg`) : `DrainTime` (existe) · `CfgRaiseOffBottom_M` (défaut 0,5 m, `AX8`→`AX9`) · `DiveStartMin_M` (altimétrie lancement Kobold, 3–5 m, `AX4`→`AX5`) · `CfgCtrlAscentMaxStep` (palier max `AX11`, défaut 1, clamp **1..2**). Tous bornés côté FB. |
| **Q15** | ✅ | **Pas de capteur de mou de câble.** Détection = **visuelle opérateur**. Sur `AX9` / `AX10` / `AX11` : l'IHM expose un **sélecteur de couplage** `BOTH` (défaut) / `M1 seul` / `M2 seul` (cas treuil bloqué ou câble trop détendu). Le **basculement de mode n'est autorisé que joystick au centre** (aucune commande) — garde à assurer côté **code winch / `PRG_04`**, pas dans `FB_CycleSemiAuto`. Retour `BOTH` au jugé de l'opérateur (pas de critère automatique). |

---

_Brouillon 2026-09-03. Signale les erreurs, je corrige._
