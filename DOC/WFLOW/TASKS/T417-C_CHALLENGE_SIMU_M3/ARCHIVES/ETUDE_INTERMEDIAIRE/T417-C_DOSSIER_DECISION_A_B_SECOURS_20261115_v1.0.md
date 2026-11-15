# T417-C — Dossier Décisionnel : Plans A / B / Secours & Protocole de Test

> **Statut :** Prêt pour exécution et test au retour exploitant (`CODE/` strictement intact en lecture seule).
> **Sources vérifiées :** Audit `CODE/` + `DOC/` + Trace 27 complète (`Suivi_TranslationM3bug_20260904_27_wide.csv`) + matrice sandbox `plan_abc_matrix.py`.

---

## 1. Ce qui est PROUVÉ vs ce qui reste À VÉRIFIER

### ✅ Faits PROUVÉS (code & trace 27 complète)
1. **Trace 27 complète (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27_wide.csv`, 352 échantillons jusqu'à 35 137 ms) :**
   - `t = 26 438 ms` : `M3_PosTremie_DI` `0→1`, `M3_CommandWord` `1→0`, `M3_SetpointFrequencyHz` `1000→0`, `M3_BrakeIsOpen_DI` `1→0`, `State.ErrorId` `0→64`.
   - `t = 26 553 ms` (+115 ms) : `M3_PosTremie_DI` `1→0` (perte capteur), `M3_ActualFrequencyHz = 913` (9,13 Hz réels sur variateur AC600 `C00.01`), `M3_BrakeIsOpen_DI = 0`.
   - `t = 26 637 → 27 056 ms` : décélération variateur régulière `7,46 → 4,84 → 2,23 → 0,68 → 0,00 Hz` (~618 ms, ~16,2 Hz/s), **`CommandWord = 0` et `Setpoint = 0` jusqu'à 35 137 ms**. Aucune ré-énergisation automatique sur cette trace.
   - `M3_PosTremie_DI` reste à `0` jusqu'à 35 137 ms : le chariot n'est pas revenu sur la came.
2. **Sémantique des signaux :**
   - `M3_BrakeIsOpen_DI` (`%IX225.2`, `PRG_02_Acquisition.st:175`) = **retour contacteur frein** (pas un ordre, et ne mesure pas le couple/usure des mâchoires).
   - `DriveActualFreqHz` (`PRG_05_Translation.st:497`) = **fréquence réelle délivrée** par l'AC600 (`C00.01`, `%IW9 / 100`).
3. **`ErrorId = 64` (`16#0040`, bit 6) est AUTO-RESET (`Latching := FALSE`) :**
   - Prouvé dans `FB_Safety_Translation.st:209` et `FB_Translation.st:142` (`FB_FaultCore.st:49-69`).
   - Tant que `ErrorId = 64` est actif, il inhibe `EffectivePermitM3_Tremie` (`PowerCutOff` masque `16#00F8`, `FB_Safety_Translation.st:269`) et `BrakeReleaseRequest` (`FB_Translation.st:362-366`).
   - Mais dès que `M3_PosTremie_DI` retombe à `0` (franchissement de came) ou que la demande retombe, `ErrorId = 64` s'efface **sans Reset** — un second ordre opérateur peut donc ré-énergiser au-delà de la came.
4. **Asymétrie Maintenance prouvée (`PRG_06_Outputs.st:431-451`) :**
   - Trémie possède `M3_TremieHardStopActive` + `AND NOT M3_PosTremie_DI` + coupure `BrakeReleaseRequest` / `RequestedDrive*`.
   - Maintenance (`PRG_06_Outputs.st:441`) passe `EffectivePermitM3_Maintenance` **sans** `AND NOT M3_PosMaintenance_DI` ni `M3_MaintenanceHardStopActive`.
5. **Plafond odométrique bloquant (`FB_Translation_OdometryGain.st:57`) :**
   - `CST_GainMax : REAL := 0.05;` rejette le gain d'audit `0,0551 m/(Hz·s)` (`FB_Sim_Translation.st:156`) et le rabat sur `FallbackGain = 0.02`.

### ❓ Incertitudes terrain à lever au retour (4 points max)
1. **Distance réelle came Trémie ↔ butée mécanique** sur machine (vs `0,50 m` arbitraire dans `GVL_Simulation.st:64`) + **longueur utile de la came Trémie**.
2. **Gain réel `k` de translation M3** (`0,0551` vs `0,02 m/(Hz·s)`) — chronométrage sur 2 repères à ~9–10 Hz.
3. **Temps réel de fermeture mécanique + décélération du frein** (usure/humidité/pente vs `0,09 s / 2,0 m/s²`).
4. **Mode actif** lors des incidents récurrents (Trémie Manu avec reprise d'ordre, Trémie SEMI_AUTO, ou Maintenance).

---

## 2. Matrice quantitative sandbox (`plan_abc_matrix.py`)

| Scénario | Pénétration (`pen_m`) | Choc butée (`hit`) | Vitesse choc (`impact_mps`) | Ré-énergisations |
|---|---:|:---:|---:|---:|
| `BASE-5Hz` (simu actuel `k=0.02`, frein `0.09s/2.0`) | `0.008 m` | `False` | `0.0` | `0` |
| `BASE-10Hz` (simu actuel, trou came `4 cm`) | `0.0836 m` | `False` | `0.0` | `1` |
| `PLAN-A1-BUG` (10 Hz, came finie `4 cm`, frein `0.25s/0.8`, sans latch) | `0.5003 m` | **`True`** | `0.2` | `1` |
| `PLAN-A1-FIX` (10 Hz, came finie `4 cm`, frein `0.25s/0.8`, **AVEC LATCH**) | `0.0486 m` | `False` | `0.0` | `0` |
| `PLAN-A2-BUG` (5 Hz, Maintenance sans HardStop `PRG_06:441`) | `0.5000 m` | **`True`** | `0.1` | `0` |
| `PLAN-A2-FIX` (5 Hz, Maintenance **AVEC HardStop + Latch**) | `0.0080 m` | `False` | `0.0` | `0` |
| `PLAN-B1-NOMINAL` (10 Hz, Trace 27 `Cmd=0`, `k=0.0551`, frein `0.09s/2.0`) | `0.1137 m` | `False` | `0.0` | `0` |
| `PLAN-B1-DEGRADE` (10 Hz, Trace 27 `Cmd=0`, `k=0.0551`, frein `0.30s/0.35`) | `0.4559 m` | `False` | `0.0` | `0` |
| `PLAN-B2-FIX` (**5 Hz PV réduit**, `k=0.0551`, frein `0.30s/0.35`) | `0.1178 m` | `False` | `0.0` | `0` |

*(Lecture critique : à `k=0.0551` + frein dégradé `0.30s/0.35`, même avec `Cmd=0` immédiat comme Trace 27, le chariot glisse déjà à **`0,456 m`** — il heurte dès que la marge réelle < 45 cm ou en légère pente !)*

---

## 3. Plan A — Route principale (à implémenter & tester en premier au retour)

### Sous-plan A0 (C2 — `CODE/L_SIMULATION/` uniquement, sans toucher production)
- **But :** Supprimer les 2 angles morts du simulateur pour reproduire et tester fidèlement.
- **Modifications prêtes à coder après GO :**
  1. `CODE/L_SIMULATION/FB_Sim_PositionSensor.st` + `GVL_Simulation.st` : exposer un mode came finie configurable (`SimM3SensorFiniteCam_BOOL` / longueur came) en plus de `CamDropoutActive`.
  2. `CODE/L_SIMULATION/FB_Sim_Translation.st` / `GVL_Simulation.st` : exposer `SimM3GainMetersPerHzSec` (testable jusqu'à `0.06` en banc) et `SimM3BrakeCloseDelay_S` (actuellement figé à `0.09` dans `FB_Sim_TranslationBrake.st:9`).
  3. `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/test_m3_sandbox.st` : ajouter les cas `S1` (came finie / perte DI), `S3` (Maintenance) et `S4` (gain 0.0551 + frein dégradé).

### Sous-plan A1 & A2 (Bascule C3/C4 requise — `CODE/M_MAIN/PRG_06_Outputs.st`)
- **But :** Éliminer les 2 failles automates avérées quel que soit le frein/came :
  1. **Verrou directionnel post-came Trémie (A1)** : mémoriser `M3_TremieHardStopLatched` au front `M3_PosTremie_DI` tant que l'axe n'est pas réarmé par `Reset` explicite (ou recul avéré vers Maintenance / sortie de butée en sens opposé). **Ne jamais verrouiller le sens retour P1/Maintenance.**
  2. **Symétrie Maintenance (A2 — `PRG_06_Outputs.st:441`)** : ajouter `M3_MaintenanceHardStopActive` avec `M3_PosMaintenance_DI` (et `ReqMaintenanceSemantic` à ajouter dans `ST_TranslationFinalInterlockRequest` + `PRG_05_Translation.st:709`), ou vérifier d'abord la polarité thermomètre (`2#00000` à l'extrême Maintenance, `FB_Translation_PositionDecoder.st:88` !).
  - ⚠️ **Attention critique A2 :** D'après `FB_Translation_PositionDecoder.st:88`, à l'extrême Maintenance tous les capteurs sont à `0` (`SensorsWord = 2#00000`), donc `M3_PosMaintenance_DI` vaut `0` à l'extrême Maintenance et `1` avant ! **Ne pas copier-coller `AND NOT M3_PosTremie_DI` à l'aveugle sans vérifier le sens actif de `M3_PosMaintenance_DI` (`NO` à `0` ou `1` au-delà de P1).**

### Protocole de test immédiat au retour (15 min)
1. **Test 1 (Banc C2)** : activer A0 dans `L_SIMULATION`, lancer `G200_check_linkage.py --report` + `run_all_gates.py --palier C` + scénario sandbox CODESYS (`10 Hz` + came finie + frein `0.25s/0.8`).
2. **Test 2 (Terrain / Trace)** : chronométrer 1 trajet P2↔PV à 10 Hz (`k` réel) + vérifier marge physique came Trémie → tampon mécanique.

---

## 4. Plan B — Routes de secours si Plan A ne suffit pas

### Cas de déclenchement Plan B :
> *Si le test montre que `Cmd=0` est bien immédiat (pas de ré-énergisation) et qu'il n'y a pas d'incident en Maintenance, mais que le chariot glisse quand même au-delà de la came à cause de `k=0,0551` + frein lent (`0,456 m` en sandbox).*

- **Sous-plan B1 (Calibration odométrie + frein) :**
  1. Relever `CST_GainMax` dans `CODE/I_TRANSLATION/FB_Translation_OdometryGain.st:57` (ex. `0.05` → `0.07`, avec contrat C3/C4) si le `k` mesuré terrain dépasse `0.05`.
  2. Vérifier mécaniquement le frein M3 (entrefer, ressort, garnitures, temps entre `M3_BrakeIsOpen_DI 1→0` et arrêt effectif).
- **Sous-plan B2 (Réduction vitesse d'approche PV — `5 Hz` au lieu de `10 Hz`) :**
  - Preuve sandbox : à **`5 Hz`**, même avec `k=0.0551` et frein très dégradé (`0.30s / 0.35 m/s²`), la pénétration tombe de **`0,4559 m` → `0,1178 m`** (division par ~3,9×).
  - Implémentation candidate : abaisser la consigne petite vitesse d'approche finale après `M3_PosPV_DI` (ou en zone Trémie) de 10 Hz à 5 Hz.

---

## 5. Plan C — Route de secours ultime (si blocage terrain ou défaut matériel)

### Cas de déclenchement Plan C :
> *Si les capteurs/cames ou le frein ont une dérive matérielle non corrigible immédiatement par logiciel.*

1. **Secours C1 (Logique — anti-perte capteur) :** Utiliser la logique thermomètre (`FB_Translation_PositionDecoder.st`) : si `M3_PosTremie_DI` retombe à `0` alors que le dernier état connu était `11111` et aucun mouvement vers Maintenance n'a eu lieu, maintenir l'interdit Trémie jusqu'à ré-acquisition P1/PV ou `Reset` conscient.
2. **Secours C2 (Exploitation immédiate) :** Brider temporairement la consigne PV IHM/variateur à `5 Hz` et contrôler le serrage/entrefer du frein M3 avant reprise en `SEMI_AUTO`.

---

## 6. Matrice de décision rapide au retour

| Observation au test | Décision immédiate |
|---|---|
| `M3_PosTremie_DI` se perd puis l'axe repart sur nouvel ordre | Appliquer **Plan A1** (Latch directionnel Trémie, C3/C4) |
| Dépassement observé en mode Maintenance | Vérifier polarité `M3_PosMaintenance_DI` puis appliquer **Plan A2** (C3/C4) |
| `Cmd=0` reste à 0 mais glissade > marge came→butée | Appliquer **Plan B2** (PV `5 Hz` -> `0,118 m`) + contrôle frein (**Plan B1**) |
| Gain mesuré terrain > `0,05 m/(Hz·s)` | Appliquer **Plan B1** (`CST_GainMax` dans `FB_Translation_OdometryGain.st:57`) |
| Capteur came trop court / rebond mécanique avéré | Appliquer **Plan C1** (verrou thermomètre) + reprise mécanique came |
