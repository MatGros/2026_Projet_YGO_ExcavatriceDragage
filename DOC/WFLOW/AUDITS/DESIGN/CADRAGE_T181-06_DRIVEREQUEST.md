# Cadrage T181-06 — `ST_fbWinch_DriveRequest`

> Statut : **ARRÊT VALIDATION HUMAINE** · Date : 2026-08-29  
> Références : `AF10_INTERFACE_TREUIL_CIBLE_T181.md` (fait foi), plan T181 §3/§4/§13, B2 §4.1/§4.3, B4 §3.2.

## 1. Décision d'architecture

`PRG_04_Treuils_Benne` reste l'unique arbitre des intentions : `Req → Tgt → Cmd → Act` :
producteurs `Req` → `DriveRequest` (`Tgt` palier/bornes) → `FB_Winch` (`Cmd` relais/contacteurs) → `PRG_06` (`Act` sorties). Ainsi, `FB_Winch` ne lit ni mode, ni synchro, ni producteur IHM/cycle ; `SyncCoupled` est exclusivement un diagnostic.

Nommage : DUT propriété de `FB_Winch` selon **NC-110** (`ST_fbWinch_*`) ; `Req` est réservé aux demandes (**NC-050**) ; unités physiques `_M` / `_Mps` sont explicites (**NC-030**).

## 2. Contrat DUT champ par champ

### `ST_fbWinch_DriveRequest` — producteur `PRG_04`, consommateur `FB_Winch`

| Champ | Type / unité | Polarité / rôle |
|---|---|---|
| `StartStop` | `BOOL` | TRUE = mouvement demandé |
| `Direction` | `INT`, -1/0/+1 | descente / stop / montée |
| `SpeedStepReq` | `INT`, 0..5 | cible décodée en amont |
| `MinStepUp`, `MaxStepUp` | `INT`, 0..5 | bornes montée agrégées |
| `MinStepDown`, `MaxStepDown` | `INT`, 0..5 | bornes descente agrégées |
| `TopLimitM`, `BottomLimitM` | `REAL`, m | limites effectives du cycle, calculées dans `PRG_04` |
| `SyncCoupled` | `BOOL` | diag : jamais lu par la logique `FB_Winch` |

### `ST_fbWinch_Sensors` — producteur acquisition/PRG_04, consommateur `FB_Winch`

| Champ | Type / unité | Polarité / rôle |
|---|---|---|
| `CablePosM` | `REAL`, m | mesure position propre à l'instance |
| `Homed`, `HomingSuspect` | `BOOL` | TRUE = référencé / doute présent |
| `ContactorsAllOff` | `BOOL` | TRUE = tous relais sens et C1..C4 retombés |
| `MeasuredSpeedMps` | `REAL`, m/s | mesure vitesse réelle |
| `MeasuredSpeedValid` | `BOOL` | TRUE = mesure exploitable |

### `ST_fbWinch_Cfg` — producteur configuration persistante, consommateur `FB_Winch`

| Champ | Type / unité | Rôle |
|---|---|---|
| `SpeedStepTable` | `ST_SpeedStepTable` | table de paliers propre à l'instance |
| `DirectionInterlockDelayUp/Down` | `TIME` | délais de changement de sens |
| `StepRampDelay` | `TIME` | cadence dédiée de rampe palier |
| `ContactorFeedbackTimeout` | `TIME` | attente retombée contacteurs |
| `SlowdownDistance_M` | `REAL`, m | approche bordure |
| `SlowdownMaxStep` | `INT`, 0..5 | plafond en zone bordure |

### `ST_WinchFinalInterlockReq` — producteur `PRG_04`, consommateur `PRG_06`

| Champs | Type | Rôle |
|---|---|---|
| `Enable`, `Reset`, `PowerContactorEngaged`, `SafeStop` | `BOOL` | pass-through de sécurité |
| `BrakeFeedback`, `ContactorsAllOff` | `BOOL` | retours physiques |
| `RelayFwd_Up`, `RelayRev_Down`, `Contactor1..4` | `BOOL` | commandes demandées ; nom actionneur conforme P5 |
| `Step` | `INT` | palier actif |
| `PowerCutOff` | `BOOL` | champ nu car struct déjà suffixée `Req` |

## 3. Clamp — sources, autorité et précédence

| Source | Sens | Portée | Calcul |
|---|---|---|---|
| `SyncDeviationWarn` → 1 | Up + Down | commun M1=M2 | agrégateur `PRG_04` |
| ralentissement bordure | selon bordure | par instance | agrégateur, `Sensors.CablePosM` |
| `HomingApproachActive` → 1 | Up | commun | agrégateur `PRG_04` |
| Dive floor → 3/4 | Down | commun | `FB_DiveSearch` → `PRG_03` |
| `ExtractionControlActive` → 1 | Up | commun | extraction → `PRG_03` |
| `M2_BucketJogLimit` → 1 | Up + Down | M2 seul | branche M2 de l'agrégateur |
| `ManualBucketLimitsActive` → 1 | Up + Down | M2 seul | branche M2 de l'agrégateur |
| `BucketNotClosedAscentStep1` | Up | M2 seul | branche M2 de l'agrégateur |
| `SlackCableAscentStep1` | Up | M2 seul | branche M2 de l'agrégateur |

