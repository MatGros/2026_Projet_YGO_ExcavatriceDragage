# 🥊 CHALLENGE T340 — Refonte homing : « référence provisoire à la fermeture benne » + palier 1 global + Plan B

> **Mission** : T340 (parent T336 Phase 3) — challenge **indépendant**, contexte frais, **AVANT tout code**, de la
> nouvelle conception validée par l'utilisateur le 2026-09-20 (abandon du design « référencement à la descente / option B »
> du challenge précédent).
> **Persona** : expert senior automatisme industriel / treuils synchronisés · benne · variateurs · codeurs ·
> référencement · sécurité machine (ISO 13849). **Posture anti-yes-man : rien n'est validé par défaut, y compris la
> nouvelle conception.**
> **Périmètre** : ⛔ **LECTURE SEULE** — aucun fichier `CODE/` modifié, aucun commit, aucune écriture hors ce livrable.
> **Date** : 2026-09-20 · **Orchestrateur** : CC01 · **Criticité** : C1
> **Prédécesseur direct** : `CHALLENGE_T336_HOMING_HYPOTHESE_MONTEE_2026-09-20.md` (design abandonné — ses faits
> restent valides et sont re-cités ici, jamais recopiés).
> **Sources lues** : `CODE/G_CYCLE/FB_CycleMachineHoming.st` (685 l.) · `CODE/E_CODEURS/FB_Encoder_Homing.st` ·
> `FB_EncoderReliability.st` · `FB_Encoder_Safety.st` · `_TYPES/ST_Encoder_Calib.st` · `CODE/F_MODES/FB_Modes.st` ·
> `PRG_02_Acquisition.st` · `PRG_03_Modes_Cycle.st` · `PRG_04_Treuils_Benne.st` · `PRG_05_Translation.st` ·
> `FB_CycleSemiAuto.st` · `FB_Bucket.st` · `FB_Winch.st` · `FB_Safety_Winch.st` · `FB_WinchSync.st` ·
> `FB_SyncDeviation.st` · `FB_WinchCmdArbitrationM1/M2.st` · `FB_SpeedStep.st` · `FB_Joystick.st` ·
> `GVL_PERSISTENT.st` · `_TYPES/ST_fbMachineHomingCycle_Cfg.st` · `DOC/WFLOW/TASKS.yaml` (T340).

---

## 🚦 0 · Verdict en 6 lignes

1. 🔴🔴 **BLOCK sur le point 1** — la « position provisoire » **n'a aucun endroit où vivre** sans devenir un vrai
   `Homed` : `ST_Encoder_Calib` (`:9-21`) n'a **que** `HomingRefRaw` + `Homed`, et **toute** la chaîne de
   qualification est un **unique fil** `Calib.Homed → Homed → HomedAndReliable → BothAxesHomed → MachineHomed`
   (`FB_Encoder_Homing.st:264-290` · `FB_EncoderReliability.st:34` · `FB_CycleMachineHoming.st:196,594`). Pire : la
   fabrication du couple « M1 provisoire + M2 calé sur M1 » **est précisément ce qui rend `MachineHomed` vrai**
   (§2.3) — le faux datum est **auto-cohérent**, donc **indétectable** par tous les garde-fous existants.
2. 🔴 **BLOCK (aggravant)** — un `Homed := TRUE` provisoire **libère en plus** les protections **fail-safe** — plafond palier 1 ISO 13849 (`PRG_04:1226-1230`), butée logicielle haute + zone de ralentissement (`FB_Safety_Winch.st:581` · `FB_Winch.st:173-174`), **permits benne** (`PRG_04:1102-1111`), **interlock anti-collision M3** (`PRG_05:135-136`) :
   → qui **deviennent actives sur un datum faux**, et qui ouvrent une **plongée automatique en altitude/profondeur
   absolues** (`FB_CycleSemiAuto:412-413, 1000, 1093-1094, 1203, 1309-1310`). On passe donc de « protections inertes »
   à « protections actives et fausses » : c'est **strictement pire** que l'état actuel.
