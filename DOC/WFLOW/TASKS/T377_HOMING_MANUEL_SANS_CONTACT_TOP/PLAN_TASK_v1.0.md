# 🎯 T377 — PLAN D'IMPLÉMENTATION — Homing N1 manuel sans contact TOP

> **Version** : v1.0 · **Date** : 2026-11-14 · **Auteur** : CC01 (orchestrateur)
> **Statut** : plan soumis à validation humaine — **aucune ligne de `CODE/` modifiée**
> **Contrat** : `DOC/WFLOW/TASKS/T_TEMP (A TRIER)/CONTRACTS/T377_CONTRAT_HOMING_MANUEL_SANS_CONTACT_TOP.yaml` (2026-11-02)
> **Parent** : T364 (refonte homing, ✅ livrée le 2026-09-21)

---

## 0. Décisions exploitant du 2026-11-14 ✅

1. **Référence M1** = `CfgTopSensorPos_M` = **8,50 m** (valeur persistante existante, réglable IHM).
2. **Validation de la position haute** = **`BtnValidation`** (bouton du grafcet, utilisable à toute étape).
3. **Doctrine du contrat T377 du 02/11** : validée → passage au plan technique.

Doctrine conservée : la montée vers le haut est **manuelle** (joystick + homme-mort, palier 1),
l'opérateur **valide visuellement** avant le capteur, le capteur TOP devient **barrière de sécurité
seule** — s'il est touché, **aucun référencement n'est écrit**.

---

## 1. 🔍 État réel du code (preuves)

| Fait | Preuve |
|---|---|
| Le homing monte **automatiquement** jusqu'au capteur | `FB_CycleMachineHoming.st:452-470` (HX2, sortie sur `TopPositionSensor`) |
| La référence est prise **sur contact** du capteur | `FB_CycleMachineHoming.st:463-469` → `M1Demand.HomeReq := TRUE` |
| Le preset écrit déjà **8,50 m** | `PRG_02_Acquisition.st:662` et `:716` → `CfgHomingTargetM := CfgTopSensorPos_M` |
| Le réglage 8,50 m est persistant | `GVL_PERSISTENT.st:41` et `:49` → `CfgTopSensorPos_M := 8.5` |
| La montée est déjà plafonnée palier 1 | `FB_CycleMachineHoming.st:181` → `CST_StepSlow := 1` |
| L'enum n'est consommé que par 3 fichiers | `grep E_MachineHomingTxState CODE/` |

👉 **Conséquence majeure** : le preset est déjà bon. Le refactor porte sur **le moment** où
`HomeReq` est émis (validation opérateur au lieu du contact capteur) et sur **les gardes** —
pas sur la valeur de référence.

---

## 2. 🚨 Écarts constatés dans le contrat (à corriger avant exécution)

1. **`SafetyPermit_Ascent` n'existe pas** dans le code (AC3). Le vrai nom est **`AscentPermit`**
   (`FB_Safety_Winch.st:574`). Une AC qui nomme une variable inexistante n'est pas testable.
2. **Chemin de contrat périmé** dans `TASKS.yaml` : pointe `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_HOMING_N1_MANUAL_TOP.yaml`,
   disparu. Le fichier vivant est celui cité en en-tête (T_TEMP) — migration T430 inachevée.
3. **AC4 parle de 23,5 m pour M2** (`OffsetCloseM`). Le code écrit **8,50 m sur M2 aussi**
   (`PRG_02:716`). Les 23,5 m concernent la **référence benne** (`BucketReferenceTargetM`,
   `PRG_02:575-577`), pas le homing machine. AC4 à reformuler.
4. **⚠️ AC3 — CORRIGÉ LE 2026-11-14 après vérification à la source.** La version v1.0 affirmait
   que la détection était « inhibée quand le capteur est atteint » : **c'est faux** (erreur de
   polarité). Réalité vérifiée : dans `FB_Safety_Winch.st`, l'entrée reçoit la DI **directe**
   (`PRG_04_Treuils_Benne.st:946-948`, `TRUE` = capteur libre), donc `AND NOT TopPositionSensor`
   (`FB_Safety_Winch.st:376-379`) **arme** la détection **au contact**. Et `CauseMecaDActive`
   figure dans `CausesPowerCutOffActive` (`FB_Safety_Winch.st:523-525`) : **l'escalade
   `PowerCutOff` exigée par AC3 existe déjà**.
   Le vrai écart n'est donc pas là : il est que **le cycle ne commande pas le treuil en MAINT_N2**
   (seul SEMI_AUTO consomme `ReqWinch`, `FB_WinchCmdArbitrationM1.st:56-61`) — voir D4.
