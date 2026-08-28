# T167-CR — Revue de code indépendante & certification (FB_DiveSearch / FB_ExtractionSequence)

> Revues confiées au sous-agent Ollama local (`deepseek-v4-flash:cloud`), **séparément** par brique.
> Validation finale = orchestrateur (lecture du `git diff` réel + vérification par test).

---

## 1. FB_DiveSearch — revue Ollama `deepseek-v4-flash` (2026-08-28)

**Verdict Ollama : REJETÉ** sur 1 écart MAJEUR + 2 mineurs.

### Écart MAJEUR #1 — « non-redémarrage auto violé au cycle Enable OFF/ON »
> Scénario Ollama : timeout → `ERROR_HOLD` + `Fault.Latched`. Enable OFF → gate force
> `DiveState := WAIT_PRECONDITIONS`. Enable ON → `Fault.Error` supposé retombé (cause plus
> présente) → `WAIT_PRECONDITIONS` peut repartir vers `READY_TO_DESCEND` sans Reset.

**Statut orchestrateur : FAUX POSITIF — prémisse incorrecte.**
La « cause » du timeout est le BOOL interne `TimeoutImmersionFault` (`Latching:=TRUE`), **jamais
effacé au gate**, seulement par le bloc Reset gardé. À `Enable=TRUE`, `instCauses[4].Active` est
donc encore TRUE → `FB_FaultCore` ré-évalue la vue live → **`Fault.Error` revient TRUE** au premier
scan → §3 force `ERROR_HOLD`. Pas de redémarrage possible.

**Preuve** : `TC-P04-015` étendu — après Enable OFF→ON sans Reset :
`Fault.Latched=TRUE`, `Fault.Error=TRUE`, `DiveState=ERROR_HOLD`, `DescendPermit=FALSE`. ✅

**Action défense en profondeur (appliquée quand même)** : garde explicite
`IF Fault.Error OR Fault.Latched THEN DiveState := ERROR_HOLD` — la propriété de sécurité
devient locale et lisible, sans dépendre du raisonnement sur le ré-feed de `FB_FaultCore`.

### Écarts mineurs
- **#2** — 1 scan de latence sur `KoboldContactorCmd:=FALSE` quand `SeqErrorFault` est levé en §3
  (agi en §1 au scan suivant + `ERROR_HOLD`). **Pré-existant**, hors scope T167, pattern homogène
  au reste du FB. `ERROR_HOLD` coupe aussi le contacteur.
- **#3** — pas de garde de position basse directe en `SEARCHING_BOTTOM` (arrêt par timeout seul).
  **Pré-existant** : la limite légale est appliquée en aval par `PRG_04` (`BottomLimitM`), le permis
  descente est gardé ailleurs. À considérer comme durcissement futur, pas un défaut T167.
- **#4 (info)** — Reset exige `NOT MotionRequestActive` : peut bloquer le réarmement si l'opérateur
  maintient la commande. **Conforme spec** — à documenter côté IHM.

