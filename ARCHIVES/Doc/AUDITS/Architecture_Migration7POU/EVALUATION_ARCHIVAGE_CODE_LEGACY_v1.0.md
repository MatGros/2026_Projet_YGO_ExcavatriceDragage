# Évaluation & archivage du code legacy — état implémenté avant migration

> 📄 **Nature : trace documentaire de l'existant + classification d'archivage.**
> 🎯 **But :** figer ce qui était **implémenté à l'époque** (avant migration 7 POU) et décider
> **quoi garder / quoi archiver**, sans perte d'information de câblage.
> 🗂️ **Pilotage, pas une spec.** Détail ligne à ligne des PRG MAIN : [`AUDIT_M0_GEL_ETAT_INITIAL.md`](AUDIT_M0_GEL_ETAT_INITIAL.md).
> ⏳ **Date** : 2026-08-03 · **Décision** : archivage **au fil des lots** (M1→M8) — un PRG legacy
> n'est déplacé vers `ARCHIVES/Code/` qu'au moment où son POU cible le remplace.

---

## 0. Méthode

| Élément | Valeur |
|---|---|
| Source cible | AF02 v3.0 §2/§4, `DIAGRAMME_ARCHITECTURE_CFC_TARGET.md`, AF03/AF06/AF08/AF09 v2.x |
| Référence code | `CODE/` actuel (161 fichiers `.st` + 1 CFC natif, hors `CODE_Bundle.xml` généré) |
| Inventaire détaillé PRG | `AUDIT_M0_GEL_ETAT_INITIAL.md` (13 PRG, 3215 lignes) |
| Règle | `ARCHIVES/` n'est **jamais** une source active |
| Statut | ⚠️ Code legacy = **en migration** : bundle déjà rouge (réf. pendantes `PRG_01_Diagnostics`/`PRG_02_Encoders`/`PRG_05_Cycle`) — assumé |

**Légende** : 🟢 **GARDE** = réutilisé par la cible (reste dans `CODE/`, adapté au lot concerné) ·
🟠 **ARCHIVER** = remplacé par la cible (→ `ARCHIVES/Code/` au lot indiqué) ·
🔴 **PENDANT** = POU cité mais absent du dépôt (référence à nettoyer au lot concerné).

---

## 1. Programmes `MAIN/` — 7 PRG cibles vs legacy

| Legacy (`CODE/MAIN/`) | Type | Cible qui le remplace | Décision | Lot |
|---|---|---|---|---|
| `PRG_01_Inputs_LD` *(absent)* | Ladder | `PRG_01_Inputs_LD` (créer, 22 `FB_Input`) | 🔴 réf. pendante → créer | M1 |
| `PRG_02_Acquisition_CFC.xml` | CFC natif (bridge) | `PRG_02_Acquisition_CFC` (cible : SEL inline, gate joy) | 🟠 archiver | M1 |
| `PRG_MODES_CFC` | CFC | `PRG_03_Modes_Cycle_CFC` | 🟠 archiver | M2 |
| `PRG_SAFETY_CFC` | CFC | absorbé (safety en parallèle Treuils/Translation) | 🟠 archiver | M3/M5 |
| `PRG_TREUILS_CFC` | CFC | `PRG_04_Treuils_Benne_CFC` | 🟠 archiver | M3 |
| `PRG_TRANSLATION_CFC` | CFC | `PRG_05_Translation_CFC` | 🟠 archiver | M4 |
| `PRG_OUTPUTS_LD` | LD | `PRG_06_Outputs_LD` | 🟠 archiver | M5 |
| `PRG_SUPERVISION_CFC` | CFC | `PRG_07_Supervision_CFC` | 🟠 archiver | M6/M7 |
| `PRG_TROUBLESHOOTING_CFC` | CFC | absorbé par `PRG_07` | 🟠 archiver | M7 |
| `GVL_Global`, `GVL_BypassRetain`, `GVL_Troubleshooting` | GVL | à migrer selon contenu | 🟠 archiver | lot concerné |

