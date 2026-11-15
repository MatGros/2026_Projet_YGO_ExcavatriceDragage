# T417-C — Synthèse Étude M3 & Plans A / B / Secours

> **Document unique consolidé** (fusion des audits `CODE/`/`DOC/`, Trace 27, étude Bureau d'Études et bancs sandbox).
> **Règle :** `CODE/` intact (lecture seule stricte).
> **Bancs exécutables :** `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/` (`plan_abc_matrix.py`, `be_dynamic_study.py`, `test_m3_sandbox.st`).

---

## 1. Faits prouvés (Trace 27 & `CODE/`)

1. **Trace 27 complète (`Suivi_TranslationM3bug_20260904_27_wide.csv`, 352 éch., 35,1 s) :**
   - `26 438 ms` : `M3_PosTremie_DI 0→1` ⇒ `CommandWord 1→0`, `Setpoint 1000→0`, `M3_BrakeIsOpen_DI 1→0`, `ErrorId 0→64`.
   - `26 553 ms` (+115 ms) : **`M3_PosTremie_DI 1→0`** (came perdue), `ActualFreq = 9,13 Hz` (sortie réelle AC600 `C00.01`).
   - `26 637 → 27 056 ms` : rampe `7,46 → 0,00 Hz` (~618 ms, ~16,2 Hz/s). **`CommandWord = 0` jusqu'à 35,1 s**, et **`M3_PosTremie_DI` reste à `0`**.
2. **Sémantique vérifiée :** `M3_BrakeIsOpen_DI` (`%IX225.2`) = retour contacteur frein (ne mesure pas l'usure/couple mâchoires) ; `DriveActualFreqHz` = fréquence réelle variateur.
3. **`ErrorId = 64` (`16#0040`) est auto-reset (`Latching := FALSE`)** (`FB_Safety_Translation.st:209`, `FB_Translation.st:142`) : inhibe permis + frein tant qu'il est actif, puis s'efface sans `Reset` dès sortie de came (`M3_PosTremie_DI = 0`).
4. **Asymétrie Maintenance (`PRG_06_Outputs.st:431-451`) :** Trémie a `M3_TremieHardStopActive` + `AND NOT M3_PosTremie_DI` ; **Maintenance (`:441`) n'a aucune coupure locale**. *(Attention : codage thermomètre `2#00000` à l'extrême Maintenance, `FB_Translation_PositionDecoder.st:88`.)*
5. **Angles morts simulateur (`L_SIMULATION/` + `I_TRANSLATION/`) :**
   - `FB_Sim_PositionSensor.st` : came « infinie » après le trou de 4 cm (retrouve `1`).
   - `FB_Translation_OdometryGain.st:57` : `CST_GainMax := 0.05` rejette le gain d'audit `0,0551 m/(Hz·s)` (`FB_Sim_Translation.st:156`).
   - `FB_Sim_TranslationBrake.st:9` : `CloseDelay_S := 0.09` non exposé dans `GVL_Simulation.st`.
   - `TonLimitSwitchOverrun = T#1S500MS` (`FB_Safety_Translation.st:203`) est **13× trop long** pour une traversée de came de `0,115 s`.

---

## 2. Synthèse Bureau d'Études (Mécanique · Dynamique · AC600 · Automatisme)

- **Pendule benne + adhérence rail (`be_dynamic_study.py`, `LoadMassRatio=0.5`, `L=4 m`) :**
  - À `10 Hz` (`k=0,0551`, `0,551 m/s`), même avec un **frein neuf** (`0,09 s / 2,0 m/s²`), un **rail humide/boueux** ($\mu = 0,06$) fait patiner les galets : la benne (`3,26°`) pousse le chariot et l'arrêt passe de `0,154 m` → **`0,471 m`**.
  - Avec **frein dégradé** (`0,30 s / 0,35 m/s²`), l'arrêt atteint **`1,005 m`** à `10 Hz`, mais retombe à **`0,226 m`** en approchant à **`5 Hz`** (et l'énergie d'impact $E = \frac{1}{2}mv^2$ est divisée par **4**).
- **Longueur minimale de came :** à `k=0,0551` et `10 Hz`, toute came < `0,15–0,30 m` est perdue avant l'arrêt complet.
- **Variateur AC600 :** vérifier si la rampe `618 ms` (Trace 27) est un arrêt sur rampe (lutte moteur/frein) ou roue libre.

---

## 3. Plans A / B / Secours & Matrice de décision au retour

| Plan | Périmètre & Criticité | Action technique | Résultat sandbox |
|---|---|---|---|
| **Plan A0** *(principal simu)* | `CODE/L_SIMULATION/` (**C2**) | Exposer came finie (`FB_Sim_PositionSensor.st`), `CloseDelay_S` et `k` (`0,06` max en banc) + profil `WORST_CASE_SITE`. | Reproduit `0,5003 m (hit)` |
| **Plan A1** *(principal PLC)* | `PRG_06_Outputs.st` (**C3/C4**) | Latch directionnel `M3_TremieHardStopLatched` (réarmé par `Reset` + sens opposé). | `0,5003 m` → **`0,0486 m`** |
| **Plan A2** *(symétrie Maint.)* | `PRG_06_Outputs.st:441` (**C3/C4**) | Ajouter `M3_MaintenanceHardStopActive` après vérif polarité `2#00000`. | `0,5000 m` → **`0,0080 m`** |
| **Plan B1** *(secours physique)* | `FB_Translation_OdometryGain.st:57` + frein | Relever `CST_GainMax` (`0,05 → 0,07` si `k` terrain > `0,05`) + contrôle mécanique entrefer/garnitures frein. | Trace `k` réel |
| **Plan B2** *(secours vitesse)* | `PRG_05` / `FB_Translation` (**C3/C4**) | Réduire la PV d'approche finale `10 Hz → 5 Hz` après `M3_PosPV_DI` (5 m avant Trémie). | `1,005 m` → **`0,226 m`** (pendule) / **`0,118 m`** |
| **Plan C** *(secours ultime)* | Exploitation + thermomètre | **C1 :** verrou thermomètre si `11111 → 01111` sans ordre Maintenance + alarme perte came < 2 scans. **C2 :** bridage PV à `5 Hz`. | Couvre perte capteur |

### Matrice rapide au retour (4 vérifications terrain ~15 min)
1. **Mesurer marge physique came Trémie ↔ tampon** (vs `0,50 m`) et **longueur de came**.
2. **Chronométrer 10 Hz sur `P2 ↔ PV` (`2,0 m`)** ⇒ tranche `k` (`0,02` vs `0,0551`).
3. **Si `M3_PosTremie_DI` se perd puis repart sur ordre** ⇒ **Plan A1** (+ **A2** si Maintenance).
4. **Si `Cmd=0` reste à 0 mais glissade > marge** ⇒ **Plan B2 (`5 Hz`) + Plan B1 (frein/odométrie)**.

---

## 4. Propositions d'implémentation prêtes au GO (non appliquées sur `CODE/`)

### 4.1 Plan A0 (C2 — `CODE/L_SIMULATION/` uniquement)
1. `CODE/L_SIMULATION/GVL_Simulation.st` & `FB_Sim_PositionSensor.st` : ajouter `SimM3SensorFiniteCam_BOOL : BOOL := FALSE` + `SimM3SensorCamLength_M : REAL := 0.04` pour modéliser une came finie (sans ré-acquisition après sortie).
2. `CODE/L_SIMULATION/GVL_Simulation.st` & `FB_Sim_TranslationBrake.st` : exposer `SimM3BrakeCloseDelay_S : REAL := 0.09` et `SimM3GainMetersPerHzSec : REAL := 0.02` (plage banc `[0.02 ; 0.06]`) + profil `WORST_CASE_SITE` (`k=0.0551`, `0.30s/0.35 m/s²`).
3. **Validation C2 immédiate après édition :**
   ```powershell
   python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
   python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
   python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
   python TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/run_m3_sandbox.py
   ```

### 4.2 Plan A1 / A2 (Bascule C3/C4 requise — `CODE/M_MAIN/PRG_06_Outputs.st`)
- **A1 (Latch Trémie, `PRG_06_Outputs.st:431-450`) :** mémoriser `M3_TremieHardStopLatched` sur front `M3_PosTremie_DI` (réarmé uniquement par `FaultMachineReset_IHM` + capteur revenu ou commande opposée Maintenance), et l'appliquer dans `M3_TremieHardStopActive` et `EffectivePermitM3_Tremie`.
- **A2 (Symétrie Maintenance, `PRG_06_Outputs.st:441`) :** vérifier d'abord la polarité physique de `M3_PosMaintenance_DI` (`2#00000` à l'extrême Maintenance dans `FB_Translation_PositionDecoder.st:88`), puis ajouter `M3_MaintenanceHardStopActive` + verrou directionnel symétrique.
- **B2 (Secours vitesse PV) :** abaisser la consigne PV finale après `M3_PosPV_DI` à `5,0 Hz` (divise `d_arrêt` par ~4× et `E_choc` par 4×).

