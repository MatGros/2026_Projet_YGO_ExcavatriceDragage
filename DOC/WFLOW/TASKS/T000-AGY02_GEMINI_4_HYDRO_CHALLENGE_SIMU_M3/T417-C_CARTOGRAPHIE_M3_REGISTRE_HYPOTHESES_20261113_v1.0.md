# 🗺️ Cartographie `M3` & Registre d'Hypothèses (`T417-C`)

> **Statut :** Phase 1 — Lecture seule vérifiée sur `CODE/`.
> **Objectif :** Séparer strictement **(A) Chaîne Automate Réelle** et **(B) Modèle Simulateur**, puis lister les hypothèses testables en Phase 2.

---

## A. Chaîne Automate Réelle (`CODE/M_MAIN/` + `CODE/I_TRANSLATION/`)

1. **Coupure ultime Trémie (`PRG_06_Outputs.st:431-451`)**
   - `M3_TremieHardStopActive := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic`
   - Si `TRUE` : coupe `BrakeReleaseRequest`, `RequestedDriveControlWord := 0`, `RequestedDriveFreqHz := 0.0` dans le même scan.
   - **Failles identifiées :**
     - **F1 (Armement sur requête)** : si `ReqTremieSemantic` retombe (ex. relâchement homme-mort en Manu pendant l'inertie, ou veto `SEMI_AUTO` à `PRG_05:715-721`), `M3_TremieHardStopActive` retombe à `FALSE`.
     - **F2 (Aucun verrou post-FDC)** : si le chariot franchit la came (`M3_PosTremie_DI` retombe à `0`, comme en trace 27 à `26553 ms`), `M3_TremieHardStopActive` et `EffectivePermitM3_Tremie` (`PRG_06:439-440`) repassent à `TRUE`.
     - **F3 (Asymétrie Maintenance)** : `PRG_06_Outputs.st:441` n'a ni `MaintenanceHardStopActive` ni `AND NOT M3_PosMaintenance_DI`.
2. **Détection Overrun (`FB_Translation.st:137-141`, `FB_Safety_Translation.st:200-204`)**
   - `TonLimitSwitchOverrun` exige **1,5 s** continues (`T#1S500MS`) avec `Commanded*` (ou `ABS(DriveActualFreqHz) > 0.5`) ET `LimitSwitch*` actif simultanément.
   - Si le capteur est perdu avant 1,5 s ou si la commande est coupée au scan capteur, la cause 6 (`ErrorLimitSwitch` / `SafeStop`) ne monte pas sur ce mécanisme seul.

> ⚠️ **Alerte Criticité (`WORKFLOW.md`) :** Toute correction sur `PRG_06`, `FB_Translation` ou `FB_Safety_Translation` sort du périmètre `C2` (`CODE/L_SIMULATION/`) et impose une bascule **C3/C4** (contrat dédié + double revue A/B + validation humaine).

---

## B. Modèle Simulateur (`CODE/L_SIMULATION/`)

1. **Pourquoi la simulation s'arrête proprement à 5–10 Hz :**
   - `FB_Sim_TranslationDrive.st:57-61` : force `ActualFrequency_Hz := 0.0` sous `0,5 Hz`.
   - `FB_Sim_Translation.st:336-338` : tant que `BrakeMechanicallyOpen`, `VelocityTrue_Mps := VelocityTarget_Mps` (vitesse esclave du variateur, sans inertie propre).
   - `FB_Sim_TranslationBrake.st:74-83` : avec `PhysicalBrakeActive = TRUE`, le frein ferme en `0,09 s` (`CloseDelay_S`) après coupure bobine, puis `BrakeDecel_Mps2 = 2,0 m/s²`.
   - **Distance d'arrêt résultante** : **0,80 cm** à 5 Hz et **2,17 cm** à 10 Hz, contre `SimM3EndStopMargin_M = 0,50 m` (`GVL_Simulation.st:64`).
   - **`ObsCartFree` inhibé** (`FB_Sim_Translation.st:302`) : `DriveTorqueActive` reste `TRUE` pendant la rampe, puis la vitesse est mise à `0` à `0,5 Hz` et le frein est déjà fermé à `0,09 s`.

---

## C. Registre d'Hypothèses pour Reproduction Phase 2 (Sandbox)

| ID | Hypothèse physique / automate | Paramètre ou mécanisme ciblé | Impact attendu en petite vitesse (5–10 Hz) |
|---|---|---|---|
| **H1** | **Perte de came / rebond capteur (`M3_PosTremie_DI` 1→0)** pendant le roulis | `CamDropoutActive` (`FB_Sim_PositionSensor.st:114-120`) + ré-ouverture permis `PRG_06:439-440` | Permet une ré-alimentation ou perte de coupure si l'ordre marche est maintenu (similaire trace 27 `26553 ms`). |
| **H2** | **Retard de fermeture / couple de freinage réel dégradé** | `BrakeCloseDelay_S` (> 0,09 s) et `BrakeDecel_Mps2` (< 2,0 m/s², ou montée progressive) | Allonge la distance de freinage au-delà de quelques cm si l'inertie n'est pas annulée par le variateur. |
| **H3** | **Inertie chariot & glissement rail** (chariot non esclave de la fréquence) | Découplage `VelocityTrue_Mps` vs `VelocityTarget_Mps` quand couple variateur = 0 ou frein glissant | Permet au chariot de continuer sur son élan (`ObsCartFree` ou glissement) même après `ActualFrequency_Hz <= 0,5 Hz`. |
| **H4** | **Latence capteur / debounce / scan** | `ElectricalDelayS` + `CaptorDebounce` + +1 scan `PRG_05 → PRG_06` | À `0,20 m/s`, `100 ms` = `2 cm` (secondaire seul, cumulatif avec H2/H3). |
| **H5** | **Maintien ordre marche opérateur (Manu) ou défaut réarmement** | Relâchement puis reprise ou maintien `ReqTremie` pendant franchissement came | Teste la faille `F1`/`F2` de `PRG_06_Outputs.st:431-451`. |
| **H6** | **Asymétrie côté Maintenance** (`PRG_06_Outputs.st:441`) | Approche P1/Maintenance sans `HardStop` ni `AND NOT DI` brut | Vérifie si le dépassement est encore plus facile côté Maintenance. |
