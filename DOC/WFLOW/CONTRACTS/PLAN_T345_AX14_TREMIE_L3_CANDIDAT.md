# 📌 T345 — AX14→AX15A « continuité trémie » : requalifiée **CANDIDAT L3 (BLOQUÉE)**

> 🚦 **Statut : `⏸️` BLOQUÉE — décision humaine requise.** Aucun `CODE/` touché, aucun test, aucun gate, aucun bundle, **aucun commit**.
> 🏷️ Acteur : **DSH15** (premier tag libre — `DSH14` = T347, vérifié `TASKS.yaml:7` **et** `TASK_LOCKS.json:109`).
> 📅 2026-09-21 · 🔢 **Révision figée** : `HEAD = 6cbb0a8d` **+ arbre de travail** (`CODE/G_CYCLE/FB_CycleSemiAuto.st` = **+7 lignes non commitées**, lot **T347/DSH14**).
> ⚖️ **Verdict : `PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` §10bis PRIME sur le brief T345.** Le brief était fondé sur une analyse incomplète (arbitrage gelé le même jour par une session concurrente, `DSH07` + challenger `DSH10`).

---

## 1 · Décision

| | |
|---|---|
| **Objet du brief** | Remplacer à **AT14** la garde `TranslationStopTimer.Q AND NOT JoystickDeflected` par un **maintien** `JoystickDeflected AND Translation_At_Tremie`, **timer retiré**. |
| **Décision** | 🛑 **Refusé en l'état.** T345 n'est pas un bug non corrigé : c'est le **lot L3** du plan T334, explicitement **`OPTIONNEL`** et **conditionné**. |
| **Nouvelle qualification** | `⏸️ T345 = candidat L3` — déblocable **uniquement** après L0 → L1 → L2 prouvés **et** décisions **D1 / D3 / D4 / D5**. |
| **Action immédiate** | **Zéro ligne de code.** T345 reste `⏸️` (bloquée sur décision humaine), **pas** `⏳` (en cours). |

---

## 2 · Les 4 écarts du brief (chacun prouvé `fichier:ligne`)

> 📐 **Convention de lignes** : toutes les références ci-dessous sont **l'arbre de travail** (disque, `Select-String`/`Get-Content`).
> Le brief cite la révision **`HEAD`** : `WT = HEAD + 6` pour les lignes antérieures à `L1580 (WT)`. Ex. `AT14` = **`WT:1460`** = `HEAD:1454`.

