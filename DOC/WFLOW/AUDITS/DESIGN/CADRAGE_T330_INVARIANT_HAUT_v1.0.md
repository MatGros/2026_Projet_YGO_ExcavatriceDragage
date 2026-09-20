# 📐 Cadrage T330 — Invariant entre position de référencement TOP et FDC logiciel haut

> 📌 Livrable **T330** (contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_HOMING_TOP_SOFT_LIMIT_INVARIANT.yaml`,
> criticité **C2**) · **ANALYSE ET CADRAGE UNIQUEMENT**.
> ⛔ **Aucune ligne de code automate, aucun type IHM, aucun `CODE_XML/`, aucun bundle, aucun réglage modifié.**
> Aucun commit, push, revert, nettoyage ou suppression.
>
> **Responsable principal** : `DSH01` · **Verrou** : 🔒 `T330` (voir `DOC/WFLOW/TASK_LOCKS.json`)
> **Date** : 2026-09-20 · **Reviews indépendantes** : 4 (automatisme, Safety, IHM, tests/CI), lecture seule.

---

## 🚦 0 · Verdict en une ligne

**`BLOCK` pour le passage à C3** — le cadrage est livré et les faits sont établis, mais **deux règles de
cohérence contradictoires coexistent déjà** dans le dépôt : le gate CI **G483** (AC2b) impose
`CfgTopSensorPos_M − CfgCableLimitAscent_M ≤ 1,0` alors que T330 impose `≥ 1,00 m`. Les deux ne sont
vraies **que si l'écart vaut exactement `1,00 m`** — c'est le cas des défauts actuels (8,5 / 7,5), donc
**G483 ne passe que par coïncidence**. Pire : **G483 est actuellement rouge** (`exit=1`, AC1) et son
fallback lit un **champ renommé disparu** ⇒ **aucune protection effective**. Aucune implémentation C3 ne
doit être engagée avant arbitrage humain de **Q1** et **Q2**.

> 📊 **Reviews indépendantes : 3 × `BLOCK` (automatisme, Safety, orchestrateur) · 1 × `ALERTE` (IHM) · 1 × `ALERTE` (tests/CI)**
> — 2 motifs de `BLOCK` de reviewers ont été **arbitrés en `ALERTE`** avec argumentation (§10.3, §E.5),
> et **1 erreur de MON analyse a été démentie par la review Safety puis corrigée** (§3-D, ERRATA).
> **16 questions** restent à trancher (§9) · **0 fichier `CODE/` modifié**.

---

## 🧭 1 · Alerte préalable — les noms de la commande et du contrat n'existent pas dans le code

| Nom employé (mission / contrat) | Nom **réellement déclaré** | Déclaration | Constat |
|---|---|---|---|
| `PositionHomingTop_M` | **`CfgTopSensorPos_M`** | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCfg.st:8` | ❌ n'existe pas |
| `PositionFdcLogicielHaut_M` | **`CfgCableLimitAscent_M`** | `CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st:21` | ❌ n'existe pas |
| `CableLimitAscent_M` (contrat AC1/AC2) | **`CfgCableLimitAscent_M`** | idem | ❌ préfixe `Cfg` amputé |
| `CableLimitAscent` | ⚠️ **existe** — mais c'est un **état BOOL**, pas un paramètre | `.../1_TREUILS_BENNE/ST_SafetyWinch.st:19` | 🪤 **piège homonyme** |

**Preuve** : `grep` exhaustif sur `CODE/` — les trois libellés de la mission/contrat ont **0 occurrence**.
Le nom sans `Cfg` (`CableLimitAscent`) désigne l'**état** « limite haute atteinte », produit par
`FB_WinchStateProjection.st:229`/`:256`. **Toute reformulation doit imposer le préfixe `Cfg`.**

**L'erreur propage** (à corriger en `fix:` documentaire, hors T330) :
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_...yaml:11,14`
- `DOC/WFLOW/TASKS.yaml:38,42`
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T291_B_AUTORITE_M1_LIMITES_HAUTES.yaml:77`
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T331_AX1_POSTURE_DIAGNOSTIC_REMISE.yaml:44`

> ⚠️ Conséquence directe : le critère **AC1** du contrat (« Les deux paramètres existants sont tracés… :
> `PositionHomingTop_M` et `CableLimitAscent_M` ») porte sur des identifiants **inexistants** ⇒ il est
> **infalsifiable**. Un agent qui le « valide » ne valide rien.

---

## 📋 2 · T330-A — Cartographie producteur → route → consommateur

### 2.1 Tableau des paramètres réels

| Donnée | Déclaration | Valeur actuelle | Unité | Producteur | Consommateurs | Modifiable IHM |
|---|---|---:|---|---|---|---|
| `CfgTopSensorPos_M` **M1** | `ST_WinchCfg.st:8` · persist `GVL_PERSISTENT.st:41` | **8,5** | m | `GVL_IHM.M1TreuilRetenue.Cfg` → pont `instCfgPersistBridgeWinchM1` (`PRG_07:140`) → `_WinchM1CfgPersist` | `PRG_02:601` (preset codeur M1) · `PRG_02:599` (cible homing) · `PRG_04:874` (`TopLimitM1_M` override) | ✅ **oui (maître)** |
| `CfgTopSensorPos_M` **M2** | `ST_WinchCfg.st:8` · persist `GVL_PERSISTENT.st:49` | 8,5 | m | ⚠️ **écrasé chaque scan** par `PRG_07:154-155` depuis M1 | `PRG_02:529` (`MachineHomingCfg.CfgTopHomingTarget_M`) · `PRG_02:655` (preset codeur M2) · `PRG_04:877` (`TopLimitM2_M` override) | ❌ **non réglable — miroir M1** |
| `CfgCableLimitAscent_M` | `ST_CommunCfg.st:21` · persist `GVL_PERSISTENT.st:145` | **7,5** | m | `GVL_IHM.Commun.Cfg` → pont `instCfgPersistBridgeCommun` (`PRG_07:182`) → `_CommunCfgPersist` | `PRG_04:873,876` (FDC actif) · `FB_WinchStateProjection:222,226` · `PRG_03:164,231` · `PRG_07:857` (diag) | ✅ **oui** |
| `WinchSlowdownDistanceTop_M` | `ST_CommunCfg.st:16` · persist `:142` | **0,5** | m | idem commun | `PRG_04:1417,1485` → `FB_Winch:173` (**zone de ralentissement**) | ✅ oui |
| `WinchSlowdownMaxStep` | `ST_CommunCfg.st:20` · persist `:144` | 1 | palier | idem commun | `FB_Winch:179` | ✅ oui |
| `WinchMaxStepAscent` / `Descent` | `ST_CommunCfg.st:14,15` · persist `:140,141` | 5 / 4 | palier | idem commun | `PRG_04:1210-1211` | ✅ oui |
| `M2_LimitShift` | local `PRG_04:212` · affecté `:824` | = `instBucket.ActiveOffsetM` (0 ouvert → 15,0 fermé) | m | `FB_Bucket` | `FB_WinchStateProjection:226` · `PRG_04:876-877` | ❌ dérivé |
| `LimitLegalDepthMinAllowed_M` | `ST_CommunCfg.st:11` · persist `:137` | −30,0 | m | idem commun | `PRG_04:684-685` · `PRG_03:60` · `PRG_07:189` | ✅ oui |
| `CfgCableLimitDescent_M` | `ST_WinchCfg.st:13` · persist `:46,54` | −50,0 | m | par axe | `PRG_04:684-688` · `FB_Safety_Winch:319,565` | ✅ oui |
| `CST_CycleInitWindowM` | `PRG_03:52` — **`VAR CONSTANT`** | **0,4** | m | — | `PRG_03:164` (posture départ cycle) | ❌ constante |
| `_TranslationMinHeightM1M2_M` | `GVL_PERSISTENT.st:93` | **6,0** | m | — | `PRG_05:137-138` (autorisation translation) | ❌ **cote en dur, non dérivée** |
| `TopLimitM1_M` / `TopLimitM2_M` | `PRG_04:247-248` · calculés `:872-877` | 7,5 nominal · 8,5 override N1 / bypass N2 | m | `PRG_04` | `FB_Safety_Winch:581` (via `:942,1011`) · `FB_Winch:173` (via `:1389,1463`) | ❌ dérivé |
| `CableLimitAscent` (état) | `ST_SafetyWinch.st:19` | — | BOOL | `FB_WinchStateProjection:229,256` | `PRG_03:162-163` · `PRG_07:696` · `FB_Hmi_BannerFormatter:656` | ❌ état |

### 2.2 Les 8 notions à ne JAMAIS confondre (exigence explicite de la mission)

| # | Notion | Nom réel | Preuve |
|---|---|---|---|
| 1 | **Position brute M1** | `EncoderM1.Measurement.CablePosM` | `FB_WinchStateProjection.st:87` |
| 2 | **Position brute M2** | `EncoderM2.Measurement.CablePosM` | `FB_WinchStateProjection.st:195` |
| 3 | **Position M2 corrigée (SÉCURITÉ)** | `CablePosM2_brut − instBucket.ActiveOffsetM` — ⚠️ **jamais matérialisée** comme variable ; n'existe qu'en équivalence algébrique dans les comparaisons | `PRG_04:817-819,824` ; `FB_WinchStateProjection.st:226` |
| 3bis | **Position M2 corrigée (AFFICHAGE)** | `BucketState.M2PositionCorrected := CablePosM2 − instBucket.DisplayOffsetM` | `PRG_04:1737` · `ST_BucketHMIState.st:26` |
| 3ter | **Écart M1/M2 corrigé** | `DeltaPositionCorrected_M := DeltaPosition_M − instBucket.OffsetTargetM` | `FB_Bucket.st:716` |
| 4 | **FDC logiciel d'exploitation** | `TopLimitM1_M` / `TopLimitM2_M` (nominal = `CfgCableLimitAscent_M` `[+ M2_LimitShift]`) | `PRG_04:872-877` |
| 5 | **Position de référencement au TOP** | `CfgTopSensorPos_M` | `ST_WinchCfg.st:8` |
| 6 | **État réel du capteur TOP** | `HwIn.Winch.M1M2_TopPositionFree_DI` (TRUE = zone haute **libre**) | `PRG_04:932,1001` · `G496:4` |
| 7 | **Limite basse de tambour** | `CfgCableLimitDescent_M` | `ST_WinchCfg.st:13` |
| 8 | **Limite légale de profondeur** | `LimitLegalDepthMinAllowed_M` | `ST_CommunCfg.st:11` |

> 🚨 **Point 3 — trois « positions M2 corrigées » avec TROIS offsets différents** :
> `DisplayOffsetM` (nominal, figé par état franc) pour l'**affichage** ; `ActiveOffsetM` (**pente bornée**
> `CST_OffsetSlewMPerScan = 0.08 m/scan`, `FB_Bucket.st:142`) pour les **comparaisons de sécurité** ;
> `OffsetTargetM` (instantané) pour l'**écart corrigé**. La position M2 **affichée** et la position M2
> **jugée par le FDC** n'utilisent donc **pas le même offset**. Conséquence : l'opérateur peut lire une
> position corrigée qui ne correspond pas à la grandeur réellement comparée à la limite. **À trancher
> avant C3** (voir §9 Q4).

### 2.3 🔴 Contradiction documentaire prouvée — M2 « indépendant » vs M2 « miroir »

| Source | Affirmation | Verdict |
|---|---|---|
| `CODE/M_MAIN/PRG_07_Supervision.st:150-155` | « M1 = MAITRE … on force donc **M2 = M1 en continu** (IHM + persistant) » | ✅ **c'est ce que fait le code** |
| `DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md:548` | « Les cibles homing … restent les réglages métier **indépendants M1/M2** » | ❌ **FAUX** |
| `DOC/AF/AF_Partie-09_...v2.4.md:459` | M2 reçoit sa **PROPRE** cible haute … « **jamais la config M1** » | ❌ **FAUX** |
| `DOC/AF/AF_Partie-09_...v2.4.md:429-430` | Cible dynamique M2 sourcée depuis `_WinchM2CfgPersist.CfgTopSensorPos_M` | ⚠️ vrai, mais ce champ **vaut toujours M1** ⇒ « mouflage distinct » annulé |
| `CODE/M_MAIN/PRG_02_Acquisition.st:525-528` | « Geometrie de mouflage benne differente -> **jamais la position M1** » | ❌ **FAUX** |

**Fait** : `_WinchM2CfgPersist.CfgTopSensorPos_M` **n'est jamais lu comme une valeur propre** — il est
réécrit depuis M1 **à chaque scan, sans condition** (`PRG_07:155`). Le champ `GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M`
est lui aussi écrasé (`:154`) ⇒ **toute saisie opérateur sur le champ M2 est perdue au scan suivant**
(IHM **et** NVRAM). C'est un « champ fantôme » : il s'affiche, il accepte la saisie, il ne fait rien.

> 🔎 **Réponse à la question T330-A** « position de référencement TOP M2, **si elle est distincte** » :
> elle **n'est pas distincte** dans le code actuel. Toute règle posée sur M2 doit partir de ce fait.

#### 2.3bis 🎯 Preuve DÉCISIVE — le code dit lui-même que M2 se référence **comme** M1

`CODE/G_CYCLE/FB_CycleMachineHoming.st:410-420` — **commentaire de conception, puis code** :

```pascal
// HX3 = referencement des AXES M1/M2 au vol, PAS la benne (GEL homing) : M1 et M2
// montent lies au meme capteur haut -> M2 se reference a la MEME position que M1
// (cible nominale = CfgTopHomingTarget_M). L'offset geometrique benne fermee
// (CfgOffsetClose_M) est applique par le COMMIT benne (HX5 -> FB_Bucket), pas au
// datum de l'axe. Cible dynamique (top + offset ~23 m) supprimee ici : elle creait
// un ecart apparent M1/M2 de ~15 m au preset -> FB_WinchSync SafeStop -> Fault.Latched.
M1Demand.UseDynamicTarget := FALSE;
M2Demand.UseDynamicTarget := FALSE;
M2Demand.DynamicTarget_M  := 0.0;
```

| Fait établi | Portée |
|---|---|
| « **M2 se référence à la MÊME position que M1** » | ✅ **décision de conception assumée**, écrite noir sur blanc |
| La **cible dynamique M2** (`+ OffsetCloseM`) a été **délibérément SUPPRIMÉE** | ⚠️ motif : elle créait un **écart apparent M1/M2 de ~15 m au preset → `FB_WinchSync` SafeStop → `Fault.Latched`** |
| ⇒ `CfgTopHomingTarget_M` est **alimenté mais jamais consommé** (`UseDynamicTarget := FALSE` en dur) | 🧟 **entrée morte** |

> 🚨 **Conséquence pour la spec et pour T330** : `AF_Partie-09_v2.4.md:459` (« M2 reçoit sa **PROPRE**
> cible haute configurée … `± OffsetClose_M` … **jamais la config M1 ni une position M1 live** ») est
> **doublement FAUX** :
> 1. `_WinchM2CfgPersist.CfgTopSensorPos_M` est **forcé = M1** chaque scan (`PRG_07:155`) ;
> 2. même si ce n'était pas le cas, le `UseDynamicTarget := FALSE` en dur **neutralise** toute cible
>    dynamique propre à M2 (`:418-420`).
>
> ⚠️ **Et la raison de cette suppression est un REX de sécurité** : la cible dynamique provoquait un
> **`SafeStop` synchro latché** au preset. ⇒ Toute tentative future de « rendre M2 distinct » **doit**
> repartir de ce REX, pas de la spec AF-09 — sinon on **réintroduit une régression connue**.
> 📌 **T330 ne demande ni ne propose aucun changement de M2** : ce constat est un **fait de cadrage**,
> signalé à l'orchestrateur (devoir d'alerte), pour que la future C3 ne s'appuie **pas** sur AF-09 v2.4.

### 2.4 Persistance et pont IHM

| Mécanisme | Preuve | Condition |
|---|---|---|
| Restauration au boot | `FB_CfgPersistBridge_WinchCfg.st:20-26` · `..._CommunCfg.st:20-26` | `IF NOT Hmi.Initialized → Hmi := Persist` (+ `JustRestored`) |
| Recopie IHM → NVRAM | mêmes ponts | **chaque scan, `Persist := Hmi`**, **aucune condition** de mode ni d'arrêt machine |
| Bornage de saisie | ❌ **aucun** | ni min/max, ni `LIMIT`, ni validation de plage sur ces 2 champs |
| Gel d'édition pendant mouvement / homing / cycle | ❌ **aucun** | — |
| Validation croisée `≥ 1,00 m` | ❌ **aucune** | `grep` exhaustif `CODE/` : seule co-occurrence = **commentaire** `PRG_04:867` |

### 2.5 Valeur réellement appliquée au moment du **preset codeur** (livrable T330-A)

| Maillon | Fait | Preuve |
|---|---|---|
| Cible retenue | `TargetPositionM := CfgTopSensorPosM` (mode nominal) — **capturée au déclenchement** | `FB_Encoder_Homing.st:216-223` |
| Déclencheur du **cycle machine** | ⚠️ **pas** le trigger « nominal » (`front Home` + `front capteur`) mais le trigger **unitaire** : `M1Demand.HomeReq`/`M2Demand.HomeReq`, émis sur le **front DESCENDANT** du capteur en `HX3_HOME_AXES` | `FB_CycleMachineHoming.st:504-522` · `PRG_02:596,650` · `FB_Encoder_Homing.st:209` (`UnitaryHomingTrigger`) |
| Conversion | `TargetPoints := REAL_TO_DINT(TargetPositionM × PointsPerRev / CableM_PerRev)` | `FB_Encoder_Homing.st:229` |
| Référence candidate | `PendingHomingRefRaw := RawPos − TargetPoints` | `FB_Encoder_Homing.st:230` |
| **Valeur écrite au codeur** | 🔴 **`PresetValue := RawPos`** — **preset NEUTRE, PAS le centre de plage** | `FB_Encoder_Homing.st:231` · `FB_Encoder_Abs.st:135,140` |
| Commit du datum | `Calib.HomingRefRaw := PendingHomingRefRaw` + `Homed := TRUE` (RETAIN `_CalibM1/_CalibM2`) | `FB_Encoder_Homing.st:263-270` |
| Position obtenue | `CablePosM := (RawPos − HomingRefRaw) × k` ⇒ au capteur = `CfgTopSensorPos_M` ✅ | `FB_Encoder_Scale.st:34` |
| Gel des consommateurs | `HomingLifecycle.Busy := PresetVerificationActive`, fenêtre `CST_PresetVerifyTime = 50 ms` | `FB_Encoder_Homing.st:110,241,289` |

> ✅ **Divergence DÉJÀ DOCUMENTÉE — ne pas la présenter comme une découverte** :
> `AF_Partie-09_v2.4.md:49-51` l'écrit explicitement : « *v2.4 : F09.01/F09.02/F09.08 — le code actuel
> (**preset neutre `PresetValue := RawPos`**, commit `73fa758d`) **ne satisfait pas** l'exigence
> centre-plage : **divergence spec/code ouverte**, correction planifiée (fiche
> `TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md`).* »
> ⇒ **hors périmètre T330**, mais **connu et tracé** — je l'ai vérifié pour éviter de le compter deux fois.

---

## 🧩 3 · T330-B — Matrice des modes (faits sourcés)

### A · Exploitation normale, axes référencés

| Attendu mission | Fait constaté | Preuve |
|---|---|---|
| Ralentissement avant le FDC selon config existante | ✅ Zone haute = `TopLimitM − WinchSlowdownDistanceTop_M` (**0,5 m**), palier plafonné à `WinchSlowdownMaxStep` (**1**) | `FB_Winch.st:173` · `:178-179` |
| Arrêt nominal au FDC logiciel haut | ✅ `AscentPermit := FALSE` si `CablePosM >= TopLimitM` (Homed ∧ ¬suspect ∧ ¬homing) | `FB_Safety_Winch.st:581` |
| Montée interdite au-dessus | ✅ idem — **neutralisation d'`AscentPermit`** | `FB_Safety_Winch.st:574-582` |
| Descente autorisée | ✅ `DescendPermit` **n'utilise jamais** `TopLimitM` ni le capteur TOP | `FB_Safety_Winch.st:563-572` |
| Aucun besoin d'atteindre le TOP | ✅ Le TOP n'est **jamais** une cible de cycle ; le FDC le précède de `Δ = 1,0 m` | `PRG_04:867` · `AF-10 §7.7` |

### B · Homing explicitement actif

| Question mission | Fait constaté | Preuve |
|---|---|---|
| Condition exacte autorisant la montée vers le TOP | `InReferencingMode` **exempte** `AscentPermit` du FDC logiciel **et** du capteur TOP | `FB_Safety_Winch.st:576,581` |
| Permis de homing | MAINT_N1/N2 **ET** (arrêt mécanique conjoint **OU** (`¬BtnHomingAtZero` ∧ `¬TopPositionFree_DI`)) — **OU** demande du cycle machine | `PRG_02:590-593` · `:643-646` |
| Vitesse / palier autorisé | Cycle GRAFCET `HX2_CLIMB` → `HX3_HOME_AXES`, timer `CfgTimeoutClimb` | `FB_CycleMachineHoming.st:186-188,422` |
| Arrêt au capteur | **Front** capteur, **au vol** : « capture au front, pas après arrêt confirmé » | `FB_Encoder_Homing.st:197,207` · `AF-09 §5:394` |
| Transaction de preset | `PresetValue := RawPos` ; `PendingHomingRefRaw := RawPos − TargetPoints` ; readback `CST_HomingVerifyToleranceM` | `FB_Encoder_Homing.st:229-233,249` |
| **Valeur de référence appliquée** | `TargetPositionM := CfgTopSensorPosM` (**nominal**) — cible **capturée au déclenchement** | `FB_Encoder_Homing.st:216-223` |
| Conditions d'abandon | `HXF_FAILED` (erreur axe, hors phase, timeout, perte de mode) | `FB_CycleMachineHoming.st:483-557` |
| Perte de capteur / datum en mouvement | `HomingLossLatched` → `MachineHomingLossSafeStop` → `ReHomingAckRequired` (**Reset conscient requis**) | `FB_CycleMachineHoming.st:282-297,353-355` |
| Non-redémarrage automatique | ✅ Levée sur **front `Reset`** uniquement ; re-homing obligatoire armé immédiatement | `FB_Modes.st:140-153` |
| Déclencheur réellement emprunté par le **cycle machine** | ⚠️ **trigger UNITAIRE**, émis sur le **front DESCENDANT** du capteur (`TopLostEdge.Q`) en `HX3_HOME_AXES` — **pas** le trigger « nominal » | `FB_CycleMachineHoming.st:511-515` · `FB_Encoder_Homing.st:209` |
| Gardes de temps | `CfgTimeoutClimb := T#120s` (HX2) · `CfgTimeoutHomeAxes := T#60s` (HX3) · `CST_SettleGrace := T#3s` | `ST_fbMachineHomingCycle_Cfg.st:18-19` · `FB_CycleMachineHoming.st:161` |
| Palier de montée | `CST_StepSlow := 1` (palier **1**) | `FB_CycleMachineHoming.st:162,478-481` |
| 🔴 **Comment la montée franchit réellement le FDC logiciel** | ⚠️ **Par un BYPASS de sécurité** : l'override qui relève la butée exige **MAINT_N1** (`PRG_04:845-848`) alors que le homing exige **MAINT_N2** ⇒ sur une machine **déjà référencée** (butée active à 7,5 m), le **seul** chemin de montée vers le TOP est le **bypass IHM latché** `Bypass.TopLimitSoftware` | `PRG_04:856,861,872-877` · `FB_CycleMachineHoming.st:464` · cartouche IHM `ST_WinchCmd.st:17-23` |
| ⛔ **`SelHomingApproachEnable` ne sert à RIEN pour franchir la butée** | Son commentaire déclare « **autorise le dépassement butée haute** pour homing » (`ST_CommunCfg.st:13`) — **mais** son effet réel est un **plafond palier 1** : `Auth.HomingApproachEnable := (Mode = MAINT_N2) AND SelHomingApproachEnable` → `FB_Winch.st:190-191` `ActiveMaxStep := 1`. ⇒ **aucun dépassement n'est autorisé** : le paramètre est un **placebo** au regard de son libellé | `ST_CommunCfg.st:13` vs `FB_Modes.st:344` · `FB_Winch.st:190-191` · `ST_fbWinch_DriveRequest.st:35` |

> ✅ **Captured target** : `TargetPositionM` n'est affecté **que** dans `IF HomingTrigger THEN`
> (`FB_Encoder_Homing.st:216-223`) et `HomingTrigger` exige `NOT PresetVerificationActive` (`:214`).
> ⇒ Une modification de `CfgTopSensorPos_M` **pendant** une transaction de homing en vol **ne retargete
> pas** le cycle en cours. Elle prend effet au cycle **suivant**.

### C · Non référencé, hors transaction de homing

| Question mission | Fait constaté | Preuve |
|---|---|---|
| Mouvements normaux interdits ? | ❌ **Non interdits, mais bridés** : plafond palier **1** sur **M1 ET M2**, **montée ET descente** (posture fail-safe T146 / ISO 13849) | `PRG_04:1226-1230` |
| Cycle automatique interdit ? | ⚠️ **Sélectionnable mais non progressif** : `HomingRequiredM1/M2` → cause « cycle non prêt », info **non bloquante** | `FB_Modes.st:155-161` |
| Mouvements de dégagement réellement disponibles | ✅ **Descente disponible** (palier 1) ; bornes basses et limite légale **actives** | `PRG_04:1228-1229` |
| Conditions pour demander un homing | MAINT_N1/N2 + (arrêt mécanique OU capteur haut atteint) — `BtnHomingAtZero` exempte la condition capteur | `PRG_02:590-592` |
| Si la position affichée est proche du TOP mais non qualifiée | ⚠️ **Rien** : `Homed=FALSE` ⇒ les protections logicielles sont **inertes** (`AF-10 §7.7`) ⇒ seul le plafond palier 1 protège | `AF_Partie-10 v2.1 §7.7:595-599` |

### D · Capteur TOP réellement sollicité

> 📌 **ERRATA (correction de l'orchestrateur, 2026-09-20)** — la **review Safety a démenti une première
> version de cette section**. J'avais écrit « aucun défaut déclenché *par* le TOP ; les surveillances
> Meca A/B/C/D/E sont indépendantes ». **C'ÉTAIT FAUX.** Vérification faite ligne à ligne :
> **la cause 11 « Méca D » est explicitement conditionnée au capteur TOP** (`FB_Safety_Winch.st:372-387`)
> et **escalade en `SafeStop` ET `PowerCutOff`**. Le tableau ci-dessous est corrigé.

| Distinction demandée | Fait constaté | Preuve |
|---|---|---|
| Coupure immédiate de la montée | ✅ `AscentPermit := FALSE` **live** (cause 5, non latchée), même scan, **sans rampe** → `RequestedStep := 0` → `ShapedStep := 0` immédiat | `FB_Safety_Winch.st:310-316,574-582` · `FB_Winch.st:216` · `FB_WinchStepShaper.st:45-47` |
| Réaction sur M1 / M2 | ✅ **Indépendante par axe** : deux instances `instSafetyWinchM1/M2` ; le capteur est **commun** | `PRG_04:932,1001` |
| `SafeStop` **direct** par la cause 5 | ❌ **NON** — la cause 5 est exclue de `CausesSafeStopActive` (traitée par le permis de sens) | `FB_Safety_Winch.st:512-521` |
| `PowerCutOff` **direct** par la cause 5 | ❌ **NON** — exclue de `CausesPowerCutOffActive` | `FB_Safety_Winch.st:523-525,584` |
| 🔴 **Défaut mécanique temporisé si mouvement/contacteurs persistent** | ✅ **OUI — ET IL EST CONDITIONNÉ AU TOP !** `UncommandedActiveD := NOT (BenneBusy OR BenneHoldStillActive) AND **NOT TopPositionSensor** AND NOT InReferencingMode AND NOT (contacteurs retombés AND frein fermé)` → `TonMecaD` **`PT := PostRampTimeout = T#3s`** → `MecaDFaultLatched` (**`Latching := TRUE`**) → **cause 11** → incluse dans `CausesSafeStopActive` **ET** `CausesPowerCutOffActive` ⇒ **escalade en AU après 3 s** si l'arrêt n'est pas confirmé au TOP | `FB_Safety_Winch.st:49,372-387,505,519,525` |
| Exception volontaire à cette escalade | Pendant une **manœuvre benne**, M1 peut être **volontairement** maintenu au FdC avec frein ouvert/transitionnel : exclu par `NOT (BenneBusy OR BenneHoldStillActive)` — **décision assumée et commentée** | `FB_Safety_Winch.st:373-375` |
| `Bypass` de cette escalade | ⚠️ `BypassMecaD` / `BypassSafety` la neutralisent (`PRG_04:859,864` — **sans gate de mode**, dérogation MES) | `FB_Safety_Winch.st:376` |
| Descente après disparition / acquittement | ✅ **`DescendPermit` préservé** : la descente n'est **jamais** conditionnée par le TOP ni par `TopLimitM` | `FB_Safety_Winch.st:563-572` |
| ⚠️ Après escalade MecaD | **`Reset` + réarmement AU explicites** — `RestartInhibit` **latché** sur ce chemin ⇒ **aucun redémarrage automatique** | `FB_WinchOutputInterlock.st:202-212` |

> 🎯 **Conclusion mode D (CORRIGÉE)** : le capteur TOP produit **deux réactions distinctes à deux échelles
> de temps** :
> 1. **immédiate** — retrait d'`AscentPermit` (cause 5, **non latchée**, réversible, ne touche ni
>    `SafeStop` ni `PowerCutOff`) ;
> 2. **temporisée à 3 s** — **cause 11 Méca D**, **latchée**, escalade en **`SafeStop` + `PowerCutOff`**
>    si les contacteurs/frein ne confirment pas l'arrêt au TOP, hors manœuvre benne.
>
> ⇒ Le TOP **n'est donc pas** « une simple neutralisation de permis » : il dispose bien d'une
> **escalade latchée vers l'AU**. Ce qui **reste vrai** : l'arrêt **immédiat** n'est ni un `SafeStop`
> classé, ni un `PowerCutOff`, et la **descente n'est jamais piégée**.

### E · Configuration incohérente — comportement **aujourd'hui** (avant tout code T330)

| Cas | Comportement réel constaté | Gravité |
|---|---|---|
| `Δ = CfgTopSensorPos_M − CfgCableLimitAscent_M < 1,00 m` (ex. 8,2 / 7,5) | **Aucun contrôle, aucun message.** Le homing pose la référence à 8,2 m ⇒ **la réserve n'est plus que 0,7 m** ; le FDC logiciel arrête toujours avant le TOP, mais avec une marge non maîtrisée | 🟠 |
| **`Δ = 0` (valeurs égales)** | La butée logicielle **coïncide** avec la position de référencement ⇒ **zéro course** entre FDC et TOP ; la zone de ralentissement (0,5 m sous `TopLimitM`) est **au-dessus** du FDC ⇒ **le ralentissement devient inopérant** | 🔴 |
| **`Δ < 0` (valeurs inversées, ex. 7,2 / 7,5)** | 🚨 **Le FDC logiciel est AU-DESSUS de la position de référencement TOP** ⇒ en exploitation normale, la montée **n'est plus arrêtée avant le TOP** : `CablePosM >= TopLimitM` (7,5) n'est atteint qu'**après** que la benne a franchi la référence de 7,2 m. **Seul le capteur TOP physique subsiste** — exactement le scénario que la règle veut interdire. Aggravant : la zone de ralentissement s'ouvre à `7,5 − 0,5 = 7,0 m`, **sous** le FDC ⇒ le treuil arrive sur le capteur **déjà ralenti**… mais rien ne garantit l'arrêt avant lui | 🔴🔴 **CRITIQUE** |
| **`Δ` exactement `= 1,00 m`** (défauts actuels) | Comportement nominal **correct** — **mais** c'est aussi le **seul** point où le gate CI `G483` passe (voir §6). Configuration **valide par coïncidence** | 🟠 |
| `Δ > 1,00 m` (ex. 9,0 / 7,5) | Réserve **plus grande** que nécessaire : le FDC arrête plus tôt ⇒ **perte de course utile**. ⚠️ **G483 AC2b échoue** (« arrivée capteur à pleine vitesse » en override N1). Aucune validation utilisateur ne prévient | 🟠 |
| Valeurs hors domaine (`0.0`, négatif, absurde) | ❌ **Aucune borne** sur ces deux champs. Le bornage `[−99 ; +99] m` n'existe **qu'au moment du preset** (`FB_Encoder_Homing.st:226-227`, `TargetOutOfRangeError`) — **pas** sur la valeur persistée | 🔴 |
| Modifié **machine déjà référencée** | ⚠️ **La référence codeur n'est PAS recalculée** (`HomingRefRaw` reste). Changer `CfgTopSensorPos_M` **après** homing ⇒ la position physique correspondant à la référence **ne vaut plus** la nouvelle valeur : **le FDC et le TOP se décalent silencieusement de l'écart**. Aucun re-homing n'est armé (l'armement ne couvre que `PositionLimitOverridden`, `PRG_04:897-899`) | 🔴 |
| Modifié **pendant un mouvement** | ⚠️ `TopLimitM1_M/M2_M` sont **recalculés chaque scan** (`PRG_04:872-877`) et consommés en temps réel ⇒ **la butée bouge instantanément**. Aucun gel, aucune capture. La **descente reste possible** (donc pas de piégeage en haut) | 🟠 |
| Modifié **pendant un homing** | ✅ Sans effet sur le cycle **en vol** (cible capturée, §3-B). ⚠️ Mais `PRG_07:154-155` propage **immédiatement** vers M2 ⇒ toute homing **ultérieur** part sur la nouvelle valeur | 🟡 |

