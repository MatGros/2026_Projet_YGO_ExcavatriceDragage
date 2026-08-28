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

## 2. FB_ExtractionSequence — revue Ollama indisponible

Le serveur `deepseek-v4-flash:cloud` a **timeout 3 fois** (2026-08-28) — revue indépendante formelle
**non aboutie**, à rejouer.

**Revue orchestrateur substituée** :
- Revue deepseek en phase dev : PASS avec 3 réserves → **toutes traitées** (contrôle runtime
  ordre des watchdogs via `BucketMoveTimeout`, garde `CycleTime<=T#0ms`, `StepAtFault` reset conditionné).
- L'écart MAJEUR #1 de la revue DiveSearch a la **même prémisse** ici (même socle `FB_FaultCore`
  + latches internes `TimeoutBucketCloseFault`/`TimeoutControlAscentFault` non effacés au gate) →
  **même conclusion** (faux positif) + **même garde-fou appliqué** :
  `IF Fault.Error OR Fault.Latched THEN ExtractionState := ERROR_HOLD`.
- **Preuve** : `TC-P04-024` étendu — Enable OFF→ON sans Reset : `Fault.Latched=TRUE`,
  `ExtractionState=ERROR_HOLD`, `AscentPermit=FALSE`. ✅

**Décision : CERTIFIÉ SOUS RÉSERVE** — rejouer la revue Ollama indépendante quand le serveur
répond, avant clôture T170.

---

## 3. Bilan mécanique (les 2 briques, état committé)

| Contrôle | Résultat |
|---|---|
| `FB_DiveSearch` STruCpp | **7/7 PASS** |
| `FB_ExtractionSequence` STruCpp | **6/6 PASS** |
| Non-régression | FB_Cycle 7/7, PRG_03 5/5, PRG_07 3/3 |
| `G200_check_linkage` | PASS (0 erreur) |
| `run_all_gates --palier C` | **16/16 PASS** |
