# 🔄 T184 — Bindings IHM à mettre à jour manuellement dans CODESYS

> 📌 **Contexte** : le renommage T184 (homogénéisation « sens par axe » M1/M2/M3) a
> renommé des variables **exposées à l'IHM**. Le code `CODE/*.st` est à jour, mais les
> **bindings de la visualisation CODESYS** (`Visualization_1` et autres écrans) référencent
> encore les **anciens noms** → erreurs de compilation CODESYS (`GVL_IHM.TranslationM3.Cmd.BtnFwd`
> / `BtnRev` non définis).
>
> ⚠️ **Ces bindings vivent dans le projet CODESYS (hors repo)** — l'utilisateur doit les
> corriger **manuellement** dans CODESYS 3.5. Ce document est la liste de migration.

---

## 🎯 Bindings bloquants (erreurs de compilation signalées)

| Ancien binding IHM (à supprimer) | Nouveau binding IHM (à lier) | Écran / objet |
|---|---|---|
| `GVL_IHM.TranslationM3.Cmd.BtnFwd` | `GVL_IHM.TranslationM3.Cmd.BtnTremie` | `Visualization_1` — bouton translation vers Trémie |
| `GVL_IHM.TranslationM3.Cmd.BtnRev` | `GVL_IHM.TranslationM3.Cmd.BtnMaintenance` | `Visualization_1` — bouton translation vers Maintenance |

> Ces 2 bindings sont la cause de l'erreur `Visualization_1 : GVL_IHM.TranslationM3.Cmd.BtnFwd/BtnRev non définis`.

---

## 📋 Autres bindings IHM sur noms renommés (à vérifier / mettre à jour)

Le renommage T184 a touché d'autres variables exposées à l'IHM. **Vérifier** dans toutes les
visualisations que les bindings utilisent les **nouveaux noms** (le code les référence déjà) :

### Translation M3 — `GVL_IHM.TranslationM3.*`

| Ancien | Nouveau | Chemin |
|---|---|---|
| `Cmd.BtnFwd` | `Cmd.BtnTremie` | `GVL_IHM.TranslationM3.Cmd.BtnTremie` |
| `Cmd.BtnRev` | `Cmd.BtnMaintenance` | `GVL_IHM.TranslationM3.Cmd.BtnMaintenance` |
| `State.LimitSwitchFwd` | `State.LimitSwitchTremie` | `GVL_IHM.TranslationM3.State.LimitSwitchTremie` |
| `State.LimitSwitchRev` | `State.LimitSwitchMaintenance` | `GVL_IHM.TranslationM3.State.LimitSwitchMaintenance` |

### Treuils M1 / M2 — `GVL_IHM.M1TreuilRetenue.*` / `GVL_IHM.M2TreuilBenne.*`

| Ancien | Nouveau | Chemin |
|---|---|---|
| `Cmd.BtnUp` | `Cmd.BtnAscent` | `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent` / `GVL_IHM.M2TreuilBenne.Cmd.BtnAscent` |
| `Cmd.BtnDown` | `Cmd.BtnDescent` | `GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent` / `GVL_IHM.M2TreuilBenne.Cmd.BtnDescent` |

---

## 🛠️ Procédure manuelle dans CODESYS 3.5

1. Ouvrir le projet CODESYS (source de vérité = `CODE/*.st` + bundle `CODE_XML/CODE_Bundle.xml`).
2. Ouvrir `Visualization_1` (et tout autre écran IHM).
3. Pour chaque objet lié à un ancien nom :
   - **Supprimer** le binding pointant vers l'ancien nom (ex. `GVL_IHM.TranslationM3.Cmd.BtnFwd`).
   - **Relier** l'objet au nouveau nom (ex. `GVL_IHM.TranslationM3.Cmd.BtnTremie`).
4. Recompiler : les 15 erreurs T184 doivent disparaître (les 2 bindings M3 + les 4 variables
   physiques relais + la référence `WinchMaxStepDescending` — ces dernières sont déjà corrigées
   côté repo, voir note ci-dessous).
5. ⚠️ **Mapping E/S physique** : les noms de canaux `M1_RelayFwd_Up_DQ` / `M1_RelayRev_Down_DQ`
   / `M2_RelayFwd_Up_Close_DQ` / `M2_RelayRev_Down_Open_DQ` sont renommés en
   `M1_RelayAscent_DQ` / `M1_RelayDescent_DQ` / `M2_RelayAscent_Close_DQ` / `M2_RelayDescent_Open_DQ`
   dans le mapping E/S du projet CODESYS (stub `TOOLS/LINTER_ST/stubs/GVL_Device_IO.st` déjà à jour).

---

## ✅ État côté repo (déjà corrigé — pas d'action repo requise)

| Fichier | Correction |
|---|---|
| `CODE/GVL_PERSISTENT.st` | `WinchMaxStepDescending` → `WinchMaxStepDescent` (déjà en place, L133) |
| `CODE/M_MAIN/PRG_06_Outputs.st` | utilise déjà les nouveaux noms relais (L141-142, L214-215) |
| `TOOLS/LINTER_ST/stubs/GVL_Device_IO.st` | noms physiques relais renommés (L70-71, L79-80) |

> 🔍 Grep de contrôle : **0 occurrence** des anciens noms dans `CODE/` et `TOOLS/LINTER_ST/`.