> 🧨 **Le cas `Δ < 0` est le risque de sécurité n°1 de T330** : il place la butée logicielle
> **au-dessus** de la référence de homing, et **rien** dans le code ne l'empêche aujourd'hui.

#### E.1 — 🎯 Premier consommateur qui casse (chaîne tracée bout en bout)

L'effet n'est pas seulement « la protection devient inerte » : **le cycle automatique devient
impossible**. Chaîne vérifiée :

```
CfgCableLimitAscent_M > CfgTopSensorPos_M   (Δ < 0)
  ⇒ au capteur TOP physique, CablePosM = CfgTopSensorPos_M < CfgCableLimitAscent_M
  ⇒ CableLimitAscentM1Reached / M2Reached = FALSE   (FB_WinchStateProjection.st:219-226)
  ⇒ fenêtre de posture ABS(CablePosM1 − CfgCableLimitAscent_M) <= 0,4 m  FAUSSE si |Δ| > 0,4 m
  ⇒ CycleWinchesAtTopOk = FALSE                      (PRG_03_Modes_Cycle.st:161-165)
  ⇒ CycleInitPositionOk = FALSE                      (PRG_03:168, condition AX1_INIT)
  ⇒ AX1_INIT JAMAIS satisfait  ⇒  CYCLE SEMI_AUTO IMPOSSIBLE
```