---

## 5. Retours Panel Utilisateurs & Experts (Ollama) — Ajustements Plans A/B/C

Panel exécuté hors `CODE/` avec 3 personas terrain (`ARCHIVES/OLLAMA_EXPERTS/RESULT_EXPERT_*.md`) :

### 5.1 Opérateur Drague (`RESULT_EXPERT_1_OPERATEUR_DRAGUE.md` — `deepseek-v4.1-flash:cloud`)
- **B2 (`5 Hz` sur 5 m) rejeté tel quel :** double le temps d'approche (~30–45 min/j perdues sur 200 cycles) et pousse au contournement en `MANU`. **Ajustement :** maintenir `10 Hz` sur les premiers ~3 m après `M3_PosPV_DI`, et n'abaisser à `5 Hz` que sur les **1–2 derniers mètres** (surcoût ≤ 3 s/cycle).
- **Ergonomie Reset A1 :** si le réarmement `A1` impose un retour IHM ou oblige à reculer alors que la benne est déjà au-dessus de la trémie, risque de shuntage opérateur. **Ajustement :** rendre le réarmement accessible au poste/joystick (< 2 s) et filtrer les micro-pertes transitoires (< 300 ms) ou reprises homme-mort sans blocage injustifié.

### 5.2 Maintenance Site (`RESULT_EXPERT_2_MAINTENANCE_SITE.md` — `glm-5.3-flash:cloud`)
- **Piège critique `A2` / `2#00000` :** `00000` code à la fois « extrême Maintenance » et « chaîne capteurs morte / câble coupé / fusible 24V / boue ». Ne pas bloquer sur `00000` seul sans capteur dédié actif à `1` côté tampon Maintenance, sinon toute coupure capteur immobilise le chariot en pleine voie.
- **Protocole tests terrain corrigé :**
  - **Test 2 (`P2↔PV`) :** filmer l'IHM plutôt que chronométrer + compter simultanément.
  - **Test 3 (entrefer frein) :** **consignation électrique stricte + jeu de cales** obligatoire (le plateau plaque en ~50 ms).
  - **Test frein vs AC600 (< 5 min) :** vérifier à la main la libre rotation hélice moteur (consigné) et comparer distance d'arrêt normal vs arrêt d'urgence (`E-stop > normal` ⇒ variateur freine et frein mécanique limite ; `égales` ⇒ variateur en roue libre).
