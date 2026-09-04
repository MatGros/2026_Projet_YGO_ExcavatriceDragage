# 🔍 AUDIT EXHAUSTIF — Tâches ↔ Contrats & Liaison/Intégrité

> **Date** : 2026-09-04 · **Périmètre** : cohérence `TASKS.yaml` ↔ `CONTRACTS/` + liaison & intégrité (bundle, G200, gates)
> **Mode** : rapport de synthèse — **aucune correction appliquée**.
> **Méthode** : script `TOOLS/AGENT_WORKFLOW/scripts/audit_tasks_contracts.py` (créé pour cet audit) + suite de gates officielle.

---

## 📊 Vue d'ensemble

| Indicateur | Valeur |
|---|---|
| Tâches dans `TASKS.yaml` | **259** |
| Fichiers contrat (DOC + ARCHIVES) | **178** |
| Statuts tâches | 184 ✅ · 34 ⬜ · 25 ⏳ · 8 ⏸️ · 4 ⛔ · 3 ❌ · 1 🔒 |
| Bundle `CODE_XML/CODE_Bundle.xml` | **FRAIS** (généré 2026-09-04 23:37, 0 fichier `.st` plus récent) |
| G200 liaison | **PASS** (0 erreur, 1517 avertissements) |
| Gates (36) | **31 PASS / 5 FAIL** |

---

## 🧩 PARTIE 1 — Cohérence tâches ↔ contrats

### 🔴 1.1 — 66 tâches C2-C4 SANS contrat (champ `contrat:` vide)

La règle `check_task_contract.py` (T1) exige un contrat **dès C2**. **66 tâches** de criticité C2-C4 n'en ont aucun. Extrait des plus critiques :

| Tâche | Criticité | Statut |
|---|---|---|
| T054 | C4 | ✅ |
| T092 | C4 | ⏸️ |
| T125 | C4 | ⏸️ |
| T157 | C4 | ⏸️ |
| T158 | C4 | ⏸️ |
| T180 | C4 | ✅ |
| T181 | C4 | ⏳ |
| T164 | C3 | ⏸️ |
| T187 | C3 | ✅ |
| T198 | C3 | ✅ |
| T201 / T201-A..F | C3 | ✅ |
| T238 | C3 | ⏳ |
| T248 | C3 | ⏳ |
| T251 | C3 | ⬜ |
| T015, T022, T085, T093, T098, T116, T118, T128, T139, T142, T152, T159, T172, T173, T182, T188-A..F, T191, T195, T196, T197, T200, T203, T211, T214, T217, T239..T246, T249, T252 | C2 | mixte |

> ⚠️ **Note** : certaines (T123-D..J, T188-A..F, T201-A..F) sont des **sous-tâches** d'un parent qui a peut-être un contrat. À vérifier si le contrat parent couvre les sous-tâches.

### 🔴 1.2 — 8 champs `contrat:` pointant vers un fichier inexistant

| Tâche | Valeur du champ |
|---|---|
| T181-04 | `null` |
| T181-07 | `null` |
| T181-12 | `null` |
| T181-13 | `null` |
| T181-17 | `null` |
| T181-18 | `null` |
| T188 | `TASK_CONTRACT_T188.yaml` (fichier absent) |
| T250 | `TASK_CONTRACT_T250_position_offset_aware.yaml (a rediger - C3)` (texte, pas un chemin) |

> Le script `fix_task_contract_links.py --check` confirme : **1 lien à repointer** (T188) + **7 orphelins** (dont 6 `null`).

### 🟠 1.3 — 24 contrats DOC actifs ORPHELINS (aucune tâche ne les référence)

Ces contrats sont dans `DOC/WFLOW/CONTRACTS/` (actifs) mais **aucune tâche** de `TASKS.yaml` ne pointe vers eux :

`T089_AF_VIEWER_READONLY`, `T170-A_AUDIT_RELEASE_ET_CLOTURE`, `T181-07_SPEEDSTEP_MINSTEP`, `T181-09_RENOMMAGE_VOCAB`, `T181-12_MINSTEPDOWN_DIVE`, `T181-13_PLANCHER_KOBOLD`, `T196_BUCKET_STATE`, `T197_LEGAL_LIMIT_SIM_BYPASS`, `T198_ENCODER_HOMING_BUTTONS`, `T198_TROUBLESHOOTING_SNAPSHOT`, `T199_BUCKET_HARDWARE_REFERENCE_ROUTE`, `T201-A_NC120`, `T201-B_DIVESEARCH_HEX`, `T201-C_RESETS`, `T201-D_CST_ABORT_GVL`, `T201-F_REVUE_FINALE`, `T202E_QUALIFICATION_FOND_SEMIAUTO`, `T216_PERMITS_DIRECTIONNELS_UNIQUES`, `T217_LIAISON_SORTIES_VARIATEUR_M3`, `T221_M3_P1_BANNER`, `T221_SIMULATION_BYPASS_LIMITES`, `T228_ARMINGPERMIT_TEMPOS_INTERLOCK`, `WT3-T172-A_REBOUCLAGE_X13_X2`, `WT3-T173-A_BANC_WEB_INTERACTIF`.

