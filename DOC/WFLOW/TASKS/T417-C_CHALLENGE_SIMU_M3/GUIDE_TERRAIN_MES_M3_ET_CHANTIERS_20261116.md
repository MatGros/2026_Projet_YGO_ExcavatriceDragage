# 🛠️ GUIDE OPÉRATIONNEL DE MISE EN SERVICE — M3 & CHANTIERS ACTIFS (v2.0)

> **Date :** 2026-11-16 · **Version :** 2.0 (Intégration retours exploitant & analyse chaîne de code profonde)  
> **Format :** TDAH-Friendly · Checklists actionnables · Multi-hypothèses & Multi-solutions code  
> **Principe d'or :** En `MANU`, l'arrêt M3 est propre (~10 cm) et le frein tient. Si `SEMI_AUTO` dérive ou dépasse, la mécanique du frein est hors de cause : **c'est la chaîne logicielle/électrique `SEMI_AUTO` (entre le 1er trou capteur, la rampe, le maintien frein et l'ouverture benne) qu'il faut verrouiller.**

---

## 🎯 1. OBJECTIFS INITIAUX (`T417` / `T417-C` / `T334`) — VALIDÉ ✅

1. **Constat Machine Réelle (Terrain) :**
   - **En MANUEL :** Arrêt propre sur Trémie et P1 (~10 cm après le 1er trou capteur). Le frein mécanique tient parfaitement.
   - **En SEMI-AUTO (`AX14 ➔ AX15`) :**
     - **Déplacement lent (30 à 50 cm)** vers la butée mécanique *après* l'arrêt, pendant l'ouverture de la benne (`AX15B`), sans bruit moteur.
     - **Défauts `Brake M3` (`ErrorId=16` Méca B / `ErrorId=64`)** fréquents à `10 Hz` (avec saccades électriques), quasi disparus à **`20 Hz`**.
2. **Constat Simulation (Bureau) :**
   - L'IHM affiche **`0,0 m`** (Trémie) et **`5,0 m`** (P1), mais la position réelle simulée (`PositionTrue_M`) dépasse jusqu'à **`-0,40 m / -0,45 m`** (Trémie) et **`+5,38 m`** (P1).
3. **Objectif Opérationnel :**
   - Reproduire fidèlement le comportement en simulation (`T417-D`), comprenant la réalité mécanique du **trou dans le rail** (`on a le capteur ➔ on le perd au trou ➔ on le retrouve`).
   - Bloquer le mouvement dans ce sens **dès le premier trou** en `SEMI_AUTO` exactement comme en `MANU` (`T417-E`).
   - Intégrer et tester ensemble les **3 évolutions souplesse `T417-F`** (Pause `AX14/AX15`, Ouverture anticipée avant capteur Trémie en zone PV, Assouplissement du démarrage `AX1_INIT`).

---

## 🔍 2. DIAGNOSTIC PROFOND : POURQUOI « COUPER AU CAPTEUR » N'EST PAS SI SIMPLE DANS LE CODE

> 💡 **Réalité mécanique du capteur M3 :** Ce n'est pas une « came trop courte à rallonger », c'est un **trou mécanique dans le rail** (`CamDropoutActive` dans `FB_Sim_PositionSensor.st`). Quand le chariot avance, le capteur bascule au **1er trou** (`1 ➔ 0` ou `0 ➔ 1`), puis si le chariot glisse encore de quelques centimètres, il **sort du trou** et change à nouveau d'état avant de le retrouver.
> **Il faut donc impérativement bloquer et freiner dès le 1er trou, comme en `MANU`.**

### A. Pourquoi `MANU` s'arrête en 10 cm alors que `SEMI_AUTO` dépasse de 40 cm ? (Autopsie du code scan par scan)

En parcourant toute la chaîne (`PRG_03 ➔ PRG_05 ➔ FB_Translation ➔ FB_Brake ➔ PRG_06`), voici les **4 pièges en cascade** qui empêchaient un arrêt franc en `SEMI_AUTO` :