| # | Affirmation du brief | Verdict | Preuve |
|---|---|---|---|
| **E1** | « Aligner AT14 sur la spec gelée » | 🟢 **Vrai sur le fond** | `GEL_GRAFCET_SEMIAUTO_20260903.md:105` : `AT14` = `JoystickDeflected AND Translation_At_Tremie` → AX15A. Le code exige bien un **relâchement**. |
| **E2** | « Même bug que P1, resté non aligné » | 🟢 **Vrai** | `WT:1460` `IF TranslationStopTimer.Q AND NOT JoystickDeflected THEN` vs `WT:966` `IF TranslationStopTimer.Q AND DeadmanArmed AND JoystickPushOnly THEN`. |
| **E3** | « Le pattern de correction de P1 (discrimination d'axe) est **déjà appliqué** en AX15A→AX15B » | 🔴 **FAUX** | `WT:1484` `IF DeadmanArmed AND JoystickPush THEN`. `JoystickPushOnly` (`WT:783`, X **exclu**) n'est utilisé **qu'**en AX2 (`WT:960`, `WT:966`). → requalifié **T349** (§7). |
| **E4** | « Retirer `TranslationStopTimer.Q` ne réintroduit pas le risque de P1 » | 🔴 **Réfute la mauvaise objection** | Le risque arbitré n'est **pas** la confusion X/Y : c'est **H1** (§3). Et le pattern P1 **garde** le timer (`WT:966`) — voir §4. |

---

## 3 · Le diagnostic complet — mécanisme exact du risque H1

### 3.1 La demande M3 en cycle **dérive du permis joystick**

```st
// WT:781-783
TranslationP1Permit     := DeadmanArmed AND JoystickRight AND NOT JoystickPush AND NOT JoystickPull;
TranslationTremiePermit := DeadmanArmed AND JoystickLeft  AND NOT JoystickPush AND NOT JoystickPull;
JoystickPushOnly       := JoystickPush AND NOT (JoystickLeft OR JoystickRight);
```

```st
// WT:1451-1452  (AX14, chaque scan)
TranslationCmd.PositionTgt := 1;                        // Trémie
TranslationCmd.ReqStart    := TranslationTremiePermit;  // ← re-créée à CHAQUE scan
```

➡️ **Relâcher X est le seul geste qui retire réellement la demande M3 du séquenceur.** Le neutre n'est donc pas un confort opérateur : c'est la soupape qui empêche la demande d'être **recréée pendant un dropout capteur**.

### 3.2 Les **deux** conditions concurrentes (le cœur de l'argument)

```st
// WT:354-358
TranslationStopTimer(
    IN := (((State = E_AutoCycleStep.AX2_TRANSLATE_P1)  AND Translation_At_P1)
           OR ((State = E_AutoCycleStep.AX14_TRANSLATE_DUMP) AND Translation_At_Tremie))
          AND NOT Translation_Busy,
    PT := CST_TranslationStopConfirmTime);   // WT:261 = T#500ms
```

| Condition | Exigence | Durée |
|---|---|---|
| **A** — confirmation d'arrêt | `(AX14 ∧ At_Tremie ∧ ¬Translation_Busy)` **continus** | **500 ms** (`WT:261`) |
| **B** — ré-armement de la demande | `ReqStart := TranslationTremiePermit` dès que `At_Tremie` retombe (branche `ELSE` implicite, `WT:1452`) | **1 scan** |

➡️ **Sous capteur qui rebondit** : `At_Tremie` tombe → **B** recrée la demande **immédiatement** (le variateur repart) → `At_Tremie` remonte → le TON **A repart de zéro**. La transition ne peut **jamais** s'armer, et **le neutre était la seule sortie**. C'est le verdict `§10bis` **MAJOR**, confirmé sur le code par le porteur (`PLAN_T334_PHASE3:204`, `:142`).

### 3.3 Aggravant : `Translation_At_Tremie` n'est **pas** un capteur, c'est un **latch**

```st
// PRG_05_Translation.st:245 / :266 / :306
M3_AtTremieStable := GVL_PERSISTENT._TranslationAtTremiePersisted OR instPosDecoderM3.TranslationPosTremie;
```

➡️ Le correctif du brief armerait la transition au **premier scan vrai** du jeton, **sans** la confirmation d'arrêt physique de 500 ms. On entre dans AX15A avec une demande de translation **encore vivante** au scan de bascule — exactement la classe de faute frein de **T287** (`PRG_05:658` veto SEMI_AUTO au changement d'étape ; `PRG_06:431-432` coupure dure Trémie couplée à la demande).

---

## 4 · Pourquoi le correctif proposé est refusé

| # | Raison | Preuve |
|---|---|---|
| **R1** | La porte de transition AX2/AX14 est **gelée par arbitrage humain** | `PLAN_T334_PHASE3:6`, `:183`, `:204` |
| **R2** | Le neutre **n'est pas retiré** ; réévaluation **seulement en L3** | `PLAN_T334_PHASE3:183`, invariant **I4** (`:124`) |
| **R3** | L3 est **`OPTIONNEL`** et exige **L1+L2 prouvés + D4** | `PLAN_T334_PHASE3:138` |
| **R4** | Le correctif **casse la symétrie qu'il prétend restaurer** : le pattern P1 garde le timer | `dcb28019` (diff `FB_CycleSemiAuto.st`) : seule la **garde de geste** a changé ; `WT:966` conserve `TranslationStopTimer.Q` |
| **R5** | Le lot identique est **déjà arrêté** sous ce nom | `TASKS_ORCHESTRATOR.yaml:2302` (« transition sous geste maintenu, **sans neutre requis** ») → `:2306` « implementation STOPPEE, lot abandonne » |
| **R6** | Le plan recommande même d'**abandonner** l'uniformisation | `PLAN_T334_PHASE3:196` — décision **D4** : « 🟢 **abandonner** … documenter pour l'opérateur » |

---

## 5 · Ce que le brief §5 demandait de vérifier — réponses prouvées