| Fait | Preuve |
|---|---|
| `CycleWinchesAtTopOk` = (`CableLimitAscent` M1 **OU** M2 **OU** fenêtre `±0,4 m` sur M1) **ET** benne à état franc | `PRG_03_Modes_Cycle.st:161-165` |
| Fenêtre = `CST_CycleInitWindowM := 0,4` | `PRG_03:52` |
| Aucune borne ni validation sur les deux paramètres lors de la saisie | `FB_CfgPersistBridge_*` recopie sans contrôle |

> ⚠️ **Nuance** : c'est un **effet bénin comparé au franchissement du TOP** (le cycle refuse de démarrer,
> donc pas de mouvement dangereux). Mais c'est un **symptôme silencieux et non diagnostiqué** :
> l'opérateur voit un cycle qui « ne part pas » sans explication liée à la configuration.
> **Renforce l'OPTION 1** (refus explicite + message) : un refus au réglage vaut mieux qu'un cycle
> silencieusement impossible.

#### E.2 — ⚠️ Réserve **consommée à 0 m** sous override / bypass (par conception)

| Fait | Preuve |
|---|---|
| L'override du FDC logiciel exige **MAINT_N1** | `PRG_04:845-852` |
| Le homing (cycle machine) exige **MAINT_N2** | `PRG_02:590-593` · `FB_CycleMachineHoming.st:464` |
| ⇒ Une montée de homing sur machine **déjà référencée** ne peut passer que par le **bypass latché** `Bypass.TopLimitSoftware` | `PRG_04:855-861` |
| Sous override/bypass : `TopLimitM1_M := CfgTopSensorPos_M` ⇒ **réserve = 0 m** | `PRG_04:872-877` |
| Le capteur physique reste alors la **seule** butée sur les derniers `Δ` mètres | `PRG_04:838-844` |

> ⇒ La réserve `Δ` **n'est pas** une protection active dans les modes maintenance : elle est
> **entièrement consommée** dès qu'on relève la butée. **C'est exactement l'objet de la règle G483 AC2b**
> (§6.2) — et la raison pour laquelle les deux règles ne peuvent pas être fusionnées sans qualification de mode.

#### E.3 — 🚨 La « barrière dure non bypassable » est **contredite par le code**

| Affirmation dans le code | Réalité du code |
|---|---|
| `PRG_04:816` : « Le FDC haut **PHYSIQUE** reste la barriere **dure (non bypassable)**, FB_Safety_Winch:528-531 » | ❌ `FB_Safety_Winch.st:574-577` : `AscentPermit := NOT (((CauseTopLimitSwitchActive OR (NOT TopPositionSensor AND NOT InReferencingMode)) **AND NOT BypassTopLimitSwitch**) …)` ⇒ **le capteur physique EST bypassable** |
| `PRG_04:838` : « le capteur physique haut reste la butée dure » (à propos de l'override) | ✅ vrai **pour l'override N1** (qui n'ouvre jamais `BypassTopLimitSwitch`) — ⚠️ mais **faux** pour le bypass IHM dédié `Bypass.TopLimitSwitch` |
| `PRG_04:854-864` : bypass de la famille position **« SANS gate de mode — dérogation MES 2026 »** | ⚠️ `Bypass.TopLimitSwitch` est donc effectif **dans TOUS les modes, SEMI_AUTO inclus** |

> 🔴 **Conséquences pour T330** :
> 1. la doctrine « le TOP mécanique est le **dernier rempart matériel commun** » (mission §3) **ne tient
>    que si `Bypass.TopLimitSwitch` est désarmé** — ce qui n'est **pas** garanti par le code ;
> 2. `G496` verrouille la **polarité** de ce capteur, mais **aucun gate actif** ne verrouille son
>    **caractère non bypassable** ;
> 3. c'est la cause directe du **rouge de G483 AC1** (§6.1ter) : le gate *exigeait* ce gate de mode, la
>    dérogation MES l'a supprimé, et le gate n'a **jamais** été réconcilié.
>
> 🚫 **Hors périmètre T330** (T330 ne touche ni FDC, ni permis, ni homing) ⇒ **signalé, non corrigé.**

#### E.4 — 🔴 Le paramètre qui **justifie** la marge de `1,00 m` n'est **ni borné ni dans le périmètre T330**

**Apport de la review Safety, vérifié** : la marge de `1,00 m` entre le FDC logiciel et la position de
référencement TOP **n'a de sens que parce que** `WinchSlowdownDistanceTop_M` (0,5 m) doit absorber
l'arrêt + l'inertie avant le capteur physique sous override. Or :

| Fait | Preuve |
|---|---|
| `WinchSlowdownDistanceTop_M` est **IHM / RETAIN** | `ST_CommunCfg.st:16` · `GVL_PERSISTENT.st:142` |
| Sa documentation **autorise `0`** : « 0 = arrêt au seuil (m) » | `ST_CommunCfg.st:16` |
| Il **n'est pas borné** — aucun `LIMIT` (seuls 3 réglages IHM le sont dans tout `PRG_07`) | `PRG_07:189-197` · grep exhaustif |
| Sauf override/bypass, où la limite active devient `CfgTopSensorPos_M` | `PRG_04:872-877` |

> 🧨 **Conséquence** : régler cette bande à **`0`** **détruit silencieusement la justification de
> l'invariant** — le treuil arriverait alors sur le capteur physique **à pleine vitesse** sous override,
> alors même que la règle `Δ ≥ 1,00 m` serait « satisfaite ». **C'est très exactement le risque que la
> règle G483 AC2b visait** (§6.2) — et il montre que **borner `Δ` seul ne suffit pas** : la cohérence est
> un **triplet** `{CfgTopSensorPos_M, CfgCableLimitAscent_M, WinchSlowdownDistanceTop_M}`.
> ⛔ `WinchSlowdownDistanceTop_M` **n'était pas** dans le champ d'investigation initial de T330 →
> **intégré ici**, et posé en **Q15**.

#### E.5 — ⚠️ Reprise de montée au retour du permis, **sans nouveau geste**

| Fait | Preuve |
|---|---|
| La cause capteur TOP est **non latchée** (`Latching := FALSE`) | `FB_Safety_Winch.st:315` |
| **La cause 5** (permis) est exclue de `SafeStop` **et** de `PowerCutOff` — ⚠️ mais la **cause 11 Méca D**, elle, y est incluse et se latche (§3-D) | `FB_Safety_Winch.st:315,372-387,516-525` |
| `RestartInhibit` **n'est pas** posé par cette cause (il l'est sur « frein non confirmé ») | `FB_WinchOutputInterlock.st:504-507` |
| `RestartRequired` s'arme à `NOT MotorRequest` **et se purge après `T#500ms`** | `FB_WinchOutputInterlock.st:221-228` |
| `DeadTime` directionnel **se purge aussi pendant la pause** | `FB_WinchOutputInterlock.st:246-253` |
| La perte du permis coupe le palier **immédiatement** (`ShapedStep := 0`, sans rampe) | `FB_WinchStepShaper.st:45-47` |
| La reprise est **rampée en montée** (1 cran / `StepRampDelay`) | `FB_WinchStepShaper.st:50-55` |

> 🎯 **Arbitrage honnête (anti-Yes-Man, y compris envers la review Safety)** :
> la review Safety conclut que ce point **viole** le principe « jamais de redémarrage auto ». **Ce n'est
> pas exact au sens strict** : le principe projet vise les **défauts latchés** ; le capteur TOP est traité
> comme un **fin de course** (cause **live**, non latchée, au même titre que la limite basse câble), pour
> lequel « ça repart quand on quitte la zone » est le comportement **attendu**.
> **En revanche le fait est réel et mérite décision** : commande **maintenue** + disparition **transitoire**
> de la cause ⇒ la montée **reprend sans nouveau geste**. Et ce cas ne se produit **que** en configuration
> invalide (`Δ < 0`) ou sous override/bypass — c'est-à-dire **précisément là où la machine est proche du
> TOP mécanique**, ce que la mission qualifie d'**anormal**. → **Q10**

> ⚠️ **Nuance DÉCISIVE (apport de la review Safety, vérifiée)** : cette reprise automatique ne concerne
> **que le chemin du permis** (cause 5). Elle est **bornée à 3 secondes** : si l'arrêt n'est pas confirmé
> au TOP (contacteurs retombés **et** frein serré), la **cause 11 Méca D** se **latche** et escalade en
> **`SafeStop` + `PowerCutOff`** (§3-D), après quoi **`Reset` + réarmement AU sont exigés** —
> **aucun redémarrage automatique** (`FB_WinchOutputInterlock.st:202-212`).
> ⇒ Il n'existe donc **pas** de « reprise silencieuse infinie » : il y a une fenêtre de **3 s**, puis
> verrouillage. Cela **réduit** fortement la portée du constat — mais **ne le supprime pas**
> (rebond capteur < 3 s), et **ne dispense pas** de la décision Q10.

---

## 🧮 4 · T330-C — Formules dérivées (uniquement à partir des paramètres existants)

### 4.1 Réserve haute et invariant cible

```
ReserveTop_M = CfgTopSensorPos_M − CfgCableLimitAscent_M
Invariant cible : ReserveTop_M >= 1,00 m
```

⚠️ **Le `1,00 m` est une règle d'ingénierie**, pas un réglage : il doit vivre en **constante nommée**
(`VAR CONSTANT`, comme `CST_CycleInitWindowM` en `PRG_03:52`) et **jamais** comme champ IHM/RETAIN.
Ce **n'est pas** un « 8.50 / 7.50 codé en dur » au sens de l'interdit AC3.

### 4.2 Seuils dérivés à ±0,50 m

```
SeuilSurveillanceM2 = CfgCableLimitAscent_M + 0,50 m
SeuilProximiteTop   = CfgTopSensorPos_M     − 0,50 m
```

**Contraintes (confirmées)** : calculés depuis les 2 paramètres existants · **non persistants** ·
**jamais des champs IHM** · si une expression locale suffit, **aucune variable métier permanente**.
❌ Pas de `LIMIT()`, ❌ pas de clamp silencieux.

> ✅ **Pattern existant à réutiliser** : `CST_CycleInitWindowM : REAL := 0.4` en **`VAR CONSTANT`**
> (`PRG_03:51-53`), seuil dérivé de `CfgCableLimitAscent_M`, ni persistant ni IHM, consommé localement
> (`PRG_03:164`). C'est **exactement** le gabarit canonique pour les dérivés ±0,50 m.

> 🪤 **Collision numérique à ne pas confondre** : `WinchSlowdownDistanceTop_M = 0,5 m` (`ST_CommunCfg.st:16`)
> est **déjà** un 0,50 m, mais c'est la **largeur de la zone de ralentissement**, une notion **différente**
> des seuils de surveillance. Trois grandeurs distinctes convergent sur la valeur `8,0 m` quand
> `Δ = 1,00 m` (voir §4.3). À nommer sans ambiguïté.

### 4.3 ⭐ Cas particulier obligatoire — réserve **exactement** `1,00 m`

```
Si ReserveTop_M = 1,00 m :
    CfgCableLimitAscent_M + 0,50 = 7,50 + 0,50 = 8,00 m
    CfgTopSensorPos_M     − 0,50 = 8,50 − 0,50 = 8,00 m
    ⇒ LES DEUX SEUILS COÏNCIDENT
```

**Fonction de ce point médian** : il est **la bascule entre le domaine « FDC » et le domaine « TOP »**.
C'est la seule valeur où :
1. la borne « FDC logiciel + marge d'approche » et la borne « référence TOP − marge de sécurité » sont **confondues** ;
2. il n'existe **aucune bande morte** entre les deux seuils — l'espace de surveillance est **réduit à un point**.

> 🔴 **Risque à figer** : si les deux seuils sont implémentés par **deux expressions distinctes** avec des
> opérateurs `<` / `<=` non alignés, le point `8,000 m` produit **soit une bande morte d'un scan, soit un
> double déclenchement**. Le test qui doit le figer : balayer `CablePosM` à `7,999 / 8,000 / 8,001` et
> prouver **un seul** changement d'état, sans oscillation. **Recommandation : une seule expression dérivée**,
> jamais deux.

**Point médian et zone de ralentissement** (défauts actuels, `Δ = 1,00`) :
| Grandeur | Valeur | Nature |
|---|---|---|
| FDC logiciel nominal (`TopLimitM` hors override) | **7,50 m** | butée d'exploitation |
| Début de zone de ralentissement (`TopLimitM − 0,5`) | **7,00 m** | plafond palier 1 |
| **Point médian** (`FDC + 0,50` = `TOP − 0,50`) | **8,00 m** | ⚠️ **au-dessus du FDC ⇒ jamais atteint en exploitation normale** |
| `TopLimitM` **sous override N1** | **8,50 m** | = position de référencement TOP |
| Début de zone de ralentissement **sous override** | **8,00 m** | ⚠️ **c'est ici que le point médian devient actif** |
| Capteur TOP physique | ≈ 8,50 m | dernier rempart matériel |

> 🎯 **Lecture décisive** : le point médian `8,00 m` **ne peut être atteint qu'en override N1 / bypass N2**,
> car en exploitation nominale la montée est déjà interdite à `7,50 m`. En override, `8,00 m` est
> **exactement le début de la zone de ralentissement** (`TopLimitM − WinchSlowdownDistanceTop_M`).
> Les deux notions se **superposent** : le seuil de proximité TOP devient un **doublon** de la zone de
> ralentissement existante lorsque `Δ = 1,00 m` et que `WinchSlowdownDistanceTop_M = 0,50 m`.
> **À trancher** (voir §9 Q3) — sinon on crée deux mécanismes concurrents pour le même fait.

### 4.4 Si la réserve est supérieure à `1,00 m`

Aucune nouvelle doctrine n'est nécessaire — **comportement arithmétique direct** :
- `SeuilProximiteTop` (`TOP − 0,50`) **reste au-dessus** de `SeuilSurveillanceM2` (`FDC + 0,50`) ;
- l'écart entre les deux seuils vaut **exactement `ReserveTop_M − 1,00 m`** ;
- ⇒ une **bande de surveillance** apparaît, d'autant plus large que la réserve est grande.
- ⚠️ **Mais** `G483` AC2b refuse `Δ > 1,0 m` ⇒ **contradiction** (voir §6). Tant qu'elle n'est pas
  arbitrée, « réserve > 1,00 m » n'est **pas** une configuration acceptable par la CI.

**Cas **descente** — la descente de dégagement est-elle toujours possible ?** ✅ **Oui, indépendamment du
FDC haut** : `DescendPermit` (`FB_Safety_Winch.st:563-572`) n'utilise ni `TopLimitM`, ni le capteur TOP,
ni `CfgTopSensorPos_M`, ni `CfgCableLimitAscent_M`. ⚠️ **Nuance honnête** : la descente reste bloquée par
d'**autres** verrous — limite légale, limite câble basse, mou de câble, et verrou T249-A (chariot M3 hors
P1/Maintenance). « Descente possible » **ne veut donc pas dire** « descente toujours possible ».

