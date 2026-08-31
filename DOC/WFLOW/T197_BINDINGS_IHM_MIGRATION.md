# 🔄 T197 — Bindings IHM à mettre à jour manuellement dans CODESYS

> 📌 **Contexte** : le refactor T197 sort les champs **emergency/safety** de `GVL_IHM.Modes`
> vers une structure dédiée `GVL_IHM.Emergency` (type `ST_EmergencyHMI`), selon le **standard
> IHM projet** (Cmd + State [+ Cfg]). Le code `CODE/*.st` est à jour, mais les **bindings de la
> visualisation CODESYS** (`Visualization_1` et autres écrans) référencent encore les **anciens
> chemins** `Modes.State.*` / `Modes.Cmd.*` → erreurs de compilation CODESYS (champs non définis).
>
> ⚠️ **Ces bindings vivent dans le projet CODESYS (hors repo)** — l'utilisateur doit les
> corriger **manuellement** dans CODESYS 3.5. Ce document est la liste de migration.
>
> 🧭 **Point de vue IHM** : `Emergency.Cmd` = les **boutons** opérateur. Les commandes physiques
> fail-safe (`MaintainA/B_Cmd`, `ArmPulse_Cmd`) sont des **sorties du FB AU**, exposées dans
> `Emergency.State` comme states/info. Le diagnostic vit dans `Emergency.State.Diag`
> (**PAS de dossier `Diag` au top**).

---

## 🎯 Bindings bloquants (erreurs de compilation signalées)

Les champs déplacés sont référencés par l'IHM sous les anciens chemins. Les relier aux
**nouveaux chemins** :

### Commandes IHM (boutons) — `Modes.Cmd.*` → `Emergency.Cmd.*`

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `GVL_IHM.Modes.Cmd.BtnEmergencyArming` | `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` | Bouton « Réarmer puissance » |
| `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` | `GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff` | Bouton « Coupure d'urgence » |

### États IHM — `Modes.State.*` → `Emergency.State.*` (champs plats)

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `GVL_IHM.Modes.State.EmergencyChainOk` | `GVL_IHM.Emergency.State.ChainOk` | Voyant boucle AU saine |
| `GVL_IHM.Modes.State.PowerContactorOk` | `GVL_IHM.Emergency.State.ContactorOk` | Voyant contacteur confirmé |
| `GVL_IHM.Modes.State.EmergencyArmable` | `GVL_IHM.Emergency.State.Armable` | Voyant réarmement possible |
| `GVL_IHM.Modes.State.EmergencyArmingBusy` | `GVL_IHM.Emergency.State.ArmingBusy` | Voyant séquence en cours |
| `GVL_IHM.Modes.State.RedundancyTestFailed` | `GVL_IHM.Emergency.State.Diag.RedundancyTestFailed` | Alarme test redondance |
| `GVL_IHM.Modes.State.EmergencyArmingFailed` | `GVL_IHM.Emergency.State.Diag.ArmFailed` | Alarme échec réarmement |

