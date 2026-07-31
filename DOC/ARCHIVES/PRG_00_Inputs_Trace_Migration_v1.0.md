# 🗂️ Trace migration — `PRG_00_Inputs` legacy → `PRG_02_ACQUISITION_CFC`

> Version : v1.0
> Date : 2026-08-01
> Source : `CODE/MAIN/PRG_00_Inputs.st` (dernière version avant refactor)
> Statut : Archivé · ne pas réutiliser comme source active

---

## 🎯 Identité du POU

| Champ | Valeur |
|---|---|
| Nom | `PRG_00_Inputs` |
| Langage | ST (Structured Text) |
| Rôle | Acquisition & conditionnement : matériel → `HwReal` → `FB_SimBench` → `HwIn` → `FB_Input` → sorties publiques. |
| Position d'exécution | 0 dans la `MainTask` historique (`PRG_00` → `PRG_10`). |

---

## 📤 Sorties publiques (`VAR_OUTPUT`)

29 sorties publiques.

| # | Sortie | Type / DUT | Rôle court |
|---|---|---|---|
| 1 | `HwReal` | `ST_HardwareImage` | Image matérielle brute (device → PDO). |
| 2 | `HwSim` | `ST_HardwareImage` | Image produite par le banc (observation uniquement). |
| 3 | `HwIn` | `ST_HardwareImage` | Image consommée par tout le programme (réel ou simulé par domaine). |
| 4 | `WinchInputSourceChanged` | `BOOL` | Pulse atomique : bascule réel ↔ simulé du domaine Winch. |
| 5 | `PowerContactorEngaged` | `BOOL` | `TRUE` = contacteur puissance engagé (portail maître). |
| 6 | `EmergencyChainClosed` | `BOOL` | `TRUE` = boucle AU fermée/saine. |
| 7 | `TopPositionSensor` | `BOOL` | `TRUE` = fin de course haut libre. |
| 8 | `SlackCableSwitch` | `BOOL` | `TRUE` = câble M2 tendu. |
| 9 | `KoboldContactFond` | `BOOL` | `TRUE` = contact fond Kobold détecté. |
| 10 | `PhaseRotationOk` | `BOOL` | `TRUE` = rotation phases correcte. |
| 11 | `BrakeThermalFeedback` | `BOOL` | `TRUE` = thermique freins M1/M2/M3 OK. |
| 12 | `M1FwdRevSpeedFeedbackOff` | `BOOL` | `TRUE` = tous contacteurs M1 retombés. |
| 13 | `M1ThermalFeedback` | `BOOL` | `TRUE` = thermique moteur M1 OK. |
| 14 | `M1BrakeFeedback` | `BOOL` | `TRUE` = frein M1 serré (état sûr). |
| 15 | `M1BrakeCommandOpenConfirmed` | `BOOL` | Contacteur desserrage M1 confirmé (`NOT M1BrakeFeedback`). |
| 16 | `M2FwdRevSpeedFeedbackOff` | `BOOL` | `TRUE` = tous contacteurs M2 retombés. |
| 17 | `M2ThermalFeedback` | `BOOL` | `TRUE` = thermique moteur M2 OK. |
| 18 | `M2BrakeFeedback` | `BOOL` | `TRUE` = frein M2 serré (état sûr). |
| 19 | `M2BrakeCommandOpenConfirmed` | `BOOL` | Contacteur desserrage M2 confirmé (`NOT M2BrakeFeedback`). |
| 20 | `TranslationPosTremie` | `BOOL` | `TRUE` = translation en position Trémie. |
| 21 | `TranslationPosPV` | `BOOL` | `TRUE` = zone pré-ralentissement PV atteinte. |
| 22 | `TranslationPosP2` | `BOOL` | `TRUE` = translation en position P2. |
| 23 | `TranslationPosP1` | `BOOL` | `TRUE` = translation en position P1. |
| 24 | `TranslationPosMaintenance` | `BOOL` | `TRUE` = translation en position Maintenance. |
| 25 | `M3BrakeFeedback` | `BOOL` | `TRUE` = frein M3 serré (état sûr). |
| 26 | `M3BrakeCommandOpenConfirmed` | `BOOL` | Contacteur desserrage M3 confirmé (`NOT M3BrakeFeedback`). |
| 27 | `instPositionDecoder` | `FB_Translation_PositionDecoder` | Instance locale de décodage 5 capteurs M3. |
| 28 | `M3_StatusWord_Filtered` | `WORD` | Recopie du `StatusWord` AC600 M3. |
| 29 | `M3_ActualFrequencyHz_Filtered` | `UINT` | Recopie de la fréquence mesurée AC600 M3. |

