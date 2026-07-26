# 🗑️ PLAN — Suppression du framework de tests in-PLC (`PLC_TESTS`)

**Version** : v1.1 · **Date** : 2026-07-26 · **Demandeur** : utilisateur
**Motif** : le framework occupe trop de place dans l'automate et son **maintien est chronophage**
(chaque évolution métier oblige à réécrire les suites).
**Statut** : 📋 plan validé sur le périmètre, **non exécuté**.

> 🔄 v1.1 (2026-07-26) : Phase 2 ne modifie plus le contenu de `GVL_PLC_Tests` (simple déplacement) ;
> le ménage des variables devient une **Phase 5 dédiée**, découpée en 5 sous-étapes testables.

---

## 0. 🎯 Décisions de cadrage (validées 2026-07-26)

| # | Décision | Choix |
|---|---|---|
| D1 | Séquenceur auto + 7 suites de validation | ❌ **Supprimés** (Phases 1-3) |
| D2 | `GVL_PLC_Tests` et ses `Override*` | ✅ **Conservés intacts** pendant les phases 1-4 — nom inchangé, **zéro modif dans PRG_00/01/09** |
| D3 | Sort du code/doc retirés | 📦 **`ARCHIVES/`** (+ historique git) |
| D4 | Ménage des variables mortes | ⏸️ **Phase 5 séparée**, après stabilisation — pas mélangé à la suppression du moteur |

👉 Conséquence de D2 : les `Override*` deviennent des **forçages manuels** (vue instance CODESYS
ou IHM pour M3), plus aucun automate ne les pilote. C'est le mode de test qui reste.

---

## 1. 📊 État des lieux

### Poids
| Mesure | `PLC_TESTS` | `CODE/` total | Part |
|---|---|---|---|
| Fichiers `.st` | **45** | 158 | 28 % |
| Lignes ST | **7 347** | 17 247 | **43 %** |

### Contenu (45 fichiers)
```
FB_TestSequencer.st · GVL_PLC_Tests.st · GVL_PLC_Tests_Const.st
BRICKS/          6 FB   (TestCheck, TestEdgeCounter, TestEventOrder, TestStimulus, TestStopwatch, Timeout)
CORE/            6 FB   (TranslationTestPlan/Runtime/StepExecutor/Fixture/Cleanup/ReportFinalizer)
FRAMEWORK_TESTS/ 1 FB   (TestFrameworkValidation)
SUITE_*/         8 FB   (Safety, PLC_Tests_Management, Heartbeat, Translation, Bucket, Encoder, Modes, Supervision)
TYPES/           8 ENUM + 13 STRUCT
```

### Points d'accroche dans le programme — **5 seulement**
| Fichier:ligne | Accroche | Action |
|---|---|---|
| `PRG_00_Inputs.st:102` | `instTestsManagement : FB_PLC_Tests_Management;` | ❌ supprimer (P1) |
| `PRG_00_Inputs.st:294-295` | appel `instTestsManagement(...)` | ❌ supprimer (P1) |
| `PRG_00_Inputs.st:116,160,298-342` | 14 blocs `IF GVL_PLC_Tests.Override*` | ✅ **conserver** (D2) |
| `PRG_01_Diagnostics.st:42-45,91-95` | overrides Joystick + Heartbeat IHM | ✅ **conserver** (D2) |
| `PRG_09_Supervision.st:64-73` | `GVL_IHM.TranslationM3.Test.*` → `Override*` | ✅ **conserver** (D2) |
| `PRG_06_WinchControl.st:564-565` | `GVL_Simulation.LinkBucket/LinkWinchM2 REF=` | ❌ supprimer (P1) — seul lecteur = `FB_BucketValidation` |
| `GVL_Simulation.st:85-86` | 2 champs `REFERENCE TO FB_Bucket/FB_Winch` | ❌ supprimer (P1) |

### Écritures perdues (⚠️ à assumer)
Les suites pilotaient `GVL_IHM` en simulation : `M1/M2TreuilRetenue.Cmd.BtnHome`,
`Modes.Cmd.SelMode`, `Modes.Cmd.BtnFaultReset`, `Cycle.Cmd.BtnStart`.
👉 Ces séquences devront être **rejouées à la main** en simulation. Aucun impact terrain
(tout était gardé par `GVL_Simulation.SimulationModeActive`).