1. **Piège 1 — Retrait instantané de `ReqStart` en `SEMI_AUTO` (au bout de 10 ms) :**
   - En **`MANU`** : quand le chariot touche le 1er trou capteur, l'opérateur a encore le doigt sur le joystick pendant ~0,3 à 0,5 s ➔ **`M3_ReqTremie_Active` (`ReqTremieSemantic`) reste à `TRUE`**.
   - En **`SEMI_AUTO` (`FB_CycleSemiAuto.st:1490`)** : dès le 1er scan où `Translation_At_Tremie` (ou `Translation_At_P1` en `AX2`) passe à `TRUE`, le grafcet écrit immédiatement :
     `TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;`
     Dès ce scan (+10 ms), `instArbM3` met **`M3_ReqTremie_Active := FALSE`** !

2. **Piège 2 — Bascule sur la rampe LENTE au lieu de la rampe RAPIDE (`FB_Translation.st:291 & 306`) :**
   - Dans `FB_Translation.st:291` :
     `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) ...`
   - En **`MANU`** : comme `ReqTremie` reste `TRUE` face au permis coupé (`EffectivePermitM3_Tremie = FALSE`), `EffectiveSafeStop` passe à `TRUE` ➔ `SpeedRamp` décélère avec **`CfgRampDecelFastRate` (Rampe Rapide)** !
   - En **`SEMI_AUTO`** : comme `ReqTremie` tombe à `FALSE` au bout de 10 ms, `EffectiveSafeStop` retombe à `FALSE` ! `SpeedRamp` décélère alors tranquillement sur **`CfgRampDecelNormalRate` (Rampe Normale lente)** !

3. **Piège 3 — Le verrou `M3_TremieHardStopActive` de `PRG_06_Outputs` se désactive en 10 ms !**
   - Dans `PRG_06_Outputs.st:438` :
     `M3_TremieHardStopActive := M3_TremieHardStopLatched AND ReqTremieSemantic;`
   - En **`MANU`** : `ReqTremieSemantic` est `TRUE` ➔ `M3_TremieHardStopActive` coupe le variateur **ET** fait tomber `BrakeRelease_RQ := FALSE` immédiatement !
   - En **`SEMI_AUTO`** : `ReqTremieSemantic` tombe à `FALSE` après 1 scan (10 ms) ➔ **`M3_TremieHardStopActive` retombe à `FALSE` au bout de 10 ms** ! Le frein n'est donc **pas** coupé par `PRG_06`, il reste piloté par `FB_Translation.BrakeReleaseRequest` qui attend la fin de la rampe lente + `DelayMotorDecel` !

4. **Piège 4 — À `P1` (`AX2`), le debounce de `100 ms` (`CaptorDebounceTon`) est tué avant d'aboutir !**
   - Dans `PRG_05_Translation.st:433`, en `SEMI_AUTO`, `M3_TargetCodeSel` dépend de `SelTarget` (`ReqTranslation.PositionTgt`).
   - Comme `FB_CycleSemiAuto` met `PositionTgt := 0` dès le 1er scan où `M3_AtP1Stable` passe à `TRUE`, `M3_PositionSensorTarget` retombe à `FALSE` après 10 ms : le timer `CaptorDebounceTon` (`100 ms` dans `FB_Translation.st:192`) **n'atteint jamais 100 ms** en `SEMI_AUTO` ! `TargetReached` et `ArrivalLock` ne s'arment jamais sur P1 !

### B. Les 3 Hypothèses du déplacement lent sur site pendant l'ouverture benne (`AX15B`) — VALIDÉ ✅
| ID | Hypothèse | Mécanisme | Vérification Trace M3 |
|---|---|---|---|
| **H1** | **Maintien logique du frein ouvert (`BrakeReleaseRequest`)** | En `SEMI_AUTO`, à cause des Pièges 1-2-3 ci-dessus, `BrakeReleaseRequest` reste maintenu pendant la rampe + `TranslationStopTimer` (500 ms), laissant le chariot libre au début d'ouverture benne. | `M3_BrakeRelease_RQ` tarde à passer `1 ➔ 0` après le 1er trou capteur. |
| **H2** | **Secousse dynamique d'ouverture benne (`AX15B`) + Pente** | L'ouverture de la benne (`AX15B`) démarre alors que le chariot finit tout juste de s'immobiliser : le balancier/transfert de charge M2 tire le chariot. | Le mouvement coïncide exactement avec `Step = 16 (AX15B)` et `M2_RelayAscent_Close_RQ`. |
| **H3** | **Franchissement du 1er trou (`1 ➔ 0 ➔ 1`) et perte du verrou** | Si le chariot glisse hors du 1er trou pendant la décélération, un verrou non latché sur le 1er front relâche la sécurité. | `M3_PosTremie_DI` bat (`0 ➔ 1 ➔ 0`) pendant la décélération. |

