# Cadrage T181-06 — `ST_fbWinch_DriveRequest` (clamp unifié)

> Statut : **ARRÊT VALIDATION HUMAINE — décisions tranchées, visa humain requis** · Date : 2026-08-29
> Références : `AF10_INTERFACE_TREUIL_CIBLE_T181.md` (fait foi), plan T181 §3/§4/§13, B2 §4.1/§4.3, B4 §3.2.
> Contrat : `TASK_CONTRACT_T181-06_DRIVEREQUEST_CADRAGE.yaml` (AC1–AC8, AC7b, AC7c).
> **Documentation uniquement — aucun POU ni DUT modifié. STOP avant toute écriture `CODE/`.**

---

## 1. Décision d'architecture

`PRG_04_Treuils_Benne` reste l'unique arbitre des intentions : `Req → Tgt → Cmd → Act` :
producteurs `Req` → `DriveRequest` (`Tgt` palier/bornes) → `FB_Winch` (`Cmd` relais/contacteurs) → `PRG_06` (`Act` sorties). Ainsi, `FB_Winch` ne lit ni mode, ni synchro, ni producteur IHM/cycle ; `SyncCoupled` est exclusivement un diagnostic (garde de revue : jamais lu en logique).

Nommage : DUT propriété de `FB_Winch` selon **NC-110** (`ST_fbWinch_*`) ; `Req` réservé aux demandes (**NC-050**) ; unités physiques `_M` / `_Mps` explicites (**NC-030**).

**Point d'arbitrage unique confirmé (AC7)** : `StartStop` / `Direction` / `SpeedStepReq` restent arbitrés dans `PRG_04 §3`, jamais dans `FB_Winch`. Aucun arbitrage ne migre dans le FB de mouvement.

---

## 2. Contrat DUT champ par champ (AC1)

### `ST_fbWinch_DriveRequest` — producteur `PRG_04`, consommateur `FB_Winch`

| Champ | Type / unité | Polarité / rôle |
|---|---|---|
| `StartStop` | `BOOL` | TRUE = mouvement demandé |
| `Direction` | `INT`, -1/0/+1 | descente / stop / montée |
| `SpeedStepReq` | `INT`, 0..5 | cible décodée en amont (joystick % ou étape de cycle) |
| `MinStepUp`, `MaxStepUp` | `INT`, 0..5 | bornes montée agrégées |
| `MinStepDown`, `MaxStepDown` | `INT`, 0..5 | bornes descente agrégées |
| `TopLimitM`, `BottomLimitM` | `REAL`, m | limites effectives du cycle, calculées dans `PRG_04` |
| `SyncCoupled` | `BOOL` | diag : jamais lu par la logique `FB_Winch` |

> Retiré vs maquette : `SpeedTgt_Pct` (→ `SpeedStepReq`). `MinStepUp/Down` = planchers, `MaxStepUp/Down` = plafonds (MIN des sources).

### `ST_fbWinch_Sensors` — producteur acquisition/PRG_04, consommateur `FB_Winch`

| Champ | Type / unité | Polarité / rôle |
|---|---|---|
| `CablePosM` | `REAL`, m | mesure position propre à l'instance |
| `Homed`, `HomingSuspect` | `BOOL` | TRUE = référencé / doute présent |
| `ContactorsAllOff` | `BOOL` | TRUE = tous relais sens et C1..C4 retombés (ex-`FwdRevSpeedFeedbackOff`) |
| `MeasuredSpeedMps` | `REAL`, m/s | mesure vitesse réelle (remplace `MeasuredSpeedBand`) |
| `MeasuredSpeedValid` | `BOOL` | TRUE = mesure exploitable |

### `ST_fbWinch_Cfg` — producteur configuration persistante, consommateur `FB_Winch` (statique uniquement)