---

## 🔩 Instances `FB_Input` (19)

| # | Instance | Signal brut (`HwIn`) | Sortie | Polarité | Filtre | Rôle / consommateur cible |
|---|---|---|---|---|---|---|
| 1 | `instPowerContactorEngaged` | `.Machine.PowerContactorEngaged_DI` | `PowerContactorEngaged` | NO | 20 ms | Portail maître — PRG_01..11, FB_Safety_*, FB_Cycle. |
| 2 | `instEmergencyChainClosed` | `.Machine.EmergencyChainClosed_DI` | `EmergencyChainClosed` | NC | 20 ms | Précondition armement — PRG_03_Safety, PRG_06/11. |
| 3 | `instSlackCableSwitch` | `.Winch.M2_TensionedCable_DI` | `SlackCableSwitch` | NC | 20 ms | ForbidDescent M2 — PRG_03_Safety, PRG_11. |
| 4 | `instKoboldContactFond` | `.Machine.M1_M2_KoboldContactFond_DI` | `KoboldContactFond` | NO | 20 ms | Cycle figé `BOTTOM_TOUCH_WAIT` — PRG_05_Cycle, PRG_09. |
| 5 | `instTopPositionSensor` | `.Winch.M1M2_TopPositionFree_DI` | `TopPositionSensor` | NC | 20 ms | ForbidAscent M1/M2 — PRG_02_Encoders, PRG_03_Safety. |
| 6 | `instCtrlPhaseRotation` | `.Machine.PhaseRotationOk_DI` | `PhaseRotationOk` | NC | 20 ms | SafeStop 3 axes — PRG_03_Safety. |
| 7 | `instBrakeThermalFeedback` | `.Machine.BrakeThermalOk_DI` | `BrakeThermalFeedback` | NC | 20 ms | SafeStop + PowerCutOff — PRG_03_Safety. |
| 8 | `instM1FwdRevSpeedFeedbackOff` | `.Winch.M1_ContactorsReleased_DI` | `M1FwdRevSpeedFeedbackOff` | NO | 20 ms | Méca A/C collage contacteur — PRG_02_Encoders, PRG_03_Safety. |
| 9 | `instM1Thermal` | `.Winch.M1_ThermalOk_DI` | `M1ThermalFeedback` | NC | 20 ms | SafeStop M1 — PRG_03_Safety, PRG_09_Supervision. |
| 10 | `instM1BrakeFeedback` | `.Winch.M1_BrakeIsOpen_DI` | `M1BrakeFeedback` | Inversée via `BrakeFeedbackInvertLogic` | 20 ms | Frein normalisé (TRUE=serré) — PRG_02/03. |
| 11 | `instM2FwdRevSpeedFeedbackOff` | `.Winch.M2_ContactorsReleased_DI` | `M2FwdRevSpeedFeedbackOff` | NO | 20 ms | Méca A/C collage contacteur — PRG_02_Encoders, PRG_03_Safety. |
| 12 | `instM2Thermal` | `.Winch.M2_ThermalOk_DI` | `M2ThermalFeedback` | NC | 20 ms | SafeStop M2 — PRG_03_Safety, PRG_09_Supervision. |
| 13 | `instM2BrakeFeedback` | `.Winch.M2_BrakeIsOpen_DI` | `M2BrakeFeedback` | Inversée via `BrakeFeedbackInvertLogic` | 20 ms | Frein normalisé (TRUE=serré) — PRG_02/03. |
| 14 | `instTranslationPosTremie` | `.Translation.M3_PosTremie_DI` | `TranslationPosTremie` | NO | 20 ms | Décodage M3 — PRG_05_Cycle, PRG_09_Supervision. |
| 15 | `instTranslationPosPV` | `.Translation.M3_PosPV_DI` | `TranslationPosPV` | NO | 20 ms | Ralentissement Trémie — PRG_09_Supervision. |
| 16 | `instTranslationPosP2` | `.Translation.M3_PosP2_DI` | `TranslationPosP2` | NO | 20 ms | Décodage M3 — PRG_05_Cycle, PRG_09_Supervision. |
| 17 | `instTranslationPosP1` | `.Translation.M3_PosP1_DI` | `TranslationPosP1` | NO | 20 ms | Décodage M3 — PRG_05_Cycle, PRG_09_Supervision. |
| 18 | `instTranslationPosMaintenance` | `.Translation.M3_PosMaintenance_DI` | `TranslationPosMaintenance` | NO | 20 ms | Décodage M3 — PRG_05_Cycle, PRG_09_Supervision. |
| 19 | `instM3BrakeFeedback` | `.Translation.M3_BrakeIsOpen_DI` | `M3BrakeFeedback` | Inversée via `BrakeFeedbackInvertLogic` | 20 ms | Frein M3 normalisé — PRG_03_Safety, PRG_09_Supervision. |