---

## 🛠️ 3. LES OPTIONS DE SOLUTIONS CODE & LES 3 DEMANDES `T417-F` À TESTER ENSEMBLE

### A. Plusieurs solutions code pour bloquer au 1er trou en `SEMI_AUTO` (comme en `MANU`)
*(Ces options seront challengées par 5 sous-agents Ollama en parallèle pour garantir zéro effet de bord)* :

- **Solution S1 (Côté `FB_Translation` — Mémoire d'arrêt sur cible atteinte) :**
  - Dès que `PositionSensorTarget` (`M3_AtTremieStable` ou `M3_AtP1Stable`) ou `LimitSwitchTremie` est vu pendant un mouvement commandé (`LastMoveDirection = 1` ou `-1`), armer immédiatement **`ArrivalLock := TRUE`** (sans attendre 100 ms de debounce déjà filtré en amont par `M3_AtXxxStable`), forcer la **rampe rapide (`CfgRampDecelFastRate`)** ET couper `MovementRequested := FALSE` dès que la cible est touchée pour faire tomber le frein immédiatement comme en `MANU`.
- **Solution S2 (Côté `PRG_05` / `PRG_06` — Maintien de la coupure `HardStop` jusqu'à l'arrêt physique complet) :**
  - Dans `PRG_06_Outputs`, ne pas conditionner `M3_TremieHardStopActive` au seul `ReqTremieSemantic` (qui disparaît en 10 ms en `SEMI_AUTO`), mais à :
    `M3_TremieHardStopLatched AND (ReqTremieSemantic OR (LastMoveWasTremie AND NOT M3_PhysicallyStopped))`
    ➔ Coupe immédiatement `DriveControlWord := 0` et `BrakeRelease_RQ := FALSE` au 1er trou, exactement comme en `MANU`.
- **Solution S3 (Côté `FB_CycleSemiAuto` — Maintien de `PositionTgt` pendant `TranslationStopTimer`) :**
  - En `AX2` et `AX14`, quand `Translation_At_P1` / `Translation_At_Tremie` est atteint, couper `ReqStart := FALSE` mais **conserver `PositionTgt` (`3` ou `1`)** jusqu'à la sortie effective de l'étape (`TranslationStopTimer.Q`), pour que `PRG_05` et `FB_Translation` ne perdent jamais leur cible pendant le freinage.

---

### B. Le Lot des 3 Évolutions `T417-F` à coder et tester immédiatement en simulation

1. **Évolution F1 — Pause réglable entre `AX14` et `AX15B` (`CfgPauseBeforeDump_S`) :**
   - **Fonctionnement :** Ajout d'un paramètre réglable IHM (défaut `0,0 s`, testable à `0,3 s` / `0,5 s` / `1,0 s`) sur la transition d'arrivée trémie avant d'autoriser l'ouverture benne `AX15B`.
   - **But :** S'assurer que le chariot M3 est totalement figé et frein plaqué avant l'ouverture de la benne.

2. **Évolution F2 — Ouverture Benne anticipée avant capteur Trémie (`TglAllowDumpInPV`) :**
   - **Est-ce faisable rapidement et testable en simu ?** **OUI (100 % faisable et isolé dans `PRG_03` / `FB_Modes` / `FB_CycleSemiAuto`).**
   - **Fonctionnement avec simple bit IHM (`TglAllowDumpInPV : BOOL := FALSE` par défaut) :**
     - **En `AX14_TRANSLATE_DUMP` :** Si `TglAllowDumpInPV = TRUE` ET que le chariot est entré en zone PV (`TranslationPosPV = TRUE`, soit les 3,5 derniers mètres avant Trémie) :
       - L'opérateur peut commander l'ouverture de la benne (`BucketCmd.ReqOpen`) **pendant** ou dès l'approche PV (avec garde `WinchSel = 2` autorisée en zone PV).
       - Dès que la benne est ouverte (`Benne_IsOpen = TRUE`), la transition vers **`AX18_DONE_SYNC` ( puis retour `AX2` vers `P1`) est autorisée immédiatement**, même si le capteur `M3_PosTremie_DI` n'a jamais été touché !
     - **Si `TglAllowDumpInPV = FALSE` :** Comportement actuel strictement inchangé.

3. **Évolution F3 — Assouplissement & Diagnostic clair du Démarrage Semi-Auto (`AX1_INIT`) :**
   - **Fonctionnement :**
     - **Diagnostic immédiat :** Remplacer le message fourre-tout `16#0401` par le motif exact affiché sur la bannière IHM :
       1. `'AX1 - Chariot M3 en zone Maintenance : dégager vers P1'`
       2. `'AX1 - Treuils M1/M2 trop bas : remonter en zone haute'`
       3. `'AX1 - Etat benne incertain : ouvrir ou fermer la benne'`
     - **Bit d'assouplissement IHM (`TglRelaxSemiAutoStart : BOOL := FALSE` par défaut) :**
       - Quand `TRUE` : élargit la fenêtre haute de départ (`CST_CycleInitWindowM` ex. `0,50 m ➔ 1,50 m`) et n'exige plus que la benne soit en butée mécanique stricte `IsOpen/IsClosed` si les treuils sont déjà en sécurité haute (`CablePosM >= CfgCableLimitAscent_M - 1.5`). Permet de lancer les essais et la production sans blocage tatillon en `AX1_INIT`.

---

## ⏱️ 4. CHRONOLOGIE OPÉRATIONNELLE SUR SITE (PLAN D'ACTION PAS-À-PAS)

### 🔴 ÉTAPE 0 — Points Critiques Sécurité, Sauvegarde `GVL_PERSISTENT` & Chantiers Majeurs

#### 0.1 — 🚨 ALERTE CRITIQUE SÉCURITÉ : Capteur FdC Haut M1/M2 shunté
- [ ] **État terrain connu ([REGISTRE_PrepaNextMES_20260926.md](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/WFLOW/MISE_EN_SERVICE/REGISTRE_PrepaNextMES_20260926.md)) :** Le capteur mécanique de fin de course haut (`TopPositionFree_DI`) a été cassé le 25/09 puis **shunté électriquement au bornier par le client**.
- [ ] **Risque critique :** **Perte de la barrière matérielle ultime anti-collision haute** si ce shunt reste en place (seuls les codeurs M1/M2 protègent la montée).
- [ ] **Action obligatoire :**
  1. Vérifier dès l'arrivée sur site si le capteur mécanique TOP a été remplacé et décâblé de son shunt.
  2. Ne **jamais** lancer d'ancien homing automatique qui monte chercher le contact physique du capteur TOP !

#### 0.2 — Sauvegarde `GVL_PERSISTENT` avant le Premier Chargement (Zéro perte de data)
- [ ] **Se connecter en ligne CODESYS (sans charger)** et sauvegarder toutes les valeurs `GVL_PERSISTENT` actuelles (*Lire Recette* / export CSV / captures) :
  - Positions M3 (`1,5 / 3,5 / 5,0 / 10,0 m`), gain odométrique `k`, vitesses d'approche (`20 Hz`).
  - Références codeurs M1/M2 (`CfgTopSensorPos_M = 8,50 m`, `OffsetCloseM`, `OffsetOpenM`).
  - Réglages cycle (`ExtractionStartOpening_Pct = 10 %`, temps d'égouttage).
- [ ] Faire une archive complète `.projectarchive` de l'état automate trouvé sur site.
- [ ] Charger le nouveau programme et contrôler que `GVL_PERSISTENT` a conservé ou reçu ses bonnes valeurs.

#### 0.3 — Modification du Grafcet Homing Codeur et Benne (`T377`)
- [ ] **Principe du nouveau Grafcet Homing (`T377`) :**
  - **Montée manuelle prudente (`HX2_CLIMB_COUPLED`) :** L'opérateur monte manuellement au joystick (homme-mort + palier 1 lent) et s'arrête visuellement au repère haut (~8,50 m) **SANS toucher le capteur TOP**.
  - **Validation opérateur (`BtnValidation`) :** À l'arrêt et manche au neutre, l'appui sur `BtnValidation` passe en `HX3_REFERENCE_RESTORE` (applique `8,50 m` sur M1 et M2), vérifie en `HX4_REFERENCE_VERIFY`, puis qualifie la benne en `HX5 / HX6` (commit atomique benne + `MachineHomed := TRUE`).
  - **Barrière sécurité TOP (`HX2A_CONTACT_CLEARANCE`) :** Si le capteur TOP est touché par erreur, **aucun référencement n'est écrit**, la montée est bloquée et seule la descente manuelle est autorisée pour dégager.

#### 0.4 — Validation des Compteurs Horaires (`T396` — `UDINT`)
- [ ] Vérifier à l'IHM (`GVL_IHM.Commun.RunningHours`) l'affichage **Heures / Minutes** (Machine, M1, M2, M3) sans secondes ni bouton RAZ.
- [ ] Vérifier le maintien des compteurs après coupure/remise sous tension.

---

### 🟠 ÉTAPE 1 — Diagnostic & Validation M3 avec Trace Reclassée par Échelle

> 📊 **Révision de la Trace M3 (`Suivi_97_SIMU_M3_Translation`) :**
> Dans `Suivi_97_SIMU_M3_Translation_M3_manu_auto_20261116.trace`, les 30 variables avaient toutes la même échelle `[-12..12]` et 5 variables clés étaient masquées (`Visible=False`).
> **Nouvelle Trace M3 Optimisée (`Trace_M3_Par_Echelle.trace`) — toutes variables actives et classées en 4 groupes d'échelle :**
> - **Groupe 1 — Échelle `[0 .. 2]` (Booléens purement logiques 0/1) :**
>   - Capteurs : `M3_PosPV_DI`, `M3_PosTremie_DI`, `M3_PosP1_DI`
>   - Cibles & Verrous : `ReqTranslation.ReqStart`, `M3_AtTremieStable`, `M3_AtP1Stable`, `EffectivePermitM3_Tremie`
>   - Frein & Sens : `ReqTremieSemantic`, `BrakeCmd`, `BrakeReleaseRequest`, `M3_BrakeIsOpen_DI`
> - **Groupe 2 — Échelle `[-1 .. 11 m]` (Positions en mètres) :**
>   - `EstimatedPosM3_M` (Position IHM automate)
>   - `SimM3ObsPositionTrue_M` (Position physique vraie en simulation)
>   - `PositionTgt` (`0, 1=Trémie, 3=P1`)
> - **Groupe 3 — Échelle `[0 .. 100]` (Fréquences Hz, Consignes % et Étapes Grafcet) :**
>   - `SequenceState.Step` (`14=AX14`, `15=AX15A`, `16=AX15B`, `18=AX18`, `2=AX2`)
>   - `SpeedCmd_Pct` (`0..100 %`), `RequestedDriveFreqHz` (`0..50 Hz`), `DriveFreqCmd_Hz` (`0..50 Hz`)
>   - `TranslationState.ErrorId` (`0, 16, 64`)
> - **Groupe 4 — Échelle `[0 .. 5000]` (Mot brut variateur AC600 ×100) :**
>   - `PRG_02_Acquisition.Data.M3.ActualFrequencyHz` (`2000 = 20 Hz`, `5000 = 50 Hz`)

#### Déroulé des essais M3 (En Simulation d'abord, puis sur Site) :
1. **Test 1 — Approche `MANU` vs `SEMI_AUTO` au 1er trou capteur (`20 Hz`) :**
   - Vérifier sur la trace que dès le **1er trou** de `M3_PosTremie_DI` (et `M3_PosP1_DI` au retour), `SEMI_AUTO` coupe la consigne et ferme le frein **aussi vite qu'en `MANU`** (~10 cm, sans glisser jusqu'à `-0,40 m` ou `+5,38 m`).
2. **Test 2 — Activation de la Pause `CfgPauseBeforeDump_S` (`0,0 s` vs `0,5 s`) :**
   - Si en `AX15B` l'ouverture de la benne provoque un léger mouvement du chariot, régler `CfgPauseBeforeDump_S := 0.5` s pour séparer temporellement la fin du freinage M3 et le coup de bélier d'ouverture benne.
3. **Test 3 — Activation du bit `TglAllowDumpInPV = TRUE` (Ouverture anticipée en zone PV) :**
   - Vérifier qu'en entrant en zone PV (`M3_PosPV_DI = 1`), on peut ouvrir la benne avant le capteur Trémie et repartir directement vers `P1` (`AX18 ➔ AX2`) dès que la benne est ouverte.
4. **Test 4 — Activation du bit `TglRelaxSemiAutoStart = TRUE` (`AX1_INIT`) :**
   - Vérifier le lancement souple du cycle Semi-Auto et la précision des 3 messages de diagnostic si une condition initiale manque.