### Impact outillage
| Fichier | Action |
|---|---|
| `TOOLS/ST_PLCOPENXML_GENERATOR/tests/integration/test_plc_test_safety_contract.py` | ❌ supprimer (100 % dédié) |
| `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py:53` | 🔧 retirer l'exception `/SIMULATION/PLC_TESTS/` |
| `TOOLS/AGENT_WORKFLOW/scripts/pre_edit_gate.py:20` | 🔧 retirer réf `AF_Partie-14` (+ corriger `Partie-13 v1.2`→`v1.3`, déjà obsolète) |
| `TOOLS/generate_workflow_png.py:168,285` · `AGENT_WORKFLOW/docs/WORKFLOW.md:52` | 🔧 retirer l'étape « Simulation PLC_TESTS » du schéma |
| `generator/st_types.py:27` · `docs/PLCOPENXML_FORMAT.md:263` | ✅ **garder** le support borne symbolique (`ARRAY[1..GVL_X.Const]`) — générique ; 🔧 noter qu'après P5 aucun code du projet ne l'exerce plus |
| `tests/integration/test_cli_full_code_tree.py:35` (`len(objects) >= 60`) | ✅ RAS — 114 objets restants |
| `tests/golden/` | ✅ RAS — n'utilise pas `PLC_TESTS` |
| `CODE/CODE_Bundle.xml` | 🔄 régénérer **après chaque phase touchant `CODE/`** (1, 2, 3, 5) |

---

## 2. 🧩 Découpage en phases

> ⚠️ **L'ordre est critique** : découpler AVANT de supprimer, sinon erreurs de compilation CODESYS.

### 🔹 Phase 1 — Découplage (code métier)
**Modifs** : 3 fichiers
1. `PRG_00_Inputs.st` — supprimer la déclaration `instTestsManagement` (l.102) et son appel (l.294-295).
2. `PRG_06_WinchControl.st` — supprimer les 2 `REF=` (l.564-565).
3. `GVL_Simulation.st` — supprimer `LinkBucket` et `LinkWinchM2` (l.85-86) + bandeau de commentaire.

`PLC_TESTS` est encore présent mais **plus jamais appelé**.
⚠️ Les FB des suites restent compilés (objets orphelins) → warnings « unused » possibles, normal.

✅ **Test P1** : compilation 0 erreur · en simulation : boot, homing M1/M2, cycle semi-auto complet,
AU + réarmement, translation M3 → comportement **strictement identique**.
(Tous les `Override*` sont `FALSE` au boot et n'ont plus aucun écrivain → aucun effet de bord possible.)

---

### 🔹 Phase 2 — Sortie de la GVL et de ses types (⚠️ **déplacement seul, zéro modif de contenu**)

`GVL_PLC_Tests` ne compile pas seule : elle dépend de 13 autres fichiers du dossier.
On sort donc **14 fichiers** de `PLC_TESTS/` vers `CODE/SIMULATION/` **sans toucher une ligne** :

```
CODE/SIMULATION/
├── GVL_PLC_Tests.st            (74 l.)  ← les 40 vars, INTACTES
├── GVL_PLC_Tests_Const.st      (30 l.)  ← MaxSteps / MaxTestCases / MaxTestEvents
└── _TYPES_TESTS/
    ├── ST_PlcTestsCmd · ST_PlcTestsStatus · ST_TestEvent
    ├── ST_TestSuiteReport ─┬─ ST_TestStepResult
    │                       └─ ST_TestCaseResult
    ├── ST_TranslationTestResult · ST_TestFrameworkResult
    └── E_TestRunState · E_TestTerminalState · E_TestEventSeverity · E_TestFailReason
```
Total conservé : **308 lignes** (4 % du dossier).

✅ **Test P2** : compilation 0 erreur. Aucun comportement ne change (déplacement pur).

---

### 🔹 Phase 3 — Archivage du moteur (31 fichiers)
`CODE/SIMULATION/PLC_TESTS/` → `ARCHIVES/Code/PLC_TESTS/` :
- `FB_TestSequencer` (1) + `BRICKS/` (6) + `CORE/` (6) + `FRAMEWORK_TESTS/` (1) + `SUITE_*/` (8) = **22 FB**
- Types de configuration devenus inutiles : `ST_TestCaseConfig`, `ST_TestCheckConfig`,
  `ST_TestInvariantConfig`, `ST_TestStepConfig`, `ST_TestStimAnalogConfig`,
  `E_TestCheckKind`, `E_TestCheckMode`, `E_TestStimKind`, `E_TestFailAction` = **9 types**

**−7 039 lignes.** Le générateur ne scanne que `CODE/` → le bundle se nettoie tout seul.

✅ **Test P3** : compilation 0 erreur · simulation identique à P1 · `pytest` vert (après P4).

---

### 🔹 Phase 4 — Outillage & bundle
1. `git rm tests/integration/test_plc_test_safety_contract.py`
2. `check_code_style.py` : retirer l'exception `PLC_TESTS` · `pre_edit_gate.py` : retirer `AF_Partie-14`
3. `generate_workflow_png.py` + `WORKFLOW.md` : retirer l'étape « Simulation PLC_TESTS »
4. Régénérer le bundle :
   ```
   cd TOOLS/ST_PLCOPENXML_GENERATOR
   python -c "from generator.cli import main; import sys; sys.exit(main(['--bundle','CODE_Bundle','--project-name','MGS_v0.6.0']))"
   ```

✅ **Test P4** : `python -m pytest` vert · **import d'essai** du bundle dans un projet CODESYS vierge → 0 erreur.

---

### 🔹 Phase 5 — 🧹 Ménage des variables mortes (D4)

> 🔑 **Point clé** : après P3, aucune des variables ci-dessous n'est lue **nulle part** dans le
> programme. Chaque sous-étape se valide donc par une **simple compilation** — impossible de créer
> une régression métier. C'est aussi ici que le gain **RAM** arrive (le moteur, c'était de la
> mémoire *programme*).