### 4.5 Contraintes d'implémentation à cadrer **avant** C3 (remontées par la review IHM, vérifiées)

| # | Contrainte | Détail | Preuve |
|---|---|---|---|
| **C1** 🔴 | **Tolérance de comparaison REAL obligatoire** | La réserve est comparée à `1,00 m` sur des valeurs **saisies par l'utilisateur**. En flottant, `8,49 − 7,49` peut valoir `0,9999999` ⇒ **refus fantôme** sur une configuration voulue valide. Prévoir une **constante de tolérance explicite** (`CST_*`), jamais une comparaison sèche | `NAMING_CONVENTION.md:695-714` (préfixe `CST_`) |
| **C2** 🟠 | **Le `1,00 m` doit être une `CST_` nommée** | `CST_HomingTopMinMargin_M := 1.0` en `VAR CONSTANT`. Ce **n'est pas** une valeur « 8.50/7.50 en dur » interdite par AC3 : c'est une **règle d'ingénierie** | pattern existant : `CST_CycleInitWindowM` (`PRG_03:52`) |
| **C3** 🟠 | **Tension doctrinale à arbitrer** | `DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md:182` impose « 🔧 `Cfg` → Réglages. **Bornage PLC obligatoire** » — alors que T330 **interdit** `LIMIT()` / clamp silencieux. **Résolution proposée** : *borner = **refuser avec cause***, jamais corriger en silence. ⚠️ Les `LIMIT` existants (`PRG_07:195,197`) sont des clamps **silencieux** ⇒ incohérence **préexistante**, hors périmètre T330 | `AF-07:182` vs `PRG_07:195,197` |
| **C4** 🟡 | **Ordre de correction à énoncer à l'opérateur** | Le message doit être **impératif et ordonné** (« baisser d'abord le FDC logiciel, puis la position TOP ») : dans un sens le couple est refusé, dans l'autre la montée devient interdite (§E.1) | — |
| **C5** 🟡 | **La liste d'IHM est périmée — ne jamais s'en servir comme preuve** | `ihm_variables.txt` référence `WinchSlowdownDistance_M` (**renommé**) et `GVL_IHM.M*Treuil.Cfg.CfgCableLimitAscent_M` (**champ inexistant** dans `ST_WinchCfg`), et **omet** le vrai chemin `GVL_IHM.Commun.Cfg.CfgCableLimitAscent_M` | `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/ihm_variables.txt:10,231,362` |

#### Inventaire des valeurs **en dur** liées aux deux paramètres (état actuel, à ne pas étendre)

| Valeur | Emplacements | Nature |
|---|---|---|
| **`8.5`** ×4 | `ST_WinchCfg.st:8` · `GVL_PERSISTENT.st:41` (M1) · `:49` (M2) · `FB_Encoder_Homing.st:25` · `ST_fbWinch_DriveRequest.st:28` | défauts de type — **légitimes aux déclarations**, à ne pas répliquer ailleurs |
| **`7.5`** ×2 | `ST_CommunCfg.st:21` · `GVL_PERSISTENT.st:145` | idem |
| `2.0` | `PRG_04:890` (marge jog benne) | ⚠️ **littéral nu**, non couvert par AC3 |
| `6.0` | `GVL_PERSISTENT.st:93` (`_TranslationMinHeightM1M2_M`) | ⚠️ cote **dérivée**, non suivie (Q6) |
| `1.0` / `8.5` / `7.5` | `G483:169-170` | ⚠️ **fallbacks** du gate (champ fantôme) |

#### Entrées **mortes** / paramètres **trompeurs** repérés (signalements hors périmètre T330)

| Élément | Fait | Preuve |
|---|---|---|
| 🧟 `CableLimitM1AscentM` | **déclaré** (`// compatibilite interface`), **câblé** (`PRG_03:231`) et **jamais lu** dans le corps de `FB_CycleSemiAuto` ⇒ **variable morte** + **4ᵉ nom** pour la même notion | `FB_CycleSemiAuto.st:54` (unique occurrence) |
| 🧟 `CfgTopHomingTarget_M` | **alimenté** (`PRG_02:529`) mais **neutralisé** par `UseDynamicTarget := FALSE` en dur (§2.3bis) | `FB_CycleMachineHoming.st:418-420` |
| ⚠️ `SelHomingApproachEnable` | libellé « **autorise le dépassement butée haute pour homing** » — effet réel = **plafond palier 1** ⇒ **placebo** au regard de son libellé (mode B) | `ST_CommunCfg.st:13` vs `FB_Winch.st:190-191` |
| ⚠️ `CfgTopLimitM` / `Idx321_CfgTopLimitM` | publiés comme « limite haute **effective active** » mais reçoivent la valeur **nominale** ⇒ **diagnostic trompeur** en override/bypass (Q9) | `PRG_07:857` · `FB_TroubleshootingView.st:111` |

> 📌 **Duplication de la cote TOP** : `CfgTopSensorPos_M` est déclaré **1×**, **instancié 2×**
> (`GVL_IHM` M1/M2), **persisté 2×**, **+ défauts locaux** dans `FB_Encoder_Homing.st:25` et
> `ST_fbWinch_DriveRequest.st:28` ⇒ **jusqu'à 5 définitions** de la même grandeur physique.

---

## ⚖️ 5 · T330-D — Configuration invalide : OPTION 1 vs OPTION 2

### 5.1 Comparaison

| Critère | **OPTION 1** — refus du réglage | **OPTION 2** — accepté mais déclaré invalide |
|---|---|---|
| Mécanisme | Valeur refusée, **dernière config valide conservée**, diagnostic explicite | Valeurs **conservées** pour correction, état invalidé |
| Comportement au démarrage | NVRAM **toujours valide** ⇒ rien à armer | État invalide **à armer depuis la NVRAM** ⇒ logique de boot à écrire |
| Modification IHM **à l'arrêt** | ✅ refus + champ réécrit + message | valeurs persistées |
| Modification IHM **pendant mouvement** | ✅ refus sur la **valeur** (aucun gel du *moment* nécessaire) | ⚠️ l'invalidité apparaît en cours de mouvement ⇒ montée neutralisée **en vol** |
| Modification **pendant homing** | ✅ homing sur valeur valide | ⚠️ homing sur valeur invalide (cible capturée, mais `TopLimitM` recalculé) |
| Machine **référencée** | ✅ inchangé | ⚠️ état invalide **avec** référence codeur encore valide ⇒ incohérence persistante |
| Machine **non référencée** | ✅ inchangé | ⚠️ cumul avec le plafond palier 1 (T146) |
| **Possibilité de descendre** | ✅ préservée **par construction** | ⚠️ **à préserver explicitement** |
| Diagnostic opérateur | Refus immédiat, **message ciblé** | État persistant + message permanent |
| Acquittement | **Aucun** (warning auto-retombant) | **Latch à décider** (nouveau classement de cause) |
| Persistance | Valeur valide uniquement | ⚠️ **une config invalide est persistée** ⇒ survit aux coupures |
| **Risque de redémarrage automatique** | ✅ **nul** | 🔴 **réel** : corriger le 2ᵉ champ **ré-arme sans geste conscient** |
| Champs IHM/RETAIN neufs | ✅ **0** — conforme AC3 | ❌ **≥ 1 booléen d'état** ⇒ **viole AC3** |
| Compatibilité patterns existants | ✅ `Refus + motif` déjà modélisé (`ModeChangeBlockReason`, `FB_Hmi_BannerFormatter.st:36-37,359`) | ❌ **aucun pattern existant** pour un « Cfg accepté mais invalide » |
| Coût / réversibilité | Faible, localisé avant la persistance | Élevé : nouveau concept d'état + latch + boot |

### 5.2 🎯 Recommandation argumentée : **OPTION 1**, avec traitement explicite du cas dégénéré

**Pourquoi OPTION 1**
1. **Seule option compatible AC3** (« aucune nouvelle cote, variable persistante ou réglage IHM de FDC ») :
   l'OPTION 2 exige **au minimum un booléen d'état** ⇒ violation directe du critère contractuel.
2. **Fail-safe par construction** : la NVRAM ne contient **jamais** de configuration invalide ⇒ il n'existe
   aucun état dégradé à armer, à acquitter, ni à faire survivre à une coupure.
3. **Zéro risque de redémarrage automatique** : c'est le principe non négociable du projet
   (« Jamais de redémarrage auto après défaut », `AGENTS.md`). L'OPTION 2 le met en tension.
4. **Cohérente avec les patterns existants** : le projet modélise déjà « refus + motif » et non
   « acceptation dégradée ».
5. **Point d'insertion propre** : le contrôle se pose **avant tout pont de persistance**
   (`PRG_07_Supervision.st`, **avant la ligne 140**) — c'est le **producteur unique** des deux valeurs, et
   le programme y borne déjà d'autres `Cfg` (`:189-197`). Plus loin dans le scan, on ne peut **plus**
   refuser la persistance.

