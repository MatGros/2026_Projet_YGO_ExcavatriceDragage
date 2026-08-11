# AUDIT M0 — Gel de l'état initial (photo avant migration 7 POU)

> 🧊 **Nature : inventaire factuel, lecture seule.** Aucune proposition, aucun correctif, aucun jugement.
> 🎯 **But :** permettre aux lots M1→M8 de **prouver** qu'aucune donnée, instance ou liaison n'a disparu.
> 📄 **Décision source :** [`RU_C4_ARCHITECTURE_PROCEDES.md`](RU_C4_ARCHITECTURE_PROCEDES.md) ·
> **Plan :** [`PLAN_EXECUTION_MIGRATION_7POU.md`](PLAN_EXECUTION_MIGRATION_7POU.md) §4 lot M0.

---

## 0. Périmètre et méthode

| Élément | Valeur |
|---|---|
| Commit de référence | `f32dcd612ed32e0debd0b6614848c85f7804df22` (2026-08-02) |
| Fichiers audités | 13 `PRG_*.st` de `CODE/MAIN/` + 3 GVL locales |
| Volume | 3215 lignes au total (`wc -l CODE/MAIN/*.st`) |
| Écriture dans `CODE/` | **aucune** |

**Convention de citation** : `Fichier.st:Ligne`. Les numéros de ligne sont ceux des fichiers
`.st` sources, pas ceux du bundle PLCopenXML.

**Méthode d'extraction** : parcours ligne à ligne des 13 fichiers, hors commentaires de fin de
ligne (`//`). Les commentaires de bloc `(* … *)` ne sont pas exclus : les 3 occurrences concernées
sont signalées explicitement (`PRG_AUXILIARY_CFC.st:9`, `PRG_ACQUISITION_CFC.st:9`,
`PRG_TREUILS_CFC.st` bandeau).

### 0.1 — Table des POU et écart nom fichier / nom POU

| # ordre déclaré | Fichier | Nom `PROGRAM` | Ligne `PROGRAM` | Lignes | Position tâche déclarée en bandeau |
|---|---|---|---|---|---|
| — | `PRG_ACQUISITION_CFC.st` | `PRG_ACQUISITION_CFC` | :12 | 336 | non prouvé (aucune position en bandeau) |
| — | `PRG_01_Inputs_LD.st` | `PRG_01_Inputs_LD` | :10 | 236 | non prouvé (aucune position en bandeau) |
| 1 | `PRG_01_Diagnostics.st` | `PRG_01_Diagnostics` | :9 | 97 | `PRG_01_Diagnostics.st:4` — position 1 |
| 2 | `PRG_02_Encoders.st` | `PRG_02_Encoders` | :10 | 212 | `PRG_02_Encoders.st:4` — position 2 |
| 8 | `PRG_AUXILIARY_CFC.st` | `PRG_AUXILIARY_CFC` | :14 | 21 | `PRG_AUXILIARY_CFC.st:4` — position 8 |
| 3 | `PRG_MODES_CFC.st` | `PRG_MODES_CFC` | :9 | 36 | `PRG_MODES_CFC.st:4` — position 3 |
| 3 | `PRG_SAFETY_CFC.st` | `PRG_SAFETY_CFC` | :9 | 235 | `PRG_SAFETY_CFC.st:4` — position 3 |
| 5 | `PRG_05_Cycle.st` | `PRG_05_Cycle` | :10 | 98 | `PRG_05_Cycle.st:4` — position 5 |
| 6 | `PRG_TREUILS_CFC.st` | `PRG_TREUILS_CFC` | :9 | 708 | `PRG_TREUILS_CFC.st:4` — position 6 |
| 7 | `PRG_TRANSLATION_CFC.st` | `PRG_TRANSLATION_CFC` | :10 | 180 | `PRG_TRANSLATION_CFC.st:4` — position 7 |
| 10 | `PRG_OUTPUTS_LD.st` | **`PRG_10_Outputs_LD`** | :10 | 187 | `PRG_OUTPUTS_LD.st:5` — position 10 |
| 9 | `PRG_SUPERVISION_CFC.st` | `PRG_SUPERVISION_CFC` | :16 | 524 | `PRG_SUPERVISION_CFC.st:4` — position 9 |
| 11 | `PRG_TROUBLESHOOTING_CFC.st` | `PRG_TROUBLESHOOTING_CFC` | :8 | 262 | `PRG_TROUBLESHOOTING_CFC.st:4` — position 11 |

📌 **Fait #1 — un seul écart nom fichier / nom POU** : `PRG_OUTPUTS_LD.st:10` déclare
`PROGRAM PRG_10_Outputs_LD`. Les 12 autres fichiers ont `nom_fichier = nom_POU`.
Tous les consommateurs référencent le **nom POU** `PRG_10_Outputs_LD`
(ex. `PRG_ACQUISITION_CFC.st:137`, `PRG_SUPERVISION_CFC.st:502`).

📌 **Fait #2 — deux POU déclarent la même position 3** : `PRG_MODES_CFC.st:4` et
`PRG_SAFETY_CFC.st:4`. L'ordre réel d'exécution MainTask n'est **pas prouvable depuis `CODE/`** ;
aucun gate ne lit `Device.export` (AGENTS.md). Statut : **non prouvé**.

📌 **Fait #3 — `END_PROGRAM` incohérents** : `PRG_MODES_CFC.st` contient **deux** `END_PROGRAM`
(`:35` et `:37`), `PRG_05_Cycle.st` en contient **un** (`:99`), les 11 autres **zéro**.

---

# PARTIE A — Inventaire POU par POU

Pour chaque POU : ① instances FB déclarées · ② variables publiques produites · ③ variables lues
chez d'autres POU · ④ consommateurs de ses sorties.

---

## A1. `PRG_ACQUISITION_CFC` — source historique archivée `ARCHIVES/Code/MAIN/PRG_ACQUISITION_CFC.st` (336 lignes)

### ① Instances FB déclarées — 12

| Instance | Type | Déclaration |
|---|---|---|
| `instSimBench` | `FB_SimBench` | `PRG_ACQUISITION_CFC.st:34` |
| `instJoystick` | `FB_Joystick` | `PRG_ACQUISITION_CFC.st:35` ⚠️ **dupliquée** (T1) |
| `instEncoderAbsM1` | `FB_Encoder_Abs` | `PRG_ACQUISITION_CFC.st:36` ⚠️ **dupliquée** (T1) |
| `instEncoderScaleM1` | `FB_Encoder_Scale` | `PRG_ACQUISITION_CFC.st:37` ⚠️ **dupliquée** (T1) |
| `instHomingM1` | `FB_Encoder_Homing` | `PRG_ACQUISITION_CFC.st:38` ⚠️ **dupliquée** (T1) |
| `instEncoderAbsM2` | `FB_Encoder_Abs` | `PRG_ACQUISITION_CFC.st:39` ⚠️ **dupliquée** (T1) |
| `instEncoderScaleM2` | `FB_Encoder_Scale` | `PRG_ACQUISITION_CFC.st:40` ⚠️ **dupliquée** (T1) |
| `instHomingM2` | `FB_Encoder_Homing` | `PRG_ACQUISITION_CFC.st:41` ⚠️ **dupliquée** (T1) |
| `instPosDecoderM3` | `FB_Translation_PositionDecoder` | `PRG_ACQUISITION_CFC.st:42` |
| `instCycleTimeAcq` | `FB_CycleTime` | `PRG_ACQUISITION_CFC.st:45` |
| `instFilterM3StatusWord` | `FB_Filter_PT1` | `PRG_ACQUISITION_CFC.st:46` |
| `instFilterM3ActualFreqHz` | `FB_Filter_PT1` | `PRG_ACQUISITION_CFC.st:47` |

### ② Variables publiques produites (`VAR_OUTPUT`) — 11

| Variable | Type | Déclaration | Écriture(s) |
|---|---|---|---|
| `HwReal` | `ST_HardwareImage` | `:15` | `:60`–`:106` (47 champs) |
| `HwSim` | `ST_HardwareImage` | `:16` | `:157`, `:158`, `:159`, `:160` |
| `HwIn` | `ST_HardwareImage` | `:17` | `:175`, `:177`, `:179`, `:181` |
| `WinchInputSourceChanged` | `BOOL` | `:18` | `:167`, `:169` |
| `TranslationPosTremie` | `BOOL` | `:21` | `:315` |
| `TranslationPosPV` | `BOOL` | `:22` | `:316` |
| `TranslationPosP2` | `BOOL` | `:23` | `:317` |
| `TranslationPosP1` | `BOOL` | `:24` | `:318` |
| `TranslationPosMaintenance` | `BOOL` | `:25` | `:319` |
| `M3_StatusWord_Filtered` | `UINT` | `:28` | `:329` |
| `M3_ActualFrequencyHz_Filtered` | `UINT` | `:29` | `:336` |

Variables internes hors instances : `WinchInputSourceSimulated` (`:50`),
`PreviousWinchInputSourceSimulated` (`:51`), `WinchInputSourceInitialized` (`:52`).

### ③ Variables lues chez d'autres POU — 21 symboles / 34 lignes-occurrences

| Symbole lu | POU producteur | Lignes dans `PRG_ACQUISITION_CFC.st` |
|---|---|---|
| `PRG_01_Diagnostics.instDiagCanOpen.DeviceCanOpenMaster` | `PRG_01_Diagnostics` | 195 |
| `PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick` | `PRG_01_Diagnostics` | 196 |
| `PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1.Operational` | `PRG_01_Diagnostics` | 220 |
| `PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2.Operational` | `PRG_01_Diagnostics` | 267 |
| `PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd` | `PRG_02_Encoders` | 120 |
| `PRG_02_Encoders.instEncoderAbsM1.PresetValueOut` | `PRG_02_Encoders` | 121 |
| `PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd` | `PRG_02_Encoders` | 130 |
| `PRG_02_Encoders.instEncoderAbsM2.PresetValueOut` | `PRG_02_Encoders` | 131 |
| `PRG_10_Outputs_LD.PowerKeepAlive_A_RQ` | `PRG_10_Outputs_LD` | 137 |
| `PRG_10_Outputs_LD.PowerKeepAlive_B_RQ` | `PRG_10_Outputs_LD` | 138 |
| `PRG_10_Outputs_LD.EmergencyArming_RQ` | `PRG_10_Outputs_LD` | 139 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 191, 216, 229, 231, 263, 276, 278 |
| `PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated` | `PRG_MODES_CFC` | 232, 233, 279, 280 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 189, 214, 227, 261, 274 |
| `PRG_TRANSLATION_CFC.M3_Direction_Active` | `PRG_TRANSLATION_CFC` | 133 |
| `PRG_TRANSLATION_CFC.M3_SpeedRef_Active` | `PRG_TRANSLATION_CFC` | 134 |
| `PRG_TREUILS_CFC.M1_SpeedRef_Active` | `PRG_TREUILS_CFC` | 119 |
| `PRG_TREUILS_CFC.M2_SpeedRef_Active` | `PRG_TREUILS_CFC` | 129 |
| `PRG_TREUILS_CFC.instBucket.Busy` | `PRG_TREUILS_CFC` | 192 |
| `PRG_TREUILS_CFC.instExtractionSequence.Busy` | `PRG_TREUILS_CFC` | 193 |
| `PRG_TREUILS_CFC.instExtractionSequence.ExtractionState` | `PRG_TREUILS_CFC` | 194 |

Lectures GVL (hors POU) : `GVL_Global.M1RelayFwd` … `GVL_Global.TranslationBrakeCmd`
(`:113`–`:135`, 15 champs), `GVL_Simulation.*` (`:112`, `:140`–`:149`, `:163`, `:176`, `:178`, `:180`),
`GVL_IHM.*` (`:136`, `:150`, `:200`, `:230`, `:235`, `:237`, `:247`, `:277`, `:282`, `:284`, `:294`),
`GVL_PERSISTENT` via `_JoystickInvertX` etc. (`:152`, `:153`, `:201`–`:204`, `:207`, `:208`, `:234`, `:237`, `:248`, `:281`, `:284`, `:295`).

### ④ Consommateurs de ses sorties

| Sortie | Consommateurs (POU : lignes) |
|---|---|
| `HwReal` | **AUCUN consommateur inter-POU** |
| `HwSim` | **AUCUN consommateur inter-POU** |
| `HwIn` | `PRG_01_Diagnostics`(33,34,35,36,37,86,87,88) · `PRG_02_Encoders`(47,48,57,58,107,108) · `PRG_AUXILIARY_CFC`(9 *(commentaire)*, 21) · `PRG_SUPERVISION_CFC`(377) · `PRG_TROUBLESHOOTING_CFC`(233) |
| `WinchInputSourceChanged` | `PRG_02_Encoders`(188,190) |
| `TranslationPosTremie` | `PRG_05_Cycle`(78) · `PRG_SUPERVISION_CFC`(390) · `PRG_TRANSLATION_CFC`(136) · `PRG_TROUBLESHOOTING_CFC`(225) |
| `TranslationPosPV` | `PRG_SUPERVISION_CFC`(391) · `PRG_TRANSLATION_CFC`(156) · `PRG_TROUBLESHOOTING_CFC`(226) |
| `TranslationPosP2` | `PRG_05_Cycle`(76) · `PRG_SUPERVISION_CFC`(392) · `PRG_TRANSLATION_CFC`(137) · `PRG_TROUBLESHOOTING_CFC`(227) |
| `TranslationPosP1` | `PRG_05_Cycle`(75) · `PRG_SUPERVISION_CFC`(393) · `PRG_TRANSLATION_CFC`(138) · `PRG_TROUBLESHOOTING_CFC`(228) |
| `TranslationPosMaintenance` | `PRG_05_Cycle`(77) · `PRG_SUPERVISION_CFC`(394) · `PRG_TRANSLATION_CFC`(139) · `PRG_TROUBLESHOOTING_CFC`(229) |
| `M3_StatusWord_Filtered` | `PRG_SAFETY_CFC`(213) · `PRG_SUPERVISION_CFC`(416,417) · `PRG_TRANSLATION_CFC`(159) · `PRG_TROUBLESHOOTING_CFC`(231) |
| `M3_ActualFrequencyHz_Filtered` | `PRG_SAFETY_CFC`(214) · `PRG_SUPERVISION_CFC`(419) · `PRG_TRANSLATION_CFC`(160) · `PRG_TROUBLESHOOTING_CFC`(230) |

Instance interne exposée en lecture croisée : `instPosDecoderM3` → voir T2 (T2-30, T2-48, T2-67, T2-93).
Les 11 autres instances (`instSimBench`, `instJoystick`, `instEncoderAbs/Scale/HomingM1/M2`,
`instCycleTimeAcq`, `instFilterM3*`) **ne sont lues par aucun autre POU** (0 occurrence
`PRG_ACQUISITION_CFC.inst<X>` hors ce fichier).

---

## A2. `PRG_01_Inputs_LD` — `CODE/MAIN/PRG_01_Inputs_LD.st` (236 lignes)

### ① Instances FB déclarées — 19 (toutes `FB_Input`)

| Instance | Type | Déclaration |
|---|---|---|
| `instPowerContactorEngaged` | `FB_Input` | `PRG_01_Inputs_LD.st:52` |
| `instEmergencyChainClosed` | `FB_Input` | `:53` |
| `instTopPositionSensor` | `FB_Input` | `:54` |
| `instSlackCableSwitch` | `FB_Input` | `:55` |
| `instKoboldContactFond` | `FB_Input` | `:56` |
| `instCtrlPhaseRotation` | `FB_Input` | `:57` |
| `instBrakeThermalFeedback` | `FB_Input` | `:58` |
| `instM1FwdRevSpeedFeedbackOff` | `FB_Input` | `:59` |
| `instM1Thermal` | `FB_Input` | `:60` |
| `instM1BrakeFeedback` | `FB_Input` | `:61` |
| `instM2FwdRevSpeedFeedbackOff` | `FB_Input` | `:62` |
| `instM2Thermal` | `FB_Input` | `:63` |
| `instM2BrakeFeedback` | `FB_Input` | `:64` |
| `instTranslationPosTremie` | `FB_Input` | `:65` |
| `instTranslationPosPV` | `FB_Input` | `:66` |
| `instTranslationPosP2` | `FB_Input` | `:67` |
| `instTranslationPosP1` | `FB_Input` | `:68` |
| `instTranslationPosMaintenance` | `FB_Input` | `:69` |
| `instM3BrakeFeedback` | `FB_Input` | `:70` |