```text
MaxStepClamped := MIN(AllMaxSources);
MinStepRaw     := MAX(AllMinSources);
MinClamped     := LIMIT(1, MinStepRaw, MaxStepClamped);
RequestedStep  := MAX(SpeedStepReqAfterHysteresis, MinClamped);
```

La garde est dans `FB_SpeedStep`, après le plafond et avant le `CASE`. Cas imposé : `MinStepDown=3`, `MaxStepDown=1` donne **1** ; le plafond safety gagne. `MinStepNumber` agit uniquement sur `RequestedStep`, jamais par `StepNumber := MinStepNumber`. Le `TON` inline de rampe, piloté par `Config.StepRampDelay`, conserve l'accostage d'un palier par période ; relâche `StartStop=FALSE` donne 0 immédiatement.

## 4. Flux, producteurs et arbitrages

```text
FB_DiveSearch (dans PRG_03) → Data.ReqProgram.MinStepDown
→ PRG_04 agrégateur → DriveRequest.MinStepDown → FB_Winch/FB_SpeedStep
```

Ce chemin est **intra-cycle, zéro latence** : `PRG_02…07` sont séquentiels dans MainTask 10 ms, pas « trois tâches ». `MinStepDown` est gaté par `DescentActive` ; au front de sortie il retombe le même cycle. Le TC couvre aussi le maintien joystick après fond : `KoboldBottomTouchLatched` coupe `StartStop`, donc le plancher devient sans effet.

| Producteur | Mapping vers `DriveRequest` | Verdict |
|---|---|---|
| `FB_Cycle` | `StartStop`, `Direction`, `SpeedStepReq` | OK ; ne pas fusionner sa demande existante |
| `PRG_03` | sélection mode, requêtes cycle et `MinStepDown` | OK |
| `FB_DiveSearch` | `MinStepDown`, inhibition palier 5 | gap traité T181-12 |
| `FB_ExtractionSequence` | `MaxStepUp:=1` via `ExtractionControlActive` | OK après renommage |
| joystick | direction, start/stop, palier décodé amont | OK |
| `FB_Modes` | gating, homing, `SyncCoupled` diag | OK ; hors `FB_Winch` |
| IHM | intentions M1/M2 par `PRG_04` | OK |
| `FB_Bucket` | sélection M2 et plafonds M2-only | cadré ci-dessous |

### Sync et override benne

`instWinchSync` reste dans `PRG_04` : `SafeStopMx_Active`, `EffectivePermit` et `SyncDeviationWarn` sont calculés avant l'agrégateur ; l'alerte sync plafonne **les deux** demandes. `FB_Winch_Symmetry` reste mesure passive, hors interface `FB_Winch`.

Lorsque `instBucket.Busy`, `PRG_04 §3` écrit seulement `DriveRequest.StartStop` et `Direction` de M2. Le jog est un **palier** `BucketJogStep : INT` (valeur à fixer par validation), jamais 15 %. `M2_BucketJogLimit` est un plafond M2-only dans l'agrégateur. Cela maintient le producteur unique et évite de brider M1.

## 5. Six décisions soumises à visa humain

| # | Décision proposée | Preuve / condition |
|---|---|---|
| 1 | Deux seuils `FB_WinchRateInterlock` restent des constantes locales indépendantes : safety nu côté final, safety+marge côté `FB_Winch`. **Valeurs numériques non fixées.** | Essai site et analyse sécurité avant valeur |
| 2 | D13 : supprimer `M2_SpeedStepTableActive` si les TC démontrent `MaxStepDown:=1` équivalent ; sinon conserver avec justification. | TC M2 jog + régression M1 ; visa humain |
| 3 | Ajouter à `ST_SafetyWinch` un champ public `ContactorStuck` produit exclusivement par `FB_Safety_Winch`, puis `PRG_04` réalimente `ContactorsCheck.ContactorStuck`. | G200 : un producteur ; IHM/Troubleshooting conservent le champ |
| 4 | Remplacer toute vitesse `%` de jog par `BucketJogStep : INT`, valeur de calibration humaine. | P1, absence de vitesse continue dans `FB_Winch` |
| 5 | Table RETAIN : `[axe][sens][charge][palier]` avec `Valid`, vitesse apprise et compteur échantillons ; chaque vitesse doit être finie, positive et dans une enveloppe configurée par palier. Initialisation invalide, collecte passive ; validation complète charge/vide avant armement. | migration RETAIN, test corruption et procédure de première mise en service |
| 6 | Import : `_TYPES` communs/supervision → DUT treuil → sous-FB → `FB_Winch`/Safety → `PRG_03/04/06` → `PRG_07`, `GVL_Troubleshooting`, IHM → SimBench. | import CODESYS manuel et bundle/G200 |

## 6. Conditions de sortie et arrêt

Avant T181-07/08/10/12/13, le visa humain doit valider les six lignes §5, en particulier les seuils, D13, la migration RETAIN et le palier de jog. Cette note ne change aucun POU ni aucun DUT : **STOP — validation humaine obligatoire.**
