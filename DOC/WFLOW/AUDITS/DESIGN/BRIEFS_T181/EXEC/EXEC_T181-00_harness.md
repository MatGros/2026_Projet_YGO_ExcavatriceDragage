# CONSIGNE D'EXÉCUTION — T181-00 : Harnais d'intégration treuil

**Pour : Codex Terra (ou équivalent code).** À coller tel quel. Aucun commit — l'orchestrateur valide le `git diff`.

---

## 1 · Rôle & règles

- Tu es Expert Senior Automatisme CODESYS 3.5 + test/CI industriel. FR, concis.
- Lis **d'abord** : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (guardrails projet, cas d'arrêt, devoir d'alerte).
- **Aucune écriture dans `CODE/`.** Cette tâche ne touche QUE l'outillage de test et la doc de tir.
- Tout blocage / incohérence → **remonter immédiatement** à l'orchestrateur, ne pas contourner.
- Machine de sécurité réelle : un test vert sur du code non représentatif est pire que pas de test (REX `PRG_10_Outputs_LD`).

## 2 · Contrat (ta seule référence de succès)

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-00_HARNESS_INTEG.yaml` — **AC1 à AC9**. Ta restitution se juge contre eux, pas contre « j'ai bien travaillé ».

## 3 · Documents de référence (lire dans cet ordre)

| # | Document | Pour |
|---|---|---|
| 1 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md` §7-§9 + §13 | phasage, plan de tir, corrections B2 |
| 2 | `DOC/WFLOW/AUDITS/DESIGN/SPEC_HARNESS_INTEG_TREUIL_T181-00_v0.1.md` | **catalogue des vecteurs HARN-1x..8x, oracles, montage** — ta spec de contenu |
| 3 | `DOC/WFLOW/AUDITS/DESIGN/BRIEFS_T181/RESULTS/B4_review_independante.md` §1 (B3) + §3.1 | **pourquoi le harnais actuel est un stub à reconstruire** |
| 4 | `DOC/WFLOW/AUDITS/DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` §6 | reconstruction du stub + gate d'égalité + oracle table-à-la-main |
| 5 | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (intégral) | **le modèle à mirroir** : §1-§8, agrégateur clamp, SEL M1/M2, permits §5 |
| 6 | `CODE/M_MAIN/PRG_03_Modes_Cycle.st`, `PRG_06_Outputs.st` | amont / aval de la chaîne |
| 7 | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_Main_EndToEnd.st` + `FB_TestHarness_PRG_04.st` + `registry.yaml` + `README.md` + `config.yaml` | l'existant (mégabloc, stub simplifié 196 l., primitives `ASSERT_*` / `ADVANCE_TIME`) |
| 8 | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/tests/test_prg_04_treuils_benne.st` + `test_main_end_to_end.st` | format des suites `.st` |

## 4 · Objectif mesurable (résumé — le détail est dans le contrat)

1. **Reconstruire `FB_TestHarness_PRG_04.st`** en miroir fidèle de `PRG_04 §1-§8` : `instWinchM2` / `instWinchSync` / `instBucket` **réellement appelés** ; vrai agrégateur de clamp (commun + M2-propre) ; vrais `SEL` M1/M2 ; vraie taxonomie de permits §5. **Zéro valeur métier en dur** (`grep 'MaxStep.*:= 5'` = 0, `grep 'TopLimit.*:= 7.5'` = 0).
2. **Gate d'égalité** stub ↔ `PRG_04` : un script à créer (nom suggéré `G4xx_check_harness_mirrors_prg04.py`) dans le dossier `TOOLS/AGENT_WORKFLOW/scripts/` — échoue si les expressions clés de §3/§6 divergent. (Ou : générer le stub depuis `PRG_04` et gater la régénération.)
3. **Étendre `FB_Main_EndToEnd`** : entrées boutons IHM M1/M2, commande benne, contexte plongée Kobold, `InjectRateBypassFbWinch` ; sorties diag `StepNumber` M1/M2, position modèle M1/M2, `SyncDeviationM`, `FinalInterlockGoverned` M1/M2.
4. **Modèle physique minimal** : `CablePosM += v_palier(StepNumber, Direction) * 0.010` par instance ; `ecart = |M1.pos - M2.pos|` ; `ContactorsAllOff` retardé de `ContactorFeedbackTimeout` ; `BrakeFeedback := RelayFwd_Up OR RelayRev_Down`. **Aucune dynamique moteur.**
5. **`test_winch_integ.st`** — les 6 familles HARN-1x..6x + les vecteurs sécurité HARN-74/75/80/81, **exécutables**. Oracle = **valeur attendue écrite à la main** (jamais « == ancien calcul »). HARN-75 (redémarrage à chaud) : cible = **front montant `Enable`**, pas `FirstScanDone`.
6. **Entrée registre `WINCH_INTEG`** + **gate dans `run_all_gates.py`** (palier C ou D), rouge tant que la cible n'est pas verte.
7. **Plan de tir** (`DOC/WFLOW/AUDITS/DESIGN/`) : ordre d'import CODESYS **incluant `PRG_07` + `_TYPES` supervision** ; rollback Git par phase ; checklist essais site chiffrée ; mention explicite « aucune protection survitesse active à la mise en service » (SEC-1 de B4).

## 5 · Restitution

- `git diff` complet (stub + mégabloc + suite + gate + registry + run_all_gates).
- Sortie de `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb WINCH_INTEG` (compile + s'exécute ; verdict initial peut être rouge = baseline).
- Sortie de `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C`.
- Note « points d'interprétation / limites du modèle / coordination T169-A ».
- **Aucun commit.**