`VAR CONSTANT` : `CST_InputFilterTime` (`:74`), `CST_BrakeFeedbackInvertLogic` (`:75`).

### ② Variables publiques produites — 22 `VAR_OUTPUT` + 1 `VAR_INPUT`

`VAR_INPUT` : `HwIn : ST_HardwareImage` (`:13`).

| Variable | Type | Décl. | Écriture | Consommateurs |
|---|---|---|---|---|
| `PowerContactorEngaged` | BOOL | `:18` | `:87` | 10 POU — voir ④ |
| `EmergencyChainClosed` | BOOL | `:19` | `:95` | `PRG_10_Outputs_LD`(135,148) · `PRG_TROUBLESHOOTING_CFC`(62,80,98,129,176,215,245) |
| `PhaseRotationOk` | BOOL | `:20` | `:103` | `PRG_SAFETY_CFC`(45,106,209) · `PRG_TROUBLESHOOTING_CFC`(61) |
| `BrakeThermalFeedback` | BOOL | `:21` | `:111` | `PRG_SAFETY_CFC`(43,104,210) · `PRG_TROUBLESHOOTING_CFC`(61) |
| `TopPositionSensor` | BOOL | `:24` | `:128` | `PRG_02_Encoders`(79,129) · `PRG_SAFETY_CFC`(46,107) · `PRG_SUPERVISION_CFC`(157) · `PRG_TROUBLESHOOTING_CFC`(132,179) |
| `SlackCableSwitch` | BOOL | `:25` | `:136` | `PRG_SAFETY_CFC`(44,105) · `PRG_SUPERVISION_CFC`(229,304) · `PRG_TROUBLESHOOTING_CFC`(61,135,182) |
| `M1FwdRevSpeedFeedbackOff` | BOOL | `:26` | `:144` | `PRG_02_Encoders`(81) · `PRG_SAFETY_CFC`(56) · `PRG_TREUILS_CFC`(614,686) · `PRG_TROUBLESHOOTING_CFC`(60,115) |
| `M1ThermalFeedback` | BOOL | `:27` | `:152` | `PRG_SAFETY_CFC`(42) · `PRG_SUPERVISION_CFC`(230) · `PRG_TROUBLESHOOTING_CFC`(60,117) |
| `M1BrakeFeedback` | BOOL | `:28` | `:160` | `PRG_02_Encoders`(82) · `PRG_SAFETY_CFC`(57) · `PRG_TREUILS_CFC`(615) · `PRG_TROUBLESHOOTING_CFC`(59,68,116) |
| `M2FwdRevSpeedFeedbackOff` | BOOL | `:29` | `:169` | `PRG_02_Encoders`(131) · `PRG_SAFETY_CFC`(118) · `PRG_TREUILS_CFC`(658,701) · `PRG_TROUBLESHOOTING_CFC`(60,162) |
| `M2ThermalFeedback` | BOOL | `:30` | `:177` | `PRG_SAFETY_CFC`(103) · `PRG_SUPERVISION_CFC`(305) · `PRG_TROUBLESHOOTING_CFC`(60,164) |
| `M2BrakeFeedback` | BOOL | `:31` | `:185` | `PRG_02_Encoders`(132) · `PRG_SAFETY_CFC`(119) · `PRG_TREUILS_CFC`(659) · `PRG_TROUBLESHOOTING_CFC`(59,68,163) |
| `KoboldContactFond` | BOOL | `:34` | `:119` | `PRG_05_Cycle`(61) · `PRG_SUPERVISION_CFC`(469) · `PRG_TREUILS_CFC`(142) |
| `TranslationPosTremie` | BOOL | `:37` | `:195` | **AUCUN** |
| `TranslationPosPV` | BOOL | `:38` | `:203` | **AUCUN** |
| `TranslationPosP2` | BOOL | `:39` | `:211` | **AUCUN** |
| `TranslationPosP1` | BOOL | `:40` | `:219` | **AUCUN** |
| `TranslationPosMaintenance` | BOOL | `:41` | `:227` | **AUCUN** |
| `M3BrakeFeedback` | BOOL | `:42` | `:235` | `PRG_SAFETY_CFC`(215) · `PRG_SUPERVISION_CFC`(376) · `PRG_TRANSLATION_CFC`(165) · `PRG_TROUBLESHOOTING_CFC`(59,232) |
| `M1BrakeCommandOpenConfirmed` | BOOL | `:45` | `:161` | `PRG_SUPERVISION_CFC`(214) · `PRG_TREUILS_CFC`(685) · `PRG_TROUBLESHOOTING_CFC`(36,147) |
| `M2BrakeCommandOpenConfirmed` | BOOL | `:46` | `:186` | `PRG_SUPERVISION_CFC`(287) · `PRG_TREUILS_CFC`(700) · `PRG_TROUBLESHOOTING_CFC`(37,194) |
| `M3BrakeCommandOpenConfirmed` | BOOL | `:47` | `:236` | `PRG_SUPERVISION_CFC`(374) · `PRG_TRANSLATION_CFC`(178) · `PRG_TROUBLESHOOTING_CFC`(38,257) |

Détail consommateurs `PowerContactorEngaged` : `PRG_01_Diagnostics`(76) ·
`PRG_02_Encoders`(54,71,104,121,154,167) · `PRG_05_Cycle`(50) · `PRG_10_Outputs_LD`(134,149) ·
`PRG_MODES_CFC`(22) · `PRG_SAFETY_CFC`(34,95,153,163,175,186,204) · `PRG_SUPERVISION_CFC`(499) ·
`PRG_TRANSLATION_CFC`(149,175) · `PRG_TREUILS_CFC`(125,137,158,208,431,595,640,682,697) ·
`PRG_TROUBLESHOOTING_CFC`(62,81).

📌 **Fait #4 — 5 sorties `PRG_01_Inputs_LD` sans aucun consommateur** :
`TranslationPosTremie/PV/P2/P1/Maintenance` (`PRG_01_Inputs_LD.st:37`–`:41`). Les consommateurs lisent
les homologues de `PRG_ACQUISITION_CFC` (`:21`–`:25`). Les deux chaînes coexistent :
`PRG_01_Inputs_LD` passe par `FB_Input` (filtre 20 ms, `:189`–`:227`), `PRG_ACQUISITION_CFC` par
`instPosDecoderM3` (`:306`–`:319`).

### ③ Variables lues chez d'autres POU — **0**

`PRG_01_Inputs_LD.st` ne contient **aucune** référence `PRG_<autre>.…`. Sa seule entrée externe est
`VAR_INPUT HwIn` (`:13`), lue en `:82, :90, :98, :106, :114, :123, :131, :139, :147, :155, :164, :172, :180, :190, :198, :206, :214, :222, :230`.

📌 **Fait #5 — `PRG_01_Inputs_LD.HwIn` n'a aucun site d'affectation dans `CODE/`.** Recherche
`PRG_01_Inputs_LD.HwIn` : 0 occurrence ; recherche d'un appel `PRG_01_Inputs_LD(...)` : 0 occurrence.
Le raccordement de ce `VAR_INPUT` est **non prouvé depuis `CODE/`** (mécanisme CFC de la page
CODESYS, non observable ici).

### ④ Consommateurs — 10 POU sur 12 (tous sauf `PRG_ACQUISITION_CFC` et lui-même)

---

## A3. `PRG_01_Diagnostics` — `CODE/MAIN/PRG_01_Diagnostics.st` (97 lignes)

### ① Instances FB déclarées — 4

| Instance | Type | Déclaration |
|---|---|---|
| `instDiagCanOpen` | `FB_Diag_CanOpen` | `PRG_01_Diagnostics.st:11` |
| `instDiagEthercat` | `FB_Diag_Ethercat` | `PRG_01_Diagnostics.st:12` |
| `instJoystick` | `FB_Joystick` | `PRG_01_Diagnostics.st:13` ⚠️ **dupliquée** (T1) |
| `instIhmHeartbeat` | `FB_Diag_IhmHeartbeat` | `PRG_01_Diagnostics.st:14` |

Variables internes : `RawCanBusState`(`:19`), `RawJoystickState`(`:20`), `RawVariateurState`(`:21`),
`RawEncoderM1State`(`:22`), `RawEncoderM2State`(`:23`).

### ② Variables publiques produites — **0 `VAR_OUTPUT`**

📌 **Fait #6 — `PRG_01_Diagnostics` n'a aucun `VAR_OUTPUT`.** Tout ce que ce POU publie transite
par des lectures directes de ses instances internes (`instDiagCanOpen`, `instDiagEthercat`,
`instJoystick`, `instIhmHeartbeat`) depuis 8 POU — voir T2.
Il n'écrit aucun champ `GVL_*` (0 affectation `GVL_…:=`).

### ③ Variables lues chez d'autres POU — 14 symboles / 16 lignes-occurrences

| Symbole lu | POU producteur | Lignes |
|---|---|---|
| `PRG_ACQUISITION_CFC.HwIn.Operator.CanBusState` | `PRG_ACQUISITION_CFC` | 33 |
| `PRG_ACQUISITION_CFC.HwIn.Operator.JOY1_DeviceState` | `PRG_ACQUISITION_CFC` | 34 |
| `PRG_ACQUISITION_CFC.HwIn.Translation.AC600_DeviceState` | `PRG_ACQUISITION_CFC` | 35 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD1_DeviceState` | `PRG_ACQUISITION_CFC` | 36 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD2_DeviceState` | `PRG_ACQUISITION_CFC` | 37 |
| `PRG_ACQUISITION_CFC.HwIn.Operator.JoyXRaw_ANA1` | `PRG_ACQUISITION_CFC` | 86 |
| `PRG_ACQUISITION_CFC.HwIn.Operator.JoyYRaw_ANA2` | `PRG_ACQUISITION_CFC` | 87 |
| `PRG_ACQUISITION_CFC.HwIn.Operator.JoyBtnRaw` | `PRG_ACQUISITION_CFC` | 88 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 76 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 78 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 43, 53, 77 |
| `PRG_TREUILS_CFC.instBucket.Busy` | `PRG_TREUILS_CFC` | 79 |
| `PRG_TREUILS_CFC.instExtractionSequence.Busy` | `PRG_TREUILS_CFC` | 80 |
| `PRG_TREUILS_CFC.instExtractionSequence.ExtractionState` | `PRG_TREUILS_CFC` | 81 |

Lectures GVL : `GVL_IHM.Network.Bypass.Global`(`:47`,`:60`), `GVL_IHM.Network.Bypass.IhmHeartbeat`(`:66`),
`GVL_IHM.Commun.TglHeartbeatIhm`(`:67`), `GVL_Global.BlinkClock`(`:68`),
`GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate`(`:89`), `_Joystick*` PERSISTENT (`:82`,`:83`,`:90`–`:93`).

### ④ Consommateurs — 8 POU (via instances internes uniquement)

| POU consommateur | Instances lues | Occ. |
|---|---|---|
| `PRG_02_Encoders` | `instDiagEthercat` | 2 (59, 109) |
| `PRG_05_Cycle` | `instIhmHeartbeat`, `instJoystick` | 3 (39, 40, 48) |
| `PRG_ACQUISITION_CFC` | `instDiagCanOpen`, `instDiagEthercat` | 4 (195, 196, 220, 267) |
| `PRG_SAFETY_CFC` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat`, `instJoystick` | 13 |
| `PRG_SUPERVISION_CFC` | `instDiagCanOpen`, `instDiagEthercat`, `instJoystick` | 25 |
| `PRG_TRANSLATION_CFC` | `instJoystick` | 10 |
| `PRG_TREUILS_CFC` | `instJoystick` | 21 |
| `PRG_TROUBLESHOOTING_CFC` | `instDiagEthercat`, `instIhmHeartbeat`, `instJoystick` | 11 |

---

## A4. `PRG_02_Encoders` — `CODE/MAIN/PRG_02_Encoders.st` (212 lignes)

### ① Instances FB déclarées — 10

| Instance | Type | Déclaration |
|---|---|---|
| `instEncoderAbsM1` | `FB_Encoder_Abs` | `PRG_02_Encoders.st:27` ⚠️ **dupliquée** (T1) |
| `instEncoderScaleM1` | `FB_Encoder_Scale` | `:28` ⚠️ **dupliquée** (T1) |
| `instHomingM1` | `FB_Encoder_Homing` | `:29` ⚠️ **dupliquée** (T1) |
| `instEncoderAbsM2` | `FB_Encoder_Abs` | `:30` ⚠️ **dupliquée** (T1) |
| `instEncoderScaleM2` | `FB_Encoder_Scale` | `:31` ⚠️ **dupliquée** (T1) |
| `instHomingM2` | `FB_Encoder_Homing` | `:32` ⚠️ **dupliquée** (T1) |
| `instEncoderSafetyM1` | `FB_Encoder_Safety` | `:33` |
| `instEncoderSafetyM2` | `FB_Encoder_Safety` | `:34` |
| `instEncoderSpeedMeasureM1` | `FB_Encoder_SpeedMeasure` | `:35` |
| `instEncoderSpeedMeasureM2` | `FB_Encoder_SpeedMeasure` | `:36` |

Variables internes : `M1_RawPosToUse`(`:23`), `M2_RawPosToUse`(`:24`), `M1PositionValid`(`:38`),
`M2PositionValid`(`:39`), `M1SpeedReset`(`:40`), `M2SpeedReset`(`:41`).

### ② Variables publiques produites — 9 `VAR_OUTPUT` + 6 sorties physiques codeurs

| Variable | Type | Décl. | Écriture | Consommateurs |
|---|---|---|---|---|
| `EncoderFaultPresent` | BOOL | `:12` | `:212` | `PRG_MODES_CFC`(28) |
| `EncoderFaultPresentM1` | BOOL | `:13` | `:162` | **AUCUN** |
| `EncoderFaultPresentM2` | BOOL | `:14` | `:175` | **AUCUN** |
| `M1MeasuredSpeed_Mps` | REAL | `:15` | `:205` | `PRG_05_Cycle`(68) · `PRG_SAFETY_CFC`(71,155,178) · `PRG_SUPERVISION_CFC`(186) · `PRG_TROUBLESHOOTING_CFC`(70) |
| `M1MeasuredSpeedSigned_Mps` | REAL | `:16` | `:206` | `PRG_SAFETY_CFC`(72,179) |
| `M1SpeedValid` | BOOL | `:17` | `:207` | `PRG_SAFETY_CFC`(73,151,173) · `PRG_TREUILS_CFC`(169) |
| `M2MeasuredSpeed_Mps` | REAL | `:18` | `:208` | `PRG_05_Cycle`(69) · `PRG_SAFETY_CFC`(131,165,189) · `PRG_SUPERVISION_CFC`(259) · `PRG_TROUBLESHOOTING_CFC`(70) |
| `M2MeasuredSpeedSigned_Mps` | REAL | `:19` | `:209` | `PRG_SAFETY_CFC`(132,190) |
| `M2SpeedValid` | BOOL | `:20` | `:210` | `PRG_SAFETY_CFC`(133,161,184) · `PRG_TREUILS_CFC`(170) |

**Sorties physiques écrites directement par ce POU** (voir T3) :

| Symbole | Écriture | Adresse `Device.export` |
|---|---|---|
| `COD1_PresettTrigCmd` | `PRG_02_Encoders.st:63` | `%QW2` (`Device.export:82334`) |
| `COD1_CodeSeqTrigCmd` | `:64` | `%QW3` (`Device.export:82783`) |
| `COD1_PresetValue` | `:65` | `%QD4` (`Device.export:83648`) |
| `COD2_PresettTrigCmd` | `:113` | mappé (`Device.export:95422`), adresse non prouvée |
| `COD2_CodeSeqTrigCmd` | `:114` | mappé (`Device.export:95870`), adresse non prouvée |
| `COD2_PresetValue` | `:115` | mappé (`Device.export:96734`), adresse non prouvée |

📌 **Fait #7 — `PRG_02_Encoders` écrit 6 sorties physiques codeurs.** Ce sont les seules écritures
de sorties matérielles hors `PRG_10_Outputs_LD` dans `CODE/`. Voir T3.

### ③ Variables lues chez d'autres POU — 18 symboles / 40 lignes-occurrences

| Symbole lu | POU producteur | Lignes |
|---|---|---|
| `PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1.Operational` | `PRG_01_Diagnostics` | 59 |
| `PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2.Operational` | `PRG_01_Diagnostics` | 109 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD1_PosValue` | `PRG_ACQUISITION_CFC` | 47 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD2_PosValue` | `PRG_ACQUISITION_CFC` | 48 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD1_Alarms` | `PRG_ACQUISITION_CFC` | 57 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD1_Warnings` | `PRG_ACQUISITION_CFC` | 58 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD2_Alarms` | `PRG_ACQUISITION_CFC` | 107 |
| `PRG_ACQUISITION_CFC.HwIn.Winch.COD2_Warnings` | `PRG_ACQUISITION_CFC` | 108 |
| `PRG_ACQUISITION_CFC.WinchInputSourceChanged` | `PRG_ACQUISITION_CFC` | 188, 190 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 54, 71, 104, 121, 154, 167 |
| `PRG_01_Inputs_LD.TopPositionSensor` | `PRG_01_Inputs_LD` | 79, 129 |
| `PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff` | `PRG_01_Inputs_LD` | 81 |
| `PRG_01_Inputs_LD.M1BrakeFeedback` | `PRG_01_Inputs_LD` | 82 |
| `PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff` | `PRG_01_Inputs_LD` | 131 |
| `PRG_01_Inputs_LD.M2BrakeFeedback` | `PRG_01_Inputs_LD` | 132 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 55, 72, 74, 105, 122, 124, 155, 168 |
| `PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated` | `PRG_MODES_CFC` | 75, 76, 125, 126 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 53, 70, 103, 120, 153, 166 |

