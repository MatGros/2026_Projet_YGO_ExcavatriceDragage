# 📊 Historique Trié `T417` & Contrôle par Échantillonnage (`T417-C`)

> **Statut :** Phase 1 — Lecture seule sur `CODE/`.
> **Échantillon audité directement :** **5 / 27** artefacts (`18,5 %`) dans `DOC/WFLOW/TASKS/T_TEMP (A TRIER)/T417_ANALYSES/` + lecture directe `PASSATION_T417_SimM3_20261030.md` et `REPRISE_PREUVES_20261030.md`.

---

## 1. Classement des pistes déjà testées (sans effacement)

### ✅ Vérifié avec preuve citée (dépriorisé sur la voie rapide)
1. **Chronologie nominale `SEMI_AUTO` (`Suivi_93`)** : en cycle normal, `DriveFreqCmd_Hz` et `DriveControlWord` tombent au scan capteur (`70,37 s`), `BrakeReleaseRequest` tombe à la sortie d'étape `X14 → X15` (`71,22 s`, soit ~`0,5 s` après passage sous `0,5 Hz`) — `PASSATION_T417_SimM3_20261030.md:65-79`, `PRG_05_Translation.st:715-721`.
2. **Paramétrage réel actif en simulation** : `SimM3BrakePhysicalActive = TRUE` (`GVL_Simulation.st:79`), `SimM3CartFreeActive = TRUE` (`GVL_Simulation.st:84`), `SimM3SensorCamDropoutActive = TRUE` (`GVL_Simulation.st:90`), passés par `FB_SimBench.st:697-705`.
3. **Distance d'arrêt actuelle du modèle en petite vitesse** : `0,0080 m` à `5 Hz` et `0,0217 m` à `10 Hz` contre `SimM3EndStopMargin_M = 0,50 m` (`FB_Sim_Translation.st`, `FB_Sim_TranslationDrive.st`, `FB_Sim_TranslationBrake.st`).
4. **Harnais intégré existant (`FB_TestHarnessT417_M3.st`)** : audité sur `R19` et `R21` (`INTEGRATION_M3_CYCLE_REJEU_R21_20261101.json:171-178`). Le test `T417-E2E-010` échoue sur le dépassement P1 (`0,274671 m` vs `<= 0,04 m`).

### 🔶 Hypothèse non prouvée / Incomplet (à traiter en Phase 2)
1. **Comportement butée électrique → choc mécanique en petite vitesse (5–10 Hz)** : aucune trace ni aucun test `T417` ne reproduit le franchissement de la butée électrique jusqu'au choc mécanique.
2. **Effet de la came `CamDropoutActive` (`FB_Sim_PositionSensor.st:114-120`)** combiné à la perte de `M3_PosTremie_DI` observée en trace 27 (`26553 ms`).
3. **Failles chaîne automate réelle** (`PRG_06_Outputs.st:431-450`, `FB_Translation.st:137-141`) : armement `HardStop` sur requête et non sur sorties, absence de verrou post-FDC, asymétrie Maintenance.

### ❌ Contredit / Obsolète / Non recevable tel quel
1. **Runner `run_m3_study_agents.py`** : tronque les sources à 6000 car. et masque les fichiers absents (`REPRISE_PREUVES_20261030.md:27`) → **écarté**.
2. **Revue `REVIEW_STOP_P1_GLM_20261101.md`** : `0` référence `fichier:ligne` (l'agent n'avait pas les sources) → **non recevable comme preuve**.
3. **Tests unitaires `test_fb_sim_translation.st`** : non compilables (`FullTravelTimeS` supprimé en T301 — `PASSATION_T417:139`).

---

## 2. Contrôle par échantillonnage (`18,5 %` — 5 / 27 fichiers)

| Fichier audité | Résultat audit | Statut |
|---|---|---|
| `INTEGRATION_M3_CYCLE_REJEU_R21_20261101.json` | Harnais réel, `T417-E2E-010` **FAIL** (`0,274671 m > 0,04 m` sur P1). Pas de scénario choc 5–10 Hz. | ✅ Vérifié |
| `INTEGRATION_M3_CYCLE_REJEU_R19_20261101.json` | Cohérent avec `R21` (`5,27417 m` vs `5 ± 0,04 m`), même harnais. | ✅ Vérifié |
| `REVIEW_OVERRUN_R19_DEEPSEEK_20261101.md` | Calculs cohérents (`0,16 m` rampe vs `0,04-0,08 m` frein), signale l'impossibilité de la bande `±0,04 m` à 20 Hz. | ✅ Vérifié |
| `REVIEW_OVERRUN_R19_GLM_20261101.md` | Converge avec DeepSeek sur l'exclusion du frein seul, propose test segmenté `dv/dt`. | ✅ Vérifié |
| `REVIEW_STOP_P1_GLM_20261101.md` | **0 ref `fichier:ligne`** (pas d'accès sources lors du run). | ⚠️ Rejeté comme preuve |

> **Verdict échantillonnage :** Aucun « faux vert » masquant un échec sur `R19/R21` (les deux sont explicitement rouges), mais **aucune couverture** du dépassement de butée en petite vitesse (5–10 Hz) jusqu'au choc mécanique.
