# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : Historique factuel des séances banc/terrain (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/PLAN_TASK_v1.0.md` §3 (registre maître `Txx`).

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

### MES-011 — ⚡ Polarité Retour Frein (Câblage vs Logiciel)
- 📅 **Date** : 2026-07-26 | 📍 **Lieu** : Terrain (Armoire) | 🏷️ **Commit** : `1d2e086`
- 🎯 **Périmètre** : Retours freins M1, M2, M3 (`PRG_00_Inputs.st`, `FB_Brake.st`, `AF_Partie-09` §5bis)
- 🚦 **Statut** : ✅ Corrigé logiciel ➔ ⚡ **Contrôle terrain au 1er essai**
- 🔍 **Constat** :
  - Frein à **manque de courant** (`PLC Output = 1 ➔ Frein Ouvert`).
  - Retour câblé = **contacteur de commande** (`DI = 1 ⟺ Frein OUVERT`).
  - 💥 **Bug initial** : Le PLC supposait `TRUE = Frein serré` dans `FB_Safety_Winch` (Méca A/B/D/E) et `FB_Safety_Translation` (Méca B).
- ❓ **Pourquoi invisible avant ?** : `Sensor*ContactorFeedbackIsReal = FALSE`. Le modèle simulé renvoyait `NOT BrakeCmd` (compensait la fausse logique).
- ⚠️ **Risques évités sur matériel réel** :
  - **Méca B** ➔ `SafeStop` + `PowerCutOff` 3s après chaque arrêt.
  - **Méca A désarmé** ➔ Perte détection roue libre / frein qui patine.
  - `FB_Brake` en incohérence ➔ Serrage frein sous couple + coupure relais (cause incident `v0.4.27`).