### ④ Consommateurs — 7 POU

| POU | Ce qu'il lit | Occ. |
|---|---|---|
| `PRG_MODES_CFC` | `EncoderFaultPresent` | 1 |
| `PRG_05_Cycle` | `M1/M2MeasuredSpeed_Mps`, `instEncoderScaleM1/M2` | 4 |
| `PRG_ACQUISITION_CFC` | `instEncoderAbsM1/M2` | 4 |
| `PRG_SAFETY_CFC` | 6 `VAR_OUTPUT` + `instEncoderAbs/Scale/HomingM1/M2` | 28 |
| `PRG_SUPERVISION_CFC` | 2 `VAR_OUTPUT` + `instEncoderAbs/Safety/Scale/HomingM1/M2` | 47 |
| `PRG_TREUILS_CFC` | `M1/M2SpeedValid` + `instEncoderAbs/Scale/HomingM1/M2` | 44 |
| `PRG_TROUBLESHOOTING_CFC` | `M1/M2MeasuredSpeed_Mps` + `instEncoderAbs/Scale/HomingM1/M2` | 14 |

---

## A5. `PRG_AUXILIARY_CFC` — `CODE/MAIN/PRG_AUXILIARY_CFC.st` (21 lignes)

### ① Instances FB déclarées — **0**

### ② Variables publiques produites — 1

| Variable | Type | Décl. | Écriture | Consommateur |
|---|---|---|---|---|
| `HydraulicFaultOk` | BOOL | `PRG_AUXILIARY_CFC.st:16` | `:21` | `PRG_SUPERVISION_CFC`(161) — unique |

### ③ Variables lues chez d'autres POU — 1

| Symbole lu | POU producteur | Lignes |
|---|---|---|
| `PRG_ACQUISITION_CFC.HwIn.Machine.HydraulicThermalOk_DI` | `PRG_ACQUISITION_CFC` | 21 (code) · 9 (commentaire de bandeau) |

### ④ Consommateurs — 1 : `PRG_SUPERVISION_CFC.st:161`
(`GVL_IHM.Commun.HydraulicThermalFault := NOT PRG_AUXILIARY_CFC.HydraulicFaultOk;`)

📌 **Fait #8 — POU de 21 lignes, 1 ligne de code exécutable** (`:21`), 0 instance FB.

---

## A6. `PRG_MODES_CFC` — `CODE/MAIN/PRG_MODES_CFC.st` (36 lignes)

### ① Instances FB déclarées — 1

| Instance | Type | Déclaration |
|---|---|---|
| `instModes` | `FB_Modes` | `PRG_MODES_CFC.st:11` |

### ② Variables publiques produites — 1

| Variable | Type | Décl. | Écriture | Consommateurs |
|---|---|---|---|---|
| `Auth` | `ST_Modes_Autorisations` | `:14` | `:33` | 9 POU (tous sauf `PRG_01_Inputs_LD` et lui-même) |

Champs de `Auth` effectivement lus : `Mode`, `InhibitM1`, `InhibitM2`, `SyncEnable`,
`HomingApproachEnable`, `JoystickWinchSelectArbitrated`, `MaintenanceM3TargetEnable`.

### ③ Variables lues chez d'autres POU — 2

| Symbole lu | POU producteur | Ligne |
|---|---|---|
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 22 |
| `PRG_02_Encoders.EncoderFaultPresent` | `PRG_02_Encoders` | 28 |

### ④ Consommateurs de `Auth` — 9 POU / 95 lignes-occurrences

Occ. = lignes-occurrences comptées par symbole (`Auth.<Champ>`).

| POU | Occ. | Champs lus | Lignes distinctes |
|---|---|---|---|
| `PRG_TREUILS_CFC` | 34 | `Mode`(16) · `JoystickWinchSelectArbitrated`(5) · `InhibitM2`(4) · `HomingApproachEnable`(4) · `InhibitM1`(3) · `SyncEnable`(2) | 107, 124, 134, 138, 155, 159, 180, 189, 204, 209, 225, 226, 253, 287, 288, 318, 349, 350, 378, 426, 427, 432, 437, 553, 572, 592, 593, 596, 613, 637, 638, 641, 657 *(33 lignes ; `:427` lit `InhibitM1` **et** `InhibitM2`)* |
| `PRG_SAFETY_CFC` | 17 | `Mode`(7) · `InhibitM1`(4) · `InhibitM2`(4) · `SyncEnable`(2) | 32, 35, 36, 70, 93, 96, 97, 130, 151, 154, 161, 164, 173, 176, 184, 187, 205 |
| `PRG_02_Encoders` | 12 | `Mode`(8) · `JoystickWinchSelectArbitrated`(4) | 55, 72, 74, 75, 76, 105, 122, 124, 125, 126, 155, 168 |
| `PRG_ACQUISITION_CFC` | 11 | `Mode`(7) · `JoystickWinchSelectArbitrated`(4) | 191, 216, 229, 231, 232, 233, 263, 276, 278, 279, 280 |
| `PRG_SUPERVISION_CFC` | 8 | `Mode`(3) · `InhibitM1`(2) · `InhibitM2`(2) · `MaintenanceM3TargetEnable`(1) | 154, 155, 235, 254, 310, 329, 400, 498 |
| `PRG_TRANSLATION_CFC` | 6 | `Mode`(5) · `MaintenanceM3TargetEnable`(1) | 40, 67, 68, 130, 147, 150 |
| `PRG_TROUBLESHOOTING_CFC` | 5 | `Mode`(5) | 72, 76, 124, 171, 241 *(`:76` lit `Mode` deux fois)* |
| `PRG_01_Diagnostics` | 1 | `Mode` | 78 |
| `PRG_05_Cycle` | 1 | `Mode` | 46 |
| **TOTAL** | **95** | 7 champs distincts | — |

📌 **Fait #9 — `instModes` n'est lue par aucun POU externe.** Tous passent par `Auth` (`:33`).
C'est le seul POU métier où l'encapsulation est intégralement respectée.

---

## A7. `PRG_SAFETY_CFC` — `CODE/MAIN/PRG_SAFETY_CFC.st` (235 lignes)

### ① Instances FB déclarées — 7

| Instance | Type | Déclaration |
|---|---|---|
| `instSafetyWinchM1` | `FB_Safety_Winch` | `PRG_SAFETY_CFC.st:11` |
| `instSafetyWinchM2` | `FB_Safety_Winch` | `:12` |
| `instSpeedMonitorM1` | `FB_Encoder_SpeedMonitor` | `:13` |
| `instSpeedMonitorM2` | `FB_Encoder_SpeedMonitor` | `:14` |
| `instLoadEstimatorM1` | `FB_WinchLoadEstimator` | `:15` |
| `instLoadEstimatorM2` | `FB_WinchLoadEstimator` | `:16` |
| `instSafetyTranslationM3` | `FB_Safety_Translation` | `:17` |

### ② Variables publiques produites — **0 `VAR_OUTPUT`, 0 écriture GVL**

📌 **Fait #10 — `PRG_SAFETY_CFC` n'a aucun `VAR_OUTPUT` et n'écrit aucune GVL.**
La totalité de ses résultats safety (`SafeStop`, `ForbidAscent`, `ForbidDescent`, `PowerCutOff`,
`Error`, `ErrorId`, `MecaADriftM`, `MecaBElapsedTime`, `MecaCDriftM`, `State`, `SpeedBand`,
`SpeedStable`, `SpeedVariationConfirmed`, `EstimatedLoadPct`, …) est consommée par **lecture directe
de ses 7 instances internes** depuis 4 POU (T2-11/12/13, T2-49→55, T2-68, T2-77→82, T2-94/95/96).

### ③ Variables lues chez d'autres POU — 55 symboles / 108 lignes-occurrences

| Symbole lu | Producteur | Lignes |
|---|---|---|
| `PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online` | `PRG_01_Diagnostics` | 37, 98, 206 |
| `PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational` | `PRG_01_Diagnostics` | 38, 99, 207 |
| `PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Online` | `PRG_01_Diagnostics` | 211 |
| `PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur.Operational` | `PRG_01_Diagnostics` | 212 |
| `PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk` | `PRG_01_Diagnostics` | 39, 100, 208 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef` | `PRG_01_Diagnostics` | 61, 121 |
| `PRG_02_Encoders.M1MeasuredSpeed_Mps` | `PRG_02_Encoders` | 71, 155, 178 |
| `PRG_02_Encoders.M1MeasuredSpeedSigned_Mps` | `PRG_02_Encoders` | 72, 179 |
| `PRG_02_Encoders.M1SpeedValid` | `PRG_02_Encoders` | 73, 151, 173 |
| `PRG_02_Encoders.M2MeasuredSpeed_Mps` | `PRG_02_Encoders` | 131, 165, 189 |
| `PRG_02_Encoders.M2MeasuredSpeedSigned_Mps` | `PRG_02_Encoders` | 132, 190 |
| `PRG_02_Encoders.M2SpeedValid` | `PRG_02_Encoders` | 133, 161, 184 |
| `PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable` | `PRG_02_Encoders` | 40 |
| `PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable` | `PRG_02_Encoders` | 101 |
| `PRG_02_Encoders.instEncoderScaleM1.CablePosM` | `PRG_02_Encoders` | 48, 127 |
| `PRG_02_Encoders.instEncoderScaleM2.CablePosM` | `PRG_02_Encoders` | 67, 109 |
| `PRG_02_Encoders.instHomingM1.Busy` / `.Homed` / `.HomingSuspect` | `PRG_02_Encoders` | 47 / 52 / 53 |
| `PRG_02_Encoders.instHomingM2.Busy` / `.Homed` / `.HomingSuspect` | `PRG_02_Encoders` | 108 / 113 / 114 |
| `PRG_ACQUISITION_CFC.M3_StatusWord_Filtered` | `PRG_ACQUISITION_CFC` | 213 |
| `PRG_ACQUISITION_CFC.M3_ActualFrequencyHz_Filtered` | `PRG_ACQUISITION_CFC` | 214 |
| `PRG_ACQUISITION_CFC.instPosDecoderM3.LimitSwitchFwd` / `.LimitSwitchRev` / `.Incoherent` | `PRG_ACQUISITION_CFC` | 220 / 221 / 222 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 34, 95, 153, 163, 175, 186, 204 |
| `PRG_01_Inputs_LD.BrakeThermalFeedback` | `PRG_01_Inputs_LD` | 43, 104, 210 |
| `PRG_01_Inputs_LD.PhaseRotationOk` | `PRG_01_Inputs_LD` | 45, 106, 209 |
| `PRG_01_Inputs_LD.SlackCableSwitch` | `PRG_01_Inputs_LD` | 44, 105 |
| `PRG_01_Inputs_LD.TopPositionSensor` | `PRG_01_Inputs_LD` | 46, 107 |
| `PRG_01_Inputs_LD.M1ThermalFeedback` / `.M1FwdRevSpeedFeedbackOff` / `.M1BrakeFeedback` | `PRG_01_Inputs_LD` | 42 / 56 / 57 |
| `PRG_01_Inputs_LD.M2ThermalFeedback` / `.M2FwdRevSpeedFeedbackOff` / `.M2BrakeFeedback` | `PRG_01_Inputs_LD` | 103 / 118 / 119 |
| `PRG_01_Inputs_LD.M3BrakeFeedback` | `PRG_01_Inputs_LD` | 215 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 35, 96, 154, 164, 176, 187, 205 |
| `PRG_MODES_CFC.Auth.InhibitM1` | `PRG_MODES_CFC` | 32, 130, 151, 173 |
| `PRG_MODES_CFC.Auth.InhibitM2` | `PRG_MODES_CFC` | 70, 93, 161, 184 |
| `PRG_MODES_CFC.Auth.SyncEnable` | `PRG_MODES_CFC` | 36, 97 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 33, 94, 152, 162, 174, 185, 203 |
| `PRG_TRANSLATION_CFC.M3_Direction_Active` | `PRG_TRANSLATION_CFC` | 217 |
| `PRG_TREUILS_CFC.M1_Direction_Active` | `PRG_TREUILS_CFC` | 50 |
| `PRG_TREUILS_CFC.M2_Direction_Active` | `PRG_TREUILS_CFC` | 111 |
| `PRG_TREUILS_CFC.instBucket.Busy` | `PRG_TREUILS_CFC` | 62, 68, 128 |
| `PRG_TREUILS_CFC.instBucket.ActiveOffsetM` | `PRG_TREUILS_CFC` | 67, 127 |
| `PRG_TREUILS_CFC.instWinchM1.RelayFwd` / `.RelayRev` / `.StepNumber` | `PRG_TREUILS_CFC` | 51 / 51 / 177 |
| `PRG_TREUILS_CFC.instWinchM2.RelayFwd` / `.RelayRev` / `.StepNumber` | `PRG_TREUILS_CFC` | 112 / 112 / 188 |

Lecture GVL particulière : `GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd`
(`PRG_SAFETY_CFC.st:216`) — instance interne de `PRG_10_Outputs_LD` recopiée en GVL
(`PRG_OUTPUTS_LD.st:187`). Cité par le plan M5 (`PLAN_EXECUTION_MIGRATION_7POU.md` §4 M5).

### ④ Consommateurs — 5 POU

| POU | Instances lues | Occ. |
|---|---|---|
| `PRG_10_Outputs_LD` | `instSafetyWinchM1/M2.PowerCutOff`, `instSafetyTranslationM3.PowerCutOff` | 3 (toutes `:141`) |
| `PRG_SUPERVISION_CFC` | `instSafetyWinchM1/M2`, `instSafetyTranslationM3`, `instSpeedMonitorM1/M2`, `instLoadEstimatorM1/M2` | 45 |
| `PRG_TRANSLATION_CFC` | `instSafetyTranslationM3.SafeStop` | 2 (152, 176) |
| `PRG_TREUILS_CFC` | `instSafetyWinchM1/M2`, `instSpeedMonitorM1/M2`, `instLoadEstimatorM1/M2` | 12 |
| `PRG_TROUBLESHOOTING_CFC` | `instSafetyWinchM1/M2`, `instSafetyTranslationM3` | 22 |

---

## A8. `PRG_05_Cycle` — `CODE/MAIN/PRG_05_Cycle.st` (98 lignes)

### ① Instances FB déclarées — 1

| Instance | Type | Déclaration |
|---|---|---|
| `instCycle` | `FB_Cycle` | `PRG_05_Cycle.st:13` |

Variables internes : `CmdStartCycle_IHM`(`:16`), `CmdPauseCycle_IHM`(`:17`), `CmdAbortCycle_IHM`(`:18`),
`CmdResetCycle_IHM`(`:19`), `SetDepthM`(`:22`), `SetOffsetM`(`:23`), `CycleMotionPermit`(`:24`),
`SpeedMismatchThresholdMps`(`:26`), `SpeedMismatchTimeout`(`:27`).

### ② Variables publiques produites — **0 `VAR_OUTPUT`**

Écritures GVL : `GVL_IHM.Cycle.State.SpeedMismatch_Mps`(`:89`), `.SpeedMismatchActive`(`:90`),
`.SpeedMismatchConfirmed`(`:91`) ; remises à zéro impulsionnelles
`GVL_IHM.Cycle.Cmd.BtnStart/BtnPause/BtnAbort/BtnReset`(`:94`–`:97`).

📌 **Fait #11 — `PRG_05_Cycle` n'a aucun `VAR_OUTPUT`.** Ses consommateurs lisent `instCycle`
(T2-45, T2-66, T2-76, T2-92) et la variable locale `CycleMotionPermit` (T2b-08).

### ③ Variables lues chez d'autres POU — 20 symboles / 20 lignes-occurrences

| Symbole lu | Producteur | Ligne |
|---|---|---|
| `PRG_01_Diagnostics.instJoystick.DeadmanArmed` | `PRG_01_Diagnostics` | 39 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop` | `PRG_01_Diagnostics` | 40 |
| `PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk` | `PRG_01_Diagnostics` | 48 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 46 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 50 |
| `PRG_01_Inputs_LD.KoboldContactFond` | `PRG_01_Inputs_LD` | 61 |
| `PRG_TREUILS_CFC.instWinchSync.Error` | `PRG_TREUILS_CFC` | 64 |
| `PRG_TREUILS_CFC.instWinchSync.DeltaPosM` | `PRG_TREUILS_CFC` | 65 |
| `PRG_02_Encoders.instEncoderScaleM1.CablePosM` | `PRG_02_Encoders` | 66 |
| `PRG_02_Encoders.instEncoderScaleM2.CablePosM` | `PRG_02_Encoders` | 67 |
| `PRG_02_Encoders.M1MeasuredSpeed_Mps` | `PRG_02_Encoders` | 68 |
| `PRG_02_Encoders.M2MeasuredSpeed_Mps` | `PRG_02_Encoders` | 69 |
| `PRG_ACQUISITION_CFC.TranslationPosP1` | `PRG_ACQUISITION_CFC` | 75 |
| `PRG_ACQUISITION_CFC.TranslationPosP2` | `PRG_ACQUISITION_CFC` | 76 |
| `PRG_ACQUISITION_CFC.TranslationPosMaintenance` | `PRG_ACQUISITION_CFC` | 77 |
| `PRG_ACQUISITION_CFC.TranslationPosTremie` | `PRG_ACQUISITION_CFC` | 78 |
| `PRG_TRANSLATION_CFC.instTranslationM3.Busy` | `PRG_TRANSLATION_CFC` | 79 |
| `PRG_TRANSLATION_CFC.instTranslationM3.Done` | `PRG_TRANSLATION_CFC` | 80 |
| `PRG_TREUILS_CFC.instBucket.Busy` | `PRG_TREUILS_CFC` | 83 |
| `PRG_TREUILS_CFC.instBucket.Done` | `PRG_TREUILS_CFC` | 84 |