5. **⚠️ Même DI, deux polarités.** `M1M2_TopPositionFree_DI` est passé :
   - **inversé** au homing et aux codeurs → `TRUE` = **contact** (`PRG_02:593`, `:666`, `:721`)
   - **direct** à la sécurité → `TRUE` = **libre** (`PRG_04:948`, `:1017`)

   Toute nouvelle garde doit utiliser la polarité **homing**. `G496_check_top_sensor_polarity.py` existe.

---

## 3. 🧩 Nouvelle séquence — changements

États **inchangés** : HX0, HX1, HX1A, HX5, HX6, HX7.
États **modifiés** : HX2, HX3, HX4.
État **nouveau** : `HX2A_CONTACT_CLEARANCE` — **valeur 9 ajoutée en fin d'enum** (aucun changement
des valeurs 0..8, donc aucune casse des forçages `CfgForceStepTarget` ni des traces IHM).

### HX2_CLIMB_COUPLED — approche manuelle (remplace la montée automatique)

- Montée **uniquement** si : `ClimbPermit` **ET** `JoystickWinchSelectArbitrated = 0` **ET** `NOT TopPositionSensor` **ET** `NOT TopContactLatched`.
- **Contact capteur** (`TopPositionSensor = TRUE`) → `TopContactLatched := TRUE`, aucun `HomeReq`,
  séquence → `HX2A_CONTACT_CLEARANCE`.
- **Validation opérateur** (`BtnValidationEdge.Q`) acceptée **seulement** si les 5 gardes sont vraies au même scan :
  1. `ModeIsMaint2`
  2. `WinchesMechanicallyStopped`
  3. `NOT TopPositionSensor` (capteur libre, polarité homing)
  4. `NOT JoystickDeflected` (manche au neutre)
  5. `NOT TopContactLatched`
- Hors gardes → **refus explicite** : message IHM + compteur de refus (aucune écriture).
- `ClimbTimedOut` conservé (garde de durée), texte reformulé « approche manuelle non validée ».

### HX2A_CONTACT_CLEARANCE — dégagement imposé (nouveau)

- **Aucun** `HomeReq`, aucun preset, aucune référence possible sur ce passage.
- **Montée interdite** (`TopContactLatched` verrouille HX2 jusqu'au Reset).
- Descente possible **uniquement** sous joystick poussé + homme-mort, palier 1.
- Sortie : `NOT TopPositionSensor` **ET** `WinchesMechanicallyStopped` → `HX7_FAILED` avec
  cause dédiée `CST_CauseTopContact` (nouvelle cause, texte « Capteur haut touché — re-référencer »).
- `Reset` conscient en MAINT_N2 remet `TopContactLatched := FALSE`.

### HX3_FLYING_REFERENCE → `HX3_REFERENCE_RESTORE`

- **Suppression** du Mode A « à la volée » et du repli Mode B : la machine est **déjà à l'arrêt**
  par construction (validation exige `WinchesMechanicallyStopped`).
- Actions supprimées : `HomingModeBActive`, `FlyingHomingTimer`, `StandstillHomeReqDone`.
- Sur entrée : `M1Demand.HomeReq := TRUE` puis `M2Demand.HomeReq := TRUE` (preset 8,50 m déjà câblé).
- Sortie : `BothAxesHomed` → HX4 · timeout `CfgTimeoutHomeAxes` → HX7.

### HX4_STABILIZATION_CHECK → `HX4_REFERENCE_VERIFY`

- La fenêtre d'inertie (`CfgStabilizationMinM/MaxM` = **7,50 / 9,50 m**,
  `ST_fbMachineHomingCycle_Cfg.st:29-30`, et non `[8.50..8.80]` comme l'indiquent les commentaires
  `FB_CycleMachineHoming.st:9` et `:520`) **ne contrôle plus rien** : le preset impose 8,50 m par
  construction. Elle est remplacée par :
  - `BothAxesHomed` (preset **lu et confirmé** — reste la seule source de `Homed`, AC5)
  - `WinchesMechanicallyStopped` **ET** `NOT JoystickDeflected`
  - `ABS(CablePosM1 - CablePosM2) <= CoherenceLimitM`
  - `ABS(CablePosM1 - CfgTopSensorPos_M) <= CST_HomingVerifyToleranceM`
- Échec → **1 seule** nouvelle émission de `HomeReq`, puis HX7 (au lieu de 3 retries par HX1).

### Inchangé (à préserver)

- Transaction preset vérifiée = **seule** source de `Homed` / `MachineHomed`.
- `M3Locked` pendant tout le cycle, commit benne atomique en HX6.
- Palier 1 max, homme-mort, interlock couplage `WinchSel = 0`.