> 📝 Toutes les instances `FB_Input` reçoivent `FilterTime := T#20MS`, sauf les 3 retours frein qui ajoutent `InvertLogic := BrakeFeedbackInvertLogic`.

---

## 🧱 Structures internes

| Nom | Type | Rôle |
|---|---|---|
| `HwReal` | `ST_HardwareImage` | Copie one-to-one des E/S brutes device / PDO / méthodes `.GetDeviceState()` / `.GetBusState()`. |
| `HwSim` | `ST_HardwareImage` | Récupération des champs `Winch`/`Translation`/`Operator`/`Machine` produits par `FB_SimBench`. |
| `HwIn` | `ST_HardwareImage` | Image aiguillée : `HwReal` OU `HwSim` selon le domaine (`Winch`/`Translation`/`Operator`/`Machine`). |
| `instSimBench` | `FB_SimBench` | Banc de simulation : remplace le réel par domaine entier quand `GVL_Simulation.SimulationModeActive` et le flag de domaine sont TRUE. |

### Carte des sections du corps ST

```text
§0  MATÉRIEL ──► HwReal       (acquisition brute unique)
§0bis HwReal/SimBench ──► HwIn (aiguillage simulation par domaine)
§1  HwIn ──► FB_Input ──► VAR_OUTPUT (filtre + polarité)
§2  Décodage mot capteurs M3 (FB_Translation_PositionDecoder)
```

---

## ✍️ Écritures directes dans `GVL_IHM`

20 écritures dans le bloc de purge boot (lignes historiques ~148–177).

| # | Cible `GVL_IHM` | Valeur forcée | Motivation |
|---|---|---|---|
| 1 | `.HmiInitDone` | `FALSE` | Marqueur de purge actif. |
| 2 | `.Modes.Cmd.BtnEmergencyArming` | `FALSE` | Acquittement armement remis à zéro (neutre). |
| 3 | `.M1TreuilRetenue.Cmd.BtnHome` | `FALSE` | Commande homing M1 purgée. |
| 4 | `.M1TreuilRetenue.Bypass.EncoderFault` | `FALSE` | Bypass codeur M1 purgé. |
| 5 | `.M1TreuilRetenue.Cmd.BtnConfirmCoherence` | `FALSE` | Confirm coherence M1 purgé. |
| 6 | `.M2TreuilBenne.Cmd.BtnHome` | `FALSE` | Commande homing M2 purgée. |
| 7 | `.M2TreuilBenne.Bypass.EncoderFault` | `FALSE` | Bypass codeur M2 purgé. |
| 8 | `.M2TreuilBenne.Cmd.BtnConfirmCoherence` | `FALSE` | Confirm coherence M2 purgé. |
| 9 | `.M2TreuilBenne.Bucket.Cmd.BtnOpen` | `FALSE` | Commande ouverture benne purgée. |
| 10 | `.M2TreuilBenne.Bucket.Cmd.BtnClose` | `FALSE` | Commande fermeture benne purgée. |
| 11 | `.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos` | `FALSE` | Confirmation ouverture purgée. |
| 12 | `.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos` | `FALSE` | Confirmation fermeture purgée. |
| 13 | `.Cycle.Cmd.BtnStart` | `FALSE` | Démarrage cycle purgé. |
| 14 | `.Cycle.Cmd.BtnPause` | `FALSE` | Pause cycle purgée. |
| 15 | `.Cycle.Cmd.BtnAbort` | `FALSE` | Arrêt cycle purgé. |
| 16 | `.TranslationM3.Cmd.SelPositioning` | `FALSE` | Mode positionnement M3 purgé. |
| 17 | `.TranslationM3.Cmd.BtnFwd` | `FALSE` | Marche avant M3 purgée. |
| 18 | `.TranslationM3.Cmd.BtnRev` | `FALSE` | Marche arrière M3 purgée. |
| 19 | `.JOY1Joystick.Cmd.BtnCalibrate` | `FALSE` | Calibration joystick purgée. |
| 20 | `.HmiInitDone` | `TRUE` | Fin de la purge initiale. |

