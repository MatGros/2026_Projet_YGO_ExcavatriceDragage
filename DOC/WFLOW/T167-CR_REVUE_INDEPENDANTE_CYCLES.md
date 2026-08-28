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

## 4. Items de durcissement identifiés (hors scope T167 — tâches dédiées)

| # | Brique | Constat | Décision |
|---|---|---|---|
| D1 | `FB_ExtractionSequence` | `WAIT_BOTTOM_CONFIRMATION → READY_TO_CLOSE` sur **niveau** de `BottomPositionConfirmed`, pas sur front frais. Après un Reset post-défaut avec capteur fond encore actif, la séquence peut reprendre sans nouvelle confirmation de pose au fond. | Nouvelle tâche : définir en spec (`AF-04`) la **sémantique de reprise** voulue (reprise d'ascension vs redémarrage depuis le fond), puis gate correspondant. Pré-existant baseline, aucune régression T167-C. |
| D2 | `FB_DiveSearch` | `SEARCHING_BOTTOM` : arrêt de descente par **timeout seul**, pas de garde de position basse directe dans le FB (limite légale appliquée en aval par `PRG_04.BottomLimitM`). | Durcissement optionnel : passer `LimitLegalDepthMin_M` en garde d'arrêt directe dans le FB. Faible priorité. |
