# AF-10 — Interface cible du sous-système treuil (T181)

> Alimente la future fiche `FB_Winch` v2.0 du dossier `DOC/AF/AF_Partie-10_Fonction_Winch/` (à produire par T181-06).
> Intègre toutes les corrections de revue (utilisateur + B2 + B4). **Fait foi pour le cadrage T181-06.**
> Date : 2026-08-29.

---

## 0 · Principes actés

| # | Décision | Source |
|---|---|---|
| P1 | **Le treuil = 1 palier, pas un %.** Aucune consigne de vitesse continue n'entre dans `FB_Winch`. Le décodage joystick % → palier + hystérésis vit **en amont** (chaîne joystick / `PRG_04`). | utilisateur |
| P2 | **`FB_Safety_Winch` reste un POU distinct, externe** à `FB_Winch` — arbitrage paire (sync M1/M2), `ReqPowerCutOff` niveau chaîne, fonction de sécurité auditable ISO 13849. Ses sorties entrent en entrées plates. | utilisateur + B4 |
| P3 | **Mesure vitesse = m/s.** Plus de `MeasuredSpeedBand : INT`. `Sensors.MeasuredSpeedMps : REAL` + `MeasuredSpeedValid`. La survitesse (dans `FB_Safety_Winch`) compare au `vitesse_apprise + marge` en m/s. | utilisateur |
| P4 | **Limites haute/basse = données par cycle**, calculées dans `PRG_04` (MIN câble/légal, override maintenance) — pas des constantes de `Config`. Passent dans `DriveRequest`. | utilisateur |
| P5 | **Nommage actionneur = convention IO HW** : `RelayFwd_Up` / `RelayRev_Down` (le préfixe `M1_`/`M2_`, l'extension `_Close`/`_Open` M2 et le suffixe `_DQ` sont ajoutés par `PRG_06`). | utilisateur (`PRG_06_Outputs.st:144-145,217-218`) |
| P6 | **`ReqPowerCutOff`** : la sortie `FB_Safety_Winch` est une *demande* (agrégée M1+M2+M3 par `PRG_06`, acte = chaîne AU). Marqueur `Req` en préfixe (NC-050). Dans une struct déjà nommée `...Req`, les champs restent nus. | utilisateur + `NAMING_CONVENTION.md` NC-050 |
| P7 | **Le clamp est unifié mais calculé par instance** : bornes communes identiques M1=M2 (déviation sync, ralentissement bordure, approche homing, plancher plongée) ; **M2 seul** applique en plus le plafond benne. | challenge #2-A |
| P8 | **On refait ce qu'il faut refaire.** Le harnais `FB_TestHarness_PRG_04` est un stub simplifié → il est **reconstruit** en miroir fidèle de `PRG_04 §1-§8`. Les sous-FB à créer/refaire sont créés/refaits. | utilisateur + B4-§3.1 |

---

## 1 · DUT

### `ST_fbWinch_DriveRequest` — requête d'axe (produite par `PRG_04`, une par treuil)

| Champ | Type | Unité/domaine | Rôle |
|---|---|---|---|
| `StartStop` | BOOL | — | Ordre marche / arrêt |
| `Direction` | INT | −1 / 0 / +1 | Sens : −1 descente · 0 stop · +1 montée |
| `SpeedStepReq` | INT | 0..5 | **Palier demandé** (décodé en amont — joystick % ou étape de cycle) |
| `MinStepUp` | INT | 0..5 | Plancher palier montée (agrégé `PRG_04`) |
| `MaxStepUp` | INT | 0..5 | Plafond palier montée (MIN des sources) |
| `MinStepDown` | INT | 0..5 | Plancher palier descente — **plongée Kobold 3-4** |
| `MaxStepDown` | INT | 0..5 | Plafond palier descente |
| `TopLimitM` | REAL | m | Limite haute effective ce cycle : **7,5 m** normal / **8,5 m** si override maintenance N1 |
| `BottomLimitM` | REAL | m | **MIN**(limite câble physique, limite légale) — calculé `PRG_04` |
| `SyncCoupled` | BOOL | — | **Diag strict** — `FB_Winch` ne le lit jamais en logique (garde de revue) |

> Retiré vs maquette précédente : `SpeedTgt_Pct` (→ `SpeedStepReq`).

### `ST_fbWinch_Sensors`

| Champ | Type | Rôle |
|---|---|---|
| `CablePosM` | REAL (m) | Position câble propre à l'instance |
| `Homed` | BOOL | Treuil référencé |
| `HomingSuspect` | BOOL | Doute sur le référencement |
| `ContactorsAllOff` | BOOL | Retour unique : relais sens + C1..C4 tous retombés (ex-`FwdRevSpeedFeedbackOff`) |
| `MeasuredSpeedMps` | REAL (m/s) | Mesure vitesse câble (codeur) — **remplace `MeasuredSpeedBand`** |
| `MeasuredSpeedValid` | BOOL | Mesure exploitable |

### `ST_fbWinch_Cfg` — **statique uniquement**

| Champ | Type | Rôle |
|---|---|---|
| `SpeedStepTable` | ST_SpeedStepTable | Table des 5 paliers propre au treuil |
| `DirectionInterlockDelayUp` | TIME | Délai interlock changement de sens → montée |
| `DirectionInterlockDelayDown` | TIME | Délai interlock changement de sens → descente |
| `StepRampDelay` | TIME | **Tempo de rampe palier** (paramètre **dédié**, découplé des délais d'interlock direction — corrige D10) |
| `ContactorFeedbackTimeout` | TIME | Attente retombée des contacteurs |
| `SlowdownDistance_M` | REAL (m) | Distance d'approche bordure avant ralentissement |
| `SlowdownMaxStep` | INT | Plafond palier en zone de ralentissement bordure |

> Retiré vs maquette : `TopLimitM`, `BottomLimitM` (→ `DriveRequest`), `HystMargin` (l'hystérésis part avec le décodage % en amont), `MeasuredSpeedBand`.

### `ST_WinchFinalInterlockReq` — renommé + réduit (ex-`ST_WinchFinalInterlockRequest`)

Producteur `PRG_04`, consommateur `PRG_06`. **Le nom de la struct porte le rôle `Req` → champs nus.**

| Champ | Type | Rôle |
|---|---|---|
| `Enable`, `Reset`, `PowerContactorEngaged`, `SafeStop` | BOOL | états pass-through |
| `BrakeFeedback`, `ContactorsAllOff` | BOOL | feedbacks physiques |
| `RelayFwd_Up`, `RelayRev_Down` | BOOL | ex-`RequestedRelayFwd/Rev` |
| `Contactor1` .. `Contactor4` | BOOL | ex-`RequestedContactor1..4` |
| `Step` | INT | ex-`RequestedStep` |
| `PowerCutOff` | BOOL | nu ici (struct = `Req`) ; agrégé M1+M2+M3 par `PRG_06` |

> Symétrie M3 : `ST_TranslationFinalInterlockRequest` → `ST_TranslationFinalInterlockReq`, même règle.

---

## 2 · `FB_Winch` (générique, ×2 : M1 Retenue, M2 Benne)

### VAR_INPUT

| Groupe | Champs |
|---|---|
| Commandes & permis | `Enable`, `Reset`, `PowerContactorEngaged`, `DriveRequest : ST_fbWinch_DriveRequest`, `Sensors : ST_fbWinch_Sensors`, `Config : ST_fbWinch_Cfg` |
| Sécurité (sorties `FB_Safety_Winch`, déjà arbitrées paire+sync) | `SafeStop`, `PermitUp`, `PermitDown` |
| Test | `BypassContactorCheck`, `BypassGlobal` |

> Retiré : `StartStop`/`Direction`/`SpeedTgt_Pct`/`Mode` + tous les scalaires CFG/HW (→ structs). `Mode` était **entrée morte** — son retrait édite `PRG_04:671,702` (acté : Phase 0 = interface en réduction contrôlée, 2 sites `PRG_04` au même commit).

### VAR_OUTPUT

| Groupe | Champs |
|---|---|
| État | `Ready`, `Fault : ST_Fault` |
| Actionneurs | `RelayFwd_Up`, `RelayRev_Down`, `Contactor1` .. `Contactor4` |
| Diag | `SpeedStepReq_Decoded` (palier après clamp), `StepNumber` (palier temporisé actif), `StepRampElapsed`, `ContactorsCheck : ST_ContactorCheck` *(sans `ContactorStuck` — propriétaire = `FB_Safety_Winch`, voir note)*, `InTopSlowdownZone`, `InBottomSlowdownZone`, `CommandedDirection`, `DirectionChangePending`, `DirectionChangeElapsed` |

> **D07 / `ContactorsCheck.ContactorStuck`** : la *détection* passe dans `FB_Safety_Winch`. Le *champ* `ContactorsCheck.ContactorStuck` reste publié (consommé IHM/Troubleshooting) mais **ré-alimenté depuis `FB_Safety_Winch`** via `PRG_04` — pas supprimé. La cause de défaut interne `instCauses[1]` de `FB_Winch` est retirée en parallèle.

---

## 3 · Sous-FB

| FB | Statut | Interface | Note |
|---|---|---|---|
| **`FB_WinchDirectionInterlock`** | à créer (extraction `FB_Winch §5`) | IN: `Enable`, `ReqDirection:INT`, `ChangeDelayUp:TIME`, `ChangeDelayDown:TIME`, `EnableRising:BOOL` — OUT: `CommandedDirection:INT`, `ChangePending:BOOL`, `DelayElapsed:TIME` | **D18** : sur `EnableRising` (front montant `Enable`), **ne pas** adopter `ReqDirection` immédiatement — armer le temps mort. Cible = front `Enable`, **pas** `FirstScanDone`. |
| **`FB_WinchStepShaper`** | à créer (extraction `FB_Winch:250-271`) | IN: `Enable:BOOL`, `TargetStep:INT`, `StepRampDelay:TIME` — OUT: `ShapedStep:INT`, `StepDelayElapsed:TIME` | Le bloc `BusinessStepDelay` = petite machine d'état (palier courant/cible + TON + `step++` sur front) **+** couplage caché D10. L'extraire isole D10 et rend l'anti-à-coup testable en isolé. Reco B4 « garder inline » **reversée** : « 1 responsabilité = 1 FB » (AGENTS.md), symétrique de `FB_WinchDirectionInterlock`. |
| **`FB_WinchRateInterlock`** | à créer | IN: `Enable`, `Reset`, `SpeedStepReq:INT`, `CurrentStep:INT`, `MeasuredSpeedMps:REAL`, `MeasuredSpeedValid:BOOL`, `RefSpeedMps:REAL`, `Bypass:BOOL` — OUT: `AuthorizedStep:INT`, `RateLimited:BOOL`, `Governed:BOOL`, `Reason:enum` | **Seuils = 2 CONSTANTES en dur**, pas des entrées : instance `FB_Winch` = `RefSpeed + marge` ; instance `PRG_06` = `RefSpeed` nu. Constantes ≠ corruptibles → renforce l'indépendance (B4). `Governed` de l'instance `PRG_06` = `FinalInterlockGoverned`, DOIT rester FALSE en nominal. |
| **`FB_WinchSpeedLearning`** | à créer | IN: `Enable`, `LearnStart:BOOL` (1 bit IHM), `WinchId:INT`, `Direction:INT`, `StepNumber:INT`, `MeasuredSpeedMps:REAL`, `MeasuredSpeedValid:BOOL`, `LoadPresent:BOOL`, `StableForLearn:BOOL` — IN_OUT: `Table : ST_WinchSpeedLearnTable` (RETAIN) — OUT: `Learning:BOOL`, `TableComplete:BOOL`, `LampLearn:BOOL`, `CellsFilled:INT`, `CellsTotal:INT` | Collecteur **passif** (jamais de commande moteur). RETAIN : garde-fou de plausibilité obligatoire (borne min/max par palier ; valeur hors borne → cellule invalidée, pas d'armement survitesse). Emplacement RETAIN dans `GVL_PERSISTENT` en **fin** de zone (l'ajout ne décale pas les champs existants). |

---

## 3bis · Cadencement des contacteurs — règle absolue (utilisateur, critique matériel)

> Cadencer la **montée** protège le moteur et le matériel. La **retombée** des contacteurs de
> **vitesse** doit être quasi instantanée. **Condition absolue** : ne jamais relâcher le contacteur
> de **sens** (`RelayFwd_Up` / `RelayRev_Down`) **avant** que les contacteurs de **vitesse**
> (`Contactor1..4`) soient tous à 0.
>
> Fondement électrotechnique (moteur à bagues) : le contacteur de sens est **statorique** (coupe le
> courant ligne plein → arc AC-3 pleine charge, soudure, transitoire rotor). Les `Contactor1..4`
> commutent le **circuit rotorique** (résistances, courant de glissement) — c'est leur régime nominal.
> Séquence saine = ouvrir le rotor (couple s'effondre, courant chute) **puis** ouvrir le stator à
> courant quasi nul.

### Séquence — montée / retombée nominale

| Phase | `Contactor1..4` (rotor) | `RelayFwd_Up` / `RelayRev_Down` (stator) | Frein |
|---|---|---|---|
| **Montée en palier** | montée **cadencée** : +1 cran par `StepRampDelay` (`FB_WinchStepShaper`) | établi **avant** le 1ᵉʳ cran de vitesse ; maintenu | desserré |
| **Relâche joystick / `StartStop=FALSE`** | **tous à 0 immédiatement** (pas de rampe descendante) | **maintenu** (fenêtre de retombée) | voir §3ter |
| **Confirmation vitesse retombée** | `ContactorsAllOff` = TRUE (feedback) OU `Contactor1..4` commandés à 0 depuis ≥ `DropConfirmDelay` | → 0 | — |

### §3ter — bornage de la fenêtre de retombée (correction B5-§1.1)

La fenêtre « sens maintenu, vitesse déjà à 0 » est **bornée** :

| Cas | Comportement |
|---|---|
| Feedback `ContactorsAllOff` confirmé **ou** tempo `DropConfirmDelay` écoulée | chute du sens → 0 (cas nominal) |
| **`T_max` atteint** sans confirmation (`ContactorsAllOff` collé « not released ») | chute du sens **forcée** + latch `ContactorStuck` (propriétaire `FB_Safety_Winch`) + **escalade** : `SafeStop` immédiat, puis `PowerCutOff` **si le collage persiste** (le contacteur collé empêche l'arrêt = cas grave). Le maintien indéfini du stator sous tension est **interdit**. |
| Feedback `ContactorsAllOff` collé « released » alors qu'un `Contactor1..4` est encore commandé | la garde `DropConfirmDelay` (tempo) **prévaut** sur le feedback seul (DI simple voie) — on n'ouvre pas le sens sur la seule foi du feedback |

`DropConfirmDelay` (défaut 100 ms) et `T_max` (défaut 1 s) sont des **paramètres dédiés modifiables** — jamais réutiliser `DeadTimeSameDir/OppositeDir`
ni `DirectionInterlockDelay*` (répéterait D10). Ordre : `DropConfirmDelay < T_max`.

### `FB_WinchStepShaper` — comportement asymétrique

```
ShapedStep :
  montée   : ShapedStep -> ShapedStep+1 quand StepDelayElapsed >= StepRampDelay   (cadencé)
  descente : ShapedStep -> 0 au cycle suivant                                     (immédiat, pas de rampe descendante)
```

### Ordonnancement de retombée — vérifié à DEUX niveaux (correction B5-§1.2)

⚠️ **Conflit à résoudre AVANT le code** : `FB_WinchOutputInterlock` §5 force aujourd'hui
`RelayFwd:=FALSE` dès `MotorRequest=FALSE` (`FB_WinchOutputInterlock.st:122,208,225-231`), lui-même
faux dès `RequestedStep=0`. La barrière **coupe donc le sens le cycle où la vitesse tombe** → elle
défait le maintien fait dans `FB_Winch`. La règle « 2 niveaux » **exige de restructurer §5** de la
barrière pour qu'elle **tienne aussi** le relais de sens jusqu'à `FwdRevSpeedFeedbackOff` (borné `T_max`).
→ **Cette refonte de la barrière est portée par T181-01** (pas T181-05).

| Instance | Seuil de confirmation « vitesse retombée » | Rôle |
|---|---|---|
| dans `FB_Winch` (sortie) | `DropConfirmDelay` court (marge) — logique programme | gouverne en nominal |
| dans `FB_WinchOutputInterlock` (barrière) | `ContactorsAllOff` **OU** `T_max` (le filet **porte le timeout**) | filet — coupe le sens seulement après retombée effective, mais **jamais indéfiniment** |

> Diag `DirectionDropBlocked` (sens en attente de retombée vitesse) : DOIT être **transitoire**
> (≤ quelques cycles) en nominal. **Un `DirectionDropBlocked` transitoire ne compte PAS comme une
> gouvernance de la barrière** (`FinalInterlockGoverned` reste FALSE). Un latch prolongé = contacteur
> de vitesse collé → `ContactorStuck`.

### Coupures dures vs ordonnées (correction B5-§M6)

L'ordonnancement « sens après vitesse » s'applique aux arrêts **normaux** et à `SafeStop` métier.
Il ne s'applique **pas** aux coupures dures :

| Événement | Comportement |
|---|---|
| `Enable = FALSE`, `PowerCutOff`, AU physique | **coupe tout en amont / immédiat** — l'ordonnancement est court-circuité (la puissance disparaît de toute façon) |
| `Fault.Error` interne de `FB_Winch` (`FB_Winch.st:300-304`) | à **classer par type** : défaut « puissance/sécurité » → coupe dur ; défaut « process » → ordonné. Liste à figer en T181-05. |

La garde mécanique `G4xx_check_direction_after_speed` **exempte explicitement** les chemins
`NOT Enable`, `PowerCutOff` et la sous-liste de `Fault.Error` classée « dure ».

### Frein — décision (utilisateur, plus une question)

Sur M1/M2 le dernier essai = frein piloté **en direct** par le contacteur (`BrakeCmd := RelayFwd_Up OR RelayRev_Down`, sans tempo). On **réintègre `FB_Brake`** (comme la translation M3) avec **tempos de config = 0 s par défaut** → pilotage et relâchement **instantanés**, mais **modifiables** si on change d'avis. `BrakeCmd` reste asservi au relais de sens : le frein colle donc au même instant que la chute du sens (fin de la fenêtre §3bis, bornée `T_max`). **Aucune logique de séquence frein dédiée.**

> La fenêtre §3bis (sens tenu, vitesse à 0, ≤ `T_max`) est la seule fenêtre « frein desserré + couple faible » — croiser avec D16/T178 au vecteur T181-00 « relâche joystick sous charge → dérive ≤ X cm pendant la fenêtre sens-hold ».

## 3quater · Clamp de palier — jeux de bornes par contexte (décision utilisateur)

Le clamp `Min/MaxStep{Up,Down}` de `DriveRequest` reçoit un **jeu de bornes différent selon le
contexte de pilotage**, calculé par `PRG_04` :

| Contexte | Bornes envoyées | Portée |
|---|---|---|
| **Pilotage couplé** (les 2 treuils ensemble) | `SpeedStepMin/Max` **communs** M1 = M2 | commun |
| **Pilotage M1 seul** ou **M2 seul** | bornes propres à l'axe | par instance |
| **Commande benne** — maintenance / jog manuel | `BucketJogStep` (défaut **palier 1**, configurable) | M2 |
| **Commande benne** — **semi-auto / cycle Grafcet** (ouverture / fermeture) | `BucketCycleMaxStep` (défaut **palier 4 ou 5**, configurable) — **PAS forcé lent** | M2 |

> ⚠️ **À vérifier au code** : aux essais, des vitesses lentes ont été forcées pour la benne. En
> semi-auto / cycle la benne **doit pouvoir monter jusqu'au palier 4-5** (réglable) — le forçage lent
> benne ne s'applique qu'au jog manuel / maintenance.

### Ralentissement en approche des limites logicielles — avec exception

Un **ralentissement imposé ~1 m avant** chaque limite logicielle (haute / basse) reste **toujours**
actif (via `Config.SlowdownDistance_M`).

**Exception (constat essai)** : plafonner au **palier 1** en approche du FDC haut logiciel **fait
caler le moteur** — le contacteur de vitesse joue aussi sur le **couple**. Donc `Config.SlowdownMaxStep`
**ne vaut PAS 1 par défaut** : valeur **configurable palier 2 ou 3** (à ajuster à l'essai site),
potentiellement distincte par sens et par contexte (idem risque pour la benne vers position
ouverture / fermeture — pour l'instant palier 1, à revoir).


## 4 · Survitesse — une seule implémentation (SEC-2)

Aujourd'hui **deux** gardes morts : `FB_SpeedStep §2ter` **et** `FB_Winch §6`. → **les deux sont retirés**. La surveillance survitesse vit **exclusivement dans `FB_Safety_Winch`** (T181-16) :

| Entrée `FB_Safety_Winch` (ajouts) | Type | Rôle |
|---|---|---|
| `OverspeedRefMps` | REAL | vitesse apprise pour {sens, charge} courants (de `FB_WinchSpeedLearning`) |
| `OverspeedMarginSoftMps` | REAL := 0.5 | `appris + 0,5` → diag |
| `OverspeedMarginHardMps` | REAL := 1.5 | `appris + 1,5` → `SafeStop` |
| `OverspeedTableComplete` | BOOL | arme la surveillance **seulement si** table `{sens,charge}` complète |
| `BypassOverspeed` | BOOL := FALSE | flag débrayable |

Sorties : `OverspeedSoftWarn`, `OverspeedHardTrip`.
`FB_SpeedStep` perd `MeasuredSpeedBand` / `SpeedGuardEnable` / `SpeedGuardReady` — devient un **décodeur palier→contacteurs** pur + clamp `LIMIT(1, MinStepNumber, MaxStepClamped)`.
`SpeedGuardReady := NOT instWinchSync.Fault.Error` (`PRG_04:684,720`) — **câblage supprimé** (SEC-3).

---

## 5 · Nommage — lot de renommages T181-09

| Ancien | Nouveau | Portée |
|---|---|---|
| `ForceMinSpeedStep` | `ExtractionControlActive` | `FB_ExtractionSequence`, `ST_ProgramBucketRequest`, `PRG_03`, `PRG_04` |
| `ControlAscentActive` (PRG_04 local) | fusionné dans `ExtractionControlActive` | `PRG_04:341-357` |
| `CfgMaxStepDescente` | `MaxStepDown` | `PRG_04`, `FB_Winch`, fiches AF |
| `MaxStepAscent` | `MaxStepUp` | idem |
| `M2_ForceSlowSpeed` | `M2_BucketJogLimit` | `PRG_04:285-288,405,710,716-717,969`, `FB_Bucket`, `ST_BucketHMIState` *(périmètre réel — B4)* |
| `RelayFwd` / `RelayRev` (sorties `FB_Winch`) | `RelayFwd_Up` / `RelayRev_Down` | `FB_Winch`, `PRG_04`, `PRG_06`, `FB_TroubleshootingView` |
| `FwdRevSpeedFeedbackOff` | `ContactorsAllOff` | chaîne treuil |
| `FB_Safety_Winch.PowerCutOff` (sortie) | `ReqPowerCutOff` | `FB_Safety_Winch`, `PRG_04`, `ST_SafetyWinch`, IHM/Troubleshooting |
| `ST_WinchFinalInterlockRequest` | `ST_WinchFinalInterlockReq` + champs nus (drop `Requested*`) | `PRG_04`, `PRG_06`, `_TYPES` supervision |
| `ST_TranslationFinalInterlockRequest` | `ST_TranslationFinalInterlockReq` | `PRG_05`, `PRG_06` (symétrie M3) |
| `M2_SpeedStepTableActive` (si conservé — décision D13) | à statuer T181-06 | `PRG_04:405-429` |

Renommage **transverse en une passe** + `G200` + `run_all_gates` immédiat (1 oubli = liaison rouge).

---

## 6 · Harnais d'intégration — reconstruit (B4-§3.1)

`FB_TestHarness_PRG_04.st` (196 l., M2/sync/bucket déclarés jamais appelés, `MaxStepAscent:=5`/`TopLimitM:=7.5` en dur) est **reconstruit** en miroir fidèle de `PRG_04 §1-§8` :
- vrai agrégateur de clamp (commun + M2-propre), vrais `SEL` M1/M2, vraie taxonomie de permits §5, `instWinchM2` / `instWinchSync` / `instBucket` réellement appelés.
- **Gate d'égalité logique** stub ↔ `PRG_04` (ou stub généré depuis `PRG_04`) — sinon dérive garantie à chaque édition `PRG_04` (REX `PRG_10_Outputs_LD`).
- Oracle des vecteurs : **table d'attendus écrite à la main** (pas de shadow comparison contre un référentiel connu buggé — B4).
- Coordination : T169-A (AGY-01) travaille sur `FB_Main_EndToEnd` → `bloque_par`.

---

## 7 · Points restant à trancher en cadrage T181-06 (arrêt humain)

1. **Seuils de cadence de `FB_WinchRateInterlock`** : 2 constantes en dur dans le FB, valeurs ?
2. **D13** : supprimer `M2_SpeedStepTableActive` (`PRG_04:405-429`) si `MaxStepDown:=1` suffit, ou conservation motivée.
3. **`ContactorsCheck.ContactorStuck`** : forme exacte de la ré-alimentation depuis `FB_Safety_Winch` (nouveau champ bus vs réutilisation `ST_SafetyWinch`).
4. **Bornes benne** : `BucketJogStep : INT` (jog manuel/maint, défaut palier 1) + `BucketCycleMaxStep : INT` (semi-auto/cycle, défaut 4-5, **pas** forcé lent). Vérifier le forçage lent benne des essais. `Config.SlowdownMaxStep` **configurable ≠ 1** (le palier 1 en approche FDC fait caler le moteur).
5. **RETAIN table apprentissage** : structure exacte + bornes de plausibilité par palier + procédure de 1ʳᵉ mise en service.
6. **Ordre d'import CODESYS** : inclure `PRG_07` + `_TYPES` supervision (partagent `ST_WinchState` / `ST_SafetyWinch` modifiés).
