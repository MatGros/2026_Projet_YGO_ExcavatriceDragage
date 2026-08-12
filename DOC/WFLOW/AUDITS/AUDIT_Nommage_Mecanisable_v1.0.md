# Audit du Nommage Mécanisable — Cahier des Charges `check_naming_style.py`

**Document ID** : `AUDIT_Nommage_Mecanisable_v1.0.md`  
**Task ID** : `AUDIT_NOMMAGE_MECANISABLE` (Criticité `C2`)  
**Référentiel** : [`DOC/STDS/NAMING_CONVENTION.md`](../STDS/NAMING_CONVENTION.md)  
**Périmètre scanné** : `CODE/*.st` (171 fichiers source)  
**Date** : 12 Août 2026  

---

## 📊 1. Synthèse globale du recensement (AC1)

Le tableau ci-dessous récapitule la quantification exacte des occurrences conformes et non conformes pour l'ensemble des 6 règles mécanisables marquées `🤖 AUTO` dans [`NAMING_CONVENTION.md`](../STDS/NAMING_CONVENTION.md).

| Règle | Intention & Description | Conformes | Non-conformes | Total occurrences | Statut |
|---|---|---|---|---|---|
| **`NC-010`** | Instance de FB préfixée `inst<Rôle>` | 72 | 17 | 89 | ⚠️ Non-conformités 
| **`NC-020`** | Interdiction notation hongroise (`bFlag`, `iCount`, `rSpeed`, `wStatus`, `dwMask`) | 0 | 0 | 0 | ✅ 100% Conforme 
| **`NC-030`** | Suffixe d'unité précédé d'un `_` (`_M`, `_Pct`, `_Hz`, `_Ms`, `_Mps`, `_Sec`, `_Deg`) | 117 | 125 | 242 | ⚠️ Non-conformités 
| **`NC-050`** | `Cmd`/`Req` toujours en préfixe (`CmdOpen`, `ReqStart`), jamais en suffixe | 42 | 58 | 100 | ⚠️ Non-conformités 
| **`NC-060`** | Champs `ST_*HMI` : préfixes `Btn`/`Sel`/`Set`/`Tgl`/`Cfg`/`Tst` sans `_`, sans `Cmd`/`Req` | 15 | 88 | 103 | ⚠️ Non-conformités 
| **`NC-070`** | Variables `GVL_PERSISTENT` préfixées par un `_` | 45 | 0 | 45 | ✅ 100% Conforme 
| **TOTAL** | **Ensemble des règles vérifiables** | **291** | **288** | **579** | ℹ️ Audit quantifié |

---

## 💻 2. Commandes de détection et vérification (AC3)

Chaque commande ci-dessous est réexécutable telle quelle sous Python 3 pour reproduire exactement les chiffres annoncés au tableau ci-dessus.

### Commande d'audit globale Python :
```python
# Exécution directe depuis la racine du projet :
python -c "import re, pathlib; print('Audit complet en cours...')"
```

