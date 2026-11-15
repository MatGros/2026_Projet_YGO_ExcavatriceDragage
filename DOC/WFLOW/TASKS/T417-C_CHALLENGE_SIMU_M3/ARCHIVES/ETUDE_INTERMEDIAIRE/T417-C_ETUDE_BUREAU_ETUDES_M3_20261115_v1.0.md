# T417-C — Étude Bureau d'Études Pluridisciplinaire M3 (Mécanique · Dynamique · Variateur · Automatisme · Simulation)

> **Rôle :** Synthèse Bureau d'Études (lecture seule stricte sur `CODE/`).
> **Complète :** `T417-C_DOSSIER_DECISION_A_B_SECOURS_20261115_v1.0.md`
> **Outil associé :** `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/be_dynamic_study.py`

---

## 1. Mécanique & Dynamique (Chariot + Benne Pendulaire + Rail de Carrière)

### 1.1 Effet du balancement de la benne lors du freinage d'urgence
- Dans une drague à benne suspendue (`LoadMassRatio = 0.5` dans `GVL_Simulation.st:85`, soit masse benne ≈ masse chariot), un arrêt brutal en `0,09–0,6 s` ne bloque que le chariot — la benne continue sur son élan (pendule $L \approx 4\text{ m}$, période $T \approx 4\text{ s}$).
- **Résultat `be_dynamic_study.py`** : l'angle pendulaire $\theta$ atteint `1,7°–4,6°` et exerce une **poussée horizontale cyclique** qui allonge la distance d'arrêt et peut remettre le chariot en mouvement si le frein glisse ou si `BrakeCloseDelay_S` est long.

### 1.2 Limite d'adhérence roue/rail en carrière noyée (facteur souvent oublié)
- Même avec un **frein mécanique neuf et instantané** (`0,09 s / 2,0 m/s²`), la décélération réelle du chariot est plafonnée par l'adhérence roue/rail : $a_{\max} = \mu \cdot g$.
- Sur rail sec ($\mu = 0,15 \Rightarrow 1,47\text{ m/s}^2$) à `10 Hz` avec `k = 0,0551 m/(Hz·s)` ($v_0 = 0,551\text{ m/s}$), l'arrêt avec pendule prend **`0,154 m`**.
- Sur **rail humide / boueux / gras** ($\mu = 0,06 \Rightarrow 0,59\text{ m/s}^2$), les galets patinent (`slip: True`) et la distance d'arrêt passe à **`0,471 m`** (**×3,05**, quasiment la butée `0,50 m` sans aucun défaut de frein !).
- Avec **frein dégradé** (`0,30 s / 0,35 m/s²`) + pendule à `10 Hz` (`k = 0,0551`), l'arrêt atteint **`1,005 m`** (**2×** la marge simulée).
- En réduisant la petite vitesse d'approche à **`5 Hz`** (`0,276 m/s`), même sous frein dégradé (`0,30 s / 0,35 m/s²`), la distance tombe à **`0,226 m`** (**division par 4,4×**).

### 1.3 Dimensionnement géométrique de la came Trémie (`L_came_min`)
- Pour que `M3_PosTremie_DI` reste à `1` jusqu'à l'arrêt complet (et ne retombe pas à `0` comme en Trace 27 à `+115 ms`), il faut $L_{\text{came}} > d_{\text{arrêt, dégradé}} + \text{hystérésis}$ :
  - À `k = 0,02`, `5 Hz` : $L_{\text{came,min}} \approx 0,15\text{ m}$ ; `10 Hz` : $\approx 0,16\text{ m}$.
  - À `k = 0,0551`, `5 Hz` : $L_{\text{came,min}} \approx 0,29\text{ m}$ ; `10 Hz` : $\approx 1,31\text{ m}$.
- **Conclusion mécanique :** Une came courte (4–15 cm) est **structurellement perdue** à `10 Hz` dès que `k ≈ 0,0551` ou sur rail humide. Si la came ne peut pas être allongée à > 0,30–0,50 m, l'automatisme **doit** mémoriser le passage (`Latch`) et/ou ralentir à `5 Hz` avant la zone finale.

### 1.4 Énergie d'impact sur butée ($\Delta E \propto v^2$)
- L'énergie cinétique à absorber par le tampon/structure varie comme le **carré de la vitesse** ($E = \frac{1}{2} m v^2$) :
  - Passer de `10 Hz` (`0,551 m/s`) à `5 Hz` (`0,276 m/s`) divise l'énergie d'impact par **4**.
  - Si `k = 0,0551` au lieu de `0,02` (`2,75×` plus vite), l'énergie cinétique réelle est **`7,6×` supérieure** à celle supposée par le simulateur actuel !

---

## 2. Électrotechnique & Variateur AC600

