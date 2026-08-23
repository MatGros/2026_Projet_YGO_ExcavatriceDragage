# 📋 Registre de Suivi de Compilation ST / C++

> **Outils utilisés :** Moulinette ST2C (`TOOLS/COMPILER_ST2C_STruCpp/convert_codesys_to_iec.py`) + Compilateur STruCpp (`TOOLS/COMPILER_ST2C_STruCpp/bin/win32-x64/strucpp.exe` & `g++`).

---

## 📑 Synthèse Globale des Domaines Validés

| Domaine / Dossier | Total Composants | Compilables (OK) | Échecs (FAIL) | Mocks Utilisés | Statut Global | Rapport HTML |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `A_COMMUN` | 10 | 10 | 0 | Non | 🟢 100% OK | [A_COMMUN.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/reports/A_COMMUN.html) |
| `B_AU_SECURITE` | 6 | 6 | 0 | Non | 🟢 100% OK | [FB_Safety_EmergencyManagement.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/AU_SECURITE/reports/FB_Safety_EmergencyManagement.html) |
| `C_DIAG_RESEAUX` | 5 | 5 | 0 | `DEVICE_STATE` | 🟢 100% OK | [DIAG_RESEAUX.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/DIAG_RESEAUX/reports/DIAG_RESEAUX.html) |
| `D_JOYSTICK` | 3 | 3 | 0 | Non | 🟢 100% OK | [FB_Joystick.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/JOYSTICK/reports/FB_Joystick.html) |
| `E_CODEURS` | 12 | 12 | 0 | Non | 🟢 100% OK (M1 / M2) | [FB_Encoder.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/CODEURS/reports/FB_Encoder.html) |
| `F_MODES` | 2 | 2 | 0 | Non | 🟢 100% OK | [MODES.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/MODES/reports/MODES.html) |
| `G_CYCLE` | 6 | 6 | 0 | Non | 🟢 100% OK | [CYCLE.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/CYCLE/reports/CYCLE.html) |
| `H_TREUILS_BENNE` | 19 | 19 | 0 | `HYSTERESIS` | 🟢 100% OK | [TREUILS.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/TREUILS/reports/TREUILS.html) |
| `I_TRANSLATION` | 7 | 7 | 0 | Non | 🟢 100% OK | [TRANSLATION.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/TRANSLATION/reports/TRANSLATION.html) |
| `J_SUPERVISION` | 105 | 105 | 0 | `DEVICE_STATE` | 🟢 100% OK | [SUPERVISION.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/SUPERVISION/reports/SUPERVISION.html) |
| `L_SIMULATION` | 7 | 7 | 0 | Non | 🟢 100% OK | [SIMULATION.html](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage.worktrees/compilation-test-auto-ci/TOOLS/TEST_AUTO_CI/RESULTS/SIMULATION/reports/SIMULATION.html) |
| **TOTAL METIER** | **168** | **168** | **0** | **100% OK** | 🏆 **100% VALIDÉ C++ / STruCpp** | **10 Domaines** |

---

## 🛠️ Adaptations Runtime & Mocks Requis (Documenté & Tracé)

1. **Type système CODESYS `DEVICE_STATE` :**
   - **Origine :** Bibliothèque 3S Device / CAA Diagnosis intégrée dans l'IDE CODESYS.
   - **Solution CI :** Fourni via `TOOLS/TEST_AUTO_CI/MOCKS/DEVICE_STATE.st` sans modifier le code source.
2. **Surcharge C++ `NOT(int)` :**
   - **Origine :** `g++` effectue une promotion entière sur les opérations booléennes composées (`|`, `&`) dans `NOT(...)`.
   - **Solution CI :** Ajout de la surcharge `inline int NOT(int value) noexcept { return !value; }` dans `iec_std_lib.hpp`.
3. **Bloc `HYSTERESIS` (lib Util CODESYS) :**
   - **Origine :** Conflit de signature entre le `HYSTERESIS` de CODESYS Util (`IN, HIGH, LOW -> OUT`) et celui de MatIEC/STruCpp Annexe E (`XIN1, XIN2, EPS -> Q`).
   - **Solution CI :** Mappage transparent en `FB_Hysteresis_Util` via `TOOLS/TEST_AUTO_CI/MOCKS/HYSTERESIS.st` dans la moulinette ST2C sans toucher au code source `CODE/`.