---

## 4. ❓ Points à trancher avant code

**D1 — Escalade `PowerCutOff` sur montée persistante (AC3).**
La détection existante est inhibée capteur atteint (`FB_Safety_Winch.st:376-379`).
- Option A (recommandée) : ajouter la garde **dans le homing** — `TopContactLatched` + vitesse
  d'ascension > seuil alors que `CmdWinch*.RunRequest = FALSE` → `PowerCutOff`.
- Option B : étendre le périmètre à `FB_Safety_Winch.st` (C3, retest sécurité treuils complet).
- Option C : amender AC3 (pas d'escalade automatique, l'opérateur descend).

**D2 — Dégagement en HX2A.**
- Option A (recommandée) : descente **sous joystick** (aucun mouvement automatique vers le bas).
- Option B : descente automatique palier 1 tant que le capteur reste atteint (doctrine « imposé » littérale).

**D3 — Renommage des états.**
Renommer `HX3_FLYING_REFERENCE` → `HX3_REFERENCE_RESTORE` et `HX4_STABILIZATION_CHECK` → `HX4_REFERENCE_VERIFY`
(3 fichiers consommateurs seulement). Sinon : noms conservés + commentaires corrigés.

---

## 5. 📁 Fichiers touchés

**Code**
1. `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` — + `HX2A_CONTACT_CLEARANCE := 9`, renommages (D3)
2. `CODE/G_CYCLE/FB_CycleMachineHoming.st` — HX2 / HX2A / HX3 / HX4, causes, guide opérateur §10
3. `CODE/M_MAIN/PRG_02_Acquisition.st` — `TopContactLatched` si publié, aucune modif de preset attendue
4. `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st` — 2 nouveaux champs de diagnostic
5. `CODE/J_SUPERVISION/GVL_Troubleshooting.st` + `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt` (AC4)

**Doc**
6. Contrat T377 (corrections §2 ci-dessus) + `AF_Partie-09` (F09.08) + `AF_Partie-14`
7. `TASKS.yaml` : chemin de contrat, statut, verrou — **via l'IHM Task Manager uniquement**

**Interdit sans accord explicite** : `FB_Safety_Winch.st`, `FB_Encoder_Homing.st`, `FB_Encoder.st`, `FB_WinchSync.st`, `Device.export`.

---

## 6. 🧪 Tests & preuves attendues

**Scénarios SimBench (SIL)**
1. Refus de validation : manche défléchi · treuils non arrêtés · capteur atteint · hors MAINT_N2 → **4 refus**, aucun `HomeReq`.
2. Validation nominale : arrêt + neutre + capteur libre + MAINT_N2 → **`HomeReq` unique**, positions M1/M2 = 8,50 m, `Homed = TRUE`.
3. Contact fortuit : montée + capteur → `HomeReq = FALSE`, montée coupée, HX2A, descente seule possible, `Homed` reste `FALSE`.
4. Preset non confirmé : readback en échec → `Homed = FALSE`, **aucun mouvement autorisé** (AC5).
5. Non-régression : `test_fb_cyclemachinehoming.st` (13 TC existants) adaptés aux nouveaux états.

**Gates**
`generate_codesys_bundle.py` · `G200_check_linkage.py --report` · `G496_check_top_sensor_polarity.py` ·
`G511_check_homing_climb_guard.py` · `G408_check_ihm_message_length.py` · `run_all_gates.py --palier C` + tous.
Diff bundle pour import rapide CODESYS.

---

## 7. 🔁 Séquence de réalisation proposée

1. **Relire le plan** (agent externe ollama, lecture seule) — challenge de la séquence et des gardes.
2. Corriger le contrat T377 (§2) et lever l'arrêt de validation.
3. Trancher D1 / D2 / D3.
4. Déléguer l'implémentation (modèle selon `MODEL_ROUTING.md`) sur contrat + plan corrigés.
5. Revue de diff par un autre agent, puis gates ci-dessus.
6. Restitution : diff réel, sorties brutes, scénarios SimBench, bandeaux bundle/gates.
7. Recette CODESYS par l'exploitant. **Aucun commit sans accord explicite.**

---

## 8. ⛔ Points d'arrêt

- Doctrine ou cote de référence remise en cause.
- Élargissement du périmètre à `FB_Safety_Winch.st` (D1 option B).
- Toute écriture dans `FB_Encoder_Homing.st` / `FB_Encoder.st`.
- Contrat non corrigé (AC3 non testable) ou D1/D2 non tranché.