| Question du brief | Réponse | Preuve physique |
|---|---|---|
| `TranslationStopTimer` est-elle « morte » localement ? | ❌ **NON — ne jamais la retirer** | `WT:238` (décl.) · `WT:354-358` (TON) · `WT:961` + `WT:966` (**AX2**, `WaitingForProcess`/porte) |
| Des transitions dépendent-elles de `WaitingForOperator`/`WaitingForProcess` ailleurs ? | ❌ **AUCUNE** — statut publié uniquement, jamais relu par une transition | `FB_CycleSemiAuto.st` : **22 sites** d'affectation, **0 lecture** conditionnelle · `PRG_03_Modes_Cycle.st:353-354` → `PRG_07_Supervision.st:888-889` → `FB_TroubleshootingView.st:694-695` (`Idx209`/`Idx210`) |
| Le scénario « joystick maintenu de AX2 à la trémie » est-il sans saccade ? | ⚠️ **Non déterminable statiquement** — c'est précisément l'objet du **run de trace 10 ms** (L0, **T348**) | `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md:14-25` : aucune des 3 expériences n'existe au dépôt ; les traces M3 existantes sont à **dt médian 100 ms** ⇒ structurellement aveugles à l'échelle 1-10 scans |
| `Translation_At_Tremie` est-il un capteur vif ? | ❌ **Latch** | `PRG_05_Translation.st:245`, `:266`, `:306` |
| AX15A force-t-elle bien les commandes à 0 ? | ✅ **Oui, chaque scan** — la trouvaille E3 est donc **incohérence d'affichage**, pas risque de mouvement | `WT:1477-1481` (treuils + translation à 0) ; `WT:1484` (porte) |

---

## 6 · Conditions de déblocage (chaîne imposée par la preuve)

```text
L0  run de trace 10 ms (HUM)  ──▶ T348   [préalable de D3 et de L1]
      ↓
D1  GO humain (bypass MAINT_N2)        ┐
      ↓                                │ décisions humaines
L1  l'AXE possède son arrêt            ┘ (aucune n'est donnée à ce jour)
      ↓
D3  Q7 : coupure dure Trémie           ── à trancher SUR TRACE (L0)
      ↓
L2  la demande survit à l'arrêt  ── exige L1 prouvé + verrou T331 libéré + D5
      ↓
L3  sort du neutre  ──▶ T345   exige L1+L2 prouvés + D4
```

| Jalon | Nature | État prouvé |
|---|---|---|
| **L0 / T348** | Run de trace **humain** (CODESYS) — hors périmètre agent | ⬜ à faire (Mathieu) |
| **D1** | GO humain pour ouvrir L1 | ❌ jamais donné |
| **L1** | Code `FB_Translation.st` + `PRG_05_Translation.st` | ⬜ bloqué par D1 |
| **D3** | Q7 — accepter/découpler la coupure dure Trémie | 🔴 ouvert, « à trancher sur trace » |
| **D5** | Séquencement : écrire `FB_CycleSemiAuto.st` **après libération du verrou T331** | ❌ non libéré |
| **D4** | Abandonner ou différer l'uniformisation | 🟡 recommandation = **abandonner** |
| **Q3 / I2** | Le demandeur conserve demande + cible jusqu'à `ArrivalLock` **et** arrêt confirmé | ⬜ dépend de L1 |

---

## 7 · Critères d'acceptation proposés **pour le futur lot L3** (si D4 le rouvre un jour)

> Ces critères ne sont **pas** exécutables aujourd'hui. Ils sont écrits maintenant pour que le lot L3, s'il est rouvert, ne puisse pas être livré sur une simple lecture statique.

| ID | Énoncé (ce que la **machine** fait) | Preuve |
|---|---|---|
| **AC-T345-1** | Avec geste X maintenu de AX14 jusqu'à l'arrivée trémie, **aucun** front montant de `M3_CommandWord` ni de `M3_SetpointFrequencyHz` n'apparaît pendant la fenêtre de confirmation d'arrêt. | Trace 10 ms, scénario B (intermittence capteur ≈ 1 s) + scénario A |
| **AC-T345-2** | Le mot de commande reste **non nul** pendant toute la décélération d'arrivée : aucun passage à 0 avant confirmation `ABS(fAct) ≤ 0,5 Hz`. | Trace 10 ms, colonnes `M3_CommandWord`, `M3_SetpointFrequencyHz`, `M3_ActualFrequencyHz` |
| **AC-T345-3** | La transition AX14→AX15A ne s'arme que sur un **fait d'arrêt confirmé publié par l'axe**, jamais sur le seul jeton `M3_AtTremieStable` (latch RETAIN). | Test CI `G_CYCLE` avec `Translation_At_Tremie` injecté à TRUE sans fait d'arrêt : la transition **ne doit pas** se produire |
| **AC-T345-4** | La transition **n'exige aucun retour au neutre** : le geste X maintenu suffit, et la continuation AX15A→AX15B se fait sous le **même** geste Y sans temps mort. | Test CI neuf, rouge avant / vert après ; assertion sur `State` sur scans consécutifs |
| **AC-T345-5** | L'attente d'arrivée est **bornée** : timeout ⇒ repli `AX_STAB` + défaut latché. Aucun maintien indéfini. | Test CI (leçon **A14** : le modèle AX3 porte lui-même un timeout **désarmé**, `PLAN_T334_PHASE3:173`) |
| **AC-T345-6** | Après bascule, les commandes benne **et** treuils sont à zéro au **même scan** (aucun recouvrement de demande). | Test CI sur `BucketCmd.ReqOpen`, `WinchM1Cmd`, `WinchM2Cmd` au scan de transition |
| **AC-T345-7** | Le message opérateur affiché en AX14 correspond au geste réellement exigé par la porte. | Relecture de `OperatorAction` (`WT:1459`) contre l'expression de la porte (`WT:1460`) |