### ④ Consommateurs — 4 POU

| POU | Ce qu'il lit | Occ. |
|---|---|---|
| `PRG_TREUILS_CFC` | `instCycle.BucketCmd.*`, `instCycle.WinchM1Cmd.*`, `instCycle.WinchM2Cmd.*` | 9 (181, 190, 210, 257, 260, 265, 321, 324, 329) |
| `PRG_SUPERVISION_CFC` | `instCycle.*` (8) + `CycleMotionPermit` (1) | 9 |
| `PRG_TRANSLATION_CFC` | `instCycle.TranslationCmd.Target`(43), `.Start`(46) | 2 |
| `PRG_TROUBLESHOOTING_CFC` | `instCycle.Busy`(86), `.WinchM1Cmd.SpeedPct`(123), `.WinchM2Cmd.SpeedPct`(170), `.BucketCmd.Open`(213) | 4 |

---

## A9. `PRG_TREUILS_CFC` — `CODE/MAIN/PRG_TREUILS_CFC.st` (708 lignes)

### ① Instances FB déclarées — 7

| Instance | Type | Déclaration |
|---|---|---|
| `instWinchSync` | `FB_WinchSync` | `PRG_TREUILS_CFC.st:22` |
| `instBucket` | `FB_Bucket` | `:23` |
| `instWinchM1` | `FB_Winch` | `:24` |
| `instWinchM2` | `FB_Winch` | `:25` |
| `instDiveSearch` | `FB_DiveSearch` | `:26` |
| `instExtractionSequence` | `FB_ExtractionSequence` | `:27` |
| `BenneBusyFallEdge` | `F_TRIG` | `:81` (déclarée hors bloc d'instances, dans le `VAR` métier) |

### ② Variables publiques produites — 3 `VAR_OUTPUT`

| Variable | Type | Décl. | Écritures | Consommateur |
|---|---|---|---|---|
| `WinchM1FinalInterlockRequest` | `ST_WinchFinalInterlockRequest` | `:13` | `:680`–`:693` (14 champs) | `PRG_10_Outputs_LD`(55–68) |
| `WinchM2FinalInterlockRequest` | `ST_WinchFinalInterlockRequest` | `:14` | `:695`–`:708` (14 champs) | `PRG_10_Outputs_LD`(71–84) |
| `KoboldContactorCmdArbitrated` | BOOL | `:15` | `:190`, `:192` | `PRG_10_Outputs_LD`(133) |

**Variables `VAR` (internes) lues par d'autres POU** — voir T2b :
`StubMachineEnableN1`(`:19`), `M1_Direction_Active`(`:40`), `M1_SpeedRef_Active`(`:41`),
`M2_Direction_Active`(`:45`), `M2_SpeedRef_Active`(`:46`), `ForbidDescentM1_Active`(`:55`),
`ForbidDescentM2_Active`(`:56`), `CableLimitAscentM1Reached`(`:60`), `CableLimitAscentM2Reached`(`:61`).

Écritures GVL : `GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE` (`:129`, `:176`).

### ③ Variables lues chez d'autres POU — 50 symboles / 147 lignes-occurrences

| Symbole lu | Producteur | Lignes |
|---|---|---|
| `PRG_01_Diagnostics.instJoystick.AxisCmdY.Direction` | `PRG_01_Diagnostics` | 104, 284, 346 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop` | `PRG_01_Diagnostics` | 105, 262, 285, 326, 347 |
| `PRG_01_Diagnostics.instJoystick.DeadmanArmed` | `PRG_01_Diagnostics` | 106, 118, 261, 286, 304, 325, 348, 366 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef` | `PRG_01_Diagnostics` | 108, 266, 291, 330, 353 |
| `PRG_02_Encoders.instEncoderScaleM1.CablePosM` | `PRG_02_Encoders` | 143, 167, 214, 433, 527, 552, 559, 622 |
| `PRG_02_Encoders.instEncoderScaleM2.CablePosM` | `PRG_02_Encoders` | 144, 168, 215, 434, 530, 571, 578, 666 |
| `PRG_02_Encoders.instHomingM1.Homed` | `PRG_02_Encoders` | 145, 171, 216, 435, 550, 557, 620 |
| `PRG_02_Encoders.instHomingM1.HomingSuspect` | `PRG_02_Encoders` | 146, 172, 551, 558, 621 |
| `PRG_02_Encoders.instHomingM2.Homed` | `PRG_02_Encoders` | 145, 171, 217, 436, 569, 576, 664 |
| `PRG_02_Encoders.instHomingM2.HomingSuspect` | `PRG_02_Encoders` | 146, 172, 570, 577, 665 |
| `PRG_02_Encoders.M1SpeedValid` / `M2SpeedValid` | `PRG_02_Encoders` | 169 / 170 |
| `PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable` / `M2` | `PRG_02_Encoders` | 205 / 206 |
| `PRG_05_Cycle.instCycle.BucketCmd.Close` / `.KoboldContactorCmd` / `.Open` | `PRG_05_Cycle` | 181 / 190 / 210 |
| `PRG_05_Cycle.instCycle.WinchM1Cmd.Direction` / `.StartStop` / `.SpeedPct` | `PRG_05_Cycle` | 257 / 260 / 265 |
| `PRG_05_Cycle.instCycle.WinchM2Cmd.Direction` / `.StartStop` / `.SpeedPct` | `PRG_05_Cycle` | 321 / 324 / 329 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 125, 137, 158, 208, 431, 595, 640, 682, 697 |
| `PRG_01_Inputs_LD.KoboldContactFond` | `PRG_01_Inputs_LD` | 142 |
| `PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff` / `.M1BrakeFeedback` / `.M1BrakeCommandOpenConfirmed` | `PRG_01_Inputs_LD` | 614, 686 / 615 / 685 |
| `PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff` / `.M2BrakeFeedback` / `.M2BrakeCommandOpenConfirmed` | `PRG_01_Inputs_LD` | 658, 701 / 659 / 700 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 124, 134, 138, 155, 159, 180, 189, 209, 253, 318, 378, 432, 592, 596, 637, 641 |
| `PRG_MODES_CFC.Auth.InhibitM1` / `.InhibitM2` | `PRG_MODES_CFC` | 225, 427, 593 / 204, 226, 427, 638 |
| `PRG_MODES_CFC.Auth.SyncEnable` | `PRG_MODES_CFC` | 426, 437 |
| `PRG_MODES_CFC.Auth.HomingApproachEnable` | `PRG_MODES_CFC` | 553, 572, 613, 657 |
| `PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated` | `PRG_MODES_CFC` | 107, 287, 288, 349, 350 |
| `PRG_SAFETY_CFC.instSafetyWinchM1.SafeStop` / `.ForbidDescent` / `.ForbidAscent` | `PRG_SAFETY_CFC` | 517 / 525 / 556 |
| `PRG_SAFETY_CFC.instSafetyWinchM2.SafeStop` / `.ForbidDescent` / `.ForbidAscent` | `PRG_SAFETY_CFC` | 521 / 528 / 575 |
| `PRG_SAFETY_CFC.instLoadEstimatorM1.SpeedBand` / `M2` | `PRG_SAFETY_CFC` | 608 / 652 |
| `PRG_SAFETY_CFC.instSpeedMonitorM1.SpeedStable` / `.SpeedVariationConfirmed` | `PRG_SAFETY_CFC` | 610 / 611 |
| `PRG_SAFETY_CFC.instSpeedMonitorM2.SpeedStable` / `.SpeedVariationConfirmed` | `PRG_SAFETY_CFC` | 654 / 655 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 126, 136, 157, 207, 430, 594, 639, 681, 696 |

### ④ Consommateurs — 8 POU

| POU | Ce qu'il lit | Occ. |
|---|---|---|
| `PRG_SUPERVISION_CFC` | `instWinchM1/M2`, `instBucket`, `instWinchSync`, `instDiveSearch`, `instExtractionSequence`, `ForbidDescentM1/M2_Active`, `CableLimitAscentM1/M2Reached` | 80 |
| `PRG_10_Outputs_LD` | `WinchM1/M2FinalInterlockRequest`, `KoboldContactorCmdArbitrated` | 29 |
| `PRG_TROUBLESHOOTING_CFC` | `instWinchM1/M2`, `instBucket`, `instWinchSync`, `M1/M2_Direction_Active`, `M1/M2_SpeedRef_Active` | 24 |
| `PRG_SAFETY_CFC` | `instWinchM1/M2`, `instBucket`, `M1/M2_Direction_Active` | 13 |
| `PRG_ACQUISITION_CFC` | `instBucket`, `instExtractionSequence`, `M1/M2_SpeedRef_Active` | 5 |
| `PRG_05_Cycle` | `instBucket`, `instWinchSync` | 4 |
| `PRG_01_Diagnostics` | `instBucket`, `instExtractionSequence` | 3 |
| `PRG_TRANSLATION_CFC` | `StubMachineEnableN1` | 2 (146, 173) |

---

## A10. `PRG_TRANSLATION_CFC` — `CODE/MAIN/PRG_TRANSLATION_CFC.st` (180 lignes)

### ① Instances FB déclarées — 1

| Instance | Type | Déclaration |
|---|---|---|
| `instTranslationM3` | `FB_Translation` | `PRG_TRANSLATION_CFC.st:17` |

### ② Variables publiques produites — 1 `VAR_OUTPUT`

| Variable | Type | Décl. | Écritures | Consommateur |
|---|---|---|---|---|
| `TranslationFinalInterlockRequest` | `ST_TranslationFinalInterlockRequest` | `:14` | `:173`–`:180` (8 champs) | `PRG_10_Outputs_LD`(87–94) |

**Variables `VAR` internes lues par d'autres POU** (T2b) : `M3_StartStop_Active`(`:20`, non lue),
`M3_Direction_Active`(`:21`), `M3_SpeedRef_Active`(`:22`), `M3_PositioningActive`(`:23`),
`M3_PositionSensorTarget`(`:24`), `SelTarget`(`:28`, non lue), `FreqPct`(`:32`, non lue).

### ③ Variables lues chez d'autres POU — 23 symboles / 37 lignes-occurrences

| Symbole lu | Producteur | Lignes |
|---|---|---|
| `PRG_01_Diagnostics.instJoystick.DeadmanArmed` | `PRG_01_Diagnostics` | 47, 92 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdX.StartStop` | `PRG_01_Diagnostics` | 48, 95, 113 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef` | `PRG_01_Diagnostics` | 50, 108, 115 |
| `PRG_01_Diagnostics.instJoystick.AxisCmdX.Direction` | `PRG_01_Diagnostics` | 82, 114 |
| `PRG_05_Cycle.instCycle.TranslationCmd.Target` / `.Start` | `PRG_05_Cycle` | 43 / 46 |
| `PRG_ACQUISITION_CFC.TranslationPosTremie` / `P2` / `P1` / `Maintenance` / `PV` | `PRG_ACQUISITION_CFC` | 136 / 137 / 138 / 139 / 156 |
| `PRG_ACQUISITION_CFC.instPosDecoderM3.LimitSwitchFwd` / `.LimitSwitchRev` | `PRG_ACQUISITION_CFC` | 157 / 158 |
| `PRG_ACQUISITION_CFC.M3_StatusWord_Filtered` / `.M3_ActualFrequencyHz_Filtered` | `PRG_ACQUISITION_CFC` | 159 / 160 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 149, 175 |
| `PRG_01_Inputs_LD.M3BrakeFeedback` / `.M3BrakeCommandOpenConfirmed` | `PRG_01_Inputs_LD` | 165 / 178 |
| `PRG_MODES_CFC.Auth.Mode` | `PRG_MODES_CFC` | 40, 67, 68, 147, 150 |
| `PRG_MODES_CFC.Auth.MaintenanceM3TargetEnable` | `PRG_MODES_CFC` | 130 |
| `PRG_SAFETY_CFC.instSafetyTranslationM3.SafeStop` | `PRG_SAFETY_CFC` | 152, 176 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 148, 174 |
| `PRG_TREUILS_CFC.StubMachineEnableN1` | `PRG_TREUILS_CFC` | 146, 173 |

Lecture d'un stub GVL : `StubTranslationPositionSelect_IHM` (`:75`, `:112`) — déclaré dans
`CODE/TRANSLATION/GVL_Translation_M3_Stub.st:14`, écrit par `PRG_SUPERVISION_CFC.st:52`.

### ④ Consommateurs — 6 POU

| POU | Ce qu'il lit | Occ. |
|---|---|---|
| `PRG_10_Outputs_LD` | `TranslationFinalInterlockRequest.*` | 8 |
| `PRG_SUPERVISION_CFC` | `instTranslationM3`(7) + `M3_Direction_Active`, `M3_SpeedRef_Active`, `M3_PositioningActive`, `M3_PositionSensorTarget` | 11 |
| `PRG_05_Cycle` | `instTranslationM3.Busy`(79), `.Done`(80) | 2 |
| `PRG_ACQUISITION_CFC` | `M3_Direction_Active`(133), `M3_SpeedRef_Active`(134) | 2 |
| `PRG_SAFETY_CFC` | `M3_Direction_Active`(217) | 1 |
| `PRG_TROUBLESHOOTING_CFC` | `M3_SpeedRef_Active`(243) | 1 |

---

## A11. `PRG_10_Outputs_LD` — `CODE/MAIN/PRG_OUTPUTS_LD.st` (187 lignes)

### ① Instances FB déclarées — 4

| Instance | Type | Déclaration |
|---|---|---|
| `instWinchOutputInterlockM1_LD` | `FB_WinchOutputInterlock_LD` | `PRG_OUTPUTS_LD.st:41` |
| `instWinchOutputInterlockM2_LD` | `FB_WinchOutputInterlock_LD` | `:42` |
| `instTranslationOutputInterlock_LD` | `FB_TranslationOutputInterlock_LD` | `:43` |
| `instSafetyEmergencyManagement` | `FB_Safety_EmergencyManagement` | `:44` |

Variable interne : `PowerCutOffReq` (`:45`, écrite `:141`).

⚠️ Les 3 premières instances sont **également déclarées dans `GVL_Global`**
(`GVL_Global.st:43`, `:44`, `:45`) et recopiées à chaque scan (`PRG_OUTPUTS_LD.st:185`, `:186`, `:187`).
Ce ne sont pas les mêmes objets : ce sont deux jeux d'instances, dont un est une copie de valeur.

### ② Variables publiques produites — 23 `VAR_OUTPUT` + 21 champs `GVL_Global` + 21 sorties physiques

**`VAR_OUTPUT`** :

| Variable | Type | Décl. | Écriture | Consommateurs |
|---|---|---|---|---|
| `M1RelayFwd` | BOOL | `:13` | `:98` | **AUCUN inter-POU** (recopié `GVL_Global.M1RelayFwd`, `:166`) |
| `M1RelayRev` | BOOL | `:14` | `:99` | **AUCUN** (idem, `:167`) |
| `M1SpeedContactor1..4` | BOOL | `:15`–`:18` | `:100`–`:103` | **AUCUN** (idem, `:168`–`:171`) |
| `M1BrakeCmd` | BOOL | `:19` | `:104` | **AUCUN** (idem, `:172`) |
| `M2RelayFwd` | BOOL | `:20` | `:113` | **AUCUN** (idem, `:173`) |
| `M2RelayRev` | BOOL | `:21` | `:114` | **AUCUN** (idem, `:174`) |
| `M2SpeedContactor1..4` | BOOL | `:22`–`:25` | `:115`–`:118` | **AUCUN** (idem, `:175`–`:178`) |
| `M2BrakeCmd` | BOOL | `:26` | `:119` | **AUCUN** (idem, `:179`) |
| `TranslationBrakeCmd` | BOOL | `:27` | `:129` | **AUCUN** (idem, `:180`) |
| `PowerKeepAlive_A_RQ` | BOOL | `:28` | `:155` | `PRG_ACQUISITION_CFC`(137) |
| `PowerKeepAlive_B_RQ` | BOOL | `:29` | `:156` | `PRG_ACQUISITION_CFC`(138) |
| `EmergencyArming_RQ` | BOOL | `:30` | `:157` | `PRG_ACQUISITION_CFC`(139) |
| `EmergencyArmingPulseActive` | BOOL | `:31` | `:159` | **AUCUN** (recopié `GVL_Global`, `:181`) |
| `EmergencyArmingLockoutActive` | BOOL | `:32` | `:160` | **AUCUN** (idem, `:182`) |
| `ArmingSeqStep` | INT | `:33` | `:161` | **AUCUN** (idem, `:183`) |
| `RedundancyTestFailed` | BOOL | `:34` | `:162` | **AUCUN** — non recopié dans `GVL_Global` |
| `EmergencyArmingFailed` | BOOL | `:35` | `:163` | **AUCUN** — non recopié dans `GVL_Global` |

📌 **Fait #12 — `RedundancyTestFailed` (`:34`, écrite `:162`) et `EmergencyArmingFailed`
(`:35`, écrite `:163`) n'ont ni consommateur inter-POU ni recopie `GVL_Global`.**
Les valeurs équivalentes sont relues ailleurs directement sur l'instance :
`PRG_SUPERVISION_CFC.st:506`, `:507` lisent
`PRG_10_Outputs_LD.instSafetyEmergencyManagement.Diag.RedundancyTestFailed` / `.ArmFailed`.

**Écritures `GVL_Global`** (`:166`–`:187`) : 18 champs BOOL/INT + 3 instances complètes.

**Sorties physiques** : voir T3 (21 symboles, `:105`–`:133`).

### ③ Variables lues chez d'autres POU — 43 symboles / 45 lignes-occurrences

| Symbole lu | Producteur | Lignes |
|---|---|---|
| `PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.*` (14 champs) | `PRG_TREUILS_CFC` | 55–68 |
| `PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.*` (14 champs) | `PRG_TREUILS_CFC` | 71–84 |
| `PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.*` (8 champs) | `PRG_TRANSLATION_CFC` | 87–94 |
| `PRG_TREUILS_CFC.KoboldContactorCmdArbitrated` | `PRG_TREUILS_CFC` | 133 |
| `PRG_01_Inputs_LD.PowerContactorEngaged` | `PRG_01_Inputs_LD` | 134, 149 |
| `PRG_01_Inputs_LD.EmergencyChainClosed` | `PRG_01_Inputs_LD` | 135, 148 |
| `PRG_SAFETY_CFC.instSafetyWinchM1.PowerCutOff` | `PRG_SAFETY_CFC` | 141 |
| `PRG_SAFETY_CFC.instSafetyWinchM2.PowerCutOff` | `PRG_SAFETY_CFC` | 141 |
| `PRG_SAFETY_CFC.instSafetyTranslationM3.PowerCutOff` | `PRG_SAFETY_CFC` | 141 |
| `PRG_SUPERVISION_CFC.FaultMachineReset_IHM` | `PRG_SUPERVISION_CFC` | 146 |

Lectures GVL : `GVL_IHM.Modes.Cmd.BtnEmergencyArming`(`:147`), `.BtnEmergencyCutOff`(`:151`).

### ④ Consommateurs — 2 POU

| POU | Ce qu'il lit | Occ. |
|---|---|---|
| `PRG_ACQUISITION_CFC` | `PowerKeepAlive_A_RQ`(137), `PowerKeepAlive_B_RQ`(138), `EmergencyArming_RQ`(139) | 3 |
| `PRG_SUPERVISION_CFC` | `instSafetyEmergencyManagement.*`(502–507), `instWinchOutputInterlockM1_LD.RestartDelayElapsed`(215), `.StepDelayElapsed`(216) | 8 |

📌 **Fait #13 — deux chemins de lecture coexistent pour les interlocks finaux.**
`PRG_SUPERVISION_CFC.st:215`/`:216` lisent l'instance **directement**
(`PRG_10_Outputs_LD.instWinchOutputInterlockM1_LD.…`), tandis que `:208`–`:213`, `:281`–`:291`,
`:369`–`:375`, `:420`, `:421` lisent la **copie GVL** (`GVL_Global.instWinchOutputInterlockM1_LD.…`).

---

## A12. `PRG_SUPERVISION_CFC` — `CODE/MAIN/PRG_SUPERVISION_CFC.st` (524 lignes)

### ① Instances FB déclarées — 9

| Instance | Type | Déclaration |
|---|---|---|
| `instBlink1Hz` | `BLINK` | `PRG_SUPERVISION_CFC.st:21` |
| `instAckConfigRestored` | `R_TRIG` | `:22` |
| `instCfgPersistBridgeSync` | `FB_CfgPersistBridge_SyncCfg` | `:23` |
| `instCfgPersistBridgeCycle` | `FB_CfgPersistBridge_CycleCfg` | `:24` |
| `instCfgPersistBridgeDredgingAssist` | `FB_CfgPersistBridge_DredgingAssistCfg` | `:25` |
| `instCfgPersistBridgeCommun` | `FB_CfgPersistBridge_CommunCfg` | `:26` |
| `instCfgPersistBridgeBucket` | `FB_CfgPersistBridge_BucketCfg` | `:27` |
| `instCfgPersistBridgeWinchM1` | `FB_CfgPersistBridge_WinchCfg` | `:28` |
| `instCfgPersistBridgeWinchM2` | `FB_CfgPersistBridge_WinchCfg` | `:29` |

### ② Variables publiques produites — 1 `VAR_OUTPUT` + 316 écritures `GVL_IHM` + 4 autres

| Variable | Type | Décl. | Écriture | Consommateurs |
|---|---|---|---|---|
| `FaultMachineReset_IHM` | BOOL | `:18` | `:55`–`:58` | **7 POU** (voir ④) |

Autres écritures :
- `GVL_Global.BlinkClock` (`:48`) — unique producteur ; lu par `PRG_01_Diagnostics.st:68`.
- `StubTranslationPositionSelect_IHM` (`:52`) — GVL `CODE/TRANSLATION/GVL_Translation_M3_Stub.st:14`.
- `BypassTranslationGlobal`(`:140`), `BypassWinchM1Global`(`:143`), `BypassWinchM2Global`(`:146`)
  — `GVL_BypassRetain` (`GVL_BypassRetain.st:56`, `:58`, `:60`).
- **316 affectations `GVL_IHM.*`** (mesure : comptage des lignes commençant par `GVL_IHM.` suivi de `:=`).

### ③ Variables lues chez d'autres POU — 242 symboles / 264 lignes-occurrences

C'est le POU au plus fort couplage entrant. Résumé par producteur (détail des lignes en T2 et
dans les sections A des POU producteurs) :