| Champ | Type / unité | Rôle |
|---|---|---|
| `SpeedStepTable` | `ST_SpeedStepTable` | table de paliers propre à l'instance |
| `DirectionInterlockDelayUp/Down` | `TIME` | délais de changement de sens |
| `StepRampDelay` | `TIME` | cadence dédiée de rampe palier (découplée des délais d'interlock — corrige D10) |
| `ContactorFeedbackTimeout` | `TIME` | attente retombée contacteurs |
| `SlowdownDistance_M` | `REAL`, m | approche bordure |
| `SlowdownMaxStep` | `INT`, 0..5 | plafond en zone bordure — **configurable ≠ 1** (voir Décision 4) |

> Retiré vs maquette : `TopLimitM`/`BottomLimitM` (→ `DriveRequest`), `HystMargin` (l'hystérésis part avec le décodage % en amont), `MeasuredSpeedBand`.

### `ST_WinchFinalInterlockReq` — producteur `PRG_04`, consommateur `PRG_06`

| Champs | Type | Rôle |
|---|---|---|
| `Enable`, `Reset`, `PowerContactorEngaged`, `SafeStop` | `BOOL` | pass-through de sécurité |
| `BrakeFeedback`, `ContactorsAllOff` | `BOOL` | retours physiques |
| `RelayFwd_Up`, `RelayRev_Down`, `Contactor1..4` | `BOOL` | commandes demandées ; nom actionneur conforme P5 |
| `Step` | `INT` | palier actif |
| `PowerCutOff` | `BOOL` | champ nu car struct déjà suffixée `Req` |

---

## 3. Clamp — sources, autorité et précédence (AC2, AC3)

### 3.1 Sources de borne — commun vs M2-propre (amendement A)

| Source de borne | Sens | Portée | Où calculée |
|---|---|---|---|
| `SyncDeviationWarn` → plafond 1 | Asc + Desc | **commun** M1 = M2 | agrégateur `PRG_04` |
| Zone ralentissement bordure (`CablePosM` vs `SlowdownDistance_M`) → `SlowdownMaxStep` | selon bordure | **par instance** (position câble propre) | agrégateur `PRG_04`, `Sensors.CablePosM` de chaque instance |
| `HomingApproachActive` → plafond 1 | Asc | **commun** | agrégateur `PRG_04` |
| Dive floor Kobold → `MinStepDown = 3` (`CfgDiveFloorStep`) | Desc | **commun** | producteur `FB_DiveSearch` (amendement C) |
| `ExtractionControlActive` (ex-`ForceMinSpeedStep`) → plafond 1 | Asc | **commun** | `FB_ExtractionSequence` → `PRG_03` → `PRG_04` |
| `M2_BucketJogLimit` (ex-`M2_ForceSlowSpeed`) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur `PRG_04`, branche M2 |
| `ManualBucketLimitsActive` (FDC benne MAINT) → plafond 1 | Asc + Desc | **M2 uniquement** | agrégateur `PRG_04`, branche M2 |
| `BucketNotClosedAscentStep1` | Asc | **M2 uniquement** (géométrie benne) | agrégateur `PRG_04`, branche M2 |
| `SlackCableAscentStep1` | Asc | **M2 uniquement** | agrégateur `PRG_04`, branche M2 |

> ⚠️ **Rôle M2-only de la benne (tranché)** : câbler strictement identique M1 = M2 = **régression M1** dès que la benne jogge en pilotage unitaire. L'agrégateur produit `commonMin/Max{Asc,Desc}` (identiques M1=M2) **puis** M2 applique `MIN(…, plafondBenne)`. Les bridages benne sont **M2-propres** ; M1 ne les voit jamais.

### 3.2 Précédence Min/Max (amendement B) — règle écrite noir sur blanc

```text
MaxStepClamped := MIN(AllMaxSources);          // plafond = MIN des sources plafond
MinStepRaw     := MAX(AllMinSources);          // plancher = MAX des sources plancher
MinClamped     := LIMIT(1, MinStepRaw, MaxStepClamped);   // plafond safety gagne TOUJOURS
RequestedStep  := MAX(SpeedStepReqAfterHysteresis, MinClamped);   // plancher sur la cible
```

- La garde `LIMIT(1, MinStepNumber, MaxStepClamped)` vit dans **`FB_SpeedStep`**, **après** le plafond et **avant** le `CASE StepNumber`.
- **Cas limite imposé (AC3)** : `MinStepDown = 3` (Kobold) + bordure basse voulant `MaxStepDown = 1` → résultat **1** (le plafond safety gagne).
- `MinStepNumber` agit **uniquement sur `RequestedStep`** (la cible), jamais par `StepNumber := MinStepNumber` (amendement D, AC5) — sinon court-circuit de la rampe = à-coup contacteur.
- `MinStep` **sans effet si `StartStop = FALSE`** (relâche → palier 0 immédiat).
- Montée `StepNumber 0→1→2→3` cadencée par `FB_WinchStepShaper` (`Config.StepRampDelay`, ~0,5–1 s/cran) ; descente → 0 immédiat.

---

## 4. Flux, producteurs et arbitrages (AC4, AC6)

### 4.1 Producteur `MinStepDown` (amendement C) — nommé et localisé

```text
FB_DiveSearch (instancié dans PRG_03) → Data.ReqProgram.MinStepDown
→ PRG_04 agrégateur → DriveRequest.MinStepDown → FB_Winch / FB_SpeedStep
```

- **Chemin intra-cycle, zéro latence** : `PRG_02…07` s'exécutent **séquentiellement dans la même MainTask 10 ms** (AF02 §5), pas « trois tâches ». `FB_DiveSearch` est instancié dans `PRG_03` → le flux `FB_DiveSearch → PRG_03.ReqProgram → PRG_04` est **intra-cycle**.
- `MinStepDown` est **gaté par `DescentActive`** (front de sortie) ; au front de sortie il retombe le même cycle.
- Cas « maintien descente joystick post-fond » : `KoboldBottomTouchLatched` coupe `StartStop` → le plancher devient sans effet. TC front + TC maintien post-fond dans T181-12.
- `FB_DiveSearch.CurrentSpeedStep` (interdiction palier 5 Kobold) est câblé — D12 traité par T181-12.

### 4.2 Matrice d'interconnexion producteurs → `DriveRequest` (AC6)

| Producteur | Mapping vers `DriveRequest` | Verdict |
|---|---|---|
| `FB_Cycle` (Grafcet X0-X13) | `StartStop`, `Direction`, `SpeedStepReq` | ✅ OK — **ne pas** fusionner `ST_fbCycle_WinchCmdDemand` avec un refactor palier-INT |
| `PRG_03` | sélection mode, requêtes cycle et `MinStepDown` | ✅ OK (sélecteur mode-gated) |
| `FB_DiveSearch` | `MinStepDown`, inhibition palier 5 | ⚠️ gap traité T181-12 (producteur à créer) |
| `FB_ExtractionSequence` | `MaxStepUp := 1` via `ExtractionControlActive` | ✅ OK après renommage T181-09 |
| joystick | `Direction`, `StartStop`, palier décodé amont | ✅ OK / ⚠️ plongée (granularité 0-40 % perdue — assumé, lissé) |
| `FB_Modes` | gating, homing, `SyncCoupled` diag | ✅ OK ; hors `FB_Winch` |
| IHM directe | intentions M1/M2 par `PRG_04` | ✅ OK trivial |
| `FB_Bucket` (M2 caché) | sélection M2, `StartStop`/`Direction`, plafonds M2-only | ✅ cadré §4.3 |

### 4.3 Sync et override benne (AC7b)

- `instWinchSync` reste dans `PRG_04` : `SafeStopMx_Active`, `EffectivePermit` et `SyncDeviationWarn` sont calculés **avant** l'agrégateur ; l'alerte sync plafonne **les deux** demandes. `FB_Winch_Symmetry` reste mesure passive, hors interface `FB_Winch`.
- **Override benne (tranché)** : lorsque `instBucket.Busy`, la branche `IF instBucket.Busy` de `PRG_04 §3` écrit **seulement** `DriveRequest.{StartStop, Direction}` de M2 (reste en §3). La vitesse benne `15.0` codée en dur (`PRG_04:288`) est **retirée** (grep `15.0` dans `PRG_04` = 0 après T181-10) et remplacée par le palier `BucketJogStep` (voir Décision 4). `M2_BucketJogLimit` (ex-`M2_ForceSlowSpeed`) va dans l'agrégateur de clamp, **branche M2-only**.
- Cela maintient le producteur unique et évite de brider M1.

---

## 5. Décisions tranchées — visa humain (AC7c, AC8)

> Les six points ouverts du plan T181 §7 sont **tranchés ci-dessous**. Le visa humain (§7) est la
> signature finale ; chaque verdict est explicite et motivé, aucune case vide.

| # | Point ouvert | **Décision tranchée** | Justification / condition |
|---|---|---|---|
| **1** | Seuils de cadence `FB_WinchRateInterlock` (2 constantes) | **2 jeux de constantes locales indépendants** : safety **nu** côté instance `PRG_06` (barrière finale), safety **+ marge** côté instance `FB_Winch`. **Valeurs numériques non fixées au cadrage.** | Architecture figée (indépendance des 2 jeux, zéro GVL partagée — B2 §13 #4). Les **valeurs** exigent l'essai site + analyse sécurité (PLr) : la CI ne délivre pas la signature sécurité finale. |
| **2** | **D13** — `M2_SpeedStepTableActive` (`PRG_04:405-429`) | **SUPPRIMER** la reconstruction de table. | Le clamp unifié (`M2_BucketJogLimit` → `MaxStepUp/Down := 1`) s'applique aux **deux sens** (SEL `PRG_04:716-717`) → `StepNumber ≤ 1` → seuls les états P1 sont commandés. La reconstruction de table (tous paliers → P1) est **redondante** et constitue le 2ᵉ mécanisme divergent (D13). **Condition** : TC M2 jog (palier 1) + régression M1 (M1 reste à 4). Si un TC démontre une divergence, conserver avec justification en clair. |
| **3** | `ContactorsCheck.ContactorStuck` ré-alimentation | Ajouter un champ public `ContactorStuck` à `ST_SafetyWinch`, produit **exclusivement** par `FB_Safety_Winch` ; `PRG_04` réalimente `ContactorsCheck.ContactorStuck`. | G200 : un seul producteur. IHM/Troubleshooting conservent le champ. La cause interne `instCauses[1]` de `FB_Winch` est retirée en parallèle (D07). |
| **4** | Bornes benne + `SlowdownMaxStep` | `BucketJogStep : INT` (jog manuel/maint, **défaut palier 1**, configurable) · `BucketCycleMaxStep : INT` (semi-auto/cycle, **défaut 4-5**, PAS forcé lent) · `Config.SlowdownMaxStep` **configurable ≠ 1** (défaut à ajuster à l'essai site, 2 ou 3). Ces configs vivent dans **`ST_fbBucket_Config`** (propriété `FB_Bucket`), pas `ST_fbWinch_Cfg`. | **Résout `BucketJogSpeedPct`** : le jog est un **palier**, jamais un % (P1 : « le treuil = 1 palier, pas un % »). Le `15.0` % (`PRG_04:288`) est retiré. Le palier 1 en approche FDC fait caler le moteur (constat essai) → `SlowdownMaxStep` ≠ 1. |
| **5** | RETAIN table apprentissage | Structure `[axe][sens][charge][palier]` avec `Valid`, vitesse apprise, compteur échantillons. Chaque vitesse **finie, positive, dans une enveloppe configurée par palier**. Initialisation invalide, collecte **passive**. Validation complète charge/vide **avant** armement survitesse. Emplacement RETAIN en **fin** de `GVL_PERSISTENT` (mapping positionnel). | `FB_WinchSpeedLearning` collecteur passif (T181-15). Garde-fou de plausibilité obligatoire : valeur hors borne → cellule invalidée, pas d'armement. |
| **6** | Ordre d'import CODESYS | `_TYPES` communs/supervision → DUT treuil → sous-FB → `FB_Winch`/`FB_Safety_Winch` → `PRG_03/04/06` → `PRG_07`, `GVL_Troubleshooting`, IHM → SimBench. | Inclure `PRG_07` + `_TYPES` supervision (partagent `ST_WinchState` / `ST_SafetyWinch` modifiés). Import manuel + bundle/G200. |

### Récapitulatif des points explicitement demandés

| Point | Verdict |
|---|---|
| **D13** | Supprimer `M2_SpeedStepTableActive` (clamp unifié suffit) |
| **Rôle M2-only benne** | Clamp scindé commun (M1=M2) + M2-propre ; bridages benne jamais vus par M1 |
| **Règles Min/MaxStep** | `MaxStep := MIN(plafonds)`, `MinStep := MAX(planchers)`, plafond safety gagne, garde `LIMIT(1, Min, Max)` dans `FB_SpeedStep` ; cas 3+1 → 1 |
| **Producteur `MinStepDown`** | `FB_DiveSearch` (dans `PRG_03`), flux intra-cycle zéro latence, gaté par `DescentActive` |
| **Vitesse `BucketJogSpeedPct`** | **Rejeté** — remplacé par `BucketJogStep : INT` (palier, défaut 1) ; le `15.0` % est retiré |

---

## 6. Devoir d'alerte — écarts à signaler (non comblés par hypothèse)

| # | Écart | Décision / suite |
|---|---|---|
| **A1** | Le contrat AC7b nomme `Config.BucketJogSpeedPct` (vitesse %), en **contradiction** avec P1 (« le treuil = 1 palier, pas un % ») et `AF10_INTERFACE_TREUIL_CIBLE_T181.md` §3quater (`BucketJogStep : INT`). | **Tranché en faveur du palier** (`BucketJogStep`). Le contrat doit être amendé (`BucketJogSpeedPct` → `BucketJogStep`) — hors scope de ce cadrage (contrat non modifiable ici), signalé à l'orchestrateur. |
| **A2** | `Config.SlowdownMaxStep` vaut aujourd'hui `1` en dur (`GVL_PERSISTENT:136`, `FB_Winch.st:38`). Le palier 1 en approche FDC fait caler le moteur (constat essai). | Valeur par défaut à ajuster à l'essai site (2 ou 3), potentiellement distincte par sens/contexte. |
| **A3** | `FB_WinchRateInterlock` : les **valeurs** des 2 constantes ne sont pas fixées au cadrage. | Dépend de l'essai site + analyse sécurité (PLr). La CI ne délivre pas la signature sécurité finale. |
| **A4** | Le harnais `FB_TestHarness_PRG_04` est un stub simplifié (B4 §3.1). | Reconstruit en miroir fidèle de `PRG_04 §1-§8` (T181-00) ; gate d'égalité logique stub ↔ `PRG_04`. |

---

## 7. Conditions de sortie et arrêt

Avant T181-07/08/10/12/13, le **visa humain** doit valider les six lignes §5, en particulier :
les seuils de cadence (Décision 1), **D13** (Décision 2), la migration RETAIN (Décision 5) et le
palier de jog `BucketJogStep` (Décision 4). Cette note ne change aucun POU ni aucun DUT :
**STOP — validation humaine obligatoire.**

| Critère d'acceptation | Preuve |
|---|---|
| AC1 (DUT champ par champ) | §2 — tableau interface complet, revue nommage NC-xxx |
| AC2 (sources de clamp) | §3.1 — tableau ≥ 8 sources, aucune case vide |
| AC3 (précédence Min/Max) | §3.2 — pseudo-code + cas limite 3+1 → 1 |
| AC4 (producteur `MinStepDown`) | §4.1 — schéma de flux + latence (intra-cycle) |
| AC5 (contrat d'implémentation) | §3.2 — `MinStepNumber` sur `RequestedStep`, lissé |
| AC6 (matrice 8 producteurs) | §4.2 — matrice 8 lignes |
| AC7 (arbitrage unique) | §1 — localisation `PRG_04 §3` |
| AC7b (override benne) | §4.3 — tableau override + grep `15.0` = 0 après T181-10 |
| AC7c (D13) | §5 Décision 2 — verdict explicite, visa humain |
| AC8 (section AF-10) | `FB_Winch_v2.0.md` — diff relu par l'humain |
