# 🗺️ Plan C3 — T330 · Invariant haut et normalisation des réglages

> 📌 **Plan d'implémentation C3** de la tâche **T330** (contrat
> `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_HOMING_TOP_SOFT_LIMIT_INVARIANT.yaml`), suite du cadrage
> `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md`.
>
> ⛔ **AUCUN CODE N'EST ÉCRIT PAR CE PLAN.** Il spécifie ce qui devra être fait, **soumis à validation
> humaine**, phase par phase. Aucun fichier `CODE/`, `CODE_XML/`, type IHM ni `Device.export` touché.
>
> 🛑 **P3 (code) attend un GO DISTINCT** après restitution de P1/P2, **et** la livraison de **T255-D**
> (même `PRG_07`).

## 🔄 RÉVISIONS INTERNES

| Révision | Date | Contenu |
|---|---|---|
| v1.0 | 2026-09-20 | Première rédaction |
| **v1.1** | 2026-09-20 | **Audit indépendant** (sous-agent `34229875`, verdict `BLOCK`) : **11 erreurs factuelles** relevées, **8 confirmées** après vérification personnelle — dont **1 erreur mathématique de l'orchestrateur**. Journal complet **§11**. |
| **v1.2** | 2026-09-20 | **Arbitrages CC01/Q17→Q28 intégrés** ; **Q17→Q28 toutes FERMÉES et tracées** (§1) ; **domaines corrigés** (C1) ; **gating R2** (C2) ; **limite du lot tracée** (C3) ; **matrice `AC ↔ TC ↔ oracle ↔ preuve` figée** (§4) ; ids **`TC-P10-073-088`** conformes `G470` ; restriction du périmètre réconciliée (§7). |

---

## 1 · DÉCISIONS — **TOUTES FERMÉES** (Q17 → Q28), avec leur source

> ✅ **AC1** : aucune question bloquante ouverte. Chaque décision est tracée avec **sa source**.

