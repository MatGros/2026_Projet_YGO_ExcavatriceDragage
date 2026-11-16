# 🛠️ GUIDE OPÉRATIONNEL DE MISE EN SERVICE — M3, CYCLE AUTO & MAINT N2 (v3.0)

> **Date :** 2026-11-16 · **Version :** 3.0 (Consolidé après Challenge 7 Agents Ollama & Implémentation ST)  
> **Note technique de cette mise à jour :** [NOTE_MISE_A_JOUR_CODE_20261116.md](./NOTE_MISE_A_JOUR_CODE_20261116.md) (bits IHM exacts, défauts `FALSE`/`0.0`, nuances & périmètre).  
> **Format :** TDAH-Friendly · Checklists actionnables · Arbres de décision (Action ➔ Résultat ➔ Piste ➔ Solution)  
> **Bundles prêts à importer :** `CODE_XML/CODE_Bundle.xml` (complet) et `CODE_XML/CODE_DiffBundle.xml` (rapide : 10 objets modifiés).  
> **Trace M3 classée par échelle :** `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Trace_Site_M3_Par_Echelle.trace` (35 variables actives, 4 groupes d'échelle).

---

## 🎯 1. RAPPEL DES OBJECTIFS (`T417` / `T417-C` / `T417-D/E/F` / `T395`)

1. **Arrêt M3 au 1er trou capteur en `SEMI_AUTO` comme en `MANU` (`T417-E`) :**
   - En `MANU`, l'arrêt sur Trémie et P1 se fait en ~10 cm et le frein mécanique tient.
   - En `SEMI_AUTO`, corriger la chaîne logicielle (`FB_CycleSemiAuto` ➔ `PRG_05` ➔ `FB_Translation` ➔ `PRG_06`) qui relâchait la rampe rapide et le hard stop 10 ms après le 1er trou capteur et maintenait le frein ouvert pendant `2,5 s` (`-0,40 m` Trémie, `+5,38 m` P1).
2. **Souplesse Cycle Semi-Auto & Trémie (`T417-F`) — 3 réglages IHM sans toucher à `GVL_PERSISTENT` :**
   - **`SetPauseBeforeDump_S`** : Pause réglable (s) entre la fin d'approche `AX14` et l'ouverture benne `AX15B` (`0,0 s` par défaut = transparent).
   - **`TglAllowDumpInPV`** : Bit IHM autorisant l'ouverture benne dès la zone PV (`M3_PosPV_DI`) tout en avançant vers la trémie, et autorisant le retour vers `P1` (`AX18 ➔ AX2`) dès que la benne est ouverte (même sans avoir touché `M3_PosTremie_DI`).
   - **`TglRelaxSemiAutoStart` + Diagnostic granulaire `AX1_INIT`** : 3 messages explicites en `AX1_INIT` (`M3 en Maintenance`, `M1/M2 hors zone haute`, `Etat benne non qualifie`) + bit IHM élargissant la fenêtre haute (`0,4 m ➔ 2,0 m`) et dispensant de qualification stricte benne si les treuils sont hauts.
3. **Mode `MAINT_N2` Inconditionnel (`T395`) :**
   - Garantir qu'en **`MAINT_N2`**, l'opérateur peut piloter **directement et sans condition** les contacteurs et les treuils **M1 seul (`WinchSel=1`), M2 seul (`WinchSel=2`) ou M1+M2 ensemble (`WinchSel=0`)**, y compris en présence de n'importe quel défaut (codeur HS, non référencé, mou de câble, écart synchro, M3 à la trémie, Kobold latché, défaut retour auxiliaire frein/contacteur), sous la seule réserve de la chaîne AU physique fermée (`PowerContactorEngaged_DI`), de l'homme-mort joystick, et du capteur mécanique haut (`M1M2_TopPositionFree_DI`).

---

## 🔍 2. SYNTHÈSE DU DIAGNOSTIC CODE & DES PARADES APPLIQUÉES

### A. Pourquoi `SEMI_AUTO` glissait alors que `MANU` s'arrêtait en 10 cm ?
| Maillon | Ce qui se passait avant en `SEMI_AUTO` | Correctif ST appliqué (`T417-E`) |
|---|---|---|
| **1. `FB_Translation.st:290`** | `EffectiveSafeStop` tombait à `FALSE` 10 ms après le capteur (dès `ReqStart := FALSE`), basculant `SpeedRamp` sur la rampe lente (`40 %/s` = `2,5 s`). | `ArrivalLock` est intégré dans `EffectiveSafeStop` ➔ **Rampe rapide (`100 %/s`) garantie dès le 1er trou**. |
| **2. `FB_Translation.st:320`** | `MovementRequested` restait `TRUE` tant que `SpeedRamp.Current > 0.1` (`2,5 s`), maintenant `BrakeReleaseRequest = TRUE` (frein ouvert !). | `MovementRequested := NOT ArrivalLock AND (...)` ➔ **Fermeture immédiate du frein dès le 1er trou** (Trémie et P1), comme en `MANU`. |
| **3. `PRG_06_Outputs.st:448`** | `M3_TremieHardStopActive` dépendait de `ReqTremieSemantic` (tombé à `0` après 10 ms en `SEMI_AUTO`) et utilisait un champ `ReqMaintenanceSemantic` non déclaré. | `ReqMaintenanceSemantic` déclaré et câblé dans `PRG_05` ; `M3_TremieHardStopActive` reste actif tant qu'aucun recul (`ReqMaintenanceSemantic`) n'est demandé. |
| **4. `FB_CycleSemiAuto.st:1513`** | En `AX14`, `PositionTgt` tombait à `0` dès le 1er scan `Translation_At_Tremie`. | `PositionTgt := 1` maintenu pendant toute la confirmation d'arrêt `TranslationStopTimer`. |

### B. Les 6 Verrous `MAINT_N2` levés suite à l'audit des 2 Agents Ollama dédiés
1. **`FB_Modes.st:364` :** Scission `MAINT_N2` / `MAINT_N1`. En `MAINT_N2`, `JoystickWinchSelectArbitrated := JoystickWinchSelectRequest` (`0`, `1` ou `2`) sans jamais être forcé à `2` par `M3AtTremie` ni par `CoupledBucketSeqEnable`.
2. **`PRG_03_Modes_Cycle.st:532` :** `WinchDescentAuth_M3` forcé à `TRUE` en `MAINT_N2` (permet de descendre M1 et M2 même si M3 est à la trémie ou hors P1).
3. **`PRG_04_Treuils_Benne.st:501` :** Neutralisation de `BucketBusy`, `WinchBothMotionBlockedByBucket`, et `SyncBlocksAscent/Descent` en `MAINT_N2`.
4. **`PRG_04_Treuils_Benne.st:1120` :** En `MAINT_N2`, tant que `PowerContactorEngaged_DI = TRUE`, `SafeStopM1/M2_Active := FALSE` et `EffectivePermitM1/M2_Descend/Ascent := TRUE` (hors contact capteur mécanique haut `M1M2_TopPositionFree_DI`).
5. **`PRG_04_Treuils_Benne.st:1180 & 1617` :** Maintien de `ArmingPermit` (homme-mort) en `MAINT_N2` malgré un défaut latché, et synthèse de `BrakeFeedback` / `FwdRevSpeedFeedbackOff` en `MAINT_N2` pour que `FB_WinchOutputInterlock` ne coupe pas après 500 ms.
6. **`PRG_06_Outputs.st:355` :** `instSyncContactorFinal` bypassé en `MAINT_N2` pour autoriser tout pilotage séparé ou combiné des contacteurs sans coupure de discordance.

---

## ⏱️ 3. CHRONOLOGIE D'EXÉCUTION SUR SITE (CHECKLIST OPÉRATIONNELLE)

### 🔴 ÉTAPE 0 — Points Critiques Sécurité & Premier Chargement

- [ ] **0.1 — 🚨 Capteur FdC Haut M1/M2 shunté :**
  - Vérifier l'état physique du capteur `M1M2_TopPositionFree_DI` (shunté au bornier le 25/09 suite à casse plastique).
  - Tant qu'il est shunté, la barrière matérielle haute est absente : **ne jamais lancer d'ancien homing automatique** ; utiliser exclusivement l'approche manuelle prudente (`T377`).
- [ ] **0.2 — Sauvegarde `GVL_PERSISTENT` avant téléchargement (Zéro perte de data) :**
  - Se connecter en ligne CODESYS **sans charger** ➔ *Lire Recette / Sauvegarder* les valeurs de `GVL_PERSISTENT` (positions M3 `1,5 / 3,5 / 5,0 / 10,0 m`, gain `k`, références M1/M2 `8,50 m`, offsets benne).
  - *(Note : les 3 nouveaux réglages `TglAllowDumpInPV`, `TglRelaxSemiAutoStart`, `SetPauseBeforeDump_S` ont été placés en fin de `ST_CycleCmd` non persisté pour ne créer aucun décalage mémoire dans `GVL_PERSISTENT`).*
- [ ] **0.3 — Validation Compteurs Horaires (`T396` — `UDINT`) :**
  - Contrôler à l'IHM (`GVL_IHM.Commun.RunningHours`) l'affichage **Heures / Minutes** (Machine, M1, M2, M3) et leur conservation après redémarrage électrique.

---

### 🟠 ÉTAPE 1 — Validation Mode `MAINT_N2` (Commande Inconditionnelle Contacteurs & Treuils)

- [ ] **1.1 — Basculer en `MAINT_N2`** (chariot M3 à la trémie ou en zone intermédiaire, ou avec défaut simulé/présent).
- [ ] **1.2 — Tester les 3 sélections treuils au Joystick (avec homme-mort) et aux Boutons IHM :**
  1. **`WinchSel = 1` (M1 seul) :** Montée + Descente ➔ Vérifier fermeture franche de `M1_RelayAscent_RQ` / `M1_RelayDescent_RQ`, `M1_SpeedContactor_1..4_DQ` et `M1_BrakeRelease_RQ`.
  2. **`WinchSel = 2` (M2 seul) :** Montée + Descente ➔ Vérifier fermeture franche de `M2_RelayAscent_Close_RQ` / `M2_RelayDescent_Open_RQ`, `M2_SpeedContactor_1..4_DQ` et `M2_BrakeRelease_RQ`.
  3. **`WinchSel = 0` (M1 + M2 ensemble) :** Montée + Descente ➔ Vérifier que `JoystickWinchSelectArbitrated` reste bien à `0` (pas de bascule forcée à `2`) et que les deux treuils partent ensemble.

---

### 🟡 ÉTAPE 2 — Validation M3 & Options Cycle Semi-Auto avec `Trace_Site_M3_Par_Echelle.trace`

Charger dans CODESYS : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Trace_Site_M3_Par_Echelle.trace`
*(35 variables actives, toutes `Visible=True`, classées en 4 groupes d'échelle : `[1] Booléens -0.1..1.2`, `[2] Positions -1..11 m`, `[3] Step/Hz/% -5..105`, `[4] ActualFrequencyHz 0..5000`).*

1. **Test 2.1 — Arrêt au 1er trou capteur en `SEMI_AUTO` (`AX14` Trémie & `AX2` P1) à `20 Hz` :**
   - Observer sur la trace : dès le **1er front** de `M3_PosTremie_DI` (ou `M3_PosP1_DI`), `BrakeReleaseRequest` et `DriveControlWord` tombent immédiatement à `0` comme en `MANU` (~10 cm d'arrêt, plus de dérive à `-0,40 m` ou `+5,38 m`).
2. **Test 2.2 — Démarrage souple `AX1_INIT` (`GVL_IHM.CycleSemiAuto.Cmd.TglRelaxSemiAutoStart`) :**
   - À `FALSE` : vérifier l'affichage du motif exact si une condition manque (`M3 en zone Maintenance` vs `M1/M2 hors zone haute` vs `Etat benne non qualifie`).
   - À `TRUE` : vérifier le départ immédiat dès que les treuils sont dans la fenêtre haute élargie (`2,0 m`) sans exiger une qualification préalable de la benne.
3. **Test 2.3 — Pause avant ouverture benne (`GVL_IHM.CycleSemiAuto.Cmd.SetPauseBeforeDump_S`) :**
   - À `0.0` : enchaînement standard immédiat `AX14 ➔ AX15A ➔ AX15B`.
   - À `0.5` : vérifier en `AX15A` le maintien de 0,5 s (`AX15a - Stabilisation chariot avant ouverture benne.`) avant l'ouverture `AX15B`.
4. **Test 2.4 — Ouverture benne anticipée dès la zone PV (`GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV`) :**
   - Passer `TglAllowDumpInPV := TRUE`.
   - En `AX14`, dès que `M3_PosPV_DI = TRUE`, pousser le manche (`JoystickPush`) pour ouvrir la benne tout en avançant vers la trémie.
   - Vérifier que dès que `Benne_IsOpen = TRUE`, le cycle passe en **`AX18_DONE_SYNC`** et autorise le retour immédiat vers `P1` (`AX2`) même sans avoir touché `M3_PosTremie_DI`.

---

## 📋 4. TABLEAU DE BORD RAPIDE DES VARIABLES IHM (`GVL_IHM.CycleSemiAuto.Cmd`)

| Variable IHM | Type | Défaut | Effet immédiat |
|---|---|---|---|
| `GVL_IHM.CycleSemiAuto.Cmd.SetPauseBeforeDump_S` | `REAL` | `0.0` | Pause (s) à l'arrêt Trémie avant ouverture benne `AX15B` (`0.3` à `0.5` si secousse benne). |
| `GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV` | `BOOL` | `FALSE` | Autorise l'ouverture benne dès `M3_PosPV_DI` et le retour `P1` dès `Benne_IsOpen`. |
| `GVL_IHM.CycleSemiAuto.Cmd.TglRelaxSemiAutoStart` | `BOOL` | `FALSE` | Élargit la fenêtre haute `AX1_INIT` (`2,0 m`) et dispense de qualification benne au départ. |
