# CONSIGNE D'EXÉCUTION — T181-00b : calibration des 32 vecteurs WINCH_INTEG

**Pour : Codex Terra.** À coller tel quel. Aucune écriture `CODE/`. Aucun commit — l'orchestrateur relit le `git diff`.

---

## 1 · Contexte

Le harnais d'intégration treuil `WINCH_INTEG` est **livré et compile** (`FB_TestHarness_PRG_04.st` miroir de `PRG_04`, `FB_Main_EndToEnd.st` v2 + modèle physique, 32 vecteurs `HARN-1x..8x`). Gates `G480` (miroir) et `G481` (compile+exécute) **PASS**.

**Problème** : les séquences de stimulus des vecteurs ne montent pas le treuil au palier cible dans les cas nominaux — `M1_StepNumber` reste à 0 ou 1 là où le test attend 3-5. Résultat : 7/32, mais la plupart des échecs sont des **préconditions non établies** (le treuil ne bouge pas), pas de vrais écarts. Symétriquement, 3 vecteurs `ROUGE baseline` (`HARN-31`, `HARN-51`, `HARN-74b`) **passent VERT par trivialité** (assertion `StepNumber <= 4` satisfaite parce que `StepNumber` = 0).

Cause identifiée (à confirmer) :
1. **Homme-mort non armé** : plusieurs vecteurs SEMI_AUTO ne mettent jamais `JoyDeadmanBtn := TRUE` + `ADVANCE_TIME(150ms)` + re-call → `BusAcq.JoystickDeadmanArmed` reste FALSE → `CycleMotionPermit` bloque le mouvement.
2. **Temps de rampe insuffisant** : après avoir posé la demande, le test fait 1-2 `machine()` + un seul `ADVANCE_TIME` court → le `BusinessStepDelay` de `FB_Winch` (~0,5-1,25 s/cran) n'a pas le temps de monter 0→3.

## 2 · Contrat

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-00_HARNESS_INTEG.yaml` — AC5 (« 6 familles exécutables ») et AC6 (vecteurs sécurité). Cette tâche **calibre** ce qui a été livré.

## 3 · Documents de référence

| # | Doc | Pour |
|---|---|---|
| 1 | `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_winch_integ.st` | **le fichier à calibrer** (32 vecteurs) |
| 2 | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_Main_EndToEnd.st` | le mégabloc v2 (entrées disponibles, modèle physique, sorties diag) |
| 3 | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_04.st` | le stub miroir (agrégateur clamp, `SEL` M1/M2, permits) |
| 4 | `DOC/WFLOW/AUDITS/DESIGN/SPEC_HARNESS_INTEG_TREUIL_T181-00_v0.1.md` §3 | **table des attendus par vecteur** (Direction, SpeedPct, palier attendu) |
| 5 | `DOC/WFLOW/AUDITS/DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` §3quater | **clamp par contexte** (couplé / M1 / M2 / benne-jog / benne-cycle) + exception ralentissement (`SlowdownMaxStep` ≠ 1) |
| 6 | `CODE/M_MAIN/PRG_02_Acquisition.st` (chaîne homme-mort), `CODE/M_MAIN/PRG_03_Modes_Cycle.st` (`CycleMotionPermit`, `DeadmanArmed`) | pour la séquence d'armement |
| 7 | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/tests/test_main_end_to_end.st` | modèle d'armement homme-mort qui MARCHE déjà (2 scénarios verts) |

## 4 · Objectif mesurable

1. **Bloc d'armement réutilisable** en tête de chaque vecteur qui pilote un mouvement :
   `JoyDeadmanBtn := TRUE` → `machine(...)` → `ADVANCE_TIME(150000000)` → `machine(...)` (confirmation) — jusqu'à `machine.BusAcq.JoystickDeadmanArmed = TRUE`. (Copier le pattern de `test_main_end_to_end.st:9-40`.)
2. **Boucle de convergence** après la pose de la demande : ~10 à 15 itérations `machine(...)` + `ADVANCE_TIME(300000000)` (300 ms) pour laisser `FB_Winch` monter le palier jusqu'à la cible, AVANT d'asserter.
3. **Attendus recalés sur la table SPEC §3** : `HARN-10` = palier 3 pour 50 % ; `HARN-13a/b/c` = 2/3/5 ; `HARN-20` = 4 pour 75 % ; etc. Prendre en compte `SlowdownMaxStep` configurable (**pas 1**) pour les vecteurs d'approche FDC (`HARN-12`).
4. **Vecteurs `ROUGE baseline` rendus non triviaux** : `HARN-31` (palier 5 interdit Kobold) doit d'abord établir « le treuil EST au palier 5 en Kobold » puis asserter « plafonné à 4 » — donc rouge tant que T181-12 n'a pas livré, pas vert par trivialité. Idem `HARN-51` (injection), `HARN-33`, `HARN-74b`, `HARN-75`, `HARN-81`.
5. **Marqueur `SUITE_CALIBREE`** ajouté en commentaire de tête du `.st` UNE FOIS que : (a) toutes les familles nominales `HARN-1x..6x` établissent leur précondition (le treuil bouge), (b) aucun `ROUGE baseline` ne passe vert par trivialité. À ce moment `G481` bascule le leak de WARN → FAIL.
6. **Baseline figée** : le nouveau score `X/32` est reporté dans `PLAN_DE_TIR_T181_v0.1.md` §5 comme référence.

## 5 · Restitution

- `git diff` de `test_winch_integ.st` (+ `PLAN_DE_TIR` §5 si mis à jour).
- Sortie de `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb WINCH_INTEG` (résumé par vecteur).
- Sortie de `python TOOLS/AGENT_WORKFLOW/scripts/G481_check_winch_integ.py`.
- Liste des vecteurs restés rouges + pourquoi (doit être : uniquement les `CIBLE T181-xx`, pas des préconditions cassées).
- **Aucun commit.**