> ⚠️ **Champs retirés** (plus d'équivalent dans `State` — à supprimer des écrans) :
> - `PowerContactorEngaged` → entrée brute `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI`
>   (déjà exposée ailleurs, ex. `GVL_Troubleshooting`).
> - `PowerCutOffActive` → `PRG_06_Outputs.PowerCutOffActive` (coupure métier finale active).

---

## 🔄 Étape 2 — Structure intermédiaire → structure plate finale (C0218 IHM)

> 📌 **Contexte** : après T197, la visualisation CODESYS a été reliée à une **structure
> intermédiaire** `Emergency.HmiCmd` / `Emergency.HmiState` / `Emergency.Status.State` /
> `Emergency.Cmd.Maintain*`. Cette structure a été **remplacée** par la structure plate finale
> `Emergency.Cmd` (boutons) + `Emergency.State` (champs plats + `Diag` interne). Les bindings
> de la visualisation référencent encore l'ancienne structure → erreurs de compilation CODESYS
> (champs non définis). **Ces bindings vivent dans le projet CODESYS (hors repo)** — à corriger
> manuellement. Table de migration **exacte** (relevée dans `Device.export`, lignes 63750-92705) :

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `Emergency.HmiCmd.BtnEmergencyArming` | `Emergency.Cmd.BtnEmergencyArming` | Bouton « Réarmer puissance » |
| `Emergency.HmiCmd.BtnEmergencyCutOff` | `Emergency.Cmd.BtnEmergencyCutOff` | Bouton « Coupure d'urgence » |
| `Emergency.HmiState.EmergencyArmable` | `Emergency.State.Armable` | Voyant réarmement possible |
| `Emergency.HmiState.EmergencyArmingFailed` | `Emergency.State.Diag.ArmFailed` | Alarme échec réarmement |
| `Emergency.HmiState.PowerCutOffActive` | `PRG_06_Outputs.PowerCutOffActive` | Voyant coupure métier |

> ⚠️ **Clarification utilisateur** : `Emergency.HmiState.PowerCutOffActive` est **conservé** et
> relié à **`PRG_06_Outputs.PowerCutOffActive`** (coupure métier finale active). **Pas** de
> `Emergency.PowerCutOffRequest` (n'existe pas dans `ST_EmergencyHMI`).
| `Emergency.Status.State.ChainOk` | `Emergency.State.ChainOk` | Voyant boucle AU saine |
| `Emergency.Status.State.ContactorOk` | `Emergency.State.ContactorOk` | Voyant contacteur confirmé |
| `Emergency.Cmd.MaintainA_Cmd` | `Emergency.State.MaintainA_Cmd` | État maintien canal A |
| `Emergency.Cmd.MaintainB_Cmd` | `Emergency.State.MaintainB_Cmd` | État maintien canal B |

> 🔍 **Autres champs `HmiState` de la structure intermédiaire** (si présents sur d'autres écrans,
> même règle de migration) :
> - `Emergency.HmiState.EmergencyChainOk` → `Emergency.State.ChainOk`
> - `Emergency.HmiState.PowerContactorOk` → `Emergency.State.ContactorOk`
> - `Emergency.HmiState.EmergencyArmingBusy` → `Emergency.State.ArmingBusy`
> - `Emergency.HmiState.RedundancyTestFailed` → `Emergency.State.Diag.RedundancyTestFailed`
> - `Emergency.HmiState.PowerContactorEngaged` → ⚠️ **champ retiré** → `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI`

---

## 🧩 C0218 — CASE `FB_Safety_EmergencyManagement` (message opérateur §11)

> 📌 **Verdict (confirmé utilisateur)** : CODESYS **refuse** les constantes locales
> `VAR CONSTANT` déclarées dans un `FUNCTION_BLOCK` comme **étiquettes de CASE** (conformité IEC).
> Le C0218 persiste malgré une déclaration correcte. **Correctif appliqué** : les constantes
> `CST_STEP_*` (0..6) et `CST_ABORT_*` (bitfield) sont déplacées dans une **GVL de constantes**
> `GVL_Safety_Emergency_Constants` en `VAR_GLOBAL CONSTANT` — les constantes globales sont des
> labels de CASE valides en CODESYS. Le CASE **garde ses labels symboliques** (lisible).

**Correctif repo** :
- ➕ `CODE/B_AU_SECURITE/GVL_Safety_Emergency_Constants.st` : `VAR_GLOBAL CONSTANT` avec
  `CST_STEP_IDLE..CST_STEP_CONFIRM` (`INT := 0..6`) et `CST_ABORT_NONE..CST_ABORT_TIMEOUT_CONTACTOR`
  (`INT := 0,1,2,4,8,16,32,64,128`). GVL **non** `qualified_only` → les références symboliques
  non qualifiées (`ArmingSeqStep = CST_STEP_IDLE`, labels du CASE) restent valides sans modification.
- ✏️ `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st` : bloc `VAR CONSTANT` local réduit aux
  **5 temporisations** (`CST_TestDuration`…`CST_FaultDisplayDebounce`). `CST_STEP_*`/`CST_ABORT_*`
  retirées (commentaire de renvoi vers la GVL). CASE §11 et toutes les comparaisons **inchangés**.

**Vérification de la déclaration** (`CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st`) :
- Bloc `VAR CONSTANT` local : lignes **94-107** (temporisations uniquement).
- CASE : ligne **438** (après le bloc `VAR CONSTANT`), labels `CST_STEP_*` → résolus depuis la GVL.
- Variable scrutée `ArmingSeqStep` : `INT` (ligne 56) — type cohérent avec les labels.

**Action CODESYS (manuelle)** : ré-importer la GVL `GVL_Safety_Emergency_Constants` **et** le FB
`FB_Safety_EmergencyManagement` (ou le bundle `CODE_XML/CODE_Bundle.xml`) dans CODESYS, puis
recompiler. Le C0218 disparaît. ⚠️ **Ne pas** remplacer les labels `CST_STEP_*` par des littéraux :
les constantes symboliques restent plus lisibles et sont utilisées dans les comparaisons.

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
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_EmergencyHMI.st` | type `ST_EmergencyHMI` (Cmd + State) |
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_EmergencyCmd.st` | boutons `BtnEmergencyArming` / `BtnEmergencyCutOff` |
| `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_EmergencyState.st` | état AU + cmd FB AU + `Diag` interne |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesState.st` | allégé (8 champs retirés) |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesCmd.st` | allégé (2 boutons retirés) |
| `CODE/M_MAIN/PRG_07_Supervision.st` | producteur → `Emergency.State.*` (dont `State.Diag`) |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `Emergency.Cmd.BtnEmergencyCutOff` |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `Emergency.Cmd.BtnEmergencyArming/CutOff` |
| `CODE/J_SUPERVISION/FB_TroubleshootingView.st` | `Emergency.Cmd.BtnEmergencyCutOff` |

> 🔍 Grep de contrôle : **0 occurrence** de `Modes.State.Emergency*` / `Modes.Cmd.BtnEmergency*`
> dans `CODE/` (hors commentaire obsolète `ST_SafetyChecklist.st` L21, non bloquant).
> **0 occurrence** de `Emergency.HmiCmd` / `Emergency.HmiState` / `Emergency.Status` /
> `Emergency.Diag` (top-level) dans `CODE/`.
