# 📋 RAPPORT DE RÉALISATION — Lot L5 : Frontière Unique `HwIn` et Lisibilité `PRG_00`

> 🤖 **Auteur** : Agent d'implémentation externe  
> 📅 **Date** : 2026-07-27  
> 🏷️ **Version** : v1.0  
> ⏱️ **Périmètre** : Lot L5 (Frontière unique matérielle `HwIn` + Refonte lisibilité `PRG_00_Inputs`)

---

## 1. 📑 Synthèse des travaux réalisés

Le lot L5 a été réalisé en conformité stricte avec la fiche de tâche [`TASK_L5_Frontiere_Unique_et_Lisibilite_v1.0.md`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/AUDITS/PreLivraison/TASKS/TASK_L5_Frontiere_Unique_et_Lisibilite_v1.0.md) :

1. **Création des 5 structures d'image matérielle** dans `CODE/SUPERVISION/_TYPES/` :
   - [`ST_HwWinch.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/_TYPES/ST_HwWinch.st)
   - [`ST_HwTranslation.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/_TYPES/ST_HwTranslation.st)
   - [`ST_HwOperator.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/_TYPES/ST_HwOperator.st)
   - [`ST_HwMachine.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/_TYPES/ST_HwMachine.st)
   - [`ST_HardwareImage.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/_TYPES/ST_HardwareImage.st)
2. **Réécriture complète de `PRG_00_Inputs.st`** :
   - **§0** : Remplissage unique et centralisé de `HwReal` depuis toutes les entrées physiques directes (`_DI`, `_ANA`, `COD*`, `M3_*`, `GetBusState()`, `GetDeviceState()`).
   - **§0bis** : Recopie inconditionnelle `HwIn := HwReal;` (aucune logique `IF`, aucun flag de simulation).
   - **§1** : Conditionnement `FB_Input` depuis `HwIn` (filtre 20 ms, inversion polarité le cas échéant).
   - **Bandeau de tête & Carte des blocages** : Intégrés en noir et blanc avec des tags texte alignés `[BLOQUE]`, `[ESCAL.]`, `[DIAG]`.
   - **Format par signal** : Standardisé sur 3-4 lignes max avec traçabilité complète `source ──► [traitement] ──► sortie ──► consommateurs`.
3. **Migration des consommateurs d'entrées physiques** :
   - `PRG_01_Diagnostics` : lit désormais `HwIn.Operator` et `HwIn.Translation` (GetBusState, GetDeviceState, RawX/Y/Button).
   - `PRG_02_Encoders` : lit désormais `HwIn.Winch` (COD1/COD2 PosValue, Alarms, Warnings).
   - `PRG_08_AuxiliaryControl` : lit désormais `HwIn.Machine.HydraulicThermalOk_DI`.
   - `PRG_10_Outputs` : non impacté (sorties uniquement).

---

## 2. 📊 Tableau de correspondance des signaux d'entrée (~35 signaux)

| Signal physique d'origine | Champ dans `HwIn` (`PRG_00_Inputs.HwIn`) | Consommateurs mis à jour |
|---|---|---|
| `PowerContactorEngaged_DI` | `HwIn.Machine.PowerContactorEngaged_DI` | `PRG_00` §1 (`instEmergencyStopOk`) |
| `EmergencyChainClosed_DI` | `HwIn.Machine.EmergencyChainClosed_DI` | `PRG_00` §1 (`instEmergencyChain`) |
| `M1M2_TopPositionFree_DI` | `HwIn.Winch.M1M2_TopPositionFree_DI` | `PRG_00` §1 (`instTopPositionSensor`) |
| `M2_TensionedCable_DI` | `HwIn.Winch.M2_TensionedCable_DI` | `PRG_00` §1 (`instSlackCableSwitch`) |
| `M1_M2_KoboldContactFond_DI` | `HwIn.Machine.M1_M2_KoboldContactFond_DI` | `PRG_00` §1 (`instKoboldContactFond`) |
| `PhaseRotationOk_DI` | `HwIn.Machine.PhaseRotationOk_DI` | `PRG_00` §1 (`instCtrlPhaseRotation`) |
| `BrakeThermalOk_DI` | `HwIn.Machine.BrakeThermalOk_DI` | `PRG_00` §1 (`instBrakeThermalFeedback`) |
| `M1_ContactorsReleased_DI` | `HwIn.Winch.M1_ContactorsReleased_DI` | `PRG_00` §1 (`instM1FwdRevSpeedFeedbackOff`) |
| `M1_ThermalOk_DI` | `HwIn.Winch.M1_ThermalOk_DI` | `PRG_00` §1 (`instM1Thermal`) |
| `M1_BrakeIsOpen_DI` | `HwIn.Winch.M1_BrakeIsOpen_DI` | `PRG_00` §1 (`instM1BrakeFeedback`) |
| `M2_ContactorsReleased_DI` | `HwIn.Winch.M2_ContactorsReleased_DI` | `PRG_00` §1 (`instM2FwdRevSpeedFeedbackOff`) |
| `M2_ThermalOk_DI` | `HwIn.Winch.M2_ThermalOk_DI` | `PRG_00` §1 (`instM2Thermal`) |
| `M2_BrakeIsOpen_DI` | `HwIn.Winch.M2_BrakeIsOpen_DI` | `PRG_00` §1 (`instM2BrakeFeedback`) |
| `M3_PosTremie_DI` | `HwIn.Translation.M3_PosTremie_DI` | `PRG_00` §1 (`instTranslationPosTremie`) |
| `M3_PosPV_DI` | `HwIn.Translation.M3_PosPV_DI` | `PRG_00` §1 (`instTranslationPosPV`) |
| `M3_PosP2_DI` | `HwIn.Translation.M3_PosP2_DI` | `PRG_00` §1 (`instTranslationPosP2`) |
| `M3_PosP1_DI` | `HwIn.Translation.M3_PosP1_DI` | `PRG_00` §1 (`instTranslationPosP1`) |
| `M3_PosMaintenance_DI` | `HwIn.Translation.M3_PosMaintenance_DI` | `PRG_00` §1 (`instTranslationPosMaintenance`) |
| `M3_BrakeIsOpen_DI` | `HwIn.Translation.M3_BrakeIsOpen_DI` | `PRG_00` §1 (`instM3BrakeFeedback`) |
| `HydraulicThermalOk_DI` | `HwIn.Machine.HydraulicThermalOk_DI` | `PRG_08_AuxiliaryControl` |
| `M3_ActualFrequencyHz` | `HwIn.Translation.M3_ActualFrequencyHz` | `PRG_00` §1 (`M3_ActualFrequencyHz_Filtered`) |
| `M3_StatusWord` | `HwIn.Translation.M3_StatusWord` | `PRG_00` §1 (`M3_StatusWord_Filtered`) |
| `COD1_PosValue` | `HwIn.Winch.COD1_PosValue` | `PRG_02_Encoders` (`M1_RawPosToUse`) |
| `COD1_Alarms` | `HwIn.Winch.COD1_Alarms` | `PRG_02_Encoders` (`instEncoderAbsM1`) |
| `COD1_Warnings` | `HwIn.Winch.COD1_Warnings` | `PRG_02_Encoders` (`instEncoderAbsM1`) |
| `COD2_PosValue` | `HwIn.Winch.COD2_PosValue` | `PRG_02_Encoders` (`M2_RawPosToUse`) |
| `COD2_Alarms` | `HwIn.Winch.COD2_Alarms` | `PRG_02_Encoders` (`instEncoderAbsM2`) |
| `COD2_Warnings` | `HwIn.Winch.COD2_Warnings` | `PRG_02_Encoders` (`instEncoderAbsM2`) |
| `JoyXRaw_ANA1` | `HwIn.Operator.JoyXRaw_ANA1` | `PRG_01_Diagnostics` (`FB_Joystick_0`) |
| `JoyYRaw_ANA2` | `HwIn.Operator.JoyYRaw_ANA2` | `PRG_01_Diagnostics` (`FB_Joystick_0`) |
| `JoyBtnRaw` | `HwIn.Operator.JoyBtnRaw` | `PRG_01_Diagnostics` (`FB_Joystick_0`) |
| `CANbus.GetBusState()` | `HwIn.Operator.CanBusState` | `PRG_01_Diagnostics` (`RawCanBusState`) |
| `JOY1.GetDeviceState()` | `HwIn.Operator.JOY1_DeviceState` | `PRG_01_Diagnostics` (`RawJoystickState`) |
| `AC600.GetDeviceState()` | `HwIn.Translation.AC600_DeviceState` | `PRG_01_Diagnostics` (`RawVariateurState`) |
| `COD1.GetDeviceState()` | `HwIn.Winch.COD1_DeviceState` | `PRG_01_Diagnostics` (`RawEncoderM1State`) |
| `COD2.GetDeviceState()` | `HwIn.Winch.COD2_DeviceState` | `PRG_01_Diagnostics` (`RawEncoderM2State`) |

---

## 3. 💬 Commentaires Déplacés / Conservés

Conformément à la règle "Zéro perte d'information", aucun commentaire technique explicatif n'a été supprimé. Tous les commentaires d'en-tête, REX terrain et justifications de polarité (notamment `BrakeFeedbackInvertLogic`) ont été intégralement conservés et mis au format dans `PRG_00_Inputs.st`.

---

## 4. 🚨 Devoir d'alerte — Constats et Remarques (§4 TASK_L2-L3)

1. **Cas Particulier Dualité Polarité Thermique M1/M2 (`PRG_03_Safety.st`)** :
   - `PRG_00_Inputs` conditionne `M1ThermalFeedback` / `M2ThermalFeedback` tel que `TRUE = Sain` (repos NC).
   - `PRG_03_Safety` fait `ThermalFeedback := NOT PRG_00_Inputs.M1ThermalFeedback` (FB_Safety_Winch attend `TRUE = Défaut`).
   - *Action* : Conformément aux consignes B4 et Interdictions (§4), aucune modification n'a été faite sur `PRG_03_Safety.st`. Le comportement exact est préservé.
2. **Ordre d'exécution impératif (CK9)** :
   - `PRG_00_Inputs` s'exécutant en Position 0, l'image matérielle `HwIn` est intégralement acquise en §0 et recopiée en §0bis **avant** que `PRG_01_Diagnostics` (Position 1), `PRG_02_Encoders` (Position 2), `PRG_03_Safety` (Position 3) ne lisent `HwIn`.
   - *Confirmation* : Aucun retard d'un scan n'est introduit.
3. **Absence totale de simulation** :
   - `HwIn := HwReal;` est 100% inconditionnel dans `PRG_00_Inputs.st`.
   - Aucune référence à `GVL_Simulation` n'a été introduite.

---

## 5. ✅ Checklist de validation des critères de sortie

- [x] `HwIn := HwReal` inconditionnel, aucun `IF`, aucun flag de simulation
- [x] Toute lecture matérielle directe est effectuée dans `PRG_00` §0 — nulle part ailleurs
- [x] Aucune polarité, aucun seuil, aucune temporisation modifiés
- [x] Carte des blocages présente et vérifiée dans le code
- [x] Zéro information perdue (commentaires déplacés/conservés)
- [x] Commentaires en français + emoji conservés
- [x] Aucun commit Git réalisé