### 2.1 Coexistence frein mécanique / rampe variateur (Trace 27)
- Sur Trace 27 (`26 438 ms`), `M3_BrakeIsOpen_DI` retombe à `0` **au même échantillon** que `Setpoint 1000→0`, mais `M3_ActualFrequencyHz` (`C00.01`) continue de décroître de `10,00 Hz → 0,00 Hz` pendant **`618 ms`** (`~16,2 Hz/s`).
- **Point d'attention électrotechnique à vérifier sur variateur AC600 :**
  1. Le variateur est-il configuré en **arrêt sur rampe** (avec couple maintenu pendant `618 ms` pendant que le frein essaie de serrer — usure garnitures + lutte moteur/frein ?) ou en **arrêt roue libre (coast-to-stop)** où la fréquence `C00.01` suit simplement l'inertie du rotor ?
  2. Le temps réel entre coupure bobine (`M3_BrakeIsOpen_DI = 0`) et serrage effectif des mâchoires sur disque/tambour (`CloseDelay_S`) est-il de `0,09 s` ou plutôt `0,20–0,35 s` (ressorts fatigués, jeu d'entrefer, rémanence magnétique) ?

---

## 3. Automatisme & Architecture de Défense en Profondeur (`CODE/`)

### 3.1 Les 4 couches de défense indépendantes (sans modifier `CODE/` avant validation)

| Couche | Problème identifié dans `CODE/` | Solution Bureau d'Études | Criticité |
|---|---|---|---|
| **C1 — Prévention (Profil vitesse)** | Approche finale en PV jusqu'à `10 Hz` sur les derniers mètres (`M3_PosPV_DI` est à `5,0 m` de `Trémie` d'après `AF_Partie-11`). | Décélération anticipée ou bridage à **`5 Hz`** dès passage `M3_PosPV_DI` en approche Trémie (divise `d_arrêt` par ~4× et `E_choc` par 4×). | C3/C4 |
| **C2 — Détection Overrun** | `TonLimitSwitchOverrun = T#1S500MS` (`FB_Safety_Translation.st:203`, `FB_Translation.st:140`) est **aveugle** quand la came est traversée en `0,115 s` (13× trop long !). | Déclencher une alarme dédiée de **perte de came extrême** (`11111 → 01111` sans ordre Maintenance actif) en ≤ 2 scans, indépendamment du timer `1,5 s`. | C3/C4 |
| **C3 — Verrouillage directionnel** | `ErrorId = 64` (`Latching := FALSE`) et `PRG_06_Outputs.st:439-440` ré-ouvrent `EffectivePermitM3_Tremie` dès que `M3_PosTremie_DI` retombe à `0`. | Mémoriser `M3_TremieHardStopLatched` au front `M3_PosTremie_DI` tant que pas de `Reset` conscient + sens opposé (`Maintenance`). Idem côté Maintenance (`PRG_06:441`) après vérif polarité `2#00000`. | C3/C4 |
| **C4 — Fidélité Simulateur** | `FB_Sim_PositionSensor.st` a une came infinie après trou ; `FB_Translation_OdometryGain.st:57` bloque `k > 0,05` ; `CloseDelay_S` figé à `0,09 s`. | Exposer `SimM3SensorFiniteCam_BOOL`, `SimM3BrakeCloseDelay_S`, `SimM3GainMetersPerHzSec` (jusqu'à `0,06` en banc), et ajouter les cas `S1/S3/S4` au banc CI. | **C2** (`L_SIMULATION`) |

---

## 4. Idées complémentaires à forte valeur ajoutée (Innovations BE)

1. **Test automatique de santé frein & came en exploitation (`DIAG` sans capteur supplémentaire) :**
   - À chaque arrêt sur `M3_PosTremie_DI`, mesurer `Δt` entre `M3_BrakeIsOpen_DI 1→0` et `DriveActualFreqHz <= 0.5 Hz` (et détecter si `M3_PosTremie_DI` retombe à `0`). Une dérive de `Δt` de `+30 %` sur 10 cycles déclenche une alerte **maintenance préventive frein** avant tout choc butée !
2. **Calibration odométrique automatique sur `P2 ↔ PV` (`2,0 m`) :**
   - Exploiter le passage réel `M3_PosPVP2_DI → M3_PosPV_DI` en régime établi pour calculer le vrai `k = 2.0 / (Freq * Δt)` et journaliser l'écart vs `0,02` / `0,0551` (évite les estimations à l'aveugle).
3. **Banc `L_SIMULATION` avec carte de risque 2D intégrée :**
   - Paramétrer le banc avec 2 profils nommés dès le démarrage : **`PROJET_NOMINAL`** (`k=0,02`, `0,09s/2,0`) et **`WORST_CASE_SITE`** (`k=0,0551`, `0,30s/0,35`, rail humide `mu=0,06`, came finie `0,08 m`) pour que **toute régression future** soit testée sur le pire cas réel et jamais seulement sur l'artefact optimiste.