**Câblage PRG legacy (capturé avant archivage — référence de non-régression)** :

| PRG legacy | Instances / sorties clés | Consommateurs |
|---|---|---|
| `PRG_MODES_CFC` | `instModes : FB_Modes` → `Auth : ST_Modes_Autorisations` | tous |
| `PRG_SAFETY_CFC` | `instSafetyWinchM1/M2`, `instSpeedMonitorM1/M2`, `instLoadEstimatorM1/M2`, `instSafetyTranslationM3` | PRG_06 |
| `PRG_TREUILS_CFC` | `instWinchSync`, `instBucket`, `instWinchM1/M2`, `instDiveSearch`, `instExtractionSequence` → `FinalInterlockRequest` | PRG_06 |
| `PRG_TRANSLATION_CFC` | `instTranslationM3 : FB_Translation`, `SelTarget 0-4` (PV jamais cible) → `FinalInterlockRequest` | PRG_06 |
| `PRG_OUTPUTS_LD` | `instWinchOutputInterlockM1/M2_LD`, `instTranslationOutputInterlock_LD`, `instSafetyEmergencyManagement` ; relais M1/M2, contacteurs, freins, `PowerKeepAlive`, `EmergencyArming` | physique |
| `PRG_SUPERVISION_CFC` | mapping IHM↔PERSISTENT, `FaultMachineReset_IHM`, 6× `instCfgPersistBridge*`, `instBlink1Hz` | IHM |
| `PRG_TROUBLESHOOTING_CFC` | lecture seule, `instPreflight`, `instWinchSymmetry`, diags barrières | IHM diag |

---

## 2. FB — classification par domaine

### 🟢 JOYSTICK (GARDE, lot M1)
`FB_Joystick` (cible AF08 §2, `DeadmanReconfEnable` 2026-08-03) · `FB_AxisScale` · `FB_Filter_PT1` · `ST_Joystick_AxisCmd`.

### 🟢 CODEURS (GARDE, lot M1/M3)
`FB_Encoder_Abs` · `FB_Encoder_Scale` · `FB_Encoder_Homing` (→ PRG_04, pas PRG_02) · `FB_Encoder_Safety` · `FB_Encoder_SpeedMeasure` · `FB_Encoder_SpeedMonitor` · `ST_Encoder_Calib`.

### 🟢 DIAG (GARDE, lot M1 — instances dans PRG_02)
`FB_Diag_CanOpen` · `FB_Diag_Ethercat` · `FB_Diag_IhmHeartbeat` · `E_Diag_State` · `ST_Diag_Device`.

