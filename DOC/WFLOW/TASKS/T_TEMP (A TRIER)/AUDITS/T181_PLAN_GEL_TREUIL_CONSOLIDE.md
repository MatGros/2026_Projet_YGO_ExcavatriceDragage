# PLAN DE GEL DU SOUS-SYSTÈME TREUIL — chapô **T181** (consolidé)

> Objectif utilisateur : *« vraiment figer ce treuil »*, *« un winch qui fonctionne du premier coup »*
> — zéro aller-retour, zéro régression, pas de big-bang.
> Statut : **brief maître**, à valider humain puis à confier à agent1 pour production du
> `PLAN_GEL_TREUIL_v0.1.md` + entrées `TASKS.yaml` + contrats de cadrage.
> Date : 2026-08-29.

---

## 0 · Sources consolidées (traçabilité de ce plan)

| Source | Apport principal retenu |
|---|---|
| **Revue experte #1** (archi / POO) | `FB_Winch` n'est pas un objet propre : entrées mortes `Mode`/`CycleTimeCalc`, `ContactorStuck` dupliqué, délais d'interlock direction détournés en tempo de rampe palier (couplage caché), `SEL` direction `FB_Winch.st:248` nommé à l'envers. Blocs sains à **extraire** : direction-interlock (`:198-227`), step-shaper (`:250-271`), garde `Enable=FALSE`→sorties sûres (`:139-159`). Piège : `FirstScanDone` (`:165-168`) capture `CommandedDirection` au 1ᵉʳ scan → bypass interlock au redémarrage à chaud. |
| **Revue experte #2** (fonctionnel / garant TC) | `F10.06..09` (Symmetry, SpeedStep, LoadEstimator, DriftGuard) **sans aucun TC**. `M1_Busy`/`M2_Busy` déclarés **jamais lus** → le TC anti-traversée benne teste un chemin mort = **faux vert**. Pas de prolifération de TC : regrouper, chaque TC justifié. |
| **Challenge #1** (séquencement / « du premier coup ») — verdict **BLOCK** | 5 changements structurants (voir §6). Cœur : (a) **harness d'intégration** paire `M1+M2+PRG_04+PRG_06` — le CI est unitaire STruCpp, aucun test ne fait tourner la chaîne ensemble ; (b) **corriger les C4 rouges AVANT de toucher l'API**, pas après ; (c) extraction sous-FB **après** interface stable ; (d) **contrat formel d'autorité des 2 interlocks** + preuve `FinalInterlockGoverned=FALSE` ; (e) plan **FAT / essais site / rollback / ordre d'import CODESYS**. |
| **Challenge #2** (interconnexion Grafcets / joystick / IHM) — verdict **`DriveRequest` couvre ~80 %, 4 amendements requis** | (A) le clamp **ne peut pas** être « câblé identique M1=M2 » : les bridages benne (`M2_ForceSlowSpeed`, `ManualBucketLimitsActive`, `BucketNotClosedAscentStep1`) sont **M2-only** → clamp **par instance** ou scindé *commun + plafond M2 propre*, sinon **régression M1**. (B) **précédence Min/Max non définie** → règle écrite « plafond safety gagne » + garde `FB_SpeedStep : LIMIT(1, MinStepNumber, MaxStepClamped)` après le plafond. (C) **aucun producteur de `MinStepDescent` n'existe** → à créer dans `FB_DiveSearch` + contrat de flux `PRG_03→PRG_04`. (D) `MinStepNumber` agit sur la **cible** (`RequestedStep`), lissée par `BusinessStepDelay`/`FB_WinchStepShaper` — **interdiction de forcer `StepNumber` directement** (à-coup plongée). |
| **Rapports CI** (`TEST_AUTO_CI`) | `FB_WinchOutputInterlock` **2/7** · `FB_Winch` **5/7** · `FB_Bucket` **14/17** · `FB_Safety_Winch` **14/14** · `FB_WinchSync` **4/4**. |
| **Constats P0** (déjà avérés, contexte) | Clamp M1 (5 conditions) ≠ M2 (7) — 2 `SEL()` dupliqués inline `PRG_04:679-681 / 716-717`. Garde-fou survitesse **mort** (`MeasuredSpeedBand:=0` en dur `:682,718`, `SpeedGuardEnable=FALSE`). `ForceMinSpeedStep` = sémantique inversée (c'est un **plafond** `MaxStepAscent:=1`). Pas de `MinStep` (plancher). Reconstruction table 24 affectations `PRG_04:405-429` = 2ᵉ mécanisme au même effet. `FB_DiveSearch.CurrentSpeedStep` **jamais câblé** → interdiction palier 5 en Kobold **morte** (`FB_DiveSearch.st:266-272`). |
| **Décisions utilisateur Q1–Q8** | voir §2. |
| **Absorptions** | T096 (apprentissage vitesse), T131 partiel (refactor intention palier), T175, T177, T178 (coast-down `CfgWinchCoastMax_M` ~3 m + timeout, ex-T054). Superséder explicitement T130/T131/T135 (⏸️). |

---

## 1 · Registre des défauts — critère de sortie **mesurable** par item

| ID | Défaut | Preuve | Crit. | Critère de sortie (mesurable) |
|---|---|---|---|---|
| **D01** | Barrière finale `FB_WinchOutputInterlock` non fiable | CI 2/7 : FAIL TC-P10-012 (watchdog frein), 013 (latches hors `Enable`), 021/022 (temps morts directionnels), 020 (SITE) | C4 | CI `FB_WinchOutputInterlock` **7/7 PASS** sur interface **inchangée** |
| **D02** | `FB_Winch` : inversion sens + `ContactorStuck` | CI 5/7 : FAIL TC-P10-011 (Fwd/Rev), 018 (ContactorStuck) | C4 | CI `FB_Winch` **7/7 PASS**, `ContactorStuck` **retiré** de `FB_Winch` (→ D07) |
| **D03** | `FB_Bucket` : confirm MAINT + timeouts | CI 14/17 : FAIL TC-P10-030, 046.1, 047.1 | C3 | CI `FB_Bucket` **17/17** ; TC-030 traité en Phase C |
| **D04** | Anti-traversée benne = chemin mort | `M1_Busy`/`M2_Busy` déclarés, **0 lecture** ; TC-025/030 = faux vert | C3 | `M1_Busy`/`M2_Busy` **consommés** (G200 les voit produits+consommés sur 2 instances) ; TC anti-traversée re-écrit sur le **vrai** chemin |
| **D05** | Clamp palier M1 ≠ M2, dupliqué inline | `PRG_04:679-681` (M1, 2/5 termes) vs `:716-717` (M2, 3/7 termes) | C4 | **1 seule** fonction d'agrégation clamp en `PRG_04` ; sources **commun vs M2-propre** tabulées (§3-A) ; `SEL()` inline supprimés |
| **D06** | Garde-fou survitesse mort | `MeasuredSpeedBand:=0` en dur `:682,718` ; `SpeedGuardEnable=FALSE` | C3 | `MeasuredSpeedBand`/`MeasuredSpeedValid` **câblés** via `Sensors` ; survitesse active **ssi** table `{sens,charge}` complète (Q ci-dessous) ; flag débrayable ; TC-055/060 PASS |
| **D07** | `ContactorStuck` : 2 propriétaires (`FB_Winch` 500 ms + `FB_Safety_Winch` Méca B 3 s) | `FB_Winch.st:292-298` vs `FB_Safety_Winch.st:246-256` | C4 | **1 seul** propriétaire = `FB_Safety_Winch` ; `FB_Winch` ne détecte plus rien ; TC-018 déplacé côté Safety |
| **D08** | `ForceMinSpeedStep` sémantique inversée + pas de `MinStep` | `FB_ExtractionSequence.st:272` `ForceMinSpeedStep := AscentPermit` → `PRG_04:681,717` `SEL(…, EffMax, 1)` | C3 | Renommé `ExtractionControlActive` sur **toute la chaîne** (7 pts, §5) ; `FB_SpeedStep.MinStepNumber` ajouté |
| **D09** | Entrées mortes `FB_Winch` | `Mode : E_Mode` (`:18`, jamais lu) ; `CycleTimeCalc : FB_CycleTime` (`:82,170`, jamais consommé) | C2 | Retirées ; fiche `FB_Winch_v1.0.md` **réécrite** (aujourd'hui périmée = piège) |
| **D10** | Délais direction détournés en tempo rampe palier + `SEL` à l'envers | `FB_Winch.st:248` `SEL(CommandedDirection=-1, DelayAscent, DelayDescent)+T#100ms` | C3 | Tempo rampe = **paramètre dédié** (`FB_WinchStepShaper`) ; `SEL` direction corrigé ou justifié par commentaire + TC |
| **D11** | `F10.06..09` sans TC | Symmetry / SpeedStep / LoadEstimator / DriftGuard | C1 | ≥ 1 TC macro **justifié** par fonction (Phase D) |
| **D12** | Bypass survitesse Kobold mort | `FB_DiveSearch.CurrentSpeedStep` jamais passé en argument (`PRG_03`) | C3 | `CurrentSpeedStep` **câblé** (palier arbitré) ; interdiction palier 5 en Kobold **effective** ; TC DiveSearch mis à jour |
| **D13** | 2 mécanismes « tout palier 1 » pour M2 | `SEL(...,1)` `:716` **+** reconstruction table `:405-429` (`M2_SpeedStepTableActive`) | C3 | **Décision actée** : si `MaxStepDescent:=1` suffit → `:405-429` supprimé ; sinon conservation **motivée** en clair |
| **D14** | `ControlAscentActive` (PRG_04 local) ⟷ `ExtractionControlActive` (FB) : 2 flags même effet | `PRG_04:341-357` vs `FB_ExtractionSequence.st:272` | C2 | **1 seul** flag « montée contrôlée → `MaxStepAscent:=1` » |
| **D15** | ~20 `Bypass*` OR-és, pas de matrice de mode | `PRG_04:554-627` + `FB_Safety_Winch.st:63-66` | C3 | Matrice bypass **N1/N2** explicite (Phase C) ; N1 = bouton maintenu momentané, N2 = latché, re-homing, **tout à l'arrêt** |
| **D16** | Coast-down / plongée frein 1–2 m non bornée | REX utilisateur (T054→T178) | C4 | `CfgWinchCoastMax_M` (défaut ~3 m) + timeout ; seuils AU « déplacement pendant contacteurs retombés » **assouplis** de ce montant ; note AF + **tâche IHM auto-générée** pour rabaisser le seuil |
| **D17** | Fiche `FB_Winch_v1.0.md` périmée | cartouche-sync | C1 | Fiche régénérée, cohérente interface finale |

---

## 2 · Décisions figées — utilisateur (Q1–Q8 + challenge #1)

| # | Décision |
|---|---|
| **Apprentissage** | 1 **bit IHM** « lancer apprentissage », fonction dispo via IHM. Collecteur **passif** (non bloquant). Voyant IHM d'état. |
| **Table apprise** | `{M1/M2 × sens × charge / vide × palier 1-5}`, **RETAIN**. Charge **et** vide mesurés. Calibration **rare**. Tant que l'apprentissage complet n'est pas fait → **table vide = non applicable** ; **bypass facile**. |
| **Seuils survitesse** | **Marge fixe** ajoutée à la vitesse apprise : `appris + 0,5 m/s` (soft → diag) / `appris + 1,5 m/s` (hard → **SafeStop**). 0,5 / 1,5 = constantes de config, faciles à régler. |
| **Surveillance survitesse** | Active **seulement si** table `{sens, charge}` complète **+** flag débrayable. |
| **Invariant clamp** | `Min < Max` toujours. **Plafond (safety) gagne** sur plancher. |
| **Fonction unifiée** | `Min/MaxStep{Ascent,Descent}` — **même sémantique et mêmes bornes appliquées à M1 et M2**, calcul unique (⚠️ challenge #2-A : *unique* ≠ *aveuglément identique* — les bornes propres benne restent M2). **Pas de `Force*` dans le vocabulaire du clamp** : `Min`/`Max` seulement. |
| **Requête « palier plancher »** | Vient d'une **étape de séquence** (ou geste joystick), injectée comme **paramètre** `MinStep*` — pas une variable `Force*` balancée. Responsabilité **cadrée fonctionnellement**. |
| **Interlock cadence** | **1 FB `FB_WinchRateInterlock`, 2 niveaux** : instancié dans `FB_Winch` (seuils = safety **+ marge**) **ET** dans `PRG_06` (seuils safety nus). Diag `FinalInterlockGoverned` **DOIT rester FALSE en nominal** = critère d'acceptation. *« Si le code logique est bien fait, interlock jamais bloquant = 0. »* Si `PRG_06` limite → **le signaler** (diag + trace). |
| **`ContactorStuck`** | Propriétaire **unique** = `FB_Safety_Winch`. |
| **Override FDC logiciel** | N1 : bouton IHM **maintenu momentané**, borné par capteur homing haut. N2 : latché. **Capteur homing top toujours > FDC haut logiciel** : 8,5 m (homing) / 7,5 m (FDC logiciel). Fonctionnement normal : arrêt **7,5 m**. Override ne dépasse **jamais** 8,5 m. |
| **Plongée Kobold** | Palier **plancher constant 3–4** (hydraulique stable pour validité mesure). Palier 5 **interdit**. Joystick hors neutre à tout % → **≥ plancher** (montée lissée, pas d'à-coup). Relâche → **0 immédiat**. |
| **Application** | Manuelle par l'humain (copie ST + import PLCopenXML). MainTask **10 ms**. |

---

## 3 · Contrat de flux `ST_fbWinch_DriveRequest` (issu challenge #2)

### Interface cible `FB_Winch`

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
    SyncCoupled    : BOOL    (* DIAG STRICT — FB_Winch ne le lit JAMAIS en logique. Garde de revue. *)

ST_fbWinch_Sensors  : CablePosM, Homed, HomingSuspect, FwdRevSpeedFeedbackOff,
                      MeasuredSpeedBand, MeasuredSpeedValid
ST_fbWinch_Cfg      : SpeedStepTable, HystMargin, DirectionInterlockDelay*,
                      ContactorFeedbackTimeout, TopLimitM, BottomLimitM,
                      SlowdownDistanceM, SlowdownMaxStep, HomingApproachActive
```

### 3-A · Sources de clamp — **commun** vs **M2-propre** (amendement A, BLOQUANT)

| Source de borne | Sens | Portée | Où calculée |
|---|---|---|---|
| `SyncDeviationWarn` → plafond 1 | Asc + Desc | **commun** M1 = M2 | agrégateur PRG_04 |
| Zone de ralentissement bordure (`CablePosM` vs `SlowdownDistanceM`) → `SlowdownMaxStep` | selon sens | **par instance** (position câble propre) | agrégateur PRG_04, entrée `Sensors.CablePosM` de chaque instance |
| `HomingApproachActive` → plafond 1 | Asc | **commun** | agrégateur PRG_04 |
| **Dive floor** Kobold → `MinStepDescent = 3` (config `CfgDiveFloorStep`) | Desc | **commun** | producteur `FB_DiveSearch` (amendement C) |
| `ExtractionControlActive` (ex-`ForceMinSpeedStep`) → plafond 1 | Asc | **commun** | `FB_ExtractionSequence` → PRG_03 → PRG_04 |
| `M2_ForceSlowSpeed` (benne jogging lent) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur PRG_04, branche M2 |
| `ManualBucketLimitsActive` (FDC benne MAINT) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur PRG_04, branche M2 |
| `BucketNotClosedAscentStep1` / `SlackCableAscentStep1` | Asc | **M2 uniquement** (géométrie benne) | agrégateur PRG_04, branche M2 |

> ⚠️ Un câblage strictement identique M1 = M2 **briderait M1 à tort** dès que la benne jogge en pilotage unitaire. → l'agrégateur produit `commonMinAsc/commonMaxAsc/commonMinDesc/commonMaxDesc` (identiques) **puis** M2 applique en plus `MIN(…, plafondBenne)`.

### 3-B · Règle de précédence Min/Max (amendement B, BLOQUANT)

1. `MaxStep := MIN(toutes les sources plafond)` — en **un seul endroit** (agrégateur PRG_04).
2. `MinStep := MAX(toutes les sources plancher)`.
3. **Plafond gagne toujours** : garde dans `FB_SpeedStep` →
   `MinClamped := LIMIT(1, MinStepNumber, MaxStepClamped)` **après** application du plafond, **avant** le `CASE StepNumber` (sinon sortie hors [0..5]).
4. Invariant vérifié par TC : `MinStepDescent = 3` (Kobold) **+** bordure basse voulant `MaxStepDescent = 1` → résultat **1** (plafond gagne), pas d'incohérence.

### 3-C · `MinStepNumber` agit sur la **cible**, jamais sur `StepNumber` (amendement D, BLOQUANT)

- `FB_SpeedStep` : `RequestedStep := MAX(sel_hyst, MinClamped)` **avant retour**.
- La montée `StepNumber 0→1→2→3` reste **cadencée par `BusinessStepDelay` / `FB_WinchStepShaper`** (~0,5–1 s/cran).
- **Interdit** : `StepNumber := MinStepNumber` direct (= court-circuit rampe = vrai à-coup contacteur).
- `MinStep` **sans effet si `StartStop = FALSE`** (correct : relâche joystick → palier 0 immédiat via `RampTargetPct:=0`).
- Corriger au passage `FB_Winch.st:248` (`SEL` direction apparemment inversé — il pilote la vitesse d'accostage en plongée).

### 3-D · Matrice d'interconnexion producteurs → `DriveRequest` (synthèse challenge #2)

| Producteur | Émet aujourd'hui | → `DriveRequest` | Statut |
|---|---|---|---|
| **FB_Cycle** (Grafcet X0-X13) | `ST_fbCycle_WinchCmdDemand {StartStop, Direction:INT, SpeedPct:REAL}` (`FB_Cycle.st:74-75`), vitesses **codées en dur** X1=10 % … X8=70 % | `StartStop`/`Direction`/`SpeedTgt_Pct` 1:1 | ✅ — **ne pas** fusionner `ST_fbCycle_WinchCmdDemand` avec un refactor palier-INT (casse `test_fb_cycle`) |
| **PRG_03** | `Data.ReqProgram.ReqWinchM1/M2 {ReqStartStop, ReqDirection, SpeedTgtPct}` — **SEMI_AUTO uniquement**, forcé 0 en MAINT/DISABLE (`PRG_03:225-231`) | alimente via PRG_04 §3 | ✅ sélecteur mode-gated déterministe |
| **FB_DiveSearch** | `DescendPermit`, `KoboldMeasureEnable` — **n'émet aucune consigne** ; `CurrentSpeedStep` = **entrée jamais câblée** | doit produire **`MinStepDescent`** (nouveau) | ⚠️ **amendement C** — producteur à créer |
| **FB_ExtractionSequence** | `ForceMinSpeedStep := AscentPermit` (`:272`) | `MaxStepAscent := 1` (renommé `ExtractionControlActive`) | ✅ sémantique OK, nom trompeur → rename |
| **FB_Joystick** | `AxisCmdY {SpeedTgt:REAL 0..100, Direction:INT, StartStop, Enable}` → PRG_04 `SpeedCmd_Pct := ABS(AxisY.SpeedTgt)` | `SpeedTgt_Pct`/`Direction`/`StartStop` | ✅ nominal / ⚠️ plongée (granularité 0-40 % perdue avec plancher — assumé, lissé §3-C) |
| **FB_Modes** | `Auth.Mode`, `SyncEnable`, `InhibitM1/M2`, `JoystickWinchSelectArbitrated (0/1/2)`, `HomingApproachEnable` | gating amont + `Config.HomingApproachActive` + `SyncCoupled` (diag) | ✅ si `SyncEnable`/`SyncActive` restent **hors** `FB_Winch` |
| **IHM directe** | `GVL_IHM.M1TreuilRetenue.Cmd.BtnUp/Down` … → PRG_04 `SpeedCmd_Pct := 100.0` en dur | `Direction`/`StartStop`/`SpeedTgt_Pct` | ✅ trivial |
| **FB_Bucket** (producteur M2 caché) | `M2_StartStop/M2_Direction/M2_ForceSlowSpeed` → 15 % en dur + swap table P1 (`PRG_04:285-288, 405-429`) | `StartStop`/`Direction`/`SpeedTgt_Pct=15` + `MaxStepDescent:=1` | ⚠️ sens M2 = **propriété FB_Bucket** (géométrie), OK ; swap table → **D13** |

### 3-E · Arbitrage / priorité (point unique = `PRG_04` §3, `:242-357`)

| Situation | Qui gagne | Garanti |
|---|---|---|
| Grafcet + joystick | **Mode** racine : SEMI_AUTO → branche joystick non évaluée (joystick = `CycleMotionPermit` + `DeadmanArmed` seulement) | ✅ si calcul clamps reste **mode-aware** |
| IHM boutons + cycle | exclusif par mode | ✅ |
| IHM + joystick maître | `TglJoystickMaster` sélectionne l'un **ou** l'autre | ✅ |
| Benne active + mouvement couplé | override `IF instBucket.Lifecycle.Busy AND instBucket.M2_StartStop` + `BenneBusyFallEdge` force-stop 1 scan | ⚠️ à ré-exprimer proprement : **où** cet override s'insère dans la construction du `DriveRequest` (doit être explicite dans le contrat) |
| N sources de plafond | `MIN()` en un seul endroit (§3-B) | ⚠️ à formaliser |

> **Règle d'or** : aucun arbitrage de `StartStop`/`Direction`/`SpeedTgt_Pct` ne migre dans `FB_Winch`. Tout reste `PRG_04` §3.

---

## 4 · Autorité des 2 interlocks de cadence (issu challenge #1 #4 + Q6)

### Contrat formel

| | Instance `FB_Winch` (interne) | Instance `PRG_06` (barrière finale) |
|---|---|---|
| Rôle | **Gouverne** la cadence en fonctionnement nominal | **Filet de sécurité** — ne doit jamais agir en nominal |
| Seuils | safety **+ marge** (plus serrés) | safety **nus** |
| Effet | limite `StepNumber` / temporise transition | coupe `Cmd` contacteur (dernier recours) |
| Diag | `RateGoverned` (info) | **`FinalInterlockGoverned`** |

### Critères d'acceptation (sans HIL)

1. `FinalInterlockGoverned = FALSE` sur **100 %** des vecteurs de test nominaux (Grafcet X0-X13, rampes joystick 0→100 %, plongée, extraction, benne). TC dédié `TC-P10-0xx : FinalInterlockGoverned reste FALSE`.
2. Si `FinalInterlockGoverned = TRUE` apparaît → **trace horodatée** + latch diag + remontée IHM (le code logique amont est en défaut, pas la sécurité).
3. Test d'injection : forcer une cadence > seuil safety **en contournant** l'instance `FB_Winch` (stub) → l'instance `PRG_06` **doit** couper. Prouve que le filet fonctionne.
4. Pas de **double-freinage** : TC vérifie que quand l'instance `FB_Winch` gouverne déjà (marge), l'instance `PRG_06` **reste passive** (pas d'interaction entre les 2 jeux de seuils).

---

## 5 · Renommage vocabulaire — chaîne complète (D08, D14)

| Ancien | Nouveau | Points d'impact |
|---|---|---|
| `ForceMinSpeedStep` | `ExtractionControlActive` | `FB_ExtractionSequence.st:48,194,213,272` · `ST_ProgramBucketRequest.st:13` · `PRG_03:242,319,401` · `PRG_04:681,717` |
| `ControlAscentActive` (PRG_04 local) | **fusionné** dans `ExtractionControlActive` | `PRG_04:341-357` |
| `CfgMaxStepDescente` | `MaxStepDescent` | `PRG_04:679,716` + fiches AF |
| `M2_ForceSlowSpeed` | `M2_BucketJogLimit` (ou `BucketSlowLimitM2`) — **Max**, pas `Force` | `PRG_04:285-288,716-717` + `FB_Bucket` |
| `M2_SpeedStepTableActive` (si conservé) | à statuer (D13) | `PRG_04:405-429` |

> 1 oubli = liaison G200 rouge → renommage **transverse en une passe**, `run_all_gates` immédiat.

---

## 6 · Phasage révisé (challenge #1 + #2)

```
Phase -1  HARNESS + PLAN DE TIR                                    [BLOQUANT tout]
          ├─ Harness d'intégration ST : paire M1+M2 + PRG_04 + PRG_06 ensemble
          │  (vecteurs Grafcet X0-X13, rampes joystick, plongée, extraction, benne)
          ├─ Plan FAT / essais site / rollback / ordre d'import CODESYS manuel
          └─ Baseline : rejouer CI actuel, figer les 5/7-2/7-14/17 comme référence

Phase 0   CORRECTIONS C4 — INTERFACE FB_Winch INCHANGÉE           [bloque A, B, C]
          ├─ D01  FB_WinchOutputInterlock 7/7 (TC-012/013/021/022)
          ├─ D02  FB_Winch 7/7 (TC-011 Fwd/Rev)  — SANS toucher l'API
          ├─ D07  ContactorStuck → FB_Safety_Winch (retrait FB_Winch, TC-018 déplacé)
          ├─ D04  Anti-traversée benne : câbler M1_Busy/M2_Busy, TC ré-écrit
          ├─ §4   Contrat formel autorité 2 interlocks + correction MINIMALE + TC FinalInterlockGoverned
          └─ GATE : CI winch complet vert sur interface actuelle + harness -1 vert

Phase 0b  EXTRACTION SOUS-FB — interne, interface INCHANGÉE       [bloque_par: 0]
          ├─ FB_WinchDirectionInterlock  (ex FB_Winch.st:198-227)
          ├─ FB_WinchStepShaper          (ex :250-271, tempo rampe palier DÉDIÉE — D10)
          ├─ FB_WinchRateInterlock       (2 niveaux, §4)
          ├─ D09  retrait Mode + CycleTimeCalc
          └─ GATE : CI iso (0 régression), harness -1 iso

Phase A   INTERFACE DriveRequest + CLAMP UNIFIÉ — SHADOW COMPARISON [bloque_par: 0b]
          ordre de migration (challenge #2 §6), chaque pas = commit + gates :
          A1  FB_SpeedStep : + MinStepNumber (défaut 1, rétro-compat) + garde LIMIT (§3-B)
          A2  Créer ST_fbWinch_DriveRequest / _Sensors / _Cfg
          A3  [MÊME COMMIT] refonte interface FB_Winch + 2 sites PRG_04 + FB_SimBench + test_fb_winch
              → SHADOW : ancien calcul clamp ET nouveau tournent en //, comparés, bascule quand identiques N cycles
          A4  Rename vocabulaire complet (§5)
          A5  Agrégateur clamp PRG_04 : commun vs M2-propre (§3-A) — supprime 2 SEL() inline + D13
          A6  Producteur MinStepDescent dans FB_DiveSearch + flux PRG_03/04 (amendement C)
          A7  Câbler SyncCoupled (diag) depuis instWinchSync.SyncActive + garde revue
          A8  D12 : câbler FB_DiveSearch.CurrentSpeedStep (interdiction palier 5 effective)
          A9  Palier plancher mode (Kobold 3-4, joystick hors neutre → ≥ plancher, lissé §3-C)
          └─ GATE : TC intégration Grafcet↔Winch + Joystick↔Winch + régression M1 (§8)

Phase C   MATRICE MAINTENANCE N1/N2                     [bloque_par: 0 ; dépend A pour vocabulaire]
          ├─ Cadrage + AF-05 (matrice bypass, N1 momentané / N2 latché, re-homing, tout à l'arrêt)
          │  ARRÊT VALIDATION HUMAINE
          ├─ D15  FB_Modes + PRG_04 : arbitrage bypass par mode, rationalise ~20 Bypass*
          ├─ D16  override FDC N1 borné capteur homing 8,5 m
          ├─ D03  répare TC-P10-030 (confirm MAINT)
          └─ GATE : TC-080

Phase B   APPRENTISSAGE + SURVITESSE          [B14 bloque_par: 0b ; B15-16 bloque_par: A + C + B14]
          ├─ B14  FB_WinchSpeedLearning : collecteur passif, 1 bit IHM, RETAIN, voyant, stabilisation
          │       (charge + vide) — AF-10 §7.3, nouvelle fiche, crée F10.10
          ├─ B15  Survitesse dans FB_Safety_Winch : 2 seuils fixes (appris+0,5 / appris+1,5),
          │       actif ssi table {sens,charge} complète, débrayable, réactive SpeedGuard,
          │       anti-calage passage palier via MeasuredSpeedBand (D06)
          │       ⚠️ dépendance C↔B : la matrice maintenance conditionne quand la survitesse est armée
          ├─ D16b coast-down : CfgWinchCoastMax_M ~3 m + timeout, seuils AU assouplis, tâche IHM auto
          └─ GATE : TC-055 (coast-down ≠ dérive), TC-060 (apprentissage)

Phase D   RÉTRO-TC + DETTE                              [bloque_par: A]
          ├─ D11  TC macro F10.06..09 (Symmetry, SpeedStep, LoadEstimator, DriftGuard)
          ├─ D17  fiche FB_Winch_v1.0.md réécrite
          └─ fix bug sérialisation traçabilité
```

### DAG condensé

```
-1 ──► 0 ──► 0b ──► A ──► D
        │           │
        ├──► C ◄─────┤   (C dépend de A pour le vocabulaire ; C pas parallèle à B)
        │           │
        └──► B14 ────┴──► B15/B16   (B15 dépend de A + C + B14)
```

---

## 7 · Registre des tâches T181-xx (à produire par agent1)

> Numérotation indicative — agent1 aligne sur `TASKS.yaml`. 3 arrêts validation humaine : **T181-06** (cadrage `DriveRequest`), **T181-11** (matrice maintenance), **§4** (autorité interlocks, intégré T181-01).

| ID | Titre | Phase | bloque_par | Livrables `fix:` + `guard:` | Absorbe |
|---|---|---|---|---|---|
| T181-00 | Harness intégration ST paire + plan de tir FAT/rollback | -1 | — | `fix:` harness `test_integ_winch_pair.*` · `guard:` gate « harness vert » ajouté à `run_all_gates` | — |
| T181-01 | FB_WinchOutputInterlock 7/7 + contrat autorité 2 interlocks + FB_WinchRateInterlock | 0 | 00 | `fix:` TC-012/013/021/022 · `guard:` `G4xx_check_final_interlock_governed_false` | T177 |
| T181-02 | FB_Winch 7/7 (TC-011 Fwd/Rev), interface inchangée | 0 | 00 | `fix:` TC-011 · `guard:` TC direction dans harness | — |
| T181-03 | ContactorStuck → propriétaire unique FB_Safety_Winch | 0 | 00 | `fix:` retrait `FB_Winch.st:292-298`, TC-018 côté Safety · `guard:` `G4xx_check_stuckclosed_single_owner` | — |
| T181-04 | Anti-traversée benne réelle (M1_Busy/M2_Busy consommés) | 0 | 00 | `fix:` câblage + TC-025/030 ré-écrits · `guard:` G200 orphelin sur *_Busy | — |
| T181-05 | Extraction sous-FB DirectionInterlock + StepShaper + retrait Mode/CycleTimeCalc | 0b | 01,02,03 | `fix:` 3 FB extraits, D09, D10 · `guard:` TC iso sous-FB | — |
| T181-06 | **Cadrage `ST_fbWinch_DriveRequest`** + mapping sources clamp commun/M2 + AF-10. **ARRÊT VALIDATION HUMAINE** | A | 05 | contrat de cadrage `TASK_CONTRACT_T181-06` | T131 (partiel) |
| T181-07 | FB_SpeedStep + MinStepNumber + garde LIMIT précédence | A | 06 | `fix:` `FB_SpeedStep.st` · `guard:` `G4xx_check_speedstep_clamp_bounds` | — |
| T181-08 | Refonte interface FB_Winch (struct) + 2 sites PRG_04 + FB_SimBench + tests — **SHADOW COMPARISON** | A | 07 | `fix:` migration · `guard:` shadow-diff assert en test | — |
| T181-09 | Rename vocabulaire complet (§5) + fusion ExtractionControlActive/ControlAscentActive | A | 08 | `fix:` 7 fichiers · `guard:` `G4xx_check_no_force_in_clamp_vocab` | — |
| T181-10 | Agrégateur clamp PRG_04 (commun vs M2-propre) — supprime SEL() inline + statue D13 | A | 09 | `fix:` `PRG_04` · `guard:` TC régression M1 sous M2_BucketJogLimit | — |
| T181-11 | **Cadrage matrice maintenance N1/N2** + AF-05. **ARRÊT VALIDATION HUMAINE** | C | 01 | contrat `TASK_CONTRACT_T181-11` | — |
| T181-12 | Producteur MinStepDescent (FB_DiveSearch) + flux PRG_03/04 + câblage CurrentSpeedStep | A | 10 | `fix:` D12 · `guard:` TC interdiction palier 5 Kobold | — |
| T181-13 | Palier plancher mode (Kobold 3-4, joystick → ≥ plancher, lissé) + AF-04 | A | 12 | `fix:` crée F10.12 · `guard:` TC anti-à-coup plongée (`StepNumber` ≤ +1/scan) | T096 (partiel) |
| T181-14 | Code matrice bypass FB_Modes + PRG_04 + override FDC N1 borné 8,5 m | C | 11,10 | `fix:` D15, D16 · `guard:` `G4xx_check_bypass_matrix_mode_gated` | — |
| T181-15 | FB_WinchSpeedLearning collecteur passif (1 bit IHM, RETAIN, charge+vide) | B | 05 | `fix:` nouvelle FB, F10.10 · `guard:` TC « table vide → non applicable » | T096 |
| T181-16 | Survitesse FB_Safety_Winch (2 seuils fixes, table complète, débrayable) + réactive SpeedGuard | B | 10,14,15 | `fix:` D06 · `guard:` TC-055/060 + `G4xx_check_measuredspeedband_wired` | T175 |
| T181-17 | Coast-down CfgWinchCoastMax_M + timeout + seuils AU assouplis + tâche IHM auto | B | 16 | `fix:` D16b · `guard:` TC coast-down borné | T178 (=T054) |
| T181-18 | Rétro-TC F10.06..09 + fiche FB_Winch_v1.0.md + fix sérialisation traçabilité | D | 10 | `fix:` D11, D17 · `guard:` G450 couverture | — |
| T181-19 | Câbler SyncCoupled diag + garde revue « FB_Winch ne lit jamais SyncCoupled » | A | 08 | `fix:` D + `guard:` `G4xx_check_synccoupled_diag_only` | — |

---

## 8 · Stratégie de test

### Unitaire (STruCpp CI) — **regroupé, justifié**
- Réparer : TC-P10-011, 012, 013, 018, 021, 022, 030, 046.1, 047.1.
- Nouveaux (1 macro par besoin, pas 50) : `MinStepNumber` + précédence, `FinalInterlockGoverned=FALSE` nominal, injection filet interlock, shadow-diff clamp, interdiction palier 5 Kobold.

### Intégration (harness Phase -1, nouveau) — **le trou identifié**
| Test | Vecteur | Attendu |
|---|---|---|
| Grafcet↔Winch | pour chaque étape X1…X11 : `{Direction, SpeedPct}` | `StepNumber` résultant compte tenu des clamps (bordure, sync) |
| Joystick↔Winch | rampe déflexion 0→100 % | séquence `StepNumber`, **avec** et **sans** `MinStepDescent` ; forme d'accostage (`StepNumber` ≤ +1/scan) |
| Dive floor | effleurement joystick ~5 % | transitions `0→1→2→3` temporisées ; relâche → 0 immédiat |
| Régression M1 | benne en `M2_BucketJogLimit`, M1 demande palier 4 | M1 **reste à 4** |
| Autorité interlock | cadence forcée > safety en contournant instance FB_Winch | instance PRG_06 **coupe** ; pas de double-freinage en nominal |
| Paire couplée | M1+M2 sync, déviation injectée | `SyncDeviationWarn` → plafond 1 **sur les 2** |

### FAT / essais site (plan Phase -1, hors CI)
- Checklist import CODESYS (ordre §9).
- Essai à vide paliers 1→5 M1 seul, M2 seul, couplé.
- Essai coast-down mesuré (valide `CfgWinchCoastMax_M`).
- Essai override FDC N1 (borne 8,5 m physique).
- Campagne apprentissage charge/vide (remplit la table RETAIN).
- Bascule survitesse ON après table complète — vérif non-déclenchement nominal.

---

## 9 · Ordre d'application manuelle CODESYS (par lot)

1. DUT d'abord : `ST_fbWinch_DriveRequest`, `_Sensors`, `_Cfg`, sous-FB extraits.
2. FB feuilles : `FB_SpeedStep`, `FB_WinchDirectionInterlock`, `FB_WinchStepShaper`, `FB_WinchRateInterlock`.
3. `FB_Winch`, `FB_Safety_Winch`.
4. `FB_DiveSearch`, `FB_ExtractionSequence` (rename).
5. `PRG_03` puis `PRG_04` puis `PRG_06`.
6. `FB_SimBench` / simulation en dernier.
7. Régénérer bundle PLCopenXML → `G200_check_linkage.py --report` → `run_all_gates.py`.
8. Bandeau de restitution (bundle frais + gates verts).

---

## 10 · Rollback & non-régression du reste de la machine

- **Checkpoint commit** avant chaque phase (`wip(treuil): phase X [NON TESTE]`).
- Shadow comparison (Phase A) = rollback logique : l'ancien calcul reste présent jusqu'à bascule validée.
- Point de retour Git par phase (tag `t181-phase0-ok`, etc.).
- Non-régression hors treuil : `run_all_gates.py` complet (21 gates) à chaque fin de phase — pas seulement les gates treuil.
- Vérifier appelants transverses : `PRG_02_Acquisition`, `PRG_07_Supervision`, `GVL_Troubleshooting` (consomment des diags treuil).
- `Device.export` **jamais** utilisé comme référence — demander export frais si besoin de comparer.

---

## 11 · Risques résiduels & points de vigilance

| Risque | Mitigation |
|---|---|
| Rename transverse : 1 oubli → G200 rouge | passe unique + `run_all_gates` immédiat (T181-09) |
| Shadow comparison masque un écart rare (vecteur non couvert) | garder shadow actif **N phases**, pas 1 commit ; log des divergences |
| Dépendance C↔B sous-estimée (matrice maint conditionne l'armement survitesse) | T181-16 `bloque_par` explicite 14 |
| `ST_fbCycle_WinchCmdDemand` fusionné par erreur avec refactor palier-INT | interdiction écrite, TC `test_fb_cycle` en garde |
| Harness -1 incomplet → faux sentiment de sécurité | revue humaine de la **liste des vecteurs** avant Phase 0 |
| Agent distant s'auto-valide | validation finale = orchestrateur (lecture `git diff` réel), jamais l'agent |

---

## 12 · Prochaine action

1. **Validation humaine de ce brief** (surtout §3-A commun/M2, §4 autorité, §6 phasage, §7 découpage).
2. Envoi à **agent1** → production `PLAN_GEL_TREUIL_v0.1.md` + entrées `TASKS.yaml` T181-00..19 + 3 contrats de cadrage (T181-06, T181-11, + autorité interlocks dans T181-01).
3. Démarrage **Phase -1** (harness + plan de tir) — bloque tout le reste.
