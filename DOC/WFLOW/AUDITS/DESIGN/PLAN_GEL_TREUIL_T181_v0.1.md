# 🪝 PLAN DE GEL DU SOUS-SYSTÈME TREUIL — T181 · v0.1

> **Statut** : plan validé pour exécution — démarrage Phase -1.
> **Objectif utilisateur** : *« vraiment figer ce treuil »*, *« un winch qui fonctionne du premier coup »* — zéro aller-retour, zéro régression, pas de big-bang.
> **Date** : 2026-08-29. **Chapô** : T181. **Registre des tâches** : `T181_TASKS_YAML_BLOCK.yaml` (même dossier).
> **Détail de travail** : `PLAN_GEL_TREUIL_T181_CONSOLIDE.md` (brouillon de consolidation, conservé pour la traçabilité — v0.1 fait foi).

---

## Sommaire

- [0 · Sources consolidées](#0--sources-consolidées)
- [1 · Registre des défauts D01–D17](#1--registre-des-défauts-d01d17)
- [2 · Réconciliation avec les tâches vivantes](#2--réconciliation-avec-les-tâches-vivantes)
- [3 · Décisions figées (Q1–Q8)](#3--décisions-figées-q1q8)
- [4 · Contrat de flux `ST_fbWinch_DriveRequest`](#4--contrat-de-flux-st_fbwinch_driverequest)
- [5 · Autorité des 2 interlocks de cadence](#5--autorité-des-2-interlocks-de-cadence)
- [6 · Renommage vocabulaire](#6--renommage-vocabulaire)
- [7 · Phasage révisé + DAG](#7--phasage-révisé--dag)
- [8 · Registre des tâches T181-xx](#8--registre-des-tâches-t181-xx)
- [9 · Stratégie de test](#9--stratégie-de-test)
- [10 · Ordre d'application manuelle CODESYS](#10--ordre-dapplication-manuelle-codesys)
- [11 · Rollback & non-régression](#11--rollback--non-régression)
- [12 · Risques résiduels & validations humaines](#12--risques-résiduels--validations-humaines)
- [13 · Corrections à intégrer — challenge B2](#13--corrections-à-intégrer--challenge-b2-2026-08-29)

---

## 0 · Sources consolidées

| Source | Apport retenu |
|---|---|
| **Revue experte #1** (archi / POO) | `FB_Winch` pas un objet propre : entrées mortes `Mode` / `CycleTimeCalc` ; `StuckClosed` dupliqué ; délais d'interlock direction détournés en tempo de rampe palier (couplage caché) ; `SEL` direction `FB_Winch.st:248` nommé à l'envers. À extraire : direction-interlock, step-shaper, garde `Enable=FALSE`→sorties sûres. Piège : `FirstScanDone` capture `CommandedDirection` au 1ᵉʳ scan → bypass interlock au redémarrage à chaud. |
| **Revue experte #2** (fonctionnel / TC) | `F10.06..09` (Symmetry, SpeedStep, LoadEstimator, DriftGuard) **sans aucun TC**. `M1_Busy` / `M2_Busy` déclarés **jamais lus** → TC anti-traversée benne = **faux vert**. Pas de prolifération de TC : regrouper. |
| **Challenge #1** (séquencement) — **BLOCK** | (a) **harnais d'intégration** paire `M1+M2+PRG_04+PRG_06` (le CI est unitaire) ; (b) corriger les **C4 rouges AVANT** de toucher l'API ; (c) extraction sous-FB **après** interface stable ; (d) **contrat formel d'autorité des 2 interlocks** + preuve `FinalInterlockGoverned=FALSE` ; (e) plan **FAT / site / rollback / import**. |
| **Challenge #2** (interconnexion Grafcets / joystick / IHM) | `DriveRequest` couvre ~80 %. **4 amendements bloquants** : (A) clamp **par instance** ou scindé commun + plafond M2 propre — les bridages benne sont **M2-only**, sinon **régression M1** ; (B) **précédence Min/Max** → « plafond safety gagne » + garde `LIMIT` dans `FB_SpeedStep` ; (C) **aucun producteur de `MinStepDescent` n'existe** → à créer dans `FB_DiveSearch` ; (D) `MinStepNumber` agit sur la **cible**, lissé — interdit de forcer `StepNumber`. |
| **Rapports CI** (`TEST_AUTO_CI`) | `FB_WinchOutputInterlock` **2/7** · `FB_Winch` **5/7** · `FB_Bucket` **14/17** · `FB_Safety_Winch` **14/14** · `FB_WinchSync` **4/4**. |
| **Constats P0** | Clamp M1 (≈2 conditions) ≠ M2 (≈4) — `SEL()` dupliqués inline `PRG_04:679-681 / 716-717`. Garde-fou survitesse **mort** (`MeasuredSpeedBand:=0` en dur `:682,718`, `SpeedGuardEnable=FALSE`). `ForceMinSpeedStep` = **plafond** (`MaxStepAscent:=1`), sémantique inversée. Pas de `MinStep`. Reconstruction table ≈24 affectations `PRG_04:405-429` = 2ᵉ mécanisme. `FB_DiveSearch.CurrentSpeedStep` **jamais câblé** → interdiction palier 5 Kobold **morte**. |
| **Décisions Q1–Q8** | voir §3. |
| **Infra CI existante** | `FB_Main_EndToEnd` (`TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/`) **chaîne déjà PRG_02→07 en boucle fermée** (entrée registre `MAIN_EndToEnd`, primitives `ADVANCE_TIME` + steps cycliques). Mince (2 tests, joystick raw, zéro assert clamp/palier/interlock). Le harnais Phase -1 **l'étend**, ne le bâtit pas. |

---

## 1 · Registre des défauts D01–D17

| ID | Défaut | Preuve | Crit. | Critère de sortie mesurable | Porté par |
|---|---|---|---|---|---|
| **D01** | Barrière finale `FB_WinchOutputInterlock` non fiable | CI 2/7 (TC-012/013/021/022, 020 SITE) | C4 | CI `FB_WinchOutputInterlock` **7/7** sur interface inchangée | T181-01 |
| **D02** | `FB_Winch` : inversion sens | CI 5/7 (FAIL TC-011) | C4 | CI `FB_Winch` **7/7** ; interface inchangée | T181-02 |
| **D03** | `FB_Bucket` : confirm MAINT + timeouts | CI 14/17 (TC-030, 046.1, 047.1) | C3 | CI `FB_Bucket` **17/17** ; TC-030 via matrice maint | T181-14 + **T175 AC4** |
| **D04** | Anti-traversée benne = chemin mort | `M1_Busy`/`M2_Busy` 0 lecture ; TC-025 faux vert | C3 | `*_Busy` consommés (G200) ; TC ré-écrit | **T175 AC3** (T181-04 retirée) |
| **D05** | Clamp palier M1 ≠ M2, dupliqué inline | `PRG_04:679-681` vs `:716-717` | C4 | 1 agrégateur ; sources commun/M2 tabulées ; `SEL()` inline supprimés | T181-06, T181-10 |
| **D06** | Garde-fou survitesse mort | `MeasuredSpeedBand:=0` en dur ; `SpeedGuardEnable=FALSE` | C3 | `MeasuredSpeedBand` câblé via `Sensors` ; survitesse active ssi table complète + débrayable ; TC-055/060 | T181-16 (**sur T177**) |
| **D07** | `StuckClosed` : 2 propriétaires | `FB_Winch.st:292-298` vs `FB_Safety_Winch.st:246-256` | C4 | 1 seul propriétaire = `FB_Safety_Winch` ; TC-018 côté Safety | T181-03 |
| **D08** | `ForceMinSpeedStep` inversé + pas de `MinStep` | `FB_ExtractionSequence.st:272` → `PRG_04:681,717` | C3 | Renommé `ExtractionControlActive` (chaîne complète) ; `FB_SpeedStep.MinStepNumber` ajouté | T181-07, T181-09 |
| **D09** | Entrées mortes `FB_Winch` | `Mode` (`:18`), `CycleTimeCalc` (`:82,170`) | C2 | Retirées ; fiche `FB_Winch_v1.0.md` réécrite | T181-05, T181-18 |
| **D10** | Délais direction détournés en tempo rampe + `SEL` à l'envers | `FB_Winch.st:248` | C3 | Tempo rampe = paramètre dédié (`FB_WinchStepShaper`) ; `SEL` corrigé/justifié + TC | T181-05 |
| **D11** | `F10.06..09` sans TC | Symmetry / SpeedStep / LoadEstimator / DriftGuard | C1 | ≥ 1 TC macro justifié par fonction | T181-18 |
| **D12** | Bypass survitesse Kobold mort | `FB_DiveSearch.CurrentSpeedStep` jamais passé en argument | C3 | `CurrentSpeedStep` câblé ; interdiction palier 5 effective ; TC | T181-12 |
| **D13** | 2 mécanismes « tout palier 1 » pour M2 | `SEL(...,1)` `:716` + reconstruction table `:405-429` | C3 | Décision actée : table supprimée si `MaxStepDescent:=1` suffit, sinon conservation motivée | T181-10 |
| **D14** | `ControlAscentActive` (PRG_04) ⟷ `ExtractionControlActive` : 2 flags même effet | `PRG_04:341-357` vs `FB_ExtractionSequence.st:272` | C2 | 1 seul flag « montée contrôlée → `MaxStepAscent:=1` » | T181-09 |
| **D15** | ~20 `Bypass*` OR-és, pas de matrice de mode | `PRG_04:554-627` + `FB_Safety_Winch.st:63-66` | C3 | Matrice bypass N1/N2 explicite ; N1 momentané, N2 latché, re-homing, tout à l'arrêt | T181-11, T181-14 |
| **D16** | Coast-down / plongée frein 1–2 m non bornée | REX utilisateur (ex-T054) | C4 | Armement DriftGuard Méca A sur « contacteurs-off + frein serré » — **pas** de `CfgWinchCoastMax_M** | **T178** (T181-17 retirée) |
| **D17** | Fiche `FB_Winch_v1.0.md` périmée | cartouche-sync | C1 | Fiche régénérée = interface finale | T181-18 |

---

## 2 · Réconciliation avec les tâches vivantes

Le plan T181 **ne re-crée pas** ce qui est déjà tracé. Il se coordonne :

| Tâche vivante | Statut | Ce qu'elle porte | Interaction T181 |
|---|---|---|---|
| **T175** | ⏳ C4 (contrat) | Temps mort directionnel TC-021/022 (AC2) · **anti-traversée benne** `M1/M2_Busy` TC-025 (AC3) · MAINT_N1/N2 confirm benne TC-030 (AC4) · gates palier C | **T181-01** partage l'implémentation du temps mort (AC2, pas de doublon) · **T181-04 RETIRÉE** = T175 AC3 · **T181-14** intègre T175 AC4 |
| **T176** | ⏳ C3 (contrat) | `ArmingPermit` câblé `TRUE` en dur (joystick) | Connexe, **hors périmètre T181** — noté prérequis d'armement joystick |
| **T177** | ⬜ C3 (contrat) | `SpeedGuardEnable := TRUE` par défaut + garde vitesse en défaut | **Prérequis de T181-16** (`bloque_par: T177`) — T181-16 **consomme** son résultat, ne l'absorbe pas |
| **T178** | ⬜ C4 (contrat) | `DriftGuardA.Arm` conforme AF = contacteurs-off + frein serré. **A rejeté** `CfgWinchCoastMax_M` / `RunOn` (redondants avec Méca B 3 s) | **T181-17 RETIRÉE** — le coast-down borné est couvert par T178 + Méca B. Le harnais T181-00 vérifie « coast normal → pas de faux `PowerCutOff` » |
| **T169 / T169-A** | ⏳ | Harnais de tests CI scénarios dragage | **T181-00 se greffe** dessus (extension `FB_Main_EndToEnd`), ne le double pas |
| **T180** | ⬜ C4 | Audit 29 cas limites sécurité (2 C4 : chute de charge) | Vecteurs T181-00 **croisés** avec les `CAS-xxx` (au moins CAS-001 retombée contacteur en marche, CAS-012 = T175) |
| **T096** | (absorbée) | Apprentissage vitesse par palier | **Absorbée** par T181-15 (collecteur) + T181-13 (plancher plongée) |
| **T130 / T131 / T135** | ⏸️ | Refactor intention palier (INT) | **Supersédées** par T181-06/07 (`DriveRequest` + `MinStepNumber`) |

---

## 3 · Décisions figées (Q1–Q8)

| Sujet | Décision |
|---|---|
| **Apprentissage** | 1 **bit IHM** « lancer apprentissage ». Collecteur **passif** (non bloquant). Voyant IHM. |
| **Table apprise** | `{M1/M2 × sens × charge / vide × palier 1-5}`, **RETAIN**. Charge **et** vide. Calibration **rare**. Tant qu'incomplète → **non applicable** ; **bypass facile**. |
| **Seuils survitesse** | Marge **fixe** sur la vitesse apprise : `appris + 0,5 m/s` (soft → diag) / `appris + 1,5 m/s` (hard → **SafeStop**). |
| **Surveillance survitesse** | Active **ssi** table `{sens, charge}` complète **+** flag débrayable. |
| **Invariant clamp** | `Min < Max` toujours. **Plafond (safety) gagne**. |
| **Fonction unifiée** | `Min/MaxStep{Ascent,Descent}` — même sémantique et mêmes bornes **communes** M1=M2, calcul unique. Bornes **propres benne** restent M2 (challenge #2-A). **Pas de `Force*`** dans le vocabulaire du clamp. |
| **Requête plancher** | Vient d'une **étape de séquence** (ou geste joystick), injectée comme **paramètre** `MinStep*`. |
| **Interlock cadence** | **1 FB, 2 niveaux** : `FB_Winch` (seuils safety **+ marge**) **ET** `PRG_06` (seuils safety nus). `FinalInterlockGoverned` **DOIT rester FALSE** en nominal. Si `PRG_06` limite → **le signaler**. |
| **`StuckClosed`** | Propriétaire **unique** = `FB_Safety_Winch`. |
| **Override FDC** | N1 : bouton IHM **maintenu momentané** · N2 : latché. Capteur homing top **toujours >** FDC logiciel : **8,5 m** / **7,5 m**. Arrêt normal **7,5 m**. Override **≤ 8,5 m**. |
| **Plongée Kobold** | Plancher **3-4 constant**. Palier 5 **interdit**. Joystick hors neutre → **≥ plancher** (montée lissée). Relâche → **0 immédiat**. |

---

## 4 · Contrat de flux `ST_fbWinch_DriveRequest`

### Interface cible

```
FB_Winch.VAR_INPUT
    Enable, Reset, PowerContactorEngaged : BOOL
    DriveRequest : ST_fbWinch_DriveRequest
    Sensors      : ST_fbWinch_Sensors
    SafeStop, DescendPermit, AscentPermit : BOOL   (* sorties FB_Safety_Winch, DÉJÀ arbitrées paire+sync par PRG_04 *)
    Config       : ST_fbWinch_Cfg

ST_fbWinch_DriveRequest
    StartStop      : BOOL
    Direction      : INT     (* -1 / 0 / +1 *)
    SpeedTgt_Pct   : REAL    (* 0..100, continu *)
    MinStepAscent  : INT     MaxStepAscent  : INT
    MinStepDescent : INT     MaxStepDescent : INT
    SyncCoupled    : BOOL    (* DIAG STRICT — FB_Winch ne le lit JAMAIS en logique *)

ST_fbWinch_Sensors : CablePosM, Homed, HomingSuspect, FwdRevSpeedFeedbackOff, MeasuredSpeedBand, MeasuredSpeedValid
ST_fbWinch_Cfg     : SpeedStepTable, HystMargin, DirectionInterlockDelay*, ContactorFeedbackTimeout,
                     TopLimitM, BottomLimitM, SlowdownDistanceM, SlowdownMaxStep, HomingApproachActive
```

### 4-A · Sources de clamp — commun vs M2-propre (amendement A, BLOQUANT)

| Source de borne | Sens | Portée | Où calculée |
|---|---|---|---|
| `SyncDeviationWarn` → plafond 1 | Asc + Desc | **commun** M1 = M2 | agrégateur PRG_04 |
| Zone de ralentissement bordure (`CablePosM` vs `SlowdownDistanceM`) → `SlowdownMaxStep` | selon sens | **par instance** (position câble propre) | agrégateur PRG_04, `Sensors.CablePosM` de chaque instance |
| `HomingApproachActive` → plafond 1 | Asc | **commun** | agrégateur PRG_04 |
| **Dive floor** Kobold → `MinStepDescent = 3` (`CfgDiveFloorStep`) | Desc | **commun** | producteur `FB_DiveSearch` (amendement C) |
| `ExtractionControlActive` (ex-`ForceMinSpeedStep`) → plafond 1 | Asc | **commun** | `FB_ExtractionSequence` → PRG_03 → PRG_04 |
| `M2_BucketJogLimit` (ex-`M2_ForceSlowSpeed`) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur PRG_04, branche M2 |
| `ManualBucketLimitsActive` (FDC benne MAINT) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur PRG_04, branche M2 |
| `BucketNotClosedAscentStep1` / `SlackCableAscentStep1` | Asc | **M2 uniquement** (géométrie benne) | agrégateur PRG_04, branche M2 |

> ⚠️ Câblage strictement identique M1 = M2 = **régression M1** dès que la benne jogge en pilotage unitaire. L'agrégateur produit `commonMin/Max{Asc,Desc}` (identiques) **puis** M2 applique `MIN(…, plafondBenne)`.

### 4-B · Précédence Min/Max (amendement B, BLOQUANT)

1. `MaxStep := MIN(sources plafond)` — un seul endroit (agrégateur PRG_04).
2. `MinStep := MAX(sources plancher)`.
3. **Plafond gagne** : garde `FB_SpeedStep` → `MinClamped := LIMIT(1, MinStepNumber, MaxStepClamped)` **après** le plafond, **avant** `CASE StepNumber`.
4. TC : `MinStepDescent = 3` (Kobold) + bordure basse voulant `MaxStepDescent = 1` → résultat **1**.

### 4-C · `MinStepNumber` agit sur la cible (amendement D, BLOQUANT)

- `FB_SpeedStep` : `RequestedStep := MAX(sel_hyst, MinClamped)` **avant** retour.
- Montée `StepNumber 0→1→2→3` **cadencée par `FB_WinchStepShaper`** (~0,5–1 s/cran).
- **Interdit** : `StepNumber := MinStepNumber` direct (= court-circuit rampe = à-coup contacteur).
- `MinStep` **sans effet si `StartStop = FALSE`** (relâche → palier 0).
- Corriger `FB_Winch.st:248` (`SEL` direction inversé — pilote l'accostage en plongée).

### 4-D · Matrice d'interconnexion producteurs → `DriveRequest`

| Producteur | Émet aujourd'hui | → `DriveRequest` | Statut |
|---|---|---|---|
| **FB_Cycle** (Grafcet X0-X13) | `ST_fbCycle_WinchCmdDemand {StartStop, Direction:INT, SpeedPct:REAL}`, vitesses codées en dur | `StartStop`/`Direction`/`SpeedTgt_Pct` 1:1 | ✅ — **ne pas** fusionner `ST_fbCycle_WinchCmdDemand` avec un refactor palier-INT |
| **PRG_03** | `Data.ReqProgram.ReqWinchM1/M2` — SEMI_AUTO uniquement, forcé 0 en MAINT/DISABLE | via PRG_04 §3 | ✅ sélecteur mode-gated |
| **FB_DiveSearch** | `DescendPermit`, `KoboldMeasureEnable` — **aucune consigne** ; `CurrentSpeedStep` = entrée jamais câblée | doit produire **`MinStepDescent`** | ⚠️ **amendement C** — producteur à créer (T181-12) |
| **FB_ExtractionSequence** | `ForceMinSpeedStep := AscentPermit` | `MaxStepAscent := 1` (renommé `ExtractionControlActive`) | ✅ nom trompeur → rename |
| **FB_Joystick** | `AxisCmdY {SpeedTgt:REAL 0..100, Direction:INT, StartStop, Enable}` | `SpeedTgt_Pct`/`Direction`/`StartStop` | ✅ nominal / ⚠️ plongée (granularité 0-40 % perdue — assumé, lissé) |
| **FB_Modes** | `Auth.Mode`, `SyncEnable`, `InhibitM1/M2`, `JoystickWinchSelectArbitrated`, `HomingApproachEnable` | gating amont + `Config.HomingApproachActive` + `SyncCoupled` (diag) | ✅ si sync reste hors `FB_Winch` |
| **IHM directe** | `GVL_IHM.M1TreuilRetenue.Cmd.BtnUp/Down` … → `SpeedCmd_Pct := 100.0` en dur | `Direction`/`StartStop`/`SpeedTgt_Pct` | ✅ trivial |
| **FB_Bucket** (M2 caché) | `M2_StartStop/M2_Direction/M2_ForceSlowSpeed` → 15 % en dur + swap table P1 | `StartStop`/`Direction`/`SpeedTgt_Pct=15` + `MaxStepDescent:=1` | ⚠️ sens M2 = propriété `FB_Bucket` ; swap table → D13 |

**Règle d'or** : aucun arbitrage `StartStop`/`Direction`/`SpeedTgt_Pct` ne migre dans `FB_Winch`. Tout reste `PRG_04` §3. Place de l'override benne (`instBucket.Busy`) : à fixer explicitement dans le contrat T181-06.

---

## 5 · Autorité des 2 interlocks de cadence

### Contrat formel

| | Instance `FB_Winch` (interne) | Instance `PRG_06` (barrière finale) |
|---|---|---|
| Rôle | **Gouverne** la cadence en nominal | **Filet de sécurité** — ne doit jamais agir en nominal |
| Seuils | safety **+ marge** (plus serrés) | safety **nus** |
| Effet | limite `StepNumber` / temporise transition | coupe `Cmd` contacteur (dernier recours) |
| Diag | `RateGoverned` (info) | **`FinalInterlockGoverned`** |

### Critères d'acceptation (sans HIL)

1. `FinalInterlockGoverned = FALSE` sur **100 %** des vecteurs nominaux (harnais T181-00 : Grafcet X0-X13, rampes joystick, plongée, extraction, benne). TC dédié.
2. `FinalInterlockGoverned = TRUE` → **trace horodatée** + latch diag + remontée IHM (le code amont est en défaut, pas la sécurité).
3. Injection : cadence > seuil safety **en contournant** l'instance `FB_Winch` (stub) → l'instance `PRG_06` **coupe**.
4. Pas de **double-freinage** : quand l'instance `FB_Winch` gouverne (marge), l'instance `PRG_06` **reste passive**.

---

## 6 · Renommage vocabulaire

| Ancien | Nouveau | Points d'impact |
|---|---|---|
| `ForceMinSpeedStep` | `ExtractionControlActive` | `FB_ExtractionSequence.st:48,194,213,272` · `ST_ProgramBucketRequest.st:13` · `PRG_03:242,319,401` · `PRG_04:681,717` |
| `ControlAscentActive` (PRG_04 local) | **fusionné** dans `ExtractionControlActive` | `PRG_04:341-357` |
| `CfgMaxStepDescente` | `MaxStepDescent` | `PRG_04:679,716` + fiches AF |
| `M2_ForceSlowSpeed` | `M2_BucketJogLimit` — **Max**, pas `Force` | `PRG_04:285-288,716-717` + `FB_Bucket` |
| `M2_SpeedStepTableActive` (si conservé) | à statuer (D13) | `PRG_04:405-429` |

> 1 oubli = liaison G200 rouge → renommage **transverse en une passe**, `run_all_gates` immédiat.

---

## 7 · Phasage révisé + DAG

```
Phase -1  HARNAIS + PLAN DE TIR                                    [BLOQUANT tout]
          ├─ Étendre FB_Main_EndToEnd : paire M1+M2 + PRG_04 + PRG_06, vecteurs Grafcet/joystick/plongée
          ├─ Plan FAT / essais site / rollback / ordre d'import CODESYS manuel
          └─ Baseline : rejouer CI actuel, figer 5/7-2/7-14/17 comme référence           → T181-00

Phase 0   CORRECTIONS C4 — INTERFACE FB_Winch INCHANGÉE           [bloque A, C]
          ├─ D01  FB_WinchOutputInterlock 7/7 + FB_WinchRateInterlock + autorité 2 interlocks  → T181-01
          ├─ D02  FB_Winch TC-011 Fwd/Rev                                                       → T181-02
          ├─ D07  StuckClosed → FB_Safety_Winch                                                 → T181-03
          └─ D04  Anti-traversée benne : couverte par T175 AC3                        (T181-04 RETIRÉE)

Phase 0b  EXTRACTION SOUS-FB — interne, interface INCHANGÉE       [bloque_par: 0]
          └─ FB_WinchDirectionInterlock + FB_WinchStepShaper + retrait Mode/CycleTimeCalc       → T181-05

Phase A   INTERFACE DriveRequest + CLAMP UNIFIÉ — SHADOW COMPARISON [bloque_par: 0b]
          06  Cadrage ST_fbWinch_DriveRequest + AF-10          [ARRÊT VALIDATION HUMAINE]       → T181-06
          07  FB_SpeedStep : + MinStepNumber + garde LIMIT                                      → T181-07
          08  Refonte interface FB_Winch + 2 sites PRG_04 + SimBench  [SHADOW]                   → T181-08
          09  Renommage vocabulaire complet + fusion des 2 flags                                → T181-09
          10  Agrégateur clamp PRG_04 (commun vs M2-propre) + D13                               → T181-10
          12  Producteur MinStepDescent (FB_DiveSearch) + CurrentSpeedStep                      → T181-12
          13  Palier plancher plongée Kobold + geste joystick lissé + AF-04                     → T181-13
          19  Câbler SyncCoupled (diag) + garde diag-only                                       → T181-19

Phase C   MATRICE MAINTENANCE N1/N2                             [bloque_par: 0]
          11  Cadrage matrice bypass + AF-05                     [ARRÊT VALIDATION HUMAINE]     → T181-11
          14  Code matrice bypass FB_Modes + PRG_04 + override FDC N1 8,5 m + T175 AC4          → T181-14

Phase B   APPRENTISSAGE + SURVITESSE
          15  FB_WinchSpeedLearning collecteur passif (bloque_par: 0b)                          → T181-15
          16  Survitesse FB_Safety_Winch + SpeedGuard (bloque_par: 10, 14, 15, T177)           → T181-16
          --  Coast-down borné : couvert par T178 + Méca B                            (T181-17 RETIRÉE)

Phase D   RÉTRO-TC + DETTE                                       [bloque_par: A]
          18  TC macro F10.06..09 + fiche FB_Winch + fix sérialisation traçabilité              → T181-18
```

### DAG condensé

```
-1 ──► 0 ──► 0b ──► A ──► D
        │            │
        ├──► C ◄──────┤     (C dépend de A pour le vocabulaire ; C ≠ parallèle à B)
        │            │
        └──► B15 ─────┴──► B16   (B16 dépend de A + C + B15 + T177)
```

---

## 8 · Registre des tâches T181-xx

Source de vérité : **`T181_TASKS_YAML_BLOCK.yaml`** (21 entrées : chapô + T181-00→19, dont T181-04 et T181-17 ❌ retirées). Résumé :

| ID | Phase | Titre | Crit. | bloque_par | Contrat |
|---|---|---|---|---|---|
| T181-00 | -1 | Harnais intégration ST paire + plan de tir | C4 | — | — |
| T181-01 | 0 | `FB_WinchOutputInterlock` 7/7 + autorité 2 interlocks + `FB_WinchRateInterlock` | C4 | 00 | ✅ `T181-01` |
| T181-02 | 0 | `FB_Winch` TC-011 Fwd/Rev, interface inchangée | C4 | 00 | — |
| T181-03 | 0 | `StuckClosed` → propriétaire unique `FB_Safety_Winch` | C4 | 00 | — |
| ~~T181-04~~ | 0 | ❌ RETIRÉE — = T175 AC3 | — | — | — |
| T181-05 | 0b | Extraction sous-FB + retrait `Mode`/`CycleTimeCalc` | C3 | 01,02,03 | — |
| T181-06 | A | Cadrage `ST_fbWinch_DriveRequest` + AF-10 · **arrêt humain** | C4 | 05 | ✅ `T181-06` |
| T181-07 | A | `FB_SpeedStep` + `MinStepNumber` + garde `LIMIT` | C3 | 06 | — |
| T181-08 | A | Refonte interface `FB_Winch` + 2 sites PRG_04 + SimBench · **shadow** | C4 | 07 | — |
| T181-09 | A | Renommage vocabulaire + fusion des 2 flags | C3 | 08 | — |
| T181-10 | A | Agrégateur clamp PRG_04 (commun/M2) + D13 | C4 | 09 | — |
| T181-11 | C | Cadrage matrice maintenance N1/N2 + AF-05 · **arrêt humain** | C3 | 01 | ✅ `T181-11` |
| T181-12 | A | Producteur `MinStepDescent` (`FB_DiveSearch`) + `CurrentSpeedStep` | C3 | 10 | — |
| T181-13 | A | Palier plancher plongée Kobold + geste joystick lissé + AF-04 | C3 | 12 | — |
| T181-14 | C | Code matrice bypass + override FDC N1 8,5 m (inclut T175 AC4) | C3 | 11,10 | — |
| T181-15 | B | `FB_WinchSpeedLearning` collecteur passif | C3 | 05 | — |
| T181-16 | B | Survitesse `FB_Safety_Winch` + réactivation SpeedGuard | C4 | 10,14,15,**T177** | — |
| ~~T181-17~~ | B | ❌ RETIRÉE — coast-down couvert par T178 + Méca B | — | — | — |
| T181-18 | D | Rétro-TC F10.06..09 + fiche `FB_Winch` + fix sérialisation | C1 | 10 | — |
| T181-19 | A | Câbler `SyncCoupled` (diag) + garde diag-only | C2 | 08 | — |

3 arrêts de validation humaine : **T181-01** (autorité interlocks), **T181-06** (interface DriveRequest), **T181-11** (matrice maintenance).

---

## 9 · Stratégie de test

### Unitaire (STruCpp CI) — regroupé, justifié
Réparer : TC-P10-011, 012, 013, 018, 021, 022, 030, 046.1, 047.1. Nouveaux (1 macro par besoin) : `MinStepNumber` + précédence, `FinalInterlockGoverned=FALSE` nominal, injection filet interlock, shadow-diff clamp, interdiction palier 5 Kobold.

### Intégration (harnais T181-00, extension de `FB_Main_EndToEnd`)
| Test | Vecteur | Attendu |
|---|---|---|
| Grafcet↔Winch | chaque étape X1…X11 : `{Direction, SpeedPct}` | `StepNumber` M1/M2 résultant compte tenu des clamps (bordure, sync) |
| Joystick↔Winch | rampe déflexion 0→100 % puis 100→0 | séquence `StepNumber` avec/sans `MinStepDescent` ; `StepNumber` ≤ +1/cycle |
| Dive floor | effleurement joystick ~5 % | transitions `0→1→2→3` temporisées ; relâche → 0 immédiat |
| Régression M1 | benne en `M2_BucketJogLimit` + M1 demande palier 4 | M1 **reste à 4** |
| Autorité interlock | cadence forcée > safety en contournant l'instance `FB_Winch` | l'instance `PRG_06` **coupe** ; pas de double-freinage nominal |
| Sync paire | déviation injectée | `SyncDeviationWarn` → plafond 1 **sur M1 ET M2** |
| Croisement T180 | CAS-001 (retombée contacteur en marche), CAS-012 (anti-traversée) | comportement sûr documenté |

### FAT / essais site (plan Phase -1, hors CI)
Checklist import CODESYS · essai à vide paliers 1→5 M1/M2/couplé · essai coast-down mesuré · essai override FDC N1 (borne 8,5 m physique) · campagne apprentissage charge/vide · bascule survitesse ON après table complète — vérif non-déclenchement nominal.

---

## 10 · Ordre d'application manuelle CODESYS (par lot)

1. DUT d'abord : `ST_fbWinch_DriveRequest`, `_Sensors`, `_Cfg`, sous-FB extraits.
2. FB feuilles : `FB_SpeedStep`, `FB_WinchDirectionInterlock`, `FB_WinchStepShaper`, `FB_WinchRateInterlock`.
3. `FB_Winch`, `FB_Safety_Winch`.
4. `FB_DiveSearch`, `FB_ExtractionSequence` (rename).
5. `PRG_03` puis `PRG_04` puis `PRG_06`.
6. `FB_SimBench` / simulation en dernier.
7. Régénérer bundle → `G200_check_linkage.py --report` → `run_all_gates.py`.
8. Bandeau de restitution (bundle frais + gates verts).

---

## 11 · Rollback & non-régression

- **Checkpoint commit** avant chaque phase (`wip(treuil): phase X [NON TESTE]`).
- Shadow comparison (Phase A) = rollback logique : l'ancien calcul reste présent jusqu'à bascule validée.
- Point de retour Git par phase (tag `t181-phase0-ok`, etc.).
- Non-régression hors treuil : `run_all_gates.py` complet (21 gates) à chaque fin de phase.
- Appelants transverses à vérifier : `PRG_02_Acquisition`, `PRG_07_Supervision`, `GVL_Troubleshooting`.
- `Device.export` **jamais** utilisé comme référence — export frais si comparaison nécessaire.

---

## 12 · Risques résiduels & validations humaines

| Risque | Mitigation |
|---|---|
| Rename transverse : 1 oubli → G200 rouge | passe unique + `run_all_gates` immédiat (T181-09) |
| Shadow comparison masque un vecteur non couvert | garder shadow actif **N phases** ; log des divergences |
| Dépendance C↔B sous-estimée (matrice maint conditionne l'armement survitesse) | T181-16 `bloque_par` explicite 14 |
| `ST_fbCycle_WinchCmdDemand` fusionné par erreur avec refactor palier-INT | interdiction écrite, `test_fb_cycle` en garde |
| Harnais T181-00 incomplet → faux sentiment de sécurité | revue humaine de la **liste des vecteurs** avant Phase 0 |
| Collision avec T175/T177/T178 (autre piste) | §2 réconciliation : T181 référence, n'absorbe pas ; `bloque_par: T177` ; T181-04/17 retirées |
| Agent distant s'auto-valide | validation finale = orchestrateur (lecture `git diff` réel) |

**3 arrêts de validation humaine obligatoires** : T181-01 (contrat d'autorité des 2 interlocks), T181-06 (note de cadrage `DriveRequest`), T181-11 (matrice de maintenance).

---

## 13 · Corrections à intégrer — challenge B2 (2026-08-29)

> 3ᵉ challenge indépendant (subagent Claude, accès dépôt). Rapport complet :
> `BRIEFS_T181/RESULTS/B2_challenge3_resultat.md`. Verdict : *« proche, mais ne donne pas encore
> un winch qui fonctionne du premier coup »*. À intégrer avant le lancement de Phase 0.

### Écarts sécurité relevés en passant

| # | Fait | Emplacement | Suite |
|---|---|---|---|
| **S1** | L'interlock de cadence dans la barrière finale **n'existe pas** (`StepDelay` TON câblé `IN:=FALSE`). T181-01 le **crée**, ne le fiabilise pas. | `FB_WinchOutputInterlock.st:213…246` | Reformuler T181-01 (fait) |
| **S2** | Garde-fou survitesse **neutralisé** et le reste jusqu'à T181-16 (Phase B) — donc pendant les 1ᵉʳˢ essais site. | `PRG_04:682,718` ; `FB_Winch.st:264-269` | Acter le risque au plan de tir |
| **S3** 🚨 | **Nouveau — D18** : temps mort directionnel **bypassé au redémarrage à chaud** (`FirstScanDone` non ré-init + branche neutre→sens immédiate + `DeadTimePending:=FALSE` au gate barrière). | `FB_Winch.st:141-168,211` ; `FB_WinchOutputInterlock.st:97-116` | **D18** ajouté (ci-dessous) → T181-05 |
| S4 | `SpeedGuardReady := NOT instWinchSync.Fault.Error` — câblage sémantiquement faux, deviendra actif avec T181-16. | `PRG_04:684,720` | À corriger dans T181-16 |
| S5 | `FB_WinchOutputInterlock` ne réagit pas à un `SafeStop` amont tant que la demande métier ne retombe pas seule (volontaire, l.118-122). | `FB_WinchOutputInterlock.st:118-122` | À confirmer humain (hors périmètre) |

### D18 (ajout au registre §1)

| ID | Défaut | Preuve | Crit. | Critère de sortie | Porté par |
|---|---|---|---|---|---|
| **D18** | Temps mort directionnel bypassé au redémarrage à chaud (`FirstScanDone`) | `FB_Winch.st:141-168,211` ; `FB_WinchOutputInterlock.st:97-116` | C4 | Hot-restart avec `Direction ≠ 0` maintenu → temps mort appliqué par **au moins un** des deux niveaux (TC harnais + TC unitaire) | T181-05 (+ garde T181-01) |

### Les 5 changements structurants

| # | Changement | Cible |
|---|---|---|
| **1** | **Scinder T181-08** → **T181-08a** (plomberie struct pure, comportement bit-identique, shadow-equal, `MinStepNumber` câblé mais `= 1` partout) + **T181-08b** (bascule du calcul clamp vers l'agrégateur `PRG_04`, fin du shadow). **Oracle shadow redéfini** : « égalité **sauf** cas où un plancher / une précédence est active, comparés à un attendu écrit à la main ». `N` = « 100 % des vecteurs du harnais T181-00, chacun rejoué jusqu'à convergence » (pas un compteur). Fermer le shadow **avant** T181-10. | §7, §8, §11 + bloc TASKS |
| **2** | **Requalifier Phase 0/0b** : « interface `FB_Winch` **en réduction / additive contrôlée uniquement**, les 2 sites `PRG_04` édités au même commit » — **pas** « inchangée ». Tracer explicitement : D07 (`ContactorsCheck.StuckClosed` est une **sortie publique** consommée IHM/Troubleshooting) · D09/T181-05 (`Mode` est `VAR_INPUT` → retrait ⇒ édition `PRG_04`) · D01/T181-01 (ajout d'un `Config` de seuils de cadence, le FB n'en a aucun aujourd'hui). | §7 + bloc TASKS T181-01/05 |
| **3** | **Ajouter D18** (ci-dessus) → rattaché à **T181-05** (interne `FB_Winch`) avec garde côté **T181-01**. | §1 + bloc TASKS |
| **4** | **Renforcer §5** (preuve `FinalInterlockGoverned = FALSE`) : ajouter 4 exigences — (a) **indépendance** des 2 jeux de seuils (sources de config distinctes, zéro variable / GVL partagée) ; (b) **non-bypassabilité** de l'instance interne `FB_Winch` par `GVL_IHM.MxTreuil*.Bypass.Global` ; (c) **argument PLr** documenté (fonction de sécurité, PLr visé, catégorie d'archi) ; (d) **critère site chiffré** (cadence 1→5 chronométrée, la barrière ne mord pas). Écrire noir sur blanc : **la signature sécurité finale exige l'essai site — la CI ne la délivre pas.** | §5 + contrat T181-01 |
| **5** | **Corriger les arêtes `bloque_par`** : `T181-00 bloque_par: [T169-A]` (T169-A ⏳ AGY-01 modifie le même `FB_Main_EndToEnd`) · `T181-01 bloque_par: [T181-00, T175]` (T175 AC2 = source unique du temps mort directionnel). **Compléter le contrat T181-06** : place de l'override `instBucket.Busy` (reste `PRG_04` §3, écrit `DriveRequest.{StartStop,Direction}` de M2) · le `15.0` magique → `Config.BucketJogSpeedPct` · **décision D13** (garder / supprimer la table `PRG_04:405-429`) remontée en **arrêt de validation humaine** de T181-06, pas enterrée dans T181-10. Étendre les `objectifs` de **T181-00** à la modélisation frein + contacteurs retombés (croisements T178 / T180 CAS-001). | bloc TASKS + contrats T181-06 / T181-01 |

### Corrections de justification (pas de changement de tâche)

- **§4.1 (flux `MinStepDescent`)** : la prémisse « 3 POU / 3 tâches, latence » est **fausse** — `PRG_02…07` s'exécutent **séquentiellement dans la même MainTask 10 ms**, `FB_DiveSearch` est instancié dans `PRG_03` → flux `FB_DiveSearch → PRG_03.ReqProgram → PRG_04` **intra-cycle, zéro latence**. Le vrai point : gating sur `DescentActive` (front de sortie) + cas « maintien descente joystick post-fond » (`KoboldBottomTouchLatched` coupe `StartStop`). TC front + TC maintien post-fond dans T181-12.
- **T130/T131/T135 (⏸️) et T096** : « supersédées / absorbée » mais **jamais clôturées** dans `TASKS.yaml`. Housekeeping : passer ❌ avec renvoi T181-06/07/13/15 lors de l'insertion du bloc.

### Découpage (§6 de B2, à appliquer à l'insertion)

- Scinder **T181-14** → 14a (matrice bypass ~20 `Bypass*`) + 14b (override FDC N1 borné 8,5 m + re-homing).
- Critères non mesurables à réécrire : T181-08 « ≥ N cycles » → « 100 % vecteurs à convergence » ; T181-00 « modèle physique minimal » → fidélité chiffrée ; T181-13 « acceptable pour l'opérateur » → « relâche → palier 0 au cycle N+1 » + « ΔStepNumber ≤ +1/cycle ».
- Fusions optionnelles (coordination) : T181-02 + T181-03 ; T181-18 + T181-19.

---

## Suivi historique

| Version | Date | Changement |
|---|---|---|
| v0.1 | 2026-08-29 | Première version formatée. Consolidation 6 sources. Réconciliation T175/T176/T177/T178/T169/T180 (T181-04 et T181-17 retirées, `bloque_par: T177` ajouté). 20 tâches + 3 contrats de cadrage. |
| v0.1 + §13 | 2026-08-29 | Challenge B2 (3ᵉ passe indépendante). §13 = 5 changements structurants + D18 + 5 écarts sécurité S1–S5 + corrections de justification. À intégrer dans le corps du plan (v0.2) avant lancement Phase 0. |
