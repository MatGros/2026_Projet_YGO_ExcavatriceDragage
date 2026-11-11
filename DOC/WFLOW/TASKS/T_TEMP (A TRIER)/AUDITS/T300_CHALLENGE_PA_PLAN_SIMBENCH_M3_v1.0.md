# CHALLENGE T300 P-A — Revue read-only du cadrage « banc SimBench M3 capable de reproduire le terrain »

> **Rôle** : reviewer / challenger **read-only** (pas de verrou T300 — non requis pour ce rôle).
> **Auteur** : `DSH03` (porteur T328). **Destinataire** : `CDX01` (détenteur du verrou T300), orchestrateur `CC01`.
> **Date** : 2026-09-20. **Statut** : base de plan validée par l'orchestrateur — les 4 challenges partent tels quels.
> ⛔ **Ce document n'est pas une édition du plan T300.** Aucun fichier `CODE/`, aucun test, aucun contrat T300 modifié par son auteur.

---

## 1. Portée et règles d'engagement du rôle

| Point | Règle |
|---|---|
| Verrou T300 | **`CDX01`** (`TASK_LOCKS.json:8-12`). Le reviewer n'en prend pas. |
| Écriture | Aucune dans `CODE/`, les tests, les contrats/plans T300. Ce fichier est le **seul** artefact. |
| Objet | Challenger le **cadrage** avant écriture (étape 2) ; relire le **diff** après livraison (étape 5). |
| Sortie | Verdict `BLOCK` / `MAJOR` / `MINOR` / `PASS` avec `fichier:ligne` et preuve. |
| Règle d'or | Le reviewer ne recopie jamais une affirmation : toute conclusion est revérifiée sur le code réel. |

**Vérifications déjà réalisées par l'orchestrateur** : seuil `0,5 Hz` exact ✅ · périmètre `FB_SimBench` manquant confirmé ✅ · `G502` confirmé ✅. Les 4 challenges sont **validés comme base** du plan CDX01.

---

## 2. Challenge 1 — C4 : **ne pas retirer la garde 0,5 Hz** (elle est corroborée par la trace)

`FB_Sim_TranslationBrake.st:48` : `ELSIF ActualFrequency_Hz <= CST_StopFrequency_Hz` (seuil `:24` = `0.5`).

| t trace | `fAct` | `BrakeIsOpen_DI` | Lecture |
|---:|---:|---|---|
| 16,04 | **0,60 Hz** | 1 (ouvert) | > 0,5 Hz ⇒ reste ouvert ✔ |
| 16,16 | **0,00 Hz** | 0 (fermé) | ≤ 0,5 Hz ⇒ ferme ✔ |

**Seuil admissible déduit de la mesure : `∈ ]0,00 ; 0,60] Hz`. `0,5` est dedans.**
⇒ Le cas **nominal** est validé par le terrain. Le défaut 26,437 (`State.ErrorId=64`, frein fermé à 10,00 Hz) est une **branche de faute**, pas un comportement nominal.
⇒ **Correctif retenu : entrée de faute explicite** (type `FaultBrakeCloseWhileRunning` + délai), défaut `FALSE`. La garde nominale est **conservée intacte**.

**Conséquence sur le cadrage** : `TC-T300-BRK-020` (*« frein reste ouvert tant que vitesse non nulle »*, `test_fb_sim_translation_brake.st:23`) **ne doit PAS être révisé** — c'est un oracle validé par la mesure. Il doit être **complété** par `BRK-040` (branche de faute), pas remplacé.

---

## 3. Challenge 2 — C3 : oubli, pas choix voulu (correctif contraint par un test existant)

`FB_Sim_Translation.st:164` : `VelocityTarget_Mps := DirectionSign * …`, avec `DirectionSign` **recalculé à 0** chaque scan (`:134-139`). Retrait de commande ⇒ vitesse écrasée via τ = 0,15 s pendant que `fAct` met 2 s à ramper.