**Ce qui RESTE (20 vars, jamais touchées)** — lues par `PRG_00`/`PRG_01`, écrites par `PRG_09`/toi :

| Groupe | Variables | Lecteur |
|---|---|---|
| Chaîne AU | `OverrideChainTrue`, `OverrideChainFalse`, `OverrideContactorFalse`, `OverrideEmergencyStopOkTrue` | `PRG_00:160,298-308` |
| Translation M3 | `OverrideM3AtTremie`, `OverrideM3BrakeStuckOpen`, `OverrideM3PhantomFreq`, `OverrideM3SensorsWordActive`, `OverrideM3SensorsWord` | `PRG_00:311-328` ← écrit par `PRG_09:64-73` (IHM) |
| Joystick | `OverrideJoystickActive`, `OverrideJoystickRawX`, `OverrideJoystickRawY`, `OverrideJoystickRawButton` | `PRG_01:42-45` |
| Heartbeat | `OverrideIhmHeartbeatActive`, `OverrideIhmHeartbeatToggle` | `PRG_01:91-95` |
| Retours M1/M2 | `OverrideM1FwdRevSpeedFbOff`, `OverrideM1BrakeFeedback`, `OverrideM2FwdRevSpeedFbOff`, `OverrideM2BrakeFeedback` | `PRG_00:331-342` |
| Purge boot | `OverrideHmiCommandPurge` | `PRG_00:116` |

**Sous-étapes** (chacune compilable/testable indépendamment, dans cet ordre) :