### 🟢 MODES / CYCLE (GARDE, lot M2)
`FB_Modes` (+ calcule l'agrégat `EncoderFault` M1 OR M2) · `E_Mode` · `FB_Cycle` · `FB_DiveSearch` · `FB_ExtractionSequence` + 3 enum.

### 🟢 TREUILS / TRANSLATION (GARDE, lots M3/M4/M5)
`FB_Winch` · `FB_Bucket` · `FB_WinchSync` · `FB_Safety_Winch` (+ `FB_DriftGuard`) · `FB_SpeedStep` · `FB_WinchLoadEstimator` · `FB_WinchOutputInterlock_LD` · `FB_Translation` · `FB_Safety_Translation` · `FB_Translation_PositionDecoder` · `FB_TranslationOutputInterlock_LD` + DUT/enum associés.

### 🟢 AU (GARDE, lot M5)
`FB_Safety_EmergencyManagement` + `_Logic` + `_Output` + 3 ST.

### 🟢 COMMUN (GARDE)
`FB_Input` · `FB_Output` · `FB_CycleTime` · `FB_Ramp` · `FB_Brake` · `FB_Acquisition_Preflight` · 6× `FB_CfgPersistBridge_*` · `ST_ContactorCheck` · `E_State`.

### 🟢 SIMULATION (GARDE)
`FB_SimBench` · `FB_Sim_Encoder` · `FB_Sim_Joystick` · `FB_Sim_Safety` · `FB_Sim_Translation` · `GVL_Simulation`.

### 🟢 DUT / GVL (GARDE)
Tous `ST_*` (`SUPERVISION/_TYPES` + domaines) · `GVL_IHM` · `GVL_PERSISTENT`.

---

## 3. POU à archiver dès le lot M1 (déjà remplaçables)

| Fichier | Cible | Lot |
|---|---|---|
| `ARCHIVES/Code/ACQUISITION/FB_AcquisitionLegacyBridge.st` | implémentation cible `PRG_02` (SEL inline + gate + chaîne codeurs) | M1 |
| `CODE/MAIN/PRG_02_Acquisition.st` | nouveau `PRG_02_Acquisition_CFC` | M1 |
| `ARCHIVES/Code/SUPERVISION/GVL_IHM_AU.st` | supprimé (décision T99) | lot dédié |

🔴 **Références pendantes à résoudre au M1** (POU absents du dépôt) :
`PRG_01_Diagnostics` (84 réf), `PRG_02_Encoders` (142 réf), `PRG_05_Cycle` (24 réf),
`PRG_AUXILIARY_CFC` (2 réf). Les FB cibles correspondants existent déjà (instances à recréer
dans les PRG cibles) — pas d'archivage nécessaire.

---

## 4. Plan d'archivage par lot (validé 2026-08-03)

| Lot | Archiver vers `ARCHIVES/Code/` | Créer / adapter dans `CODE/` |
|---|---|---|
| **M1** | `FB_AcquisitionLegacyBridge`, `PRG_02_Acquisition_CFC.xml` | `PRG_01_Inputs_LD`, `ST_InputsQualified`, `ST_EncoderMeasurements`, nouveau `PRG_02` ; résoudre réf. pendantes acquisition |
| **M2** | `PRG_MODES_CFC` | `PRG_03_Modes_Cycle_CFC` |
| **M3** | `PRG_TREUILS_CFC`, `PRG_SAFETY_CFC` (partie winch) | `PRG_04_Treuils_Benne_CFC` |
| **M4** | `PRG_TRANSLATION_CFC` | `PRG_05_Translation_CFC` |
| **M5** | `PRG_OUTPUTS_LD`, `PRG_SAFETY_CFC` (partie safety) | `PRG_06_Outputs_LD` |
| **M6/M7** | `PRG_SUPERVISION_CFC`, `PRG_TROUBLESHOOTING_CFC`, GVL locaux | `PRG_07_Supervision_CFC` |

> Convention destination : conserver la structure — `ARCHIVES/Code/<dossier d'origine>/<fichier>`,
> suffixe `_vX.Y` ou `_OLD` le cas échéant (témoins : `PRG_00_Inputs_v1.0.st`,
> `PRG_ACQUISITION_CFC.st`, `FB_Safety_EmergencyManagement_OLD.st`).

---

## 5. Points de vigilance

- ⚠️ **AUDIT_M0_GEL_ETAT_INITIAL.md** reste la preuve ligne à ligne de ce qui était câblé ; le
  présent fichier en est la **classification décisionnelle** (pas un doublon).
- ⚠️ `FB_Output` : défini (AF03 §6) mais **jamais instancié** — statut cible TBD (AF06 §7). Non archivable.
- ⚠️ `FB_Ramp` dans `FB_Joystick` : retrait prévu (AF08 §8, décision non appliquée) — lot dédié, pas M1.
- ⚠️ Toute suppression de PRG legacy doit être **précédée** de la recréation de ses instances dans
  le PRG cible correspondant (sinon rouge L4/L13). Ordre : implémenter → lier → **puis** archiver.
