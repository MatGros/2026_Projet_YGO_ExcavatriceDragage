# 📦 RAPPORT T177 — Garde-vitesse réel (SpeedGuardEnable + MeasuredSpeedBand)

> Rapport d'orchestration transmissible à l'agent orchestrateur.
> Date : 2026-08-30 · Criticité C3 · Stratégie patch · Worktree isolé `.mgs-worktrees/T177` (branche `T177`, base main réalignée sur état live).

---

## 1. Verdict de revue (défi orchestrateur)

| Axe | Verdict | Preuve |
|---|---|---|
| Liaison structurelle | ✅ PASS | G200 : `FB_WinchLoadEstimator` désormais **instancié 2×** (M1/M2) — plus orphelin ; 0 erreur lot |
| Contrat FB / nommage | ✅ PASS | appels nommés, `MeasuredSpeedBand`/`SpeedGuardEnable` corrects |
| Encapsulation / producteur unique | ✅ PASS | var mortes `SpeedGuardEnableM1/M2` **supprimées** ; `TRUE` direct (producteur unique AF03) |
| Logique métier / sécurité | ✅ PASS (à valider en cycle) | garde actif réellement ; **changement comportemental** (bride `RequestedStep` à bande mesurée) — voir §6.3 |
| Gates (non-régression) | ⚠️ VERT sur lot | 4 gates FAIL **tous préexistants/hors scope** (détail §5) |

**Verdict global : PASS avec 3 réserves tracées (§6).** Lot respecte le périmètre réel (uniquement `PRG_04`), conforme AC1/AC3, et remplit le rôle de **prérequis consommé par T181-16**.

---

## 2. Contenu livré (diff réel, 1 fichier scopé, +28/−3)

### Volet A — SpeedGuardEnable réellement actif
```st
// Suppression des var mortes
-   SpeedGuardEnableM1 : BOOL := FALSE;
-   SpeedGuardEnableM2 : BOOL := FALSE;
// Câblage direct (M1 & M2)
-   SpeedGuardEnable        := SpeedGuardEnableM1,
+   SpeedGuardEnable        := TRUE,
```
- Les variables `:= FALSE` qui **écrasaient** le défaut sain `FB_Winch.st:47 := TRUE` sont **supprimées**.
- `SpeedGuardEnable := TRUE` en dur (pas de bypass SpeedGuard dans GVL_IHM → TRUE fixe).
- Le 1ᵉʳ étage du garde (stabilité `SpeedGuardReady`) ET le 2ᵉ (bande mesure) sont désormais **actifs** sur M1 et M2.

### Volet B — MeasuredSpeedBand alimenté par une vraie mesure
- `FB_WinchLoadEstimator` **instancié** : `instWinchLoadEstimatorM1/M2`, câblés sur `Speed_Mps`/`SignedSpeed_Mps` (mêmes sources que FB_Safety_Winch), `ActiveSpeedStep := StepNumber`.
- `MeasuredSpeedBand := instWinchLoadEstimatorX.SpeedBand` → **fini le `:= 0` codé en dur**.
- Appels placés **avant** `instWinchM1/M2` (SpeedBand prête même scan).
- Config : `_WinchSpeedConfig` + `_WinchLoadEstimateTable` (GVL_PERSISTENT, déjà présents).

**Preuve before/after G200** : `FB_WinchLoadEstimator` orphelin dans HEAD (0 instanciation) → instancié 2× et sorti du KO.

---

## 3. Gates
- Bundle frais 208/208, 0 erreur.
- G200 : seul KO = `FB_WinchSpeedLearning` (T181-15, **préexistant HEAD**, hors scope).
- Palier C : 4 FAIL **préexistants/hors scope** (G340 liens docs, G430 commentaires T181 préexistants, G481 crash runner baseline, G484 script absent). Aucun imputable au lot.

---

## 4. Réserve R1 — Conflit roadmap confirmé (à tracer)
La roadmap `PLAN_GEL`/D06/phase B place la **vraie** surveillance vitesse réelle (`REAL MeasuredSpeedMps` + table apprise, débrayable) dans **FB_Safety_Winch**, différée **T181-16** (qui dépend de T177). Ce lot active l'étage **bande INT** du garde `FB_Winch` (`FB_WinchLoadEstimator`/`_WinchSpeedConfig`). ⚠️ Il existe maintenant **deux vitesses** (bande FB_Winch vs future surveillance SAFETY) — **ne pas les confondre dans T181-16**.

## 5. Réserve R2 — D5 (bypass maintenance) non tranché
Le contrat **ne tranche pas**. Aucun bypass SpeedGuard dans GVL_IHM ; `BypassGlobal`/`BypassSafety` ne neutralisent pas le garde (il agit sur `RequestedStep` au-delà des `ErrorId`). Choix retenu : **TRUE fixe** (conforme décision utilisateur). Si la maintenance doit pouvoir neutraliser le garde → **décision expresse** requise (bypass gaté MAINT_N2 inexistant).

## 6. Réserve R3 — Changement comportemental à valider
Le garde **bride désormais `RequestedStep` à la bande mesurée** en fonctionnement nominal (ex. demande palier 4, bande mesurée 1 → clampé à 1). C'est l'objectif anti-survitesse/anti-dépassement (AC1, TASKS.yaml), mais constitue un **changement de comportement runtime** → à valider en essai réel (pas d'à-coup ni de blocage de cycle attendu).

## 7. Notes annexes
- `_WinchLoadEstimateTable.IsConfigured := FALSE` (table vide) → `EstimatedLoadPct` restera 0 tant que non calibré ; `SpeedBand` fonctionne indépendamment (§3 de l'estimateur). **Non bloquant**.
- `TOOLS/TEST_AUTO_CI/FB_TestHarness_PRG_04.st` référence encore `SpeedGuardEnableM1/M2` supprimées → **sera cassé** au prochain run harnais ; à re-synchroniser au lot tests (hors scope).

**Clôture : aucun commit effectué · diff prêt à validation orchestrateur + intégration CODESYS manuelle.**