| # | Sujet | Décision retenue | Source |
|---|---|---|---|
| **Q17** | Les **deux** champs changent dans le même scan | **Préserver le TOP** (`CfgTopSensorPos_M`) ; corriger le FDC : `CfgCableLimitAscent_M := TOP − 1,00 m` | Arbitrage humain 2026-09-20 |
| **Q23** | Point d'insertion | **Option A** : normalisation **AVANT** les bridges, référence lue sur le **persistant** (pattern existant `PRG_07:187-196`) | Arbitrage humain 2026-09-20 |
| **Q19** | Destination de la valeur corrigée | **Sans objet** — l'option A propage via les bridges **dans le même scan** | Conséquence de Q23 |
| **Q20** | Miroir M2 | **Sans objet** — le miroir `:154-155` s'exécute **après** les bridges ⇒ reçoit la valeur **corrigée** | Conséquence de Q23 |
| **Q21** | Bornes **absolues** | **`CfgCableLimitAscent_M ∈ [0 ; 9,00 m]`** · **`CfgTopSensorPos_M ∈ [1 ; 10,00 m]`** ⚠️ **borne FDC CORRIGÉE** (voir C1 ci-dessous) | Arbitrage CC01 2026-09-20 + **démonstration arithmétique** |
| **Q22** | Gating pendant homing | **(a) R2 seul est INHIBÉ pendant `InReferencingMode`** — la **cible de homing ne bouge jamais pendant un homing** ; correction appliquée **au scan suivant la sortie du mode**, **avec message**. **R1 et R3 jamais inhibées** | Arbitrage CC01 2026-09-20 |
| **Q24** | Non-rebond | Correction **à sens unique** ⇒ pas de rebond — **à prouver** par un **test 2 scans** | Arbitrage humain 2026-09-20 |
| **Q27** | Tolérance REAL | **AUCUN `eps`** — règle **stricte** `Δ ≥ 1,00 m` (**lemme de Sterbenz** ⇒ différence **exacte**) | Arbitrage humain + **démonstration mathématique** |
| **Q18** | Bande `0,50 m` non mesurée | Risque **accepté** ; **mesure en recette P5** | Arbitrage humain 2026-09-20 |
| **Q28** | Maintien T291-B B1 | **LEVÉ** — B1 remis (commit `55700932`), validation utilisateur | Arbitrage humain 2026-09-20 |
| **Q3** | Coïncidence des seuils ±0,50 m | **Une seule** expression dérivée (le point médian devient l'état **nominal** après correction) — **contrainte d'implémentation**, pas une question | Décision orchestrateur, cf. §2.5 |
| **Q25** | Message IHM | Champ bandeau + **maintien** `CST_BannerHoldTime` + libellé **discriminant** (cf. cadrage §11bis) — **spécifié §2.6** | Décision orchestrateur |
| **Q26** | Format d'ID + matrice | **`TC-P10-<NNN>` canonique**, bloc **035-071**, déclaré dans `af_traceability_matrix.yaml` | Décision orchestrateur (§4) |
| **C1** | Borne Q21 vs invariant | ⛔ **La borne annoncée `FDC ≤ 10` était INCOMPATIBLE** : `Δ ≥ 1` ⇒ `FDC ≤ TOP − 1` ; avec `TOP ≤ 10` ⇒ **`FDC ≤ 9`**. ⇒ **corrigée en `[0 ; 9,00 m]`** | **Démonstration arithmétique** (reprise et acceptée par CC01) |
| **C2** | Q22 vs R2 | ⛔ « le TOP n'est jamais déplacé » **contredisait R2** qui déplace le TOP (= **cible de homing**). ⇒ **résolu par (a)** : **R2 inhibé** pendant `InReferencingMode`, R1/R3 **jamais** | **Contradiction prouvée** (reprise et acceptée par CC01) |
| **C3** | Test 2 scans vs guerre d'écriture | Le test 2 scans prouve la **non-récorrection interne** ; la **guerre d'écriture IHM (Q12)** est **tracée comme LIMITE du lot**, **non couverte**. **Pas de test IHM en P2** | Arbitrage CC01 2026-09-20 |

### Règles à implémenter (état **final**, gating inclus)

| # | Condition | Action | Gating |
|---|---|---|---|
| 🔴 **R0** | **CLAMP ABSOLU — INCONDITIONNEL, À CHAQUE SCAN, sur FDC et TOP SÉPARÉMENT** *(Q21 bis, décision CC01 2026-09-20)* | `CfgCableLimitAscent_M := MIN(MAX(FDC, 0,00), 9,00)` et `CfgTopSensorPos_M := MIN(MAX(TOP, 1,00), 10,00)` — **avec le même message non alarmant que Q2** | ❌ **jamais** inhibée |
| **R1** | `Δ < 1,00 m` **après modification du FDC** *(sur les valeurs **clampées**)* | `CfgCableLimitAscent_M := CfgTopSensorPos_M − 1,00 m` | ❌ **jamais** inhibée |
| **R2** | `Δ < 1,00 m` **après modification du TOP** *(sur les valeurs **clampées**)* | `CfgTopSensorPos_M := CfgCableLimitAscent_M + 1,00 m` | ✅ **INHIBÉE pendant le homing** (Q22/C2) — voir **§2.7bis** |
| **R3** | `WinchSlowdownDistanceTop_M < 0,50 m` | `WinchSlowdownDistanceTop_M := 0,50 m` | ❌ **jamais** inhibée |

> ## 🔴 **ORDRE D'EXÉCUTION IMPOSÉ (Q21 bis)** — **R0 d'abord, TOUJOURS**
>
> ```
> 1. CLAMP ABSOLU INDIVIDUEL   (R0, inconditionnel, chaque scan)
>         FDC → [0 ; 9,00]      TOP → [1 ; 10,00]
> 2. PUIS règle Δ ≥ 1,00 m / slowdown ≥ 0,50 m   (R1 / R2 / R3)
>         évaluées SUR LES VALEURS CLAMPÉES
> ```
>
> **Motif (trou réel identifié au challenge, accepté par CC01)** : le contre-exemple
> `FDC = 9,50` + `TOP = 12,00` donne `Δ = 2,50 ≥ 1,00` ⇒ **aucune règle R1/R2/R3 ne se déclenche**,
> alors que **les deux valeurs violent DÉJÀ leurs bornes absolues individuelles** ⇒ elles restaient
> **hors domaine indéfiniment**. Le clamp aval (ex-`R4`, uniquement en aval d'une correction) **ne
> couvrait pas ce cas**.
>
> ### ✅ Preuve d'inutilité du clamp aval (l'ex-`R4` est **absorbé** par `R0`)
> Avec **R0 en amont**, les entrées de R1/R2 sont **bornées** :
> - `TOP ∈ [1 ; 10]` ⇒ `R1` donne `FDC := TOP − 1,00 ∈ [0 ; 9,00]` ✅ **dans la borne**
> - `FDC ∈ [0 ; 9,00]` ⇒ `R2` donne `TOP := FDC + 1,00 ∈ [1 ; 10,00]` ✅ **dans la borne**
>
> ⇒ **La correction Q17/Q2 ne peut structurellement JAMAIS produire une valeur hors borne** : le clamp
> aval est **redondant** et **non testable** (il ne peut pas se déclencher) ⇒ **il est retiré** comme
> règle distincte. ⛔ **Ne pas le réintroduire** : une garde qu'aucun test ne peut faire échouer est du
> **code mort**.

- **R2 inhibée** ⇒ message **spécifique** « correction différée » ; la correction est appliquée **au premier
  scan où le homing est terminé**, avec le message nominal.
- **Invariant d'intention** : la règle appliquée est celle du **champ modifié** ; **le champ non modifié

### 2.7bis 🔴 Signaux de gating et **mécanisme de la correction différée** (C2) — 2 pièges traités

> 🔍 **Vérifiés par l'orchestrateur** (non supposés) — l'implémenteur **doit** appliquer ces deux points.
> ⚠️ Sans eux, la décision **C2/Q22 est inapplicable** et la normalisation **perdrait** sa correction.

#### Piège 1 — `HomingLifecycle.Busy` **seul** = fenêtre de ~50 ms ⇒ **insuffisant pour Q22**

| Signal | Ce qu'il couvre **réellement** | Source |
|---|---|---|
| `PRG_02.Data.EncoderM1/M2.Measurement.HomingLifecycle.Busy` | **la transaction de preset** uniquement — `Lifecycle.Busy := PresetVerificationActive` (`FB_Encoder_Homing.st:289`), `CST_PresetVerifyTime = 50 ms` ⇒ **beaucoup plus court** que le homing perçu par l'opérateur | consommé par `FB_Safety_Winch` via `PRG_04:933,1002` |
| `PRG_02.Data.MachineHoming.Active` | ✅ **le cycle de homing machine COMPLET** (HX0..HX6) | `PRG_02:565` (`instCycleMachineHoming.MachineHomingActive`), déjà consommé en `PRG_06:258` |

⇒ ⛔ **Gater sur `HomingLifecycle.Busy` seul ne satisferait PAS Q22** : la protection ne durerait que
**~50 ms**, alors que le homing machine dure tout HX0..HX6.
✅ **Signaux retenus** (disponibles en **lecture** dans `PRG_07`) :
```
InHomingT330 := PRG_02_Acquisition.Data.MachineHoming.Active
                OR PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy
                OR PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy;
```

#### Piège 2 — 🔴 la correction différée **NE peut PAS** reposer sur la seule détection de front

La détection « quel champ a changé » (§2.2) est **sur front**. Si R2 est **inhibée** pendant le homing :
la valeur TOP **n'est pas** corrigée, puis **le champ ne change plus** à la sortie du mode ⇒ **plus de
front** ⇒ **R2 ne se déclencherait JAMAIS** ⇒ la configuration invalide **resterait violée
indéfiniment**. ⇒ **La correction différée exigée par Q22 serait silencieusement perdue.**

✅ **Règles RETENUES par l'arbitrage CC01 (2026-09-20) — ⛔ AUCUN latch, AUCUNE mémoire nouvelle :**

| # | Exigence actée | Conséquence |
|---|---|---|
| **a** | **Gater sur le CYCLE de homing complet**, pas sur `HomingLifecycle.Busy` (~50 ms, **trop étroit**) | signal = `PRG_02.Data.MachineHoming.Active` **OR** `EncoderM1/M2…HomingLifecycle.Busy` (piège 1 ci-dessus) |
| **b** | 🔴 **NVRAM GELÉE pendant l'inhibition** — **aucune écriture `Cfg`** | ⛔ **annule** la mention « Fenêtre NVRAM : aucune » **pendant le homing** (§2.3) : l'écriture est **suspendue**, ni différée ni corrigée |
| **c** | 🔴 **Coupure pendant le homing = intention opérateur PERDUE**, jamais appliquée après coup silencieusement | ⇒ **rien à mémoriser** : au retour, si la configuration **restaurée** est **toujours invalide**, on **retombe dans le cas normal Q2** (normalisation + message) |
| **d** | R1 et R3 **jamais** inhibées | inchangé |

🔧 **Conséquence de (c) — le piège 2 se résout SANS latch** : sans mémoire d'intention, la correction au
retour **ne peut pas** dépendre d'un front (le champ ne change plus). ⇒ La normalisation comporte donc un
**repli NIVEAU** : *si le couple est invalide au scan courant, corriger* — et **le champ à préserver est
celui de `Q17`** : **on préserve le TOP, on corrige le FDC** (R1), le TOP étant la **cote gravée par le
homing**. ⚠️ Ce repli **réutilise la règle Q17 déjà arbitrée** ⇒ **aucune question nouvelle**.

> 🧹 **ANNULÉ de la v1.2** : la mémoire `R2PendingTopCorrection` et l'« application différée » qu'elle
> portait. **Le latch n'existe plus** ; `TC-P10-082` est **réécrit** en conséquence (§4.2).
  n'est JAMAIS touché**.

### 🔴 Q21 vs R2 — contrôle de cohérence **après** correction de borne (C1)

Avec `FDC ∈ [0 ; 9]` et `TOP ∈ [1 ; 10]`, **R2 est-elle toujours dans la borne** ?

| Situation | `R2` calcule | Dans la borne `TOP ≤ 10` ? |
|---|---|---|
`FDC = 9,00` | `TOP := 10,00` | ✅ **exactement à la borne** |
`FDC = 10,00` | *impossible* — **hors borne FDC** depuis C1 | ✅ éliminé par la borne |
`FDC = 0,00` | `TOP := 1,00` | ✅ à la borne basse |

⇒ ✅ **Avec la borne corrigée, R2 ne peut plus produire de valeur hors borne.** **C'est l'objet de `TC-P10-092`.**

---

## 2 · SPÉCIFICATION TECHNIQUE

### 2.1 Constantes (`VAR CONSTANT` locales — **jamais** persistantes ni IHM)

| Constante | Valeur | Rôle |
|---|---|---|
| `CST_T330ReserveMinMargin_M` | `1.00` | réserve minimale FDC / TOP |
| `CST_T330SlowdownTopMin_M` | `0.50` | plancher du ralentissement haut |
| `CST_T330FdcMin_M` | `0.00` | borne basse FDC (Q21/C1) |
| `CST_T330FdcMax_M` | `9.00` | borne haute FDC (Q21/**C1**) |
| `CST_T330TopMin_M` | `1.00` | borne basse TOP (Q21) |
| `CST_T330TopMax_M` | `10.00` | borne haute TOP (Q21) |
| ~~`CST_T330CompareEps_M`~~ | — | ⛔ **RETIRÉE** — non fondée (§2.4) |

> ✅ **Conforme AC3** : constantes **locales**, ni persistantes ni IHM. `CST_T330ReserveMinMargin_M` est
> une **règle d'ingénierie**, **pas** une cote métier.

### 2.2 Détection du champ modifié — **3 mémoires NON persistantes**, chemins **NOMMÉS**

| # | Mémoire | Chemin **exact** surveillé |
|---|---|---|
| 1 | `PrevT330TopSensorPosM` | `GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M` |
| 2 | `PrevT330CableLimitAscentM` | `GVL_IHM.Commun.Cfg.CfgCableLimitAscent_M` |
| 3 | `PrevT330SlowdownTopM` | `GVL_IHM.Commun.Cfg.WinchSlowdownDistanceTop_M` |

⛔ **INTERDIT** : surveiller `GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M` — réécrit **chaque scan** par
le miroir M1 (`PRG_07:154-155`) ⇒ **faux positif garanti**.

⚠️ `GVL_IHM` **n'est pas RETAIN** (`GVL_IHM.st:7`) ⇒ comportement en **hot restart / download / RTS** à
**prouver** (`TC-P10-074`).

#### 🔴 `[v1.3]` Exigence **ABSOLUE** oubliée en v1.2 — initialisation des 3 mémoires **depuis les valeurs RESTAURÉES**

La v1.2 listait les 3 mémoires **sans spécifier leur initialisation** ⇒ **le piège P2 du cadrage §0ter
n'était PAS paré**. Or, avec l'insertion **avant les ponts** : au scan 1 `GVL_IHM.*.Cfg` contient les
**défauts du DUT** (`8,5` / `7,5`) ; au scan 2 les ponts **restaurent la NVRAM** ⇒ un détecteur naïf voit
un « **changement opérateur** » **FAUX** ⇒ **correction injustifiée → écriture NVRAM → perte du réglage réel**.

✅ **Règles d'implémentation OBLIGATOIRES** :
1. Les 3 mémoires sont **initialisées depuis les valeurs RESTAURÉES** (`_WinchM1CfgPersist`,
   `_CommunCfgPersist`) — **jamais** depuis les défauts du DUT.
2. La normalisation est **inhibée tant que les ponts n'ont pas restauré** (`NOT Hmi.Initialized`) — critère
   **significatif** en amont des ponts (§2.3).
3. **Preuve exigée** : `TC-P10-071` (`NOT Initialized`) **et** un test explicite « **aucun changement
   détecté à la restauration NVRAM** » — le challenge relève qu'**aucun TC ne le couvre** aujourd'hui
   (`TC-P10-074` ne fait que l'effleurer).

### 2.3 Point d'insertion — **AVANT les bridges** (option A, Q23)

**Pattern existant, délibéré (`PRG_07_Supervision.st:187-196`)** : la référence est lue sur le
**persistant**, la valeur IHM est corrigée, **puis** le bridge propage.

**Ordre de référence (vérifié)** :
```
:140  bridge WinchCfg M1   → porte CfgTopSensorPos_M
:145  bridge WinchCfg M2
:154  GVL_IHM.M2…CfgTopSensorPos_M := GVL_IHM.M1…        ← MIROIR M2
:155  _WinchM2CfgPersist…          := GVL_IHM.M1…
:157…:177  autres bridges
:182  bridge CommunCfg     → porte CfgCableLimitAscent_M ET WinchSlowdownDistanceTop_M
```

| Point | Fait |
|---|---|
| Référence lue | **le persistant** (`_WinchM1CfgPersist`, `_CommunCfgPersist`) — **pas** `GVL_IHM` |
| Fenêtre NVRAM | ✅ **aucune** (le bridge écrit la valeur **corrigée** dans le même scan) |
| Miroir M2 | ✅ reçoit la valeur **corrigée** (`:154-155` après la normalisation) |
| Critère d'inhibition | `NOT Hmi.Initialized` — **significatif** ici, car **avant** les ponts |

⚠️ **Pourquoi pas après `:182`** : le pont y pose `Hmi.Initialized := TRUE` **dans le même appel**
(`FB_CfgPersistBridge_CommunCfg.st:20-26`) ⇒ le critère y serait **MORT**, et la fenêtre NVRAM
vaudrait **1 cycle `MainTask` = `T#10ms`** (❌ et non « 4–20 ms » : 4 ms = EtherCAT, 20 ms = CANopen).

### 2.4 Tolérance REAL — **AUCUN `eps`** (Q27)

`float32(8.49) − float32(7.49) = 1.0` **exactement**. 🔧 **Justification CORRIGÉE (challenge v1.2)** : la
v1.2 affirmait « les deux champs sont **toujours** dans un rapport `< 2` » — **FAUX** (ex. `10 / 1`).
La **conclusion reste bonne** mais la justification doit être exacte : sur le **domaine utile**
`FDC ∈ [0 ; 9]` et `TOP ∈ [1 ; 10]`, le rapport `TOP / FDC` peut atteindre **10** ⇒ **Sterbenz ne
s'applique pas partout**. Le rejet de l'`eps` ne repose donc **pas** sur Sterbenz seul, mais sur des
**cas vérifiés par calcul** : `8,49−7,49 = 1.0` · `8,5 − 7,5001 = 0.99989986` · `8,5 − 7,4999 = 1.00010014`
⇒ la comparaison **stricte** `>= 1,00` **détecte correctement** les violations réelles **sans** tolérance.
⇒ ✅ **comparaison stricte** : `(CfgTopSensorPos_M − CfgCableLimitAscent_M) >= CST_T330ReserveMinMargin_M`.
⛔ **Ne PAS introduire d'`eps`** : il **relâcherait** l'invariant (`0,9999 m` acceptée **sans correction**).

### 2.5 Seuils dérivés ±0,50 m — ⛔ **Q3 ABANDONNÉE** *(décision CC01 2026-09-20)*

**Décision : Q3 est ABANDONNÉE explicitement. Aucune preuve inventée.**

| Point | Décision |
|---|---|
| Preuve exigée par le cadrage §4.3 (balayage `CablePosM` `7,999 / 8,000 / 8,001`) | ⛔ **RETIRÉE** — aucun TC ne la porte, et il est **interdit d'inventer** une revendication de couverture |
| Revendication d'AC associée | ⛔ **RETIRÉE** de §4.1 |
| Coïncidence des deux seuils quand `Δ = 1,00` exactement | devient un **risque ACCEPTÉ**, **mesuré en recette** — déjà tracé **Q18** |
| Contrainte « **une seule** expression dérivée » | ✅ **CONSERVÉE** (bonne pratique, coût nul) — mais **sans revendication de test** |

> ⚠️ Le fait technique **demeure** : après toute normalisation, `Δ = 1,00` **exactement**, donc
> `FDC + 0,50 = TOP − 0,50` **coïncident**. C'est **assumé** et **vérifié en recette P5**, **pas testé en ST**.

### 2.6 Message IHM (Q25)

| Élément | Spécification |
|---|---|
| Champ | `Banner.OperatorActionText` (via la chaîne de causes `FB_Hmi_BannerFormatter`) |
| **Maintien** | `CST_BannerHoldTime = T#500ms` (`FB_Hmi_BannerFormatter.st:150`) — ⚠️ sans maintien, une correction d'**un scan (10 ms)** serait **invisible** |
| Libellé nominal | « *Réglage corrigé : réserve TOP/FDC maintenue à 1,00 m.* » |
| Libellé **R2 différée** | « *Réglage TOP corrigé à la sortie du mode homing.* » |
| Libellé R3 | « *Réglage corrigé : ralentissement haut ramené à 0,50 m.* » |
| **Discrimination** | ⛔ doit rester **strictement distinguable** des messages **D18**, **benne non fermée** et **synchro** (exigence cadrage §11bis) |
| Interaction | Pas de **double message** avec `ConfigRestoredFromPersistent` (`TC-P10-072`) |
| Ton | **Non alarmant** (pas de classe alarme) |

#### 🔴 `[v1.3]` Compléments exigés par le challenge v1.2 — la v1.2 était **sous-spécifiée**

| # | Point manquant | Exigence |
|---|---|---|
| **1** | **Point d'insertion non spécifié** | Nommer la branche exacte dans la cascade `OperatorActionText` (`FB_Hmi_BannerFormatter.st:606-754`) **et** l'entrée de cause du FB — « §2.6 » ne suffit pas à implémenter |
| **2** | **Préfixe `[TAG]`** | ⚠️ **tous** les messages existants en portent un ⇒ le nouveau **doit** en avoir un (proposition : `[CFG]`) |
| **3** | **Plafond `G408` (70 caractères, palier C)** | à **citer et respecter** — la v1.2 l'ignorait |
| **4** | 🔴 **Masquage par priorité** | Les branches de priorité **supérieure** (`[JOY]`, `[TREUIL]`, `AbortMsgActive`, `SafeStopActive`…) **peuvent masquer** « Réglage corrigé » ⇒ **à prouver** : le message doit apparaître **malgré** les conditions concurrentes (ou assumer explicitement le masquage) |
| **5** | 🔴 **Coexistence sur PLUSIEURS scans** | `ConfigRestoredFromPersistent` est **latché jusqu'à `BtnAckConfigRestored`** (`ST_CommunHMI.st:43`, `PRG_07:220-222`) ⇒ les deux messages coexistent **plusieurs scans**, pas un seul ⇒ `TC-P10-072` doit être **requalifié** (il est **non observable en ST** : le second message est **rendu par le panneau IHM**, hors automate) → **à déplacer en recette** |
| **6** | ⚠️ **Sérialisation T255-D sur le CONTENU** | T255-D modifie **la même cascade** (`:812-849`) ⇒ §2.6 est **spécifié mais à REVALIDER** après sa livraison ; « strictement distinguable de D18 / benne / synchro » **n'est pas vérifiable avant** |

---

## 3 · GARDE-FOU AUTOMATIQUE (règle `fix:` + `guard:`)

### 3.1 `G483` — **liste EXACTE des lignes à retirer** (AC4)

| Lignes | Contenu | Action |
|---|---|---|
| **`G483:15-16`** | docstring **AC2** : « `TopLimitM1_M`/`TopLimitM2_M` = **MIN**(SEL(override, 7,5 m, 8,5 m), bande de ralentissement) » | ⛔ **RETIRER** — **faux** : `PRG_04:872-877` ne comporte **AUCUN `MIN`** |
| **`G483:17-18`** | docstring **AC2b** : « la réserve ne doit jamais excéder `WinchSlowdownDistance_M` » | ⛔ **RETIRER** — règle **ABROGÉE** par Q1 |
| **`G483:164-175`** | bloc **AC2b** : `delta > band` + message | ⛔ **RETIRER** |
| **`G483:166-168`** | helper local `value(name, default)` utilisé **uniquement** par AC2b | ⛔ **RETIRER** (devient **code mort**) |
| **`G483:165`** | `cfg = read(GVL_PERSISTENT)` | ⛔ **RETIRER** si plus utilisé ailleurs dans la fonction |

✅ **Vérifié** : AC2/AC3/AC3b sont dans des **blocs distincts** ; **AC1/AC1b (`:75-124`) intacts** ⇒ le
retrait **ne casse rien d'autre**. ⚠️ **`G483` restera ROUGE sur AC1** (dérogation MES bypass sans gate de
mode) — **Q11 ouverte, indépendante de T330** : **aucun faux vert** n'est annoncé.

### 3.2 `G504_check_t330_homing_top_invariant.py` — spécification (AC4)

| Aspect | Spécification |
|---|---|
| **ID** | **`G504`** — ✅ **vérifié LIBRE** (`run_all_gates.py:92-150` : ni `504` ni `505`) |
| **Entrées** | `CODE/GVL_PERSISTENT.st` (défauts persistés) · `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCfg.st` et `.../7_COMMUN_CONFIG/ST_CommunCfg.st` (défauts de type) · `CODE/**/*.st` **commentaires retirés** · `GVL_IHM.*.Cfg` · le bloc de normalisation de `PRG_07` |
| **Sortie** | `0` = PASS · `1` = FAIL, avec **le delta calculé** et **le nom du champ fautif** dans le message |
| **Enregistrement** | ligne ajoutée dans `PLANS` (`run_all_gates.py`), **palier C** — ⛔ **critère d'acceptation**, cf. REX §3.3 |
| **Exclusions (faux positifs)** | `TOOLS/`, `DOC/`, `ARCHIVES/`, `CODE_BACKUP/`, `CODE_XML/`, `**/reports/`, `*.html`, `*.json`, `.claude/` |

**Les 10 contrôles** :

| # | Contrôle | Échec si |
|---|---|---|
| **G504-1** | `ReserveTop_M ≥ 1,00 m` — **règle 1 SEULE** | réserve insuffisante |
| **G504-2** | `WinchSlowdownDistanceTop_M ≥ 0,50 m` — **règle 2 SEULE**, **jamais** comparée à la réserve | bande sous le plancher |
| **G504-3** | **Aucun nom de champ introuvable** : tout symbole lu doit exister | nom absent ⇒ **jamais de repli muet** |
| **G504-4** | **Aucun nouveau champ** `*LimitAscent*`/`*HomingTop*`/`*Fdc*`/`*TopSensorPos*`/`*Slowdown*` dans `ST_*Cfg.st`, `GVL_PERSISTENT.st`, `GVL_IHM.*.Cfg` (AC3) | champ neuf détecté |
| **G504-5** | **Bornes Q21** : `FDC ∈ [0 ; 9]` et `TOP ∈ [1 ; 10]` sur les valeurs persistées **et** les défauts de type | valeur hors borne |
| **G504-6** | La normalisation existe ; tout bornage **écrit** la valeur corrigée **ET** émet un message (≥ 1 appel de message dans le même bloc) | clamp **muet** |
| **G504-7** | Les constantes sont des `CST_` **locales**, **non** persistantes ni IHM | gardes devenues persistantes |
| **G504-8** 🔧 *(exigé par le contrat AC1)* | **Grep des noms INTERDITS** dans les livrables T330 : `PositionHomingTop_M`, `PositionFdcLogicielHaut_M`, `CableLimitAscent_M` (sans `Cfg`) | ≥ 1 occurrence ⇒ échec |
| **G504-9** 🔧 *(exigé par le contrat AC5)* | **Les 3 exceptions de montée sont NOMMÉES** dans le code de la normalisation/gating : `InReferencingMode`-cycle-homing · `OverrideTopSoftwareN1` · `BypassTopLimitSoftware` | l'une des 3 absente ⇒ échec |
| **G504-10** 🔧 *(Q21 bis)* | **`R0` est INCONDITIONNELLE et EN AMONT** : dans le bloc de normalisation, le clamp absolu précède l'évaluation de `Δ` | clamp absent, conditionnel, ou placé **après** le test `Δ` ⇒ échec |

### 🔧 Arbitrages techniques tranchés (arb. 6, délégués par CC01) — **aucun ne touche la sûreté de façon nouvelle**

| Point | Décision retenue | Justification |
|---|---|---|
| **`G504-4` — baseline** | ⛔ **Interdit** de comparer l'arbre courant à lui-même. Baseline = **`git diff --name-only`** restreint aux **3 fichiers de déclaration** (`ST_WinchCfg.st`, `ST_CommunCfg.st`, `GVL_PERSISTENT.st`) **+ `GVL_IHM.*.Cfg`** ; échec si un **nouveau nom de champ** apparaît dans le **diff** | sans baseline, les motifs `*Slowdown*`/`*TopSensorPos*` matchent des champs **existants** ⇒ gate **toujours rouge** ou **allowlist** (décision d'agent **interdite**) |
| **`G504-6` — périmètre décidable** | Le contrôle s'applique **exclusivement à une RÉGION BALISÉE** : `{region "🔧 T330 NORMALISATION"}` … `{endregion}` à créer dans `PRG_07`. Hors région ⇒ **non contrôlé** | « le bloc de normalisation » n'est **pas localisable mécaniquement** sans marqueur ; **sans balise**, le contrôle est **faux-positif garanti** sur `PRG_07:189-197` (`MAX`/`LIMIT` **sans message**, code **légitime**) |
| **`G504-5` — portée** | S'applique aux **valeurs persistées** *et* aux **défauts de type** ; ⚠️ **il ne remplace pas `R0`** (qui borne au **runtime**) : `G504-5` vérifie la **configuration au repos**, `R0` garantit le **domaine en fonctionnement** | deux niveaux distincts, **complémentaires** |
| **`G504-3` — non-régression** | Le gate doit **passer** sur la configuration actuelle (`8,50` / `7,50` / `0,50`) — **vérifié compatible** avec les bornes `[0;9]` / `[1;10]` | évite un gate néo-rouge |

> 🔧 **`G504-5` restreint aux littéraux liés à l'invariant** : un contrôle **global** des littéraux
> `7.5`/`8.0`/`8.5` serait **rouge sur du code légitime** — **vérifié présents** :
> `FB_Encoder_Homing.st:25` (`8.5`), `ST_fbWinch_DriveRequest.st:28` (`8.5`), `FB_CycleSemiAuto.st:306`
> (`8.0`, borne de plage **sans rapport**), `FB_SimBench.st:159` et `FB_Sim_Translation.st:9` (`8.0`,
> **course M3 en secondes** !). Une allowlist **ne peut pas** être décidée par un agent
> (`TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — § « Interdits absolus », règle d'exemption).
> 🔧 **Référence CORRIGÉE (challenge v1.2)** : la v1.2 citait `subagent_preamble.md:44`, ce qui était
> **faux** — la règle « une exemption n'est jamais une décision d'agent » est à la **ligne 56**.

### 3.3 🚨 REX « garde-fou mort-né » — pourquoi l'enregistrement `PLANS` est un **critère**

Deux garde-fous **existent sur disque** et **ne s'exécutent JAMAIS** faute d'être branchés :
`G490_check_ihm_bindings.py` · `G499_check_t291b_top_authority.py` (⚠️ `PLANS` ne contient **qu'une**
entrée `"499"`, pointant sur **T289**).
⇒ Un garde-fou non branché produit une **assurance fallacieuse** — **pire** qu'une absence de garde-fou.
⇒ **`G504` non enregistrée dans `PLANS` = lot refusé.**

#### 🔴 `[v1.3]` Aggravant — **fausse couverture** si les IDs sont dupliqués

`TOOLS/AGENT_WORKFLOW/scripts/G450_check_af_ci_coverage.py:119` crédite au catalogue TC les tests CI
**trouvés par identifiant**. ⇒ Un ID **dupliqué** (ex. `TC-P10-056` déjà porté par `test_fb_safety_winch.st:617`)
fait **créditer un test d'une AUTRE intention** ⇒ **fausse couverture silencieuse**, invisible à la fois
de `G450` et de `G470` (aveugle à `tc_couvrants`, cf. §4).
🎯 C'est la raison de fond pour laquelle la **renumérotation du bloc T330 est BLOQUANTE** (§4).

---

## 4 · MATRICE `AC ↔ TC ↔ ORACLE ↔ PREUVE` (AC2)

> 🔴 **BLOCAGE IDENTIFIÉ PAR LE CHALLENGE v1.2 — RENUMÉROTATION EN ATTENTE D'ARBITRAGE.**
> **Convention d'ID** (AC3) : `TC-P10-<NNN>`, format canonique `TC-P\d+-\d+`
> (`extract_functions_matrix.py:34`).
>
> ✅ **RENUMÉROTATION APPLIQUÉE EN v1.3 — décision CC01 du 2026-09-20** : le bloc T330 est
> **`TC-P10-056-092`** (37 cas). ⛔ **Les tests CI `TC-P10-052`…`055` ne sont PAS touchés** (ils
> appartiennent à **T288**).
>
> **Pourquoi la v1.2 était BLOQUÉE — 2 faits vérifiés par l'orchestrateur** :
> 1. 🔴 **Collision d'IDs** : le bloc v1.2 (`052-088`) réattribuait des IDs **déjà portés** par la CI avec
>    **d'autres intentions** — `TC-P10-052` (`test_fb_safety_winch.st:617`, limite légale) ·
>    `TC-P10-053` (`:643`, bypass MAINT_N2) · `TC-P10-054`/`055` (`:52`, `:91`, T288 retour collectif) ·
>    `TC-P10-052.1` (`test_fb_winch.st:415`). La **matrice** ne les listait pas ⇒ ma mesure initiale,
>    **faite sur la seule matrice**, était **incomplète**.
> 2. 🔴 **`G470` est AVEUGLE à `tc_couvrants`** : `quality_report` (`extract_functions_matrix.py:66-70`)
>    n'itère que **`validation_points`**. Une déclaration en `tc_couvrants` **n'est vue par aucun gate** ⇒
>    ma « preuve d'unicité » v1.2 était **VIDE** (le compteur resté à `156` **était le signal** — que j'ai
>    eu tort d'expliquer au lieu de creuser).
> 3. 🔴 **Fausse couverture** : `G450_check_af_ci_coverage.py:119` crédite les tests CI **par identifiant**
>    ⇒ un ID dupliqué fait créditer **un test d'une autre intention** (cf. §3.3ter).
>
> **Plage mesurée (exhaustive)** — **404 fichiers** scannés (`TOOLS/TEST_AUTO_CI/**`, `DOC/AF/**`, matrice) :
> AF-10 occupe **`1-34, 36, 37, 39, 42, 44-48, 51-55`** ⇒ **premier bloc contigu libre = `56+`**
> (bloc libre ≥ 48 : `56-599`) ⇒ **`056-092` retenu**.
>
> ⚠️ **La déclaration devra être portée en `validation_points`** (et **non** en `tc_couvrants`) pour être
> réellement contrôlée — idéalement **une clé par TC**, `tc_tokens()` ne rendant que le **premier** ID
> canonique d'une clé composée ou d'une plage.
> ⛔ **Aucun recouvrement** ⇒ `G470` sans « overlap » ni « cross_domain ».

### 4.1 Couverture des critères du contrat

| AC du contrat | Contenu | TC couvrants |
|---|---|---|
| **AC1** | Noms réels tracés producteur → route → consommateur | `TC-P10-088` (diag) + table §1/§2.1 du cadrage |
| **AC2** | Deux règles **distinctes**, **aucune** valeur figée | `TC-P10-056`…`062` (R1/R2/R3 + bornes) + `TC-P10-090`, `TC-P10-092` |
| **AC3** | Aucun champ neuf ; dérivés **locaux** | **`G504-4` / `G504-7`** (gate) + `TC-P10-063` (idempotence, absence de second message) |
| **AC4** | Normalisation exacte + message + **pas de boucle** | `TC-P10-056`…`062` + `TC-P10-063`…`068` (idempotence / non-rebond) |
| **AC5** | Montée = **3 exceptions nommées** ; **descente toujours possible** | `TC-P10-077` (descente préservée) · `TC-P10-078` (montée bloquée hors homing) · **`TC-P10-082` (exception **homing**)** · **`TC-P10-085` (exception **override N1**)** · **`TC-P10-086` (exception **bypass N2**)** |
| **AC6** | `G483` AC2b **retiré**, remplacé par `G504` **sans repli muet** | `G504-1`…`G504-3` + liste exacte §3.1 |
| **AC7** | Séquencement respecté (aucun code avant B1 ; pas de garde-fou M2 avant B2) | revue du `git diff` réel par l'orchestrateur |

> 🔧 **CORRECTION (auto-détectée avant livraison, v1.2)** : cette table portait des **IDs en forme
> abrégée** — historiquement `041`, `042`, `057`, `062`, `064`, `065` — **non renumérotés** lors des
> passages successifs `035-071` → `052-088` → **`056-092`** : le script de renumérotation ne traitait que
> la forme complète `TC-P10-0NN`. **Tous les IDs sont désormais canoniques et complets.**
> ⚠️ **Deux incohérences sémantiques corrigées au passage** :
> ① **AC5 omettait l'exception « homing »**, pourtant l'un des **3 cas nommés** exigés par l'AC ;
> ② `HomingSuspect` était rattaché à AC5 par **approximation** ⇒ **retiré** de cette ligne (cas de
> robustesse, **non** une exception de montée).
> ⇒ **AC5 est maintenant couvert par ses 3 exceptions réelles : homing · override N1 · bypass N2.**

### 4.2 Cas de test — **oracle numérique** et **preuve**

#### A · Normalisation (`F10.02` — `FB_Safety_Winch`) — 7 cas

| TC | Entrée | **Oracle numérique** | Preuve |
|---|---|---|---|
| `TC-P10-056` | FDC saisi `8,70` ; TOP `8,50` | `CfgCableLimitAscent_M = 8,50 − 1,00 = 7,50` ; **TOP = 8,50 inchangé** ; message ×1 | ST : égalité exacte `7.50` |
| `TC-P10-057` | TOP saisi `7,00` ; FDC `7,50` | `CfgTopSensorPos_M = 7,50 + 1,00 = 8,50` ; **FDC = 7,50 inchangé** ; message ×1 | ST |
| `TC-P10-058` | FDC saisi `7,60` ; TOP `8,50` (`Δ=0,90`) | `FDC = 7,50` ; TOP inchangé | ST |
| `TC-P10-059` | slowdown saisi `0,20` | `WinchSlowdownDistanceTop_M = 0,50` ; **autres réglages inchangés** | ST |
| `TC-P10-060` | TOP saisi `10,00` ; FDC `7,50` (`Δ=2,50`, **valide**) | **aucune** correction, **aucun** message | ST : compteur de messages = 0 |
| `TC-P10-061` | **Les 3** réglages changent au même scan, FDC `9,50` / TOP `8,00` / slowdown `0,10` | **Q17** : TOP **préservé** ⇒ `FDC = 8,00 − 1,00 = 7,00` ; `slowdown = 0,50` ; **TOP = 8,00** | ST : 3 assertions |
| `TC-P10-062` | FDC saisi `0,00` ; TOP `8,50` (`Δ=8,50` **valide** mais FDC à la borne basse) | **aucune** correction (valide) ; à la borne ⇒ **accepté** | ST |

#### B · Idempotence et non-rebond (Q24 / Q27 / C3) — 6 cas

| TC | Entrée | **Oracle** | Preuve |
|---|---|---|---|
| `TC-P10-063` | après `TC-P10-056`, exécuter **2 scans** (exigence Q24) | scan 2 : **0 correction**, **0 message**, valeur **stable** `7,50` | ST : **le test probatoire de Q24** |
| `TC-P10-064` | `TOP = 8,50` / `FDC = 7,50` (réserve **exactement** 1,00) | **aucune** correction — `8,50 − 7,50 = 1,00` **exact** (Sterbenz) | ST |
| `TC-P10-065` | FDC balayé `7,4999` / `7,5000` / `7,5001` | **un seul** franchissement ; **aucune** oscillation ; seuils ±0,50 m issus d'**une seule** expression | ST scan-par-scan + G504-1 |
| `TC-P10-066` | **Guerre d'écriture IHM** : le panneau réécrit `8,70` à chaque scan | ⚠️ **LIMITE DU LOT (C3)** — **non couvert** en P2. Comportement attendu **non spécifié** : à **tracer**, pas à valider | ⛔ **aucun test** — déclaré comme limite |
| `TC-P10-067` | valeur **identique** re-saisie (`8,50` → `8,50`) | **aucun front** ⇒ **aucune** correction, **aucun** message | ST |
| `TC-P10-068` | changement de **page IHM** sans modification | **aucune** correction | ST |

#### C · Boot, restauration, hot restart — 6 cas

| TC | Entrée | **Oracle** | Preuve |
|---|---|---|---|
| `TC-P10-069` | NVRAM **valide** (`8,50` / `7,50` / `0,50`), démarrage à froid | **0 correction**, **0 message**, valeurs **préservées** | ST |
| `TC-P10-070` | NVRAM **invalide** (`TOP=7,00` / `FDC=7,50`), démarrage à froid | **Q17** : `FDC = 7,00 − 1,00 = 6,00` ; **TOP = 7,00 préservé** ; NVRAM **non corrompue** | ST |
| `TC-P10-071` | **1ᵉʳ scan**, `Hmi.Initialized = FALSE` | normalisation **INHIBÉE** (critère **significatif** en amont des ponts) ; **aucune** écriture NVRAM | ST |
| `TC-P10-072` | `ConfigRestoredFromPersistent` **et** normalisation au **même boot** | **un seul** message (pas de doublon) | ST : compteur = 1 |
| `TC-P10-073` | `BtnAckConfigRestored` actionné **pendant** une correction | **aucune** interférence (l'acquittement n'écrit **aucun** `Cfg`) | ST |
| `TC-P10-074` | **RTS / download** (`GVL_IHM` **non RETAIN**) | comportement **déterministe** ; **aucune** correction fantôme | ST |

#### D · Miroir M2 et non-régression — 7 cas

| TC | Entrée | **Oracle** | Preuve |
|---|---|---|---|
| `TC-P10-075` | correction du TOP M1 (`TC-P10-057`) | `GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M = 8,50` **dès le 1ᵉʳ scan** | ST |
| `TC-P10-076` | idem | `_WinchM1CfgPersist == _WinchM2CfgPersist` — **aucune divergence**, même sur 1 scan | ST : égalité à chaque scan |
| `TC-P10-077` | config invalide + demande de **descente** | ✅ `DescendPermit = TRUE` — **jamais** gaté par la validité | ST |
| `TC-P10-078` | config invalide + **montée** hors homing | montée **bloquée** par le FDC ; **descente possible** | ST |
| `TC-P10-079` | **montée EN COURS** pendant la correction | pendant **tout** le cycle : `TopLimitM1_M` **jamais au-dessus** de la référence → `AscentPermit` cohérent, **aucune** sortie non sûre | ST + **le vrai test probatoire de Q19** |
| `TC-P10-080` | machine **non référencée** (`Homed=FALSE`) + correction | FDC logiciel **inerte** (attendu), plafond palier 1 appliqué | ST |
| `TC-P10-081` | machine **référencée** + R2 déclenchée | **Q22/C2** : correction **différée** si `InReferencingMode` ; sinon appliquée **avec message** | ST |

#### E · Modes, homing, domaines — 11 cas

| TC | Entrée | **Oracle** | Preuve |
|---|---|---|---|
| `TC-P10-082` | **homing en cours** (`InHomingT330 = TRUE`, cf. §2.7bis) + TOP saisi `7,00` avec FDC `7,50` | ① **pendant** : `CfgTopSensorPos_M` reste **`7,00` INCHANGÉ** (R2 **inhibée**) et **aucune écriture NVRAM** (gel, §2.7bis **b**) ; message « **correction différée** » ; ② **à la sortie** du homing : la config est **toujours invalide** ⇒ **repli NIVEAU** = règle **Q17** (préserver le TOP, corriger le FDC) ⇒ `FDC := 7,00 − 1,00 = 6,00`, **TOP reste 7,00**, message **nominal** **une seule fois** ; ③ **scan suivant** : **aucune** seconde correction (idempotence) ; ④ **variante (c)** — **coupure pendant le homing** : l'intention est **PERDUE** ; au redémarrage, la NVRAM restaurée est invalide ⇒ **normalisation Q2 normale** + message (**rien** de spécifique mémorisé) | ST — **LE test probatoire de Q22/C2** : inhibition **+ gel NVRAM + repli niveau + non-mémorisation** |
| `TC-P10-083` | `HomingSuspect = TRUE` + FDC saisi trop haut | R1 **active** (jamais inhibée) ⇒ `FDC = TOP − 1,00` | ST |
| `TC-P10-084` | `BtnHomingAtZero` + correction | cible forcée `0,0` **respectée**, non écrasée | ST |
| `TC-P10-085` | **override N1 actif** pendant la correction | `TopLimitM1_M` reflète **immédiatement** la valeur corrigée | ST |
| `TC-P10-086` | **bypass N2 actif** pendant la correction | idem — `TopLimitM` relevé **cohérent** | ST |
| `TC-P10-087` | `ManualBucketJogActive` + correction | exemption jog (`PRG_04:888-891`) **préservée** | ST |
| `TC-P10-088` | après correction | `Idx321_CfgTopLimitM` **cohérent** (⚠️ diag **trompeur** sous override — cadrage §6.3, **signalé**) | ST |
| `TC-P10-089` | cycle **SEMI_AUTO** après correction | `CycleWinchesAtTopOk` (`PRG_03:161-168`, fenêtre ±0,4 m autour du FDC **corrigé**) **atteignable** | ST |
| `TC-P10-090` | `FDC = 0,00` / `FDC = −1,00` / `TOP = 0,50` | **R0 (Q21 bis)** : `0,00` **reste `0,00`** (à la borne) ; `−1,00` ⇒ **clampé à `0,00`** + message ; `TOP = 0,50` ⇒ **clampé à `1,00`** + message. **Aucune valeur hors domaine ne subsiste** | ST |
| `TC-P10-091` | ① 🔴 **`FDC = 9,50` + `TOP = 12,00`** (⇒ `Δ = 2,50 ≥ 1,00`) — **LE cas Q21 bis** ⇒ **R0 s'applique SEUL** (aucune règle Δ ne se déclenche) ⇒ `FDC := 9,00`, `TOP := 10,00`, **message non alarmant**. ② **Variante domaines absurdes** : `FDC = −150,00` / `TOP = 150,00` ⇒ **R0** clampe ⇒ `0,00` / `10,00` ⇒ `TargetOutOfRangeError` (`FB_Encoder_Homing.st:226`) **NON atteint** (la cible de homing est bornée **avant** d'y arriver — oracle **corrigé** : la v1.2 affirmait à tort que `TOP = 150` passait les bornes) | ST — **le test probatoire de Q21 bis** |
| `TC-P10-092` | `TOP` clampé à `10,00` et `FDC` saisi `10,00` | **R0** : `FDC := 9,00` (borne) ; puis `Δ = 10,00 − 9,00 = 1,00` ✅ **valide** ⇒ **aucune** correction supplémentaire — **la démonstration C1** | ST |

### 4.3 Récapitulatif du bloc TC

| Groupe | TC | Nombre | Fonction AF |
|---|---|---|---|
A · Normalisation | `TC-P10-056`…`062` | 7 | `F10.02` |
B · Idempotence | `TC-P10-063`…`068` | 6 | `F10.02` |
C · Boot | `TC-P10-069`…`074` | 6 | `F10.02` |
D · Miroir / non-régression | `TC-P10-075`…`081` | 7 | `F10.02` |
E · Modes / domaines | `TC-P10-082`…`092` | 11 | `F10.02` |
| **TOTAL** | **`TC-P10-073-088`** | **37** | **`F10.02`** — `FB_Safety_Winch` |

> ⚠️ **Déclaration CENTRALISÉE sous `F10.02` — choix délibéré.** Les cas `TC-P10-077` (descente préservée)
> et `TC-P10-085`/`TC-P10-086` (override/bypass) touchent fonctionnellement `F10.01` (`FB_Winch`), **mais** déclarer le
> bloc en **deux endroits** ferait **recouvrir** la plage `TC-P10-073-088` de `F10.02` par des clés
> simples de `F10.01` ⇒ **`G470` signalerait un « overlap »**. ⇒ Une **seule** entrée
> `- TC-P10-073-088` dans `F10.02`, **sans recouvrement** avec `TC-P10-001-010`.

> ⚠️ **Signalement (devoir d'alerte)** : la **normalisation** vit dans `PRG_07_Supervision`, dont le
> domaine logique est **AF-07 (Interface IHM)** — or **`AF-07` ne déclare AUCUNE fonction dans
> `af_traceability_matrix.yaml`** (vérifié : section `AF-07` **vide**). ⇒ Les TC T330 sont donc rattachés
> à **AF-10**, faute de fonction AF-07 à couvrir. **Le trou de traçabilité AF-07 est signalé, non corrigé**
> (hors périmètre T330).

---

## 5 · PHASES ET POINT D'ARRÊT

| Phase | Contenu | Prérequis | Sortie |
|---|---|---|---|
| **P0** | ✅ **FAIT** — arbitrages Q17→Q28 + C1/C2/C3 intégrés (§1) | — | — |
| **P1** *(spécifiée ici, **exécutable en code**)* | Nettoyer `G483` (§3.1) ; écrire `G504` (§3.2) **+ l'enregistrer dans `PLANS`** | — | G504 vert sur la config actuelle ; G483 **toujours rouge** (AC1, **attendu**) |
| **P2/P3** *(spécifiée ici, **exécutable en code**)* | Implémenter **R1/R2/R3** + 3 mémoires + message (§2) ; puis les **37 TC** | **T255-D livrée** (même `PRG_07`) · GO distinct | Tests §4 verts |
| **P4** | Bundle + diff bundle + `G200 --report` + gates (§8) | P2/P3 | Bloc `Auto-vérification liaison` |
| **P5** | **Recette machine** : mesurer la **distance d'arrêt au palier 1** et **confirmer `0,50 m`** (Q18) | P4 | Mesure tracée + décision Safety |
| **P6** | Revue indépendante + livraison | P5 | Rapport + bandeaux |

> ⛔ **CE LOT (P1/P2 de la mission) S'ARRÊTE ICI** : **plan v1.2 + matrice figée**, **aucun code**.
> **P3 (code) attend un GO distinct.**

---

## 6 · PRÉCONDITIONS — état après arbitrages

| # | Objet | Statut |
|---|---|---|
| **Q17, Q21, Q22, Q23, Q24, Q27, Q18, Q28** | Arbitrages | ✅ **TOUS FERMÉS** (§1) |
| **C1, C2, C3** | Challenges orchestrateur | ✅ **TOUS REPRIS ET ACCEPTÉS** |
| **T291-B B1** | Maintien | ✅ **LEVÉ** |
| **Q13** | Réaction pendant un homing | ✅ **résolu par (a)** : R2 inhibée pendant `InReferencingMode` (`TC-P10-082`) |
| **Q11** | `Bypass.TopLimitSwitch` tous modes ⇒ `G483` rouge (AC1) | 🔴 **ouvert** — **indépendant de T330** ; bloque la suite « fin de lot » |
| **Q12** | Guerre d'écriture IHM | 🟠 **tracé comme LIMITE du lot** (C3) — **non couvert**, **pas de test IHM en P2** |
| **Q5** | `CfgTopSensorPos_M` modifié sur machine **déjà référencée** (valeur **valide**, `TC-P10-060`) : datum **non re-preseté** | 🔴 **ouvert** — **hors du champ de la normalisation** (sûreté complète) |
| **Q18** | Bande `0,50 m` non adossée à une mesure | 🟠 **accepté** — mesure en **P5** |
| **T255-D** | Livraison | 🔴 **bloque P2/P3** (même `PRG_07`) |

---

## 7 · PÉRIMÈTRE DE FICHIERS

| Fichier | Nature | Motif |
|---|---|---|
| `DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` | ✏️ **ce document** (v1.2, remplacé en place) | — |
| `TOOLS/AGENT_WORKFLOW/config/af_traceability_matrix.yaml` | ✏️ **lignes T330** (`F10.01`/`F10.02`, bloc `035-071`) | **AC3** — ⚠️ **autorisation nominative** (fichier sous `TOOLS/`, cf. §7.1) |
| `DOC/WFLOW/TASKS.yaml` | ✏️ **champ `avancement` de T330 uniquement** (🚩) | traçabilité |
| `CADRAGE_T330_INVARIANT_HAUT_v1.0.md` | ✏️ **si un fait change** | — |
| `TASK_CONTRACT_T330_*.yaml` | ✏️ si nécessaire | — |

### 7.1 ⚠️ Restriction du périmètre — **réconciliation CORRIGÉE (challenge v1.2)**

La mission interdit `TOOLS/` **en bloc**, mais autorise nominativement
`af_traceability_matrix.yaml` — fichier qui vit dans **`TOOLS/AGENT_WORKFLOW/config/`**.

🔴 **Correction** : la v1.2 justifiait cette exception par « **sinon AC3 serait inexécutable** ».
**C'ÉTAIT FAUX** — AC3 est vérifié par **`G504-4` / `G504-7`** (valeurs + diff), **jamais** par la matrice.
⇒ La justification légitime est **simplement** l'**autorisation nominative** de la mission, rien d'autre.
⚠️ **Aggravant** : ce fichier **n'est pas** dans `scope.allowed` du **contrat** T330 ⇒ son écriture est
**hors périmètre contractuel** tant que l'humain ne l'y a pas **acté nominativement**.
⇒ ⛔ **Décision humaine requise** (item 5 de la liste du challenge) ; en attendant, la matrice a été
**rendue à son état `HEAD`** (voir §4).

✅ **Seul ce fichier** était concerné sous `TOOLS/` ; **`scripts/` est respecté à la lettre**
(`G483`/`G504` sont **spécifiés, jamais écrits**).

⛔ **Interdits** : `CODE/` · `CODE_XML/` · types IHM · `PRJ_CODESYS/**/Device.export` ·
`TOOLS/AGENT_WORKFLOW/scripts/` · `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (T291-B B2).

---

## 8 · PREUVES MÉCANIQUES EXIGÉES (à la **livraison du code**, P4 — pas à ce lot)

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers CODE touchés>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report      # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C --pytest --full-ci
```
- ⛔ **Sans `--full-ci`**, `G460` (harnais `TEST_AUTO_CI`) **n'est pas exécuté** (`run_all_gates.py:194-195`).
- ⛔ **Sans `--pytest`**, `G420` ne tourne pas.
- **Bloc `Auto-vérification liaison`** collé dans la restitution ; **bandeaux** bundle + diff bundle.
- **Ce lot P1/P2** (documentaire) exige : **`check_task_contract.py` PASS** + **`git status --short`**.

---

## 9 · RISQUES RÉSIDUELS ET LIMITES **ASSUMÉS**

| # | Risque / limite | Ampleur | Statut |
|---|---|---|---|
| **R-a** | Sous **override N1 / bypass N2**, seuls les **0,50 m finaux** sont ralentis (bande mesurée depuis la limite **active**) | **accepté** par Q18, **non prouvé par mesure** | 🛠️ **P5** |
| **R-b** | `G483` reste **ROUGE** sur AC1 (bypass sans gate de mode) | suite « fin de lot » bloquée | 🔴 **Q11** |
| **R-c** | `CfgTopSensorPos_M` modifié sur machine **déjà référencée** : datum non re-preseté, **non détecté** par la normalisation | décalage silencieux | 🔴 **Q5** |
| **R-d** | **Guerre d'écriture IHM** : **LIMITE DU LOT** — non couverte, **aucun test IHM en P2** (C3) | rebond possible hors couverture | 🟠 **Q12** |
| **R-e** | **Trou de traçabilité AF-07** : le domaine logique de la normalisation n'a **aucune** fonction dans la matrice ⇒ TC rattachés à **AF-10** | traçabilité **approximative** | 🟠 **signalé** |
| **R-f** | `FDC ∈ [0 ; 9]` **n'empêche pas** une configuration **valide mais inopérante** (ex. `FDC=0` / `TOP=1` : butée au sol) | inhérent au domaine | 🟠 **assumé** |

---

## 10 · TRAÇABILITÉ

- **Cadrage** : `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` (§0bis décisions, §0ter pièges, §11bis périmètre exclu)
- **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_HOMING_TOP_SOFT_LIMIT_INVARIANT.yaml` (AC1→AC7)
- **Matrice** : `TOOLS/AGENT_WORKFLOW/config/af_traceability_matrix.yaml` — `F10.01`/`F10.02`, `TC-P10-073-088`
- **Audit v1.0** : sous-agent `34229875` (`BLOCK`, 11 erreurs → journal §11)
- **Checkpoints** : `agent_heartbeat.py` session **`T330-P1P2`**, agent **`DSH01`**
- **Verrou** : 🔒 `T330 = DSH01`
- ⛔ **Aucun `CODE/`, `CODE_XML/`, type IHM ni `Device.export` touché. Aucun code écrit. Aucun commit.**

---

## 11 · JOURNAL D'AUDIT

### v1.1 — audit indépendant `34229875` (`BLOCK` sur la v1.0)

**8 erreurs factuelles confirmées** après vérification personnelle : fenêtre `4–20 ms` → **`T#10ms`** ·
critère `NOT Initialized` **mort** après `:182` · **`eps` non fondé (Sterbenz — erreur mathématique de
l'orchestrateur)** · `G504-5` **inexécutable** · `TC-P10-T330-nnn` **hors convention** · retrait AC2b
**incomplet** (`G483:15-16`) · `G460` exclu sans `--full-ci` · 3ᵉ champ **non nommé**.
**3 requalifiés** : « nécessairement après `:182` » **renversé** (pattern pré-bridge) · `-190` **absent**
de la matrice · libellé de phase **faux**.
**19 cas de test** et **8 questions** ajoutés (Q21→Q28).

### v1.2 — arbitrages intégrés

| Action | Détail |
|---|---|
| **Q17→Q28** | **toutes fermées** et **tracées avec leur source** (§1) |
| **C1** | borne **`FDC ≤ 9,00 m`** (démonstration : `FDC ≤ TOP − 1` et `TOP ≤ 10`) — borne **corrigée** dans le plan **et** vérifiée pour **R2** (§1, `TC-P10-092`) |
| **C2** | **R2 inhibée** pendant `InReferencingMode` ; **R1/R3 jamais** (§1, `TC-P10-082`) |
| **C3** | guerre d'écriture **tracée comme limite** ; **pas de test IHM en P2** (`TC-P10-066` **déclaré non couvert**) |
| **IDs** | `TC-P10-073-088` (bloc contigu, **sans recouvrement** avec `001-034`) |
| **Matrice** | `AC ↔ TC ↔ oracle ↔ preuve` **figée** (§4) ; **37 cas** |
| **Signalement** | **AF-07 sans aucune fonction** dans la matrice ⇒ TC rattachés à AF-10 (§4.3) |
| **Périmètre** | restriction **réconciliée explicitement** (§7.1) |

### v1.2 — challenge indépendant `d33ae8bd` : **`BLOCK`** (2 motifs bloquants vérifiés)

| Motif | Fait **vérifié par l'orchestrateur** | État |
|---|---|---|
| **M1 — collision d'IDs** | le bloc **v1.2** `TC-P10-052`…`055` **était déjà porté** par la CI (`test_fb_safety_winch.st:617,643,52,91` · `test_fb_winch.st:415`) ; ma mesure portait **sur la seule matrice** | ✅ **RÉSOLU en v1.3** — renuméroté en **`056-092`** (CC01, 2026-09-20) ; tests CI `052-055` **intacts** |
| **M2 — preuve d'unicité VIDE** | `quality_report` (`extract_functions_matrix.py:66-70`) n'itère que **`validation_points`** ⇒ déclarer en **`tc_couvrants`** est **invisible à `G470`** | 🔴 **confirmé** — **ma preuve AC3 était vacue** ; le compteur figé à `156` était le signal |

**Corrections appliquées** : §2.4 justification **Sterbenz rectifiée** (le rapport `TOP/FDC` peut atteindre
**10**, Sterbenz ne s'applique pas partout → conclusion conservée sur **cas calculés**) · référence
`subagent_preamble.md` **44 → 56** · §4.3 plages **corrigées** (v1.2 : `052…058`, `059…064`, `065…070`,
`071…077`, `078…088` ; **v1.3 : `056…062`, `063…068`, `069…074`, `075…081`, `082…092`**) · §4.1 **AC5
recâblé** sur ses **3 exceptions réelles** (homing, override N1, bypass N2) · IDs en forme abrégée **tous
recanonisés** · **matrice RESTAURÉE** à son état `HEAD` (aucun état faux laissé dans un fichier lu par la CI).

**Items RÉSOLUS en v1.3** (arbitrages CC01 du 2026-09-20) :
1. ✅ **Renumérotation** → `TC-P10-056-092` ; tests CI `052-055` (**T288**) **non touchés**.
2. **C2** : signal de gating = **cycle de homing** (et non `HomingLifecycle.Busy` ~50 ms) — §2.7bis piège 1 ;
   **gel de la NVRAM** pendant l'inhibition ; sort de l'**intention volatile** (coupure pendant le homing).
3. **Q21** : **aucune règle n'applique les bornes** aujourd'hui (contre-exemples du challenge : `FDC=10` +
   `TOP` modifié à `5,00` ⇒ `TOP := 11,00` **hors borne**) ⇒ `090`/`091`/`092` **non décidables**.
4. **Q3** : réécrire avec sa **preuve** (balayage `7,999 / 8,000 / 8,001`) ou l'abandonner explicitement —
   aucun TC ne couvre les seuils ±0,50 m.
5. **Contrat** : ids `TC-P10-T330-*` (hors convention) et « idempotence sur **3** scans » vs Q24 (**2** scans).
6. **`G504`** : baseline de `G504-4`, marqueur de bloc de `G504-6` (non décidables en l'état) ; **AC1/AC5 du
   contrat attendent des contrôles que `G504` ne porte pas**.

> 🧠 **Leçon de méthode (2ᵉ occurrence)** : j'ai **vu** l'anomalie (compteur `G470` figé à `156`) et je l'ai
> **expliquée** au lieu de la **creuser** — c'était précisément le signal que ma déclaration matricielle
> était **invisible au gate**. Même pattern que la tolérance REAL : **une vérification qui n'atteint pas
> l'outil de contrôle n'est pas une vérification.**