> 17 autres contrats orphelins sont dans `ARCHIVES/` (normal, archivés).

### 🟠 1.4 — 18 contrats dont le `task_id` interne ne matche aucune tâche

Ex. : `T089_AF_VIEWER_READONLY`, `T170-A_AUDIT_RELEASE_ET_CLOTURE`, `T202E_...`, `T216_...`, `T221_...`, `T228_...`, `AUDIT_STRUCTS_MAPPING`, `LOT_E_ENCODER_INTERFACE_CONFORMANCE`, `LOT_JOYSTICK_...`, `REFACTOR_DOSSIERS_PHASE1..4`, `T163_ROOT_CAUSE_MASKING_HMI_BANNER`, `TASK_MANAGER_CONCURRENCY_REPAIR`.

> ⚠️ Certains `task_id` (ex. `LOT_*`, `REFACTOR_*`) semblent être d'anciennes conventions de nommage. À harmoniser.

### 🟠 1.5 — 22 groupes de contrats en doublon (même préfixe `Txxx`)

Plusieurs contrats coexistent pour une même tâche racine. Exemples notables :

- **T165** : 9 contrats (`T165-A`, `T165-B1`, `T165-B2`, `T165-BR`, `T165-C0`, `T165-C1`, `T165-C2`, `T165-CR`, `T165_FLUX`)
- **T166** : 7 contrats · **T167** : 6 · **T127** : 6 · **T168** : 5 · **T164-4** : 5 · **T172** : 5 · **T201** : 5
- **T181-09** : 2 (`CLAMP_VOCABULARY` + `RENOMMAGE_VOCAB`) · **T198** : 2 · **T199** : 2 · **T221** : 2

> ⚠️ Les sous-tâches (`T165-A`, `T165-B1`…) sont légitimes si elles correspondent à des sous-tâches de `TASKS.yaml`. À vérifier que chaque contrat est bien référencé par sa sous-tâche.

---

## 🧩 PARTIE 2 — Liaison & intégrité

### ✅ 2.1 — Bundle frais

`CODE_XML/CODE_Bundle.xml` généré le **2026-09-04 23:37** — **0 fichier `.st` plus récent**. Bundle à jour.

### ✅ 2.2 — G200 Liaison : PASS

```
Linkage check: PASS (0 erreur(s), 1517 avertissement(s), 1830 instance(s) verifiee(s))
  L1-L7: 129 OK, 0 KO · L8: 0 · L9: 0 OK, 25 WARN · L10: 1694 OK, 1463 WARN
  L11: 0 OK, 29 WARN · L12: 7 OK · L13: 84 OK
```

**Avertissements non bloquants à surveiller** :
- **L10 (producteur unique)** : 1463 WARN — variables assignées depuis plusieurs endroits (ex. `PRG_07_Supervision.DeadmanArmed` assigné depuis 3 lignes). Conforme au pattern « lecture seule stricte » de `PRG_07` mais à documenter.
- **L9 (I/O mapping)** : 25 WARN — `PRG_02_Acquisition` et `PRG_06_Outputs` (`Data`, `HwReal`, `HwSim`, `HwIn`) non trouvés dans la map I/O par nom exact (convention de nommage différente du CSV).
- **L11 (polarité)** : 29 WARN.

### 🔴 2.3 — Gates : 5 échecs sur 36

| Gate | Verdict | Cause |
|---|---|---|
| **G340** — Liens documentaires | **FAIL** | **33 liens morts** (voir 2.4) |
| **G390** — Fraîcheur bundle | **FAIL (faux négatif)** | Planté sur `PermissionError` Windows (nettoyage temp sandbox) — **bundle réellement frais** (vérifié manuellement) |
| **G430** — Commentaires REX | **FAIL** | Commentaires « journal intime » (`[T248]`, `[T249]`, `[REX]`) dans le code, contraires à `CODE_QUALITY_STANDARDS.md §2ter` |
| **G481** — Harnais treuil | **FAIL (faux négatif)** | Planté sur `PermissionError` Windows (nettoyage temp) — pas un échec logique |
| **G483** — Matrice bypass MAINT_N2 | **FAIL** | Bypass non gatés par `MAINT_N2` (voir 2.5) |