> ⚠️ État neutre sûr maintenu (`BtnEmergencyCutOff`, inhibitions globales) volontairement **non** effacé.

### Lectures `GVL_Global` (pas d'écriture)

`PRG_00_Inputs` ne **écrit jamais** dans `GVL_Global`. Il lit exclusivement les commandes actionneur et consignes nécessaires au banc de simulation : `M1RelayFwd`/`M1RelayRev`, `M1SpeedContactor1..4`, `M1BrakeCmd`, `M2RelayFwd`/`M2RelayRev`, `M2SpeedContactor1..4`, `M2BrakeCmd`, `TranslationBrakeCmd`.

---

## 🔗 Consommateurs / dépendances externes identifiés dans `PRG_00_Inputs.st`

Ce POU lit des données produites par d'autres POUs (principalement pour alimenter `FB_SimBench`).

| POU / Instance externe | Type d'usage | Pourquoi dans `PRG_00_Inputs` |
|---|---|---|
| `PRG_02_Encoders.instEncoderAbsM1` | Lecture `.PresetTriggerCmd`, `.PresetValueOut` | Simulation position codeur M1. |
| `PRG_02_Encoders.instEncoderAbsM2` | Lecture `.PresetTriggerCmd`, `.PresetValueOut` | Simulation position codeur M2. |
| `PRG_06_WinchControl.M1_SpeedRef_Active` | Lecture | Simulation consigne M1. |
| `PRG_06_WinchControl.M2_SpeedRef_Active` | Lecture | Simulation consigne M2. |
| `PRG_07_TranslationControl.M3_Direction_Active` | Lecture | Simulation sens M3. |
| `PRG_07_TranslationControl.M3_SpeedRef_Active` | Lecture | Simulation consigne M3. |
| `COD1_CODEUR.GetDeviceState()` | Appel méthode | Diagnostic device codeur M1. |
| `COD2_CODEUR.GetDeviceState()` | Appel méthode | Diagnostic device codeur M2. |
| `AC600_ECAT_Drive.GetDeviceState()` | Appel méthode | Diagnostic variateur M3. |
| `CANbus.GetBusState()` | Appel méthode | Diagnostic bus joystick. |
| `GVL_Simulation.*` | Lecture 25+ flags | Configuration du banc de simulation. |
| `GVL_Global.*` | Lecture commandes | Données de rétroaction simulation. |

> 📌 Aucune instance locale de `FB_Joystick`, `FB_Encoder_*` ou `FB_Winch` n'est déclarée dans ce POU ; ces FB complexes sont appelés dans `PRG_02_ACQUISITION_CFC.xml` (anciennement `PRG_ACQUISITION_CFC.xml`), pas ici.

---

## 📦 Fichier d'archive

| Fichier | Destination |
|---|---|
| `CODE/MAIN/PRG_00_Inputs.st` | `ARCHIVES/CODE/PRG_00_Inputs_v1.0.st` |

---

## 🗑️ Pourquoi archiver

- Refactor total de l'architecture acquisition : remplacement par `PRG_02_ACQUISITION_CFC` (CFC) + `PRG_01_INPUTS_LD` (Ladder).
- Objectif : séparer **device/simulation/FB complexes** (CFC) de **l'affichage TOR qualifié** (Ladder).
- `PRG_00_Inputs` mélangeait acquisition ST, simulation, filtrage TOR et purge IHM dans un seul POU ; il n'est plus la frontière cible.

---

## 📚 Documents liés

- `AF_Partie-02_Architecture_Programme_v3.0.md` §4 : ordre d'exécution cible (`PRG_02_ACQUISITION_CFC`).
- `AF_Partie-06_Acquisition_Qualification_IO_v2.0.md` : contrats de la nouvelle frontière acquisition.
- `PLAN_TASK_v1.0.md` : T97 — refonte architecture acquisition.
