# 🔄 T197 — Bindings IHM à mettre à jour manuellement dans CODESYS

> 📌 **Contexte** : le refactor T197 sort les champs **emergency/safety** de `GVL_IHM.Modes`
> vers une structure dédiée `GVL_IHM.Emergency` (type `ST_EmergencyHMI`), en réutilisant les
> DUT du refactor AU (`ST_Safety_Emergency_State` / `ST_Safety_Emergency_Diag`).
> Le code `CODE/*.st` est à jour, mais les **bindings de la visualisation CODESYS**
> (`Visualization_1` et autres écrans) référencent encore les **anciens chemins** `Modes.State.*`
> / `Modes.Cmd.*` → erreurs de compilation CODESYS (champs non définis).
>
> ⚠️ **Ces bindings vivent dans le projet CODESYS (hors repo)** — l'utilisateur doit les
> corriger **manuellement** dans CODESYS 3.5. Ce document est la liste de migration.
>
> 🧭 **Point de vue IHM** : `Emergency.Cmd` = les **boutons** opérateur. Les commandes physiques
> fail-safe (`MaintainA/B_Cmd`, `ArmPulse_Cmd`) sont des **sorties du FB AU**, internes à
> `PRG_06` — **PAS** des commandes IHM.

---

## 🎯 Bindings bloquants (erreurs de compilation signalées)

Les champs déplacés sont référencés par l'IHM sous les anciens chemins. Les relier aux
**nouveaux chemins** :

### Commandes IHM (boutons) — `Modes.Cmd.*` → `Emergency.Cmd.*`

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `GVL_IHM.Modes.Cmd.BtnEmergencyArming` | `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` | Bouton « Réarmer puissance » |
| `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` | `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` | Bouton « Coupure d'urgence » |

### États IHM — `Modes.State.*` → `Emergency.State.*` / `Emergency.Diag.*`

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `GVL_IHM.Modes.State.EmergencyChainOk` | `GVL_IHM.Emergency.State.ChainOk` | Voyant boucle AU saine |
| `GVL_IHM.Modes.State.PowerContactorOk` | `GVL_IHM.Emergency.State.ContactorOk` | Voyant contacteur confirmé |
| `GVL_IHM.Modes.State.EmergencyArmable` | `GVL_IHM.Emergency.State.Armable` | Voyant réarmement possible |
| `GVL_IHM.Modes.State.EmergencyArmingBusy` | `GVL_IHM.Emergency.State.ArmingBusy` | Voyant séquence en cours |
| `GVL_IHM.Modes.State.RedundancyTestFailed` | `GVL_IHM.Emergency.Diag.RedundancyTestFailed` | Alarme test redondance |
| `GVL_IHM.Modes.State.EmergencyArmingFailed` | `GVL_IHM.Emergency.Diag.ArmFailed` | Alarme échec réarmement |

> ⚠️ **Champs retirés** (plus d'équivalent dans `State`/`Diag` — à supprimer des écrans) :
> - `PowerContactorEngaged` → entrée brute `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI`
>   (déjà exposée ailleurs, ex. `GVL_Troubleshooting`).
> - `PowerCutOffActive` → non repris dans `State`/`Diag` (coupure métier, voir `PRG_06_Outputs.PowerCutOffActive`).

---

## 🛠️ Procédure manuelle dans CODESYS 3.5

1. Ouvrir le projet CODESYS (source de vérité = `CODE/*.st` + bundle `CODE_XML/CODE_Bundle.xml`).
2. Ouvrir `Visualization_1` (et tout autre écran IHM).
3. Pour chaque objet lié à un ancien nom :
   - **Supprimer** le binding pointant vers l'ancien nom (ex. `GVL_IHM.Modes.State.EmergencyArmable`).
   - **Relier** l'objet au nouveau nom (ex. `GVL_IHM.Emergency.State.Armable`).
4. Recompiler : les erreurs T197 doivent disparaître.

---

## ✅ État côté repo (déjà corrigé — pas d'action repo requise)

| Fichier | Correction |
|---|---|
| `CODE/J_SUPERVISION/GVL_IHM.st` | ajout `Emergency : ST_EmergencyHMI` |
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_EmergencyHMI.st` | type `ST_EmergencyHMI` (Cmd/State/Diag) |
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_EmergencyCmd.st` | boutons `BtnEmergencyArming` / `BtnEmergencyCutOff` |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesState.st` | allégé (8 champs retirés) |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesCmd.st` | allégé (2 boutons retirés) |
| `CODE/M_MAIN/PRG_07_Supervision.st` | producteur → `Emergency.State` / `Emergency.Diag` |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `Emergency.Cmd.BtnEmergencyCutOff` |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `Emergency.Cmd.BtnEmergencyArming/CutOff` |
| `CODE/J_SUPERVISION/FB_TroubleshootingView.st` | `Emergency.Cmd.BtnEmergencyCutOff` |

> 🔍 Grep de contrôle : **0 occurrence** de `Modes.State.Emergency*` / `Modes.Cmd.BtnEmergency*`
> dans `CODE/` (hors commentaire obsolète `ST_SafetyChecklist.st` L21, non bloquant).
> **0 occurrence** de `Emergency.HmiCmd` / `Emergency.HmiState` / `Emergency.Status` dans `CODE/`.