**Cas dégénéré à traiter (sinon l'option est incomplète)** — *une NVRAM peut **déjà** contenir une
configuration invalide* (réglage manuel antérieur, restauration, flash d'une ancienne version). Ce cas
n'est pas couvert par un « refus » :
- l'état invalide doit être **dérivé, non persistant** (aucun champ neuf) ;
- `AscentPermit` tombe **naturellement** si `TopLimitM` dépasse la position réelle — mais **pas** de façon
  garantie (cas `Δ > 1,00`) ⇒ **le diagnostic explicite est indispensable** ;
- la **descente doit rester disponible** ;
- **aucune reprise automatique** après correction : geste conscient requis.

**⚠️ Vigilance IHM** : sans message, un refus silencieux est **indiscernable d'un widget mort** — c'est
**exactement** le piège que constitue aujourd'hui le champ M2 (écrasé sans aucune indication, §2.3).

> 🚦 **L'orchestrateur et l'humain tranchent avant toute implémentation C3.** T330 ne décide pas.

### 5.3 🔄 Auto-challenge de la recommandation (la review Safety a challengé **mon** argument n°1)

La review Safety objecte — **à raison sur le fond technique** — deux points qui affaiblissent l'OPTION 1
telle que je l'avais argumentée. Je les intègre au lieu de les écarter :

| Mon argument initial | Objection Safety (vérifiée) | Statut |
|---|---|---|
| « OPTION 2 exige **≥ 1 champ neuf** ⇒ viole AC3 » | ⚠️ **Partiellement faux** : l'état invalide peut être porté par un champ **existant** — `_MaintM1HomingRequired` / `_MaintM2HomingRequired` (`GVL_PERSISTENT.st:182-183`), déjà armés par `FB_Modes`, **déjà audités par G483 AC6/AC7/AC8**, et qui interdisent déjà SEMI_AUTO | **Argument AFFAIBLI** — l'OPTION 2 est *techniquement* réalisable sans champ neuf. ⚠️ **Mais** cela **confondrait deux notions** (« re-homing requis » ≠ « configuration invalide ») ⇒ violation **NC-090** (« 1 notion = 1 nom ») et **diagnostic indiscernable**. → à trancher (**Q1/Q2**) |
| « OPTION 1 est fail-safe par construction : la NVRAM est toujours valide » | ⚠️ **Faux pour une NVRAM DÉJÀ invalide** (réglage manuel antérieur, restauration RETAIN, download) : une validation **à l'écriture** ne couvre **pas** ce cas. **Avantage décisif de l'OPTION 2** : elle contrôle **à la lecture / au boot** | **Argument AFFAIBLI** — c'est pourquoi mon §5.2 prévoyait **déjà** un « cas dégénéré » traité par un **contrôle dérivé non persistant**… qui **est** le mécanisme de l'OPTION 2 |

> 🎯 **Synthèse honnête — ma recommandation converge en réalité vers un HYBRIDE**, et l'apport de la
> review Safety le rend explicite :
>
> | Volet | Mécanisme | Origine |
> |---|---|---|
> | **A. Refus à l'écriture** — la config invalide ne peut **jamais** entrer dans la NVRAM | blocage avant tout pont de persistance (`PRG_07`, avant `:140`) | **OPTION 1** |
> | **B. Déclaration à la lecture** — si la NVRAM est **déjà** invalide, l'état est **déclaré** invalide (dérivé, **non persistant**) | condition calculée en ligne, `AscentPermit` tombe naturellement, **descente préservée** | **OPTION 2** (mécanisme) |
> | **C. Jamais de gate de validité sur `DescendPermit`** | `FB_Safety_Winch.st:563-572` reste **inchangé** | sécurité des deux options |
> | **D. Transition invalide → valide sur geste explicite uniquement** | aucun réarmement automatique | doctrine projet |
>
> ⛔ **Piège logique identifié par la review Safety, à contractualiser** : si l'invalidité vient d'une
> cote **inversée**, le homing re-presettera l'axe **avec la même mauvaise cote** ⇒ il **fait sortir de
> l'état invalide sans corriger la cause**. La règle doit donc **interdire au homing de lever** l'état
> invalide : **seul un changement de paramètre cohérent** le lève. Sans cela, on crée une **boucle de
> sortie fausse** — et c'est le point le plus subtil de tout le volet T330-D.
>
> ✅ **Conclusion** : l'**OPTION 1** reste ma recommandation pour le **volet A** (refus), mais elle **doit**
> être complétée par le **volet B** — sinon elle laisse passer le cas des machines **déjà** en service avec
> une NVRAM incohérente. Les deux reviewers (IHM : « OPTION 1 » ; Safety : « OPTION 2 bornée »)
> **convergent en fait vers ce hybride**. → **Q2**, à l'humain de trancher.

---

## 🚨 6 · Conflit bloquant CI ↔ T330 — le gate G483 impose la règle **inverse**

**Fait vérifié personnellement** — `TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py:164-175` :

```python
# AC2b — invariant de configuration : la course d'override reste couverte par le ralentissement.
delta = value("CfgTopSensorPos_M", 8.5) - value("CfgCableLimitAscent_M", 7.5)
band  = value("WinchSlowdownDistance_M", 1.0)
if delta > band + 1e-6:
    errors.append(f"AC2b … = {delta} m > WinchSlowdownDistance_M = {band} m : "
                  "sous override, le treuil arrive sur le capteur physique sans ralentissement")
```

| | Règle | Valeur |
|---|---|---|
| **T330** (cible) | `CfgTopSensorPos_M − CfgCableLimitAscent_M` **≥ 1,00 m** | 8,5 − 7,5 = **1,00** → *limite exacte* |
| **G483 AC2b** (CI active) | `CfgTopSensorPos_M − CfgCableLimitAscent_M` **≤ `band`** | `band = 1,0` → **1,00** → *limite exacte* |

> 🔴 **Les deux règles ne sont simultanément satisfaites QUE si l'écart vaut exactement `1,00 m`.**
> Or AC2 exige précisément de traiter « les cas de valeurs utilisateur modifiées » :
> - `CfgTopSensorPos_M := 9,0` ⇒ T330 ✅ mais **G483 échoue** ;
> - `CfgTopSensorPos_M := 8,2` ⇒ G483 ✅ mais **T330 est violé**.
> **Ce conflit est le risque n°1 du cadrage T330.**

### 6.1 Aggravant — `band` lit un champ **fantôme** : G483 ne passe que par accident

`G483:170` lit `WinchSlowdownDistance_M`. **Ce champ n'existe nulle part** dans `CODE/` (vérifié :
recherche du nom exact ⇒ **0 occurrence**). Les vrais champs sont :

| Champ réel | Déclaration | Valeur |
|---|---|---|
| `WinchSlowdownDistanceTop_M` | `ST_CommunCfg.st:16` · `GVL_PERSISTENT.st:142` | **0,5** |
| `WinchSlowdownDistanceBottom_M` | `ST_CommunCfg.st:17` · `GVL_PERSISTENT.st:143` | 1,0 |

La regex `WinchSlowdownDistance_M\s*:=\s*(…)` **ne matche ni l'un ni l'autre** ⇒ `value()` retombe
silencieusement sur le défaut codé en dur **`1.0`**.

> 🧨 **Conséquence** : si le nom était lu correctement, `band = 0,5` et **G483 AC2b échouerait
> AUJOURD'HUI sur la configuration par défaut du projet** (`1,0 > 0,5`). Avec la correction du nom,
> G483 exigerait `Δ ≤ 0,5 m`, ce qui est **mutuellement exclusif** avec `Δ ≥ 1,00 m`.
> **Aucun `Δ` ne satisferait alors les deux règles.**

### 6.1bis Origine de la divergence — régression de renommage **prouvée**

| Étape | Fait | Preuve |
|---|---|---|
| Historique | Le champ s'appelait **`WinchSlowdownDistance_M := 1.0`** — G483 et la règle `Δ ≤ band` étaient alors **cohérents** avec `Δ = 1,0` | `DOC/STDS/AUDIT_STRUCTS_MAPPING_20260827.md:81` |
| Aujourd'hui | Le champ a été **renommé/scindé** en `WinchSlowdownDistanceTop_M := 0,5` **et** `WinchSlowdownDistanceBottom_M := 1,0` | `CODE/GVL_PERSISTENT.st:142-143` |
| Conséquence | **G483 n'a pas suivi** : il lit l'ancien nom, retombe sur `1.0` (l'ancienne valeur) et **passe** sur des données qui ne le satisfont plus (`0,5`) | `G483:170` |

> ⇒ **Ce n'est pas un conflit doctrinal, c'est une régression de renommage non propagée.**
> La règle `Δ ≤ band` **était** satisfaite quand la bande valait `1,0 m` ; réduire la bande à `0,5 m`
> a **silencieusement** invalidé l'invariant. C'est un cas d'école du risque visé par T330 (§4.4).

### 6.1ter 🚨 **G483 est actuellement ROUGE** — preuve par exécution

```
$ python TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py
[G483] FAIL — matrice de maintenance N1/N2 :
  - AC1 bypass non gaté par MAINT_N2 : BypassM1TopLimitSwitchEff := ...
  - AC1 bypass non gaté par MAINT_N2 : BypassM2TopLimitSwitchEff := ...
  - AC1 seulement 10 affectations Bypass* gâtées (attendu >= 30)
  - AC1b MaintN2 ne dérive pas de PRG_03_Modes_Cycle.Data.Auth.Mode (= E_Mode.MAINT_N2)
[exit=1]
```

**Faits établis par cette exécution (lecture seule, aucun artefact écrit)** :
1. ❌ **G483 échoue aujourd'hui sur AC1** — cause : la **dérogation MES septembre 2026**
   (« bypass effectif sans conditionnement de mode », assumée et documentée en `PRG_04:830-833`),
   **jamais répercutée dans le gate**.
2. ⚠️ **AC2b n'apparaît PAS dans les erreurs** ⇒ il **passe**, mais **uniquement** grâce au fallback
   périmé `1.0` (confirme §6.1).
3. 🔴 **G483 est enregistré au palier C sans allowlist ni tolérance** (`run_all_gates.py:134`) ⇒
   **la suite « fin de lot » est actuellement ROUGE**. Le gate ne protège donc **rien** aujourd'hui —
   et sa règle AC2b est à la fois **périmée** et **non exécutée utilement**.

### 6.2 🎯 Les deux règles ne gouvernent PAS le même objet — clé de l'arbitrage Q1

| | Règle T330 | Règle G483 AC2b |
|---|---|---|
| Objet | **Réserve nominale** entre le FDC d'exploitation et la référence de homing | **Vitesse de parcours** de la course d'override N1 / bypass N2 |
| Situation visée | Exploitation normale : le FDC doit arrêter **avant** le TOP avec une marge | Override : `TopLimitM` est relevé **à** `CfgTopSensorPos_M` ⇒ la course supplémentaire vaut **exactement `Δ`** |
| Nature | Sécurité de **positionnement** | Sécurité de **vitesse** (ne pas arriver sur le capteur à pleine vitesse) |
| Sens | `Δ` **grand** est sûr | `Δ` **petit** est sûr |

> 🧠 **Elles ne sont pas contradictoires dans l'intention, mais incompatibles dans la formulation** :
> toutes deux s'expriment comme une borne sur le **même** `Δ`, sans qualifier le mode.

**Le fait décisif apporté par la review automatisme** : l'override exige **MAINT_N1** (`PRG_04:845-848`)
alors que le homing exige **MAINT_N2** ⇒ **la montée de homing d'une machine déjà référencée ne passe que
par le bypass latché `Bypass.TopLimitSoftware`**. Sous ce bypass, `TopLimitM = CfgTopSensorPos_M` ⇒
**la réserve est consommée à 0 m par conception** : seul le **capteur physique** subsiste dans les
derniers `Δ` mètres. C'est **précisément** le risque que G483 AC2b voulait couvrir.

**Options d'arbitrage (à trancher — Q1)** :
| Option | Contenu | Effet |
|---|---|---|
| **A** | Conserver `Δ ≥ 1,00 m` (T330) **et** relever `WinchSlowdownDistanceTop_M` à `≥ 1,00 m` | ✅ Restaure la cohérence historique (`band = Δ`), ✅ préserve la réserve nominale, ⚠️ ralentit plus tôt en exploitation |
| **B** | Conserver `Δ ≥ 1,00 m` et **requalifier AC2b** (la bande ne couvre que les derniers `band` m, pas toute la course d'override) | ✅ Simple, ⚠️ assume l'arrivée plus rapide sur le capteur en override N1 — **décision Safety** |
| **C** | Borner `Δ` dans un **intervalle** (`1,00 ≤ Δ ≤ band`) et aligner `band` | ✅ Une seule règle, ⚠️ nécessite `band ≥ 1,00` ⇒ revient à **A** |

> 🚦 **Recommandation de l'orchestrateur** : **Option A** — elle réconcilie les deux règles **sans
> supprimer aucune protection** et sans introduire de nouveau paramètre. Mais **c'est une décision
> Safety humaine**, et elle touche `WinchSlowdownDistanceTop_M` (paramètre IHM) ⇒ **hors périmètre T330**.

### 6.3 Autres constats d'outillage (relevés par la review CI, vérifiés)

| Constat | Preuve |
|---|---|
| **Aucun gate anti-« nombre magique »** n'existe | `grep` sur `TOOLS/AGENT_WORKFLOW/scripts/*.py` ⇒ 0 hit |
| `FB_WinchStateProjection` : **0 test, 0 entrée registre** — alors qu'il produit les faits de sécurité `CableLimitAscentM1Reached/M2Reached` | `registry.yaml` (seul `FB_Winch` présent) · `FB_WinchStateProjection.st:219-226` |
| La butée logicielle (`CablePosM >= TopLimitM ⇒ AscentPermit=FALSE`) n'est **jamais** exercée par un test (`CablePosM` max = 6,0 ; `TopLimitM := 8.5`) | `test_fb_safety_winch.st:221-241` |
| `CfgCableLimitAscent_M` : **0 occurrence** dans les tests ; `7.5` **dupliqué** dans le harnais | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_04.st:34` |
| `G490_check_ihm_bindings.py` **absent de `PLANS`** ⇒ jamais exécuté | `run_all_gates.py:92-150` |
| `G499` **déjà attribué** (T289) alors que T291-B le réclame | `run_all_gates.py:144` vs `T291_B:49` |
| « 21 gates » **périmé** | `run_all_gates.py` : **50** entrées `PLANS`, 47 par défaut |
| ⚠️ `GUIDE_GATES_ET_TESTS` : chemin cité `DOC/STDS/GUIDE_GATES_ET_TESTS.md` **inexistant** | réel : `DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md` |

---

## 🔗 7 · Interaction avec T291-B (tâche parallèle — 🔒 `AGY01`)

### 7.1 Périmètre respecté

| Règle mission | Respect |
|---|---|
| Lire les interfaces nécessaires en **lecture seule** | ✅ |
| Ne modifier **aucun** fichier de T291-B | ✅ (aucun fichier modifié hors documentation T330) |
| Ne pas présumer la position M2 corrigée fiable | ✅ — §2.2 montre **3 offsets distincts** et une continuité **non prouvée** |
| Conditionner tout futur contrôle M2 à la validation T291-B B1 | ✅ — voir §7.3 |
| Identifier les fichiers communs | ✅ — §7.2 |
| Ne proposer **aucun** changement de FDC M2 | ✅ |

### 7.2 Fichiers communs aux deux lots (risque de conflit d'édition)

| Fichier | T330 (futur C3) | T291-B | Risque |
|---|---|---|---|
| `CODE/M_MAIN/PRG_07_Supervision.st` | point d'insertion de la vérification (**avant `:140`**) + miroir M2 `:154-155` | lecture de la config M2 | 🟠 **élevé** — même fichier, même région |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` §5-0 `:835-899` | lecture (`TopLimitM1_M/M2_M`) | **autorité M1 en Both** + exception jog `+ 2.0` (`:888-891`) | 🔴 **critique** — `TopLimitM*_M` est le cœur des deux lots |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:581` | lecture (`AscentPermit`) | garde-fou M2 | 🟠 |
| `CODE/H_TREUILS_BENNE/FB_Winch.st:173` | zone de ralentissement (dérive de `TopLimitM` **actif**) | profil de vitesse M1→M2 | 🟠 |
| `DOC/WFLOW/TASKS.yaml` | bloc T330 | bloc T291-B (modifié par AGY01) | 🟡 maîtrisé — blocs distincts |
| `DOC/WFLOW/CONTRACTS/*.yaml` | contrat T330 | contrat T291-B (`:24,:77`) | 🟡 documentaire |

> ✅ **Aucun fichier de T291-B n'a été modifié par T330.** Le diff non commité de `TASKS.yaml`
> (mise à jour T291-B par AGY01) a été **préservé intégralement** — vérifié.

### 7.3 🥊 Divergence entre reviewers — **arbitrage de l'orchestrateur**

| Reviewer | Position |
|---|---|
| **CI** | L'invariant T330 sur M2 **dépend** de T291-B : `FB_WinchStateProjection.st:226` compare `CablePosM2` **brute** à `CfgCableLimitAscent_M + M2_LimitShift` avec `M2_LimitShift := instBucket.ActiveOffsetM` (`PRG_04:824`), **dont la continuité n'est pas prouvée** ⇒ grandeur non qualifiée |
| **IHM** | L'invariant est **indépendant** : `M2_LimitShift` est injecté **à l'identique dans les deux branches** du `SEL` (`PRG_04:875-877`) ⇒ **le décalage s'annule dans la marge** ⇒ vérifiable sur les valeurs de config **brutes** |

**🎯 Arbitrage (vérifié sur les sources)** : **les deux ont raison, sur deux objets différents.**

1. **L'invariant de CONFIGURATION (`Δ ≥ 1,00 m`) est bien indépendant de la géométrie M2.** Preuve
   algébrique : la comparaison M2 s'écrit, dans les deux branches du `SEL`,
   `CablePosM2_brut ≥ LIMITE + ActiveOffsetM`, ce qui équivaut à
   `CablePosM2_brut − ActiveOffsetM ≥ LIMITE`. `ActiveOffsetM` étant **le même** des deux côtés,
   la marge vaut `(CfgTopSensorPos_M + ActiveOffsetM) − (CfgCableLimitAscent_M + ActiveOffsetM) = Δ`.
   ⇒ **`ActiveOffsetM` s'annule** : T330 peut figer l'invariant **maintenant**, sans attendre T291-B. ✅
2. **En revanche, tout seuil DÉRIVÉ à ±0,50 m surveillé sur M2 est bien conditionné à T291-B B1.**
   Une position M2 corrigée **discontinue** (`ActiveOffsetM` à pente bornée mais `DisplayOffsetM`/états
   francs qui basculent de 15,0 m) franchirait un seuil fixe de façon **spurieuse** — c'est exactement le
   REX 2026-09-04 (« faux déclenchement cable ascent limite ») décrit en `PRG_04:817-823`.
   ⇒ **Les gardes ±0,50 m sur M2 restent conditionnés à la validation T291-B B1.** ✅

> 📌 **Formulation à retenir pour C3** : *l'invariant est figé sur les valeurs de configuration ; la
> surveillance dérivée M2 attend B1.*

#### ⚠️ Réserve ajoutée après la review automatisme — mon arbitrage ne vaut que pour la formule **ACTUELLE**

La review automatisme objecte — **à raison** — que `T291-B` ne se contente pas d'ajouter une marge : ses
**AC3/AC4** (« M1 seul devient l'autorité nominale », « M1 et M2 reçoivent le même palier en Both »)
**changent la FORMULE de comparaison M2 elle-même** (`PRG_04:875-877`, `FB_WinchStateProjection.st:226`).
Or mon argument d'indépendance repose **entièrement** sur la forme actuelle
`CablePosM2_brut ≥ LIMITE + M2_LimitShift` — c'est **cette forme** qui fait s'annuler `ActiveOffsetM`.

| Statut de l'arbitrage | Portée exacte |
|---|---|
| ✅ **Valide aujourd'hui** | Tant que la comparaison M2 reste « position M2 **brute** vs `limite + M2_LimitShift` », l'invariant de configuration est **indépendant** de `ActiveOffsetM` |
| ⛔ **Non garanti après T291-B B2** | Si B2 fait de **M1 l'autorité** en Both, la comparaison M2 pourrait porter sur la position **corrigée** M1 → `ActiveOffsetM` **ne s'annule plus** de la même façon ⇒ **l'invariant devra être RE-DÉRIVÉ et re-vérifié après B2** |

> 🔧 **Conséquence opérationnelle** : l'invariant T330 peut être **figé maintenant** (il porte sur des
> **valeurs de configuration**, pas sur la formule), mais **tout garde-fou codé** contre
> `CfgCableLimitAscent_M + M2_LimitShift` **sera invalidé par T291-B** ⇒ **ne pas coder ce garde-fou
> avant B2**, et **sérialiser** : `T330 (cadrage) → T291-B B1 → arbitrage Q1 → T291-B B2 → garde-fou T330`.
> ✅ Cet ajout **corrobore** la conclusion de la review automatisme (« T330 doit figer le périmètre et la
> formule de comparaison M2 avant que T291-B ne réécrive l'autorité M1/M2 »).

### 7.4 Autres frictions

| # | Friction | Preuve | Gravité |
|---|---|---|---|
| 1 | **Faux noms propagés** : la décision bloquante de T291-B est **infalsifiable** | `TASK_CONTRACT_T291_B_...yaml:77` | 🔴 |
| 2 | **Collision d'ID de gate** : T291-B réclame `G499`, déjà pris par T289 | `run_all_gates.py:144` | 🟠 |
| 3 | **Seuils dérivés partagés non arbitrés** : T291-B AC3 teste `H−0,51 / H−0,50 / H−ε / H` ; T330 définit les dérivés ±0,50 ⇒ **deux définitions possibles du même 0,50** | `T291_B:19` | 🔴 **un seul gate/test doit figer la convention** |
| 4 | **`AC5` de T330 est factuellement FAUX** — « le homing est la **seule** exception » : il y en a **3** (homing, override N1, bypass N2) | `FB_Safety_Winch.st:581` · `PRG_04:845-877` | 🔴 à reformuler |
| 5 | Précédence : T291-B B2 exige « après B1/**T330** » ⇒ la règle T330 doit être **figée avant** B2 | `T291_B:81` | 🟠 |

---

## 📁 8 · Fichiers potentiellement concernés par une future implémentation C3

| Fichier | Rôle envisagé | Nature |
|---|---|---|
| `CODE/M_MAIN/PRG_07_Supervision.st` | **Vérification de cohérence + refus** avant tout pont de persistance (**avant `:140`**) — producteur unique | ✏️ modification |
| `CODE/H_TREUILS_BENNE/FB_Hmi_BannerFormatter.st` | Message opérateur ciblé + cause | ✏️ modification |
| `CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st` | **⚠️ interdit par le contrat** (aucun nouveau champ) — lecture seule | 🔒 lecture |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | Posture de départ cycle (dérivé `CST_*`) — **à confirmer** | 🔒 lecture |
| `TOOLS/AGENT_WORKFLOW/scripts/G504_check_t330_homing_top_invariant.py` | **Nouveau garde-fou** (`fix:` + `guard:`) — ⛔ **ne pas réutiliser `G499`** | ➕ création |
| `TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` | Enregistrement du nouveau gate dans `PLANS` | ✏️ modification |
| `TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py` | **Requalification AC2b** (règle contradictoire + champ fantôme) | ✏️ modification |
| `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st` | Tests de la butée **logicielle** (aujourd'hui jamais exercée) | ✏️ extension |
| `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_winchstateprojection.st` | **Nouveau** — FB sans aucun test | ➕ création |
| `TOOLS/TEST_AUTO_CI/scripts/config/registry.yaml` | Entrée registre manquante | ✏️ modification |
| `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_04.st:34` | `7.5` **dupliqué** à supprimer | ✏️ modification |
| `DOC/AF/AF_Partie-09_...v2.4.md` | **Correction** : M2 n'est **pas** indépendant (faux §459/§548/§562) | ✏️ documentation |
| `DOC/AF/AF_Partie-10_...v2.1.md` §7.7 | Question ouverte « débridage sur capteur haut » à trancher | ✏️ documentation |

⛔ **Aucun de ces fichiers n'a été modifié par T330.**

---

## ❓ 9 · Questions restant à trancher (décisions humaines)

| # | Question | Impact si non tranchée |
|---|---|---|
| **Q1** 🔴 | **Quelle règle gouverne ?** `Δ ≥ 1,00 m` (T330) **ou** `Δ ≤ band` (G483 AC2b) — et `band` vaut-il `1,0` (fallback accidentel) ou `0,5` (`WinchSlowdownDistanceTop_M`, valeur réelle) ? **3 options d'arbitrage en §6.2 (A/B/C) — recommandation : A** | **Bloque C3.** Aucun `Δ` ne satisfait les deux si `band = 0,5` |
| **Q2** 🔴 | **Réponse de sécurité au cas `Δ < 0`** (FDC **au-dessus** de la référence TOP) : refus (OPTION 1) ou état invalide (OPTION 2) ? | Le risque n°1 du cadrage reste ouvert ; rend aussi le cycle SEMI_AUTO impossible (§E.1) |
| **Q3** 🟠 | **Le seuil « proximité TOP » (`TOP − 0,50`) fait-il doublon** avec la zone de ralentissement existante (`TopLimitM − WinchSlowdownDistanceTop_M`), qui coïncident à `8,00 m` quand `Δ = 1,00 m` ? Faut-il **un** mécanisme ou **deux** ? | Deux mécanismes concurrents pour le même fait |
| **Q4** 🟠 | **Quelle est la « position M2 corrigée » de référence ?** Trois offsets coexistent (`DisplayOffsetM` affichage, `ActiveOffsetM` sécurités, `OffsetTargetM` écart). La position **affichée** et la position **jugée par le FDC** diffèrent | Diagnostic opérateur potentiellement trompeur |
| **Q5** 🟠 | **Changement de `CfgTopSensorPos_M` sur machine DÉJÀ référencée** : faut-il **armer un re-homing obligatoire** ? Aujourd'hui l'armement ne couvre que `PositionLimitOverridden` (`PRG_04:897-899`) | La référence codeur devient silencieusement incohérente |
| **Q6** 🟠 | **`_TranslationMinHeightM1M2_M := 6,0 m`** (cote **en dur**, dérivée de `CfgTopSensorPos_M`) : commentaire « ≈ 8,0 m − 2,0 m » alors que la valeur réelle est **8,5 m** ⇒ **dérive déjà matérialisée**. Faut-il la traiter dans T330 ? | Précédent **prouvé** du risque que T330 veut prévenir |
| **Q7** 🟡 | **`AC5` du contrat est faux** (3 exceptions, pas 1) et **`AC1`/`AC4`/`AC5` ne sont pas testables** ⇒ réécriture du contrat ? | Critères de succès non vérifiables |
| **Q8** 🟡 | **`FB_Safety_Winch.TopPositionSensor`** (TRUE = libre) vs **`FB_Encoder.TopPositionSensor`** (TRUE = en haut) : **même nom, polarités opposées**. G496 verrouille **uniquement** `PRG_04` (§10.3). Faut-il renommer **ou** étendre le gate aux câblages `PRG_02` ? ⚠️ **Aggravant (review Safety, vérifié)** : le contrat `TASK_CONTRACT_T268_TOP_SENSOR_POLARITY.yaml` est resté **`PENDING`**, sa note **contredit son propre AC2**, et son `:30-31` **interdit** de toucher `FB_Safety_Winch` — ce qui **explique pourquoi les deux polarités coexistent en production**. **À rouvrir** | Risque de câblage inversé non détecté par gate ; contrat de sécurité non soldé |
| **Q9** 🟡 | **`Idx321_CfgTopLimitM`** annoncé « effective » reçoit la valeur **nominale** (`PRG_07:857`) et **ignore** `M2_LimitShift` ⇒ `Idx323/324` peuvent **mentir pour M2** | Diagnostic trompeur (faible gravité) |
| **Q10** 🟠 | **Reprise de montée au retour du permis, commande maintenue** (`RestartRequired` purgé en `T#500ms`, cause TOP non latchée, §E.4) : acceptable pour un fin de course, ou faut-il exiger un **nouveau geste** ? Le cas ne survient qu'en **configuration invalide** ou **sous override/bypass** — c'est-à-dire **près du TOP** | Reprise non gestuelle près du dernier rempart mécanique |
| **Q11** 🔴 | **`Bypass.TopLimitSwitch` est effectif dans TOUS les modes, SEMI_AUTO inclus** (dérogation MES 2026, `PRG_04:854-864`) ⇒ la doctrine « TOP = dernier rempart **non bypassable** » **ne tient pas**. Réconcilier la dérogation **ou** le gate G483 (§6.1ter, §E.3) | G483 est **rouge** aujourd'hui ; la protection TOP est désactivable en auto |
| **Q12** 🟠 | **Export IHM FRAIS requis** : le projet VISU n'est **pas versionné** ⇒ impossible de savoir en lecture seule si le widget `GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M` est **éditable**. S'il l'est, le « miroir silencieux » (§2.3) est un **piège opérateur** : griser/retirer le widget **ou** documenter M1 comme seul maître | Précondition bloquante de la review IHM : décision d'IHM à prendre sur une base **fraîche**, pas sur `ihm_variables.txt` (périmé, cf. C5) |
| **Q13** 🟡 | **`PRG_02:529`** recalcule `MachineHomingCfg.CfgTopHomingTarget_M` à **chaque scan** — une modification de `CfgTopSensorPos_M` **pendant** un homing machine peut-elle changer la cible **en cours de séquence** (HX3 / preset M2) ? | ⚠️ **INCERTAIN** : non tranchable en lecture seule par la review IHM. La cible de `FB_Encoder_Homing` est **capturée au déclenchement** (`:216-223`), mais `FB_CycleMachineHoming` a sa **propre** séquence HX0..HX6 → **à prouver avant C3** |
| **Q14** 🟠 | **Statut safety d'un arrêt sur TOP mécanique hors homing** : la cause 5 est **non latchée** (reprise possible si commande maintenue, §E.4). Faut-il une **cause latchée acquittable** + **retour au neutre / nouvelle demande** obligatoires après un arrêt sur TOP hors homing ? | Le TOP est le **dernier rempart** ; aujourd'hui son franchissement ne laisse **aucune trace latchée** (seul MecaD, à 3 s, latte — §3-D) |
| **Q15** 🔴 | **`WinchSlowdownDistanceTop_M`** (bande de ralentissement haute, **IHM/RETAIN non borné**, doc autorisant `0`) : la marge de `1,00 m` **n'a de sens que par cette bande** (§E.4). **Plafonner cette bande** (≥ 0,5 m) **ou** la sortir du champ d'action de l'IHM ? | Un réglage à `0` **détruit silencieusement** la justification de l'invariant ; la cohérence est un **triplet**, pas un couple |
| **Q16** 🟠 | **Réutilisation de `_MaintM1HomingRequired`/`_MaintM2HomingRequired`** (`GVL_PERSISTENT.st:182-183`, existants, déjà audités par G483 AC6/AC7/AC8) pour porter « configuration invalide » **sans champ neuf** ? | Permettrait l'OPTION 2 sans violer AC3, **mais** confondrait deux notions (« re-homing requis » ≠ « config invalide ») ⇒ **NC-090** et diagnostic indiscernable (§5.3) |

---

## 🔬 10 · Résultats des reviews indépendantes

Méthode : 4 sous-agents à **contexte frais**, **lecture seule**, chacun avec
`TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`, le contrat T330, le besoin métier, le périmètre
lecture seule et le format de verdict. ⚠️ **Leurs rapports sont des avis, jamais des preuves suffisantes** —
chaque constat retenu a été **revérifié sur les sources** par l'orchestrateur.

| Axe | Agent | Verdict | Apport principal |
|---|---|---|---|
| **Automatisme** | `93038da2` | **BLOCK** | 5 motifs : noms inexistants · **G483 faux PASS** · **le chemin nominal de re-homing passe par un BYPASS de sécurité** (override N1 vs homing N2 ⇒ réserve **0 m par conception**) · polarité double · « barrière dure non bypassable » contredite. Apports PROPRES vérifiés : **preuve DÉCISIVE que M2 se référence comme M1** + cible dynamique **supprimée** après un **SafeStop** synchro (`FB_CycleMachineHoming.st:410-420`) · `CfgTopHomingTarget_M` **entrée morte** · `CableLimitM1AscentM` **variable morte** · **`SelHomingApproachEnable` placebo** · **3ᵉ convention** de polarité en IHM (`PRG_07:354`) · **trigger réel = unitaire sur front DESCENDANT** · timeouts `T#120s`/`T#60s` · **challenge de mon arbitrage §7.3** (T291-B change la **formule** M2) |
| **Safety** | `636d3c02` | **BLOCK** | **A DÉMENTI UNE ERREUR DE MON RAPPORT** : `MecaD` (cause 11) est **conditionnée au TOP** et escalade en `PowerCutOff` à 3 s (§3-D corrigé) · **`WinchSlowdownDistanceTop_M` non borné / `0` autorisé ⇒ la marge de 1,00 m peut perdre sa justification** (§E.4, Q15) · **l'OPTION 2 est réalisable SANS champ neuf** via `_MaintMxHomingRequired` (§5.3, Q16) · **l'OPTION 1 ne couvre pas une NVRAM déjà invalide** (§5.3) · piège du homing qui « sort de l'invalidité sans corriger la cause » · chemin fail-unsafe sur rupture NC (**hypothèse forte, non tracée**) · contrat T268 `PENDING` auto-contradictoire · `BypassPowerCutOff` hors IHM (`PRG_06:498`) |
| **IHM** | `1feea1a3` | **ALERTE** | M2 miroir non réglable · aucun gel d'édition · aucune validation croisée · G483 périmé · **arbitrage M2 indépendant de T291-B** |
| **Tests / CI** | `75a80338` | **ALERTE** | **G483 AC2b = règle inverse** 🔴 · **champ fantôme `WinchSlowdownDistance_M`** 🔴 · 3 critères/5 non testables · butée logicielle jamais testée · aucun gate anti-magic-number · collision `G499` |

> 🎯 **3 reviewers sur 4 rendent `BLOCK`** (automatisme, Safety, et mon propre constat). Le constat **G483**
> est **corroboré indépendamment par 3 contextes frais** — c'est le constat le mieux établi de ce cadrage.
> Les 2 motifs de `BLOCK` des reviewers **non retenus tels quels** (polarité, reprise au retour du permis)
> sont **arbitrés et argumentés** ci-dessous, jamais écartés en silence.

### 10.1 Ce que l'orchestrateur a **personnellement** établi en plus des reviews

| Fait nouveau (non remonté par les reviewers) | Preuve |
|---|---|
| 🔴 **G483 est actuellement ROUGE** (`exit=1`) — il échoue sur **AC1** (dérogation MES bypass non réconciliée) ; **AC2b passe** uniquement via le fallback périmé ; G483 est au **palier C sans allowlist** ⇒ **la suite « fin de lot » est rouge aujourd'hui** | **exécution** de `G483_check_bypass_matrix_mode_gated.py` |
| 🔴 **Origine de la divergence = régression de renommage** : le champ s'appelait `WinchSlowdownDistance_M := 1.0` (cohérent avec `Δ = 1,0`), il est aujourd'hui `WinchSlowdownDistanceTop_M := 0.5` ⇒ G483 n'a pas suivi | `DOC/STDS/AUDIT_STRUCTS_MAPPING_20260827.md:81` vs `GVL_PERSISTENT.st:142` |
| 🎯 **Les 2 règles ne gouvernent pas le même objet** (réserve de position vs vitesse de parcours d'override) ⇒ **l'arbitrage a une solution** (Option A, §6.2) | lecture croisée `PRG_04:872-877` + `FB_Winch:173` + `G483:17-18` |
| 🚨 **Chaîne bout en bout du « premier consommateur qui casse »** : `Δ < 0` ⇒ `CycleWinchesAtTopOk` faux ⇒ **AX1_INIT jamais satisfait ⇒ SEMI_AUTO impossible** | `PRG_03:161-168` |

### 10.2 Divergences entre reviewers — arbitrées

| Divergence | Arbitrage orchestrateur |
|---|---|
| **Invariant M2 : dépendant (CI) vs indépendant (IHM) de T291-B** | **Les deux, sur deux objets distincts** : l'invariant de **configuration** est indépendant (`ActiveOffsetM` s'annule, §7.3) ; les **seuils dérivés M2** sont conditionnés à B1. |
| **Gravité de `G483`** : « périmé » (IHM) vs « conflit bloquant » (CI) | **Conflit bloquant confirmé** — vérifié ligne à ligne. Le fallback `1.0` masque l'échec ; avec le vrai champ (`0,5`), **aucun `Δ`** ne satisfait les deux règles. **Aggravant établi en plus** : G483 est **déjà rouge** sur AC1 (§6.1ter). |
| **Nature du champ M2** : « piège » (IHM) vs « conflit » (CI) | **Non réglable, miroir imposé** (fait) — et **contradiction avec AF-09 §5/§9** et `PRG_02:525-528` (§2.3). |
| **Polarité `TopPositionSensor`** : `BLOCK` (Safety & automatisme) vs « délibérée et gatée » (orchestrateur) | **Arbitré en ALERTE** — voir §10.3 : le comportement **net est correct** dans les deux FBs, mais le **nom partagé cache deux polarités opposées** et **seul `PRG_04` est gaté** (`G496`). Risque de câblage futur non détecté. |
| **Reprise au retour du permis** : « viole le non-redémarrage automatique » (Safety) vs « modèle fin de course » (orchestrateur) | **Fait confirmé, qualification corrigée** — voir §E.4 : ce n'est **pas** un défaut latché, donc **pas** une violation du principe ; mais le cas **commande maintenue + cause transitoire** reste à trancher → **Q10**. ⚠️ **Portée réduite** par la découverte `MecaD` (fenêtre de **3 s** puis verrou) |
| **OPTION 1 (IHM) vs OPTION 2 bornée (Safety)** | **Convergence vers un HYBRIDE** — voir §5.3 : la review Safety a **affaibli 2 de mes arguments** (l'OPTION 2 est réalisable **sans champ neuf** ; l'OPTION 1 ne couvre **pas** une NVRAM déjà invalide). Recommandation révisée : **refus à l'écriture (A) + déclaration à la lecture (B)** → **Q2 / Q16** |
| 🔄 **ERRATA — erreur de MON rapport démentie par la review Safety** | **Acceptée et corrigée** — voir §3-D : `MecaD` **est** conditionnée au TOP et escalade en `PowerCutOff` à 3 s. Mon affirmation « aucun défaut déclenché *par* le TOP » était **fausse** ; elle est **retirée** et le mode D est réécrit |

### 10.3 Arbitrage du constat « polarité » — `ALERTE`, pas `BLOCK`

**Fait (vérifié)** : le **même nom de port** `TopPositionSensor` porte **deux conventions opposées**.

| Consommateur | Signal reçu | Convention | Preuve | Comportement net |
|---|---|---|---|---|
| `FB_Safety_Winch` (M1 & M2) | `M1M2_TopPositionFree_DI` **brut** | **TRUE = zone haute LIBRE** | `PRG_04:932,1001` · `FB_Safety_Winch.st:310,576` | ✅ correct (bloque sur `NOT TopPositionSensor` = **atteint**) |
| `FB_Encoder` (M1 & M2) | `NOT M1M2_TopPositionFree_DI` | **TRUE = capteur ATTEINT** | `PRG_02:604,659` | ✅ correct (front montant = arrivée au TOP) |
| `FB_CycleMachineHoming` | `NOT M1M2_TopPositionFree_DI` | **TRUE = ATTEINT** | `PRG_02:539` | ✅ correct |
| `HomingPermit` | `NOT M1M2_TopPositionFree_DI` | **TRUE = ATTEINT** | `PRG_02:592,645` | ✅ correct |
| ⚠️ **IHM / diagnostic** | `NOT M1M2_TopPositionFree_DI` | **TRUE = ATTEINT** | `PRG_07:354` (`GVL_IHM.Commun.TopPositionSensorActive`) | ⚠️ **3ᵉ convention** sous des noms voisins |

**Verdict de l'orchestrateur** :
- ❌ **Ce n'est PAS une inversion active** : dans chaque FB, la logique interne est **cohérente** avec le
  signal reçu ⇒ **aucun défaut de comportement aujourd'hui**.
- ✅ La convention de `FB_Safety_Winch` est **explicitement documentée et verrouillée** par
  `G496_check_top_sensor_polarity.py:1-6` (« `FB_Safety_Winch` attend cette même polarité et bloque sur
  `NOT TopPositionSensor` ») — elle est donc **délibérée**, pas accidentelle.
- ⚠️ **Mais le risque est réel** : une inversion **future** de `PRG_02` (le côté `NOT`) ne serait
  **détectée par aucun gate** (G496 ne contrôle que `PRG_04`, à 2 liaisons exactes).
- ⇒ **`ALERTE` (MINOR), consigné en Q8** — je ne retiens pas le `BLOCK` : le déclarer bloquant serait
  **inexact** et ferait perdre du temps sur un point qui fonctionne.

> 🧠 **Note de méthode** : cette divergence illustre pourquoi les rapports de sous-agents sont des **avis**.
> Deux reviewers sur quatre concluaient `BLOCK` sur ce point ; la lecture directe des 4 câblages montre un
> comportement **net correct**. Le risque retenu est **de nommage et de gatage**, pas de fonction.

### 10.4 Vérification personnelle des constats critiques

| Constat retenu | Vérifié par l'orchestrateur | Méthode |
|---|---|---|
| Noms réels `CfgTopSensorPos_M` / `CfgCableLimitAscent_M` | ✅ | lecture `ST_WinchCfg.st:8`, `ST_CommunCfg.st:21` |
| **G483 AC2b impose `delta <= band`** | ✅ | lecture directe `G483:164-175` |
| **`WinchSlowdownDistance_M` inexistant** | ✅ | recherche du nom **exact** ⇒ 0 occurrence ; vrais champs `:142-143` |
| Aucune validation croisée dans `CODE/` | ✅ | `grep` exhaustif |
| **Arrêt immédiat** sur TOP ou FDC ⇒ ni `SafeStop` **direct** ni `PowerCutOff` **direct** (permis seul) — ⚠️ **mais `MecaD` escalade en 3 s** si l'arrêt n'est pas confirmé (§3-D) | ✅ **corrigé** après démenti de la review Safety | lecture `FB_Safety_Winch.st:372-387,516-525,574-582` |
| `CfgTopSensorPos_M` M2 écrasé = M1 | ✅ | lecture `PRG_07:150-155` |
| 🔴 **`MecaD` (cause 11) est conditionnée au capteur TOP et escalade en `PowerCutOff` à 3 s** — **correction d'une erreur de ma part** (§3-D, ERRATA) | ✅ | lecture `FB_Safety_Winch.st:49,372-387,505,519,525` |
| 🔴 **`WinchSlowdownDistanceTop_M` non borné, doc autorisant `0`** ⇒ la marge de 1,00 m peut être privée de justification | ✅ | `ST_CommunCfg.st:16` · `PRG_07:189-197` |
| `BypassPowerCutOff` depuis `GVL_BypassRetain` — bypass AU **hors IHM** | ✅ | `PRG_06_Outputs.st:492-498` |
| `PostRampTimeout := T#3s` (partagé Meca B / Meca D) | ✅ | `FB_Safety_Winch.st:49` |
| Zone de ralentissement dérivée du `TopLimitM` **actif** | ✅ | lecture `FB_Winch.st:173` |
| Cible de homing **capturée au déclenchement** | ✅ | lecture `FB_Encoder_Homing.st:214-223` |
| Trois offsets M2 distincts | ✅ | lecture `FB_Bucket.st:716,142` · `PRG_04:824,1739` |
| **Polarité `TopPositionSensor` — fausse alerte écartée** | ✅ | `G496:1-6` documente la convention ; **pas un bug**, mais risque de nommage (Q8) |

---

## ✅ 11 · Conformité aux règles non négociables de la mission

| Interdit mission | Respect |
|---|---|
| Ne créer aucune nouvelle variable de FDC | ✅ aucune |
| Ne créer aucun paramètre IHM ou RETAIN | ✅ aucun |
| Ne créer aucune copie des paramètres existants | ✅ aucune |
| Ne coder aucune valeur fixe `7.50` / `8.00` / `8.50` | ✅ **aucun fichier `CODE/` modifié** |
| Ne modifier ni les FDC, ni les permis, ni le homing | ✅ |
| Ne modifier aucun fichier de T291-B | ✅ diff `TASKS.yaml` d'AGY01 **préservé** |
| Ne pas modifier `CODE/`, `CODE_XML/`, types IHM | ✅ `git status` : **aucun** de ces chemins |
| Ne pas lire `Device.export` | ✅ jamais lu |
| Aucun bundle ni test générateur | ✅ aucun bundle lancé |
| Aucun commit, push, revert, nettoyage, suppression | ✅ |
| Ambiguïté de sécurité ⇒ arrêt + alerte | ✅ **verdict `BLOCK`** sur le passage à C3 |

---

## ⛔ 11bis · Périmètre EXPLICITEMENT EXCLU de T330 (décision humaine, 2026-09-20)

Décision de l'humain, actée pendant le cadrage : **trois comportements ne sont PAS dans le périmètre de
T330**, restent **chez l'humain**, en attente du **cadrage d'une tâche dédiée** et d'un **agent dédié** :

| # | Comportement | Statut | Rapport avec T330 |
|---|---|---|---|
| 1 | **Fermeture / ouverture incomplète** de la benne | ⛔ **hors T330** — tâche dédiée à cadrer par l'humain | Touche la chaîne de mouvement (cap palier 1 benne non fermée, `ActiveOffsetM`) mais **T330 n'en traite rien** |
| 2 | **Dérive après Both** | ⛔ **hors T330** — tâche dédiée à cadrer par l'humain | C'est le sujet de **T291-B** (continuité M2 corrigée / autorité M1 en Both) — T330 n'en traite **que la dépendance** (§7.3), jamais le comportement |
| 3 | **Latence D18** (interlock directionnel) | ⛔ **hors T330** — tâche dédiée à cadrer par l'humain | **Aucun recouvrement technique** : T330 ne touche ni `FB_WinchDirectionInterlock`, ni les temps morts directionnels |

**Engagements pris par T330** :
- ✅ **aucune tâche créée**, **aucun agent sollicité**, **aucun renvoi vers un agent inexistant** ;
- ✅ **aucun fichier** de ces trois périmètres n'a été lu pour autre chose que la traçabilité d'impact
  (les citations `FB_Winch.st`, `FB_Bucket.st`, `PRG_04` servent l'invariant haut, jamais ces comportements) ;
- ✅ ces trois items **ne bloquent pas** l'arbitrage de **Q1/Q2** (voir ci-dessous).

### 🔎 Point de vigilance transverse — risque de **confusion de diagnostic** (devoir d'alerte)

Les trois comportements exclus produisent, côté opérateur, des symptômes **proches** de ceux de l'invariant :

| Symptôme observé | Cause possible **A** (hors T330) | Cause possible **B** (invariant T330) |
|---|---|---|
| « La montée ne part pas / ne monte pas » | **Latence D18** — blocage **silencieux** sans défaut (`CADRAGE_T325` : `DeadTimeArmed` non purgé) | FDC logiciel haut atteint → `AscentPermit := FALSE` |
| « Le cycle refuse de démarrer » | **Fermeture incomplète** (cap palier 1 benne non fermée) | `Δ < 0` ⇒ `CycleWinchesAtTopOk` insatisfaisable (§E.1) |
| « Le treuil s'arrête avant la fin » | **Dérive après Both** (divergence M1/M2, barrière P1/P5) | Ralentissement haut puis arrêt au FDC |

> ⚠️ **Conséquence à contractualiser dans la future C3** : le **message d'erreur** ajouté pour
> « configuration invalide » doit être **strictement distinguable** des messages existants de D18, de
> benne non fermée et de synchro — sinon on ajoute une **cause de plus** à un diagnostic déjà ambigu.
> 📌 **Ce n'est pas une demande d'élargissement** : c'est une contrainte de conception **dans** T330.

---

## 📎 12 · Traçabilité de fin de rapport

### Fichiers LUS (lecture seule — `CODE/`)
`GVL_PERSISTENT.st` · `J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCfg.st` ·
`.../ST_WinchCmd.st` · `.../ST_SafetyWinch.st` · `.../ST_Chain_Winch_Safety.st` ·
`.../ST_BucketHMIState.st` · `J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st` ·
`H_TREUILS_BENNE/FB_WinchStateProjection.st` · `.../FB_Safety_Winch.st` · `.../FB_Winch.st` ·
`.../FB_WinchSync.st` · `.../FB_SyncDeviation.st` · `.../FB_WinchOutputInterlock.st` ·
`.../FB_WinchStepShaper.st` · `.../BENNE/FB_Bucket.st` ·
`E_CODEURS/FB_Encoder.st` · `.../FB_Encoder_Homing.st` · `.../FB_Encoder_Abs.st` ·
`G_CYCLE/FB_CycleMachineHoming.st` · `F_MODES/FB_Modes.st` ·
`M_MAIN/PRG_02_Acquisition.st` · `.../PRG_03_Modes_Cycle.st` · `.../PRG_04_Treuils_Benne.st` ·
`.../PRG_05_Translation.st` · `.../PRG_06_Outputs.st` · `.../PRG_07_Supervision.st` ·
`J_SUPERVISION/FB_TroubleshootingView.st` · `.../FB_Hmi_BannerFormatter.st`
**Docs** : `AGENTS.md` · `DOC/STDS/CODE_QUALITY_STANDARDS.md` · `DOC/AF/AF_Partie-09_..._v2.4.md` ·
`DOC/AF/AF_Partie-10_..._v2.1.md` · contrat T330 · `TASKS.yaml` · `TASK_LOCKS.json` ·
`TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` · `G483` · `G496` · `run_all_gates.py` ·
`DOC/STDS/AUDIT_STRUCTS_MAPPING_20260827.md`

### Commandes exécutées (lecture seule, aucun artefact écrit)
| Commande | Résultat |
|---|---|
| `python TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py` | **`FAIL`, `exit=1`** (AC1 / AC1b ; **AC2b passe via le fallback périmé**) |
| `git status --short` · `git diff --stat` | ⛔ **aucun** chemin `CODE/`, `CODE_XML/`, IHM modifié |
| Recherche du nom exact `WinchSlowdownDistance_M` | **0 occurrence** dans `CODE/` |
⛔ **Aucun bundle** (`generate_codesys_bundle.py`, `generate_codesys_diff_bundle.py`), **aucun `G200`**,
**aucun `run_all_gates.py`** complet — T330 est un cadrage (§10.4 du rapport de review CI).

### Fichiers MODIFIÉS (documentation T330 uniquement)
| Fichier | Nature |
|---|---|
| `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` | ➕ **ce rapport** (livrable T330) |
| `DOC/WFLOW/TASKS.yaml` | ✏️ bloc **T330** uniquement (statut 🔒 `⏳`, `agent: DSH01`, `date`, `avancement`) |
| `DOC/WFLOW/TASK_LOCKS.json` | ✏️ 🔒 `T330` = `DSH01` (fichier local, `.gitignore:102`) · 🚩 **retiré** |
| `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml` | ➕ 1 action T330 + 4 reviews |

⛔ `CODE/` · `CODE_XML/` · `CODE/J_SUPERVISION/_TYPES/` (IHM) · `Device.export` : **AUCUN**.
⛔ Le diff non commité de `TASKS.yaml` appartenant à **AGY01** (bloc T291-B) est **intact**.

### 🚨 12.1 Acteur parallèle détecté — `CODE/` et `CODE_XML/` modifiés PENDANT cette session

**Constat établi par horodatage** (devoir d'alerte — `AGENTS.md` : « si un fichier que tu n'as pas modifié
apparaît dans le diff → STOP et demande à l'humain ») :

| Fichier | Dernière écriture | Auteur |
|---|---|---|
| `DOC/WFLOW/TASKS.yaml` · `TASKS_ORCHESTRATOR.yaml` · `TASK_LOCKS.json` · `CADRAGE_T330_...md` | **11:46 → 11:57** | ✅ **DSH01 (T330 — moi)** |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | **11:54:50** | ⚠️ **acteur parallèle** |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | **11:54:59** | ⚠️ **acteur parallèle** |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketHMIState.st` | **11:55:05** | ⚠️ **acteur parallèle** |
| `CODE_XML/CODE_Bundle.xml` | **11:57:15** | ⚠️ **acteur parallèle** |
| `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md` · `prompts/subagent_preamble.md` · `skills/orchestrator/SKILL.md` | 11:47 → … | ⚠️ **acteur parallèle** |

**Faits** :
- En **début de session**, `git status --short` ne montrait **que** ` M DOC/WFLOW/TASKS.yaml` (bloc T291-B).
- Les chemins `CODE/` et `CODE_XML/` **n'étaient pas** modifiés à ce moment-là.
- ⇒ Ils ont été modifiés **pendant** la mission T330, à `11:54–11:57`, par un **acteur concurrent**
  (très probablement **AGY01 sur T291-B**, qui détient le 🔒 `T291-B` et dont le périmètre couvre
  précisément `FB_Bucket`, `ST_BucketHMIState` et `PRG_04_Treuils_Benne`).
- ⚠️ `CODE_XML/CODE_Bundle.xml` a été **régénéré** par cet acteur à `11:57:15` ⇒ **le bundle frais n'est
  PAS de T330** et **ne doit pas** être présenté comme la preuve de ce lot.

> 🛑 **Conséquence opérationnelle** : **AUCUN commit ne doit être fait** sans tri humain préalable.
> T330 n'a **rien** commité, **rien** poussé, **rien** supprimé. Le diff `CODE/` présent dans l'arbre de
> travail **n'appartient pas** à ce lot et **n'a pas été produit ni relu** par T330.
> **Décision demandée à l'humain** : attribuer ces modifications à leur auteur, puis commiter
> **séparément** (règle « premier réflexe avant commit/push »).
> 📌 Le rapport T330 reste **valide indépendamment** : tous ses constats portent sur des lignes **lues
> avant** `11:54` et **revérifiées** après coup par l'orchestrateur (`M2_LimitShift` — `PRG_04:824` ;
> `TopLimitM1_M`/`TopLimitM2_M` — `PRG_04:872`/`:875` ; `AscentPermit` — `FB_Safety_Winch.st:574`,`:581` ;
> FDC M2 — `FB_WinchStateProjection.st:226` : **toutes inchangées** ✅). Deux citations seulement ont été
> **corrigées** du décalage introduit par l'édition parallèle : `PRG_04:1737` (et non 1739) et
> `FB_Bucket.st:716` (et non 718).

### 12.2 ⚠️ T291-B a **déjà commencé à écrire du code** pendant le cadrage T330

| Fait observé | Preuve |
|---|---|
| `DisplayOffsetM` est passé en **continu** (« pas de saut de 15 m aux transitions d'états francs ») | `PRG_04_Treuils_Benne.st:1735-1737` (commentaire explicite « T291-B ») |
| `M2PositionCorrectedValid` rendu **conservateur** et explicitement rattaché à **T291-B B1** | `PRG_04:1738-1743` |
| `M2_LimitShift := instBucket.ActiveOffsetM` **inchangé** | `PRG_04:824` ✅ |

> 🔴 **Conséquences directes pour T330** :
> 1. Cela **confirme** l'analyse §2.2/§7.3 : T291-B agit bien sur l'offset d'**affichage**
>    (`DisplayOffsetM`), **pas** sur `ActiveOffsetM` utilisé par la comparaison de sécurité ⇒
>    **l'invariant de configuration reste indépendant de T291-B** ✅ ;
> 2. en revanche le **risque de conflit d'édition est passé de théorique à réel** (`PRG_04`,
>    `FB_Bucket`, `ST_BucketHMIState` sont en cours d'écriture) ;
> 3. ⇒ **T330 ne doit en aucun cas implémenter quoi que ce soit dans ces fichiers** avant que T291-B
>    n'ait rendu son lot et que B1 soit validé — ce que le présent cadrage recommande déjà (§7.2).

### Sous-agents utilisés
`93038da2` (automatisme) · `636d3c02` (Safety) · `1feea1a3` (IHM, ALERTE) · `75a80338` (tests/CI, ALERTE)
— tous **lecture seule**, aucun fichier touché.

### État des flags / locks
| Élément | État |
|---|---|
| 🔒 `T330` | **`DSH01`** depuis `2026-09-20T11:46:35+02:00` — **conservé jusqu'à la remise** |
| 🚩 `edit_flags` | **VIDE** (posé puis retiré après l'écriture de `TASKS.yaml`) |
| 🔒 `T291-B` | `AGY01` — **non touché** |
| `Device.export` | **non lu** (périmé par doctrine) |

### ✅ Confirmation explicite
**Aucun code automate n'a été modifié. Aucune ligne de `CODE/`, `CODE_XML/`, type IHM, FDC, permis ou
homing n'a été touchée. Aucun bundle, aucun test générateur, aucun commit, push, revert ou suppression
n'a été effectué. T330 est un cadrage : `BLOCK` pour le passage à C3 jusqu'à arbitrage humain de Q1 et Q2.**

---

## 🏁 Verdict final

```
VERDICT : BLOCK  (passage à C3)
```

**Motif** — au sens de l'`alert_duty` du contrat (« toute ambiguïté … bloque le passage à une
implémentation C3 ») :

1. 🚨 **Règle de sécurité contradictoire** : `G483` AC2b (CI **active**) impose `Δ ≤ band` quand T330
   impose `Δ ≥ 1,00 m` ⇒ satisfaisables **uniquement** à `Δ = 1,00 m` exactement. Avec le vrai champ
   `WinchSlowdownDistanceTop_M = 0,5`, **aucun `Δ`** ne satisfait les deux. Origine **prouvée** :
   régression de renommage (`WinchSlowdownDistance_M := 1.0` → `..._Top_M := 0.5`). → **Q1**
2. 🚨 **`Δ < 0` non protégé** : le FDC logiciel peut être placé **au-dessus** de la position de
   référencement TOP ; la montée n'est alors plus arrêtée avant le capteur, **aucun message**, et le
   cycle SEMI_AUTO devient **impossible** (symptôme silencieux). → **Q2**
3. 🚨 **Le garde-fou lui-même est ROUGE et aveugle** : `G483` échoue (`exit=1`) sur AC1 (dérogation MES
   non réconciliée) et son AC2b passe via un **champ fantôme** ⇒ **aucune protection effective** de
   l'invariant que T330 doit installer. → **Q11**
4. ⚠️ **Doctrine « TOP = barrière dure non bypassable » contredite** : `BypassTopLimitSwitch` la
   supprime **dans tous les modes, SEMI_AUTO inclus**. → **Q11**
5. ⚠️ **Noms du contrat inexistants** dans le code (`PositionHomingTop_M`, `PositionFdcLogicielHaut_M`,
   `CableLimitAscent_M`) ⇒ critère **AC1 infalsifiable**, erreur propagée à 3 autres documents. → **Q7**

### Constats détaillés

- `TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py:164-175` — AC2b impose
  `CfgTopSensorPos_M − CfgCableLimitAscent_M <= band` (`band` = fallback **1.0**), règle **inverse** de
  T330 (`>= 1,00`) ; les deux ne sont vraies qu'à `Δ = 1,00` exactement, cas des défauts actuels — le
  gate **ne passe que par coïncidence** ; toute valeur utilisateur réaliste casse l'une des deux règles —
  **Confiance : certaine (lecture + arithmétique + exécution)** — *Décision : arbitrer (**Q1**, options A/B/C en §6.2).*
- 🔄 **ERRATA — une erreur de MON rapport, démentie par la review Safety** : `FB_Safety_Winch.st:372-387`
  — j'avais écrit qu'**aucun défaut n'était déclenché *par* le TOP**. **Faux** : la **cause 11 « Méca D »**
  est explicitement conditionnée à **`NOT TopPositionSensor`** (donc « au TOP »), **latchée**
  (`:386`), et **incluse dans `CausesSafeStopActive` ET `CausesPowerCutOffActive`** (`:519,525`) ⇒
  **escalade en AU après `PostRampTimeout = T#3s`** (`:49`) si contacteurs/frein ne confirment pas l'arrêt
  (hors manœuvre benne, `:377`). ⇒ Le TOP dispose bien d'une **escalade latchée vers l'AU** (avec `Reset` +
  réarmement AU requis, `FB_WinchOutputInterlock.st:202-212`) — **Confiance : certaine (lecture + arrêt de
  la review Safety)** — *Section §3-D corrigée ; la portée du constat §E.5 est réduite à une fenêtre de 3 s.*
- 🔴 `CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st:16` + `CODE/M_MAIN/PRG_07_Supervision.st:189-197`
  — `WinchSlowdownDistanceTop_M` (**IHM/RETAIN**) **n'est pas borné** et sa doc **autorise `0`**
  (« 0 = arrêt au seuil ») ; or c'est **cette bande qui justifie** la marge de `1,00 m` : à `0`, le treuil
  arriverait **à pleine vitesse** sur le capteur sous override, la règle `Δ ≥ 1,00 m` étant pourtant
  « satisfaite » ⇒ **borner `Δ` seul ne suffit pas** : la cohérence est un **triplet**
  `{CfgTopSensorPos_M, CfgCableLimitAscent_M, WinchSlowdownDistanceTop_M}` — **Confiance : certaine** —
  *Décision : **Q15**.*
- 🟠 `CODE/GVL_PERSISTENT.st:182-183` — `_MaintMxHomingRequired` **existe déjà** (armé par `FB_Modes`,
  audité par G483 AC6/AC7/AC8) : l'**OPTION 2 est donc réalisable SANS champ neuf** ⇒ **mon argument
  « OPTION 2 viole AC3 » est AFFAIBLI** ; en contrepartie, réutiliser ce champ **confondrait** « re-homing
  requis » et « configuration invalide » (**NC-090**) et rendrait le diagnostic indiscernable —
  **Confiance : certaine** — *Décision : **Q16** ; recommandation révisée en **hybride** (§5.3).*
- 🟠 `CODE/M_MAIN/PRG_06_Outputs.st:492-498` — `BypassPowerCutOff := GVL_BypassRetain.BypassAuPowerCutOff` :
  bypass d'**ingénierie RETAIN, hors IHM**, du `PowerCutOff` — jamais exposé opérateur (commentaires
  `:492,:495` « jamais IHM ») ⇒ **pas de dérogation opérateur**, mais **non traçable côté IHM** —
  **Confiance : certaine** — *Décision : hors périmètre T330 ; signalé.*
- 🚨 `TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py` — **exécuté par
  l'orchestrateur : `[G483] FAIL`, `exit=1`** sur **AC1** (11+ bypass non gatés par MAINT_N2, « seulement 10 affectations
  gâtées, attendu ≥ 30 », AC1b) ; **AC2b n'apparaît pas** dans les erreurs ⇒ il passe **via le fallback
  périmé** ; G483 est en **palier C sans allowlist** (`run_all_gates.py:134`) ⇒ **la suite « fin de lot »
  est ROUGE aujourd'hui** : le gate ne protège **rien** — **Confiance : certaine (exécution)** —
  *Décision : réconcilier la dérogation MES ou le gate (**Q11**).*
- `DOC/STDS/AUDIT_STRUCTS_MAPPING_20260827.md:81` — le champ s'appelait **`WinchSlowdownDistance_M := 1.0`**,
  alors cohérent avec `Δ = 1,0` ; il est aujourd'hui **scindé** en `WinchSlowdownDistanceTop_M := 0,5` /
  `..._Bottom_M := 1,0` (`GVL_PERSISTENT.st:142-143`) ⇒ **régression de renommage non propagée** : la
  réduction de la bande de `1,0` à `0,5 m` a **silencieusement** invalidé l'invariant `Δ ≤ band` —
  **Confiance : certaine** — *Décision : **Q1** ; c'est un cas d'école du risque visé par T330.*
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st:845-852` vs `CODE/M_MAIN/PRG_02_Acquisition.st:590-593` —
  l'override du FDC exige **MAINT_N1**, le homing exige **MAINT_N2** ⇒ une montée de homing sur machine
  **déjà référencée** ne passe que par le **bypass latché** `Bypass.TopLimitSoftware`, sous lequel
  `TopLimitM = CfgTopSensorPos_M` ⇒ **réserve consommée à 0 m par conception**, seul le capteur physique
  subsiste dans les derniers `Δ` mètres — **Confiance : certaine** — *Décision : c'est l'objet réel de
  G483 AC2b ; **Q1** (§6.2).*
- `CODE/M_MAIN/PRG_03_Modes_Cycle.st:161-168` — chaîne bout en bout : `Δ < 0` ⇒ `CableLimitAscentM*` jamais
  vrai et fenêtre `±0,4 m` (`CST_CycleInitWindowM`) fausse si `|Δ| > 0,4` ⇒ **`CycleWinchesAtTopOk` jamais
  satisfait ⇒ `AX1_INIT` impossible ⇒ cycle SEMI_AUTO impossible** — symptôme **silencieux** —
  **Confiance : haute (chaîne lue intégralement)** — *Décision : renforce OPTION 1 (**Q2**).*
- `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:574-577` + `CODE/M_MAIN/PRG_04_Treuils_Benne.st:854-864` —
  la doctrine « FDC haut **physique** = barrière **dure non bypassable** » (`PRG_04:816,838`) est
  **contredite par le code** : `BypassTopLimitSwitch` la supprime, et la **dérogation MES 2026** le rend
  effectif **dans tous les modes, SEMI_AUTO inclus** ⇒ « TOP = dernier rempart matériel commun » **ne tient
  que si ce bypass est désarmé** ; aucun gate **actif** ne verrouille ce caractère non bypassable —
  **Confiance : certaine** — *Décision : **Q11** (hors périmètre T330 : signalé, non corrigé).*
- `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:221-228,246-253` + `CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st:45-47`
  — cause TOP **non latchée** (`FB_Safety_Winch.st:315`), hors `SafeStop`/`PowerCutOff`, `RestartInhibit`
  non posé, `RestartRequired`/`DeadTime` **purgés pendant la pause** ⇒ **commande maintenue + disparition
  transitoire de la cause = reprise de montée sans nouveau geste** ; la perte du permis coupe le palier
  **immédiatement** (`ShapedStep := 0`), la reprise est **rampée** — **Confiance : certaine (fait)** ;
  **qualification** : modèle **fin de course**, **pas** un défaut latché ⇒ **pas** une violation du
  principe projet (arbitrage anti-Yes-Man envers la review Safety) — *Décision : **Q10**.*
- `TOOLS/AGENT_WORKFLOW/scripts/G483_check_bypass_matrix_mode_gated.py:170` — lit
  `WinchSlowdownDistance_M`, **champ inexistant** (0 occurrence dans `CODE/` ; vrais champs
  `WinchSlowdownDistanceTop_M := 0.5` / `..._Bottom_M := 1.0`, `GVL_PERSISTENT.st:142-143`) ⇒ fallback
  silencieux `1.0` ; lu correctement, **G483 échouerait aujourd'hui** sur la configuration par défaut —
  **Confiance : certaine (recherche du nom exact)** — *Décision : corriger le nom + requalifier AC2b.*
- `CODE/M_MAIN/PRG_07_Supervision.st:150-155` — `CfgTopSensorPos_M` **M2 écrasé chaque scan** depuis M1
  (IHM **et** NVRAM), sans condition ⇒ champ M2 **non réglable**, saisie perdue silencieusement —
  contradiction avec `AF-09 v2.4:459,548,562` et avec le commentaire `PRG_02:525-528` « jamais la position
  M1 » — **Confiance : certaine** — *Décision : corriger la doc AF-09 + trancher l'éditabilité (**Q4/Q8**).*
- `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st:219-226` + `CODE/M_MAIN/PRG_04_Treuils_Benne.st:872-877`
  — aucune validation de cohérence entre les deux paramètres n'existe ; le cas `Δ < 0` place la butée
  logicielle **au-dessus** de la référence TOP ⇒ protection logicielle haute **inopérante**, seul le
  capteur physique subsiste — **Confiance : certaine** — *Décision : OPTION 1 + cas dégénéré (**Q2**).*
- `CODE/H_TREUILS_BENNE/FB_Winch.st:173` — la zone de ralentissement dérive du **`TopLimitM` actif**
  (donc relevé sous override N1) : à `Δ = 1,00` et `WinchSlowdownDistanceTop_M = 0,5`, le point médian
  `8,00 m` **coïncide** avec le début de cette zone ⇒ le seuil de proximité TOP ferait **doublon** —
  **Confiance : certaine (lecture)** — *Décision : un seul mécanisme ou deux (**Q3**).*
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1739` vs `:824` vs `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:716`
  — **trois** « positions M2 corrigées » avec **trois offsets** (`DisplayOffsetM` affichage /
  `ActiveOffsetM` sécurités à pente bornée / `OffsetTargetM` instantané) : la position **affichée** n'est
  **pas** celle comparée au FDC — **Confiance : certaine** — *Décision : trancher la référence (**Q4**).*
- `CODE/GVL_PERSISTENT.st:90-93` — `_TranslationMinHeightM1M2_M := 6.0` cote **en dur** commentée
  « ≈ 8,0 m − 2,0 m » alors que `CfgTopSensorPos_M` vaut **8,5 m** ⇒ **dérive déjà matérialisée** : preuve
  que le risque visé par T330 n'est **pas théorique** — **Confiance : certaine** — *Décision : périmètre
  (**Q6**).*
- `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st:221-241` — la butée
  **logicielle** n'est **jamais** exercée (`CablePosM ≤ 6,0`, `TopLimitM := 8.5`) ; seul le capteur
  **physique** est testé — **Confiance : certaine (review CI, cohérent avec les valeurs lues)** —
  *Décision : ajouter les tests avant C3.*
- `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:930-932,1001` + `CODE/M_MAIN/PRG_02_Acquisition.st:604` — le
  **même nom** `TopPositionSensor` porte des polarités **opposées** (`FB_Safety_Winch` TRUE = *libre* ;
  `FB_Encoder`/`FB_CycleMachineHoming` TRUE = *en haut*) ; `G496` verrouille **uniquement** `PRG_04` —
  **Confiance : certaine** — *Décision : renommer ou étendre le gate (**Q8**).*
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_...yaml:11,14,20-24` — `AC1` porte sur des identifiants
  **inexistants** (infalsifiable) ; `AC4`/`AC5` vérifient la **livraison d'un document**, pas un
  comportement ; `AC5` est **factuellement faux** (3 exceptions, pas 1) — **Confiance : certaine** —
  *Décision : réécrire le contrat (**Q7**).*

**Fichiers lus** : voir §12 · **Fichiers modifiés** : documentation T330 uniquement (§12) ·
**Sous-agents** : 4 (lecture seule) · **Divergences entre reviewers** : 4, arbitrées (§10.2) ·
**Errata** : 1 (une erreur **de mon rapport**, démentie par la review Safety — §3-D) ·
**Flags/locks** : 🔒 `T330`=`DSH01`, 🚩 retiré, `T291-B` intact ·
**✅ Aucun code automate modifié.**
