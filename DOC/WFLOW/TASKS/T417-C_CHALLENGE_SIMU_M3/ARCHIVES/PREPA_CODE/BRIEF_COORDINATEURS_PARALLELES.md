# Arborescence Parallèle `T417-C` → `T417-D` / `T417-E` / `T417-F`

> **Règle d'or :** Aucune écriture partagée sur un même fichier `.st` entre branches. Chaque coordinateur pilote ses subagents et applique la cascade `Plan A → 1 Debug → Plan B → Plan C`.

## 1. Carte de parallélisation & propriété des fichiers

1. **Tronc commun (`T417-C`, ~15 min terrain)** :
   - Mesures site (`P2↔PV`, marge came/tampon, test frein vs AC600) + GO exploitant.
2. **Exécution parallèle (3 coordinateurs indépendants après GO) :**
   - **`T417-D` — Simulation & Bancs (`C2`)**
     - *Fichiers exclusifs :* `CODE/L_SIMULATION/GVL_Simulation.st`, `FB_Sim_PositionSensor.st`, `FB_Sim_TranslationBrake.st`, `FB_Sim_Translation.st`, `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/**`.
     - *Équipe :* 1 Coordinateur + 2 Subagents (`Modèle physique ST` / `Banc CI & Sandbox`).
     - *Cascade :* `Plan A0` (came finie + `CloseDelay_S` + `k` + `WORST_CASE_SITE`) → *échec* → `1 Debug ciblé` → *blocage* → `Plan B` (validation isolée Python `be_dynamic_study.py` / `plan_abc_matrix.py`).
   - **`T417-E` — Sécurité M3 & Sorties (`C3/C4`)**
     - *Fichiers exclusifs :* `CODE/M_MAIN/PRG_06_Outputs.st`, `CODE/M_MAIN/PRG_05_Translation.st`, `CODE/I_TRANSLATION/**`.
     - *Équipe :* 1 Coordinateur + 3 Subagents (`Automate ST` / `Safety Challenger` / `Cahier FAT-SAT`).
     - *Cascade :* `Plan A1/A2` (latch `RETAIN` + anti-rebond ~100 ms + reset poste/joystick + symétrie Maintenance sur capteur dédié) → *échec/doute* → `1 Debug` → *glissade/incertitude* → `Plan B2` (`5 Hz` sur 1–2 derniers m) + `Plan B1` (`CST_GainMax` + frein) → *capteur HS* → `Plan C` (verrou `11111→01111` sans ordre Maintenance + bridage `5 Hz`).
   - **`T417-F` — Cycle Benne & Mode Auto (`C3`)**
     - *Fichiers exclusifs :* `CODE/F_MODES/FB_Modes.st`, `CODE/G_CYCLE/FB_CycleSemiAuto.st`, `CODE/M_MAIN/PRG_03_Modes_Cycle.st`, `CODE/H_TREUILS_BENNE/**`.
     - *Équipe :* 1 Coordinateur + 2 Subagents (`Conditions initiales Auto` / `Ouverture benne Trémie`).
     - *Cascade :* `Plan A` (simplification `CycleInitPositionOk` / `AX1_INIT` + `M3AtTremie` stabilisé + fluidification `AX15A/B`) → *blocage capteur/état* → `Plan B` (mode semi-auto avec confirmation opérateur explicite).
3. **Convergence (`J_FINAL` — Intégration unique)**
   - `generate_codesys_bundle.py .` → `G200_check_linkage.py --report` → `run_all_gates.py` → FAT/SAT terrain.

---

## 2. Briefs prêts à copier pour les 3 coordinateurs

### Brief `T417-D` (Coordinateur Simulation)
> Tu es coordinateur `T417-D` (C2). Périmètre exclusif : `CODE/L_SIMULATION/**` et `AGY02_T417_M3_SANDBOX/**`. Applique `PREPA_ST_T417-D_SIMU.md`. Délègue en parallèle : Subagent 1 sur `FB_Sim_PositionSensor.st` / `FB_Sim_TranslationBrake.st` / `GVL_Simulation.st`, Subagent 2 sur `run_m3_sandbox.py` + `G200`. Si `Plan A0` échoue aux gates : 1 cycle de debug max, sinon bascule `Plan B` (matrice Python isolée) et remonte l'écart.

### Brief `T417-E` (Coordinateur Sécurité M3)
> Tu es coordinateur `T417-E` (C3/C4). Périmètre exclusif : `PRG_06_Outputs.st`, `PRG_05_Translation.st`, `CODE/I_TRANSLATION/**`. Applique `PREPA_ST_T417-E_SECU_M3.md`. Délègue : Subagent 1 (code ST), Subagent 2 (challenge Safety : power-up `01111`, piège `2#00000`, anti-rebond ~100 ms), Subagent 3 (tests FAT/SAT). Cascade stricte : `Plan A1/A2 → 1 Debug → Plan B2+B1 → Plan C`.

### Brief `T417-F` (Coordinateur Cycle & Mode Auto)
> Tu es coordinateur `T417-F` (C3). Périmètre exclusif : `FB_Modes.st`, `FB_CycleSemiAuto.st`, `PRG_03_Modes_Cycle.st`, `CODE/H_TREUILS_BENNE/**` (lecture seule sur `PRG_05_Translation`). Applique `PREPA_ST_T417-F_CYCLE_TREMIE_AUTO.md`. Délègue : Subagent 1 (conditions initiales Auto `AX1_INIT`), Subagent 2 (ouverture benne Trémie `M3AtTremie` / `AX15A-B`). Cascade : `Plan A → 1 Debug → Plan B semi-auto`.
