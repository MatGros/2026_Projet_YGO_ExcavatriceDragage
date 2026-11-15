# Préparation ST `T417-D` — Branche Simulation (`CODE/L_SIMULATION/`)

> **Statut :** Brouillon prêt au GO (aucune modification appliquée sur `CODE/`).

## 1. `CODE/L_SIMULATION/FB_Sim_PositionSensor.st` (came finie)
- **Contexte vérifié :** `CamDropoutActive`, `CamDropoutStart_M`, `CamDropoutWidth_M` modélisent déjà une perte de came suivie d'une ré-acquisition infinie (`FB_Sim_PositionSensor.st:35-37`).
- **Ajout `VAR_INPUT` (après ligne 37) :**
```iecst
    (* T417-D / Plan A0 : came finie (sans re-acquisition apres depassement de la longueur physique) *)
    FiniteCamActive : BOOL := FALSE;
    CamLength_M     : REAL := 0.04;
```
- **Logique cible (dans le calcul de `HystDetected`) :** si `FiniteCamActive`, détecter uniquement dans la fenêtre `[Threshold_M - CamLength_M ; Threshold_M]` (selon `ActiveBelowThreshold` / sens), avec hystérésis `Hysteresis_M`, et **ne pas ré-activer** au-delà de la came.

## 2. `CODE/L_SIMULATION/GVL_Simulation.st` & `FB_Sim_TranslationBrake.st`
- **Contexte vérifié :** `FB_Sim_TranslationBrake.st:9` définit `CloseDelay_S : REAL := 0.09;` et `FB_Sim_Translation.st:156` fixe le gain `0.0551` (rejeté par `FB_Translation_OdometryGain.st:57` à `CST_GainMax := 0.05`).
- **Exposition `GVL_Simulation.st` :**
```iecst
    SimM3SensorFiniteCam_BOOL : BOOL := FALSE;
    SimM3SensorCamLength_M    : REAL := 0.04;
    SimM3BrakeCloseDelay_S    : REAL := 0.09;
    SimM3GainMetersPerHzSec   : REAL := 0.02; (* Plage banc [0.02 ; 0.06] *)
```
- **Profil `WORST_CASE_SITE` :** `SimM3GainMetersPerHzSec := 0.0551`, `SimM3BrakeCloseDelay_S := 0.30`, décélération `0.35 m/s²`, `FiniteCamActive := TRUE`, `CamLength_M := 0.04`.

## 3. Cascade & Validation C2
1. **Plan A0 :** appliquer ci-dessus → exécuter :
   ```powershell
   python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
   python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
   python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
   python TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/run_m3_sandbox.py
   ```
2. **Plan B (si blocage CI/bundle) :** figer les résultats sous `be_dynamic_study.py` et `plan_abc_matrix.py` sans bloquer `T417-E`.