| POU producteur | Symboles distincts lus | Lignes-occurrences |
|---|---|---|
| `PRG_TREUILS_CFC` | 73 | 80 |
| `PRG_02_Encoders` | 42 | 47 |
| `PRG_SAFETY_CFC` | 42 | 45 |
| `PRG_01_Diagnostics` | 24 | 25 |
| `PRG_ACQUISITION_CFC` | 13 | 14 |
| `PRG_TRANSLATION_CFC` | 11 | 11 |
| `PRG_01_Inputs_LD` | 10 | 11 |
| `PRG_05_Cycle` | 9 | 9 |
| `PRG_10_Outputs_LD` | 8 | 8 |
| `PRG_TROUBLESHOOTING_CFC` | 5 | 5 |
| `PRG_MODES_CFC` | 4 | 8 |
| `PRG_AUXILIARY_CFC` | 1 | 1 |
| **TOTAL** | **242** | **264** |

Lectures `GVL_Global.inst*` (copies d'instances Outputs) : 24 lignes —
`instWinchOutputInterlockM1_LD`(208–213), `instWinchOutputInterlockM2_LD`(281–291),
`instTranslationOutputInterlock_LD`(369–375, 420, 421).

### ④ Consommateurs de `FaultMachineReset_IHM` — 7 POU / 44 lignes-occurrences

| POU | Lignes |
|---|---|
| `PRG_TREUILS_CFC` | 126, 136, 157, 207, 430, 594, 639, 681, 696 |
| `PRG_SAFETY_CFC` | 33, 94, 152, 162, 174, 185, 203 |
| `PRG_02_Encoders` | 53, 70, 103, 120, 153, 166 |
| `PRG_ACQUISITION_CFC` | 189, 214, 227, 261, 274 |
| `PRG_01_Diagnostics` | 43, 53, 77 |
| `PRG_TRANSLATION_CFC` | 148, 174 |
| `PRG_10_Outputs_LD` | 146 |

Les 9 instances internes de `PRG_SUPERVISION_CFC` **ne sont lues par aucun autre POU**
(0 occurrence `PRG_SUPERVISION_CFC.inst<X>` hors ce fichier).

📌 **Fait #14 — `PRG_SUPERVISION_CFC` écrit dans `GVL_IHM` et lit `PRG_TROUBLESHOOTING_CFC`.**
`:175`–`:179` lisent `PRG_TROUBLESHOOTING_CFC.instPreflight.*` et `.instWinchSymmetry.*`,
alors que `PRG_TROUBLESHOOTING_CFC` est déclaré en position 11, `PRG_SUPERVISION_CFC` en position 9
(`PRG_TROUBLESHOOTING_CFC.st:4`, `PRG_SUPERVISION_CFC.st:4`).

---

## A13. `PRG_TROUBLESHOOTING_CFC` — `CODE/MAIN/PRG_TROUBLESHOOTING_CFC.st` (262 lignes)

### ① Instances FB déclarées — 3

| Instance | Type | Déclaration |
|---|---|---|
| `instPreflight` | `FB_Acquisition_Preflight` | `PRG_TROUBLESHOOTING_CFC.st:10` |
| `instWinchSymmetry` | `FB_Winch_Symmetry` | `:11` |
| `TonMachineStill` | `TON` | `:12` |

Variables internes de diagnostic (`:13`–`:30`) : `MachineIsStillRaw`, `M1/M2/M3BrakeCommandOpenConfirmedDiag`,
`M1/M2/M3FinalInterlockErrorDiag`, `M1/M2FinalRestartInhibitDiag`, `M1FinalInterlockStateDiag`,
`M1FinalInterlockReasonDiag`, `M1FinalBrakeTimeoutElapsedDiag`, `M1FinalRestartDelayElapsedDiag`,
`M1FinalStepDelayElapsedDiag`, `M3FinalInterlockStateDiag`, `M3FinalInterlockReasonDiag`,
`M3FinalBrakeTimeoutElapsedDiag`.

### ② Variables publiques produites — **0 `VAR_OUTPUT`**

Écritures : **152 affectations `GVL_Troubleshooting.*`** (`:72`–`:262`).
Aucune écriture `GVL_IHM`, `GVL_Global`, ni sortie physique.

### ③ Variables lues chez d'autres POU — 75 symboles / 128 lignes-occurrences

| POU producteur | Symboles distincts | Lignes-occurrences |
|---|---|---|
| `PRG_01_Inputs_LD` | 16 | 38 |
| `PRG_TREUILS_CFC` | 14 | 24 |
| `PRG_SAFETY_CFC` | 14 | 22 |
| `PRG_02_Encoders` | 8 | 14 |
| `PRG_01_Diagnostics` | 8 | 11 |
| `PRG_ACQUISITION_CFC` | 9 | 9 |
| `PRG_MODES_CFC` | 1 | 5 |
| `PRG_05_Cycle` | 4 | 4 |
| `PRG_TRANSLATION_CFC` | 1 | 1 |
| **TOTAL** | **75** | **128** |

Lectures `GVL_Global` : commandes finales recopiées (`:54`–`:56`, `:66`, `:68`, `:107`, `:108`,
`:152`–`:156`, `:199`–`:203`, `:221`, `:262`) et instances interlock (`:39`–`:51`, `:143`–`:150`,
`:190`–`:197`, `:252`–`:261`).

Lecture d'une sortie physique en entrée : `M3_CommandWord` (`:56`) — écrit par
`PRG_OUTPUTS_LD.st:131`.

### ④ Consommateurs — 1 POU

| POU | Ce qu'il lit | Lignes |
|---|---|---|
| `PRG_SUPERVISION_CFC` | `instPreflight.PreflightOk/.PreflightDone/.PreflightErrorId`, `instWinchSymmetry.SymmetryOk/.SymmetryValid` | 175, 176, 177, 178, 179 |

📌 **Fait #15 — `PRG_TROUBLESHOOTING_CFC` n'écrit aucune commande, aucun interlock, aucune sortie
physique.** Vérification : `grep` des affectations `_DQ :=` / `_RQ :=` hors `PRG_OUTPUTS_LD.st`
ne remonte que des écritures **dans `GVL_Troubleshooting`** (champs `Idx5xx_Cmd…`, `:107`, `:108`,
`:152`–`:156`, `:199`–`:203`, `:221`, `:262`), jamais sur un symbole d'E/S.

---

# PARTIE B — Tables de synthèse

## T1 — Instances dupliquées (même nom d'instance dans 2 POU ou plus)

Extraction : parsing des blocs `VAR` / `VAR_OUTPUT` / `VAR_INPUT` des 13 `PRG_*.st`, motif
`^inst… : Type ;`. Sur **78 instances déclarées** au total, **7 noms** apparaissent dans 2 POU.

| # | Nom d'instance | Type | Déclaration 1 | Déclaration 2 | Instance 1 lue hors POU ? | Instance 2 lue hors POU ? |
|---|---|---|---|---|---|---|
| T1-1 | `instJoystick` | `FB_Joystick` | `PRG_01_Diagnostics.st:13` | `PRG_ACQUISITION_CFC.st:35` | ✅ oui — 6 POU, 56 occ. | ❌ non — 0 occ. |
| T1-2 | `instEncoderAbsM1` | `FB_Encoder_Abs` | `PRG_02_Encoders.st:27` | `PRG_ACQUISITION_CFC.st:36` | ✅ oui — 5 POU, 14 occ. | ❌ non — 0 occ. |
| T1-3 | `instEncoderScaleM1` | `FB_Encoder_Scale` | `PRG_02_Encoders.st:28` | `PRG_ACQUISITION_CFC.st:37` | ✅ oui — 5 POU, 19 occ. | ❌ non — 0 occ. |
| T1-4 | `instHomingM1` | `FB_Encoder_Homing` | `PRG_02_Encoders.st:29` | `PRG_ACQUISITION_CFC.st:38` | ✅ oui — 4 POU, 25 occ. | ❌ non — 0 occ. |
| T1-5 | `instEncoderAbsM2` | `FB_Encoder_Abs` | `PRG_02_Encoders.st:30` | `PRG_ACQUISITION_CFC.st:39` | ✅ oui — 5 POU, 14 occ. | ❌ non — 0 occ. |
| T1-6 | `instEncoderScaleM2` | `FB_Encoder_Scale` | `PRG_02_Encoders.st:31` | `PRG_ACQUISITION_CFC.st:40` | ✅ oui — 5 POU, 20 occ. | ❌ non — 0 occ. |
| T1-7 | `instHomingM2` | `FB_Encoder_Homing` | `PRG_02_Encoders.st:32` | `PRG_ACQUISITION_CFC.st:41` | ✅ oui — 4 POU, 25 occ. | ❌ non — 0 occ. |

**Total T1 : 7 doublons**, tous entre `PRG_ACQUISITION_CFC` et (`PRG_01_Diagnostics` |
`PRG_02_Encoders`). Cela correspond exactement aux 7 instances citées par
`PLAN_EXECUTION_MIGRATION_7POU.md` §4 M1 point 1.

### T1bis — Comparaison des câblages des instances dupliquées

Faits observés, sans interprétation :

| Instance | Entrée | `PRG_01_Diagnostics` / `PRG_02_Encoders` | `PRG_ACQUISITION_CFC` |
|---|---|---|---|
| `instJoystick` | `PowerContactorEngaged` | `PRG_01_Inputs_LD.PowerContactorEngaged` (`PRG_01_Diagnostics.st:76`) | `HwIn.Machine.PowerContactorEngaged_DI` (`PRG_ACQUISITION_CFC.st:190`) |
| `instJoystick` | `RawX` | `PRG_ACQUISITION_CFC.HwIn.Operator.JoyXRaw_ANA1` (`:86`) | `HwIn.Operator.JoyXRaw_ANA1` (`:197`) |
| `instEncoderAbsM1` | `RawPosIn` | `M1_RawPosToUse` ← `HwIn.Winch.COD1_PosValue` (`PRG_02_Encoders.st:47`, `:56`) | `HwIn.Winch.COD1_PosValue` (`PRG_ACQUISITION_CFC.st:217`) |
| `instHomingM1` | `TopPositionSensor` | `PRG_01_Inputs_LD.TopPositionSensor` (`PRG_02_Encoders.st:79`) | `HwIn.Winch.M1M2_TopPositionFree_DI` (`PRG_ACQUISITION_CFC.st:236`) |
| `instHomingM1` | `FwdRevSpeedFeedbackOff` | `PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff` (`PRG_02_Encoders.st:81`) | `HwIn.Winch.M1_ContactorsReleased_DI` (`PRG_ACQUISITION_CFC.st:238`) |
| `instHomingM1` | `BrakeFeedback` | `PRG_01_Inputs_LD.M1BrakeFeedback` (`PRG_02_Encoders.st:82`) | `HwIn.Winch.M1_BrakeIsOpen_DI` (`PRG_ACQUISITION_CFC.st:239`) |
| `instHomingM1` | `Calib` | `_CalibM1` (`PRG_02_Encoders.st:69`) | `_CalibM1` (`PRG_ACQUISITION_CFC.st:248`) |

📌 **Fait #16 — les deux jeux d'instances ne sont pas câblés à l'identique.** Le jeu
`PRG_02_Encoders` / `PRG_01_Diagnostics` consomme les signaux **qualifiés** de `PRG_01_Inputs_LD`
(passés par `FB_Input`, polarité inversée + filtre 20 ms), le jeu `PRG_ACQUISITION_CFC` consomme
les signaux **bruts** de `HwIn` (polarité non inversée). Ex. `M1BrakeFeedback` est
`NOT M1_BrakeIsOpen_DI` (`PRG_01_Inputs_LD.st:156`, `:75`, `:160`) alors que
`PRG_ACQUISITION_CFC.st:239` passe `HwIn.Winch.M1_BrakeIsOpen_DI` directement.

---

## T2 — Lectures inter-POU d'instances INTERNES (`PRG_Xxx.instYyy.Champ`)

Extraction : motif `PRG_<POU>.inst<Nom>` dans un fichier dont le `PROGRAM` diffère de `<POU>`,
hors commentaires `//`.

**Total : 100 paires (POU consommateur × instance interne lue) · 458 lignes-occurrences ·
233 expressions distinctes.**

| # | POU consommateur | Instance interne lue | Occ. | Lignes dans le fichier consommateur |
|---|---|---|---|---|
| T2-01 | `PRG_01_Diagnostics` | `PRG_TREUILS_CFC.instBucket` | 1 | 79 |
| T2-02 | `PRG_01_Diagnostics` | `PRG_TREUILS_CFC.instExtractionSequence` | 2 | 80, 81 |
| T2-03 | `PRG_02_Encoders` | `PRG_01_Diagnostics.instDiagEthercat` | 2 | 59, 109 |
| T2-04 | `PRG_05_Cycle` | `PRG_01_Diagnostics.instIhmHeartbeat` | 1 | 48 |
| T2-05 | `PRG_05_Cycle` | `PRG_01_Diagnostics.instJoystick` | 2 | 39, 40 |
| T2-06 | `PRG_05_Cycle` | `PRG_02_Encoders.instEncoderScaleM1` | 1 | 66 |
| T2-07 | `PRG_05_Cycle` | `PRG_02_Encoders.instEncoderScaleM2` | 1 | 67 |
| T2-08 | `PRG_05_Cycle` | `PRG_TRANSLATION_CFC.instTranslationM3` | 2 | 79, 80 |
| T2-09 | `PRG_05_Cycle` | `PRG_TREUILS_CFC.instBucket` | 2 | 83, 84 |
| T2-10 | `PRG_05_Cycle` | `PRG_TREUILS_CFC.instWinchSync` | 2 | 64, 65 |
| T2-11 | `PRG_10_Outputs_LD` | `PRG_SAFETY_CFC.instSafetyTranslationM3` | 1 | 141 |
| T2-12 | `PRG_10_Outputs_LD` | `PRG_SAFETY_CFC.instSafetyWinchM1` | 1 | 141 |
| T2-13 | `PRG_10_Outputs_LD` | `PRG_SAFETY_CFC.instSafetyWinchM2` | 1 | 141 |
| T2-14 | `PRG_ACQUISITION_CFC` | `PRG_01_Diagnostics.instDiagCanOpen` | 2 | 195, 196 |
| T2-15 | `PRG_ACQUISITION_CFC` | `PRG_01_Diagnostics.instDiagEthercat` | 2 | 220, 267 |
| T2-16 | `PRG_ACQUISITION_CFC` | `PRG_02_Encoders.instEncoderAbsM1` | 2 | 120, 121 |
| T2-17 | `PRG_ACQUISITION_CFC` | `PRG_02_Encoders.instEncoderAbsM2` | 2 | 130, 131 |
| T2-18 | `PRG_ACQUISITION_CFC` | `PRG_TREUILS_CFC.instBucket` | 1 | 192 |
| T2-19 | `PRG_ACQUISITION_CFC` | `PRG_TREUILS_CFC.instExtractionSequence` | 2 | 193, 194 |
| T2-20 | `PRG_SAFETY_CFC` | `PRG_01_Diagnostics.instDiagCanOpen` | 6 | 37, 38, 98, 99, 206, 207 |
| T2-21 | `PRG_SAFETY_CFC` | `PRG_01_Diagnostics.instDiagEthercat` | 2 | 211, 212 |
| T2-22 | `PRG_SAFETY_CFC` | `PRG_01_Diagnostics.instIhmHeartbeat` | 3 | 39, 100, 208 |
| T2-23 | `PRG_SAFETY_CFC` | `PRG_01_Diagnostics.instJoystick` | 2 | 61, 121 |
| T2-24 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instEncoderAbsM1` | 1 | 40 |
| T2-25 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instEncoderAbsM2` | 1 | 101 |
| T2-26 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instEncoderScaleM1` | 2 | 48, 127 |
| T2-27 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instEncoderScaleM2` | 2 | 67, 109 |
| T2-28 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instHomingM1` | 3 | 47, 52, 53 |
| T2-29 | `PRG_SAFETY_CFC` | `PRG_02_Encoders.instHomingM2` | 3 | 108, 113, 114 |
| T2-30 | `PRG_SAFETY_CFC` | `PRG_ACQUISITION_CFC.instPosDecoderM3` | 3 | 220, 221, 222 |
| T2-31 | `PRG_SAFETY_CFC` | `PRG_TREUILS_CFC.instBucket` | 5 | 62, 67, 68, 127, 128 |
| T2-32 | `PRG_SAFETY_CFC` | `PRG_TREUILS_CFC.instWinchM1` | 3 | 51 (×2), 177 |
| T2-33 | `PRG_SAFETY_CFC` | `PRG_TREUILS_CFC.instWinchM2` | 3 | 112 (×2), 188 |
| T2-34 | `PRG_SUPERVISION_CFC` | `PRG_01_Diagnostics.instDiagCanOpen` | 6 | 491, 492, 514, 515, 516, 517 |
| T2-35 | `PRG_SUPERVISION_CFC` | `PRG_01_Diagnostics.instDiagEthercat` | 6 | 519, 520, 521, 522, 523, 524 |
| T2-36 | `PRG_SUPERVISION_CFC` | `PRG_01_Diagnostics.instJoystick` | 13 | 381, 477, 478, 483, 484, 485, 486, 487, 488, 489, 490, 493, 494 |
| T2-37 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderAbsM1` | 9 | 231, 241, 242, 243, 244, 245, 246, 247, 248 |
| T2-38 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderAbsM2` | 9 | 306, 316, 317, 318, 319, 320, 321, 322, 323 |
| T2-39 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderSafetyM1` | 1 | 231 |
| T2-40 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderSafetyM2` | 1 | 306 |
| T2-41 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderScaleM1` | 3 | 154, 174, 475 |
| T2-42 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instEncoderScaleM2` | 4 | 155, 258, 348, 476 |
| T2-43 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instHomingM1` | 9 | 217, 218, 219, 220, 221, 222, 223, 224, 225 |
| T2-44 | `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.instHomingM2` | 9 | 292, 293, 294, 295, 296, 297, 298, 299, 300 |
| T2-45 | `PRG_SUPERVISION_CFC` | `PRG_05_Cycle.instCycle` | 8 | 461, 462, 463, 464, 465, 466, 467, 470 |
| T2-46 | `PRG_SUPERVISION_CFC` | `PRG_10_Outputs_LD.instSafetyEmergencyManagement` | 6 | 502, 503, 504, 505, 506, 507 |
| T2-47 | `PRG_SUPERVISION_CFC` | `PRG_10_Outputs_LD.instWinchOutputInterlockM1_LD` | 2 | 215, 216 |
| T2-48 | `PRG_SUPERVISION_CFC` | `PRG_ACQUISITION_CFC.instPosDecoderM3` | 5 | 383, 396, 397, 398, 399 |
| T2-49 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instLoadEstimatorM1` | 1 | 193 |
| T2-50 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instLoadEstimatorM2` | 1 | 266 |
| T2-51 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instSafetyTranslationM3` | 13 | 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 510 |
| T2-52 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM1` | 9 | 226, 228, 236, 249, 250, 251, 252, 253, 508 |
| T2-53 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM2` | 9 | 301, 303, 311, 324, 325, 326, 327, 328, 509 |
| T2-54 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instSpeedMonitorM1` | 6 | 187, 188, 189, 190, 191, 192 |
| T2-55 | `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.instSpeedMonitorM2` | 6 | 260, 261, 262, 263, 264, 265 |
| T2-56 | `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.instTranslationM3` | 7 | 363, 364, 365, 366, 367, 368, 380 |
| T2-57 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instBucket` | 14 | 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 348 |
| T2-58 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instDiveSearch` | 11 | 426, 427, 428, 429, 430, 431, 432, 446, 447, 449, 450 |
| T2-59 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instExtractionSequence` | 10 | 433, 434, 435, 436, 437, 438, 441, 442, 444, 445 |
| T2-60 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instWinchM1` | 16 | 194–207, 238, 239 |
| T2-61 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instWinchM2` | 16 | 267–280, 313, 314 |
| T2-62 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.instWinchSync` | 9 | 353, 354, 355, 356, 357, 358, 359, 473, 474 |
| T2-63 | `PRG_SUPERVISION_CFC` | `PRG_TROUBLESHOOTING_CFC.instPreflight` | 3 | 175, 176, 177 |
| T2-64 | `PRG_SUPERVISION_CFC` | `PRG_TROUBLESHOOTING_CFC.instWinchSymmetry` | 2 | 178, 179 |
| T2-65 | `PRG_TRANSLATION_CFC` | `PRG_01_Diagnostics.instJoystick` | 10 | 47, 48, 50, 82, 92, 95, 108, 113, 114, 115 |
| T2-66 | `PRG_TRANSLATION_CFC` | `PRG_05_Cycle.instCycle` | 2 | 43, 46 |
| T2-67 | `PRG_TRANSLATION_CFC` | `PRG_ACQUISITION_CFC.instPosDecoderM3` | 2 | 157, 158 |
| T2-68 | `PRG_TRANSLATION_CFC` | `PRG_SAFETY_CFC.instSafetyTranslationM3` | 2 | 152, 176 |
| T2-69 | `PRG_TREUILS_CFC` | `PRG_01_Diagnostics.instJoystick` | 21 | 104, 105, 106, 108, 118, 261, 262, 266, 284, 285, 286, 291, 304, 325, 326, 330, 346, 347, 348, 353, 366 |
| T2-70 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instEncoderAbsM1` | 1 | 205 |
| T2-71 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instEncoderAbsM2` | 1 | 206 |
| T2-72 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instEncoderScaleM1` | 8 | 143, 167, 214, 433, 527, 552, 559, 622 |
| T2-73 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instEncoderScaleM2` | 8 | 144, 168, 215, 434, 530, 571, 578, 666 |
| T2-74 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instHomingM1` | 12 | 145, 146, 171, 172, 216, 435, 550, 551, 557, 558, 620, 621 |
| T2-75 | `PRG_TREUILS_CFC` | `PRG_02_Encoders.instHomingM2` | 12 | 145, 146, 171, 172, 217, 436, 569, 570, 576, 577, 664, 665 |
| T2-76 | `PRG_TREUILS_CFC` | `PRG_05_Cycle.instCycle` | 9 | 181, 190, 210, 257, 260, 265, 321, 324, 329 |
| T2-77 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instLoadEstimatorM1` | 1 | 608 |
| T2-78 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instLoadEstimatorM2` | 1 | 652 |
| T2-79 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM1` | 3 | 517, 525, 556 |
| T2-80 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM2` | 3 | 521, 528, 575 |
| T2-81 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instSpeedMonitorM1` | 2 | 610, 611 |
| T2-82 | `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.instSpeedMonitorM2` | 2 | 654, 655 |
| T2-83 | `PRG_TROUBLESHOOTING_CFC` | `PRG_01_Diagnostics.instDiagEthercat` | 2 | 62 (×2) |
| T2-84 | `PRG_TROUBLESHOOTING_CFC` | `PRG_01_Diagnostics.instIhmHeartbeat` | 1 | 85 |
| T2-85 | `PRG_TROUBLESHOOTING_CFC` | `PRG_01_Diagnostics.instJoystick` | 8 | 74, 94, 119, 120, 166, 167, 235, 236 |
| T2-86 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instEncoderAbsM1` | 1 | 113 |
| T2-87 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instEncoderAbsM2` | 1 | 160 |
| T2-88 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instEncoderScaleM1` | 5 | 64 (×2), 69, 90, 114 |
| T2-89 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instEncoderScaleM2` | 5 | 64 (×2), 69, 91, 161 |
| T2-90 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instHomingM1` | 1 | 63 |
| T2-91 | `PRG_TROUBLESHOOTING_CFC` | `PRG_02_Encoders.instHomingM2` | 1 | 63 |
| T2-92 | `PRG_TROUBLESHOOTING_CFC` | `PRG_05_Cycle.instCycle` | 4 | 86, 123, 170, 213 |
| T2-93 | `PRG_TROUBLESHOOTING_CFC` | `PRG_ACQUISITION_CFC.instPosDecoderM3` | 1 | 61 |
| T2-94 | `PRG_TROUBLESHOOTING_CFC` | `PRG_SAFETY_CFC.instSafetyTranslationM3` | 6 | 82, 83, 246, 247, 248, 250 |
| T2-95 | `PRG_TROUBLESHOOTING_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM1` | 8 | 82, 83, 100, 130, 131, 134, 137, 138 |
| T2-96 | `PRG_TROUBLESHOOTING_CFC` | `PRG_SAFETY_CFC.instSafetyWinchM2` | 8 | 82, 83, 101, 177, 178, 181, 184, 185 |
| T2-97 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.instBucket` | 4 | 209, 216, 218, 219 |
| T2-98 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.instWinchM1` | 3 | 103, 140, 141 |
| T2-99 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.instWinchM2` | 3 | 103, 187, 188 |
| T2-100 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.instWinchSync` | 3 | 70, 92, 99 |

### T2bis — Lectures inter-POU de variables `VAR` **locales** (hors instances)

Même mécanisme, cible différente : ce ne sont ni des `VAR_OUTPUT`, ni des instances.
**22 paires · 30 lignes-occurrences.**

| # | POU consommateur | Variable locale lue | Déclaration de la variable | Lignes chez le consommateur |
|---|---|---|---|---|
| T2b-01 | `PRG_ACQUISITION_CFC` | `PRG_TRANSLATION_CFC.M3_Direction_Active` | `PRG_TRANSLATION_CFC.st:21` | 133 |
| T2b-02 | `PRG_ACQUISITION_CFC` | `PRG_TRANSLATION_CFC.M3_SpeedRef_Active` | `PRG_TRANSLATION_CFC.st:22` | 134 |
| T2b-03 | `PRG_ACQUISITION_CFC` | `PRG_TREUILS_CFC.M1_SpeedRef_Active` | `PRG_TREUILS_CFC.st:41` | 119 |
| T2b-04 | `PRG_ACQUISITION_CFC` | `PRG_TREUILS_CFC.M2_SpeedRef_Active` | `PRG_TREUILS_CFC.st:46` | 129 |
| T2b-05 | `PRG_SAFETY_CFC` | `PRG_TRANSLATION_CFC.M3_Direction_Active` | `PRG_TRANSLATION_CFC.st:21` | 217 |
| T2b-06 | `PRG_SAFETY_CFC` | `PRG_TREUILS_CFC.M1_Direction_Active` | `PRG_TREUILS_CFC.st:40` | 50 |
| T2b-07 | `PRG_SAFETY_CFC` | `PRG_TREUILS_CFC.M2_Direction_Active` | `PRG_TREUILS_CFC.st:45` | 111 |
| T2b-08 | `PRG_SUPERVISION_CFC` | `PRG_05_Cycle.CycleMotionPermit` | `PRG_05_Cycle.st:24` | 479 |
| T2b-09 | `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.M3_Direction_Active` | `PRG_TRANSLATION_CFC.st:21` | 422 |
| T2b-10 | `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.M3_PositionSensorTarget` | `PRG_TRANSLATION_CFC.st:24` | 378 |
| T2b-11 | `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.M3_PositioningActive` | `PRG_TRANSLATION_CFC.st:23` | 379 |
| T2b-12 | `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.M3_SpeedRef_Active` | `PRG_TRANSLATION_CFC.st:22` | 423 |
| T2b-13 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.CableLimitAscentM1Reached` | `PRG_TREUILS_CFC.st:60` | 237 |
| T2b-14 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.CableLimitAscentM2Reached` | `PRG_TREUILS_CFC.st:61` | 312 |
| T2b-15 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.ForbidDescentM1_Active` | `PRG_TREUILS_CFC.st:55` | 227 |
| T2b-16 | `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.ForbidDescentM2_Active` | `PRG_TREUILS_CFC.st:56` | 302 |
| T2b-17 | `PRG_TRANSLATION_CFC` | `PRG_TREUILS_CFC.StubMachineEnableN1` | `PRG_TREUILS_CFC.st:19` | 146, 173 |
| T2b-18 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TRANSLATION_CFC.M3_SpeedRef_Active` | `PRG_TRANSLATION_CFC.st:22` | 243 |
| T2b-19 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.M1_Direction_Active` | `PRG_TREUILS_CFC.st:40` | 67, 127 |
| T2b-20 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.M1_SpeedRef_Active` | `PRG_TREUILS_CFC.st:41` | 96, 104, 126, 142 |
| T2b-21 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.M2_Direction_Active` | `PRG_TREUILS_CFC.st:45` | 67, 174 |
| T2b-22 | `PRG_TROUBLESHOOTING_CFC` | `PRG_TREUILS_CFC.M2_SpeedRef_Active` | `PRG_TREUILS_CFC.st:46` | 105, 173, 189 |

### T2ter — Lectures d'instances via la copie `GVL_Global`

`GVL_Global.st:43`–`:45` déclare 3 instances, recopiées depuis `PRG_10_Outputs_LD`
(`PRG_OUTPUTS_LD.st:185`, `:186`, `:187`). **63 lignes-occurrences dont 60 en lecture.**

| POU | Instance GVL lue | Occ. | Lignes |
|---|---|---|---|
| `PRG_SAFETY_CFC` | `GVL_Global.instTranslationOutputInterlock_LD` | 1 | 216 |
| `PRG_SUPERVISION_CFC` | `GVL_Global.instWinchOutputInterlockM1_LD` | 6 | 208, 209, 210, 211, 212, 213 |
| `PRG_SUPERVISION_CFC` | `GVL_Global.instWinchOutputInterlockM2_LD` | 10 | 281–286, 288–291 |
| `PRG_SUPERVISION_CFC` | `GVL_Global.instTranslationOutputInterlock_LD` | 8 | 369–373, 375, 420, 421 |
| `PRG_TROUBLESHOOTING_CFC` | `GVL_Global.instWinchOutputInterlockM1_LD` | 14 | 39, 42, 44–48, 143–146, 148–150 |
| `PRG_TROUBLESHOOTING_CFC` | `GVL_Global.instWinchOutputInterlockM2_LD` | 9 | 40, 43, 190–193, 195–197 |
| `PRG_TROUBLESHOOTING_CFC` | `GVL_Global.instTranslationOutputInterlock_LD` | 12 | 41, 49–51, 252–256, 258, 260, 261 |

**Total franchissements d'encapsulation constatés : T2 (458) + T2bis (30) + T2ter (60 lectures) =
548 lignes-occurrences.**

📌 **Fait #21 — 548 lignes de code franchissent une frontière d'encapsulation POU.**
Référence gelée : `RU_C4_ARCHITECTURE_PROCEDES.md` §2 impose que chaque procédé expose un
contrat public. Ce compteur est la mesure de départ contre laquelle chaque lot M1→M8 se compare.

---

## T3 — Sorties physiques et producteur unique

Extraction : recherche de toute affectation `<symbole> := …` dont le symbole n'est déclaré dans
aucun bloc `VAR*` du POU, sur les 13 `PRG_*.st`, croisée avec les mappings d'E/S de
`PRJ_CODESYS/PROJ_Full_ImportExport/Device.export`.

⚠️ `Device.export` n'est **pas** une référence de contrôle (AGENTS.md) ; il est cité ici
uniquement comme preuve de l'existence d'un mapping matériel, jamais comme preuve de câblage logiciel.

### T3.1 — Sorties écrites par `PRG_10_Outputs_LD` (21 symboles)

| # | Sortie physique | Écriture unique | Source de la valeur | Mapping `Device.export` |
|---|---|---|---|---|
| T3-01 | `M1_RelayFwd_Up_DQ` | `PRG_OUTPUTS_LD.st:105` | `M1RelayFwd` ← `instWinchOutputInterlockM1_LD.RelayFwd` (`:98`) | 1 occ. (`:10291`) |
| T3-02 | `M1_RelayRev_Down_DQ` | `:106` | `instWinchOutputInterlockM1_LD.RelayRev` (`:99`) | 1 occ. |
| T3-03 | `M1_SpeedContactor_1_DQ` | `:107` | `…M1_LD.Contactor1` (`:100`) | 1 occ. |
| T3-04 | `M1_SpeedContactor_2_DQ` | `:108` | `…M1_LD.Contactor2` (`:101`) | 1 occ. |
| T3-05 | `M1_SpeedContactor_3_DQ` | `:109` | `…M1_LD.Contactor3` (`:102`) | 1 occ. |
| T3-06 | `M1_SpeedContactor_4_DQ` | `:110` | `…M1_LD.Contactor4` (`:103`) | 1 occ. |
| T3-07 | `M1_BrakeRelease_RQ` | `:111` | `…M1_LD.BrakeCmd` (`:104`) | 2 occ. |
| T3-08 | `M2_RelayFwd_Up_Close_DQ` | `:120` | `instWinchOutputInterlockM2_LD.RelayFwd` (`:113`) | 1 occ. |
| T3-09 | `M2_RelayRev_Down_Open_DQ` | `:121` | `…M2_LD.RelayRev` (`:114`) | 1 occ. |
| T3-10 | `M2_SpeedContactor_1_DQ` | `:122` | `…M2_LD.Contactor1` (`:115`) | 1 occ. |
| T3-11 | `M2_SpeedContactor_2_DQ` | `:123` | `…M2_LD.Contactor2` (`:116`) | 1 occ. |
| T3-12 | `M2_SpeedContactor_3_DQ` | `:124` | `…M2_LD.Contactor3` (`:117`) | 1 occ. |
| T3-13 | `M2_SpeedContactor_4_DQ` | `:125` | `…M2_LD.Contactor4` (`:118`) | 1 occ. |
| T3-14 | `M2_BrakeRelease_RQ` | `:126` | `…M2_LD.BrakeCmd` (`:119`) | 2 occ. |
| T3-15 | `M3_BrakeRelease_RQ` | `:130` | `instTranslationOutputInterlock_LD.BrakeCmd` (`:129`) | 1 occ. |
| T3-16 | `M3_CommandWord` | `:131` | `instTranslationOutputInterlock_LD.DriveControlWord` | 1 occ. (`:20834`) |
| T3-17 | `M3_SetpointFrequencyHz` | `:132` | `REAL_TO_UINT(instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0)` | 1 occ. |
| T3-18 | `M1_M2_KoboldMeasureEnable_DQ` | `:133` | `PRG_TREUILS_CFC.KoboldContactorCmdArbitrated AND PRG_01_Inputs_LD.PowerContactorEngaged AND PRG_01_Inputs_LD.EmergencyChainClosed` | 1 occ. (`:42890`) |
| T3-19 | `PowerKeepAlive_A_RQ` | `:155` | `instSafetyEmergencyManagement.MaintainA_RQ` | 1 occ. (`:42988`) |
| T3-20 | `PowerKeepAlive_B_RQ` | `:156` | `instSafetyEmergencyManagement.MaintainB_RQ` | 1 occ. |
| T3-21 | `EmergencyArming_RQ` | `:157` | `instSafetyEmergencyManagement.ArmPulse_RQ` | 1 occ. |

**Résultat : chacune de ces 21 sorties a exactement UN site d'affectation dans `CODE/`,
et il est dans `PRG_OUTPUTS_LD.st`.**

⚠️ `PowerKeepAlive_A_RQ` / `_B_RQ` / `EmergencyArming_RQ` sont **à la fois** des `VAR_OUTPUT`
(`PRG_OUTPUTS_LD.st:28`–`:30`) et des symboles mappés E/S (`Device.export:42988`).
`PRG_ACQUISITION_CFC.st:137`–`:139` les relit via le préfixe POU.

### T3.2 — Sorties écrites HORS `PRG_10_Outputs_LD` (6 symboles)

| # | Sortie physique | Écriture unique | Source | Mapping `Device.export` |
|---|---|---|---|---|
| T3-22 | `COD1_PresettTrigCmd` | `PRG_02_Encoders.st:63` | `instEncoderAbsM1.PresetTriggerCmd` | `%QW2` (`:82334`) |
| T3-23 | `COD1_CodeSeqTrigCmd` | `PRG_02_Encoders.st:64` | `instEncoderAbsM1.CodeSeqTriggerCmd` | `%QW3` (`:82783`) |
| T3-24 | `COD1_PresetValue` | `PRG_02_Encoders.st:65` | `instEncoderAbsM1.PresetValueOut` | `%QD4` (`:83648`) |
| T3-25 | `COD2_PresettTrigCmd` | `PRG_02_Encoders.st:113` | `instEncoderAbsM2.PresetTriggerCmd` | mappé (`:95422`), adresse non prouvée |
| T3-26 | `COD2_CodeSeqTrigCmd` | `PRG_02_Encoders.st:114` | `instEncoderAbsM2.CodeSeqTriggerCmd` | mappé (`:95870`), adresse non prouvée |
| T3-27 | `COD2_PresetValue` | `PRG_02_Encoders.st:115` | `instEncoderAbsM2.PresetValueOut` | mappé (`:96734`), adresse non prouvée |

### T3.3 — Conclusion factuelle T3

| Affirmation | Verdict prouvé | Preuve |
|---|---|---|
| Chaque sortie physique a **un producteur unique** | ✅ **VRAI** — 27/27 symboles ont exactement 1 site d'affectation dans `CODE/` | recherche exhaustive `<symbole> :=` sur `CODE/**/*.st` |
| `PRG_10_Outputs_LD` est le **seul** POU écrivant des sorties physiques | ❌ **FAUX** | `PRG_02_Encoders.st:63`, `:64`, `:65`, `:113`, `:114`, `:115` écrivent 6 sorties codeurs mappées `%Q*` |
| `PRG_10_Outputs_LD` est le seul producteur des commandes **moteur / frein / variateur** (M1, M2, M3, Kobold, AU) | ✅ **VRAI** — 21/21 | T3.1 |
| `PRG_TROUBLESHOOTING_CFC` écrit une sortie physique | ❌ **FAUX** (= il n'en écrit aucune) | 0 affectation d'un symbole non déclaré autre que `GVL_Troubleshooting.*` |

📌 **Fait #17 — la règle « `Outputs` est l'unique producteur de chaque commande physique »
(`RU_C4` §4) est vérifiée pour les 21 commandes d'actionneurs, mais 6 sorties de configuration
codeur (`COD1/COD2 Preset/CodeSeq`) sont écrites par `PRG_02_Encoders`.** Ce sont des commandes de
paramétrage EtherCAT vers les codeurs, pas des commandes de mouvement. Le constat est ici factuel ;
aucune qualification de conformité n'est faite dans ce document.

---

# PARTIE C — Compteurs de référence pour la vérification `must_survive`

Ces compteurs sont la **valeur de référence gelée**. Tout lot M1→M8 doit pouvoir expliquer
chaque écart.

## C1 — Instances FB par POU (total 78)

| POU | Instances |
|---|---|
| `PRG_01_Inputs_LD` | 19 |
| `PRG_ACQUISITION_CFC` | 12 |
| `PRG_02_Encoders` | 10 |
| `PRG_SUPERVISION_CFC` | 9 |
| `PRG_SAFETY_CFC` | 7 |
| `PRG_TREUILS_CFC` | 7 |
| `PRG_01_Diagnostics` | 4 |
| `PRG_10_Outputs_LD` | 4 |
| `PRG_TROUBLESHOOTING_CFC` | 3 |
| `PRG_05_Cycle` | 1 |
| `PRG_MODES_CFC` | 1 |
| `PRG_TRANSLATION_CFC` | 1 |
| `PRG_AUXILIARY_CFC` | 0 |
| **TOTAL** | **78** |

+ 3 instances déclarées dans `GVL_Global.st:43`–`:45` (copies).

## C2 — `VAR_OUTPUT` par POU (total 72)

`PRG_01_Inputs_LD` a en plus **1 `VAR_INPUT`** (`HwIn`, `:13`), non compté ici.

| POU | `VAR_OUTPUT` | Dont sans consommateur inter-POU |
|---|---|---|
| `PRG_01_Inputs_LD` | 22 | 5 (`TranslationPos*`) |
| `PRG_10_Outputs_LD` | 23 | 20 |
| `PRG_ACQUISITION_CFC` | 11 | 2 (`HwReal`, `HwSim`) |
| `PRG_02_Encoders` | 9 | 2 (`EncoderFaultPresentM1/M2`) |
| `PRG_TREUILS_CFC` | 3 | 0 |
| `PRG_AUXILIARY_CFC` | 1 | 0 |
| `PRG_MODES_CFC` | 1 | 0 |
| `PRG_SUPERVISION_CFC` | 1 | 0 |
| `PRG_TRANSLATION_CFC` | 1 | 0 |
| `PRG_01_Diagnostics` | 0 | — |
| `PRG_05_Cycle` | 0 | — |
| `PRG_SAFETY_CFC` | 0 | — |
| `PRG_TROUBLESHOOTING_CFC` | 0 | — |
| **TOTAL** | **72** | **29** |

📌 **Fait #18 — 4 POU sur 13 n'ont aucun `VAR_OUTPUT`** : `PRG_01_Diagnostics`, `PRG_05_Cycle`,
`PRG_SAFETY_CFC`, `PRG_TROUBLESHOOTING_CFC`. Trois d'entre eux (les 3 premiers) sont pourtant
lus par 4 à 8 POU — exclusivement via leurs instances internes (T2).

## C3 — Graphe de dépendances inter-POU (lignes-occurrences émises)

Ligne = POU qui **lit** ; colonne = POU **producteur**.

Une cellule = nombre de **lignes-occurrences distinctes** (une ligne lisant 2 symboles du même
producteur compte 2 ; une ligne lisant 2 fois le même symbole compte 1).

| Lecteur ↓ / Producteur → | ACQ | INP | D01 | E02 | AUX | MOD | SAF | CYC | TRE | TRA | OUT | SUP | TRB | **TOT** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `PRG_ACQUISITION_CFC` | — | 0 | 4 | 4 | 0 | 11 | 0 | 0 | 5 | 2 | 3 | 5 | 0 | **34** |
| `PRG_01_Inputs_LD` | 0 | — | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| `PRG_01_Diagnostics` | 8 | 1 | — | 0 | 0 | 1 | 0 | 0 | 3 | 0 | 0 | 3 | 0 | **16** |
| `PRG_02_Encoders` | 8 | 12 | 2 | — | 0 | 12 | 0 | 0 | 0 | 0 | 0 | 6 | 0 | **40** |
| `PRG_AUXILIARY_CFC` | 2 | 0 | 0 | 0 | — | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **2** |
| `PRG_MODES_CFC` | 0 | 1 | 0 | 1 | 0 | — | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **2** |
| `PRG_SAFETY_CFC` | 5 | 24 | 13 | 28 | 0 | 17 | — | 0 | 13 | 1 | 0 | 7 | 0 | **108** |
| `PRG_05_Cycle` | 4 | 2 | 3 | 4 | 0 | 1 | 0 | — | 4 | 2 | 0 | 0 | 0 | **20** |
| `PRG_TREUILS_CFC` | 0 | 18 | 21 | 44 | 0 | 34 | 12 | 9 | — | 0 | 0 | 9 | 0 | **147** |
| `PRG_TRANSLATION_CFC` | 9 | 4 | 10 | 0 | 0 | 6 | 2 | 2 | 2 | — | 0 | 2 | 0 | **37** |
| `PRG_10_Outputs_LD` | 0 | 4 | 0 | 0 | 0 | 0 | 3 | 0 | 29 | 8 | — | 1 | 0 | **45** |
| `PRG_SUPERVISION_CFC` | 14 | 11 | 25 | 47 | 1 | 8 | 45 | 9 | 80 | 11 | 8 | — | 5 | **264** |
| `PRG_TROUBLESHOOTING_CFC` | 9 | 38 | 11 | 14 | 0 | 5 | 22 | 4 | 24 | 1 | 0 | 0 | — | **128** |
| **TOT produit** | **59** | **115** | **89** | **142** | **1** | **95** | **84** | **24** | **160** | **25** | **11** | **33** | **5** | **843** |

📌 **Fait #20 — le POU le plus lu est `PRG_TREUILS_CFC` (160), le plus lecteur est
`PRG_SUPERVISION_CFC` (264).** `PRG_01_Inputs_LD` est le seul POU qui ne lit **rien** (ligne à 0).

## C4 — Cycles inter-POU prouvés (lecture mutuelle A→B et B→A)

| Paire | A lit B | B lit A |
|---|---|---|
| `PRG_ACQUISITION_CFC` ↔ `PRG_01_Diagnostics` | `PRG_ACQUISITION_CFC.st:195,196,220,267` | `PRG_01_Diagnostics.st:33–37,86–88` |
| `PRG_ACQUISITION_CFC` ↔ `PRG_02_Encoders` | `PRG_ACQUISITION_CFC.st:120,121,130,131` | `PRG_02_Encoders.st:47,48,57,58,107,108,188,190` |
| `PRG_ACQUISITION_CFC` ↔ `PRG_MODES_CFC` | `PRG_ACQUISITION_CFC.st:191,216,…` | *(non — `PRG_MODES_CFC` ne lit pas ACQ)* |
| `PRG_ACQUISITION_CFC` ↔ `PRG_TREUILS_CFC` | `PRG_ACQUISITION_CFC.st:119,129,192,193,194` | *(non — `PRG_TREUILS_CFC` ne lit pas ACQ)* |
| `PRG_ACQUISITION_CFC` ↔ `PRG_TRANSLATION_CFC` | `PRG_ACQUISITION_CFC.st:133,134` | `PRG_TRANSLATION_CFC.st:136–139,156–160` |
| `PRG_ACQUISITION_CFC` ↔ `PRG_10_Outputs_LD` | `PRG_ACQUISITION_CFC.st:137,138,139` | *(non — `PRG_10_Outputs_LD` ne lit pas ACQ)* |
| `PRG_ACQUISITION_CFC` ↔ `PRG_SUPERVISION_CFC` | `PRG_ACQUISITION_CFC.st:189,214,227,261,274` | `PRG_SUPERVISION_CFC.st:377,383,390–399,416,417,419` |
| `PRG_01_Diagnostics` ↔ `PRG_TREUILS_CFC` | `PRG_01_Diagnostics.st:79,80,81` | `PRG_TREUILS_CFC.st:104,105,106,108,118,261,…` (21) |
| `PRG_01_Diagnostics` ↔ `PRG_SUPERVISION_CFC` | `PRG_01_Diagnostics.st:43,53,77` | `PRG_SUPERVISION_CFC.st:381,477,…` (25) |
| `PRG_02_Encoders` ↔ `PRG_SUPERVISION_CFC` | `PRG_02_Encoders.st:53,70,103,120,153,166` | `PRG_SUPERVISION_CFC.st:154,155,174,186,…` (47) |
| `PRG_SAFETY_CFC` ↔ `PRG_TREUILS_CFC` | `PRG_SAFETY_CFC.st:50,51,62,67,68,111,112,127,128,177,188` | `PRG_TREUILS_CFC.st:517,521,525,528,556,575,608,610,611,652,654,655` |
| `PRG_SAFETY_CFC` ↔ `PRG_TRANSLATION_CFC` | `PRG_SAFETY_CFC.st:217` | `PRG_TRANSLATION_CFC.st:152,176` |
| `PRG_SAFETY_CFC` ↔ `PRG_SUPERVISION_CFC` | `PRG_SAFETY_CFC.st:33,94,152,162,174,185,203` | `PRG_SUPERVISION_CFC.st:187–193,226,…` (45) |
| `PRG_SAFETY_CFC` ↔ `PRG_10_Outputs_LD` | *(via `GVL_Global`, `PRG_SAFETY_CFC.st:216`)* | `PRG_OUTPUTS_LD.st:141` |
| `PRG_05_Cycle` ↔ `PRG_TREUILS_CFC` | `PRG_05_Cycle.st:64,65,83,84` | `PRG_TREUILS_CFC.st:181,190,210,257,260,265,321,324,329` |
| `PRG_05_Cycle` ↔ `PRG_TRANSLATION_CFC` | `PRG_05_Cycle.st:79,80` | `PRG_TRANSLATION_CFC.st:43,46` |
| `PRG_05_Cycle` ↔ `PRG_SUPERVISION_CFC` | *(non — `PRG_05_Cycle` ne lit pas SUP)* | `PRG_SUPERVISION_CFC.st:461–470,479` |
| `PRG_TREUILS_CFC` ↔ `PRG_SUPERVISION_CFC` | `PRG_TREUILS_CFC.st:126,136,157,207,430,594,639,681,696` | `PRG_SUPERVISION_CFC.st:194–207,227,…` (80) |
| `PRG_TRANSLATION_CFC` ↔ `PRG_SUPERVISION_CFC` | `PRG_TRANSLATION_CFC.st:148,174` | `PRG_SUPERVISION_CFC.st:363–380,422,423` |
| `PRG_TRANSLATION_CFC` ↔ `PRG_TREUILS_CFC` | `PRG_TRANSLATION_CFC.st:146,173` | *(non)* |
| `PRG_10_Outputs_LD` ↔ `PRG_SUPERVISION_CFC` | `PRG_OUTPUTS_LD.st:146` | `PRG_SUPERVISION_CFC.st:215,216,502–507` |
| `PRG_TROUBLESHOOTING_CFC` ↔ `PRG_SUPERVISION_CFC` | *(non — TRB ne lit pas SUP)* | `PRG_SUPERVISION_CFC.st:175–179` |

**Cycles bidirectionnels prouvés : 14.**

📌 **Fait #19 — les 4 cycles listés par `RU_C4_ARCHITECTURE_PROCEDES.md` §1 sont confirmés**
(Safety↔Treuils, Safety↔Translation, Acquisition↔Diagnostics, Acquisition↔Encoders).
**10 cycles supplémentaires** existent, dont 8 impliquent `PRG_SUPERVISION_CFC` via
`FaultMachineReset_IHM`.

---

# PARTIE D — Constats à faire trancher ailleurs (aucune décision prise ici)

| # | Constat | Preuve | Statut |
|---|---|---|---|
| D1 | 5 `VAR_OUTPUT` de `PRG_01_Inputs_LD` (`TranslationPos*`) n'ont aucun consommateur | `PRG_01_Inputs_LD.st:37`–`:41` ; 0 occurrence `PRG_01_Inputs_LD.TranslationPos*` | fait |
| D2 | `PRG_01_Inputs_LD.HwIn` (`:13`) n'a aucun site d'affectation dans `CODE/` | 0 occurrence `PRG_01_Inputs_LD.HwIn`, 0 appel `PRG_01_Inputs_LD(` | **non prouvé** hors `CODE/` |
| D3 | `HwReal` et `HwSim` (`PRG_ACQUISITION_CFC.st:15`, `:16`) n'ont aucun consommateur inter-POU | 0 occurrence | fait |
| D4 | `EncoderFaultPresentM1/M2` (`PRG_02_Encoders.st:13`, `:14`) sans consommateur | 0 occurrence | fait |
| D5 | `RedundancyTestFailed`, `EmergencyArmingFailed` (`PRG_OUTPUTS_LD.st:34`, `:35`) sans consommateur ni recopie GVL | 0 occurrence ; équivalents relus sur l'instance `PRG_SUPERVISION_CFC.st:506`, `:507` | fait |
| D6 | 11 instances de `PRG_ACQUISITION_CFC` sur 12 ne sont lues par personne | 0 occurrence `PRG_ACQUISITION_CFC.inst<X>` sauf `instPosDecoderM3` | fait |
| D7 | Les 2 jeux d'instances dupliquées n'ont pas le même câblage d'entrée | T1bis, Fait #16 | fait |
| D8 | 6 sorties physiques codeurs écrites hors `PRG_10_Outputs_LD` | `PRG_02_Encoders.st:63`–`:65`, `:113`–`:115` | fait |
| D9 | 3 instances d'interlock final existent en double (POU + `GVL_Global`) | `PRG_OUTPUTS_LD.st:41`–`:43` vs `GVL_Global.st:43`–`:45`, recopie `:185`–`:187` | fait |
| D10 | `PRG_SUPERVISION_CFC` (position 9) lit `PRG_TROUBLESHOOTING_CFC` (position 11) | `PRG_SUPERVISION_CFC.st:175`–`:179` | fait |
| D11 | `PRG_MODES_CFC` et `PRG_SAFETY_CFC` déclarent tous deux la position 3 | `PRG_MODES_CFC.st:4`, `PRG_SAFETY_CFC.st:4` | fait |
| D12 | Ordre réel d'exécution MainTask | aucun fichier de `CODE/` ne le porte | **non prouvé** |
| D13 | `PRG_MODES_CFC.st` contient 2 `END_PROGRAM` (`:35`, `:37`) ; 11 fichiers n'en contiennent aucun | comptage `END_PROGRAM` | fait |
| D14 | `PRG_OUTPUTS_LD.st` déclare `PROGRAM PRG_10_Outputs_LD` (nom fichier ≠ nom POU) | `PRG_OUTPUTS_LD.st:10` | fait |
| D15 | `PRG_SAFETY_CFC.st:216` lit une instance interne de `PRG_10_Outputs_LD` via `GVL_Global` | `GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd` | fait — déjà signalé par `PLAN_EXECUTION_MIGRATION_7POU.md` §4 M5 |
| D16 | `PRG_TRANSLATION_CFC` lit `PRG_TREUILS_CFC.StubMachineEnableN1`, une variable `VAR` locale nommée « Stub » | `PRG_TRANSLATION_CFC.st:146`, `:173` ; décl. `PRG_TREUILS_CFC.st:19` | fait |
| D17 | Adresses `%Q` de `COD2_*` non extractibles de `Device.export` par la même méthode que `COD1_*` | `Device.export:95422`, `:95870`, `:96734` sans `IecAddress` associé dans la fenêtre analysée | **non prouvé** |

---

## Annexe — Commandes de reproduction

```bash
# Instances déclarées + doublons (T1)
cd CODE/MAIN && grep -n "^\s*inst[A-Za-z0-9_]*\s*:\s*[A-Za-z0-9_]*\s*;" PRG_*.st

# Lectures d'instances internes inter-POU (T2)
cd CODE/MAIN && grep -n -o "PRG_[A-Za-z0-9_]*\.inst[A-Za-z0-9_]*" PRG_*.st

# Producteur unique des sorties physiques (T3)
grep -rn -E "\b[A-Za-z0-9_]*(_DQ|_RQ|CommandWord|SetpointFrequencyHz|PresetValue|TrigCmd)\s*:=" --include=*.st CODE/

# Gate documentaire
python TOOLS/AGENT_WORKFLOW/scripts/check_doc_links.py
```

**Gate exécuté à la clôture de cet audit :**

```
Doc links check: PASS (0 erreur(s), 0 avertissement(s))
```

---

*Fin de l'audit M0. Aucune modification de `CODE/` ni de `TOOLS/`. Aucun commit.*
