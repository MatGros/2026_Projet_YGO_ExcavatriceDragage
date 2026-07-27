# 🔬 ANALYSE D'IMPACT — Chaînes actionneurs & capteurs face au débranchement simulation (v1.0)

> 🎯 **Question unique** : après P1 (débranchement simulation) et P2 (frontière `ST_HardwareImage`),
> **chaque actionneur reste-t-il pilotable de bout en bout, et un blocage nouveau peut-il apparaître ?**
> 📅 2026-07-27 · **aucun fichier `CODE/` modifié** (analyse en lecture seule).
> 🔗 [PLAN_Rationalisation_Simulation_v1.0](PLAN_Rationalisation_Simulation_v1.0.md) ·
> [SEQUENCE_Execution_Simulation_v1.0](SEQUENCE_Execution_Simulation_v1.0.md)
> 📌 Ce document **remplit le livrable L1** (« tableau de neutralité ») en l'élargissant aux chaînes
> complètes, commande **et** capteur.

---

## 1. 📊 Synthèse

| Indicateur | Valeur |
|---|---|
| **Chaînes analysées** | **40** — 14 chaînes de commande (actionneurs) + 26 chaînes capteur |
| ✅ **PRÉSERVÉ** (machine réelle strictement identique) | **36** |
| ⚠️ **RISQUE** (la valeur peut changer sous condition) | **4** |
| 🔴 **BLOQUANT causé par la modification** | **0** |
| 🔴 **Blocages PRÉEXISTANTS exposés/démasqués par la modification** | **5** (voir §6) |

### 🧾 Verdict global

**P1 est neutre pour la machine réelle** — démontré point par point en §3/§4. La raison est structurelle :
`GVL_Simulation.SimulationModeActive` est un `VAR_GLOBAL` **non RETAIN** initialisé à `FALSE`
(`CODE/SIMULATION/GVL_Simulation.st:34`), donc **chaque terme simulation se réduit algébriquement à sa
branche réelle** (`X OR FALSE = X`, `SEL(FALSE, Réel, Simulé) = Réel`, `IF FALSE THEN … ELSE Réel`).
Idem pour les 20 `Override*` de `GVL_PLC_Tests` : `VAR_GLOBAL` non RETAIN, `FALSE` au boot, plus aucun
automate ne les écrit (`CODE/SIMULATION/GVL_PLC_Tests.st:18`), sauf les 5 M3 que `PRG_09` force
explicitement à `FALSE` hors simulation (`PRG_09_Supervision.st:69-74`).

⚠️ **Les 4 risques et les 5 blocages préexistants portent tous sur le même point aveugle** : la
modification **retire le filet qui masquait un câblage absent**. Elle ne crée aucun blocage, mais elle
rend visibles ceux qui existent déjà — ce qui est exactement l'objectif du chantier, à condition de
l'instruire **avant** l'essai machine et pas pendant.

### 🐛 Un bug **prouvé** trouvé au passage (indépendant du chantier)

**Le capteur PV de la translation M3 n'est relié à rien.** La voie physique est mappée sous le nom
`PosPV_DI_` (underscore final, `Device.export:40712`), nom qui **n'apparaît nulle part dans `CODE/`** ;
le programme lit `GVL_Translation_M3_Stub.PosPV_DI` (`PRG_00_Inputs.st:267`), un stub que **rien
n'écrit**. Conséquence en mode réel : mot des 5 capteurs M3 systématiquement **incohérent** dès qu'un
autre capteur est actif ⇒ `FB_Safety_Translation` bit7 ⇒ `SafeStop` **+ `PowerCutOff`**, et **butées
extrêmes M3 inopérantes**. La simulation masquait entièrement ce défaut. 👉 **§6.1**

### 🚨 Prérequis absolu, non listé dans le plan

