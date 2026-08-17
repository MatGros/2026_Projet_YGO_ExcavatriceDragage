# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : Historique factuel des séances banc/terrain (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/WFLOW/PLAN_TASK.md` §3 (registre maître `Txx`).

---

## 1. ⚡ Règles & Statuts

| Élément | Emplacement |
|---|---|
| Test prévu & verdict Pass/Fail | Checklist métier / `PLAN_TASK` §4 |
| Mesure, anomalie, réglage terrain | 📍 Ce registre |
| Code, câblage, action différée | 📌 Ligne `Txx` dans `PLAN_TASK` §3 |
| Évolution CODE/DOC majeure | 📦 `VERSION_HISTORY.md` |

### 🚦 Statuts
- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

---

## 2. 📝 Entrées de Séances

### MES-012 — 🖥️ Présentation Machine & Manipulation Programme (Séance 2026-08-05)
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite` (chargée machine, avant modification)
- 🎯 **Périmètre** : Matin = présentation de la machine · manipulation du programme (config persistance, supervision, translation)
- 🚦 **Statut** : ⚪ **Non testé — en attente de données**
- 🔍 **Constat / Essai** : *(à renseigner pendant la séance)*
- 🛠️ **Solution / Décision** : *(à renseigner pendant la séance)*
- 📌 **Plan annoncé** : Après cette séance → charger **`v0.5.9_IOTest`** (nouvelle architecture) : test des **entrées/sorties de tous les devices** pour valider le câblage (NO/NC, sens, polarité)
- 📌 **Action différée** : *(réf `Txx` si nécessaire)*

---

### MES-013 — 🔌 `M3_BrakeRelease_RQ` : Sorties HW non mappées / GVL sans lien
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Sorties automate HW (`PRG_06_Outputs_LD`, `M3_BrakeRelease_RQ`), mapping E/S devices
- 🚦 **Statut** : 🟢 **Problème traité — noté** (revoir au chargement `v0.5.9_IOTest`)
- 🔍 **Constat** : Sorties HW **non mappées** physiquement dans le programme chargé ; **GVL utilisés sans lien** vers le matériel (pas d'adresse device).
- 🛠️ **Traitement** : Raccordement via **mapping E/S manuel CODESYS** (`Device.export`) — geste documenté `CODE/M_MAIN/PRG_06_Outputs_LD.st` §2 (l. 190-201, 221-225) : les `*_DQ/*_RQ` sont auto-créées par le mapping, absentes du bundle isolé.
- 📌 **Action** : Réauditer le mapping de **toutes** les sorties HW (M1/M2/M3) pendant `v0.5.9_IOTest`.

---

### MES-014 — ⛓️ Fdc traité comme « Fdc extrême » → défaut + blocage ; corrigé en Fdc normal
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Fins de course (Fdc) — traitement extrême vs normal (`FB_Translation` / `FB_Safety_Translation` M3)
- 🚦 **Statut** : 🟢 **Modification faite — OK**
- 🔍 **Constat** : Un Fdc était traité comme **Fdc extrême** → générait un **défaut avec blocage** (`ErrorId` bit6 / `ErrorLimitSwitch`, escalade `TonLimitSwitchOverrun` dans `FB_Safety_Translation.st`).
- 🛠️ **Modification** : Traitement passé en **Fdc normal** (simple butée/arrêt, sans défaut bloquant) — **fait, OK**.
- ⚠️ **À confirmer** : le code repo (`CODE/I_TRANSLATION/FB_Translation.st:23-24`, `FB_Safety_Translation.st:30-31,63`) garde la sémantique « extrême ». Vérifier que la modif « Fdc normal » est bien répercutée dans `v0.5.9` (nouvelle archi).

---

### MES-015 — 📉 Translation M3 : ralentissement PV en **Hz fixe** au lieu d'un **%**
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Ralentissement PV (`FB_Translation.st` §4bis, `ApproachSpeedHz`), `PRG_05_Translation.st:181` (`GVL_PERSISTENT._TranslationApproachSpeed_Hz`)
- 🚦 **Statut** : 🟡 **Constat — décision à prendre** (garde en Hz ou passage en %)
- 🔍 **Constat** : Le ralentissement PV est exprimé en **Hz fixe** (`ApproachSpeedHz := 10.0`), converti en % de l'échelle max au vol (`FB_Translation.st:142-143`). Moins parlant pour la maintenance que la consigne vitesse (en %) utilisée partout ailleurs.
- 🛠️ **Décision** : À trancher pendant la MES (cohérence IHM/maintenance).

### 🧭 Relevés à prendre — Calibration vitesse Translation M3 (Hz ↔ m/s)
> Objectif : relier fréquence variateur (Hz) ↔ vitesse réelle du pont (m/s) à partir de **temps de déplacement mesurés** sur une **distance connue** entre capteurs (Trémie | PV | P2 | P1 | Maintenance).

| # | Sens (Fwd/Rev) | Trajet capteurs | Distance (m) | Temps mesuré (s) | Vitesse (m/s) | Hz variateur | Consigne % | Commentaire |
|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |

---

### MES-016 — ⚠️ PRG_06 : variables output déclarées **même nom que les sorties HW** → chevauchement/écrasement
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : `PRG_06_Outputs_LD` — sorties HW M1/M2/M3 (`*_DQ`/`*_RQ`), mapping E/S device
- 🚦 **Statut** : 🟠 **Gros problème — traitement à confirmer**
- 🔍 **Constat** : Des `VAR_OUTPUT` de `PRG_06` étaient déclarées **avec le même nom que les sorties hardware** (`M1/M2/M3_BrakeRelease_RQ`, `*_DQ`…). → **chevauchement / écrasement** → les sorties **n'étaient pas pilotées correctement**.
- 💡 **Mécanisme (vérifié)** : le mapping E/S (`Device.export` l.42842-42844, `CreateVariable=True`) auto-crée des **variables globales device** nommées `M3_BrakeRelease_RQ`, etc. Le POU déclare le **même symbole** en `VAR_OUTPUT` → la portée locale gagne : l'affectation du programme écrit la **copie POU**, la sortie physique (reliée à la globale) ne reçoit **rien**.
- 🛠️ **Traitement** : *(à confirmer — désambiguïsation noms VS variables locales de mapping, cf. note `PRG_06_Outputs_LD.st` l.190-201 : le raccordement physique doit pointer les **variables locales** (ex. `M1BrakeCmd`), pas les `*_DQ/*_RQ`)*
- ⚠️ **Repo `v0.5.9` à contrôler** : `CODE/M_MAIN/PRG_06_Outputs_LD.st:64,72,74` garde les `VAR_OUTPUT` homonymes ET `Device.export` garde le mapping sur ces noms → risque identique si le mapping n'est pas déplacé sur les variables locales. **Réauditer au chargement `v0.5.9_IOTest`.**

---

### MES-017 — 🎯 Ajout : référencement codeurs absolus **sans condition via IHM**
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Codeurs absolus M1/M2, référencement via IHM (`FB_Encoder_Homing`, homing unitaire/nominal)
- 🚦 **Statut** : 🟢 **Ajouté — à valider en essai**
- 🔍 **Constat** : Avant, le référencement était **conditionné** (modes MAINT_N1/N2, sélection treuil, codeur opérationnel, contacteurs relâchés, frein appliqué — cf. `GVL_Troubleshooting.HomingM1/M2` Step1-5).
- 🛠️ **Ajout** : Possibilité de **référencement sans condition via IHM** — preset logiciel immédiat (`HomingRefRaw` recalculé à l'instant, `CablePosM` bascule à `0.0 m` / `CfgTopSensorPosM`).
- ⚠️ **Repo** : le mécanisme « Homing logiciel immédiat sans condition » existe déjà à `CODE/E_CODEURS/FB_Encoder_Homing.st:126-135` (front `Home`, `UnitaryMode`). Vérifier qu'il est **câblé/exposé IHM dans `v0.5.9`** (la version repo est la nouvelle archi, pas la `v0.4.27` chargée machine).

---

### MES-018 — 📡 Translation M3 : à l'installation / retour, décodage des capteurs → position connue
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Translation M3 — décodage 5 capteurs (Trémie|PV|P2|P1|Maintenance), position au démarrage/installation
- 🚦 **Statut** : 🟢 **Modification faite — OK**
- 🔍 **Constat** : À l'**installation / retour** (démarrage, remise en place), la position n'était pas connue directement.
- 🛠️ **Modification** : Avec le **décodage des capteurs**, le code **dit « on est à telle position »** dès le démarrage (position initialisée depuis le capteur actif, sans homing).
- ⚠️ **Repo** : comportement déjà implémenté à `CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st:90-99` (init au premier capteur actif) + recalage absolu aux fronts (§2). ⚠️ L'init se base sur les **capteurs bruts**, pas sur le mot **validé** par `FB_Translation_PositionDecoder` (combinaisons incohérentes) — vérifier le garde-fou incohérence au démarrage dans `v0.5.9`.

---

### MES-019 — ⚙️ Paramétrage variateur AC600 M3 (moteur + décélération)
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Variateur AC600 M3 — paramétrage moteur & rampes
- 🚦 **Statut** : 🟡 **Paramètres posés — à compléter/vérifier en essai**
- 🔍 **Paramètres** :
  - **F10.54** + **F2.xx** → **paramétrage moteur** *(valeurs exactes à préciser)*
  - **F01.22/23 rampes variateur** (valeurs finales) : **Accel = 1,5 s** · **Decel = 2 s**
  - **Rampes PLC** (`FB_Translation` %/s) : **Accel = 40 %/s** · **Decel = 50 %/s**
- 🛠️ **Cohérence** : rampe variateur + rampe logicielle PLC en **série** → c'est la plus lente qui domine. Vérifier l'effet réel à l'essai (allure/arrêt).
- ⚠️ **Repo `v0.5.9`** : les défauts `GVL_PERSISTENT.st:89-91` sont **accel 20 / decel 40** — tes valeurs terrain (40/50) ne sont pas encore dans le repo. Confirmer si elles doivent y être portées.
- 📌 **Action** : Compléter les valeurs `F2.xx`/`F10.54` (U/f, courant, vitesse nominale…).

---

### 📌 À faire — Ajouter les **In/Out (entrées/sorties) dans l'IHM** pour la maintenance
- 🎯 **Demande** : Rendre visibles dans l'IHM les **entrées/sorties physiques** (état réel) en vue maintenance — utile pour la MES, le test I/O (`v0.5.9_IOTest`) et le diagnostic câblage (polarité NO/NC, sens).
- 🚦 **Statut** : ⚪ **Non traité — à planifier**
- 📌 **Action différée** : Créer une ligne `Txx` dans `PLAN_TASK` §3 (proposé ; pas modifié sans ta validation).

---

## 3. 📄 Modèle à Dupliquer

```md
### MES-XXX — Titre court
- 📅 **Date** : YYYY-MM-DD | 📍 **Lieu** : Simulation / Banc / Terrain | 🏷️ **Version** : Commit/Export
- 🎯 **Périmètre** : Axe / Fonction / Composant
- 🚦 **Statut** : 🟢 / 🟡 / 🟠 / 🔴 / ⚪
- 🔍 **Constat / Essai** : Mesures, observations, faits
- 🛠️ **Solution / Décision** : Réglage, fix, validation
- 📌 **Action différée** : Réf `Txx` dans PLAN_TASK §3
```

---

## 4. ✅ Procédure de Clôture `Txx`
1. Ajouter l'entrée `MES-XXX` avec preuve.
2. Mettre `✅` + réf MES dans `PLAN_TASK` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.