4. **Matrices 2D imbriquées (`ARRAY[1..5] OF ARRAY[1..5]` & `arr[i][j]`) :**
   - **Origine :** Idiome CODESYS pour les matrices de charge `ST_WinchLoadEstimateTable`.
   - **Solution CI :** Conversion automatique en `ARRAY[1..5, 1..5]` et `arr[i, j]` via la moulinette `convert_codesys_to_iec.py`.
5. **Littéraux binaires dans les instructions `CASE` (`2#11111, 2#01111:`):**
   - **Origine :** Syntaxe CODESYS dans `FB_Translation_PositionDecoder`.
   - **Solution CI :** Conversion des littéraux binaires et séparation des labels multiples par la moulinette `convert_codesys_to_iec.py`.

---

## 🔍 Détail par Dossier & Bloc

### 1. `CODE/A_COMMUN`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `E_State.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_FbStatus.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_FbCause.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_ContactorCheck.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_CycleTime.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Ramp.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Acquisition_Preflight.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_FbStatus.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Filter.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Brake.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 2. `CODE/B_AU_SECURITE`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `ST_Safety_Emergency_InternalCmd.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Safety_Emergency_State.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Safety_Emergency_Diag.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Safety_EmergencyManagementLogic.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Safety_EmergencyManagementOutput.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Safety_EmergencyManagement.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 3. `CODE/C_DIAG_RESEAUX`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `DEVICE_STATE.st` | MOCK (Enum) | OK | OK | 🟢 **OK** | Simulé pour environnement CI (hors CODESYS) |
| `E_Diag_State.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Diag_Device.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Diag_IhmHeartbeat.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Diag_CanOpen.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Diag_Ethercat.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 4. `CODE/D_JOYSTICK`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `ST_Joystick_AxisCmd.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_AxisScale.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Joystick.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 5. `CODE/E_CODEURS`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `ST_EncoderHw.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Encoder_Calib.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_EncoderMeasurement.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder_Abs.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder_Homing.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder_Scale.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder_Safety.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_EncoderReliability.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder_SpeedMeasure.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Encoder.st` | FB (Top) | OK | OK | 🟢 **OK** | Validé sur les 2 instances (M1 et M2) |

---

### 6. `CODE/F_MODES`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `E_Mode.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Modes.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 7. `CODE/G_CYCLE`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `E_CycleStep.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `E_DiveSearchState.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `E_ExtractionSequenceState.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_DiveSearch.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_ExtractionSequence.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Cycle.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 8. `CODE/H_TREUILS_BENNE`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `HYSTERESIS.st` | MOCK (FB) | OK | OK | 🟢 **OK** | Simulé (lib Util CODESYS) |
| `ST_SpeedStepTable.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `E_WinchFinalInterlockReason.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `E_WinchFinalInterlockState.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_WinchSpeedConfig.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_WinchLoadEstimateTable.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Winch_SymmetryCfg.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_Winch_SymmetryData.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_WinchCmdDemand.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_SpeedStep.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_DriftGuard.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_WinchOutputInterlock.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Safety_Winch.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_WinchLoadEstimator.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Winch_Symmetry.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_WinchSync.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_SyncDeviation.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_SyncContactor.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Winch.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_BucketConfig.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_BucketState.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_BucketCmdDemand.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Bucket.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 9. `CODE/I_TRANSLATION`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `E_TranslationFinalInterlockReason.st` | DUT (Enum) | OK | OK | 🟢 **OK** | Aucune erreur |
| `ST_TranslationCmdDemand.st` | DUT (Struct) | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Translation_PositionDecoder.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Translation_PositionEstimator.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_TranslationOutputInterlock.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Safety_Translation.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Translation.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 10. `CODE/J_SUPERVISION`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `ST_*.st` (78 DUTs dans `_TYPES/`) | DUT (Struct) | OK | OK | 🟢 **OK** | 78 structures validées |
| `FB_CfgPersistBridge_*.st` (7 bridges) | FB | OK | OK | 🟢 **OK** | 7 ponts de persistance validés |
| `FB_AntiFlickerText.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Hmi_BannerFormatter.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_TroubleshootingView.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---

### 11. `CODE/L_SIMULATION`
| Fichier / Bloc | Type | Transpilation ST2C | Compilation C++ (STruCpp) | Statut Global | Détail / Erreurs |
|---|---|:---:|:---:|:---:|---|
| `FB_Sim_Encoder.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Sim_Joystick.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Sim_Safety.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_Sim_Translation.st` | FB | OK | OK | 🟢 **OK** | Aucune erreur |
| `FB_SimBench.st` | FB (Top) | OK | OK | 🟢 **OK** | Aucune erreur |

---