---

## 8 · Trouvaille annexe → **T349** (bug réel, mineur : affichage seul)

L'incohérence d'affichage dénoncée en **E3**, requalifiée en tâche tracée :

| | |
|---|---|
| **Fait** | `WT:1472-1473` : `WaitingForOperator := NOT JoystickDeflected;` / `WaitingForProcess := JoystickDeflected;` → **geste générique** (n'importe quelle direction) |
| **Réalité de la porte** | `WT:1484` : `IF DeadmanArmed AND JoystickPush THEN` → **axe Y** (homme-mort inclus) |
| **Conséquence** | 🔵 **Affichage opérateur uniquement.** Aucune commande n'est mal gatée : AX15A force treuils **et** translation à 0 (`WT:1477-1481`) et AX15B les force à 0 également (`WT:1505-1506`). |
| **Nuance honnête** | La porte utilise `JoystickPush` (Y-, `WT:19`), **pas** `JoystickPushOnly` (Y- **X exclu**, `WT:783`) : une diagonale X+Y satisfait donc la porte. Bénin **ici** (aucun mouvement commandé), mais l'écart de vocabulaire est réel et doit être tranché, pas contourné. |
| **Tâche** | **T349** — contrat `TASK_CONTRACT_T349_AX15A_AFFICHAGE_GESTE.yaml` |

---

## 9 · Journal de vérification

- **Méthode** : toutes les références `fichier:ligne` ont été relues **physiquement sur disque** (`Select-String` / `Get-Content`), jamais recopiées d'une analyse antérieure. Aucun `Device.export` lu.
- **Incident de lecture signalé** (⚠️ à connaître pour la suite) : deux outils de lecture m'ont rendu le contenu **`HEAD`** alors que le disque portait **+7 lignes** non commitées de **T347/DSH14** (fichier écrit à `00:17:45`, `TASKS.yaml`/`TASK_LOCKS.json` réécrits à `00:28`). **Toutes** les références de ce document sont donc issues de la lecture physique, et la conversion `WT = HEAD + 6` est fournie §2. **La leçon générale : sur ce dépôt, ne jamais citer une ligne sans `Select-String`.**
- **Collision signalée** : `CODE/G_CYCLE/FB_CycleSemiAuto.st` est au **périmètre de T347/DSH14** (verrou `TASK_LOCKS.json:108-111`, pris `00:18`), zone `AX14` ≠ zone `T347` (DSH14 a lui-même vérifié les zones disjointes, `TASKS.yaml:53-56`). Ce document **ne modifie aucun fichier `CODE/`**.
- **Dépôt non propre, hors périmètre de ce lot, signalé et laissé en place** : `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleState.st`, `ST_SequencePublicState.st`, `CODE/M_MAIN/PRG_03_Modes_Cycle.st`, `PRG_07_Supervision.st` (T347) ; suppression **non commitée** de `TOOLS/AGENT_WORKFLOW/scripts/G499_check_t291b_top_authority.py` (probable renommage G499→G505 de T291-B, **à confirmer par l'humain — non touché**).
- **Aucun** : code écrit · test lancé · gate lancé · bundle généré · commit · push.

### Fichiers produits par ce lot (hors-code)

| Fichier | Rôle |
|---|---|
| `DOC/WFLOW/CONTRACTS/PLAN_T345_AX14_TREMIE_L3_CANDIDAT.md` | ce document |
| `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T348_TRACE_M3_10MS_L0.yaml` | contrat du préalable **L0** (run de trace humain) |
| `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T349_AX15A_AFFICHAGE_GESTE.yaml` | contrat de la trouvaille d'affichage AX15A |
| `DOC/WFLOW/TASKS.yaml` | entrées **T345** (`⏸️`), **T348** (`⬜`), **T349** (`⬜`) |
| `DOC/WFLOW/TASK_LOCKS.json` | 🔒 **T345 / DSH15** |