> **Relever `GVL_Simulation.SimulationModeActive` et les 18 `*IsReal` sur l'automate en service AVANT
> d'appliquer L4a→L4d** (lot L0).
> La démonstration de neutralité ne vaut **que si `SimulationModeActive = FALSE` sur l'automate au moment
> du changement**. Si la mise en service actuelle tourne avec ce bit à `TRUE` (ce que suggèrent les
> valeurs par défaut `*IsReal := FALSE` = « rien n'est câblé »), alors P1 supprime d'un coup **10 forçages
> « capteur sain »** et la machine peut se retrouver en `SafeStop` + `PowerCutOff` permanents au premier
> download. Ce relevé est un **GO/NO-GO**, pas une formalité.

---

## 2. 🗂️ Tableau récapitulatif — actionneurs

Toutes les sorties physiques du projet, relevées dans `CODE/MAIN/PRG_10_Outputs.st` et `CODE/MAIN/PRG_02_Encoders.st`.

| # | Actionneur (sortie physique) | `fichier:ligne` d'écriture | Origine de commande | Condition la plus critique traversée | Verdict P1 | Verdict P2 |
|---|---|---|---|---|---|---|
| A1 | `M1_RelayFwd_DQ` (montée M1) | `PRG_10_Outputs.st:74` | Joystick Y+ / boutons IHM / cycle | `ForbidAscent` (terme **non bypassable** dans le FB, `FB_Safety_Winch.st:539-541`) | ✅ | ✅ |
| A2 | `M1_RelayRev_DQ` (descente M1) | `PRG_10_Outputs.st:77` | idem | `ForbidDescent` ← mou de câble / limite basse / limite légale | ✅ | ✅ |
| A3 | `M1_SpeedContactor_1..4_DQ` | `PRG_10_Outputs.st:80-89` | `FB_SpeedStep` via `SpeedRamp.Current` | `ActiveMaxStep := 1` si `NOT Homed OR HomingSuspect` (`FB_Winch.st:235-241`) | ✅ | ✅ |
| A4 | `M1_BrakeCmd_RQ` | `PRG_10_Outputs.st:92` | `FB_Brake` composé dans `FB_Winch` | `Brake.Error` → `BrakeSafetyOk=FALSE` → relais coupés (`FB_Winch.st:266-269`) | ✅ | ✅ |
| A5 | `M2_RelayFwd_DQ` (montée M2) | `PRG_10_Outputs.st:96` | Joystick / boutons / cycle / **`FB_Bucket`** | `instBucket.Busy` prend la main sur l'arbitrage (`PRG_06:200-203`) | ✅ | ✅ |
| A6 | `M2_RelayRev_DQ` (descente M2) | `PRG_10_Outputs.st:99` | idem | idem + `ForbidDescent` M2 | ✅ | ✅ |
| A7 | `M2_SpeedContactor_1..4_DQ` | `PRG_10_Outputs.st:102-111` | `FB_SpeedStep` M2 | table verrouillée palier 1 si `M2_ForceSlowSpeed` (`PRG_06:326-350`) | ✅ | ✅ |
| A8 | `M2_BrakeCmd_RQ` | `PRG_10_Outputs.st:114` | `FB_Brake` M2 | idem A4 | ✅ | ✅ |
| A9 | `M3_CommandWord` (sens/marche variateur) | `PRG_10_Outputs.st:127` | Joystick X / `BtnFwd`/`BtnRev` / cycle | `LimitSwitchFwd/Rev` dérivés du **mot 5 capteurs** (`FB_Translation.st:202-206`) | ⚠️ | ⚠️ |
| A10 | `M3_SetpointFrequencyHz` | `PRG_10_Outputs.st:128` | `DriveFreqRefHz` ← rampe | `BrakeSafetyOk` (`FB_Translation.st:218-222`) | ⚠️ | ⚠️ |
| A11 | `M3_BrakeCmd_RQ` | `PRG_10_Outputs.st:118` | `instTranslationM3.BrakeCmd` (`PRG_07:166`) | `BrakeFeedback` via `SEL(Bypass.ContactorFeedback …)` (`PRG_07:160`) | ⚠️ | ⚠️ |
| A12 | `KoboldContactor_DQ` | `PRG_10_Outputs.st:122-124` | `instCycle.KoboldContactorCmd` (`PRG_06:557`) | `AND EmergencyStopOk AND EmergencyChain` (câblés en dur) | ✅ | ✅ |
| A13 | `PowerCutOff_A_RQ` / `_B_RQ` / `EmergencyArming_RQ` | `PRG_10_Outputs.st:155-157` | `FB_Safety_EmergencyManagement` | auto-test A/B : la boucle **doit retomber** à chaque coupure canal (`…Logic.st:93,120`) | ✅ | ✅ |
| A14 | `COD1/COD2_PresettTrigCmd`, `PresetValue`, `CodeSeqTrigCmd` | `PRG_02_Encoders.st:121-123, 171-173` | `FB_Encoder_Homing` → `FB_Encoder_Abs` | `EncoderAvailable` ← `SlaveOperational` (`FB_Encoder_Abs.st:108-113`) | ✅ | ✅ |
| — | `M3_RelayFwd_DQ` / `M3_RelayRev_DQ` | `PRG_10_Outputs.st:133-134` | **forcés `FALSE`** (obsolètes) | néant | ✅ | ✅ |

👉 **13 chaînes de commande sur 14 sont strictement préservées.** La seule ⚠️ est la chaîne M3
(A9/A10/A11), et elle porte sur **la manière d'écrire la modification**, pas sur son principe — voir §5.4
et §6.

---

## 3. 🔩 Détail par chaîne — SENS COMMANDE

### 3.1 🪝 M1 — montée (A1) et descente (A2)

```
Joystick Y (JoyYRaw_ANA2, %IW) ─► PRG_01:121 SEL(instSimJoystick.Enable, JoyYRaw_ANA2, …)
  └► FB_Joystick_0 (PRG_01:106-133)
       ├─ GATE : Enable · EmergencyStopOk · BusCanOpenOP.Operational · JoystickOP.Operational  [FB_Joystick.st:100]
       ├─ Homme-mort : DeadmanArmed (armement au neutre, reconfirmation < DeadmanRearmTimeout) [FB_Joystick.st:184-213]
       └─ AxisCmdY.SpeedRef / .Direction / .StartStop                                          [FB_Joystick.st:255-262]
  └► PRG_06 §1 ARBITRAGE  [PRG_06:140-197]
       SEMI_AUTO : instCycle.CmdWinchM1_StartStop AND DeadmanArmed AND AxisCmdY.StartStop AND NOT gate directionnel
       MAINT_N1/N2 + TglJoystickMaster : AxisCmdY.StartStop AND NOT instBucket.Busy AND DeadmanArmed
                                          AND (JoystickWinchSelectArbitrated = 1 OU 3)
       MAINT_N1/N2 + boutons IHM        : (Direction<>0) AND NOT instBucket.Busy
                                          AND (DeadmanArmed OR Bypass.Global M1)
  └► coupure immédiate sur front descendant de instBucket.Busy                                 [PRG_06:271-275]
  └► SafeStopM1_Active / ForbidAscentM1_Active / ForbidDescentM1_Active  (couplage croisé M1↔M2 si SyncActive)
                                                                                               [PRG_06:379-449]
  └► instWinchM1 (FB_Winch)
       ├─ GATE : Enable (StubMachineEnableN1 AND Mode<>DISABLE AND NOT InhibitM1) · EmergencyStopOk [FB_Winch.st:150]
       ├─ EffectiveSafeStop = SafeStop OR (ForbidDescent AND Dir<>1) OR (ForbidAscent AND Dir<>-1) [FB_Winch.st:188-190]
       ├─ Interlock changement de sens (vitesse confirmée nulle + 200 ms)                        [FB_Winch.st:216-231]
       ├─ ActiveMaxStep : 1 si NOT Homed OR HomingSuspect ; CfgMaxStepDescente en descente       [FB_Winch.st:235-250]
       ├─ BrakeSafetyOk = NOT Brake.Error OR BypassContactorCheck                                [FB_Winch.st:266]
       ├─ RelayFwd = (CommandedDirection=1) AND (StepNumber>0) AND BrakeSafetyOk                 [FB_Winch.st:268]
       ├─ IF ForbidAscent THEN RelayFwd := FALSE                                                 [FB_Winch.st:275-277]
       └─ IF Error THEN toutes sorties FALSE                                                     [FB_Winch.st:356-361]
  └► PRG_06:543-544 ─► PRG_10_Outputs.M1RelayFwd/Rev ─► PRG_10:74,77 ─► %QX M1_RelayFwd_DQ / M1_RelayRev_DQ
```

**Conditions touchées par la modification & valeur avant/après (mode réel) :**

| Condition | Point de code | Valeur AVANT (`SimActive=FALSE`) | Valeur APRÈS | Δ |
|---|---|---|---|---|
| `RawY` joystick | `PRG_01:121` `SEL(instSimJoystick.Enable, JoyYRaw_ANA2, …)` — `Enable=FALSE` | `JoyYRaw_ANA2` | `JoyYRaw_ANA2` | **0** ✅ |
| `DeadmanRearmTimeout` | `PRG_01:131` `SEL(NOT SimActive OR …, T#5M, T#10S)` — garde `TRUE` | `T#10S` | `T#10S` (en dur) | **0** ✅ |
| `NeutralHoldTime` | `PRG_01:132` — garde `TRUE` | `T#500MS` | `T#500MS` (en dur) | **0** ✅ |
| `EmergencyStopOk` | `PRG_00:176` `EmergencyStopOk_DI OR instSimSafety.SimContactorOk` — `Enable=FALSE` ⇒ sortie `FALSE` (`FB_Sim_Safety.st:37-42`) | `EmergencyStopOk_DI` | `EmergencyStopOk_DI` | **0** ✅ |
| `FwdRevSpeedFeedbackOff` | `PRG_00:220` `SEL(FALSE, …_DI, …_Simulated)` | `M1_FwdRevSpeedFeedbackOff_DI` | idem | **0** ✅ |
| `BrakeFeedback` | `PRG_00:230` idem + `InvertLogic := BrakeFeedbackInvertLogic` | `M1_BrakeFeedback_DI` inversé | idem | **0** ✅ |
| `BypassContactorCheck` | `PRG_06:478` `Bypass.Global OR (SimActive AND …)` | `Bypass.Global` | `Bypass.Global` | **0** ✅ |
| `TopPositionSensor` | `PRG_00:207` `…_DI OR (FALSE AND …)` | `M1_M2_TopPositionSensor_DI` | idem | **0** ✅ |
| `SlackCableSwitch` | `PRG_00:186` idem | `M2_SlackCableSwitch_DI` | idem | **0** ✅ |
| `PhaseRotationOk` | `PRG_00:210` idem | `CtrlPhaseRotation_DI` | idem | **0** ✅ |
| `BrakeThermalFeedback` | `PRG_00:214` idem | `BrakeThermalFeedback_DI` | idem | **0** ✅ |
| `M1ThermalFeedback` | `PRG_00:223` idem | `M1_ThermalFeedback_DI` | idem | **0** ✅ |
| `EncoderAvailable` (via `SlaveOperational`) | `PRG_02:117` `…Operational OR instSimEncoderM1.Enable` — `Enable=FALSE` | `DeviceEncoderM1.Operational` | idem | **0** ✅ |
| `CablePosM` (via `RawPosIn`) | `PRG_02:89-93` `IF FALSE THEN sim ELSE COD1_PosValue` | `COD1_PosValue` | idem | **0** ✅ |
| `HeartbeatIhmOk` | `PRG_01:91-95` SEL imbriqués, gardes `FALSE` | `GVL_IHM.Commun.TglHeartbeatIhm` | idem | **0** ✅ |
| 4 `Override*` M1 | `PRG_00:345-350` — `FALSE` au boot, aucun écrivain | sans effet | supprimés | **0** ✅ |

**Verdict A1/A2 : ✅ PRÉSERVÉ.** Aucune condition de la chaîne montée/descente M1 ne change de valeur en
mode réel. Idem A3 (paliers) et A4 (frein) : ils dérivent de `SpeedRamp.Current` et de `FB_Brake`, tous
deux alimentés par les mêmes entrées déjà réelles.

⚠️ **Ce que la modification retire réellement** : uniquement le forçage « capteur sain » **en mode banc**.
Conséquence attendue et voulue en simulation : `TopPositionSensor`, `SlackCableSwitch`, `PhaseRotationOk`,
`BrakeThermalFeedback`, `M1/M2ThermalFeedback` prennent leur valeur physique, et `BypassContactorCheck`
perd son terme simulation ⇒ `ContactorsCheck.StuckClosed` et `FB_Brake.StuckOpen/StuckClosed` **se
réarment**. C'est l'attendu documenté (`SEQUENCE §2 L6`, « ⚠️ Attendu nouveau »).

---

### 3.2 🪝 M2 — montée / descente / benne (A5→A8)

Identique à §3.1 pour la partie treuil (`PRG_06:497-536` → `PRG_06:551-558` → `PRG_10:96-114`), **plus**
la priorité benne :

```
instBucket (PRG_06:90-115)
  ├─ Enable = NOT InhibitM2 AND instEncoderAbsM1.EncoderAvailable AND instEncoderAbsM2.EncoderAvailable
  ├─ bit3 ErrorId si NOT HomedM1 OR NOT HomedM2                       [FB_Bucket.st:176-177]
  ├─ M1SlipDetected (bit4) ─► SafeStopM1_Raw                          [FB_Bucket.st:238 ; PRG_06:382]
  └─ instBucket.Busy ─► prend la main sur M2_StartStop/Direction/Speed [PRG_06:200-203]
```

**Chemin touché** : `EncoderAvailable` M1 **et** M2 sont exigés pour armer la benne. Ce sont les mêmes
`SlaveOperational` que §3.1 → **inchangés en réel** (`PRG_02:117,167`). **Verdict : ✅ PRÉSERVÉ.**

⚠️ Point d'attention non lié à la simulation, mais qui pèse sur l'essai machine L4d : la benne exige
**deux codeurs disponibles ET référencés**. Toute perte codeur bloque le benne avant même la question du
mouvement.

---

### 3.3 ↔️ M3 — translation (A9/A10/A11)

```
Joystick X / GVL_IHM.TranslationM3.Cmd.BtnFwd|BtnRev / instCycle.CmdTranslationM3_*
  └► PRG_07 §1/§1bis arbitrage  [PRG_07:35-111]
       SEMI_AUTO : CmdTranslationM3_Start AND DeadmanArmed AND AxisCmdX.StartStop
       MAINT_N1/N2 : (Direction<>0) AND (DeadmanArmed OR Bypass.Global) AND (NOT TglJoystickMaster OR AxisCmdX.StartStop)
  └► cible bloquée si SelTarget=4 hors MAINT_N2                        [PRG_07:125-127]
  └► M3_PositionSensorTarget ← capteur de la cible                     [PRG_07:130-137]
  └► instTranslationM3 (FB_Translation)
       ├─ GATE Enable / EmergencyStopOk                                [FB_Translation.st:86]
       ├─ SafeStop ← FB_Safety_Translation                             [PRG_07:147]
       ├─ RampTargetPct = 0 si LimitSwitchFwd/Rev dans le sens demandé [FB_Translation.st:128-132]
       ├─ ralentissement PV si Direction=1 AND SlowdownSensor          [FB_Translation.st:140-142]
       ├─ ArrivalLock sur capteur cible                                [FB_Translation.st:144-152]
       ├─ DriveControlWord 0/1/2/7                                     [FB_Translation.st:184-198]
       ├─ coupure immédiate sur Fdc extrême                            [FB_Translation.st:202-206]
       ├─ BrakeSafetyOk = NOT Brake.Error OR BypassContactorCheck      [FB_Translation.st:218-222]
       └─ IF Error THEN CommandWord=0, FreqRef=0, BrakeCmd=FALSE       [FB_Translation.st:269-272]
  └► PRG_10:127-128 ─► M3_CommandWord / M3_SetpointFrequencyHz   ·  PRG_07:166 ─► PRG_10:118 ─► M3_BrakeCmd_RQ
```

**Conditions touchées, valeur avant/après (mode réel) :**

| Condition | Point | AVANT | APRÈS | Δ |
|---|---|---|---|---|
| 5 capteurs position | `PRG_00:264-277` `SEL(FALSE, …_DI, instSimTranslation.…)` | `PosTremie_DI`, `GVL_Translation_M3_Stub.PosPV_DI`, `PosFosse2_DI`, `PosFosse1_DI`, `PosMaintenance_DI` | idem | **0** ✅ |
| `M3BrakeFeedback` | `PRG_00:291` `SEL(FALSE, M3_BrakeFeedback_DI, …)` | `M3_BrakeFeedback_DI` inversé | idem | **0** ✅ |
| `M3_StatusWord_Filtered` | `PRG_00:295-309` branche `ELSE` | `M3_StatusWord` | idem | **0** ✅ |
| `M3_ActualFrequencyHz_Filtered` | idem | `M3_ActualFrequencyHz` | idem | **0** ✅ |
| `BypassContactorCheck` M3 | `PRG_07:161` | `Bypass.Global` | `Bypass.Global` | **0** ✅ |
| `BrakeFeedback` FB | `PRG_07:160` `SEL(Bypass.ContactorFeedback OR Bypass.Global, M3BrakeFeedback, instTranslationM3.BrakeCmd)` | `Bypass.ContactorFeedback` forcé `FALSE` par `PRG_09:293` ⇒ `M3BrakeFeedback` | **dépend de l'écriture** ⚠️ | voir §5.4 |
| 5 `Override*` M3 | `PRG_00:325-342`, écrits `FALSE` par `PRG_09:70-73` | sans effet | supprimés | **0** ✅ |
| `DriveCommReady`/`PowerReady` | `PRG_09:509-510` | `StatusWord.7` / `.0` | idem | **0** ✅ (affichage seul) |

**Verdict A9/A10/A11 : ⚠️ RISQUE** — conditionnel à la façon dont `PRG_09` §4 est modifié (§5.4), et
**🔴 blocage préexistant** sur le capteur PV (§6.1) qui n'est pas causé par la modification mais que
celle-ci démasque.

---

### 3.4 🪨 Kobold (A12)

```
instCycle (PRG_05:44-88)
  └─ étape BOTTOM_TOUCH_WAIT : KoboldContactorCmd := TRUE            [FB_Cycle.st:269]
     transition conditionnée par  CycleMotionPermit AND KoboldContactFond  [FB_Cycle.st:272]
  └► PRG_06:557 ─► PRG_10_Outputs.KoboldContactorCmd
  └► PRG_10:122-124  KoboldContactor_DQ := Cmd AND EmergencyStopOk AND EmergencyChain
```

`KoboldContactFond` ← `PRG_00:191-197` : `KoboldContactFond_DI OR (SimActive AND NOT …IsReal AND
GVL_Simulation.SimKoboldContactFondValue)`. En réel : `KoboldContactFond_DI`. La suppression de
`PRG_05:39` (`GVL_Simulation.SimKoboldContactFondValue := GVL_IHM.Cycle.Test.KoboldContactFond`) retire un
**flux inversé** sans consommateur en mode réel.

**Verdict : ✅ PRÉSERVÉ** pour la sortie `KoboldContactor_DQ`.
⚠️ **Mais** : la transition de cycle dépend de `KoboldContactFond_DI`. Si ce fil n'est pas raccordé, le
cycle semi-auto reste **bloqué en `BOTTOM_TOUCH_WAIT`** — sans défaut, sans message. Le seul chemin
d'injection opérateur (`GVL_IHM.Cycle.Test.KoboldContactFond`) disparaît en L3. Voir §6.4.

---

### 3.5 🧨 Chaîne AU / `PowerCutOff` / réarmement (A13)

```
PRG_03_Safety : instSafetyWinchM1/M2.PowerCutOff · instSafetyTranslationM3.PowerCutOff
  └► PRG_10:139-141  PowerCutOffReq
  └► instSafetyEmergencyManagement(… EmergencyChain, EmergencyStopOk, PowerCutOffRequest, BtnEmergencyCutOff)
       └─ séquence : TestA(200 ms) → RestoreA → TestB(200 ms) → RestoreB → Pulse(1 s) → Confirm(2 s)
                                                            [FB_Safety_EmergencyManagementLogic.st:88-159]
       └─ Cmd.PowerCutOff_A/B_Cmd = NOT PowerCutOffRequest AND NOT ForceTestA/B
                                    AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed   [ …Logic.st:168-169]
  └► PRG_10:155-157 ─► PowerCutOff_A_RQ · PowerCutOff_B_RQ · EmergencyArming_RQ  (fail-safe : TRUE = OK)
```

**Ce que la modification retire** : l'instance `instSimSafety` (`PRG_00:168-174`) et les 4 `Override*`
chaîne AU (`PRG_00:312-322`).

- `instSimSafety.Enable := SimActive AND NOT SensorEmergencyStopChainIsReal` = `FALSE` en réel
  ⇒ `SimChainOk = SimContactorOk = FALSE` (`FB_Sim_Safety.st:37-42`)
  ⇒ `EmergencyStopOk_DI OR FALSE` et `EmergencyChainOK_DI OR FALSE` : **identiques**. ✅
- `OverrideChainTrue/False`, `OverrideContactorFalse`, `OverrideEmergencyStopOkTrue` : `FALSE` au boot,
  aucun écrivain automate. Les 4 `IF` de `PRG_00:312-322` ne s'exécutent jamais. ✅
- L'auto-test A/B ne consomme **que** `EmergencyChain`, `EmergencyStopOk`, `PowerCutOffReq`,
  `BtnEmergencyCutOff` — tous déjà réels. **La séquence de réarmement est intégralement matérielle.** ✅

**Verdict A13 : ✅ PRÉSERVÉ.** La boucle est bouclée par le matériel : `PowerCutOff_A/B_RQ` (sorties)
→ contacteurs physiques → `EmergencyChainOK_DI` (entrée). Le retrait de `FB_Sim_Safety` ne coupe aucun
maillon réel — il coupait au contraire la **boucle simulée** qui court-circuitait ce parcours.

---

### 3.6 🧲 Preset codeurs COD1/COD2 (A14)

```
GVL_IHM.MxTreuil.Cmd.BtnHome / BtnHomingAtZero
  └► instHomingMx (PRG_02:125-149, 175-199)
       conditions de rejet : Mode ∉ {MAINT_N1, MAINT_N2} · UnitaryMode sans MAINT_N2 · mauvais treuil
       · NOT EncoderAvailable (bit3) · NOT ArretConfirme (bit2 : FwdRevSpeedFeedbackOff AND BrakeFeedback)
       · cible hors [-99;+99] · **capteur haut non confirmé** (bit4 si `TopPositionSensor = TRUE`)
                                                                       [FB_Encoder_Homing.st:156-178]
  └► instEncoderAbsMx.PresetRequest ─► CASE PresetSeqStep ─► PresetTriggerCmd := 2   [FB_Encoder_Abs.st:134-162]
  └► PRG_02:121-123 / 171-173 ─► COD1/COD2_PresettTrigCmd · _PresetValue · _CodeSeqTrigCmd (toujours 0)
```

**Conditions touchées** : `EncoderAvailable` (via `SlaveOperational`, `PRG_02:117/167`),
`FwdRevSpeedFeedbackOff`, `BrakeFeedback`, `TopPositionSensor` — **toutes déjà réelles**. ✅

**Verdict A14 : ✅ PRÉSERVÉ.**
⚠️ Sémantique à retenir pour §6.2 : `FB_Encoder_Homing.st:168` rejette le homing quand
`TopPositionSensor = TRUE` (capteur **libre**). Un capteur haut **non câblé** lit `FALSE` = « butée
atteinte » ⇒ **le homing est accepté n'importe où**. C'est un faux-positif, pas un blocage.

---

## 4. 📡 Détail par chaîne — SENS CAPTEUR

Toutes les entrées physiques du projet, leurs consommateurs et l'effet de la modification.
Convention `FB_Input` : `ValueRaw := InputRaw XOR InvertLogic` (`FB_Input.st:38`) ; seul le retour frein
utilise `InvertLogic` (`BrakeFeedbackInvertLogic := TRUE`, `PRG_00:118`).

| Entrée physique | Conditionnement | Consommateurs (métier / safety / IHM) | Effet modification (réel) | Verdict |
|---|---|---|---|---|
| `EmergencyStopOk_DI` | `PRG_00:176` + `FB_Input` 20 ms | **portail maître** : `FB_Winch:150`, `FB_Translation:86`, `FB_Joystick:100`, `FB_Safety_Winch:280,525`, `FB_Cycle`, `FB_Encoder_*`, `PRG_10:123,149`, IHM `PRG_09:136,556` | `OR instSimSafety.SimContactorOk` ⇒ `OR FALSE` | ✅ |
| `EmergencyChainOK_DI` | `PRG_00:181` | `PRG_10:124,148` (Kobold + séquence AU), IHM `PRG_09:135,138` | `OR FALSE` | ✅ |
| `M1_M2_TopPositionSensor_DI` | `PRG_00:207` | `FB_Safety_Winch` bit5 (`:357`), **Méca D bit11** (`:451`), **`ForbidAscent` inconditionnel** (`:540`), `FB_Encoder_Homing:168` ×2, IHM `PRG_09:284` | `OR (FALSE AND NOT SimTopSensorTriggered)` ⇒ `DI` | ✅ |
| `M2_SlackCableSwitch_DI` | `PRG_00:186` | `FB_Safety_Winch` bit3 → `SafeStop` (SyncEnable) / `ForbidAscent` (récup) — **2 instances** (`PRG_03:44,102`), IHM `PRG_09:337,404` | `OR FALSE` | ✅ |
| `KoboldContactFond_DI` | `PRG_00:191-197` | `FB_Cycle:272` (transition fond), IHM `PRG_09:526` | `OR (FALSE AND … AND SimKoboldContactFondValue)` | ✅ |
| `CtrlPhaseRotation_DI` | `PRG_00:210` | `FB_Safety_Winch` bit4 ×2 (`PRG_03:45,103`), `FB_Safety_Translation` bit2 (`PRG_03:203`), IHM `PRG_09:122` | `OR FALSE` | ✅ |
| `BrakeThermalFeedback_DI` | `PRG_00:214` | `FB_Safety_Winch` **bit10 → SafeStop + PowerCutOff** ×2 (`PRG_03:43,101`), `FB_Safety_Translation` **bit3 → idem** (`PRG_03:204`), IHM `PRG_09:121` | `OR FALSE` | ✅ |
| `M1_ThermalFeedback_DI` | `PRG_00:223` | `FB_Safety_Winch` M1 **bit2 → SafeStop + PowerCutOff** (`PRG_03:42`), IHM `PRG_09:338` | `OR FALSE` | ✅ |
| `M2_ThermalFeedback_DI` | `PRG_00:239` | idem M2 (`PRG_03:100`), IHM `PRG_09:405` | `OR FALSE` | ✅ |
| `ThermHydraulique_DI` | `PRG_08:24` | **`GVL_IHM.Commun.HydraulicThermalFault` uniquement** (`PRG_09:123`) — aucun consommateur métier | `OR FALSE` | ✅ |
| `M1_FwdRevSpeedFeedbackOff_DI` | `PRG_00:220` `SEL` | `FB_Winch` `ContactorsCheck` (`:294`), `FB_Safety_Winch` Méca A/B/D/E (`:387,407,454,478`), `FB_Encoder_Homing:137` | `SEL(FALSE, DI, Sim)` ⇒ `DI` | ✅ |
| `M2_FwdRevSpeedFeedbackOff_DI` | `PRG_00:236` `SEL` | idem M2 | idem | ✅ |
| `M1_BrakeFeedback_DI` | `PRG_00:230` `SEL` + inversion | `FB_Brake.ContactorFeedback` (test `=`, `FB_Brake.st:112`), `FB_Safety_Winch` Méca A/B/D/E, `FB_Encoder_Homing:137` | idem | ✅ |
| `M2_BrakeFeedback_DI` | `PRG_00:245` `SEL` + inversion | idem M2 | idem | ✅ |
| `M3_BrakeFeedback_DI` | `PRG_00:291` `SEL` + inversion | `FB_Safety_Translation` Méca A/B (`PRG_03:209`), `FB_Translation` via `SEL` `PRG_07:160`, IHM `PRG_09:470` | `SEL(FALSE, DI, Sim)` ⇒ `DI` | ⚠️ (§5.4) |
| `PosTremie_DI` | `PRG_00:264` `SEL` | `instPositionDecoder` (`PRG_00:280`), `FB_Cycle`, `PRG_07:131`, IHM | ⇒ `DI` | ✅ |
| `GVL_Translation_M3_Stub.PosPV_DI` | `PRG_00:267` `SEL` | `instPositionDecoder`, `FB_Translation.SlowdownSensor` (`PRG_07:151`) | ⇒ **stub jamais écrit** ; la voie physique est mappée sous `PosPV_DI_` (underscore final), non lue par `CODE/` | 🔴 §6.1 |
| `PosFosse2_DI` / `PosFosse1_DI` / `PosMaintenance_DI` | `PRG_00:270,273,276` `SEL` | `instPositionDecoder`, `FB_Cycle`, `PRG_07:132-134`, IHM | ⇒ `DI` | ✅ |
| `M3_StatusWord` | `PRG_00:295-309` `IF/ELSE` | `FB_Safety_Translation` Méca A/B (`.0`), `FB_Translation` bit3 (`.4`), IHM `.7`/`.0` | ⇒ branche `ELSE` | ✅ |
| `M3_ActualFrequencyHz` | idem | `FB_Safety_Translation` Méca A/B (seuil 0,5 Hz), IHM `PRG_09:512`. ⚠️ `FB_Translation.DriveActualFreqHz` est **déclaré mais jamais lu** dans le corps | ⇒ branche `ELSE` | ✅ |
| `COD1_PosValue` / `COD2_PosValue` | `PRG_02:89-99` `IF/ELSE` | `FB_Encoder_Abs.RawPosIn` → `Scale` → `Safety`/`Homing`/`Sync`/`Bucket`/`Cycle` | ⇒ branche `ELSE` | ✅ |
| `COD1/COD2_Alarms` | `PRG_02:115,165` `SEL` | `FB_Encoder_Abs:108` → `EncoderAvailable` | `SEL(FALSE, COD_Alarms, 0)` ⇒ `COD_Alarms` | ✅ |
| `COD1/COD2_Warnings` | `PRG_02:116,166` `SEL` | informatif (`FB_Encoder_Abs:51`), IHM | idem | ✅ |
| `JoyXRaw_ANA1` / `JoyYRaw_ANA2` / `JoyBtnRaw` | `PRG_01:120-122` `SEL` | `FB_Joystick` (calibration, deadband, filtre, rampe, homme-mort) | `SEL(FALSE, Réel, Sim)` ⇒ réel | ✅ |
| `CANbus.GetBusState()` | `PRG_01:53` | `FB_DiagCanOpen` → `DeviceJoystick.Online/Operational` → `FB_Joystick:100`, `FB_Safety_*` bit0 | bypass sim ⇒ `FALSE` (déjà) | ✅ |
| `JOY1.GetDeviceState()` | `PRG_01:54` | idem | idem | ✅ |
| `AC600.GetDeviceState()` | `PRG_01:55` | `FB_DiagEthercat` → `DeviceVariateur` → `FB_Safety_Translation` bit1 | `DeviceVariateurSimBypass` ⇒ `FALSE` (déjà) | ✅ |
| `COD1/COD2.GetDeviceState()` | `PRG_01:56-57` | `FB_DiagEthercat` → `DeviceEncoderMx.Operational` → `FB_Encoder_Abs:108` → `EncoderAvailable` | idem | ✅ |
| `GVL_IHM.Commun.TglHeartbeatIhm` | `PRG_01:91-95` `SEL` | `FB_Safety_Winch` bit0 + **Méca B** ×2, `FB_Safety_Translation` bit0 + Méca B, **`FB_Cycle:175` → `ERROR_HOLD`** | ⇒ lecture directe (branche déjà active) | ⚠️ §5.3 |

👉 **26 chaînes capteur : 24 ✅, 2 ⚠️** (`M3_BrakeFeedback` et heartbeat), **0 valeur modifiée en mode réel**.

---

## 5. 🔍 Les 10 points de vigilance, instruits

### 5.1 `SimTopSensorTriggered` — que devient le capteur haut ?

**Code** : `PRG_00_Inputs.st:205-208`.
```
SimTopSensorTriggered := (NOT InhibitM1 AND instEncoderScaleM1.CablePosM >= _WinchM1CfgPersist.CfgTopSensorPos_M)
                      OR (NOT InhibitM2 AND instEncoderScaleM2.CablePosM >= _WinchM2CfgPersist.CfgTopSensorPos_M);
instTopPositionSensor(InputRaw := M1_M2_TopPositionSensor_DI OR (SimActive AND NOT SensorTopPositionIsReal AND NOT SimTopSensorTriggered), …);
```

**Réponse** :
1. `SimTopSensorTriggered` **n'a aucun autre lecteur** dans `CODE/` (vérifié par recherche exhaustive).
   Sa suppression est sans effet de bord.
2. En mode réel, le terme entier vaut `FALSE` ⇒ `TopPositionSensor = M1_M2_TopPositionSensor_DI`
   **déjà aujourd'hui**. Après P1 : **identique**. ✅
3. Sa suppression retire aussi les **seules lectures avant de `PRG_00` vers `PRG_02` et `PRG_04`**
   (`instEncoderScaleM1/M2.CablePosM`, `instModes.InhibitM1/M2`) — c'est un **bénéfice** : `PRG_00`
   redevient un vrai « position 0 » sans référence aval, prérequis de P2.
4. **Consommateurs de `TopPositionSensor`** (inchangés) :
   | Consommateur | `fichier:ligne` | Effet si `FALSE` (butée / fil absent) |
   |---|---|---|
   | `FB_Safety_Winch` bit5 | `:357` | `ErrorId.5` **si `Direction > 0`** → `ForbidAscent` ; bypassable (`BypassProcess`/`BypassTopLimitSwitch`) |
   | `FB_Safety_Winch` **`ForbidAscent` direct** | `:539-541` | `ForbidAscent := … OR (NOT TopPositionSensor AND NOT InReferencingMode)` — **hors du bloc `IF NOT BypassGlobal`, donc non neutralisé par aucun bypass interne** |
   | `FB_Safety_Winch` Méca D bit11 | `:450-456` | armé si `Direction >= 0` (⚠️ **0 inclus**) et contacteurs/frein non confirmés → après `PostRampTimeout` (3 s) → `SafeStop` **+ `PowerCutOff`** |
   | `FB_Encoder_Homing` | `:168` ×2 | rejet bit4 si `TopPositionSensor = TRUE` — voir §3.6 |
   | IHM | `PRG_09:284` | `TopPositionSensorActive` |

   ⚠️ **La seule parade au terme `:539-541`** est en amont, dans `PRG_06` :
   `ForbidAscentMx_Raw := NOT GVL_IHM.MxTreuil.Bypass.Global AND (…)` (`PRG_06:417,436`).
   Autrement dit : **`Bypass.Global` de l'axe est le seul moyen de remonter avec un capteur haut à
   `FALSE`.** À connaître avant l'essai machine.

**Verdict : ✅ PRÉSERVÉ** en réel. **🔴 exposition** si le capteur n'est pas câblé (§6.2).

---

### 5.2 `SlaveOperational` sans `OR instSimEncoderMx.Enable` — chemin de blocage ?

**Code** : `PRG_02_Encoders.st:117` et `:167`.

**Chaîne complète** :
```
COD1_CODEUR.GetDeviceState()  [PRG_01:56]
 └► FB_DiagEthercat : EncoderM1OnlineReal := (Raw = DEVICE_STATE.RUNNING)   [FB_DiagEthercat.st:106]
      EncoderM1OnlineEff := OnlineReal OR (SimBypass OR NetworkBypassActive) [ :110,114]
      DeviceEncoderM1.Operational := EncoderM1OnlineEff                      [ :132]
 └► PRG_02:117  SlaveOperational := …Operational OR instSimEncoderM1.Enable
 └► FB_Encoder_Abs:108  IF (AlarmsIn <> 0) OR NOT SlaveOperational THEN ErrorId.0
      EncoderAvailable := (ErrorId AND 16#0001) = 0                          [ :113]
      RawPos GELÉ si NOT EncoderAvailable                                    [ :118-123]
 └► conséquences :
      · FB_Safety_Winch bit1 (EncoderAvailableEffective) → SafeStop          [FB_Safety_Winch.st:319-326]
      · FB_Bucket.Enable = … AND EncoderAvailable M1 AND M2                  [PRG_06:91-93]
      · FB_Encoder_Homing:162 → rejet bit3 « codeur indisponible »
      · CablePosM figé → Homed/limites/synchro figés
```

**Réponse** :
- **En mode réel, `instSimEncoderM1.Enable` vaut déjà `FALSE`** ⇒ `SlaveOperational` vaut déjà
  `DeviceEncoderM1.Operational`. **La suppression du `OR` ne change strictement rien.** ✅
- **Oui, c'est un chemin de blocage** — mais il est **déjà actif aujourd'hui en mode réel**. Un codeur
  dont le device n'est pas `RUNNING` ⇒ `EncoderAvailable = FALSE` ⇒ `SafeStop` permanent sur ce treuil
  (bit1), benne inhibée, homing refusé.
- **Deux parades existent, aucune n'est supprimée par P1** :
  1. `GVL_IHM.Network.Bypass.Global` (RETAIN) → `NetworkBypassActive` → force `OnlineEff = TRUE`
     (`FB_DiagEthercat.st:110-115`) ;
  2. `GVL_IHM.MxTreuil.Bypass.EncoderFault` **en MAINT_N2 uniquement**
     (`FB_Safety_Winch.st:319-321`) — lève le bit1 mais **pas** le gel de `RawPos`.

**Verdict : ✅ PRÉSERVÉ.** Le risque signalé en `SEQUENCE §2 L4b` est **un risque de découverte**, pas de
régression : si un faux défaut codeur apparaît après L4b, il était déjà là avant, simplement masqué par
un banc actif. ⚠️ Corollaire : **si le relevé L0 montre `SimulationModeActive = TRUE`, ce risque devient
réel et immédiat**.

---

### 5.3 Heartbeat IHM sans secours `BlinkClock` — la machine se bloque-t-elle ?

**Code** : `PRG_01_Diagnostics.st:89-98`.
```
TglHeartbeatIhm := SEL(OverrideIhmHeartbeatActive,            // FALSE au boot
                       SEL(SimActive AND NOT BusIhmHeartbeatIsReal,   // FALSE en réel
                           GVL_IHM.Commun.TglHeartbeatIhm,   // ◄── branche RÉELLE, déjà active
                           GVL_Global.BlinkClock),            // ◄── branche SIMULÉE
                       OverrideIhmHeartbeatToggle);
```

**Réponse 1 — valeur** : en mode réel, la branche retenue est **déjà** `GVL_IHM.Commun.TglHeartbeatIhm`.
`BlinkClock` n'est le secours **qu'en simulation**. La simplification est donc **strictement neutre**. ✅
(Le commentaire `PRG_01:87` le confirme : « Sans IHM réelle sur banc (simulation active), BlinkClock
fournit un toggle sain ».)

**Réponse 2 — consommateurs de `instIhmHeartbeat.HeartbeatIhmOk`** (recherche exhaustive) :

| Consommateur | `fichier:ligne` | Effet si `HeartbeatIhmOk = FALSE` | Bypass disponible ? |
|---|---|---|---|
| `FB_Safety_Winch` bit0 M1 | `PRG_03:39` → `FB_Safety_Winch.st:309` | `ErrorId.0` → **`SafeStop` M1** | ✅ `BypassOperatorComm` / `BypassProcess` / `Bypass.Global` |
| `FB_Safety_Winch` bit0 M2 | `PRG_03:97` | **`SafeStop` M2** | ✅ idem |
| `FB_Safety_Winch` **Méca B** ×2 | `FB_Safety_Winch.st:405-407` | `MecaB_NoOperatorCmd = TRUE`. `TonMecaB.IN` exige **en plus** `NOT (FwdRevSpeedFeedbackOff AND BrakeFeedback)` ⇒ **pas de déclenchement à l'arrêt confirmé**, mais bit8 → `SafeStop` + **`PowerCutOff`** si l'arrêt n'est pas confirmé sous 3 s | ✅ `BypassSafety` / `BypassMecaB` |
| `FB_Safety_Translation` bit0 | `PRG_03:202` → `FB_Safety_Translation.st:125` | **`SafeStop` M3** | ✅ `BypassOperatorComm` / `BypassProcess` / `Bypass.Global` |
| `FB_Safety_Translation` Méca B | `FB_Safety_Translation.st:157-158` | condition durcie : `(ABS(Freq)>0.5) OR StatusWord.0 OR NOT BrakeFeedback` → bit4 → **`PowerCutOff`** | ✅ `BypassSafety` / `BypassMecaB` |
| **`FB_Cycle`** | `PRG_05:49` → `FB_Cycle.st:175-179` | `Error := TRUE`, `ErrorId.5`, **`State := ERROR_HOLD`** — repli mémorisé, la reconnexion seule ne relance jamais | 🔴 **AUCUN bypass** |
| IHM (affichage) | `PRG_09:127-130` | information | — |

**Réponse 3 — dynamique** : `FB_IhmHeartbeat` démarre avec `HeartbeatIhmOk = TRUE` puis le `TON`
(`IhmTimeout := T#2s`, `PRG_01:96`) expire au bout de **2 s sans front**. Donc **sans IHM qui toggle
réellement, l'automate passe en `SafeStop` sur les 3 axes 2 s après le démarrage**, et le cycle
semi-auto en `ERROR_HOLD` **sans possibilité de bypass**.

**Verdict : ⚠️ RISQUE.** La valeur ne change pas, mais la modification **supprime le seul dispositif qui
permettait de faire tourner la machine sans IHM active**. Parade : voir §6.3.

---

### 5.4 `BypassContactorCheck` perdant son terme simulation — quels contrôles se réarment ?

**Code** : `PRG_06:478` (M1), `PRG_06:522` (M2), `PRG_07:161` (M3).
`Bypass.Global OR (SimActive AND NOT SensorMxContactorFeedbackIsReal)` → `Bypass.Global` seul.

**Contrôles réarmés (uniquement quand la simulation est active) :**

| Contrôle | `fichier:ligne` | Conséquence si déclenché |
|---|---|---|
| `FB_Brake.StuckClosed` (relâche commandée, retour « serré ») | `FB_Brake.st:113-117` | `ErrorId.0` → `Brake.Error` |
| `FB_Brake.StuckOpen` (serrage commandé, retour « relâché ») | idem | idem |
| `FB_Brake` sortie sûre | `FB_Brake.st:142-144` | `BrakeCmd := FALSE` (frein collé) |
| `FB_Winch.BrakeSafetyOk` | `FB_Winch.st:266-269` | `RelayFwd`/`RelayRev` **forcés `FALSE`** |
| `FB_Winch` bit0 (`Brake.Error`) | `FB_Winch.st:308-312` | `Error` → **toutes** sorties `FALSE` (`:356-361`) |
| `FB_Winch` `ContactorsCheck.StuckClosed` → bit1 | `FB_Winch.st:294-299, 318-326` | idem |
| `FB_Translation.BrakeSafetyOk` | `FB_Translation.st:218-222` | `DriveControlWord := 0`, `FreqRef := 0` |
| `FB_Translation` bit0 | `FB_Translation.st:225-229` | `Error` → toutes sorties `FALSE` (`:269-272`) |

**Réponse** : en mode réel, ces contrôles sont **déjà actifs aujourd'hui** (`BypassContactorCheck =
Bypass.Global`, `FALSE` par défaut). Aucun changement. ✅ **Verdict : ✅ PRÉSERVÉ** (mode réel), effet
attendu et voulu en mode banc.

#### ⚠️ 5.4bis — Le vrai risque est ailleurs : `PRG_09` §4 et le RETAIN

`GVL_IHM` est déclaré **`VAR_GLOBAL RETAIN`** (`CODE/SUPERVISION/GVL_IHM.st:7`).
`PRG_09:291-295` **réécrit ces 5 champs à chaque scan** :

```
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := SimActive AND NOT SensorM1ContactorFeedbackIsReal;  // PRG_09:291
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := …                                                    // PRG_09:292
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := …                                                    // PRG_09:293
GVL_IHM.Commun.Bypass.SlackCable                 := …                                                    // PRG_09:294
GVL_IHM.Commun.Bypass.TopPositionSensor          := …                                                    // PRG_09:295
```

Consommateurs relevés :
- `M1`/`M2`.`Bypass.ContactorFeedback` : **aucun lecteur** (écrits seulement) → suppression sans risque ;
- `Commun.Bypass.SlackCable` / `.TopPositionSensor` : **aucun lecteur** → idem ;
- **`TranslationM3.Bypass.ContactorFeedback` : LU** en `PRG_07:160`
  ```
  BrakeFeedback := SEL(Bypass.ContactorFeedback OR Bypass.Global, PRG_00_Inputs.M3BrakeFeedback, instTranslationM3.BrakeCmd)
  ```

🔴 **Piège** : si l'implémenteur **supprime** la ligne `PRG_09:293` au lieu de la remplacer par
`:= FALSE`, le champ devient **libre et RETAIN**. Une valeur résiduelle `TRUE` (ou un réglage IHM) suffit
alors à basculer `BrakeFeedback` sur `instTranslationM3.BrakeCmd`. Or :

- `M3BrakeFeedback` est normalisé **`TRUE = frein serré`** (`PRG_00:56-57`, inversion `FB_Input`),
- `instTranslationM3.BrakeCmd` vaut **`TRUE = frein desserré`** (`FB_Translation.st:62`),
- `FB_Brake` teste **l'égalité** `BrakeCmd = ContactorFeedback` (`FB_Brake.st:112`).

⇒ la branche bypass injecte `BrakeCmd` dans `ContactorFeedback` : **égalité permanente** ⇒ `TonFeedback`
expire après 1 s ⇒ `StuckClosed` ⇒ `Brake.Error` ⇒ `FB_Translation` bit0 ⇒ **`DriveControlWord := 0`,
`M3_BrakeCmd_RQ := FALSE` : M3 devient impilotable**, et `BypassContactorCheck` (`PRG_07:161`) **ne le
couvre pas** puisqu'il ne dépend que de `Bypass.Global`.

**Verdict : ⚠️ RISQUE → 🔴 BLOQUANT si mal implémenté.**
**Parade obligatoire** : écrire explicitement
`GVL_IHM.TranslationM3.Bypass.ContactorFeedback := FALSE;` (ne pas supprimer la ligne), ou —
préférable — corriger la polarité de `PRG_07:160` (chantier séparé, à instruire).

---

### 5.5 Les 8 capteurs passant de « forcé sain » à valeur réelle

⚠️ Précision de comptage : le plan parle de **8** conditions `DI OR (SimActive AND NOT …IsReal)`.
Relevé exact : **8 de cette forme** (`PRG_00:186, 191-196, 207, 210, 214, 223, 239` + `PRG_08:24`)
**plus 2 de forme voisine** `DI OR instSimSafety.Sim*` (`PRG_00:176, 181`). Soit **10 forçages
« capteur sain »** au total, tous neutres en mode réel.

Effet d'un fil **absent ou capteur NC non raccordé** (le canal lit `FALSE`) :

| # | Capteur | Valeur lue si non câblé | Chaîne déclenchée | Sévérité |
|---|---|---|---|---|
| 1 | `BrakeThermalFeedback_DI` | `FALSE` → `BrakeThermalFeedback = FALSE` → `NOT` = `TRUE` = surchauffe (`PRG_03:43,101,204`) | Winch **bit10** ×2 + Translation **bit3** → `SafeStop` **+ `PowerCutOff`** (`FB_Safety_Winch.st:556` masque `16#2F84` ; `FB_Safety_Translation.st:221` masque `16#00F8`) | 🔴🔴 **machine morte, puissance coupée** |
| 2 | `M1_ThermalFeedback_DI` / `M2_…` | `FALSE` → surchauffe | Winch **bit2** → `SafeStop` **+ `PowerCutOff`** (bit2 dans `16#2F84`) | 🔴🔴 |
| 3 | `M2_SlackCableSwitch_DI` | `FALSE` → `SlackCableDetected = TRUE` (`PRG_03:44,102`) | Winch **bit3** → `SafeStop` M1+M2 si `SyncEnable`, sinon `ForbidAscent` (`FB_Safety_Winch.st:527-531, 541`) | 🔴 mouvement bloqué |
| 4 | `M1_M2_TopPositionSensor_DI` | `FALSE` = butée atteinte | `ForbidAscent` **inconditionnel** M1+M2 (`FB_Safety_Winch.st:540`) + Méca D → `PowerCutOff` après 3 s si arrêt non confirmé | 🔴 **montée impossible** |
| 5 | `CtrlPhaseRotation_DI` | `FALSE` → `PhaseRotationOk = FALSE` | Winch **bit4** ×2 → `SafeStop` ; Translation **bit2** → `SafeStop` | 🔴 les 3 axes |
| 6 | `KoboldContactFond_DI` | `FALSE` = pas de contact | `FB_Cycle:272` : transition `BOTTOM_TOUCH_WAIT` jamais franchie | ⚠️ **cycle bloqué, sans défaut** |
| 7 | `ThermHydraulique_DI` | `FALSE` | `GVL_IHM.Commun.HydraulicThermalFault := TRUE` (`PRG_09:123`) — **aucun consommateur métier** | 🟢 **affichage seul** |
| 8 | `EmergencyStopOk_DI` / `EmergencyChainOK_DI` | `FALSE` | portail maître : `FB_Winch:150`, `FB_Translation:86`, `FB_Joystick:100`, `FB_Safety_Winch:525` (`SafeStop := TRUE`) | 🔴 immobilisation totale (comportement voulu) |

🧷 **Bypass disponibles par capteur** :
`BrakeThermal` → `BypassBrakeThermal` / `BypassSafety` / `Bypass.Global` ·
`Thermique moteur` → **`BypassSafety` uniquement** (pas de bypass individuel — `FB_Safety_Winch.st:329`) ·
`SlackCable` → `BypassProcess` / `Bypass.Global` ·
`TopPosition` → `BypassProcess`/`BypassTopLimitSwitch` pour bit5, mais **`Bypass.Global` de l'axe (`PRG_06:417,436`) est le seul recours pour `ForbidAscent`** ·
`PhaseRotation` → `BypassPhaseRotation` / `BypassProcess` ·
`Kobold` → **aucun**.

**Verdict d'ensemble : ✅ PRÉSERVÉ en mode réel** (aucune valeur ne change), **🔴 exposition immédiate si
la machine tourne actuellement avec `SimulationModeActive = TRUE`**.

---

### 5.6 `DriveCommReady` / `DrivePowerReady` — affichage ou condition de mouvement ?

**Code** : `PRG_09_Supervision.st:509-510`.
```
GVL_IHM.TranslationM3.State.DriveCommReady  := PRG_00_Inputs.M3_StatusWord_Filtered.7 OR GVL_Simulation.SimulationModeActive;
GVL_IHM.TranslationM3.State.DrivePowerReady := PRG_00_Inputs.M3_StatusWord_Filtered.0 OR GVL_Simulation.SimulationModeActive;
```

**Réponse** : recherche exhaustive des occurrences de `DriveCommReady` / `DrivePowerReady` dans `CODE/` :
- écriture unique en `PRG_09:509-510` ;
- déclaration en `ST_TranslationState.st:27-28` ;
- **aucune lecture par un FB métier ou safety.**

⇒ **Affichage IHM pur.** Le retrait du `OR SimulationModeActive` ne peut bloquer aucun mouvement.
En mode réel la valeur est déjà `StatusWord.7` / `.0`.

**Verdict : ✅ PRÉSERVÉ.** Effet visible uniquement : en simulation, ces deux voyants IHM ne seront plus
allumés artificiellement.

---

### 5.7 `M3_ActualFrequencyHz_Filtered` réel — faux défaut Méca A si variateur hors ligne ?

**Consommateurs réels** (recherche exhaustive) :
1. `FB_Safety_Translation.DriveActualFreqHz` (`PRG_03:208`) → Méca A (`:174`) et Méca B (`:158`) ;
2. `FB_Translation.DriveActualFreqHz` (`PRG_07:155`) → ⚠️ **entrée déclarée (`FB_Translation.st:28`) mais
   jamais lue dans le corps du FB** — sans effet ;
3. `GVL_IHM.TranslationM3.State.DriveActualFreq_Hz` (`PRG_09:512`) — affichage.

**Analyse Méca A** (`FB_Safety_Translation.st:172-182`) :
```
IF (Direction = 0) AND NOT BrakeCmd THEN
    UncommandedActiveA := ABS(DriveActualFreqHz) > 0.5;
```
Si le variateur n'est **pas** en ligne, le PDO `M3_ActualFrequencyHz` n'est plus rafraîchi ; CODESYS
maintient la dernière valeur de l'image process (ou 0 si jamais reçue). Deux cas :
- **jamais reçu / remis à 0** ⇒ `ABS(0.0) > 0.5` = `FALSE` ⇒ **aucun Méca A**. ✅
- **valeur figée non nulle** (perte en cours de mouvement) ⇒ Méca A peut se déclencher après 1 s
  (`TonMecaA`, `PT := T#1S`) ⇒ bit5 → `SafeStop` + **`PowerCutOff`**.
  ⚠️ Mais dans ce scénario, `bit1` (`DriveComm`, `:132-136`) est **déjà levé** au même moment, ce qui
  produit déjà un `SafeStop`. L'aggravation est le passage `SafeStop` → `SafeStop + PowerCutOff`.

**Réponse** : en mode réel, `M3_ActualFrequencyHz_Filtered` **vaut déjà `M3_ActualFrequencyHz`** — la
modification ne change rien. ✅ Le risque de « fréquence fantôme figée » est **préexistant** et
indépendant de ce chantier. Il mérite un point de contrôle en essai (TC7 : couper le bus M3 en
mouvement et observer `PowerCutOff`), mais ce n'est pas une régression.

**Verdict : ✅ PRÉSERVÉ.**

---

### 5.8 `EmergencyChain` / `EmergencyStopOk` sans `FB_Sim_Safety` — le réarmement fonctionne-t-il ?

Voir la chaîne détaillée en §3.5. Synthèse :

| Élément de la séquence | Source | Dépend-il de `FB_Sim_Safety` ? |
|---|---|---|
| Déclenchement (`ArmRequest`) | `GVL_IHM.Modes.Cmd.BtnEmergencyArming` (`PRG_10:147`) | ❌ non |
| Condition d'entrée : `EmergencyChain AND NOT EmergencyStopOk` | `PRG_00:182,177` | ❌ non (en réel, `OR FALSE`) |
| Auto-test canal A : `ForceTestA` → `PowerCutOff_A_RQ := FALSE` → la boucle **doit** retomber | `…Logic.st:88-102`, sortie `PRG_10:155` | ❌ non |
| Vérification retombée : `IF EmergencyChain THEN RedundancyTestFailed := TRUE` | `…Logic.st:93` | ❌ non — lit `EmergencyChainOK_DI` |
| Auto-test canal B | `…Logic.st:115-129` | ❌ non |
| Impulsion 1 s (`EmergencyArming_RQ`) | `…Logic.st:142-146`, `PRG_10:157` | ❌ non |
| Confirmation 2 s (`EmergencyStopOk`) | `…Logic.st:149-159` | ❌ non — lit `EmergencyStopOk_DI` |
| Verrouillage 5 s | `…Logic.st:162-165` | ❌ non |

**Réponse** : la séquence est **entièrement bouclée par le matériel** (sorties `PowerCutOff_A/B_RQ` →
contacteurs → entrées `EmergencyChainOK_DI` / `EmergencyStopOk_DI`). `FB_Sim_Safety` **fabriquait cette
boucle en logiciel** pour le banc (`FB_Sim_Safety.st:44-56`) ; en mode réel, son `Enable` est `FALSE` et
ses sorties sont forcées à `FALSE` (`:37-42`), donc les deux `OR` de `PRG_00:176,181` sont déjà neutres.

**Verdict : ✅ PRÉSERVÉ.** ⚠️ Conséquence P1↔P2 : **entre L4d et L6, aucun essai de réarmement AU n'est
possible hors machine réelle** — cohérent avec l'avertissement `SEQUENCE §2` (« aucun banc entre L4d
et L6 »).

