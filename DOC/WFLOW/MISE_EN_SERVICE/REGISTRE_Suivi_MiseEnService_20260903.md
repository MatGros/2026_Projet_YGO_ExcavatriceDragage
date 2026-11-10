# 🧾 Registre de Suivi Mise en Service — Séance 2026-09-03 (v1.0)

> 🎯 **Rôle** : Historique factuel de la séance du 2026-09-03 (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/WFLOW/TASKS.yaml` §3 (registre maître `Txx`).
> 🔗 **Séance précédente** : `REGISTRE_Suivi_MiseEnService_20260902.md` (MES-001 → MES-038).
> 🔗 **Séance suivante** : `REGISTRE_Suivi_MiseEnService_20260904.md` (objectifs + entrées).
> ♻️ Entrées extraites du registre `_20260902.md` (MES-039 → MES-045, toutes datées 2026-09-03).

---

## 1. 🚦 Statuts

- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

---

## 2. 📝 Entrées de Séance

### 🎯 Objectif de séance — 2026-09-03 — Mise en service homing machine + refonte GRAFCET SEMI_AUTO

---

### MES-039 — 🟢 Homing machine : échec au moment de quitter le capteur TOP (M2 réf. à ~23 m au lieu de 8,5)
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Terrain/Banc | 🏷️ **Version** : `backup/mes-septembre-20260902` (commit `0350e3d1`)
- 🎯 **Périmètre** : `FB_MachineHomingCycle` §7, HX3 (réf. axes au vol), `FB_WinchSync`
- 🚦 **Statut** : 🟢 **Corrigé** (à retester au banc) — ⚠️ à revoir avec MES-045 : le fix `UseDynamicTarget := FALSE` empêche le homing benne fermée → `T240` révisée
- 🔍 **Constat / Essai** :
  - Séquence homing OK jusqu'à la sortie du capteur TOP pour le référencement au vol.
  - À cet instant : `Fault.Latched` → message « Erreur ou Echec homing - Acquitter (Reset) ».
  - Snapshot `Snapshot_Troubleshooting_20260903_161518.csv` : `Idx306_WinchSyncError = TRUE`, `Idx302_SyncFaultActive = TRUE`, `MachineHomingFailed = TRUE`. M1 bien référencé à 8,5 m (config). **M2 référencé à ~23 m** (benne fermée).
- 🛠️ **Solution / Décision** : §7 forçait `M2Demand.UseDynamicTarget := TRUE` en HX3 avec `DynamicTarget_M = CfgTopHomingTarget_M + CfgOffsetClose_M` (~8,5 + 15 ≈ 23). Au préset « au vol » M2 sautait à ~23 m pendant que M1 se référençait à 8,5 → écart apparent ~15 m → `FB_WinchSync` SafeStop → défaut latché. **Fix** : HX3 = référencement des AXES uniquement (GEL homing) → `M2Demand.UseDynamicTarget := FALSE`, M2 se référence à la même cible nominale que M1. L'offset benne fermée reste appliqué par le commit benne HX5 (`BucketCommit.CommitClose` → `FB_Bucket`).
- 📌 **Action différée** : retest banc séquence homing complète HX0→HX6 après download. **MES-045** : ce fix casse le homing benne fermée (capteur top partagé) → `T240`.

---

### MES-040 — 🟡 Position capteur haut M1/M2 : paramètre commun (fin du 8,5 figé M2)
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Banc | 🏷️ **Version** : commit `5fe1266f`
- 🎯 **Périmètre** : `CfgTopSensorPos_M` M1/M2, `PRG_07_Supervision`, `PRG_02`
- 🚦 **Statut** : 🟡 **À surveiller** (réglage IHM à confirmer)
- 🔍 **Constat / Essai** : `BtnHome` M2 référençait toujours à 8,5 m quelle que soit la config ; `BtnHome` M1 fonctionnait (champ IHM câblé). Cause : `_WinchM2CfgPersist.CfgTopSensorPos_M` figé en NVRAM, sans widget IHM effectif.
- 🛠️ **Solution / Décision** : M1 et M2 montent liés au même capteur → **M1 = maître**. `PRG_07` recopie en continu `GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M` → `GVL_IHM.M2TreuilBenne.Cfg` **et** `_WinchM2CfgPersist`. Homing M2 (qui lit `_WinchM2CfgPersist`) prend la valeur M1. Tentatives antérieures (`_CommunCfgPersist` neuf, garde `SafeTopSensorPos`, relaxation permis) **revertées** (risque champ persistant neuf + régression M1).
- 📌 **Action différée** : régler `CfgTopSensorPos_M` côté M1 sur l'IHM et vérifier que M1 **et** M2 réfèrent à cette valeur.

---

### MES-041 — 🟠 Refonte GRAFCET SEMI_AUTO en 20 steps (T237) — DIVING décomposé, EXTRACTION/DÉCHARGE
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Développement | 🏷️ **Version** : commits `2dff056f` → `f73c714b`
- 🎯 **Périmètre** : `FB_CycleSemiAuto`, `E_AutoCycleStep`, `PRG_03`, banner, troubleshooting
- 🚦 **Statut** : 🟠 **Non testé banc** — 13/13 tests CI, G200 PASS, revue agent expert
- 🔍 **Constat / Essai** : GEL `GEL_GRAFCET_SEMIAUTO_20260903.md` figé (commit `537e1419`, Q1–Q16). DIVING décomposé en `AX4_DESCEND_DIVING` / `AX5_KOBOLD_INIT` / `AX6_SEARCH_IMMERSION` / `AX7_SEARCH_BOTTOM` / `AX8_BOTTOM_CONFIRMED` + `AX_DIVING_RETRY` (transverse GT-dive-retry : erreur Kobold / joystick relâché / palier ≠ 4). EXTRACTION `AX9..AX12` (retente câbles palier 1, palier max AX11 réglable [1..2], palier 4/1 selon benne en AX12). DÉCHARGE `AX13..AX18`, rebouclage `AX18 → AX2` (pas retour AX0). `CST_StepDive` 3→4.
- 🛠️ **Solution / Décision** : revue agent — fixes M4 (AT18 sur front joystick, pas maintien), M5 (C1e AX10→AX11 sans temps mort), m6 (`BottomTouched` latché), m7 (anti-rebond 200 ms retry). Feedback palier câblé sur `PRG_04.Data.WinchM1/M2State.StepNumber`.
- 📌 **Action différée** : **banc** — câbler retour contacteur Kobold réel (`KoboldContactorFeedback` = TRUE en dur), confirmer polarité DI Kobold + valeur `DiveStartMin_M` (3–5 m, persist à 1.0). **IHM** : table libellés step à régénérer (renumérotation). Rename `FB_MachineHomingCycle` → `FB_CycleMachineHoming` (fait, `T239`). Retrait sous-système assistants DiveSearch/ExtractionAssist/DumpAtTremie (`T238`). **Debug + exécution GRAFCET → `T245` (séance 2026-09-04)**.

---

### MES-042 — 🟢 Mise en service homing : IHM `CycleMachineHoming` + forçage de step encadré + textes `HXn -`
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Développement | 🏷️ **Version** : commits `d97d88b2`, `9d7a1c64`, `f624f353`, `bdd18d16`
- 🎯 **Périmètre** : `GVL_IHM.CycleMachineHoming` (`ST_CycleMachineHomingHMI` Cmd/State/Cfg), `FB_MachineHomingCycle` §4bis
- 🚦 **Statut** : 🟢 **Compile OK** — FB_MachineHomingCycle 8/8, PRG_07 3/3 (à tester banc)
- 🔍 **Constat / Essai** : besoin mise en service — bouton validation IHM (en plus du BP joystick), forçage d'un step du GRAFCET homing, consignes opérateur ambiguës.
- 🛠️ **Solution / Décision** :
  - `GVL_IHM.CycleMachineHoming` homogène avec `Cycle` / `CycleDiveSearch` — commandes homing sorties de `ST_ModesCmd`.
  - `Cmd.BtnValidate` (front) = équivaut à 1 appui du motif 3 appuis (mise en service sans joystick).
  - Forçage step (`§4bis`) : **encadré** — `Cfg.TglCommissioning` (case) **ET** `MAINT_N2` **ET** front `BtnForceStepApply` ; impulsion (pas un force continu), purge latches, le GRAFCET reprend au scan suivant. Pont persistant `_CycleMachineHomingCfgPersist`. *(le gate `NOT Fault.Latched` a été retiré ensuite — cf. MES-043)*
  - `MachineHomingInstruction` : préfixe `HXn - RefHoming …` (action-first, mention « 3 appuis JOY »), « Erreur ou Echec » au lieu de « Defaut ».
  - Motif 3 appuis : durée mini d'appui **300 ms → 150 ms** (`CST_ValidationPressHold`).
- 📌 **Action différée** : ajouter les widgets IHM (bouton validate, sélecteur step, case mise en service). Tester le forçage au banc.

---

### MES-043 — 🟢 Homing : garde re-homing si déjà référencé + silence message homed + forçage step sur défaut latché
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Développement + Banc | 🏷️ **Version** : commits `9a2518d2`, `eec7014d`
- 🎯 **Périmètre** : `FB_CycleMachineHoming` §4bis / §8 (HX0) / §10
- 🚦 **Statut** : 🟢 **Compile OK, FB 8/8, G200 PASS** (à confirmer banc)
- 🔍 **Constat / Essai** : (1) « quand je vais homing M2 ça prend toujours 8.5 » résolu avant, mais en travail benne MAINT des appuis répétés du BP joystick (homme-mort) faisaient repartir le cycle homing alors que la machine était déjà référencée. (2) Message homing affiché en permanence même machine homed. (3) Forçage de step inopérant quand un défaut est latché — or c'est exactement le cas où on en a besoin.
- 🛠️ **Solution / Décision** :
  - §8 HX0 : gestes indirects (`ExplicitValidationPulse` 3 appuis, `AutoArmTimer`) ignorés si `BothAxesHomed`. Seul le bouton IHM `StartEdge` re-référence une machine homed. Perte de datum réelle (`MachineWasHomed AND NOT MachineHomedRaw`) toujours prise.
  - §10 : `MachineHomed AND NOT CycleRunning` → `MachineHomingInstruction := ''` (aucun texte homing IHM), `Fault.Latched` reste prioritaire.
  - §4bis : suppression du gate `NOT Fault.Latched` (le forçage EST l'action de récupération) + `MachineHomingFailed := FALSE` dans la purge.
- 📌 **Action différée** : test banc du forçage sur défaut latché.

---

### MES-044 — 🟠 Jog benne unitaire M2 (WinchSel=2) : ouverture permise hors Dive + ralentissement zone anticipation + RemainingTravel permanent
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Banc | 🏷️ **Version** : commits `eec7014d`, `0defd32e`, `8bd0b65f`
- 🎯 **Périmètre** : `PRG_04` (`ProcessPermitM2_Descend`, §5ter), `FB_Bucket` §4, `ST_fbBucket_Config`, `GVL_PERSISTENT`, `ST_BucketHMIState`
- 🚦 **Statut** : 🟠 **En service partiel** — ouverture/fermeture sur FDC OK en MAINT_N1, mais série de bugs état/offset découverts (→ MES-045)
- 🔍 **Constat / Essai** : régression vs ancien programme — en mode benne WinchSel=2 on ne pouvait plus **ouvrir** la benne (M2 descente). Cause : `ProcessPermitM2_Descend` gaté par `DescendPermitDiveBucketOpen` (TRUE seulement en mode Dive). De plus le jog était bridé palier 1 sur toute la course.
- 🛠️ **Solution / Décision** :
  - **R1** : `ProcessPermitM2_Descend` += `ManualBucketJogActive` (`WinchSel=2 AND MAINT`) → ouverture permise hors Dive. Gardes conservés (Kobold latch, clamp anticipation, `SafetyPermitM2_Descend`).
  - **R4** : jog M2 palier **libre** en course, palier 1 seulement dans la **zone d'approche** (`JogSlowdownZoneM` avant le point d'arrêt anticipé `Offset ± Anticipation`) ; repli palier 1 si M1/M2 non référencés. `BucketNotClosedAscentCapStep1` (fermeture benne ouverte → P1) reste prioritaire.
  - **Config** : `ST_fbBucket_Config` +`JogSlowdownZoneM := 1.0` ; `GVL_PERSISTENT` inits explicites `OpenAnticipationM := 1.3` / `CloseAnticipationM := 1.0` / `JogSlowdownZoneM` — **réglables IHM** via pont existant.
  - `RemainingTravel_M` calculé en permanence (hors `Lifecycle.Busy`) pour l'affichage jog manuel. `ManualBucketLimitsActive` publié IHM.
  - **R3** (détection passive d'état sur position en jog M2) : ajoutée (`0defd32e`) puis **retirée** (`8bd0b65f`) — basculait `IsOpen/IsClosed` au simple passage dans une bande → `ActiveOffsetM` faux → MecaE synchro fantôme au retour en couple. Remplacée par le classifieur continu §4a (commit `f4c0ffbf`, cf. MES-045).
- 📌 **Action différée** : `JogMaxStep` (plafond ouverture benne réglable IHM, demandé ≈ P4) non implémenté. **PERSISTENT** : nouveaux champs config → « Réinit. origine » ou réglage IHM une fois après download (sinon lus à 0). `GVL_IHM.CycleSemiAuto` = slot mort (PLC lit `Cycle`). Voir MES-045 pour la suite.

---

### MES-045 — 🔴 Bug benne mise en service : datum M2 corrompu (~15 m), cascade MecaA/MecaE/OffsetMax → chantier fiabilisation état/offset (T241)
- 📅 **Date** : 2026-09-03 | 📍 **Lieu** : Banc | 🏷️ **Version** : commits `8bd0b65f` → `f4c0ffbf` (classifieur continu §4a **commité, non testé banc**)
- 🎯 **Périmètre** : `FB_CycleMachineHoming` HX3, `FB_Bucket` (état / `ActiveOffsetM` / `OffsetMaxFault`), `FB_Safety_Winch` (MecaA/MecaE), `PRG_02`
- 🚦 **Statut** : 🔴 **Bloquant mise en service homing** — contourné (homing benne ouverte), chantier T241 en cours
- 🔍 **Constat / Essai** (traces `Suivi_DéfautSortieSEnsorTopREf_20260902_18`, `Suivi_BugBenne_20260902_19` ; snapshots `..._192533` → `..._195046`) :
  - Homing lancé **benne fermée** → `1/2 [M2] ErrorID:08 MecaA` « déplacement sans commande » à la sortie du capteur top. M1 = 3.23 m référencé OK, **M2 = 17.76 m NON référencé**, `MachineHomingStep = 70` (FAILED).
  - **Cause racine** : M1 et M2 partagent **UN capteur top** (`M1M2_TopPositionFree_DI` ; `PRG_02` `instEncoderM2.TopPositionSensor := NOT M1M2_TopPositionFree_DI`). Le fix `0350e3d1` preset M2 à `CfgTopSensorPos_M` (8.5). Benne fermée → M2 physiquement ~15 m sous M1 → preset à 8.5 → 15 m d'incohérence → `DriftGuardA` M2 (MecaA) avant que `RefWindowActive` couvre → `HomedAndReliable` FALSE → HXF_FAILED. **Le datum M2 reste faux de ~15 m.**
  - Cascade : `FB_Bucket` `OffsetMaxFault` (ErrorID:02) latché → `FBState = ERROR` → `SevereError` → `RemainingTravel_M` figé, FDC « disparus » ; `M2PositionCorrected = M2 − ActiveOffsetM` faux de 15 m (état benne ≠ réalité) ; `FB_WinchSync` MecaE fantôme → **synchro désactivée à la main**. `OffsetMaxFault` re-latche à **13 cm** de M2 sous M1 (borne basse = `CablePosM1` sec).
- 🛠️ **Solution / Décision** :
  - **Récupération banc** : `FaultMachineReset` → sortie ERROR ; ré-référencer M2 physiquement (homing **benne ouverte** au capteur partagé, ou `BtnHomingAtZero` pour casser l'erreur puis re-homing) ; `BtnConfirmOpen/ClosePos` en **MAINT_N2** pour recaler état + offset. Résidu ~1 m constaté → `OffsetCloseM` réel ≈ 13.95 (pas 15).
  - **T240 révisée** : homing doit accepter benne ouverte **OU** fermée → HX3 preset M2 offset-aware (`CfgTopSensorPos_M + OffsetExpected`), propager l'offset vers `ActiveOffsetM` pendant HX3, `RefWindowActive` doit couvrir le saut. (Ancienne demande « fermer benne à HX1 » abandonnée — incompatible avec capteur partagé.)
  - **T241 (fiabilisation, commit `f4c0ffbf`, en test banc)** : `FB_Bucket` §4a **classification continue de l'état sur la mesure** (`|Δ − Offset| ≤ CoherenceLimitM` pendant 1 s, machine totalement à l'arrêt + référencée) → self-heal dans tous les modes ; §5 `ActiveOffsetM` piloté par cet état fiable ; §5a warn `OffsetStateMismatchWarn` (non bloquant, publié IHM) si `|Δ − ActiveOffsetM|` incohérent > 2 s ; §1 `OffsetMaxFault` borne basse `OffsetOpenM − CoherenceLimitM` + latch persistant > 500 ms ; `CfgFault` tolère `OffsetOpenM` légèrement négatif.
- 📌 **Action différée** : voir **T240** (homing benne ouverte/fermée, contrat C2) et **T241** (`reste_a_faire` : test banc classifieur, recalibration `OffsetOpenM/CloseM`, réparer test unitaire `FB_Bucket` périmé, widget IHM warn). Inventaire exhaustif des défauts bloquants → **`T243`** + `DOC/WFLOW/AUDITS/INVENTAIRE_Defauts_Bloquants_MES_20260903.md`.

---

## 3. 📄 Modèle à Dupliquer

```md
### MES-XXX — Titre court
- 📅 **Date** : YYYY-MM-DD | 📍 **Lieu** : Simulation / Banc / Terrain | 🏷️ **Version** : Commit/Export
- 🎯 **Périmètre** : Axe / Fonction / Composant
- 🚦 **Statut** : 🟢 / 🟡 / 🟠 / 🔴 / ⚪
- 🔍 **Constat / Essai** : Mesures, observations, faits
- 🛠️ **Solution / Décision** : Réglage, fix, validation
- 📌 **Action différée** : Réf `Txx` dans TASKS.yaml §3
```