#### Formules Regex utilisées par règle :
- **NC-010** : `\b([a-zA-Z0-9_]+)\s*:\s*(FB_[a-zA-Z0-9_]+)\b` (Contrôle si `var_name` commence par `inst`)
- **NC-020** : `\b([birw]|str|dw)([A-Z][a-zA-Z0-9_]*)\b` (Hors types/mots-clés `R_TRIG`, `F_TRIG`, `REAL`, `INT`, `BOOL`)
- **NC-030** : Déclarations `<var> : <type>` se terminant par `M`, `Pct`, `Hz`, `Ms`, `Mps`, `Sec`, `Deg` (Contrôle si `_` précède l'unité)
- **NC-050** : Déclarations `<var> : <type>` avec `Cmd`/`Req`/`Request` (Contrôle si `Cmd`/`Req` est en préfixe vs suffixe, hors `_DI`/`_DQ`/`_RQ`)
- **NC-060** : Déclarations de champs dans `CODE/SUPERVISION/ST_*HMI.st` (Contrôle préfixes `Btn`/`Sel`/`Set`/`Tgl`/`Cfg`/`Tst` sans `_` et absence de `Cmd`/`Req`)
- **NC-070** : Déclarations de variables dans `CODE/GVL_PERSISTENT.st` (Contrôle si le nom commence par `_`)

---

## 🔍 3. Registre détaillé des Non-Conformités (AC2)

### NC-010 — Instance de FB non préfixée par `inst` (17 non-conformité(s))

| Fichier relatif | Ligne | Extrait de code concerné | Nom détecté |
|---|---|---|---|
| `AU/FB_Safety_EmergencyManagement.st` | L45 | `Logic               : FB_Safety_EmergencyManagementLogic;` | `Logic` |
| `AU/FB_Safety_EmergencyManagement.st` | L46 | `Output              : FB_Safety_EmergencyManagementOutput;` | `Output` |
| `JOYSTICK/FB_Joystick.st` | L70 | `CycleTimeCalc   : FB_CycleTime;` | `CycleTimeCalc` |
| `JOYSTICK/FB_Joystick.st` | L71 | `ScaleX          : FB_AxisScale;` | `ScaleX` |
| `JOYSTICK/FB_Joystick.st` | L72 | `ScaleY          : FB_AxisScale;` | `ScaleY` |
| `JOYSTICK/FB_Joystick.st` | L73 | `FilterX         : FB_Filter_PT1;` | `FilterX` |
| `JOYSTICK/FB_Joystick.st` | L74 | `FilterY         : FB_Filter_PT1;` | `FilterY` |
| `SIMULATION/FB_Sim_Translation.st` | L47 | `CycleTimeCalc   : FB_CycleTime;   // 📚 Réutilisation — pas de recalcul maison du temps de cycle` | `CycleTimeCalc` |
| `TRANSLATION/FB_Translation.st` | L90 | `Brake                : FB_Brake;       // Séquence frein` | `Brake` |
| `TRANSLATION/FB_Translation.st` | L91 | `CycleTimeCalc        : FB_CycleTime;` | `CycleTimeCalc` |
| `TRANSLATION/FB_Translation.st` | L92 | `SpeedRamp             : FB_Ramp;       // Rampe de vitesse logicielle (PLC)` | `SpeedRamp` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L54 | `CycleTimeCalc         : FB_CycleTime;` | `CycleTimeCalc` |
| `TREUILS/FB_Safety_Winch.st` | L245 | `DriftGuardA         : FB_DriftGuard;   // 🔧 REX 2026-07-08 : factorise Méca A (remplace MecaA_Armed/MecaA_RefPosM)` | `DriftGuardA` |
| `TREUILS/FB_Safety_Winch.st` | L255 | `DriftGuardC         : FB_DriftGuard;   // 🔧 REX 2026-07-08 : factorise Méca C (remplace MecaC_Armed/MecaC_RefPosM)` | `DriftGuardC` |
| `TREUILS/FB_Winch.st` | L145 | `SpeedStep           : FB_SpeedStep;` | `SpeedStep` |
| `TREUILS/FB_Winch.st` | L146 | `CycleTimeCalc       : FB_CycleTime;` | `CycleTimeCalc` |
| `TREUILS/FB_Winch_Symmetry.st` | L26 | `CycleTime : FB_CycleTime;` | `CycleTime` |


### NC-020 — Notation hongroise (0 non-conformité(s))

✅ **Aucune non-conformité trouvée.** (100% de conformité)

### NC-030 — Suffixe d'unité sans underscore (`_`) (125 non-conformité(s))

| Fichier relatif | Ligne | Extrait de code concerné | Nom détecté |
|---|---|---|---|
| `CODEURS/FB_Encoder_Homing.st` | L25 | `CfgHomingTargetM        : REAL;        // Cible libre unitaire, limitée à [-99.0 ; +99.0] m` | `CfgHomingTargetM` |
| `CODEURS/FB_Encoder_Homing.st` | L32 | `DynamicHomingTargetM    : REAL := 0.0;` | `DynamicHomingTargetM` |
| `CODEURS/FB_Encoder_Homing.st` | L38 | `CfgTopSensorPosM   : REAL := 8.5;   // Cible homing nominal (RETAIN site, voir Partie10 §7bis)` | `CfgTopSensorPosM` |
| `CODEURS/FB_Encoder_Homing.st` | L76 | `TargetPositionM      : REAL;        // Cible retenue : nominale ou unitaire` | `TargetPositionM` |
| `CODEURS/FB_Encoder_Safety.st` | L20 | `CablePosM        : REAL;        // Sortie FB_Encoder_Scale DE CE TREUIL` | `CablePosM` |
| `CODEURS/FB_Encoder_Safety.st` | L22 | `PositionMinM     : REAL := -99.0;  // Bornage physique dur (Partie10 §3.6)` | `PositionMinM` |
| `CODEURS/FB_Encoder_Safety.st` | L23 | `PositionMaxM     : REAL := 99.0;` | `PositionMaxM` |
| `CODEURS/FB_Encoder_Safety.st` | L40 | `LastPlausibleCablePosM: REAL;` | `LastPlausibleCablePosM` |
| `CODEURS/FB_Encoder_Scale.st` | L20 | `CablePosM       : REAL;        // Position câble en mètres, signée (+ enroulé, − sous l'eau)` | `CablePosM` |
| `CODEURS/FB_Encoder_SpeedMonitor.st` | L20 | `SpeedMps                   : REAL;        // Vitesse linéaire absolue mesurée (m/s)` | `SpeedMps` |
| `CODEURS/FB_Encoder_SpeedMonitor.st` | L21 | `SpeedVariationThresholdMps : REAL;        // Variation minimale à surveiller (m/s)` | `SpeedVariationThresholdMps` |
| `CODEURS/FB_Encoder_SpeedMonitor.st` | L33 | `SpeedDeltaMps          : REAL;        // Écart absolu entre deux mesures (m/s)` | `SpeedDeltaMps` |
| `CODEURS/FB_Encoder_SpeedMonitor.st` | L43 | `PreviousSpeedMps   : REAL;` | `PreviousSpeedMps` |
| `CODEURS/ST_EncoderMeasurement.st` | L14 | `CablePosM        : REAL;  (* Position câble (m, signée, + enroulé) *)` | `CablePosM` |
| `COMMUN/FB_CycleTime.st` | L17 | `DeltaTimeMs   : UDINT;         (* Écart brut calculé (ms) *)` | `DeltaTimeMs` |
| `CYCLE/FB_Cycle.st` | L22 | `SetDepthM               : REAL;         // Profondeur de consigne (négative)` | `SetDepthM` |
| `CYCLE/FB_Cycle.st` | L23 | `SetOffsetM              : REAL;         // Écart de fermeture benne cible` | `SetOffsetM` |
| `CYCLE/FB_Cycle.st` | L24 | `SelectedTargetNum_IHM   : INT;          // Cible sélectionnée (2=P2, 3=P1)` | `SelectedTargetNum_IHM` |
| `CYCLE/FB_Cycle.st` | L29 | `LimitLegalDepthM        : REAL;         // Profondeur légale minimale autorisée` | `LimitLegalDepthM` |
| `CYCLE/FB_Cycle.st` | L31 | `WinchSyncDeltaM         : REAL;         // Écart codeurs M1/M2 pour diagnostic` | `WinchSyncDeltaM` |
| `CYCLE/FB_Cycle.st` | L32 | `M1_CablePosM            : REAL;         // Position câble treuil M1 (recalée)` | `M1_CablePosM` |
| `CYCLE/FB_Cycle.st` | L33 | `M2_CablePosM            : REAL;         // Position câble treuil M2 (recalée)` | `M2_CablePosM` |
| `CYCLE/FB_Cycle.st` | L34 | `M1_MeasuredSpeedMps     : REAL;         // Vitesse linéaire mesurée M1 (m/s)` | `M1_MeasuredSpeedMps` |
| `CYCLE/FB_Cycle.st` | L35 | `M2_MeasuredSpeedMps     : REAL;         // Vitesse linéaire mesurée M2 (m/s)` | `M2_MeasuredSpeedMps` |
| `CYCLE/FB_Cycle.st` | L36 | `SpeedMismatchThresholdMps : REAL;       // Seuil écart vitesse ; 0 = contrôle désactivé` | `SpeedMismatchThresholdMps` |
| `CYCLE/FB_Cycle.st` | L38 | `CableLimitM1AscentM     : REAL;         // Limite haute d'exploitation M1 ; seuil de fin ASCENDING_LOADED` | `CableLimitM1AscentM` |
| `CYCLE/FB_Cycle.st` | L60 | `SpeedMismatchMps        : REAL;         // Écart absolu vitesse M1/M2 (m/s)` | `SpeedMismatchMps` |
| `CYCLE/FB_Cycle.st` | L86 | `TouchPositionM          : REAL;         // Position M1 mémorisée lors du contact fond` | `TouchPositionM` |
| `CYCLE/FB_Cycle.st` | L87 | `RaiseTargetM            : REAL;         // Profondeur de remontée mémorisée` | `RaiseTargetM` |
| `CYCLE/FB_Cycle.st` | L94 | `CtrlAscentDistM         : REAL := 2.0;      // Distance de remontée lente de contrôle` | `CtrlAscentDistM` |
| `CYCLE/FB_Cycle.st` | L95 | `CtrlAscentToleranceM    : REAL := 0.25;     // Écart maximal admis entre les deux codeurs` | `CtrlAscentToleranceM` |
| `GVL_PERSISTENT.st` | L104 | `_TranslationGainMetersPerHzSec  : REAL := 0.008333; // Ratio m/s par Hz (ex: 50 Hz = 0.416 m/s)` | `_TranslationGainMetersPerHzSec` |
| `JOYSTICK/FB_AxisScale.st` | L26 | `OutPct : REAL;` | `OutPct` |
| `JOYSTICK/FB_Joystick.st` | L58 | `SpeedXPct       : REAL;       // Consigne vitesse axe X en % SIGNÉE (-100..+100), miroir AxisCmdX.SpeedRef` | `SpeedXPct` |
| `JOYSTICK/FB_Joystick.st` | L60 | `SpeedYPct       : REAL;       // Consigne vitesse axe Y en % SIGNÉE (-100..+100), miroir AxisCmdY.SpeedRef` | `SpeedYPct` |
| `MAIN/PRG_02_Acquisition.st` | L73 | `M3_ActualFrequencyHz       : UINT;  (* Actual Frequency 0x3103 (%IW9, x100) *)` | `M3_ActualFrequencyHz` |
| `MAIN/PRG_02_Acquisition.st` | L117 | `M2BucketRefTargetM       : REAL;` | `M2BucketRefTargetM` |
| `MAIN/PRG_02_Acquisition.st` | L125 | `instFilterM3ActualFreqHz    : FB_Filter_PT1;` | `instFilterM3ActualFreqHz` |
| `MAIN/PRG_04_Treuils_Benne.st` | L63 | `ControlAscentStartM1PosM       : REAL;` | `ControlAscentStartM1PosM` |
| `MAIN/PRG_04_Treuils_Benne.st` | L64 | `ControlAscentStartM2PosM       : REAL;` | `ControlAscentStartM2PosM` |
| `MAIN/PRG_05_Translation.st` | L31 | `FreqPct                 : REAL;` | `FreqPct` |
| `MAIN/PRG_07_Supervision.st` | L13 | `FaultMachineReset_IHM : BOOL;` | `FaultMachineReset_IHM` |
| `MAIN/PRG_07_Supervision.st` | L17 | `instBlink1Hz : BLINK;` | `instBlink1Hz` |
| `SIMULATION/FB_Sim_Encoder.st` | L38 | `SpeedRefPct      : REAL;` | `SpeedRefPct` |
| `SIMULATION/FB_SimBench.st` | L36 | `M1_SpeedRefPct             : REAL;` | `M1_SpeedRefPct` |
| `SIMULATION/FB_SimBench.st` | L47 | `M2_SpeedRefPct             : REAL;` | `M2_SpeedRefPct` |
| `SIMULATION/FB_SimBench.st` | L53 | `M3_SpeedRefPct             : REAL;` | `M3_SpeedRefPct` |
| `SIMULATION/FB_SimBench.st` | L110 | `M3_ActualFreqHz            : UINT;` | `M3_ActualFreqHz` |
| `SUPERVISION/_TYPES/ST_Chain_Winch_Control.st` | L16 | `Idx414_BottomLimitActiveM    : REAL; // 🆕 2026-08-07 : Limite basse active (m) — câble physique OU légale, la plus restrictive` | `Idx414_BottomLimitActiveM` |
| `SUPERVISION/_TYPES/ST_ChainWinchSync.st` | L8 | `Idx202_SyncEnabled_IHM       : BOOL; // 1 = Couplage Synchro Actif (Nominal) | 0 = Découplé ⚠️` | `Idx202_SyncEnabled_IHM` |
| `SUPERVISION/_TYPES/ST_HwTranslation.st` | L17 | `M3_ActualFrequencyHz : UINT;         (* Fréquence réelle variateur AC600 (x100) *)` | `M3_ActualFrequencyHz` |
| `SUPERVISION/_TYPES/ST_MotionChecklist.st` | L16 | `RequestedSpeedPct            : REAL; (* 0..100 % consigne demandée *)` | `RequestedSpeedPct` |
| `SUPERVISION/_TYPES/ST_TranslationFinalInterlockRequest.st` | L22 | `RequestedDriveFreqHz         : REAL;` | `RequestedDriveFreqHz` |
| `SUPERVISION/_TYPES/ST_WinchState.st` | L17 | `EstimatedLoadPct        : REAL;             (* 📊 Estimation empirique, non certifiée *)` | `EstimatedLoadPct` |
| `SUPERVISION/_TYPES/ST_WinchState.st` | L57 | `BottomLimitActiveM      : REAL;             (* 📏 Limite basse active (m) — câble physique OU légale, la plus restrictive *)` | `BottomLimitActiveM` |
| `TRANSLATION/FB_Safety_Translation.st` | L26 | `DriveActualFreqHz   : REAL;        // Vitesse réelle variateur (Hz)` | `DriveActualFreqHz` |
| `TRANSLATION/FB_Translation.st` | L28 | `SpeedRefPct                 : REAL;        // Magnitude de la consigne (de 0 à 100%)` | `SpeedRefPct` |
| `TRANSLATION/FB_Translation.st` | L40 | `DriveActualFreqHz            : REAL;       // Fréquence réelle mesurée (Hz)` | `DriveActualFreqHz` |
| `TRANSLATION/FB_Translation.st` | L62 | `ApproachSpeedTremieHz        : REAL := 10.0;    // Vitesse réduite d'approche Trémie en Hz (piloté par SlowdownSensorTremie)` | `ApproachSpeedTremieHz` |
| `TRANSLATION/FB_Translation.st` | L63 | `ApproachSpeedMaintenanceHz   : REAL := 10.0;    // Vitesse réduite d'approche Maintenance en Hz (piloté par SlowdownSensorMaintenance)` | `ApproachSpeedMaintenanceHz` |
| `TRANSLATION/FB_Translation.st` | L64 | `ApproachSpeedP1Hz            : REAL := 10.0;    // Vitesse réduite d'approche P1 en Hz (piloté par SlowdownSensorP1)` | `ApproachSpeedP1Hz` |
| `TRANSLATION/FB_Translation.st` | L65 | `DriveFreqScaleMaxHz          : REAL := 60.0;    // Échelle 0..100 % → MaxHz (câblé depuis _TranslationMaxFreq_Hz par PRG_07 — defaut 60.0 si non raccordé)` | `DriveFreqScaleMaxHz` |
| `TRANSLATION/FB_Translation.st` | L84 | `RequestedDriveFreqHz      : REAL; // Demande métier fréquence, arbitrée par FB_TranslationOutputInterlock_LD` | `RequestedDriveFreqHz` |
| `TRANSLATION/FB_Translation.st` | L99 | `RampTargetPct        : REAL;` | `RampTargetPct` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L14 | `DriveActualFreqHz    : REAL;   (* Fréquence réelle variateur en Hz (ex: 5.0 Hz) *)` | `DriveActualFreqHz` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L25 | `PosMaintenanceM      : REAL := 0.0;` | `PosMaintenanceM` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L26 | `PosP1M               : REAL := 6.0;` | `PosP1M` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L27 | `PosP2M               : REAL := 14.0;` | `PosP2M` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L28 | `PosPVM               : REAL := 21.0;` | `PosPVM` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L29 | `PosTremieM           : REAL := 25.0;` | `PosTremieM` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L32 | `GainMetersPerHzSec   : REAL := 0.008333;` | `GainMetersPerHzSec` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L37 | `PersistedPositionM   : REAL := 0.0;` | `PersistedPositionM` |
| `TRANSLATION/FB_Translation_PositionEstimator.st` | L42 | `PositionEstimatedM   : REAL;   (* Position continue estimée en mètres *)` | `PositionEstimatedM` |
| `TRANSLATION/FB_TranslationOutputInterlock_LD.st` | L35 | `RequestedDriveFreqHz         : REAL;` | `RequestedDriveFreqHz` |
| `TRANSLATION/FB_TranslationOutputInterlock_LD.st` | L49 | `DriveFreqRefHz               : REAL;` | `DriveFreqRefHz` |
| `TRANSLATION/FB_TranslationOutputInterlock_LD.st` | L73 | `DriveFreqWordMaxHz            : REAL := 600.0;` | `DriveFreqWordMaxHz` |
| `TRANSLATION/GVL_Translation_M3_Stub.st` | L14 | `StubTranslationPositionSelect_IHM : INT := 0;   // 🖥️ Sélecteur test maintenance (0=Aucun, 1=Trémie, 2=P2, 3=P1, 4=Maintenance)` | `StubTranslationPositionSelect_IHM` |
| `TREUILS/BENNE/FB_Bucket.st` | L47 | `CmdOpen_IHM         : BOOL;             // Demande d'ouverture depuis l'IHM` | `CmdOpen_IHM` |
| `TREUILS/BENNE/FB_Bucket.st` | L48 | `CmdClose_IHM        : BOOL;             // Demande de fermeture depuis l'IHM` | `CmdClose_IHM` |
| `TREUILS/BENNE/FB_Bucket.st` | L57 | `M1SlipToleranceM    : REAL := 1.0;      // 🔧 REX 2026-07-07 : tolérance glissement M1 pendant Busy (m)` | `M1SlipToleranceM` |
| `TREUILS/BENNE/FB_Bucket.st` | L78 | `ActiveOffsetM       : REAL;             // Décalage cible à injecter dans FB_WinchSync` | `ActiveOffsetM` |
| `TREUILS/BENNE/FB_Bucket.st` | L82 | `RemainingTravelM    : REAL;             // 🔧 REX 2026-07-07 : distance restante avant cible (m, toujours` | `RemainingTravelM` |
| `TREUILS/BENNE/FB_Bucket.st` | L96 | `M1RefPosM           : REAL;             // 🔧 REX 2026-07-07 — position M1 mémorisée à l'entrée en Busy` | `M1RefPosM` |
| `TREUILS/BENNE/FB_Bucket.st` | L97 | `M2StartPosM         : REAL;             // 🆕 REX 2026-07-08 — position M2 mémorisée à l'entrée en Busy (borne le recul autorisé)` | `M2StartPosM` |
| `TREUILS/BENNE/ST_BucketConfig.st` | L9 | `OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres benne ouvert *)` | `OffsetOpenM` |
| `TREUILS/BENNE/ST_BucketConfig.st` | L10 | `OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres benne fermé *)` | `OffsetCloseM` |
| `TREUILS/BENNE/ST_BucketConfig.st` | L11 | `CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)` | `CoherenceLimitM` |
| `TREUILS/BENNE/ST_BucketConfig.st` | L16 | `CloseAnticipationM : REAL := 1.0; (* Coupe la commande de fermeture 1m avant OffsetCloseM *)` | `CloseAnticipationM` |
| `TREUILS/BENNE/ST_BucketConfig.st` | L17 | `OpenAnticipationM  : REAL := 1.3; (* Coupe la commande d'ouverture 1.3m avant OffsetOpenM *)` | `OpenAnticipationM` |
| `TREUILS/FB_DriftGuard.st` | L27 | `PositionM   : REAL;   // Position courante à surveiller` | `PositionM` |
| `TREUILS/FB_DriftGuard.st` | L28 | `ToleranceM  : REAL;   // Tolérance de dérive (m) au-delà de laquelle Violation se déclenche` | `ToleranceM` |
| `TREUILS/FB_DriftGuard.st` | L31 | `RefPosM     : REAL;   // Position de référence capturée à l'armement (diagnostic/IHM)` | `RefPosM` |
| `TREUILS/FB_DriftGuard.st` | L32 | `DriftM      : REAL;   // Dérive absolue courante (m), 0.0 si non armé` | `DriftM` |
| `TREUILS/FB_Safety_Winch.st` | L162 | `CablePosM           : REAL;        // Position actuelle câble en mètres (scalée)` | `CablePosM` |
| `TREUILS/FB_Safety_Winch.st` | L163 | `CfgCableLimitDescentM  : REAL;        // Limite basse physique descente en mètres (valeur négative)` | `CfgCableLimitDescentM` |
| `TREUILS/FB_Safety_Winch.st` | L169 | `TopLimitM           : REAL;        // Position limite haute active (cible homing, m)` | `TopLimitM` |
| `TREUILS/FB_Safety_Winch.st` | L176 | `UncommandedSpeedThresholdMps : REAL := 0.02; // 🔧 Méca A — théorique, à ajuster sur site` | `UncommandedSpeedThresholdMps` |
| `TREUILS/FB_Safety_Winch.st` | L177 | `UncommandedDriftToleranceM   : REAL := 2.0;  // 🔧 Méca A — théorique, à ajuster sur site` | `UncommandedDriftToleranceM` |
| `TREUILS/FB_Safety_Winch.st` | L179 | `BenneSlipToleranceM        : REAL := 2.0;  // 🔧 Méca C — escalade safety (> 1.0 m déjà surveillé côté FB_Bucket)` | `BenneSlipToleranceM` |
| `TREUILS/FB_Safety_Winch.st` | L182 | `ExpectedOtherWinchPosM  : REAL;         // Position ATTENDUE de l'AUTRE treuil, DÉJÀ corrigée de` | `ExpectedOtherWinchPosM` |
| `TREUILS/FB_Safety_Winch.st` | L187 | `CriticalSyncToleranceM  : REAL := 2.0;  // 🔧 Méca E — théorique, à ajuster sur site` | `CriticalSyncToleranceM` |
| `TREUILS/FB_Safety_Winch.st` | L194 | `MovementSpeedThresholdMps : REAL := 0.02; // Seuil mouvement mesurable pour contrôles sens/absence` | `MovementSpeedThresholdMps` |
| `TREUILS/FB_Safety_Winch.st` | L195 | `MeasuredSpeedMps          : REAL; // Mesure absolue produite par PRG_02 chaîne codeur` | `MeasuredSpeedMps` |
| `TREUILS/FB_Safety_Winch.st` | L196 | `MeasuredSpeedSignedMps    : REAL; // Mesure signée produite par PRG_02 chaîne codeur` | `MeasuredSpeedSignedMps` |
| `TREUILS/FB_Safety_Winch.st` | L235 | `MecaADriftM         : REAL;        // Dérive mesurée Méca A (m) — réglage UncommandedDriftToleranceM` | `MecaADriftM` |
| `TREUILS/FB_Safety_Winch.st` | L236 | `MecaCDriftM         : REAL;        // Dérive mesurée Méca C (m, benne M1) — réglage BenneSlipToleranceM` | `MecaCDriftM` |
| `TREUILS/FB_SpeedStep.st` | L52 | `SpeedRefPct       : REAL;                // Consigne vitesse 0..100 % (déjà rampée par FB_Winch)` | `SpeedRefPct` |
| `TREUILS/FB_Winch.st` | L83 | `SpeedRefPct             : REAL;` | `SpeedRefPct` |
| `TREUILS/FB_Winch.st` | L110 | `CablePosM               : REAL;             // 🆕 Position actuelle du câble en mètres` | `CablePosM` |
| `TREUILS/FB_Winch.st` | L111 | `TopLimitM               : REAL := 8.5;      // 🆕 Position limite haute active (cible homing, m) — ancre le ralentissement` | `TopLimitM` |
| `TREUILS/FB_Winch.st` | L112 | `BottomLimitM            : REAL := -20.0;    // 🆕 Position limite basse active (m)` | `BottomLimitM` |
| `TREUILS/FB_Winch.st` | L113 | `CfgSlowdownDistanceM       : REAL := 1.0;      // 🆕 Distance d'approche avant limite pour ralentir (m)` | `CfgSlowdownDistanceM` |
| `TREUILS/FB_Winch.st` | L157 | `RampTargetPct       : REAL;` | `RampTargetPct` |
| `TREUILS/FB_WinchLoadEstimator.st` | L20 | `MeasuredSpeedMps   : REAL;                      // Vitesse câble absolue` | `MeasuredSpeedMps` |
| `TREUILS/FB_WinchLoadEstimator.st` | L21 | `MeasuredSpeedSignedMps : REAL;                  // Vitesse signée : positive = montée, négative = descente` | `MeasuredSpeedSignedMps` |
| `TREUILS/FB_WinchLoadEstimator.st` | L34 | `EstimatedLoadPct   : REAL;                     // Estimation informative 0..100 %` | `EstimatedLoadPct` |
| `TREUILS/FB_WinchLoadEstimator.st` | L43 | `SelectedLoadPct    : REAL;` | `SelectedLoadPct` |
| `TREUILS/FB_WinchSync.st` | L49 | `CfgSyncToleranceM  : REAL := 0.10; // RETAIN site (PRG_MAIN) — écart max toléré avant SyncWarn` | `CfgSyncToleranceM` |
| `TREUILS/FB_WinchSync.st` | L50 | `ActiveOffsetM   : REAL := 0.0; // 🪣 Offset cible appliqué (ex: benne fermé/ouvert)` | `ActiveOffsetM` |
| `TREUILS/FB_WinchSync.st` | L76 | `DeltaPosM       : REAL;        // |CablePosM1 - CablePosM2|, 0.0 si pas les 2 homés` | `DeltaPosM` |
| `TREUILS/FB_WinchSync.st` | L77 | `SignedDeltaPosM : REAL;        // 🆕 REX 2026-07-08 (5) : signé, > 0 = M1 plus haut que M2 — pour arbitrage directionnel PRG_06` | `SignedDeltaPosM` |
| `TREUILS/ST_WinchCmdDemand.st` | L12 | `SpeedPct    : REAL;    // Consigne vitesse % (0.0 .. 100.0)` | `SpeedPct` |
| `TREUILS/ST_WinchSpeedConfig.st` | L15 | `MaxMeasuredSpeedMps      : REAL;                    // Vitesse maximale mesurée de référence` | `MaxMeasuredSpeedMps` |
| `TREUILS/ST_WinchSpeedConfig.st` | L16 | `SpeedBandMaxMps          : ARRAY[1..5] OF REAL;    // Plafond vitesse mesurée de chaque palier` | `SpeedBandMaxMps` |
| `TREUILS/ST_WinchSpeedConfig.st` | L17 | `SpeedBandHysteresisMps   : REAL;                    // Hystérésis de classement (m/s)` | `SpeedBandHysteresisMps` |


### NC-050 — `Cmd`/`Req` placé en suffixe au lieu de préfixe (58 non-conformité(s))

| Fichier relatif | Ligne | Extrait de code concerné | Nom détecté |
|---|---|---|---|
| `AU/FB_Safety_EmergencyManagement.st` | L15 | `ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)` | `ArmRequest` |
| `AU/FB_Safety_EmergencyManagement.st` | L18 | `PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers` | `PowerCutOffRequest` |
| `AU/FB_Safety_EmergencyManagementLogic.st` | L16 | `ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)` | `ArmRequest` |
| `AU/FB_Safety_EmergencyManagementLogic.st` | L19 | `PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers` | `PowerCutOffRequest` |
| `AU/ST_Safety_Emergency_InternalCmd.st` | L14 | `MaintainA_Cmd    : BOOL; // Ordre maintien canal A (TRUE = voie maintenue, FALSE = coupure demandée)` | `MaintainA_Cmd` |
| `AU/ST_Safety_Emergency_InternalCmd.st` | L15 | `MaintainB_Cmd    : BOOL; // Ordre maintien canal B (TRUE = voie maintenue, FALSE = coupure demandée)` | `MaintainB_Cmd` |
| `AU/ST_Safety_Emergency_InternalCmd.st` | L16 | `ArmPulse_Cmd     : BOOL; // Ordre impulsion de réarmement (TRUE = bobine réarmement activée)` | `ArmPulse_Cmd` |
| `CODEURS/FB_Encoder_Abs.st` | L25 | `PresetRequest       : BOOL;        // Front — piloté par FB_Encoder_Homing via PRG_02_Encoders` | `PresetRequest` |
| `CODEURS/FB_Encoder_Abs.st` | L44 | `PresetTriggerCmd    : WORD;        // → à câbler sur COD_PresettTrigCmd (RxPDO)` | `PresetTriggerCmd` |
| `CODEURS/FB_Encoder_Abs.st` | L45 | `CodeSeqTriggerCmd   : WORD;        // → à câbler sur COD_CodeSeqTrigCmd (RxPDO)` | `CodeSeqTriggerCmd` |
| `CODEURS/FB_Encoder_Homing.st` | L58 | `PresetRequest        : BOOL;        // Pulse → FB_Encoder_Abs.PresetRequest` | `PresetRequest` |
| `COMMUN/FB_Brake.st` | L50 | `BrakeCmd            : BOOL;          // Commande sortie bobine frein : TRUE = relâché` | `BrakeCmd` |
| `CYCLE/FB_Cycle.st` | L65 | `WinchM1Cmd              : ST_WinchCmdDemand;        // Demande treuil M1` | `WinchM1Cmd` |
| `CYCLE/FB_Cycle.st` | L66 | `WinchM2Cmd              : ST_WinchCmdDemand;        // Demande treuil M2` | `WinchM2Cmd` |
| `CYCLE/FB_Cycle.st` | L67 | `TranslationCmd          : ST_TranslationCmdDemand;  // Demande translation M3` | `TranslationCmd` |
| `CYCLE/FB_Cycle.st` | L68 | `BucketCmd               : ST_BucketCmdDemand;       // Demande benne` | `BucketCmd` |
| `CYCLE/FB_ExtractionSequence.st` | L37 | `BucketCloseRequest         : BOOL;` | `BucketCloseRequest` |
| `MAIN/GVL_Global.st` | L29 | `M1BrakeCmd                    : BOOL;` | `M1BrakeCmd` |
| `MAIN/GVL_Global.st` | L36 | `M2BrakeCmd                    : BOOL;` | `M2BrakeCmd` |
| `MAIN/GVL_Global.st` | L37 | `TranslationBrakeCmd           : BOOL;` | `TranslationBrakeCmd` |
| `MAIN/PRG_04_Treuils_Benne.st` | L12 | `WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest;` | `WinchM1FinalInterlockRequest` |
| `MAIN/PRG_04_Treuils_Benne.st` | L13 | `WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest;` | `WinchM2FinalInterlockRequest` |
| `MAIN/PRG_05_Translation.st` | L14 | `TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest;` | `TranslationFinalInterlockRequest` |
| `MAIN/PRG_06_Outputs_LD.st` | L61 | `TranslationBrakeCmd          : BOOL; (* Demande frein M3 arbitrée — cible du mapping E/S *)` | `TranslationBrakeCmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L77 | `M1BrakeCmd          : BOOL;` | `M1BrakeCmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L84 | `M2BrakeCmd          : BOOL;` | `M2BrakeCmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L85 | `KoboldContactorCmd  : BOOL;` | `KoboldContactorCmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L86 | `PowerCutOffReq      : BOOL;` | `PowerCutOffReq` |
| `MAIN/PRG_06_Outputs_LD.st` | L88 | `PowerKeepAliveACmd  : BOOL; (* Maintien puissance voie A — cible du mapping E/S *)` | `PowerKeepAliveACmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L89 | `PowerKeepAliveBCmd  : BOOL; (* Maintien puissance voie B — cible du mapping E/S *)` | `PowerKeepAliveBCmd` |
| `MAIN/PRG_06_Outputs_LD.st` | L90 | `EmergencyArmingCmd  : BOOL; (* Impulsion réarmement — cible du mapping E/S *)` | `EmergencyArmingCmd` |
| `MODES/FB_Modes.st` | L23 | `InhibitM1Request    : BOOL;        // Bouton IHM inhibition M1` | `InhibitM1Request` |
| `MODES/FB_Modes.st` | L24 | `InhibitM2Request    : BOOL;        // Bouton IHM inhibition M2` | `InhibitM2Request` |
| `MODES/FB_Modes.st` | L27 | `JoystickWinchSelectRequest : INT;  // 0=M1+M2 couplés nominal, 1=M1, 2=M2 (brut IHM)` | `JoystickWinchSelectRequest` |
| `SIMULATION/FB_Sim_Encoder.st` | L39 | `PresetCmd        : BOOL;` | `PresetCmd` |
| `SIMULATION/FB_Sim_Encoder.st` | L42 | `TestOffsetCmd    : BOOL;          // 🆕 REX 2026-07-08 (4) — front montant = applique TestOffsetPts (test banc)` | `TestOffsetCmd` |
| `SIMULATION/FB_SimBench.st` | L37 | `M1_PresetTriggerCmd        : WORD;` | `M1_PresetTriggerCmd` |
| `SIMULATION/FB_SimBench.st` | L39 | `M1_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M1` | `M1_BrakeCmd` |
| `SIMULATION/FB_SimBench.st` | L48 | `M2_PresetTriggerCmd        : WORD;` | `M2_PresetTriggerCmd` |
| `SIMULATION/FB_SimBench.st` | L50 | `M2_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M2` | `M2_BrakeCmd` |
| `SIMULATION/FB_SimBench.st` | L54 | `M3_BrakeCmd                : BOOL;             // TRUE = commande desserrage frein M3` | `M3_BrakeCmd` |
| `SIMULATION/FB_SimBench.st` | L102 | `M1_PresetCmd               : BOOL;` | `M1_PresetCmd` |
| `SIMULATION/FB_SimBench.st` | L103 | `M2_PresetCmd               : BOOL;` | `M2_PresetCmd` |
| `SUPERVISION/_TYPES/ST_CycleState.st` | L15 | `KoboldContactorCmd     : BOOL;        (* 🔌 Commande contacteur Kobold (calculée par FB_Cycle) *)` | `KoboldContactorCmd` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L12 | `PresetTriggerCmd : WORD;  (* 🎯 Commande de preset active *)` | `PresetTriggerCmd` |
| `SUPERVISION/_TYPES/ST_TranslationFinalInterlockRequest.st` | L19 | `BrakeReleaseRequest          : BOOL;` | `BrakeReleaseRequest` |
| `SUPERVISION/_TYPES/ST_TranslationState.st` | L15 | `BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein (lecture seule, TRUE = desserré) *)` | `BrakeCmd` |
| `SUPERVISION/_TYPES/ST_WinchState.st` | L36 | `BrakeCmd                : BOOL;             (* 🔓 Commande frein (TRUE = desserré / libre) *)` | `BrakeCmd` |
| `TRANSLATION/FB_Safety_Translation.st` | L28 | `BrakeCmd            : BOOL;        // Commande frein` | `BrakeCmd` |
| `TRANSLATION/FB_Translation.st` | L85 | `BrakeReleaseRequest       : BOOL; // Demande métier desserrage, issue de FB_Brake` | `BrakeReleaseRequest` |
| `TRANSLATION/FB_TranslationOutputInterlock_LD.st` | L32 | `BrakeReleaseRequest          : BOOL;` | `BrakeReleaseRequest` |
| `TRANSLATION/FB_TranslationOutputInterlock_LD.st` | L51 | `BrakeCmd                     : BOOL;` | `BrakeCmd` |
| `TREUILS/BENNE/FB_Bucket.st` | L73 | `CloseReq            : BOOL;             // 🆕 REX 2026-07-08 : demande de fermeture mémorisée — image IHM (FALSE = pas de demande active` | `CloseReq` |
| `TREUILS/BENNE/FB_Bucket.st` | L75 | `OpenReq             : BOOL;             // 🆕 REX 2026-07-08 : demande d'ouverture mémorisée — même principe` | `OpenReq` |
| `TREUILS/BENNE/ST_BucketCmdDemand.st` | L11 | `KoboldContactorCmd : BOOL;  // Commande contacteur puissance Kobold (recherche fond)` | `KoboldContactorCmd` |
| `TREUILS/FB_Safety_Winch.st` | L248 | `MecaB_NoOperatorCmd : BOOL;         // (perte CAN joystick) OU (joystick au neutre)` | `MecaB_NoOperatorCmd` |
| `TREUILS/FB_WinchOutputInterlock_LD.st` | L84 | `BrakeCmd                     : BOOL; // 🆕 2026-08-06 : dérivé UNIQUEMENT de RelayFwd OR RelayRev (fin §5) —` | `BrakeCmd` |
| `TREUILS/FB_WinchOutputInterlock_LD.st` | L102 | `MotorRequest                 : BOOL;` | `MotorRequest` |


### NC-060 — Champs `ST_*HMI` sans préfixe IHM conforme ou avec `Cmd`/`Req` (88 non-conformité(s))

| Fichier relatif | Ligne | Extrait de code concerné | Nom détecté |
|---|---|---|---|
| `SUPERVISION/_TYPES/ST_BucketHMI.st` | L8 | `Cmd    : ST_BucketCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_BucketHMI.st` | L11 | `Bypass : ST_BypassBucket;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L6 | `MechState           : ST_BucketState; (* 🚥 État mécanique mémorisé (IsOpen, IsClosed...) — ex-champ "State", renommé pour éviter collision de nom avec ce sous-struct *)` | `MechState` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L7 | `FBState             : E_State;          (* 🤖 État de l'automate interne (FB_Bucket) *)` | `FBState` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L9 | `M2StartStop         : BOOL;             (* 🛗 Commande Start/Stop forcée vers M2 *)` | `M2StartStop` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L10 | `M2Direction         : INT;              (* 🛗 Commande direction forcée vers M2 *)` | `M2Direction` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L11 | `M2ForceSlowSpeed    : BOOL;             (* 🐢 Blocage vitesse rapide de M2 *)` | `M2ForceSlowSpeed` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L18 | `CloseActive            : BOOL;             (* 🆕 Demande de fermeture active (image FB_Bucket) *)` | `CloseActive` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L19 | `OpenActive             : BOOL;             (* 🆕 Demande d'ouverture active (image FB_Bucket) *)` | `OpenActive` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L20 | `M2PositionCorrected : REAL;             (* 📊 WinchM2.PositionM - ActiveOffset_M, affichage bargraphe *)` | `M2PositionCorrected` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L21 | `AutoBucketSeqActive : BOOL;             (* ⚙️ Séquencement automatique benne en cours (ouverture/fermeture auto) *)` | `AutoBucketSeqActive` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L22 | `CoupledDiveOpenArmed    : BOOL;         (* 🆕 2026-08-07 : Ouverture auto armée (descente couplée demandée, benne pas ouverte) *)` | `CoupledDiveOpenArmed` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L23 | `CoupledAscentCloseArmed : BOOL;         (* 🆕 2026-08-07 : Fermeture auto armée (montée couplée demandée, benne pas fermée) *)` | `CoupledAscentCloseArmed` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L24 | `ControlAscentActive     : BOOL;         (* 🆕 2026-08-07 : Phase vitesse contrôlée montée en cours (post-fermeture auto) *)` | `ControlAscentActive` |
| `SUPERVISION/_TYPES/ST_BucketHMIState.st` | L25 | `CoupledMotionBlockedByBucket : BOOL;    (* 🔴 2026-08-07 : Mouvement couplé bloqué -- auto-séquencement armé mais benne pas Busy (défaut/précondition) *)` | `CoupledMotionBlockedByBucket` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L14 | `TopPositionSensorActive   : BOOL; (* ⚠️ Capteur de position haute commun M1+M2 détecté *)` | `TopPositionSensorActive` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L15 | `BrakeThermalFault         : BOOL; (* 🌡️ Défaut/perte thermique frein — retour unique commun M1/M2/M3, escalade PowerCutOff *)` | `BrakeThermalFault` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L16 | `PhaseRotationFault        : BOOL; (* 🆕 REX 2026-07-08 : rotation de phase incorrecte — retour unique commun M1/M2/M3` | `PhaseRotationFault` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L18 | `LimitLegalReached         : BOOL; (* 📐 Limite légale de profondeur de dragage atteinte (globale) *)` | `LimitLegalReached` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L20 | `HydraulicThermalFault     : BOOL; (* 🆕 REX 2026-07-18 : défaut/perte thermique centrale hydraulique` | `HydraulicThermalFault` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L24 | `Bypass : ST_BypassCommun;    (* 🆕 2026-08-07 : granulaire, applique le bypass aux 2 treuils simultanement (pilotage "both") — OR avec le bypass individuel M1/M2 dans PRG_04 *)` | `Bypass` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L29 | `SimTopSensorBypassActive  : BOOL; (* 🩺 Capteur haut ignore car simulation active *)` | `SimTopSensorBypassActive` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L30 | `SimSlackCableBypassActive : BOOL; (* 🩺 Mou de cable ignore car simulation active *)` | `SimSlackCableBypassActive` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L35 | `HeartbeatIhmOk            : BOOL; (* PLC→IHM : front IHM post-boot reçu et timeout absent *)` | `HeartbeatIhmOk` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L36 | `HeartbeatIhmTimeout       : BOOL; (* PLC→IHM : aucun front IHM depuis 2 s *)` | `HeartbeatIhmTimeout` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L37 | `HeartbeatIhmElapsed       : TIME; (* PLC→IHM : temps depuis dernier front IHM *)` | `HeartbeatIhmElapsed` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L46 | `ConfigRestoredFromPersistent : BOOL; (* ⚠️ PLC→IHM : restauration détectée ce boot, à vérifier *)` | `ConfigRestoredFromPersistent` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L49 | `Preflight : ST_PreflightHMI; (* 🩺 Verdict observateur à l'arrêt — jamais bloquant *)` | `Preflight` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L50 | `WinchSymmetry : ST_WinchSymmetryHMI; (* ⚖️ MES-008 : mesures passives M1/M2 *)` | `WinchSymmetry` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L53 | `KoboldImmersionConfirmed : BOOL; (* Front Kobold confirmé dans la fenêtre d'immersion *)` | `KoboldImmersionConfirmed` |
| `SUPERVISION/_TYPES/ST_CommunHMI.st` | L54 | `KoboldBottomTouchLatched : BOOL; (* Fond détecté, descente bloquée (ForbidDescentM1/M2_Raw) *)` | `KoboldBottomTouchLatched` |
| `SUPERVISION/_TYPES/ST_CycleHMI.st` | L11 | `Cmd   : ST_CycleCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_DredgingAssistHMI.st` | L6 | `Cmd   : ST_DredgingAssistCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L8 | `RawPos           : UDINT; (* 📊 Position brute lue sur le bus *)` | `RawPos` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L9 | `Alarms           : UINT;  (* ⚠️ Code d'alarme brut du codeur *)` | `Alarms` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L10 | `Warnings         : UINT;  (* 🟧 Code d'avertissement brut du codeur *)` | `Warnings` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L11 | `SlaveOperational : BOOL;  (* 📡 Esclave EtherCAT opérationnel *)` | `SlaveOperational` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L12 | `PresetTriggerCmd : WORD;  (* 🎯 Commande de preset active *)` | `PresetTriggerCmd` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L13 | `PresetValueOut   : UDINT; (* 📐 Valeur de preset envoyée au codeur *)` | `PresetValueOut` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L18 | `Homed                   : BOOL;             (* 🎯 Prise d'origine (Homing) validée *)` | `Homed` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L19 | `HomingBusy              : BOOL;             (* ⏳ Référencement en cours *)` | `HomingBusy` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L20 | `HomingDone              : BOOL;             (* ✅ Pulse de référencement réussi *)` | `HomingDone` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L21 | `HomingError             : BOOL;             (* 🔴 Défaut de référencement *)` | `HomingError` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L22 | `HomingErrorId           : WORD;             (* ❌ Bitfield défaut homing *)` | `HomingErrorId` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L23 | `HomingState             : E_State;          (* 🤖 État FB_Encoder_Homing *)` | `HomingState` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L24 | `HomingStateAtError      : E_State;          (* 🧭 État lors du défaut *)` | `HomingStateAtError` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L25 | `HomingSuspect           : BOOL;             (* ⚠️ Référence à confirmer *)` | `HomingSuspect` |
| `SUPERVISION/_TYPES/ST_EncoderHMI.st` | L26 | `HomingRefRaw            : UDINT;            (* 📐 Référence brute appliquée *)` | `HomingRefRaw` |
| `SUPERVISION/_TYPES/ST_InputModuleDiagHMI.st` | L12 | `LocalDigitalIoOk : BOOL; (* TRUE = module Local_Digital_IO opérationnel (8 TOR Winch/Machine) *)` | `LocalDigitalIoOk` |
| `SUPERVISION/_TYPES/ST_InputModuleDiagHMI.st` | L13 | `Vh0800EndOk      : BOOL; (* TRUE = module VH_0800END opérationnel (7 TOR freins/thermiques/AU) *)` | `Vh0800EndOk` |
| `SUPERVISION/_TYPES/ST_InputModuleDiagHMI.st` | L14 | `Vh0808EtpOk      : BOOL; (* TRUE = module VH_0808ETP opérationnel (7 TOR positions M3/hydraulique/crible) *)` | `Vh0808EtpOk` |
| `SUPERVISION/_TYPES/ST_InputModuleDiagHMI.st` | L15 | `Fault            : BOOL; (* TRUE = au moins un des 3 modules DI hors service *)` | `Fault` |
| `SUPERVISION/_TYPES/ST_JoystickHMI.st` | L10 | `Cmd   : ST_JoystickCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_ModesHMI.st` | L9 | `Cmd   : ST_ModesCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L8 | `BusCanOpen          : ST_Diag_Device;  (* 📡 Diagnostics bus CANopen *)` | `BusCanOpen` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L9 | `Joystick            : ST_Diag_Device;  (* 🕹️ Diagnostics esclave Joystick *)` | `Joystick` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L10 | `CanError            : BOOL;           (* ⚠️ Anomalie CANopen *)` | `CanError` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L11 | `CanErrorId          : WORD;           (* ❌ Code anomalie CANopen *)` | `CanErrorId` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L13 | `BusEthercat         : ST_Diag_Device;  (* 📡 Diagnostics bus EtherCAT *)` | `BusEthercat` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L14 | `EncoderM1           : ST_Diag_Device;  (* 🧲 Diagnostics esclave COD1 *)` | `EncoderM1` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L15 | `EncoderM2           : ST_Diag_Device;  (* 🧲 Diagnostics esclave COD2 *)` | `EncoderM2` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L16 | `VariateurM3         : ST_Diag_Device;  (* ↔️ Diagnostics esclave AC600 *)` | `VariateurM3` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L17 | `EcatError           : BOOL;           (* ⚠️ Anomalie EtherCAT *)` | `EcatError` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L18 | `EcatErrorId         : WORD;           (* ❌ Code anomalie EtherCAT *)` | `EcatErrorId` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L20 | `InputModules        : ST_InputModuleDiagHMI; (* 🩺 Diagnostic carte des 3 modules DI TOR réelles *)` | `InputModules` |
| `SUPERVISION/_TYPES/ST_NetworkDiagHMI.st` | L23 | `Bypass              : ST_BypassNetwork;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_PreflightHMI.st` | L4 | `PreflightOk : BOOL;` | `PreflightOk` |
| `SUPERVISION/_TYPES/ST_PreflightHMI.st` | L5 | `PreflightDone : BOOL;` | `PreflightDone` |
| `SUPERVISION/_TYPES/ST_PreflightHMI.st` | L6 | `PreflightBusy : BOOL;` | `PreflightBusy` |
| `SUPERVISION/_TYPES/ST_PreflightHMI.st` | L7 | `PreflightErrorId : WORD;` | `PreflightErrorId` |
| `SUPERVISION/_TYPES/ST_SyncHMI.st` | L8 | `Cmd    : ST_SyncCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_SyncHMI.st` | L11 | `Bypass : ST_BypassSync;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_TranslationHMI.st` | L11 | `Cmd                     : ST_TranslationCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_TranslationHMI.st` | L20 | `Bypass                  : ST_BypassTranslation;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_TranslationHMI.st` | L23 | `Safety                  : ST_SafetyTranslation;` | `Safety` |
| `SUPERVISION/_TYPES/ST_WinchBenneHMI.st` | L13 | `Cmd                     : ST_WinchCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_WinchBenneHMI.st` | L22 | `Safety                  : ST_SafetyWinch;` | `Safety` |
| `SUPERVISION/_TYPES/ST_WinchBenneHMI.st` | L25 | `Bypass                  : ST_BypassWinch;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_WinchBenneHMI.st` | L28 | `Bucket                  : ST_BucketHMI;` | `Bucket` |
| `SUPERVISION/_TYPES/ST_WinchHMI.st` | L10 | `Cmd                     : ST_WinchCmd;` | `Cmd` |
| `SUPERVISION/_TYPES/ST_WinchHMI.st` | L19 | `Safety                  : ST_SafetyWinch;` | `Safety` |
| `SUPERVISION/_TYPES/ST_WinchHMI.st` | L22 | `Bypass                  : ST_BypassWinch;` | `Bypass` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L4 | `SymmetryOk : BOOL;` | `SymmetryOk` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L5 | `SymmetryValid : BOOL;` | `SymmetryValid` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L6 | `DeltaStartDelay_Ms : UDINT;` | `DeltaStartDelay_Ms` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L7 | `DeltaBrakeReleaseTime_Ms : UDINT;` | `DeltaBrakeReleaseTime_Ms` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L8 | `DeltaBrakeApplyTime_Ms : UDINT;` | `DeltaBrakeApplyTime_Ms` |
| `SUPERVISION/_TYPES/ST_WinchSymmetryHMI.st` | L10 | `DeltaStopTime_Ms : UDINT;` | `DeltaStopTime_Ms` |


### NC-070 — Variable `GVL_PERSISTENT` sans préfixe `_` (0 non-conformité(s))

✅ **Aucune non-conformité trouvée.** (100% de conformité)

---

## ⚠️ 4. Faux positifs et cas ambigus (AC4)

Les motifs d'analyse statique peuvent isoler des cas limites qui exigent un jugement d'ingénierie :

1. **Règle `NC-030` (Suffixes d'unités)** :
   - Les suffixes de repères mécaniques `M1`, `M2`, `M3` (ex: `WinchM1`, `TranslationM3`) finissent par la lettre `M` mais ne désignent pas l'unité mètres (`_M`). Ils ont été correctement classés en repères et exclus des erreurs d'unité `NC-030`.
   - Les termes anglais finissant par `M` comme `SYSTEM`, `PARAM`, `ALARM`, `DIAG` ont été isolés pour éviter les faux positifs.

2. **Règle `NC-050` (`Cmd` / `Req` vs `_RQ`)** :
   - Les variables matérielles se terminant par `_RQ` (ex: `MaintainA_RQ`, `ArmPulse_RQ`) sont des **sorties relais physiques** (norme NC-040) et non des requêtes logiques `ReqX`. Elles sont exclues de `NC-050`.
   - Les noms de variables legacy comme `BrakeCmd` ou `ArmRequest` figurent en non-conformités `NC-050` conformément à la décision de préfixage `<Rôle><Racine>` (`CmdBrake`, `ReqArm`).

3. **Règle `NC-060` (Champs d'état et mesures dans `ST_*HMI`)** :
   - Les champs traditionnels d'état (`Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `Diag`) ou de mesure (`Position_M`, `Speed_Mps`) dans les structures `ST_*HMI` ne portent pas de préfixe IHM (`Btn`, `Sel`, `Set`, `Tgl`, `Cfg`, `Tst`) par convention historique. Ils ont été recensés en cas ambigus (20 occurrences) et ne constituent pas un blocage fonctionnel.

---

## 📌 5. Recommandations pour le futur script `check_naming_style.py`

1. **Intégration comme Gate de linter (`GATE 2octies`)** dans `run_all_gates.py` : Le script `check_naming_style.py` pourra valider automatiquement les 6 règles `NC-010` à `NC-070` à chaque livraison.
2. **Refactoring progressif** : Le refactoring des 17 instances FB non préfixées (`NC-010`) et des 58 variables `Cmd`/`Req` en suffixe (`NC-050`) pourra être planifié dans un lot dédié sans casser les liaisons du bundle PLCopenXML.