- 🛠️ **Fix appliqué** : Normalisation frontière NO/NC via `FB_Input` : `PRG_00_Inputs.BrakeFeedbackInvertLogic : BOOL := TRUE`. Modèle simulé fixé (`:= BrakeCmd`). `FB_Brake` incohérence `<>` ➔ `=`. `FB_Safety_*` intacts.
- 🔩 **Action Terrain (Machine à l'arrêt, frein serré)** :
  1. Lire `M1_BrakeFeedback_DI`.
  2. Si `0` ➔ Conforme (`BrakeFeedbackInvertLogic = TRUE`).
  3. Si `1` ➔ Câblage inversé ➔ passer `BrakeFeedbackInvertLogic := FALSE` à chaud + figer init.
- 🛑 **Limite connue** : Retour = contacteur, PAS le frein physique. Seul **Méca A** (dérive codeur, `FB_Safety_Winch` bit7) détecte la patinage (`0,02 m/s` direct).
- 🚀 **Activation** : Passer `SensorM1/M2/M3ContactorFeedbackIsReal := TRUE` **axe par axe**.

---

### MES-010 — 📐 Mesure Offset M1/M2 Fermeture Benne
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Benne M2, offset ouverture/fermeture (`FB_Bucket.ActiveOffsetM`)
- 🚦 **Statut** : 🟡 **Appliqué 2026-07-27** (`OffsetCloseM` 10.0 ➔ **15.0 m**), à reconfirmer en charge (`T89`)
- 🔍 **Constat** : Offset mesuré fermeture benne = **≈ 15 m**.
- 🛠️ **Décision** : Comparer avec `ActiveOffsetM` (`instBucket`) et `AF_Partie-12` v1.4.

---

### MES-009 — 🎯 Position Capteur Haut vs Arrêt Réel Treuils
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Capteur position haute M1/M2 (`TopPositionSensor`), arrêt treuils
- 🚦 **Statut** : 🟡 **Appliqué 2026-07-27** (`CfgTopSensorPos_M` 8.5 ➔ **8.0**, `CfgCableLimitAscent_M` 8.0 ➔ **7.5**), contrôle terrain à faire (`T90`)
- 🔍 **Constat** : Déclenchement capteur physique = **8 m**. Arrêt réel mouvement = **≈ 7,5 m** (marge ~0,5 m).
- 🛠️ **Décision** : Comparer aux cibles homing (`HomingTargetM1/M2_M`) et distance de freinage à vitesse d'approche.

---

### MES-008 — 📈 Diagnostic Arrêt M1 vs M2 (Trace CODESYS)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Treuils M1/M2, relais, freins, codeurs (`PRG_06`, `FB_Winch`, `FB_Brake`)
- 🚦 **Statut** : 🟠 **Action ouverte** (`T79`)
- 🔍 **Constat** : Écart de comportement à l'arrêt entre M1 (Retenue) et M2 (Benne). Besoin de trancher entre **commande PLC dissymétrique** et **retard mécanique/hydraulique**.
- 🛠️ **Config Trace 10ms à créer** :
  1. **Sorties PLC** : `RelayFwd/Rev`, `Contactor1..4`, `BrakeCmd`.
  2. **Feedbacks** : `BrakeFeedback`, `FwdRevSpeedFeedbackOff`.
  3. **Dynamique** : `SpeedRamp.Current`, `CablePosM`, `MeasuredSpeedMps`.
  4. **Écart** : `DeltaPosM`, `SignedDeltaPosM` (`FB_WinchSync`).

---

### MES-007 — ⚖️ Alignement Rampes Accél M1/M2 en Mode Couplé (Both)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : Treuils M1/M2, rampes `CfgRampAccelRate`
- 🚦 **Statut** : 🟠 **Action ouverte** (`T78`)
- 🔍 **Constat** :
  1. Rampe accél nominale à adoucir : 50%/s ➔ **10%/s**.
  2. Si rampes M1/M2 différentes en mode `Both` (couplé) ➔ accélérations différentes ➔ désynchronisation mécanique.
- 🛠️ **Solution** : Égalisation automatique dynamique des rampes (`CfgRampAccelRate`) active **uniquement en mode `Both`**, conservation des rampes indifs en séparé.

---

### MES-006 — 🛑 Compromis Freinage Treuils : Glissement vs Choc
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain
- 🎯 **Périmètre** : M1/M2, pilotage freins et rampes décél
- 🚦 **Statut** : 🟡 **À surveiller / Réglage terrain**
- 🔍 **Constat** : Sensation de "glissement" au retour joystick neutre en petite vitesse.
- 💡 **Analyse** :
  1. Decel normale maintient commande tant que `SpeedRamp.Current > 0.1%` (évite les chocs).
  2. Couper trop net = à-coups violents sur flèche, câbles et réducteurs.
  3. **Levier** : Conserver la rampe progressive mais optimiser `DelayMotorDecel` (`FB_Brake.st`) dès vitesse nulle.
- 🛠️ **Décision** : Rampes inchangées au code. Ajustement fin du délai de fermeture frein à faire avec le dragueur en charge.

---

### MES-005 — 🏗️ Refactoring Architecture Diagnostics (POO vs Externe)
- 📅 **Date** : 2026-07-24 | 📍 **Lieu** : Terrain / Architecture
- 🎯 **Périmètre** : `PRG_01_Diagnostics`, `FB_DiagCanOpen`, `FB_DiagEthercat`
- 🚦 **Statut** : 🟠 **Action ouverte** (`T77`)
- 🔍 **Constat** : Fausse alarme `CANbusOnline = FALSE` avec joystick fonctionnel. `PRG_01` calculait une logique complexe dans les entrées du FB (`(GetBusState() = 1) OR (SimulationModeActive AND NOT BusIsReal)...`).
- 💥 **Problèmes POO** :
  1. Logique métier/simu sortie des FB.
  2. FB "aveugle" incapable de gérer les états transitoires légitimes (`BUS_WARNING`, boot).
  3. Alarmes bloquées intempestivement.
- 🛠️ **Cible** : Passer les statuts bruts aux FB (`CANbus.GetBusState()`, `JOY1.GetDeviceState()`, `AC600.GetDeviceState()`, `SimulationModeActive`, `BypassGlobal`). Chaque FB gère sa propre machine d'état.

---

### MES-004 — 🔓 Purge Retours Contacteurs/Freins par Bypass Global
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Terrain | 📑 **Audit** : `AUDIT_BypassGlobal_Homogenization_v1.0.md`
- 🎯 **Périmètre** : M1, M2, M3, `FB_Winch`, `FB_Translation`, `FB_Brake`
- 🚦 **Statut** : 🟢 **Validé / Appliqué**
- 🔍 **Constat** : En `Bypass.Global`, `FB_Brake` et `FB_Winch` gardaient leurs erreurs `StuckOpen`/`StuckClosed` mémorisées (entrées reliées à la simu seule). Axe bloqué à 0.
- 🛠️ **Fix appliqué** : Entrée `BypassContactorCheck` alimentée avec `OR GVL_IHM.Mx.Bypass.Global` (`PRG_06`, `PRG_07`). Purge immédiate des erreurs.
- ⚠️ **Sécurité M2** : Alimenter les contacteurs de sens avant l'ouverture du frein fait forcer le moteur sous frein serré. Ajout nécessaire d'un verrou interdisant les contacteurs de sens si frein non piloté.

---

### MES-003 — 🐢 Limitation Temporaire Palier Vitesse Treuils
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Essais Treuils
- 🎯 **Périmètre** : Winch M1/M2
- 🚦 **Statut** : 🟠 **Réglage temporaire d'essai** (`T64`)
- 🛠️ **Réglage** : Plafond palier vitesse limité à `0` pour réduire la vitesse/énergie lors des 1ers essais.
- 📌 **Action `T64`** : Vérifier décodeur paliers + contacteurs pilotés, puis restaurer la valeur d'exploitation.

---

### MES-002 — 🎯 Bypass Ciblés & Homing à 0 m
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Dev / Prépa MES | 🏷️ **Commit** : `96ef589`
- 🎯 **Périmètre** : M1/M2, M3, réseau, codeurs (`GVL_BypassRetain`, `FB_Encoder_Homing`)
- 🚦 **Statut** : 🟡 **À valider banc/terrain**
- 🛠️ **Réalisé** : Bypass globaux/ciblés regroupés dans `GVL_BypassRetain`. Homing unitaire M1/M2 réglable init à `0,0 m` (ignore capteur haut, prend la pos courante).
- ⚠️ **Vigilance** : Désactiver les bypass dès le matériel validé.

---

### MES-001 — 📋 Création Registre Initial
- 📅 **Date** : 2026-07-23 | 📍 **Lieu** : Documentation
- 🎯 **Périmètre** : Registre MES/REX
- 🚦 **Statut** : 🟢 **Validé** (remplacé par l'usage courant)

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