3. 🟢 **PASS sur le point 2** — l'interlock M3 (`PRG_05:134-138`) couvre **déjà** « zéro mouvement si non référencé » :
   c'est un **AND** (gate de référence `HomedAndReliable` **ET** seuil de hauteur 6,0 m), pas « seulement un seuil de
   hauteur ». **Ne rien écrire de nouveau.** ⚠️ Deux réserves (bypass mono-bit, symétrie d'enforcement T334) — §3.
4. 🟢 **PASS sur le point 3, avec une correction de constat** — le « palier 1 constante fixe, non réglable, sur tous
   mouvements treuils, dans tous les modes, tant que non référencé » **EXISTE DÉJÀ, à l'identique**, en `PRG_04:1217-1230`
   (littéral `1`, montée **et** descente, M1 **et** M2, agrégé tous modes, **non exposé à l'IHM** par choix documenté).
   Le risque n'est donc **pas** de l'implémenter : c'est de le **déplacer ou le dupliquer**. 🔴 **Mais 3 écarts
   vérifiés** démentent « palier 1 partout » (§4.4) — dont **un dans le scope T340** : `CST_StepSlow` du cycle est
   **du code mort en MAINT_N2** (l'arbitrage ignore `ReqWinch` hors SEMI_AUTO) ⇒ re-référencer une machine **encore
   référencée** peut se faire **à palier 5**, ce qui fait **échouer la capture** (10 mm / 50 ms). L'exigence utile
   serait **« palier 1 pendant le cycle de homing »**, pas « tant que non référencé ».
5. 🟠 **MAJOR sur le point 4** — le Plan B est implémentable **et partiellement déjà là** (le mécanisme « au repos »
   existe : `MachineHomingMechanicalStopOk`, `PRG_02:514-517`), **mais pas tel que décrit** : « à l'arrêt *après* le
   capteur » introduit une **erreur systématique = sur-course d'inertie** dans le datum (le preset est une **cote**,
   pas une mesure), et **emprunte la même descente `HX3` que le référencement au vol** — donc **ne le sécurise pas** — §5.
6. 🟠 **MAJOR sur le point 5** — **aucun deadlock pour l'opérateur** (chemin de sortie prouvé : expulsion vers
   `MAINT_N1` **jamais bloquée**, `FB_Modes:250-261` ; **et** référencement unitaire des 2 axes **dès `MAINT_N1`,
   sans jamais exécuter le GRAFCET ni la descente** — §6.2), **mais la conception n'attaque pas la cause racine déjà
   documentée** : le cycle exige une **descente `HX3`** interdite hors P1/Maintenance (T249-A) alors que **M3 est
   elle-même gelée** tant que les codeurs sont perdus (`M3Locked`, `FB_CycleMachineHoming.st:586` ; interlock hauteur,
   `PRG_05:134-138`) ⇒ **la nouvelle conception hérite de l'impasse « cycle bloqué »**, elle ne la résout pas — §6.

> 🧭 **Ce livrable n'est pas une décision.** Je propose des options (§8) et je remonte les questions à trancher (§9).
> **Aucune ligne de `CODE/` ne doit être écrite avant arbitrage humain** (la conception, telle que résumée, ne peut pas
> être implémentée sans choisir *où vit* la position provisoire — §2.1 et §2.5).

---

## 1 · Cadre, méthode et ce qui a changé depuis le challenge précédent

| # | Élément | Design abandonné (challenge précédent) | **Nouvelle conception T340** | Ce que ça change pour ma vérification |
|---|---|---|---|---|
| 1 | Instant de capture du datum | à la **montée**, front **montant**, au vol | **inchangé au fond** : vrai `Homed` **uniquement au franchissement réel du capteur mécanique haut** ; le « vol » est explicitement conservé, le Plan B s'ajoute | La contrainte **10 mm / 50 ms** du challenge précédent (§1.1 : `FB_Encoder_Homing.st:109-110, 241-249`) **reste entièrement valable** et n'est **pas** traitée par T340 |
| 2 | Position avant référencement | aucune (montée en aveugle) | **position PROVISOIRE** M1 (ex. 0) à la confirmation benne fermée | **C'est le seul vrai ajout de risque** → point 1, 🔴🔴 |
| 3 | Vitesse hors référencement | palier 1 (constaté) | palier 1 **demandé comme constante globale** | Constat : **déjà en place** (`PRG_04:1226-1230`) → point 3 |
| 4 | Translation M3 non référencée | blocage constaté (§1.3bis du précédent) | « zéro mouvement » **demandé** | Constat : **déjà en place** (`PRG_05:134-138`) → point 2 |
| 5 | Cycle auto non référencé | non traité | **bloqué à l'init** | Constat : **déjà en place, deux fois** (`FB_Modes:251` expulsion + `FB_CycleSemiAuto:834,843`) → §6 |
| 6 | Référencement à l'arrêt | — | **Plan B obligatoire** | Implémentable, mais pas comme décrit → point 4 |

> 🎯 **Constat de cadrage le plus important** : sur les **5 points** de la conception T340 (+ le Plan B), **3 sont déjà
> satisfaits par le code existant** (§3, §4, §6-1). Le delta réel de la conception se réduit donc à **trois sujets** :
> (a) la position provisoire, (b) le Plan B, (c) la reformulation « palier 1 pendant le cycle de homing » (§4.4-1).
> **Tout l'effort et tout le risque sont là.** Le reste du lot serait du code redondant — donc un risque de régression
> gratuit.

---

## 2 · Point 1 — 🔴🔴 BLOCK : la « position provisoire » ne peut pas rester provisoire

### 2.1 Il n'existe aucun contenant pour une position « non référencée »

| Fait | Source |
|---|---|
| `ST_Encoder_Calib` = **5 champs seulement** : `HomingRefRaw`, `LastKnownRawPos`, `RestartCoherenceTolerancePts`, `Homed`, `HomingSuspect` | `CODE/E_CODEURS/_TYPES/ST_Encoder_Calib.st:9-21` |
| **Aucun** champ « provisoire », « partiel », « dégradé » n'existe dans le projet (grep) | relevé |
| La position métrique est **entièrement dérivée** de `HomingRefRaw` : `CablePosM = (Raw − HomingRefRaw) × CableM/PointsPerRev` | `FB_Encoder_Scale.st:34-38` (cf. fiche T338) |
| Le **seul** producteur de `Homed` est `Calib.Homed` : `Homed := Calib.Homed AND NOT Calib.HomingSuspect` | `FB_Encoder_Homing.st:264-265, 290` |
| ⇒ **Donner une position à M1 = écrire `HomingRefRaw` + `Calib.Homed := TRUE`.** Il n'existe pas de troisième voie. | conséquence directe |

> ⛔ **La conception est incomplète sur son point central** : elle ne dit **pas** où vit la valeur provisoire.
> Tant que ce n'est pas tranché, **aucune ligne de code n'est écrivable** — c'est un cas d'arrêt au sens
> `AGENTS.md` § « Cas d'arrêt » (spec ambiguë).

### 2.2 Si la valeur provisoire passe par `Calib.Homed`, la fuite est **totale et immédiate** (chaîne unique)

| Étage | Expression | Source | Conséquence d'un `Homed` M1 provisoire |
|---|---|---|---|
| 1 | `Homed := Calib.Homed AND NOT Calib.HomingSuspect` | `FB_Encoder_Homing.st:290` | `Homed` M1 = **TRUE** |
| 2 | `HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent` | `FB_EncoderReliability.st:34` | `HomedAndReliable` M1 = **TRUE** (gate **« strict M3 »** assumé comme tel) |
| 3 | `BothAxesHomed := M1Status.HomedAndReliable AND M2Status.HomedAndReliable` | `FB_CycleMachineHoming.st:196` | **TRUE** dès que M2 est référencé |
| 4 | `MachineHomed := BothAxesHomed AND CommitOrOffsetValid AND NOT MachineHomingFailed AND NOT ReHomingAckRequired AND NOT Fault.Latched` | `FB_CycleMachineHoming.st:594-596` | **TRUE** → **datum machine déclaré valide** |
| 5a | `IF (SelMode = SEMI_AUTO) AND NOT MachineHomed THEN → MAINT_N1` | `FB_Modes.st:251-261` | L'expulsion **ne joue plus** ⇒ **SEMI_AUTO autorisé avec un datum faux** |
| 5b | `InitConditionsOk := HomedM1 AND HomedM2 AND NOT Fault.Latched AND InitPositionOk` | `FB_CycleSemiAuto.st:834, 843` | Le gate d'init du cycle **est franchi** ⇒ plongée autorisée |
| 5b-bis | 🔴 **Tout le cycle auto travaille ensuite en ALTITUDE/PROFONDEUR ABSOLUES** : consigne de profondeur `M1_CablePosM <= SetDepthM AND M2_CablePosM <= SetDepthM`, altitude de lancement Kobold, `TouchPositionM1/M2` et `StopPositionM1/M2` figés sur la position, fin de plongée, remontée contrôlée | `FB_CycleSemiAuto.st:412-413, 418-419, 1000, 1093-1094, 1125-1126, 1203, 1272-1281, 1309-1310` | 🔴 **Une plongée automatique pilotée par un datum faux** : profondeur atteinte fausse, arrêt de fond faux, seuils Kobold faux |
| 5b-ter | Posture de départ AX1 calée sur une **altitude absolue** : `CycleWinchesAtTopOk := … (ABS(CablePosM_M1 − CfgCableLimitAscent_M) <= CST_CycleInitWindowM) …` | `PRG_03:161-168` | 🟠 Condition de démarrage de cycle erronée |
| 5c | `IF NOT (HomedAndReliableM1 AND HomedAndReliableM2) THEN CommonMaxStepAscent := 1 …` | `PRG_04:1226-1230` | **Le plafond palier 1 est LEVÉ** ⇒ paliers 4/5 accessibles (jusqu'à 2,0 m/s, `GVL_PERSISTENT.st:27`) |
| 5d | `OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) …)` | `FB_Safety_Winch.st:581` | Butée **logicielle haute réactivée sur un datum faux** (ex. provisoire 0 ⇒ autorise 7,5 m de montée **réelle** de plus que la position vraie) |
| 5e | `InTopSlowdownZone := Sensors.Homed AND … (CablePosM >= TopLimitM − SlowdownDistanceTop_M)` | `FB_Winch.st:173-174` | Zone de ralentissement **activée au mauvais endroit** ⇒ arrêt/ralentissement fantôme en cours de manœuvre |
| 5f | `IF HomedAndReliableM1 AND HomedAndReliableM2 THEN <calcul DeltaPosM> … FaultActive := … (DeltaPosM > CfgSyncCriticalToleranceM)` | `FB_SyncDeviation.st:66, 81-82` | Surveillance d'écart M1/M2 **réactivée sur un Delta faux** ⇒ soit **SafeStop intempestif**, soit **masquage** d'un écart réel |
| 5g | `HomingPositionValid := HomedAndReliableM1 AND HomedAndReliableM2 AND NOT MachineHomingActive` | `FB_Bucket.st:195-197` | Contrôle d'écart benne **réactivé sur des positions fausses** |
| 5h | `BucketReferenced := TRUE` si `BucketRefRequest AND … HomedAndReliableM1 AND HomedAndReliableM2` | `FB_Bucket.st:394-398` | **Datum benne publié** comme valide (persistant, survit à la coupure, `:375-376`) |

> 🔴🔴 **Il n'y a pas « un consommateur » à risque : il y a une chaîne unique, sans point de contrôle croisé.**
> Le projet **l'assume** : le challenge précédent a déjà établi que « les deux axes reçoivent le même preset au même
> front ⇒ une divergence réelle devient **invisible pour toujours** » (`CHALLENGE_T336…:181`, trou T175-01). La
> nouvelle conception **ajoute** un faux datum **avant** ce point aveugle.

### 2.3 Le pire scénario n'est pas un bug : c'est la **cohérence** du faux datum (auto-validation)

| Fait | Source |
|---|---|
| « M2 se cale par rapport à M1 » = `BucketReferenceTargetM := M1.CablePosM + OffsetCloseM` | `PRG_02:531-534` |
| Cette confirmation exige seulement `Mode = MAINT_N2` + `MachineHomingMechanicalStopOk` | `PRG_02:521-525` |
| M2 reçoit donc **une cote dérivée de M1** ⇒ `Delta := M2 − M1 = OffsetCloseM = 15,0 m` | `GVL_PERSISTENT.st:67` |
| Et `IsClosed` est classé **sur ce même Delta** : `IsClosed := |Delta − OffsetCloseM| <= CoherenceLimitM` | `FB_Bucket.st:419-436` |

> 🧨 **Conséquence décisive** : un M1 provisoire à 0 + un M2 calé à « M1 + 15 m » produisent
> **`Delta = 15,0 m` = exactement l'offset de benne fermée attendu** ⇒ la machine se déclare
> **« référencée ET benne fermée ET cohérente »**, avec **deux** positions fausses et **aucun** signal discordant.
> Tous les garde-fous (parité M1/M2, cohérence benne, gate M3, gate SEMI_AUTO, plafond ISO 13849) sont franchis
> **par construction**, pas par accident. **C'est le piège caché de cette conception** — de la même famille que celui
> qui a fait abandonner la précédente, mais **plus profond** : il ne produit pas d'incohérence détectable, il produit
> une **cohérence fausse**.

### 2.4 Recensement exhaustif des consommateurs (audit dédié, contexte frais — complète §2.2)

> Audit `grep` exhaustif sur tout le dépôt (`\bHomed\b`, `MachineHomed`, `MachineHomedRaw`, `HomedAndReliable`,
> `HomingPositionValid`, `EncoderIncoherent`, `HomingSuspect`, `HomingRefRaw`, `ActiveOffsetValid`,
> `CommitOrOffsetValid`), `CODE/**/*.st` + `TOOLS/TEST_AUTO_CI/`, `ARCHIVES/` et `CODE_BACKUP/` exclus.

**Fait structurant** : il n'existe **qu'un seul écrivain** de référence — `Calib.Homed := TRUE` en
`FB_Encoder_Homing.st:265`, atteint uniquement après `PresetConfirmed` (relecture à 10 mm). **Aucun autre chemin**
n'écrit une référence ⇒ toute « position provisoire » passerait forcément par ce point, ou par une exception nouvelle.

**Sites qui basculent de comportement dès que `Homed`/`HomedAndReliable` passe TRUE — au-delà de §2.2 :**

| fichier:ligne | Expression | Rôle | Effet d'un `Homed` provisoire |
|---|---|---|---|
| `PRG_04:1102-1111` | `EffectivePermitBucket_Open/Close := EffectivePermitM2_Descend AND EncoderM1.Homed AND EncoderM2.Homed AND …` | **sécurité / permit benne** | 🔴 **ouverture/fermeture benne autorisée** sur un datum non prouvé |
| `PRG_04:845-852` | `OverrideTopSoftwareN1M1 := MaintN1 AND EncoderM1.Homed AND NOT HomingSuspect AND …BtnOverrideTopSoftware` | gate mode (relèvement 7,5 → 8,5 m) | 🔴 ouvre l'approche **du seul capteur physique** |
| `FB_Modes.st:148-153` | `IF MaintHomingRequiredM1 AND M1HomingDone AND M1Homed AND NOT M1HomingSuspect THEN MaintHomingRequiredM1 := FALSE;` | **purge d'obligation de re-homing** | 🔴 **l'obligation de re-homing est levée SANS homing réel** |
| `FB_CycleMachineHoming.st:226-229, 449-452, 461-463` | `AutoArmCandidate := … AND NOT MachineHomed …` / `IF MachineHomed … THEN SeqStep := HX0_REPOS` | automatisation du cycle | 🔴 **effet INVERSÉ** : le faux datum **supprime la proposition automatique de homing** ⇒ la machine **ne propose plus de se re-référencer** |
| `FB_Bucket.st:274-279` | `HomingMotionWithoutReference := (mouvement demandé) AND NOT MachineHomingActive AND NOT (HomedM1 AND HomedM2)` | défaut **live** → `SevereError` → coupe la séquence benne | 🔴 le défaut **disparaît** ⇒ la protection live ne coupe plus rien |
| `FB_WinchStateProjection.st:219-226` | `CableLimitAscentM1Reached := EncoderM1.Homed AND NOT HomingSuspect AND NOT HomingLifecycle.Busy AND (CablePosM >= CfgCableLimitAscent_M)` | fait → posture AX1 (`PRG_03:161-168, 232`) | 🟠 **posture de départ erronée** ⇒ AX1 franchi à tort |
| `FB_Bucket.st:421` | `ClassCanRun := HomedM1 AND HomedM2 AND NOT SevereError` | classification benne | 🔴 `IsClosed`/`IsOpen`/`TooOpen`/`LastPosM2Close` **calculés sur un repère faux** |
| `FB_Bucket.st:195-200` | `HomingPositionValid := … AND NOT MachineHomingActive` → `OffsetMaxViolNow := …` | sécurité (Cause 1 **latchée**) | 🟠 soit faux latch, soit garde-fou inerte |
| `FB_Acquisition_Preflight.st:82-83` | `IF NOT HomedM1 OR NOT M1PositionInBounds THEN PreflightErrorId := PreflightErrorId OR 16#4000` | diag | 🔵 verdict preflight faussement vert |

**Verrous capables de faire retomber le drapeau — la liste est courte (2) :**
`EncoderIncoherent` (`FB_Encoder_Safety.st:53,57,81` — **bornage ±99 m** et `HomingSuspect`) et
`Calib.HomingSuspect` (`FB_Encoder_Homing.st:290`). ⇒ **Aucun de ces deux verrous ne détecterait une position
provisoire « plausible »** (0 m est dans les bornes, et `HomingSuspect` n'est posé qu'au contrôle de cohérence
**au boot**, `:181-190`).

**⚠️ Automatisations déclenchées par un `Homed := TRUE` forcé sur M1 (`Homed` seul, sans `HomedAndReliable`) :**

| # | Automatisation | Fait | Verdict |
|---|---|---|---|
| A1 | Levée de l'obligation de re-homing | `FB_Modes.st:148-150` (armement `:140-145`, miroir PERSISTENT `GVL_PERSISTENT.st:182`) | 🔴 **OUI — sans homing réel** |
| A2 | Référence benne persistante | `FB_Bucket.st:394-398` → `ActiveOffsetValid` (`:745-748`) → `SyncOperationPermit` (`PRG_04:435`) | 🔴 **OUI, indirect** (un `BucketRefRequest` déjà latché est consommé automatiquement) |
| A3 | Disparition des causes **live** | `FB_Bucket.st:274-279` (`Latching := FALSE`) ⇒ `Fault.Error` FALSE ⇒ `SevereError` FALSE ⇒ séquence benne **non coupée** | 🔴 **OUI** |
| — | Purge de défaut **latché** | `FB_FaultCore.st:63-68` : latch effacé **uniquement** sur front `Reset` | ✅ **NON** — pas de contournement du `Reset` conscient |
| — | Auto-armement HX0→HX1 | `FB_CycleMachineHoming.st:226-229` | ⚠️ **NON, mais INVERSÉ** (cf. tableau ci-dessus) — la machine cesse de proposer le homing |

**Nuance métrologique importante (Q2 de l'audit)** : la **valeur** d'offset benne est un **delta pur**
(`FB_Bucket.st:684` : `OffsetTargetM := CablePosM2 - CablePosM1`), mais **son usage est absolu dans le repère M1**
(cibles mêlant `CablePosM2` et `CablePosM1 + Offset` : `FB_Bucket.st:522, 538, 566, 592, 624, 636`).
⇒ **Toute écriture de `HomingRefRaw` sur M1 décale `Delta` d'autant** ⇒ `IsClosed`/`IsOpen`, `RemainingTravelM`,
seuils d'arrêt : **tout est faux ensemble** (§2.3).

### 2.5 Verdict point 1 et options (je ne tranche pas)

**🔴🔴 BLOCK** — la conception, telle que résumée dans T340, **n'est pas implémentable en sécurité** :
elle exige d'écrire `Homed`, et `Homed` est un **fait binaire sans nuance** partagé par **toute** la machine.

| Option | Principe | Effort | Risque résiduel | Commentaire |
|---|---|---|---|---|
| **1-A — Ne pas créer de position provisoire du tout** | Le besoin réel invoqué (« mouvement **synchronisé** à petite vitesse ») est obtenu **sans position** : palier 1 **déjà imposé** (§4), commande **symétrique** M1/M2 (mêmes `StepTgt`, mêmes rampes, même sens), et surveillance d'écart sur les **deltas bruts** (indépendants du datum) | **M** | 🟢 **Faible** — aucune écriture de `Homed`, aucun consommateur à re-auditer | 🥇 **La seule option sans fuite possible.** Elle répond à la lettre à l'exigence « mouvement synchronisé à petite vitesse » |
| **1-B — Nouveau fait explicite `DatumProvisional`** (champ dédié + gate séparé, **jamais** `Homed`) | Ajouter un état de datum à **3 valeurs** (aucun / provisoire / vrai), et **ré-auditer les ~75 sites** de `Homed`/`HomedAndReliable`/`MachineHomed` pour que **chacun** exige le niveau qu'il lui faut | **L** (> 3 j) | 🔴 **Élevé** — surface énorme, un seul oubli = §2.2 ; viole « producteur unique » si un 2ᵉ flag dérive | À ne retenir que si l'utilisateur **exige** une position chiffrée avant référencement — et alors sous contrat C3/C4 + tests dédiés |
| **1-C — Position provisoire mais `Homed` interdit partout** | Même chose que 1-B, mais la valeur ne circule **que** dans les fonctions de **confort** (affichage/diagnostic), jamais dans une fonction de conduite ou de sécurité | **M** | 🟠 **Moyen** — nécessite un garde-fou automatique (gate) interdisant tout usage de la valeur provisoire hors IHM | 🟡 Compromis si l'opérateur veut « voir quelque chose » à l'écran |

> ⚠️ **Aucune de ces options ne doit être choisie ici.** Le choix **appartient à l'utilisateur** (§9, Q-1).

---

## 3 · Point 2 — 🟢 PASS : l'interlock M3 couvre **déjà** « zéro mouvement si non référencé »

### 3.1 Le code, exactement

```pascal
// PRG_05_Translation.st:134-139
M3_HeightInterlockOk := GVL_IHM.M3Translation.Bypass.MinHeight          // (0) bypass dédié, UN SEUL bit
                        OR (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable   // (a) GATE DE RÉFÉRENCE
                            AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable
                            AND (…EncoderM1.Measurement.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M)  // (b) GATE DE HAUTEUR
                            AND (…EncoderM2.Measurement.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M));
TranslationState.HeightInterlockBlocking := NOT M3_HeightInterlockOk;
```

| Question de la mission | Réponse sourcée |
|---|---|
| Couvre-t-il « zéro mouvement si non référencé » ? | ✅ **OUI** — le terme **(a)** est exactement « non référencé ⇒ pas de translation ». Le commentaire de conception le documente comme tel : « hauteur non confirmée = interlock actif (comme une hauteur insuffisante) » (`PRG_05:128-130`) |
| Ou **seulement** un seuil de hauteur différent ? | ❌ **NON** — c'est un **AND** de deux gates distincts. Le seuil 6,0 m **(b)** est une **exigence supplémentaire** (anti-télescopage), pas un substitut |
| Doctrine | « Interlock hauteur M3 strict `HomedAndReliable` M1∧M2 … ✅ conforme, **ne pas assouplir** » (`DECISIONS_T146_ARBITRAGE_ISO13849.md:100`) |

> 🎯 **VERDICT : le besoin utilisateur est DÉJÀ couvert — ne rien écrire.** Ajouter un second interlock « zéro
> mouvement M3 » créerait **deux producteurs** pour la même interdiction (violation `CODE_QUALITY_STANDARDS §10.2` /
> producteur unique) et un risque de **divergence** entre les deux.

### 3.2 Deux réserves à traiter séparément (ne bloquent pas T340)

| # | Réserve | Source | Nature |
|---|---|---|---|
| R2.1 | 🟠 **Le bypass dédié lève les DEUX gates d'un seul bit.** `Bypass.MinHeight` est **OR**-é en tête d'expression : il annule donc **aussi** le gate de référence — alors que son libellé ne parle que de hauteur. Contrairement aux overrides de position treuil (qui **arment** `MaintHomingRequiredM1/M2`, `FB_Modes:140-145`), ce bypass ne laisse **aucune conséquence** (pas de re-homing obligatoire, pas de latch tracé côté treuils) | `PRG_05:134` · `ST_BypassTranslation.st:19` · `FB_Modes:140-153` | 🔵 **Décision de conception à arbitrer** : la nouvelle exigence « **zéro** mouvement tant que non référencée » est-elle **absolue** (⇒ le bypass ne doit plus lever le gate (a)) ou **dérogatoire traçable** (⇒ statu quo) ? |
| R2.2 | 🟠 **Symétrie d'enforcement non prouvée.** L'interlock est publié puis consommé par l'arbitre M3 (`ArbM3_Context.HeightInterlockOk`, `PRG_05:360` → `FB_TranslationCmdArbitrationM3.st:72,105`), mais **T334 est ouverte** précisément parce que M3 a **deux chemins de commande** (manuel/MAINT vs cycle auto) qui ne s'arrêtent pas pareil à P1/Trémie | `TASKS.yaml` T334 (⏳, DSH07) · fiche `TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md:87` | 🟠 **Chantier existant, hors T340** — mais « zéro mouvement » ne sera **vrai** qu'une fois T334 clos |
| R2.3 | 🔵 **Cote dérivée en dur** : `_TranslationMinHeightM1M2_M := 6.0` commentée « ≈ `CfgTopSensorPos_M` 8,0 m − 2,0 m » alors que `CfgTopSensorPos_M = 8.5` ⇒ dérive **déjà matérialisée** | `GVL_PERSISTENT.st:90-93` · `GVL_PERSISTENT.st:41,49` | 🔵 **Question ouverte Q6 de `CADRAGE_T330_INVARIANT_HAUT_v1.0.md:1021`**. ⚠️ **Si T340 touche la cible de homing, cette constante doit suivre** (sinon l'interlock devient faux) |

### 3.3 Verdict point 2

**🟢 PASS** — exigence **déjà satisfaite** par `PRG_05:134-138` (gate de référence inclus, pas seulement la hauteur).
**Aucune ligne à écrire.** Deux points à **arbitrer séparément** (R2.1 bypass, R2.2 T334), un à **surveiller** (R2.3).

---

## 4 · Point 3 — 🟢 PASS / ⚠️ correction de constat : le palier 1 global **existe déjà, à l'identique**

### 4.1 Le garde-fou demandé est en place, mot pour mot

```pascal
// PRG_04_Treuils_Benne.st:1217-1230  (§5ter « Agrégateur de clamp de palier »)
MaintenanceMaxStepAscent  := 1;   // « Ces valeurs ne sont volontairement pas exposées comme consignes IHM :
MaintenanceMaxStepDescent := 1;   //  une IHM ne doit pas pouvoir relever un garde-fou de vitesse. »

// SECURITE ISO 13849 - posture fail-safe : bridage vitesse hors homing.
// Codeurs non references => position non fiable => plafond palier 1 sur M1 ET M2, montee ET descente.
IF NOT (…EncoderM1.HomedAndReliable AND …EncoderM2.HomedAndReliable) THEN
    CommonMaxStepAscent  := 1;
    CommonMaxStepDescent := 1;
END_IF;
```

| Exigence T340 | État dans le code | Source |
|---|---|---|
| Palier 1 **sur tous les mouvements treuils** | ✅ `CommonMaxStepAscent/Descent` → `ReqM1Winch.MaxStepUp/MaxStepDown` (`:1382-1383`) → consommé par `FB_Winch` | `PRG_04:1210-1211, 1382-1383` |
| **Dans les deux sens** | ✅ montée **et** descente | `PRG_04:1228-1229` |
| **Dans tous les modes** | ✅ l'agrégateur §5ter est **unique** et s'applique après l'arbitrage M1/M2 (manuel, MAINT_N1/N2, SEMI_AUTO) | `PRG_04:1203-1230` (avant `§6 Exécution` `:1322`) |
| **Tant que non référencé** | ✅ conditionné sur `NOT (HomedAndReliable M1 AND M2)` | `PRG_04:1226-1227` |
| **CONSTANTE FIXE, pas un paramètre** | ✅ **littéral `1`**, et l'exposition IHM est **explicitement refusée** par commentaire de conception | `PRG_04:1213-1218` |
| **Symétrie M1/M2** (anti-vecteurs contacteurs) | ✅ source commune imposée aux deux axes (M2 ne peut que **réduire** ensuite) | `PRG_04:1210-1211, 1265-1266` |
| Règle de priorité | ✅ « le plafond gagne » (le clamp final est appliqué côté `FB_Winch`) | `PRG_04:1258-1260` |

### 4.2 Pourquoi toucher à ce garde-fou serait un **risque de régression gratuit**

| Risque | Détail | Source |
|---|---|---|
| **Double producteur du palier** | La doctrine actuelle est explicite : « **le joystick est le producteur UNIQUE du palier** » ; M1/M2 ne font que consommer `Joystick.AxisY.StepTgt` ou `ReqWinch.StepTgt` | `FB_WinchCmdArbitrationM1.st:65-67, 93-98` · `FB_WinchCmdArbitrationM2.st:94-127` |
| **Contournement du « plafond gagne »** | Un clamp ajouté **en aval** de l'agrégateur pourrait **relever** un plafond déjà réduit (synchro, benne, position Maintenance) — interdit par la règle écrite | `PRG_04:1258-1260, 1269-1270` |
| **Placebo déjà identifié** | `Auth.HomingApproachEnable` **ne lève pas** la butée haute : son effet réel est un **plafond palier 1** — le challenge précédent l'a qualifié de **« placebo au regard de son libellé »**. Un 3ᵉ mécanisme « palier 1 » multiplierait ce type de confusion | `ST_CommunCfg.st:13` vs `FB_Modes.st:344` · `CHALLENGE_T336…:109` |
| **Aucun besoin fonctionnel exprimé** | Le palier 1 est **déjà** le régime du homing : `CST_StepSlow := 1` en `HX2`/`HX3` | `FB_CycleMachineHoming.st:162, 479-480, 507-508` |
| **Aucun besoin « benne » exprimé non plus** | Le cas « benne non fermée » dégrade **déjà** au palier 1 (couplé : les 2 treuils, `:1243-1245`), et le jog benne non référencé est **déjà** plafonné à 1 | `PRG_04:1239-1245, 1292-1306` |

### 4.3 Nuance à trancher (jamais un défaut)

| Observation | Détail |
|---|---|
| Le clamp existant est indexé sur `HomedAndReliable` (**axes**), alors que T340 écrit « si M1 **ou M2 ou benne** n'est pas Homed » | Le terme **benne** n'entre **pas** dans le clamp. Ce n'est **pas** un trou : (a) le datum benne n'affecte pas la fiabilité de la **mesure** de position ; (b) `MachineHomed` (qui **inclut** le commit benne, `FB_CycleMachineHoming.st:594`) **expulse déjà** SEMI_AUTO (`FB_Modes:251`). Étendre le clamp à la benne **briderait** le jog de maintenance sans gain de sécurité → **à ne pas faire** sauf raison explicite |
| ⚠️ **« Palier 1 » n'est pas une vitesse caractérisée** : dans la table, le palier 1 = **aucun contacteur de vitesse** (`P1R1..P1R4 := FALSE`) ⇒ la vitesse réelle est la **vitesse 1 du variateur**, et l'intervalle associé est déclaré **« provisoire à mesurer »** (`SpeedBandMaxMps[1] = 0.4`, `MaxSpeedMps[1] = 0.5`) | `GVL_PERSISTENT.st:16-28` · `FB_SpeedStep.st:74` · `ST_fbWinchSpeedLearning_Cfg.st:10`. ⇒ **Toute conclusion chiffrée sur « palier 1 » (temps de montée, sur-course, répétabilité) exige une mesure préalable** (cf. §10 · A1 et §8-D) |
| ⚠️ **Aux paliers 1, la surveillance *matérielle* d'écart contacteurs est inopérante** : `FB_SyncContactor` compare explicitement les paliers **P4/P5** (`Contactor1_M1 = SpeedStepTable.P4R1 …`) | `FB_SyncContactor.st:112-120`. ⇒ la synchronisation M1/M2 au palier 1 repose **uniquement** sur la mesure de position (`FB_SyncDeviation`, gated `HomedAndReliable`) ⇒ **à palier 1 sans datum, il ne reste AUCUNE synchronisation** — argument **décisif** pour l'option 1-A (§2.5) : c'est **le** besoin à traiter, et il se traite sur les **deltas bruts**, pas sur un faux datum |

### 4.4 🔴 Trois écarts vérifiés entre l'exigence « palier 1 » et le code réel

> Ces écarts **ne font pas échouer** le verdict §4.5 (le garde-fou ISO existe et fonctionne), mais ils
> **démentent l'hypothèse « le palier 1 s'applique partout »** sur 3 points précis. Deux sont **hors scope**
> (§10 · A5/A6), le premier est **dans le scope de T340**.

**(1) 🔴 Le palier de la MONTÉE DE HOMING n'est pas garanti par le cycle — il vient du joystick**

| Fait | Source |
|---|---|
| Le cycle émet bien `CmdWinchM1/M2.StepTgt := CST_StepSlow` (= 1) en `HX2`/`HX3` | `FB_CycleMachineHoming.st:162, 479-480, 507-508` |
| Ces ordres sont recopiés dans `ReqProgram.ReqWinchM1/M2` **uniquement en `MAINT_N2`** | `PRG_03:386-390` |
| 🔴 **Or l'arbitrage IGNORE `ReqWinch` hors `SEMI_AUTO`** : `IF Auth.Mode = E_Mode.SEMI_AUTO THEN … StepTgt := ReqWinch.StepTgt ELSE <boutons/joystick> …` | `FB_WinchCmdArbitrationM1.st:56-104` · `FB_WinchCmdArbitrationM2.st:85-133` |
| ⇒ En `MAINT_N2` (le **seul** mode où le cycle peut bouger, `:464`), `CST_StepSlow` est **du code mort** : le palier réel vient du **joystick** (`Joystick.AxisY.StepTgt`, 1..5) ou des boutons (`Cfg.BtnStepTgt := 5`) | idem · `PRG_04:512-513` |
| ⇒ Le **seul** garde-fou qui bride réellement cette montée est le clamp agrégé `IF NOT (HomedAndReliable M1 AND M2) THEN … = 1` | `PRG_04:1226-1230` |
| 🔴 Donc : **re-référencer une machine dont les codeurs sont ENCORE référencés** (cas explicitement prévu : « seul le bouton IHM dédié `StartEdge` peut RE-référencer une machine déjà homed », `FB_CycleMachineHoming.st:441-444`) ⇒ **le clamp ne s'applique pas** ⇒ l'opérateur peut monter à **palier 5** pendant `HX2` | chaîne ci-dessus |
| ⇒ et cette montée franchit le capteur **à vitesse de croisière** ⇒ la transaction preset (10 mm / 50 ms) **échoue** ⇒ `HomingSuspect`/`PresetConfirmationFailed` (constat déjà établi, `CHALLENGE_T336…:96-122`) | `FB_Encoder_Homing.st:109-110, 249, 271-276` |

> 🎯 **Conséquence décisive pour T340** : l'exigence « palier 1 constant **tant que non référencé** » **laisse
> précisément sans protection le cas de re-référencement d'une machine encore référencée** — qui est le cas d'usage
> le plus fréquent (recalage après doute, changement de benne, reprise après maintenance). Si l'intention réelle est
> « **le homing se fait toujours à palier 1** », l'exigence doit être reformulée en **« palier 1 pendant le cycle
> de homing »** (condition `MachineHomingActive`), pas seulement « tant que non référencé ». **C'est probablement
> l'apport le plus utile de ce challenge au besoin utilisateur.**

**(2) 🟠 « Palier 1 Vitesse Lente » : les boutons N2 qui portent ce libellé ne commandent AUCUN mouvement**

| Fait | Source |
|---|---|
| 6 boutons déclarés sous le libellé « Commandes Mouvements N2 (**Palier 1 Vitesse Lente**) » : `BtnM1Ascent`, `BtnM1Descend`, `BtnM2Ascent`, `BtnM2Descend`, `BtnBothAscent`, `BtnBothDescend` | `ST_MaintenanceN2Cmd.st:8-14` |
| 🔴 **Aucun n'est consommé par une logique de mouvement** (grep exhaustif) : seul `MaintenanceN2.Cmd` consommé = les 3 `*BrakeRelease` (freins) + un **indicateur d'affichage** `State.ActiveForcing` | `PRG_06:323-329` (freins) · `PRG_07:776-788` (indicateur) |
| Les boutons de mouvement **réellement câblés** sont ailleurs : `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent/BtnDescent`, `GVL_IHM.M2TreuilBenne.Cmd.*`, `GVL_IHM.Commun.BtnWinchBoth*` | `PRG_04:481-486` → `FB_WinchCmdArbitrationM1.st:75-82` |

> 🚨 **Piège à connaître avant toute décision de conception** : si le besoin « treuils synchronisés à petite vitesse
> pour se dégager » (étape 1 de T340) est censé s'appuyer sur ces boutons N2, **il ne fonctionne pas**. Ils
> **mentent sur leur libellé** — même famille que le `SelHomingApproachEnable` qualifié de « placebo » par le
> challenge précédent (`CHALLENGE_T336…:109`).

**(3) 🟠 Trou du clamp palier 1 pour M2 (jog benne)** — détail et conditions d'atteinte : **§10 · A5**.

### 4.5 Verdict point 3

**🟢 PASS — exigence déjà satisfaite ; ⛔ ne rien implémenter, ne rien déplacer.** La demande de T340 est un
**constat tardif** de l'existant, pas un besoin nouveau. ⚠️ **Recommandation forte** : inscrire cette conclusion dans
le contrat T340, sinon le lot produira un **duplicata** du garde-fou ISO 13849 — exactement le type de dette que T330
cherche à résorber.

---

## 5 · Point 4 — 🟠 MAJOR : le Plan B est implémentable, **mais pas tel que décrit**

### 5.1 Ce qui existe déjà (et qui est réutilisable)

| Mécanisme « au repos » existant | Définition | Source | Réutilisable pour le Plan B ? |
|---|---|---|---|
| **`MachineHomingMechanicalStopOk`** — le composite canonique « M1 **ET** M2 au repos » | `M1_ContactorsReleased AND NOT M1_BrakeIsOpen AND |Speed_M1| < 0.02 AND` idem M2 | `PRG_02:514-517` | ✅ **C'est exactement le besoin.** Déjà injecté dans le cycle sous le nom `WinchesMechanicallyStopped` | `PRG_02:551` · `FB_CycleMachineHoming.st:26, 498, 532, 547` |
| **`ModeChangeAllowed`** (même composite + freins) | contacteurs retombés + frein serré + vitesse < 0,02 m/s, **les deux treuils** | `FB_Modes:226-229` | ✅ Réutilisation possible (mais `PRG_02` est le bon producteur) |
| **`DiveStartStopped`** (précédent cité par la mission) | `M1/M2_SpeedValid AND ContactorsReleased AND BrakeApplied AND |Speed| < seuil` | `FB_CycleSemiAuto.st:284-288` | ✅ Preuve que le patron est **généralisé** dans le projet |
| **`SettleGraceTimer` / `CST_SettleGrace := T#3s`** — fenêtre de stabilisation à l'entrée d'un step d'arrêt | Déjà armée en `HX2N`/`HX3N`/`HX4`/`HX5` | `FB_CycleMachineHoming.st:161, 205-208` | ✅ **Le « après stabilisation inertie » demandé existe déjà comme primitive** |
| **Référencement à l'ARRÊT déjà câblé** | `NominalHomingTrigger := HomingModeOk AND NOT UseDynamicTarget AND ((Home AND TopSensorEdge.Q) OR (HomeEdge.Q AND TopPositionSensor))` → **un front `Home` avec le capteur actif** référence à `CfgTopSensorPosM` **sans mouvement** | `FB_Encoder_Homing.st:206-207, 219-220` | ✅ **Le Plan B est déjà possible manuellement** : en `MAINT_N1/N2`, treuils au repos, capteur haut actif ⇒ bouton `BtnHome` ⇒ référencement nominal à 8,5 m (`HomingPermit` accepte `MachineHomingMechanicalStopOk`, `PRG_02:601-603, 654-656`) |
| **Confirmations benne déjà « à l'arrêt »** | `BucketReferenceRequested` **exige** `Mode = MAINT_N2` **ET** `MachineHomingMechanicalStopOk` | `PRG_02:521-525` | ✅ **Précédent direct** : c'est le patron « confirmation opérateur à l'arrêt » déjà accepté sur cette machine |

> 🎯 **Bonne nouvelle** : le Plan B **n'exige aucune invention**. Le couple (composite « au repos » + fenêtre de
> stabilisation + trigger `Home` à l'arrêt) est **déjà** dans le code. L'effort est de **l'intégrer au GRAFCET**,
> pas de le créer. **Effort : M.**

### 5.2 🔴 Pourquoi « à l'arrêt *après* le capteur » n'est **pas** proprement implémentable

| Fait | Source | Conséquence |
|---|---|---|
| Un référencement **écrit une CÔTE** : `PendingHomingRefRaw := RawPos − TargetPoints`, avec `TargetPoints = TargetPositionM × Pts/tr` | `FB_Encoder_Homing.st:229-230` | La cote appliquée est **`TargetPositionM`**, pas « la position où l'on se trouve » |
| `TargetPositionM` = `CfgTopSensorPosM` (**8,5 m**) en nominal, et = `CfgHomingTargetM` = `_WinchM1CfgPersist.CfgTopSensorPos_M` (**8,5 m**) en unitaire hors `BtnHomingAtZero` | `FB_Encoder_Homing.st:219-222` · `PRG_02:610-612, 664-666` · `GVL_PERSISTENT.st:41` | ✅ Bonne nouvelle : **les deux chemins visent la même cote** — pas de piège de cible (le doute est levé) |
| ⇒ Si le déclenchement a lieu **après** le franchissement (position d'arrêt = capteur **+ sur-course**), alors la **position réelle** = `8,5 m − sur-course` est **écrite 8,5 m** | conséquence directe | 🔴 **Erreur systématique = la sur-course d'arrêt**, variable (vitesse, charge, rampe), **non instrumentée aujourd'hui** (`CADRAGE_T330…:179-187, P7`) |
| La vérification de transaction **ne détecte pas** cette erreur : elle contrôle la **cohérence de la relecture**, pas l'exactitude géométrique (`ReadbackOk` compare la position recalculée à la cible **écrite**, tolérance 10 mm) | `FB_Encoder_Homing.st:243-249` | 🔴 Un décalage de datum **faux de plusieurs cm** passerait **toutes** les vérifications ⇒ puis se propage à `Delta`, `IsClosed`, butées, gate M3 |
| Aggravant : la transaction preset n'accepte que **10 mm pendant 50 ms** ⇒ **0,20 m/s implicite** | `FB_Encoder_Homing.st:109-110, 241-249` (établi par le challenge précédent, §1.1) | ⚠️ Le Plan B « après inertie » doit donc être déclenché **réellement à l'arrêt** — sinon il transforme un échec de capture en **datum faux silencieux** |

> ⛔ **Conclusion** : « référencement à l'arrêt après le capteur » **n'est pas** une variante du référencement au vol —
> c'est une **autre métrologie**, avec un **biais systématique**. Elle n'est acceptable que si le biais est
> **mesuré et borné** (campagne de mesure) **ou** si le déclenchement est déplacé **là où la cote est vraie**.

### 5.3 🟠 Le Plan B emprunte **la même descente interdite** que le référencement au vol

| Fait | Source |
|---|---|
| Le franchissement capteur exploité par le cycle est le **front DESCENDANT** : `IF TopLostEdge.Q AND NOT HomeReqDone THEN M1Demand.HomeReq := TRUE; M2Demand.HomeReq := TRUE` | `FB_CycleMachineHoming.st:510-515` |
| Ce front n'existe qu'en **`HX3_HOME_AXES`**, qui **commande une DESCENTE** M1+M2 | `FB_CycleMachineHoming.st:504-509` |
| La descente treuil est **interdite** hors P1/Maintenance (T249-A) : `IF NOT WinchDescentAuth_M3 THEN ProcessAndSafetyPermitM1_Descend := FALSE` | `PRG_03:463-468` · `PRG_04:1067-1074` |
| ⇒ **Plan B « à l'arrêt après le capteur » suit le MÊME chemin `HX2 → HX3 → arrêt`** | conséquence directe |

> 🧨 **Le Plan B ne « sécurise » donc PAS le référencement au vol : il le double sur le même chemin défaillant.**
> Si la cause terrain est l'impasse `HX3` (§6), **les deux** échouent ensemble. Une variante réellement
> indépendante devrait **ne pas descendre** : par exemple **remonter à palier 1 jusqu'à la ré-activation du capteur**
> et déclencher `Home` **sur le front montant à l'accès** — ce que la transaction preset accepte (vitesse palier 1,
> `NominalHomingTrigger` sur `TopSensorEdge`), au prix d'un **écart ≤ 1 cycle** (≈ mm) — **option 4-B** ci-dessous.

### 5.4 Options Plan B (je ne tranche pas)

| Option | Principe | Effort | Risque résiduel |
|---|---|---|---|
| **4-A — Plan B = « arrêt sur le capteur, encore actif »** | `HX2` monte, s'arrête **capteur actif** (avant le front descendant), `WinchesMechanicallyStopped` + `SettleGrace` écoulé ⇒ `HomeReq` (**chemin nominal déjà câblé**, `FB_Encoder_Homing.st:206-207`) | **M** | 🟢 Biais = distance de stabilisation **avant** le front (mesurable) · mais 🔴 **conserve `HX3` pour le reste du cycle** (benne) ⇒ impasse T249-A **non levée** |
| **4-B — Plan B = « remontée de ré-accrochage »** | Après sur-course, **remonter** à palier 1 jusqu'au **front MONTANT** du capteur, déclencher `Home` à faible vitesse ⇒ cote exacte au point d'enclenchement | **M** | 🟢 **Indépendant de la descente** ⇒ immunisé à T249-A · 🟢 écart borné (≤ 1 cycle) · 🔴 **nouveau step GRAFCET** (`E_MachineHomingTxState` + `E_MachineHomingStep`) + **interaction Méca D au TOP** à re-qualifier |
| **4-C — Plan B = geste opérateur (statu quo amélioré)** | **Déjà disponible** : `MAINT_N1`/`N2`, treuils au repos **ou** FdC haut atteint, bouton `BtnHome` (`PRG_02:601-604, 654-657`) ⇒ référencement nominal **sans aucune descente** ⇒ **immunisé à T249-A** (l'option est en réalité plus qu'un statu quo : c'est un chemin complet de récupération, §6.2). Il suffit de **guider l'opérateur** (message IHM du guide `§10`) au lieu d'automatiser | **S** | 🟢 Aucun code de sécurité touché · 🟢 **accessible dès `MAINT_N1`** · 🟠 Dépend de la discipline opérateur (mais **`BucketReferenceRequested` suit déjà ce patron**, `PRG_02:521-525`) |
| **4-D — Plan B = les deux instants** | Autoriser **vol (front descendant) OU arrêt (front montant)**, mesurer lequel a réellement servi, tracer l'écart | **M+L** | 🟠 Complexité ; 🔴 impose de **réconcilier deux métrologies** dans un datum unique |

> ⚠️ **Aucune n'est décidée ici.** Point d'attention commun : **toute** variante « à l'arrêt » doit **borner
> explicitement le biais** (campagne de mesure, comme l'exige déjà le challenge précédent §8-D).

### 5.5 Verdict point 4

**🟠 MAJOR** — Plan B **implémentable** (primitives existantes, effort **M**), **mais** : (a) pas dans la forme
décrite (« après inertie » ⇒ biais systématique non borné) ; (b) **non indépendant** du référencement au vol tant
qu'il passe par `HX3` ⇒ il ne peut pas servir de **filet de sécurité** ; (c) une variante **manuelle existe déjà**
(4-C) et couvre probablement le besoin à coût quasi nul.

---

## 6 · Point 5 — 🟠 MAJOR : pas de deadlock opérateur, **mais la cause racine n'est pas traitée**

### 6.1 « Cycle auto bloqué à l'init si M1/M2/benne non Homed » — 🟢 **déjà en place, deux fois**

| Étage | Fait | Source | Effet |
|---|---|---|---|
| 1 | `SemiAutoCycleNotReadyMachineHoming := (SelMode = SEMI_AUTO) AND NOT MachineHomed` (diagnostic) | `FB_Modes.st:161, 171-173` | info IHM |
| 2 | **Expulsion** : `IF (SelMode = SEMI_AUTO) AND NOT MachineHomed THEN Auth.Mode := MAINT_N1` | `FB_Modes.st:246-261` | 🔒 **le mode SEMI_AUTO est refusé**, motif publié (« SEMI_AUTO refuse : datum machine absent » / « Datum machine perdu : arret controle ») |
| 3 | `InitConditionsOk := HomedM1 AND HomedM2 AND NOT Fault.Latched AND InitPositionOk` sinon `State` reste bloqué en `AX1_INIT` avec consigne opérateur explicite | `FB_CycleSemiAuto.st:834, 843-849` | 🔒 **défense en profondeur** dans le cycle lui-même |
| 4 | `MachineHomed` **inclut** le datum benne : `BothAxesHomed AND CommitOrOffsetValid AND …` | `FB_CycleMachineHoming.st:594-596` | ✅ l'exigence « M1 **ou** M2 **ou benne** » est **déjà** couverte |

> 🎯 **Verdict : exigence déjà satisfaite — et même plus strictement que demandé** (expulsion du mode, pas seulement
> blocage à l'init). Toute implémentation supplémentaire serait **redondante**.
> ⚠️ **Nuance importante pour le point 1** : `FB_CycleSemiAuto` et `FB_Modes` consomment `Homed` (**pas**
> `HomedAndReliable`) — `PRG_03:115,118,248-249`. Une position provisoire qui poserait `Homed := TRUE` franchirait
> donc **aussi** ces gates (§2.2 lignes 5a/5b) : **la redondance ne protège pas**.

### 6.2 L'opérateur a-t-il toujours un chemin de sortie ? 🟢 **OUI — prouvé**

| Chemin de sortie | Fait | Source |
|---|---|---|
| **Expulsion vers MAINT_N1 est inconditionnelle** | « L'expulsion n'est jamais bloquée par l'arret mecanique (comme la sortie DISABLE, contrat D2) » — l'expulsion est le **premier** `IF`, avant la règle de bascule conditionnelle | `FB_Modes.st:245-261` (vs `:262-269`) |
| Transition vers/depuis **DISABLE jamais bloquée** | « ⚠️ Exception de sécurité (contrat D2) : une transition vers ou depuis DISABLE n'est JAMAIS bloquée » | `FB_Modes.st:266-267` |
| **Bascule N1 ↔ N2** possible treuils arrêtés | `ModeChangeAllowed` = contacteurs retombés + frein serré + vitesse < 0,02 m/s (les deux) | `FB_Modes.st:226-229, 262-269` |
| **Cycle de homing accessible sans référence** | `AutoArmCandidate` propose `HX1` (annonce, **aucun mouvement**) en `MAINT_N1` **ou** `MAINT_N2` | `FB_CycleMachineHoming.st:222-230, 436-455` |
| Le **mouvement** du homing exige `MAINT_N2` (choix explicite, pas un verrou) | `ELSIF BootReady AND ExplicitValidationPulse AND (Mode = MAINT_N2) THEN …` | `FB_CycleMachineHoming.st:464-472` |
| **Échappatoires dédiées existantes** | `TglEnableWinchDescentLock_M3` (case IHM), `Bypass.LimitSwitch`, `Bypass.Global` (M3) lèvent le verrou T249-A ; `Bypass.MinHeight` lève l'interlock hauteur | `PRG_03:463-468` · `PRG_05:134` |
| **Forçage de step encadré (mise en service)** | Déverrouillé par case IHM + `MAINT_N2`, **impulsion sur front**, autorisé **même sur défaut latché** | `FB_CycleMachineHoming.st:318-348` |
| 🥇 **Référencement des DEUX axes SANS le GRAFCET ni la descente** — `HomingPermit` autorise un preset `BtnHome` **en `MAINT_N1` comme en `MAINT_N2`**, dès que `MachineHomingMechanicalStopOk` (treuils au repos) **ou** le FdC haut est atteint ; la **montée est libre** (§ ci-dessous) ⇒ on peut atteindre le capteur, `BtnHome` M1 puis M2, confirmer la benne, et obtenir **`MachineHomed` sans jamais exécuter `HX2`/`HX3`** | `PRG_02:601-604` (M1), `:654-657` (M2), `:521-525` · `FB_Encoder_Homing.st:206-222` · `FB_CycleMachineHoming.st:594-596` (`CommitOrOffsetValid := CommitPublished OR BucketOffsetValid`, `:197`) | ✅ **C'est le vrai chemin de récupération**, et il est **disponible en N1** |
| ✅ **La montée n'est JAMAIS bloquée par un permis process** : `ProcessPermitM1_Ascent` est constant TRUE (`ExtractionAssistActive := FALSE` en dur) ; T249-A ne touche **que la descente** ; l'interlock hauteur M3 ne concerne **que M3** | `PRG_04:294, 783-784, 1067-1074` · `FB_Safety_Winch.st:574-582` | ✅ confirme qu'**aucun deadlock n'existe côté montée** |

> ✅ **Pas de deadlock opérateur.** Un opérateur peut toujours : sortir en MAINT_N1, arrêter les treuils, passer en
> MAINT_N2, lancer le homing, ou utiliser une dérogation tracée / le forçage de step.
> 🟠 **Réserve** : la bascule N1→N2 est **refusée** tant que `ModeChangeAllowed` est faux (ex. retour frein ou
> vitesse incohérents) — **stall possible**, jamais une impasse (DISABLE reste ouvert). À tracer à l'IHM (le motif
> est déjà publié : `FB_Modes:271-286`).

### 6.3 🔴 Ce que la nouvelle conception **ne traite pas** : l'impasse `HX3` (cause racine du « cycle bloqué »)

```
codeurs NON HomedAndReliable
  ⇒ M3 bloquée (interlock hauteur, insensible à Bypass.Global)      [PRG_05:134-138]
  ⇒ M3 jamais « stable à P1/Maintenance »
  ⇒ WinchDescentAuth_M3 = FALSE (T249-A)  ⇒ DESCENTE M1/M2 INTERDITE [PRG_03:463-468]
  ⇒ or le cycle exige une descente (HX3) ET la nouvelle conception aussi
    (« vrai Homed au franchissement » = front descendant, HX3)       [FB_CycleMachineHoming.st:504-515]
  ⇒ HomeAxesTimedOut ⇒ TransactionAbort ⇒ HXF_FAILED                 [:215, 219-220, 516-518]
  ⇒ sortie uniquement par Reset conscient
```

| Fait aggravant | Source |
|---|---|
| Le cycle **gèle M3** pendant toute sa durée : `M3Locked := CycleRunning` (⇒ `HX2..HX6`), et l'agrégat `M3_SafeStop` déclenché par ce verrou est **explicitement sans bypass** (« Pas de bypass ») | `FB_CycleMachineHoming.st:582-587` · `PRG_05:474-481` |
| ⇒ l'opérateur **ne peut pas** repositionner M3 **après** avoir engagé le cycle | idem |
| ⇒ « M3 : zéro mouvement tant que non référencée » (exigence T340) **renforce** cette impasse sans la traiter | §3 |

> 🔴 **C'est le point le plus important du point 5** : la nouvelle conception **n'apporte aucune réponse** à la
> cause racine déjà identifiée par le challenge précédent (impasse `HXF_FAILED` hors P1/Maintenance), **et** elle
> conserve le Plan B sur ce même chemin. **Elle ne peut donc pas être vendue comme « la » solution au cycle
> buggué** — au mieux elle en traite les symptômes (position/synchronisation), pas la mécanique de blocage.
> 🎯 Décision humaine requise (comme dans le challenge précédent **Q-C**) : exempter `T249-A` pendant le cycle de
> homing (encadré : `MachineHomingActive AND MAINT_N2` + arrêt mécanique confirmé + palier 1) **ou** changer de
> stratégie de capture (§5.4 option 4-B).

### 6.4 🚨 Constat hors scope (devoir d'alerte) — voir §10 · **A1**

En résumé : la garde de montée `HX2` (`FB_CycleMachineHoming.st:422-425`, `T#120s` **en dur**, **non réglable**)
est un **compteur de temps mural**, pas un compteur de mouvement, et l'estimation de montée à palier 1 depuis le fond
(58,5 m à ≈ 0,4 m/s ⇒ ≈ 146 s) **la dépasse**. Détail, sources et chiffrage : **§10 · A1**.
⚠️ **Interaction directe avec T340** : l'exigence « palier 1 imposé » **allonge** le temps de montée ⇒ ce constat doit
être tranché **avant** de figer le plan de test du lot.

### 6.5 Verdict point 5

**🟠 MAJOR** — ✅ **pas de deadlock** (chemin de sortie prouvé, §6.2) et exigence « cycle bloqué à l'init »
**déjà satisfaite** (§6.1) ; 🔴 **mais** la conception **n'attaque pas la cause racine** de l'impasse du cycle
(§6.3) et **conserve** son Plan B sur le chemin défaillant ; 🚨 **constat hors scope** grave sur la garde `HX2`
(§6.4) à escalader **avant** de figer le moindre plan de test T340 (il peut fausser toute campagne terrain).

---

## 7 · Synthèse des verdicts

| # | Point challengé | Verdict | Argument décisif | Source pivot |
|---|---|---|---|---|
| 1 | Fuite du « faux référencement provisoire » | 🔴🔴 **BLOCK** | Aucun contenant pour une position non référencée ; `Homed` est un **fait unique** partagé ; le faux datum est **auto-cohérent** (M2 = M1 + 15 m = `OffsetCloseM`) donc **indétectable** ; il **libère** le plafond ISO 13849, la butée logicielle, les permits benne, **et supprime le chemin de re-référencement automatique** (§2.4 : A1/A2/A3) | `ST_Encoder_Calib.st:9-21` · `FB_Encoder_Homing.st:290` · `FB_EncoderReliability.st:34` · `FB_CycleMachineHoming.st:594` · `PRG_02:531-534` · `PRG_04:1226-1230` |
| 2 | Interlock M3 « zéro mouvement si non référencé » | 🟢 **PASS** (+ 🟠 2 réserves) | **AND** de 2 gates : référence **ET** hauteur. Besoin **déjà couvert** | `PRG_05:134-139` |
| 3 | Palier 1 constant global (tous modes) | 🟢 **PASS** / ⚠️ constat corrigé / 🔴 3 écarts | **Déjà implémenté à l'identique** : littéral 1, 2 sens, 2 treuils, tous modes, non exposé IHM. **Mais** `CST_StepSlow` est **mort en MAINT_N2** (arbitrage ignore `ReqWinch`) ⇒ homing d'une machine encore référencée possible **à palier 5** ⇒ capture preset en échec ; boutons N2 « Palier 1 » **non câblés** ; trou M2 (A5) | `PRG_04:1217-1230, 1382-1383` · `FB_WinchCmdArbitrationM1.st:56-104` · `ST_MaintenanceN2Cmd.st:8-14` · `PRG_04:1278-1287` |
| 4 | Plan B « référencement à l'arrêt après inertie » | 🟠 **MAJOR** | Primitives existantes ✅ mais **biais systématique** (cote 8,5 m écrite à une position sur-courue) **et** dépendance à la **même descente `HX3`** ⇒ pas un filet de sécurité | `FB_Encoder_Homing.st:229-230, 206-207` · `FB_CycleMachineHoming.st:504-515` · `PRG_02:514-517, 521-525` |
| 5 | Deadlock / chemin de sortie | 🟠 **MAJOR** | ✅ **Pas de deadlock** (expulsion `MAINT_N1` + DISABLE jamais bloqués) · exigence init **déjà couverte** · 🔴 **cause racine `HX3`/T249-A non traitée** · 🚨 garde `HX2` à escalader | `FB_Modes.st:245-267` · `FB_CycleSemiAuto.st:834` · `PRG_03:463-468` · `FB_CycleMachineHoming.st:422-423` |

> 📊 **Bilan de la conception challengée** : **3 exigences sur 5 déjà satisfaites** par l'existant ; **1 exigence
> bloquante non implémentable en l'état** (position provisoire) ; **1 exigence réalisable mais mal spécifiée**
> (Plan B). Le **vrai** chantier (impasse `HX3` / T249-A) **n'est pas dans le périmètre T340**.

---

## 8 · Options proposées (aucune tranchée ici)

> Posture : je propose, je ne décide pas. Effort : **S** < 1 j · **M** 1-3 j · **L** > 3 j de travail agent (hors
> campagne de mesure).

| Option | Périmètre | Effort | Risque | Verdict technique |
|---|---|---|---|---|
| **🅰 — T340 réduit au strict utile** : **aucune** position provisoire (option 1-A), **aucun** nouveau palier (déjà là), **aucun** nouvel interlock M3 (déjà là) ; on ne livre que la **synchronisation sans datum** + le **Plan B** retenu + la **reformulation « palier 1 pendant le cycle de homing »** (Q-8, seul delta réellement utile sur le palier) | Petit, sûr | **M** | 🟢 **Faible** | 🥇 **Recommandée** — c'est la seule qui **ne touche pas** `Homed` |
| **🅱 — T340 + traitement de la cause racine** : idem 🅰 **plus** l'exemption encadrée de `T249-A` pendant le cycle (ou la capture « remontée » 4-B) | Moyen | **M** + analyse Safety | 🟠 Moyen — **exemption d'un verrou de sécurité ⇒ visa humain C4** | 🥈 **La seule qui règle le « cycle buggué »** |
| **🅲 — Datum à 3 états (`DatumProvisional`)** | Gros | **L** | 🔴 Élevé (~75 sites à ré-auditer) | 🥉 À ne retenir que si l'utilisateur **exige** une position chiffrée avant référencement |
| **🅳 — Mesurer avant de décider** (transverse, à combiner) | Instrumentation | **S** + campagne | 🟢 Faible | ✅ **Indispensable** : vitesse réelle palier 1 · sur-course d'arrêt · temps de montée fond→capteur (garde `HX2`) · écart M1/M2 après confirmation benne · `MachineHomingSeqStep`/`PresetConfirmationFailed` au moment du blocage |

---

## 9 · Questions à trancher par l'humain (aucune réponse décidée ici)

| # | Question | Bloque |
|---|---|---|
| **Q-1** 🔴 | **Où vit la position provisoire ?** (aucune / champ dédié + ré-audit de tous les consommateurs / valeur limitée à l'IHM) — ou **renonce-t-on** à la position provisoire (option 1-A, la synchronisation se fait sans datum) ? | **Point 1 — tout le lot** |
| **Q-2** 🔴 | **Quel besoin réel** motive la position provisoire : (a) **afficher** une position, (b) permettre la **synchro** M1/M2, (c) permettre la **confirmation benne** « M2 = M1 + 15 m » ? La réponse **change complètement** l'option (a ⇒ 1-C, b ⇒ 1-A, c ⇒ il faut revoir `BucketReferenceTargetM`) | **Point 1** |
| **Q-3** 🟠 | `Bypass.MinHeight` doit-il **cesser** de lever le gate de **référence** (et ne lever que la hauteur) ? | Réserve **R2.1** |
| **Q-4** 🟠 | Le Plan B doit-il **emprunter `HX3`** (⇒ non indépendant) ou **remonter au capteur** (option 4-B, indépendant de T249-A) ? | **Point 4** |
| **Q-5** 🔴 | Accepte-t-on d'**exempter `T249-A`** pendant le cycle de homing (encadré, tracé) — ou change-t-on de stratégie de capture ? | **Point 5 — cause racine** |
| **Q-6** 🟠 | Le biais de datum d'un référencement « à l'arrêt » (sur-course) est-il **mesuré et borné** sur site avant d'être retenu ? | **Point 4** (campagne) |
| **Q-7** 🚨 | La garde `HX2` (120 s, **en dur**, compteur **temps mural**) est-elle compatible avec une montée **palier 1** depuis le fond (≈ 146 s estimées) ? | **§10 · A1 — escalade hors scope** |
| **Q-8** 🔴 | L'exigence doit-elle être reformulée en **« palier 1 pendant le cycle de homing »** (`MachineHomingActive`), au lieu de « tant que non référencé » — sinon le re-référencement d'une machine **encore référencée** se fait à **palier 5** et la capture preset **échoue** ? | **Point 3 (§4.4-1) — dans le scope T340** |
| **Q-9** 🟠 | Le besoin « se dégager / manœuvrer à petite vitesse en N2 » doit-il s'appuyer sur les boutons N2 existants ? ⚠️ **Ils ne commandent aucun mouvement** (`ST_MaintenanceN2Cmd.st:8-14`) : soit on les câble, soit on utilise `GVL_IHM.M1TreuilRetenue/M2TreuilBenne.Cmd.BtnAscent/BtnDescent` (`PRG_04:481-486`) | **Point 3 (§4.4-2)** |

---

## 10 · Constats hors scope — devoir d'alerte (non corrigés, non décidés ici)

| # | Constat | Source | Gravité |
|---|---|---|---|
| **A1** | 🚨 **Garde `HX2` = compteur temps mural, non réglable, possiblement trop courte.** `ClimbTimer(IN := (SeqStep = HX2_CLIMB) AND …)` ne dépend **ni du permis opérateur ni du mouvement** ⇒ toute pause consomme la garde (120 s) ; `CfgTimeoutClimb/CfgTimeoutHomeAxes` ne sont **jamais** renseignés par `PRG_02` ⇒ aucun réglage IHM. Chiffrage : 58,5 m de course (‑50 → 8,5 m) à ≈ 0,4 m/s ≈ **146 s > 120 s** ⇒ `ClimbTimedOut` ⇒ `HXF_FAILED` **sans défaut machine** | `FB_CycleMachineHoming.st:422-425` · `ST_fbMachineHomingCycle_Cfg.st:18-19` · `PRG_02:540-543, 571` · `GVL_PERSISTENT.st:24-28, 41, 46` | 🔴 **Élevée** — candidat sérieux à l'explication du « cycle actuellement buggué » (T336). **Impacte directement T340** (le palier 1 allonge le temps de montée) |
| **A2** | 🔵 **Entrée morte dans `FB_Bucket`** : `MachineHomed : BOOL` est **déclaré** (`:25`) mais **jamais lu** dans le corps du FB (grep exhaustif). ⚠️ Conséquence pour la conception : on ne peut **pas** « garder la benne » avec `MachineHomed` côté `FB_Bucket` — le fait n'y est pas consommé | `FB_Bucket.st:25` · `PRG_04:367` (câblage) | 🔵 **Faible** (dette de propreté / interface trompeuse) |
| **A3** | 🟠 **Divergence d'un test dérivé** : `TOOLS/TEST_AUTO_CI/scripts/PRG_02_Acquisition.st:369-394` ne reflète plus `CODE/` — cible d'ouverture **sans offset** (`:373` vs `CODE/M_MAIN/PRG_02_Acquisition.st:531`) et `HomingPermit` conditionné à `JoystickWinchSelectArbitrated <> 1` (`:386-387`). Non producteur en production, mais **faux positif de couverture CI possible** | `TOOLS/TEST_AUTO_CI/scripts/PRG_02_Acquisition.st:369-394` | 🟠 **Moyenne** — à traiter avec la famille T339/T341 (désalignement tests ↔ code) |
| **A4** | 🔵 **Sites consommant `CablePosM` en ABSOLU sans aucune garde `Homed`** (déjà le cas aujourd'hui, donc **pas** un risque créé par T340, mais ils démontrent qu'une valeur « provisoire » **ne peut pas être isolée**) : limite basse câble `FB_Safety_Winch.st:565` · **limite légale de profondeur** `PRG_07:477-479` → `GVL_IHM.Commun.LimitLegalReached` (consommé `PRG_03:213` et `FB_Safety_Winch.st:570`) · limites basses actives `PRG_04:684-688` · **fenêtre d'immersion Kobold** `PRG_04:727-730` · MecaE `PRG_04:947, 1016` → `FB_Safety_Winch.st:394-397` · seuils d'arrêt benne `FB_Bucket.st:522, 538, 566, 592, 624, 636` | relevé audit | 🔵 **Faible** (constat de conception) — ⚠️ mais ce sont **7 familles** de protections/consignes qui deviendraient « actives et fausses » en cas de datum provisoire |
| **A5** | 🟠 **Trou du clamp palier 1 pour M2 (jog benne)** : deux affectations **sans `MIN`** écrasent le plafond de sécurité déjà réduit à 1 — `M2MaxStepUp := LIMIT(1, _BucketCfgPersist.Config.MaxStepUp, 5)` (= 2) et `M2MaxStepDown := LIMIT(1, …MaxStepDown, 5)` (= 4) — en contradiction directe avec le commentaire de la ligne voisine (« Ne jamais relever ici un plafond deja reduit par une protection amont (codeurs non fiables, ecart synchro, position maintenance) »). Le garde-fou de secours du jog benne teste `Homed` **brut** (pas `HomedAndReliable`) ⇒ **conditions d'atteinte** : `Homed = TRUE` **ET** `EncoderIncoherent = TRUE` (mesure non fiable) **ET** jog benne M2 actif ⇒ M2 peut monter au **palier 2** au lieu de 1 | `PRG_04:1278-1287` (vs commentaire `:1267-1270`) · `PRG_04:1292-1306` (test `Homed`) · `FB_EncoderReliability.st:34` | 🟠 **Moyenne-élevée** — **défaut préexistant** de la posture ISO 13849, **hors scope T340**, à escalader (`fix:` + `guard:`). ⚠️ **Devient critique si T340 écrit un `Homed` provisoire** (§2) : la condition `Homed = TRUE` + mesure douteuse devient alors **triviale** à atteindre |
| **A6** | 🔵 **Garde-fou de bande vitesse désactivé** : `SpeedGuardEnable := FALSE` **codé en dur** des deux côtés (dette safety documentée `-S5`), donc le mécanisme `FB_Winch §5` (« bride le palier demandé si la vitesse n'est pas stable », `FB_Winch.st:234-244`) **ne protège rien** aujourd'hui | `PRG_04:1399-1413` (M1) · `PRG_04:1481` (M2) · `FB_Winch.st:233-244` · `ST_fbWinch_Sensors.st:29` | 🔵 **Moyenne** — **aucun mécanisme de « palier 1 » supplémentaire n'est disponible** par cette voie : le seul garde-fou palier 1 opérationnel hors référencement est bien celui de `PRG_04:1226-1230` |
| **A7** | 🔵 **Libellé IHM trompeur sur le motif d'expulsion** : l'expulsion `SEMI_AUTO → MAINT_N1` (datum absent) réutilise le drapeau du refus « treuils en mouvement » ⇒ la cause affichée `instCauses[1]` dit « arretez les treuils avant de changer de mode » alors que la cause réelle est le datum absent (seul `Auth.ModeChangeBlockReason` est juste) | `FB_Modes.st:179-181` vs `:251-261` | 🔵 **Faible** (confort opérateur, mais trompeur **précisément dans le cas T340**) |
| **A8** | 🔵 **`WinchSlowSpeed_Pct` retiré du projet** : aucune vitesse « petite vitesse » en **% continu** n'existe plus ; toute notion de vitesse réduite passe par les **paliers discrets 1..5** | `ST_CommunCfg.st:18` | 🔵 **Faible** — cadrage : T340 ne peut pas s'appuyer sur une consigne % |
| **A9** | 🟠 **La montée de homing reste exposée à l'escalade Méca D** : `UncommandedActiveD := NOT (BenneBusy OR BenneHoldStillActive) AND NOT TopPositionSensor AND NOT InReferencingMode AND NOT (contacteurs retombés ET frein serré)`, seuil `PostRampTimeout := T#3s` ⇒ défaut **latché** ⇒ **SafeStop + PowerCutOff** (`:516-525`). Or `InReferencingMode` ne couvre que la fenêtre preset de **50 ms** (`FB_Encoder_Homing.st:289`), très inférieure au temps de décélération | `FB_Safety_Winch.st:376-381, 516-525` · `FB_Encoder_Homing.st:110, 289` | 🟠 **Moyenne-élevée** — **risque déjà identifié** par le challenge précédent (`CHALLENGE_T336…:194`), **non traité par T340**, et aggravé par toute pause/arrêt **sur** le capteur (donc par un Plan B « arrêt au capteur » : option 4-A) |

> 🚨 **A1 est le constat le plus actionnable de tout ce challenge** : il conditionne la validité de **toute**
> campagne de mesure T340 (§8-D) et peut faire échouer un cycle de homing **sans aucune cause machine**.
> À escalader **avant** de figer un contrat T340 — `fix:` + `guard:` (garde-fou automatique sur
> `CfgTimeoutClimb ≥ course_max / vitesse_palier1_min`) dans un **lot séparé**.

---

## 11 · Contrôle de périmètre

| Élément | État |
|---|---|
| Fichiers `CODE/` écrits par ce challenge | ❌ **AUCUN** |
| Fichiers `CODE/` modifiés | ❌ **AUCUN** |
| Commit / push / revert / suppression | ❌ **AUCUN** |
| Livrable écrit | ✅ `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T340_REFONTE_HOMING_2026-09-20.md` |
| Sous-agents | 2 analyses déléguées (recensement exhaustif des consommateurs `Homed`/`HomedAndReliable` ; audit modes MAINT/permits), **lecture seule**, aucun fichier écrit |
| Verrou de tâche | ❌ non posé (mission read-only, aucune écriture hors livrable) |

> 🧭 **Ce livrable n'est pas une décision.** Les verdicts §2→§7 sont des **évaluations techniques sourcées**.
> Toute implémentation reste **subordonnée** à : (1) l'arbitrage des questions §9 (**Q-1**, **Q-5** en priorité),
> (2) la campagne de mesure (§8-D), (3) un contrat **TASK_CONTRACT_T340** rédigé (C1, objectifs testables) et à une
> **validation humaine explicite** (`AGENTS.md`).

---

## 12 · Limites & points NON vérifiables (déclarés, pas contournés)

| # | Point | Pourquoi non vérifiable depuis le dépôt |
|---|---|---|
| L1 | **Polarité physique du FdC haut** (`M1M2_TopPositionFree_DI`) | Le code est **cohérent en interne** (deux conventions explicites : `PRG_04:930-932, 1001` passe le DI brut à `FB_Safety_Winch` en convention « TRUE = libre », `PRG_02:615, 670` passe `NOT DI` à `FB_Encoder` en convention « TRUE = atteint »), mais **aucun élément du dépôt ne prouve le câblage réel** |
| L2 | **Valeurs réellement en service** des configurations | `_CommunCfgPersist`, `_BucketCfgPersist`, `_WinchM1/M2CfgPersist` sont des **PERSISTENT réécrits par l'IHM** (pont bidirectionnel `FB_CfgPersistBridge_CommunCfg.st:20-25`). Les valeurs citées sont **celles du code**, pas l'état machine. ⚠️ **Tout chiffrage (§10 · A1) doit être re-mesuré sur site** |
| L3 | **Occurrence effective de l'impasse `HX3`** (§6.3) | Dépend de la position de M3 au moment de la perte de datum et de l'état du toggle T249-A (défaut `TRUE`). **Non démontrable statiquement** |
| L4 | **Mot de passe `MAINT_N2`** | Annoncé dans un commentaire IHM (`GVL_IHM.st:24`), **absent de `CODE/`** (grep `Password\|MotDePasse\|AccessLevel` = 0) ⇒ relève de l'IHM externe |
| L5 | **Aucun gate / bundle exécuté** | Mission **read-only** : aucun bundle généré, aucun `G200` lancé, **aucun `Device.export` lu** (périmé par `AGENTS.md`) |
| L6 | **Vitesse réelle au palier 1** | Non instrumentée et non caractérisée (§4.3) — **conditionne** les conclusions chiffrées (`A1`, sur-course du Plan B) |

> 📌 **Méthode** : 2 audits délégués à contexte frais (recensement exhaustif des consommateurs de
> `Homed`/`HomedAndReliable` ; modes MAINT/permits/« petite vitesse »/deadlock), avec greps exhaustifs
> (`\bHomed\b`, `MachineHomed`, `MachineHomedRaw`, `HomedAndReliable`, `HomingPositionValid`, `EncoderIncoherent`,
> `HomingSuspect`, `HomingRefRaw`, `ActiveOffsetValid`, `CommitOrOffsetValid`). `ARCHIVES/` et `CODE_BACKUP/`
> **exclus** (non actifs). Tous les faits cités ont été **re-vérifiés par l'orchestrateur sur le code réel**
> pour les points pivots (chaîne `Homed`→`MachineHomed`, clamp `PRG_04:1226-1230`, interlock M3, arbitrage du
> palier, gardes `HX2`/`HX3`).