- **C1 corrigé :** `11111 -> 01111` survient aussi lors d'un départ normal vers Maintenance. **Ajustement :** ne déclencher le verrou `C1` que sur `11111 -> 01111` **sans commande Maintenance**, après validation à l'arrêt par forçage `SensorsWord` (variateur inhibé).

### 5.3 Sécurité & Commissioning (`RESULT_EXPERT_3_SECURITE_AUTO.md` — `deepseek-v4.1-flash:cloud`)
- **Mode commun critique (Power-Up hors came) :** après coupure secteur ou redémarrage automate alors que le chariot est déjà au-delà de la came en `01111` (ou capteur bloqué à `0`), aucun front `11111` n'est vu et `ErrorId=64` est effacé ⇒ risque de redémarrage vers Trémie. **Exigence :** persister (`RETAIN`) le latch ou interdire le mouvement Trémie au power-up tant que la position n'est pas prouvée.
- **Anti-faux-positifs (`<= 2 scans`) :** détection trop sensible aux rebonds/vibrations/saletés. **Ajustement :** confirmer sur fenêtre cohérente (~100 ms, compatible traversée came ~115 ms) et injecter des rebonds en FAT/SAT.
- **FAT/SAT minimal exigé avant signature C3/C4 :** tests stuck-at-0/1, redémarrage en `01111` hors came, Reset / dégagement sens opposé, et zéro faux déclenchement en campagne.