- Aucune source de conception ne documente ce choix (`INTERFACES_T300_SIMBENCH_M3.md:52` ne traite que de `HOLD` en désactivation) ⇒ **oubli**.
- ⚠️ **Contrainte** : `TC-T300-MEC-030` (`test_fb_sim_translation.st:149-168`) impose une **neutralité totale** sur commandes contradictoires (`ReqTremie AND ReqMaintenance`).
- ⇒ Sens **mémorisé** (*latch*) du dernier sens valide, remis à zéro **uniquement à l'arrêt** (`fAct ≤ 0,5 Hz`), **jamais latché** sur contradiction. Aucun nouveau paramètre. Aligne aussi le modèle sur `Q04`.

---

## 4. Challenge 3 — C5 : auto-correction assumée du diagnostic d'audit + décision de review à révoquer

Mon audit §2 concluait « réaction de charge inerte ⇒ recul impossible ». **Précision** (je me corrige, je ne me recopie pas) :

- `FB_Sim_SuspendedLoad.st:47` publie `ReactionGain_Mps2 × Angle_Rad × CycleTime_S` = `0,20 × 0,6 × 0,1` = **0,012 m/s par pas de 100 ms** ⇒ accélération effective **0,12 m/s²**.
- Face à `VelocityTarget` ≈ 3,75 m/s ⇒ **0,3 %** : inerte ✔ (constat d'audit valide).
- **Mais entraînement coupé**, 0,12 m/s² franchit la bande capteur `0,05 + 0,02 = 0,07 m` en `√(2×0,07/0,12) = 1,08 s`.
- ⇒ **Le vrai bloquant de C5 n'est pas le gain, c'est le clamp de butée** `FB_Sim_Translation.st:175-178` (`PositionTrue_M := CST_PositionAtTremie` + `VelocityTrue_Mps := 0.0`), qui **annule la réaction à chaque pas**.
- ⚠️ Ce clamp est un **choix tracé** : `AUDIT_T300_TC_CI.md:94` — *« Le contact rigide bloque maintenant position et vitesse translation »*, après correction d'un défaut de micro-vitesse post-butée.
- ⇒ **Corriger C5 = révoquer une décision de review antérieure** ⇒ justification tracée obligatoire, bornage explicite du recul (`EndStopRecoilMax_M`), pas un patch silencieux.
- Marge physique **faible** : demi-période pendulaire `2π√(1,5/9,81)/2 = 1,23 s` vs 1,08 s nécessaires ⇒ `LoadReactionGain_Mps2` (aujourd'hui 0,20 en dur, SYNTHETIQUE) **doit devenir paramétrable**.

---

## 5. Challenge 4 — Bloqueurs de périmètre (B1/B2/B3)

| # | Constat | Preuve | Impact |
|---|---|---|---|
| **B1** | `CODE/L_SIMULATION/FB_SimBench.st` **absent** du périmètre autorisé, alors qu'il est le **seul** point de câblage des nouveaux paramètres | `FB_SimBench.st:547-561` instancie `instSimTranslation(...)` et lui passe les 7 paramètres `SimM3Sensor*` lus dans `GVL_Simulation.st:39-45` ; `instSimTranslation` est un `VAR` **privé** ⇒ non pilotable depuis un test | AC1/AC4 (scénario **explicite**) et AC6 (fronts observés dans `instPosDecoderM3`) **exigent** de toucher `FB_SimBench.st` |
| **B2** | `FB_SimBench.st` **et** `GVL_Simulation.st` étaient verrouillés `DSH03`/T328 | `TASK_LOCKS.json:36` (raison T328) | **TRANCHÉ par CC01 2026-09-20** : DSH03 n'écrit **pas** dans ces 2 fichiers tant que T300 n'a pas livré plan + diff |
| **B3** | `G502` est **fragile** face aux nouveaux paramètres | `G502_check_simbench_m3_boundary.py:108` exige `simbench.count("Translation.M3_PosTremie_DI") == 2` ; `:90-97` interdit `GVL_Simulation.SimM3` dans `PRG_05_Translation.st`, `FB_Translation_PositionDecoder.st`, `FB_Safety_Translation.st` | toute 3ᵉ publication légitime de DI, ou toute lecture de param sim dans PRG_05/décodeur, fera **FAIL AC6**. À intégrer **avant** de coder |
| **B4** *(nouveau, constaté le 2026-09-20)* | **`TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_simbench.st` est revendiqué par DEUX lots** : T328 (raison du verrou, `TASK_LOCKS.json:36`) et T300-P-A (périmètre autorisé `RESULTS/L_SIMULATION/tests/*.st`) | idem | collision d'un seul écrivain ⇒ à arbitrer par CC01 avant tout test T300-PA dans ce fichier |

---

## 6. Plan minimal proposé (base de discussion — **rien écrit**)

| Cas | Mécanisme | Paramètre | TC cible |
|---|---|---|---|
| C3 | sens **mémorisé** tant que `fAct > 0,5 Hz` ; RAZ à l'arrêt ; jamais latché si contradiction | aucun nouveau | `TC-T300-DRV-070` (nouveau) + non-régression `MEC-030` |
| C4 | entrée de **faute explicite** ; garde 0,5 Hz **conservée** | `FaultBrakeCloseWhileRunning`, `FaultBrakeCloseDelay_S` (défaut `FALSE`) | `TC-T300-BRK-040` (nouveau) — **`BRK-020` inchangé** |
| C5 | la butée absorbe l'**inertie**, pas la **réaction de charge** ; recul borné | `EndStopRecoilMax_M`, `LoadReactionGain_Mps2` (SYNTHETIQUE) | `TC-T300-SEN-052` (nouveau) |
| C1/C2 | **2ᵉ profil** nommé « blip court » à **nombre de transitions cible** (1–2), indépendant du train de bascules ~1 s | `BlipDurationS`, `BlipTransitions` | `TC-T300-SEN-050/051` (nouveaux) ; `SEN-030/031/040` intacts |

---

## 7. Protocole de revue du diff (étape 5) — checklist engagée

Sera appliquée **après** livraison par `CDX01`, sur le `git diff` réel (jamais sur un résumé d'agent) :

| # | Vérification | Critère |
|---|---|---|
| R1 | Garde nominale frein intacte | `FB_Sim_TranslationBrake.st:24/48` inchangés ; `BRK-020` non révisé |
| R2 | Faute = **opt-in** | défaut `FALSE` ⇒ comportement bit-à-bit identique hors scénario |
| R3 | Pas de latch de sens sur contradiction | `MEC-030` toujours PASS |
| R4 | Clamp de butée : justification tracée de la révocation | référence explicite à `AUDIT_T300_TC_CI.md:94` |
| R5 | Aucun paramètre SYNTHETIQUE présenté comme mesuré | marquage explicite (`PLAN…:154`) |
| R6 | `FB_SimBench.st` touché → diff **conforme à l'extension de périmètre** accordée | + B4 tranché |
| R7 | `G502` PASS **sans** modification du garde | toute modification de `G502` = `BLOCK` (décision orchestrateur) |
| R8 | Traçabilité d'impact bout-en-bout | sortie finale → SimBench → HwSim → HwIn → décodeur ; consommateur final nommé |
| R9 | `AC1`→`AC8` du cadrage P-A repris un par un | verdict par AC, sans AC non instruite |

---

## 8. Journal d'arbitrage

| Date | Décision | Source |
|---|---|---|
| 2026-09-20 | T300 reste `CDX01` ; `DSH03` = reviewer/challenger read-only, **sans verrou** | CC01 |
| 2026-09-20 | Identités **non fusionnées** : `DSH03` (T328) ≠ rôle reviewer T300 | CC01 |
| 2026-09-20 | **B2 tranché** : `DSH03` n'écrit pas dans `FB_SimBench.st` / `GVL_Simulation.st` tant que T300 n'a pas livré plan + diff | CC01 |
| 2026-09-20 | Les 4 challenges validés et transmis à `CDX01` comme base de plan | CC01 |
| 2026-09-20 | **B4 ouvert** : `test_fb_simbench.st` revendiqué par T328 *et* T300-P-A | constat reviewer |