### 🔴 2.4 — G340 : 33 liens morts (fichiers renommés/supprimés)

Les liens pointent vers des fichiers **qui n'existent plus** (renommés lors de refactors) :

| Fichier référencé (mort) | Remplaçant probable |
|---|---|
| `CODE/G_CYCLE/FB_Cycle.st` | `FB_CycleMachineHoming.st` / `FB_CycleSemiAuto.st` |
| `CODE/G_CYCLE/FB_MachineHomingCycle.st` | `FB_CycleMachineHoming.st` |
| `CODE/G_CYCLE/_TYPES/E_CycleStep.st` | `E_AutoCycleStep.st` |
| `CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/ST_DredgingAssist*.st` | `ST_ChainDredgingAssist.st` |
| `CODE/J_SUPERVISION/_BRIDGES/FB_CfgPersistBridge_DredgingAssistCfg.st` | — |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cycle.st` | — |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_machinehomingcycle.st` | — |
| `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st` | — |
| `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService.md` | — |

**Documents concernés** : `AUDIT_STRUCTS_MAPPING_20260827.md`, `AUDIT_PERMITS_DIRECTIONNELS_20260901.md`, `PROPOSAL_WT3-T172_X13_X2_20260828.md`, `WFLOW/AUDITS/README.md`, `BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md`, `GEL_GRAFCET_SEMIAUTO_20260903.md`, `TASK_CONTRACT_PHASE1D_HOMING_M2_BENNE_FERMEE.md`, `T185_REFACTOR_FB_MachineHomingCycle_STAGE_A.md`, `DESIGN_T148_...`, `PLAN_T192corrections_...`, `PLAN_T212securite_...`, `GUIDE_SEQUENCEUR_v1.2.md`.

> 🔧 Correctif automatique disponible : `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix` (à valider humainement avant).

### 🔴 2.5 — G483 : bypass non gatés par `MAINT_N2`

Le gate attend **≥ 30 affectations `Bypass*` gatées** par `MAINT_N2` ; seulement **10** le sont. Les bypass effectifs locaux (`BypassM1TopLimitSwitchEff`, `BypassM1CableLimitSwitchEff`, `BypassM2MecaDEff`, etc.) ne sont **pas** gatés par `MAINT_N2`, et `MaintN2` ne dérive pas de `PRG_03_Modes_Cycle.Data.Auth.Mode` (`E_Mode.MAINT_N2`).

> ⚠️ **Sécurité machine** : un bypass non gaté par le mode maintenance peut laisser une dérogation active hors maintenance. **Priorité haute.**

---

## 🎯 Synthèse & recommandations

### Écarts bloquants (à traiter en priorité)
1. **G483** — bypass non gatés par `MAINT_N2` (sécurité machine). **Priorité haute.**
2. **G340** — 33 liens morts vers des fichiers renommés. Correctif `--fix` disponible.
3. **G430** — commentaires REX/journal intime dans le code (à déplacer vers `DOC/`).

### Écarts de traçabilité (cohérence tâches ↔ contrats)
4. **66 tâches C2-C4 sans contrat** — à rédiger ou à rattacher au contrat parent.
5. **8 champs `contrat:` cassés** (6 `null`, T188, T250) — à corriger.
6. **24 contrats DOC orphelins** — à référencer depuis `TASKS.yaml` ou à archiver.
7. **18 `task_id` internes non alignés** + **22 groupes de doublons** — à harmoniser.

### Faux négatifs d'environnement (à ne pas confondre avec des échecs réels)
- **G390** et **G481** ont planté sur un `PermissionError` Windows (nettoyage temp sandbox). Le bundle est **réellement frais** et G200 **PASS**. Ces gates doivent être relancés hors sandbox pour un verdict fiable.

### Hygiène du dépôt (hors périmètre demandé, signalé)
- **14 `.bat` supprimés** non commités + `README.md` modifié + `CODE_BACKUP/` et `TOOLS/LANCEURS/` non suivis. À committer ou à archiver selon l'intention.

---

## 📎 Annexes
- Script d'audit : `TOOLS/AGENT_WORKFLOW/scripts/audit_tasks_contracts.py`
- Sorties gates : G200 PASS · G340 FAIL (33) · G390 planté · G430 FAIL · G481 planté · G483 FAIL