| Étape | Ce que je supprime dans `GVL_PLC_Tests` | Types libérés ensuite | Gain RAM | Risque |
|---|---|---|---|---|
| **5a** | `OverrideM1Slip`, `OverrideM1SlipCritical`, `OverrideM2Stuck`, `OverrideM2BootDrift` (4 BOOL, lus uniquement par l'ex-`FB_BucketValidation`) | — | ~0 | 🟢 nul |
| **5b** | les 7 `Suite*Validation` + `SuiteTranslationResult` + `FrameworkResult` (9 vars) | `ST_TestSuiteReport`, `ST_TestStepResult`, `ST_TestCaseResult`, `ST_TranslationTestResult`, `ST_TestFrameworkResult`, `E_TestTerminalState`, `E_TestFailReason` (7 fichiers) | **≈ 27 Ko** | 🟢 nul (⚠️ voir IHM ci-dessous) |
| **5c** | `EventLog[32]`, `EventCount`, `EventSequence`, `EventOverflow` | `ST_TestEvent`, `E_TestEventSeverity` (2 fichiers) | **≈ 3 Ko** | 🟢 nul |
| **5d** | `Cmd` (`ST_PlcTestsCmd`), `Status` (`ST_PlcTestsStatus`) | `ST_PlcTestsCmd`, `ST_PlcTestsStatus`, `E_TestRunState` (3 fichiers) | ≈ 0,5 Ko | 🟠 **bindings IHM** |
| **5e** | — | `GVL_PLC_Tests_Const.st` (plus aucune borne symbolique) | — | 🟢 nul |

**Résultat P5** : `CODE/SIMULATION/GVL_PLC_Tests.st` ≈ **30 lignes, 20 variables**, plus **aucun**
type de test dans `CODE/` → le dossier `_TYPES_TESTS/` disparaît (13 fichiers).

🟠 **Vigilance étape 5d (et 5b)** : si la supervision physique affiche un panneau de tests
(`GVL_PLC_Tests.Cmd.RunAll`, `Status.*`, `Suite*.FailureSummary`), **ces bindings casseront**.
→ confirmer avec le collègue IHM **avant 5b**, et tracer dans
`DOC/AUDITS/ConfigPersistence/IHM_VARIABLES_MIGRATION.md`.
Les 20 `Override*` conservés gardent nom **et** chemin (`GVL_PLC_Tests.*`) → **aucun reparamétrage**.

✅ **Test P5** : après chaque sous-étape → compilation 0 erreur.
En fin de phase → simulation complète (boot / homing / cycle / AU / M3) + forçage manuel
d'au moins 3 `Override*` (`OverrideChainFalse`, `OverrideM3SensorsWord`, `OverrideJoystickActive`)
pour vérifier que les points d'injection restent opérants.

---

### 🔹 Phase 6 — Documentation (en dernier, une fois le code figé)
| Fichier | Action |
|---|---|
| `DOC/AF_Partie-14_PLC_Tests_Validation_v1.2.md` | 📦 → `ARCHIVES/Doc/` |
| `DOC/AUDITS/TEST_FRAMEWORK_AUDIT_v1.0.md` | 📦 → `ARCHIVES/Doc/` |
| `CLAUDE.md`, `AGENTS.md`, `README.md` | 🔧 délister Partie-14 (+ plan de numérotation) |
| `DOC/AF_Partie-13_Fonction_Simulation_v1.3.md` → **v1.4** | 🔧 retirer renvois `PLC_TESTS` + `Link*` ; documenter les 20 `Override*` comme forçages manuels |
| `DOC/AF_Partie-02_Architecture_Programme_v2.12.md` | 🔧 retirer `PLC_TESTS` de l'arborescence |
| `DOC/PLAN_TASK_v1.0.md` | 🔧 feature « framework tests in-PLC » → **❌ abandonnée** (motif : empreinte automate + coût de maintenance) |
| `DOC/VERSION_HISTORY.md` | ➕ ligne jalon |
| `DOC/REGISTRE_Suivi_MiseEnService_v1.0.md` | ➕ TC-01/02/03 basculés en validation manuelle/FAT |
| `DOC/AUDITS/ConfigPersistence/*` (TASK_*) | ✅ **ne pas toucher** — archives de lots exécutés |
| `.claude/settings.local.json` | 🔍 vérifier une éventuelle permission/chemin `PLC_TESTS` |

---

## 3. 🖐️ Application manuelle CODESYS (utilisateur)

**Ordre impératif** (sinon erreurs de compil) :
1. **P1** — éditer `PRG_00_Inputs`, `PRG_06_WinchControl`, `GVL_Simulation` → **compiler** (0 erreur).
2. **P2** — déplacer les 14 objets hors du dossier `PLC_TESTS` (glisser-déposer dans l'arbre CODESYS,
   contenu inchangé) → **compiler**.
3. **P3** — supprimer le dossier `PLC_TESTS` (31 objets restants) → **compiler** + rejouer le test P1.
4. **P5** — sous-étape par sous-étape : coller la nouvelle `GVL_PLC_Tests`, supprimer les objets types
   listés, **compiler après chaque sous-étape**.

---

## 4. 📈 Gain attendu

| | Avant | Après P3 | Après P5 |
|---|---|---|---|
| Fichiers `.st` dans `CODE/` | 158 | 127 | **114** (−44) |
| Lignes ST | 17 247 | 10 208 | **~9 930** (−7 317, **−43 %**) |
| Objets CODESYS | — | −31 | −44 |
| RAM data (rapports/journal) | ~30 Ko | ~30 Ko | **≈ 0** |
| Charge de maintenance | 7 suites à resynchroniser | 0 | 0 |

**Ce qu'on garde** : toute la capacité de test **manuelle** en simulation
(`GVL_Simulation` bit maître + granularité par device, `FB_Sim_*`, 20 `Override*` forçables).
**Ce qu'on perd** : le rejeu automatique non-régression (TC-01/02/03 de la Partie 14)
→ bascule sur validation manuelle / FAT terrain (Phase 6).