**Décision : CERTIFIÉ** (l'unique MAJEUR est un faux positif prouvé + garde-fou ajouté).

---

## 2. FB_ExtractionSequence — revue Ollama `deepseek-v4-flash` (2026-08-28, prompt court §3)

> Rapport brut archivé : `DOC/WFLOW/T167-CR_ollama_FB_ExtractionSequence.md`.
> (Endpoint `http://127.0.0.1:11434` relancé ; le prompt complet 21 Ko dépasse le timeout 180 s du
> runner — revue faite sur l'extrait §1-§3.)

**Verdict Ollama : MAJEUR.**

### MAJEUR #1 — « Reset → `WAIT_BOTTOM_CONFIRMATION` sans confirmation fond *fraîche* »
> Après défaut en `CONTROL_ASCENT`, si `BottomPositionConfirmed` reste TRUE (capteur collé),
> la séquence repart `WAIT_BOTTOM → READY_TO_CLOSE` sur **niveau** (pas front) → reprise possible.

**Statut orchestrateur : observation valable, mais PRÉ-EXISTANTE — hors scope T167-C.**
La transition `WAIT_BOTTOM_CONFIRMATION → READY_TO_CLOSE` sur niveau est dans le code baseline,
**inchangée** par T167-C (qui n'ajoute que les timeouts + StepAtFault). Effet réel : la benne est
déjà fermée après `CLOSING_BUCKET` → fast-forward vers `CONTROL_ASCENT` → reprise de l'ascension
(aucune descente commandée, aucune réouverture benne). Recovery discutable, pas dangereux en l'état.
→ **Candidat durcissement** (sémantique de reprise à définir en spec) — voir §4.

### Mineurs / Info — non-défauts (vérifiés orchestrateur)
- « division par zéro si `CST_MinSpeed_Mps = 0` » : `VAR CONSTANT := 0.15`, littéral compile-time,
  non configurable — impossible.
- « `MotionDirection = 1` : si fermeture = descente, accu jamais incrémenté » : `+1 = montée`
  (la benne se ferme en tirant vers le **haut**), même direction que l'entrée `CLOSING_BUCKET`. Cohérent.
- « `PrevState` MAJ fin de scan ? » : présent (hors extrait fourni).
- « gate ne coupe que 3 sorties, et treuils/freins ? » : FB **séquenceur**, pas muscle — produit des
  permis/demandes ; coupure treuil/frein = chaîne PRG_04 (`SafeStop`/`EffectivePermit`) + barrière PRG_06.
  Gate complet pour son périmètre.

**Décision : CERTIFIÉ pour le périmètre T167-C.** Le MAJEUR est pré-existant → item de durcissement §4.

### Revue orchestrateur (complémentaire) :
- Revue deepseek en phase dev : PASS avec 3 réserves → **toutes traitées** (contrôle runtime
  ordre des watchdogs via `BucketMoveTimeout`, garde `CycleTime<=T#0ms`, `StepAtFault` reset conditionné).
- L'écart MAJEUR #1 de la revue DiveSearch a la **même prémisse** ici (même socle `FB_FaultCore`
  + latches internes `TimeoutBucketCloseFault`/`TimeoutControlAscentFault` non effacés au gate) →
  **même conclusion** (faux positif) + **même garde-fou appliqué** :
  `IF Fault.Error OR Fault.Latched THEN ExtractionState := ERROR_HOLD`.
- **Preuve** : `TC-P04-024` étendu — Enable OFF→ON sans Reset : `Fault.Latched=TRUE`,
  `ExtractionState=ERROR_HOLD`, `AscentPermit=FALSE`. ✅

**Décision : CERTIFIÉ pour le périmètre T167-C** (le MAJEUR Ollama est pré-existant, hors scope).

---

## 3. Bilan mécanique (les 2 briques, état committé)

| Contrôle | Résultat |
|---|---|
| `FB_DiveSearch` STruCpp | **7/7 PASS** |
| `FB_ExtractionSequence` STruCpp | **6/6 PASS** |
| Non-régression | FB_Cycle 7/7, PRG_03 5/5, PRG_07 3/3 |
| `G200_check_linkage` | PASS (0 erreur) |
| `run_all_gates` (tout) | **PASS** |

---

## 4bis. 2ᵉ avis indépendant — `codex/gpt-5.6-terra-high` (omniroute, 2026-08-28)

> Endpoint `deepseek-v4-flash` étant lent sur gros prompts, 2ᵉ revue via le gateway `omniroute`
> (`omniroute_subagent.py`, `http://localhost:20128/v1`) sur un modèle plus capable.
> Rapports bruts : `T167-CR_omniroute_FB_DiveSearch.md`, `T167-CR_omniroute_FB_ExtractionSequence.md`.
> **Verdict des 2 : REJETÉ** — findings triés ci-dessous.

### Findings retenus → passe de durcissement appliquée (les 2 FB)

| # | Constat | Correctif appliqué | Test |
|---|---|---|---|
| **H1** | `KoboldContactorCmd`/`KoboldMeasureEnable`/`DescendPermit` inconditionnels en `SEARCHING_*` : contacteur alimenté indéfiniment si l'opérateur relâche la descente (timer gelé, pas de timeout). Anti-chauffe violé. | Gate sur `DescentActive` (mouvement + sens + mode + `NOT Palier5` + `NOT SeqError`) | `TC-P04-016` |
| **H2** | Latence 1 scan sur sorties `[ACT]` après défaut **détecté dans le `CASE`** (Palier5/SeqError ; `BucketError`/synchro). `instFault` tourne en §1 avant. | `DescendPermit`/`KoboldContactorCmd` et `BucketCloseRequest`/`AscentPermit` gardés sur `NOT <entrée défaut>` **même scan** | `TC-P04-025`, `TC-P04-016` |
| **H3** | REALs de config non bornés avant `REAL_TO_UDINT` → overflow possible du timeout de garde (`CQS §6`). | `LIMIT(plancher, val, plafond)` + `CST_*Max*` | couvert TC timeouts |
| **H4** | `StepAtFault` capturait l'étape **post-transition** pour un défaut CASE + une transition au même scan. D2 non satisfait. | Capture **au site du latch** dans le `CASE` + mutex `StepAtFaultCaptured` (effacé au seul Reset) | `TC-P04-012`, `TC-P04-025` |
| **H5** | `Mode : E_Mode` = `VAR_INPUT` **mort** dans les 2 FB (MISRA `CQS §4`). | Double garde : permis conditionnés à `Mode = MAINT_N1/N2` | tous les TC (Mode ajouté) |
| **C3** | `StepAtFault` remis à WAIT dans le gate `NOT Enable` → étape du défaut perdue sur cycle Enable. | Ne plus réinitialiser `StepAtFault`/`StepAtFaultCaptured` dans le gate (seul `Reset` les efface) | `TC-P04-015`, `TC-P04-024` |

### Findings écartés (vérifiés orchestrateur)
- « Non-redémarrage non garanti / `Fault.Latched` » : **déjà** couvert par `IF Fault.Error OR Fault.Latched THEN ERROR_HOLD` (commit `75ceba26`, prompt de revue antérieur). TC-P04-015/024 le prouvent (`DiveState`/`ExtractionState = ERROR_HOLD` au retour `Enable`).
- « Reset conditionné » : l'acquittement du latch `FB_FaultCore` reçoit `Reset` **brut** (`CQS §3bis`) ; seul le reset de la machine d'état est gardé (pattern projet `CQS §9`).
- « Câblage `BucketMoveTimeout` non prouvé » : `PRG_03` L131 = `GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration`, même source que `instBucket`.
- « `Mode` doit gater / certification ISO 13849 système » : hors scope FB (analyse de risque / PLr / architecture SRP/CS = niveau système).

**Résultat passe H1-H5** : `FB_DiveSearch` **8/8**, `FB_ExtractionSequence` **7/7**, `G200` PASS, `run_all_gates` PASS.

### 3ᵉ revue — `codex/gpt-5.6-sol-max` sur le code **durci** (2026-08-28)

> Rapport brut : `T167-CR_omniroute_FB_ExtractionSequence_v2.md` (DiveSearch : timeout serveur, non abouti).
> **Confirme H1-H5 landés** (« `BucketCloseRequest`/`AscentPermit` chutent le scan même », « captures `StepAtFault`
> au site », « calcul borné avant `REAL_TO_UDINT` », critère `StepAtFault` = PASS). **3 items restants → corrigés :**

| # | Constat | Correctif appliqué | Test |
|---|---|---|---|
| **F1** | `ForceMinSpeedStep := TRUE` inconditionnel en `CONTROL_ASCENT` → `[ACT]` actif sans permis positif. | `ForceMinSpeedStep := AscentPermit` (suit le permis) | `TC-P04-026` |
| **F2** | Garde de Reset ne vérifiait pas les entrées défaut **vives** (`BucketError`/`WinchSyncError`/`PositionsValid`/vitesses) → latch acquittable + `Ready:=TRUE` alors que la cause physique persiste. | Latches de cause physique (`BucketErrorFault`/`SyncOrSpeedErrorFault`) acquittés **seulement si** `CausesPhysiquesEffacees` ; latches timeout acquittables sur simple Reset ; DiveSearch : `NOT (CurrentSpeedStep > 4)` ajouté aux 2 gardes Reset. | `TC-P04-026` |
| **F3** | `BucketCloseTimerAcc += CycleTime` sans plafond : `CfgBucketCloseTimeout` `[CFG]` borné **seulement par le bas** → overflow possible de l'accumulateur `TIME` → backstop jamais déclenché. | `ErrorCausePresent` si `CfgBucketCloseTimeout > CST_BackstopMax` (`T#600s`). `ControlAscentTimerAcc` déjà borné (`LIMIT` sur la distance). | couvert par `ErrorCausePresent` |

**Résultat passe F1-F3** : `FB_DiveSearch` **8/8**, `FB_ExtractionSequence` **8/8** (`+TC-P04-026`), non-régression complète (`FB_Cycle` 7/7, `PRG_03` 5/5, `PRG_07` 3/3), `G200` PASS, `run_all_gates` PASS, `G340` doc-links PASS.

**Fin de la boucle de revue** : 2 rounds de findings réels traités (H1-H5 puis F1-F3), rendement décroissant.
Les rejets « ISO 13849 » résiduels des reviewers portent sur le **niveau système** (PLr, architecture SRP/CS,
MTTFd/DCavg/CCF, matériel, essais) — hors périmètre d'un FB séquenceur. Contrat logiciel du FB : **conforme**.

---

## 4. Items de durcissement résiduels (hors scope T167 — tâches dédiées)

| # | Brique | Constat | Décision |
|---|---|---|---|
| D1 | `FB_ExtractionSequence` | `WAIT_BOTTOM_CONFIRMATION → READY_TO_CLOSE` sur **niveau** de `BottomPositionConfirmed`, pas sur front frais. Après un Reset post-défaut avec capteur fond encore actif, la séquence peut reprendre sans nouvelle confirmation de pose au fond. | Nouvelle tâche : définir en spec (`AF-04`) la **sémantique de reprise** voulue (reprise d'ascension vs redémarrage depuis le fond), puis gate correspondant. Pré-existant baseline, aucune régression T167-C. |
| D2 | `FB_DiveSearch` | `SEARCHING_BOTTOM` : arrêt de descente par **timeout seul**, pas de garde de position basse directe dans le FB (limite légale appliquée en aval par `PRG_04.BottomLimitM`). | Durcissement optionnel : passer `LimitLegalDepthMin_M` en garde d'arrêt directe dans le FB. Faible priorité. |