---

### 5.9 Ordre d'exécution — la suppression change-t-elle un décalage d'un cycle ?

Inventaire des lectures « en avance » (un programme lit une valeur produite plus tard dans le scan) :

| Lecture | `fichier:ligne` | Décalage | Survit à P1 ? |
|---|---|---|---|
| `PRG_00` lit `PRG_10_Outputs.M1RelayFwd/Rev/SpeedContactor1..4` | `PRG_00:219` | N-1 | ❌ **supprimé** (n'existait que pour `M1_FwdRevSpeedFeedbackOff_Simulated`) |
| `PRG_00` lit `PRG_10_Outputs.M2…` | `PRG_00:235` | N-1 | ❌ supprimé |
| `PRG_00` lit `PRG_10_Outputs.M1BrakeCmd` / `M2BrakeCmd` | `PRG_00:229,244` | N-1 | ❌ supprimé |
| `PRG_00` lit `PRG_07_TranslationControl.instTranslationM3.BrakeCmd` | `PRG_00:290` | N-1 | ❌ supprimé |
| `PRG_00` lit `PRG_02_Encoders.instEncoderScaleM1/M2.CablePosM` et `PRG_04_Modes.instModes.InhibitM1/M2` | `PRG_00:205-206` | N-1 | ❌ supprimé |
| `PRG_00` lit `M3_CommandWord` (écrit par `PRG_10:127`) | `PRG_00:259-260` | N-1 | ❌ supprimé |
| `PRG_01` lit `PRG_06_WinchControl.instBucket.Busy` | `PRG_01:115` | N-1 | ✅ **conservé, inchangé** |
| `PRG_01` lit `PRG_09_Supervision.FaultMachineReset_IHM` | `PRG_01:63,73,109` | N-1 | ✅ conservé |
| `PRG_02` lit `PRG_06_WinchControl.instWinchM1/M2.SpeedRamp.Current` | `PRG_02:47-48` | N-1 | ❌ supprimé (n'alimentait que `FB_Sim_Encoder`) |
| `PRG_02` lit `PRG_06_WinchControl.instWinchM1/M2.RelayFwd/Rev` | `PRG_02:59-60, 73-74` | N-1 | ❌ supprimé |
| `PRG_03` lit `PRG_06_WinchControl.*` (Direction, Relay, instBucket) | `PRG_03:50-51, 62, 67-68` | N-1 | ✅ conservé |
| `PRG_06` lit `ForbidAscent/DescentMx_Active` calculés plus bas | `PRG_06:288-291` | N-1 intra-fichier | ✅ conservé |
| `PRG_04` lit `PRG_02_Encoders.EncoderFaultPresent` | `PRG_04:51` | N-1 | ✅ conservé |

**Réponse** : **aucun décalage conservé n'est modifié.** Toutes les suppressions concernent des lectures
qui n'existaient **que** pour alimenter la simulation. Bénéfice net : `PRG_00` et `PRG_02` perdent
**toutes** leurs références aval (`PRG_04`, `PRG_06`, `PRG_07`, `PRG_10`), ce qui rend `PRG_00` conforme
à la règle « toute lecture matériel en position 0 » **avant même** P2.

**Verdict : ✅ PRÉSERVÉ.**
⚠️ **Attention pour P2** : le plan prévoit de remonter les 5 `GetBusState()`/`GetDeviceState()` de
`PRG_01` vers `PRG_00` (`PLAN §4`). Ce déplacement **n'introduit pas** de décalage (les appels lisent le
pilote, pas un programme), **mais** `FB_DiagCanOpen`/`FB_DiagEthercat` restent appelés en `PRG_01` : il
faut vérifier que `HwIn` est bien rempli **avant** leur appel, sinon on introduit un retard d'un scan sur
`DeviceJoystick.Operational` → `FB_Joystick` GATE. **Point de contrôle explicite pour L5.**

---

### 5.10 `VAR_IN_OUT` `RawPos := _SimEncoderRawPosM1/M2` — variables figées après suppression ?

**Code** : `PRG_02_Encoders.st:68, 82` ; déclaration `CODE/GVL_PERSISTENT.st:104-105`
(`_SimEncoderRawPosM1/M2 : UDINT := 1000000`).

**Réponse** : recherche exhaustive de `_SimEncoderRawPos` dans `CODE/` → **4 occurrences seulement** :
- `GVL_PERSISTENT.st:104-105` (déclaration),
- `PRG_02_Encoders.st:51` (commentaire), `:68`, `:82` (les deux appels `FB_Sim_Encoder`),
- `FB_Sim_Encoder.st:49` (déclaration `VAR_IN_OUT`).

⇒ **Aucun autre consommateur.** Supprimer les instances laisse ces deux `PERSISTENT` figées à leur
dernière valeur, **sans effet sur aucune chaîne**. Elles restent nécessaires en P2 (`FB_SimBench`
recompose `FB_Sim_Encoder` ×2), donc **ne pas les supprimer** de `GVL_PERSISTENT`.

⚠️ Effets collatéraux de la suppression des deux instances :
- `M1_SimSpeedPct` / `M2_SimSpeedPct` (`PRG_02:33-34, 47-48`) deviennent orphelines → à supprimer ;
- `M1_RawPosToUse` / `M2_RawPosToUse` (`PRG_02:20-21`) disparaissent au profit de `COD1/COD2_PosValue` ;
- `GVL_Simulation.TstEncoderSpeedFactor` (`:71`) perd son lecteur. ⚠️ **Sa valeur par défaut est `3.0`,
  pas `1.0`** — à corriger en P2 comme prévu (`PLAN §3`), sinon un banc rebranché fera « courir » les
  codeurs 3× trop vite.

**Verdict : ✅ PRÉSERVÉ.**

---

## 6. 🔴 Blocages potentiels identifiés — liste priorisée

> ⚠️ Aucun de ces blocages n'est **causé** par la modification. Tous sont **préexistants** et
> **démasqués** par elle. Ils doivent être instruits **avant** l'essai machine L4d, pas pendant.

### 🥇 6.0 — PRIORITÉ ABSOLUE : état réel de `SimulationModeActive` sur l'automate

| | |
|---|---|
| **Condition exacte** | `GVL_Simulation.SimulationModeActive = TRUE` sur l'automate en service au moment du download P1 |
| **Effet** | Les **10 forçages « capteur sain »** disparaissent d'un coup. Tout capteur non câblé bascule sur sa valeur réelle → cumul possible de `SafeStop` + `PowerCutOff` sur les 3 axes |
| **Pourquoi c'est plausible** | Les 18 flags `*IsReal` sont **tous à `FALSE` par défaut** (`GVL_Simulation.st:37-61`) = « rien n'est câblé ». `SimulationModeActive` est **non RETAIN** : `FALSE` à chaque download, mais un forçage en ligne survit jusqu'au redémarrage |
| **Parade** | **L0 : relever `SimulationModeActive` + les 18 `*IsReal` sur l'automate en service, avant tout.** Si `TRUE`, dérouler d'abord le capteur-par-capteur (`*IsReal := TRUE` un par un) et vérifier qu'aucun défaut n'apparaît — **puis seulement** appliquer L4a→L4d |

### 🥈 6.1 — 🐛 **Le capteur PV est câblé sous le nom `PosPV_DI_`, mais le programme lit `PosPV_DI`**

> 🎯 **Bug de mapping confirmé, indépendant du chantier simulation.** C'est le seul défaut *prouvé*
> (et non simplement *déduit*) de cette analyse.

| | |
|---|---|
| **Constat** | La voie physique existe et est mappée : `Device.export:40710-40712`, `CreateVariable = True`, `Variable = "PosPV_DI_"` — **avec un underscore final** — description « Capteur d'info position chariot », `Bit1` |
| **Ce que le programme lit** | `PRG_00_Inputs.st:267` → `GVL_Translation_M3_Stub.PosPV_DI` — **sans** underscore final. C'est un `VAR_GLOBAL` de stub (`GVL_Translation_M3_Stub.st:12`, commentaire : « Nouvelle entrée physique PV à mapper dans CODESYS ») que **rien n'écrit jamais** |
| **Preuve du non-raccordement** | Recherche de `PosPV_DI_` (underscore final) dans tout `CODE/` : **0 occurrence**. La voie physique alimente une variable que personne ne consomme ; le programme consomme une variable que personne n'alimente |
| **Origine probable** | Renommage automatique CODESYS lors du mapping : le nom `PosPV_DI` était déjà pris par la déclaration du stub, CODESYS a créé `PosPV_DI_` pour éviter la collision. Le mapping « semble » fait dans l'éditeur, mais ne relie rien |
| **Condition de blocage** | `TranslationPosPV = FALSE` en permanence **et** au moins un autre capteur M3 actif ⇒ `SensorsWord ∉ {11111, 01111, 00111, 00011, 00001, 00000}` ⇒ `Incoherent := TRUE` (`FB_Translation_PositionDecoder.st:40-45`) |
| **Effet** | `FB_Safety_Translation` bit7 (`:201-203`) → `SafeStop` **+ `PowerCutOff`** (masque `16#00F8`, `:221`). Et `LimitSwitchFwd/Rev := FALSE` (`Decoder:48-49`) ⇒ **les butées extrêmes M3 ne fonctionnent plus**. Le ralentissement PV avant Trémie (`FB_Translation.st:140-142`) ne se déclenche jamais non plus |
| **Aggravation par la modif** | En simulation, `instSimTranslation.PosPV` fournissait un PV cohérent (`FB_Sim_Translation`, `PVLeadTimeS`) et **masquait entièrement ce bug**. Après P1, cette source disparaît définitivement |
| **Parade #1 (correcte)** | Dans CODESYS : **supprimer la déclaration `PosPV_DI` de `GVL_Translation_M3_Stub`**, puis remapper la voie sur le nom `PosPV_DI` (sans underscore), et corriger `PRG_00:267` pour lire la variable globale d'E/S au lieu du stub |
| **Parade #2 (contournement)** | Conserver le stub et ajouter `GVL_Translation_M3_Stub.PosPV_DI := PosPV_DI_;` en tête de `PRG_00` (à supprimer dès la parade #1 appliquée) |
| **Parade dégradée** | Activer et **tracer** `GVL_IHM.TranslationM3.Bypass.SensorIncoherent` (RETAIN) le temps de la correction |

### 🥉 6.2 — Capteur haut non câblé → montée M1 **et** M2 impossibles

| | |
|---|---|
| **Condition exacte** | `M1_M2_TopPositionSensor_DI = FALSE` ⇒ `TopPositionSensor = FALSE` ⇒ `FB_Safety_Winch.st:539-541` : `ForbidAscent := … OR (NOT TopPositionSensor AND NOT InReferencingMode)` |
| **Particularité** | Ce terme est **hors du bloc `IF NOT BypassGlobal`** — aucun bypass interne au FB ne le neutralise |
| **Effet** | `ForbidAscent` permanent sur les **deux** instances (capteur commun) ⇒ `FB_Winch.st:275-277` `RelayFwd := FALSE`, plus décélération rapide via `EffectiveSafeStop` (`:190`). Méca D (`:450-456`) armée dès `Direction >= 0` ⇒ `SafeStop` + `PowerCutOff` après 3 s si contacteurs/frein ne confirment pas |
| **Effet secondaire** | Homing nominal **accepté à tort** en toute position (`FB_Encoder_Homing.st:168` : le rejet n'a lieu que si `TopPositionSensor = TRUE`) |
| **Parade** | `GVL_IHM.M1TreuilRetenue.Bypass.Global` **et** `M2TreuilBenne.Bypass.Global` (`PRG_06:417,436`) — **seul recours**. Vérifier le câblage avant l'essai ; sinon prévoir ce bypass et le tracer |

### 4️⃣ 6.3 — Heartbeat IHM absent → `SafeStop` 3 axes + cycle en `ERROR_HOLD` non bypassable

| | |
|---|---|
| **Condition exacte** | `GVL_IHM.Commun.TglHeartbeatIhm` ne bascule pas pendant `T#2s` (`PRG_01:96`) ⇒ `HeartbeatIhmOk = FALSE` (`FB_IhmHeartbeat.st:56-59`) |
| **Effet** | `FB_Safety_Winch` bit0 M1+M2 et `FB_Safety_Translation` bit0 → `SafeStop` sur les 3 axes ; **`FB_Cycle.st:175-179` → `ERROR_HOLD`, sans aucun bypass prévu** |
| **Aggravation par la modif** | Le secours `GVL_Global.BlinkClock` (`PRG_01:94`) est supprimé. Il n'était actif qu'en simulation, mais c'était **le seul moyen documenté** de faire tourner l'automate sans visu |
| **Parade #1** | **Vérifier avant le download L4c que la visu écrit bien `GVL_IHM.Commun.TglHeartbeatIhm`** (test : observer `GVL_IHM.Commun.HeartbeatIhmElapsed` — il doit rester < 500 ms) |
| **Parade #2 (dégradé)** | Bypasser côté safety : `Bypass.OperatorComm` ou `Bypass.Global` sur M1/M2/M3. ⚠️ **Ne couvre PAS `FB_Cycle`** : le cycle semi-auto restera bloqué |
| **Recommandation** | Si la visu n'est pas prête à L4c : **conserver provisoirement le `SEL` heartbeat** (le figer en L6 avec `SimOperatorActive`), ou ajouter un `BypassHeartbeat` à `FB_Cycle` — décision à prendre **avant** L4c, pas après |

### 5️⃣ 6.4 — `KoboldContactFond_DI` non câblé → cycle semi-auto bloqué silencieusement

| | |
|---|---|
| **Condition exacte** | `FB_Cycle.st:272` : `IF CycleMotionPermit AND KoboldContactFond THEN` — transition `BOTTOM_TOUCH_WAIT` → étape suivante |
| **Effet** | Le cycle reste indéfiniment en attente de fond. **Aucun défaut, aucun `ErrorId`, aucun message** — l'opérateur ne voit qu'un cycle qui ne progresse pas |
| **Aggravation par la modif** | Suppression de `PRG_05:39` + du champ `GVL_IHM.Cycle.Test.KoboldContactFond` (lot L3) : le **seul chemin d'injection opérateur disparaît** |
| **Parade** | Vérifier le câblage `%IX0.5` avant TC9. À défaut, forcer `KoboldContactFond_DI` en vue instance CODESYS (forçage natif, doctrine `PLAN §1`) — et **le tracer** |

### 6️⃣ 6.5 — `PRG_09` §4 supprimé au lieu de forcé à `FALSE` → M3 impilotable

Voir la démonstration complète en §5.4bis.

| | |
|---|---|
| **Condition exacte** | `GVL_IHM.TranslationM3.Bypass.ContactorFeedback = TRUE` (valeur RETAIN résiduelle) **sans** `Bypass.Global` ⇒ `PRG_07:160` injecte `instTranslationM3.BrakeCmd` dans `BrakeFeedback` ⇒ égalité permanente ⇒ `FB_Brake.st:112-117` `StuckClosed` après 1 s ⇒ `FB_Translation` bit0 ⇒ `DriveControlWord := 0` |
| **Parade** | **Écrire explicitement `:= FALSE`, ne jamais supprimer la ligne `PRG_09:293`.** Les 4 autres miroirs (`:291, :292, :294, :295`) n'ont aucun lecteur et peuvent être supprimés sans risque |
| **Suite à instruire (hors chantier)** | La polarité de la branche bypass de `PRG_07:160` est incohérente (`BrakeCmd` = « desserré » injecté dans un signal normalisé « serré »). À corriger séparément |

### 7️⃣ 6.6 — Risques P2 (frontière `ST_HardwareImage`)

| Risque | Condition | Parade |
|---|---|---|
| Faute de redirection sur un des ~40 signaux | Un consommateur oublié lit encore la variable physique, ou lit `HwIn` avant remplissage | **TC3 signal à signal** (le seul test qui le prouve) + relecture croisée du diff |
| `GetDeviceState()` remonté en `PRG_00` | `FB_DiagCanOpen`/`FB_DiagEthercat` restent en `PRG_01` : si `HwIn` est rempli après leur appel, retard d'un scan sur `DeviceJoystick.Operational` → GATE `FB_Joystick.st:100` | Vérifier explicitement l'ordre §0 `PRG_00` → §1 `PRG_00` → `PRG_01` |
| Perte du RETAIN au lot L3 | Suppression des `.Test` d'une struct `VAR_GLOBAL RETAIN` ⇒ **tous** les bypass RETAIN et la config `PERSISTENT` repartent au défaut struct | Accepté (D10). ⚠️ **Conséquence non explicitée par le plan** : les bypass `Global` reviennent à `FALSE` — si un bypass masquait un des blocages 6.1→6.4, **le blocage réapparaît au premier boot après L3** |
| `TstEncoderSpeedFactor := 3.0` | Rebranchement du banc en L6 avec la valeur actuelle | Remise à `1.0` (déjà prévue `PLAN §3`) |
| `Bypass.ContactorFeedback` polarité | Voir 6.5 | Corriger `PRG_07:160` avant L6, sinon le banc M3 déclenchera systématiquement |

---

## 7. 🧷 Ce que je n'ai pas pu vérifier

Liste honnête des limites de cette analyse. **Aucune de ces zones n'a été comblée par supposition.**

1. **État réel de l'automate en service.** Je n'ai analysé que le code source. La valeur courante de
   `SimulationModeActive`, des 18 `*IsReal`, des bypass `RETAIN` (`GVL_BypassRetain`) et des `PERSISTENT`
   **n'est pas observable depuis les fichiers**. C'est précisément l'objet du lot L0 — et c'est le
   GO/NO-GO de tout le chantier (§6.0).

2. **Câblage physique effectif.** `Device.export` prouve que les canaux sont **mappés** (`CreateVariable =
   True` sur chaque `%IX`), pas que le **fil est présent au bornier**. Les scénarios « fil absent » du
   §5.5 et du §6 sont des **analyses de conséquence**, pas des constats. Seul un relevé terrain
   (entrée par entrée, machine à l'arrêt) peut trancher.
   ⚠️ **Exception — §6.1 est un constat, pas une déduction** : la voie PV est mappée sous le nom
   `PosPV_DI_` (`Device.export:40712`) et ce nom **n'apparaît nulle part dans `CODE/`** (0 occurrence),
   tandis que `PRG_00:267` lit `GVL_Translation_M3_Stub.PosPV_DI` que **rien n'écrit**. Les deux faits
   sont vérifiables sans accès à la machine.

2bis. **Méthode d'exploitation de `Device.export`** (11 Mo) : fichier **jamais lu intégralement** —
   uniquement des recherches ciblées par nom de variable, avec des fenêtres de contexte de 3 à 25 lignes
   pour lire la description de voie associée. Je n'ai donc **pas** d'inventaire exhaustif des voies
   d'E/S déclarées : il est possible que d'autres voies mappées ne soient consommées par aucun code
   (comme `PosPV_DI_`), ou inversement. `M3_ThermalFeedback_DI` et `ConveyorInfeedReady_DI` ont été vus
   dans l'export **sans consommateur dans `CODE/`** — non instruits, hors périmètre.

3. **Polarité réelle des capteurs.** Les descriptions `Device.export` sont laconiques
   (ex. `KoboldContactFond_DI :: "Bit5"`). Je me suis appuyé sur les conventions déclarées dans les
   commentaires de `PRG_00_Inputs.st:11-57` (NC = repos `TRUE` sain). Si une polarité terrain diffère,
   les conséquences du §5.5 s'inversent. **Le point de bascule `BrakeFeedbackInvertLogic`
   (`PRG_00:118`) reste explicitement marqué « à confirmer sur site » dans le code lui-même.**

4. **Comportement du PDO EtherCAT hors ligne.** Je n'ai pas pu déterminer si CODESYS remet
   `M3_ActualFrequencyHz` / `M3_StatusWord` à 0 ou conserve la dernière valeur quand l'esclave quitte
   `RUNNING`. Le §5.7 traite les deux cas. Le comportement réel dépend de la configuration
   `EtherCAT Master` (option « Reset outputs on error »), non lue.

5. **Contenu de la visu.** L'affirmation « aucune variable `Test` mappée dans la visu » (D6) vient du
   plan, pas d'une vérification de ma part — le projet de supervision n'est pas dans ce dépôt. Idem pour
   la question critique du §6.3 : **je ne peux pas vérifier que la visu écrit réellement
   `GVL_IHM.Commun.TglHeartbeatIhm`.**

6. **`FB_Cycle` non lu intégralement.** J'ai tracé `KoboldContactFond`, `HeartbeatIhmOk`,
   `WinchSyncError`, `CmdWinchM1/M2_*`, `CmdTranslationM3_*` et `KoboldContactorCmd`. Les 469 lignes
   complètes du séquenceur (transitions entre les 12 étapes `E_CycleStep`) n'ont pas été auditées ligne
   à ligne — hors périmètre « chaîne actionneur », mais un blocage de cycle purement séquentiel pourrait
   m'avoir échappé.

7. **`FB_SpeedStep`, `FB_WinchSync`, `FB_Ramp`, `FB_AxisScale`, `FB_DiagCanOpen`** : lus par leurs
   interfaces et leurs points d'appel, **pas ligne à ligne**. Aucun d'eux ne référence `GVL_Simulation`
   ni `GVL_PLC_Tests` (recherche exhaustive confirmée), donc aucun n'est touché par la modification —
   mais un blocage interne préexistant n'aurait pas été détecté.

8. **Le décompte « 46 points »** du plan n'a pas pu être reproduit à l'unité près. Mon relevé donne
   **10** forçages `OR` capteur (dont 2 via `FB_Sim_Safety`, là où le plan en compte 8),
   **10** `SEL` en `PRG_00`, **3** `SEL` joystick + **2** `SEL` temporisations + **1** `SEL` heartbeat en
   `PRG_01`, **2** `IF` + **4** `SEL` en `PRG_02`, **1** `IF` variateur en `PRG_00`, **4** points
   `PRG_05/06/07/08`, **9** points `PRG_09`. L'écart porte sur la convention de comptage, pas sur le
   fond : **chaque forme rencontrée a été instruite individuellement en §3/§4.**

9. **Compilation.** Aucune vérification de compilation n'a été faite (analyse statique par lecture
   seule). Les orphelins que je signale (`M1/M2_SimSpeedPct`, `M1/M2_RawPosToUse`,
   `*_Simulated`, `SimTopSensorTriggered`, `TstEncoderSpeedFactor`) devront être traités par le
   typage strict CODESYS lors de l'application manuelle.

---

## 8. ✅ Recommandations de séquencement (complément à `SEQUENCE_Execution_Simulation_v1.0`)

| # | Action | Lot concerné | Pourquoi |
|---|---|---|---|
| R1 | **Relever `SimulationModeActive` + 18 `*IsReal` sur l'automate en service** — GO/NO-GO | **L0**, bloquant | §6.0 : c'est la seule hypothèse sur laquelle repose toute la démonstration de neutralité |
| R2 | Vérifier que la visu toggle `GVL_IHM.Commun.TglHeartbeatIhm` (`HeartbeatIhmElapsed < 500 ms`) | **avant L4c** | §6.3 : `FB_Cycle` n'a aucun bypass heartbeat |
| R3 | 🐛 **Corriger le mapping PV** : la voie est câblée sous `PosPV_DI_`, le code lit le stub `GVL_Translation_M3_Stub.PosPV_DI`. À défaut, activer/tracer `Bypass.SensorIncoherent` | **avant L4a** | §6.1 : `PowerCutOff` M3 permanent + butées extrêmes M3 inopérantes |
| R4 | Contrôler la continuité des 8 DI de sécurité au bornier, machine consignée | **avant L4d** | §5.5 : 5 d'entre eux mènent à `SafeStop` + `PowerCutOff` |
| R5 | `PRG_09:293` → **`:= FALSE` explicite** (les 4 autres miroirs peuvent être supprimés) | **L4a** | §6.5 : sinon M3 impilotable via une valeur RETAIN résiduelle |
| R6 | Après L3, **rejouer les bypass** avant tout mouvement (le RETAIN est invalidé) | **L3** | §6.6 : un bypass qui masquait 6.1–6.4 disparaît au premier boot |
| R7 | Ne pas supprimer `_SimEncoderRawPosM1/M2` de `GVL_PERSISTENT` | **L4b** | §5.10 : nécessaires au `FB_SimBench` de P2 |
| R8 | En L5, vérifier explicitement que `HwIn` est rempli **avant** l'appel des FB de diagnostic | **L5** | §5.9 : retard d'un scan possible sur le GATE `FB_Joystick` |
| R9 | Ajouter à TC7 : couper le bus M3 **en mouvement** et observer `PowerCutOff` | **L4d / L5** | §5.7 : comportement du PDO figé non déterminable par lecture de code |

---

📌 **Conclusion** : la modification est **techniquement neutre** pour la machine réelle — 36 chaînes sur 40
sont préservées à l'identique, et les 4 ⚠️ portent sur la **manière d'écrire** le changement ou sur la
**perte d'un filet de mise en service**, jamais sur la logique métier. Le risque du chantier n'est pas
dans le code retiré : il est dans **l'état de câblage que ce code masquait**. Les recommandations R1 à R4
transforment ce risque en vérification planifiée.
