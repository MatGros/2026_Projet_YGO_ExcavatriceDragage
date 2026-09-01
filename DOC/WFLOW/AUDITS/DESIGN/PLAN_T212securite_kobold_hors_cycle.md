# 📋 PLAN T212 — Sécurité Kobold hors cycle : interlock anti-surchauffe

> Domaine **SAFETY** · Criticité **C2** · Stratégie **patch**
> Contrat de référence : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T212.yaml`
> Source du besoin : demande utilisateur 2026-09-01 (T212, `DOC/WFLOW/TASKS.yaml`).
> Ce document est le livrable **non-code** de cadrage. L'implémentation est **phasee** ci-dessous.

---

## 🎯 1 · Objectifs testables (repris du contrat)

| ID | Objectif mesurable (verrou du contrat) |
|----|----------------------------------------|
| AC1 | Pilotage continu hors cycle → coupure `KoboldContactorCmd=FALSE` dès `KoboldMaxOnDuration` + message « Repos Kobold requis » |
| AC2 | Repos imposé : aucune réactivation avant `KoboldMinRestTime` écoulé, même si `DescentActive` revient |
| AC3 | Fenêtre glissante : cumul ≤ `KoboldMaxCumulativeOn` sur `KoboldTrackingWindow`, sinon blocage + « Fenêtre Kobold dépassée » |
| AC4 | Non-dégradation nominal (Dive/Extraction) : aucune coupure nouvelle sous les seuils ; TC-P04-010..016 et TC-P04-020/021 inchangés |
| AC5 | 4 seuils configurables IHM (`ST_CommunCfg`), défauts 20 s / 60 s / 40 s / 300 s |
| AC6 | État bloquant persistant, réarmement **sur front** uniquement (Reset maintenu ≠ réarmement) |
| AC7 | Garde-fou CI : réintroduire un bypass direct = ROUGE (test non-creux) |
| AC8 | Structurel : fichier = nom de POU ; langage = suffixe bundle (T8, scope `CODE/M_MAIN`) |

**Seuils proposés (à valider humain C4 — Phase 0)** : `KoboldMaxOnDuration=20 s`,
`KoboldMinRestTime=60 s`, `KoboldMaxCumulativeOn=40 s`, `KoboldTrackingWindow=300 s`.

---

## 🧱 2 · Découpage en phases (séquentiel / parallèle + dépendances)

> Graph Kobold identifié : générateur `FB_DiveSearch.Outputs.KoboldContactorCmd` (MAINT_N1/N2)
> **OU** branche bypass `PRG_03` (`TglBypassDiveSearchSequence AND WinchBothMotionActive AND dir=-1`),
> puis arbitrage `FB_BucketCmdArbitration.KoboldContactorCmdArbitrated`, puis sortie physique
> `PRG_06.KoboldContactorCmd → M1_M2_KoboldMeasureEnable_DQ`.

```text
P0 Cadrage & seuils  ─────────────┐  (ARRET VALIDATION C4 : seuils)
P1 Design intégration ────────────┤  (ARRET VALIDATION C4 : point d'insertion)
                                  ▼
P2 Harness tests ROUGES (garde-fou, TC anti-surchauffe)   ◄── bloqué_par P1
                                  ▼
P3 Implémentation ST (config + interlock + message IHM)   ◄── bloqué_par P2
                                  ▼
P4 Vérification mécanique (gates, bundle, G200, run_tests) ◄── bloqué_par P3      [A]
                                  ▼
P5 Documentation AF + registres + REX + garde-fou CI final  ◄── parallèle d'implémentation (peut suivre P3)
                                  ▼
P6 Restitution & recettage humain (C0/C4)  ◄── bloqué_par P4 + P5   (ARRET VALIDATION C0)
```

| Phase | Contenu | bloqué_par | Livrable de sortie |
|---|---|---|---|
| **P0** | Valider les seuils, le comportement (couper + message), le périmètre hors cycle. | — | Seuils signés (ARRET VALIDATION C4) |
| **P1** | Tronquer le design : point d'insertion unique de l'interlock (recommandé : sink `FB_BucketCmdArbitration` **OU** gate `PRG_03` MAINT-branch), discriminateur « hors cycle » (mode `MAINT_N1/N2`), structure DUT/config, chronogrammes. | P0 | Doc design + chronogrammes (ARRET VALIDATION C4) |
| **P2** | Écrire **d'abord** les TC ROUGES : `TC_P212_01..04` (FB_DiveSearch/PRG_03), test garde-fou anti-bypass. Vérifier qu'ils échouent **avant** le fix (preuve non-creuse). | P1 | Harness TC + garde-fou ROUGES |
| **P3** | Implémenter l'interlock : champs config `ST_CommunCfg`, logique max/repos/fenêtre, coupure + message IHM, réarmement sur front. Patch **minimal**, aucun changement dans `FB_Cycle`/`FB_Winch`. | P2 | Code interlock + TCs VERTs |
| **P4** | Gate mécanique bloquante : bundle → `G200` → `run_all_gates --palier C` → `run_tests` FB_DiveSearch/PRG_03/FB_Cycle. Non-régression nominale constatée. | P3 | Bandeau bundle + gates (palier C) |
| **P5** | Mettre à jour `AF_Partie-04/05/07/10`, `DOC/VERSION_HISTORY.md`, registre de décision, note d'application + REX versionné. Garde-fou CI final intégré à la suite. | P3 (parallèle) | Specs + REX + registres |
| **P6** | Restitution complète (contrôle non-régression), recettage humain machine réelle, visa C0. | P4 + P5 | Visa VALIDATED |

---

## 🧪 3 · Plan de TEST

### 3.1 Cas à couvrir (nouveaux TC — harnais STruCpp `TOOLS/TEST_AUTO_CI/`)

| TC | Scénario | Oracle (assert) |
|----|----------|-----------------|
| `TC_P212_01` | Maintenir la descente MAINT au-delà de `KoboldMaxOnDuration` | `KoboldContactorCmd=FALSE` au scan-seuil ; `OperatorAction` = « Repos Kobold requis » |
| `TC_P212_02` | Coupure puis re-demande immédiate, puis re-demande après repos | refus immédiat `=FALSE` ; autorisation = `DescentActive` après `KoboldMinRestTime` |
| `TC_P212_03` | Série d'activations courtes cumulées (< 1 fenêtre) | blocage dès `KoboldMaxCumulativeOn` atteint ; message « Fenêtre Kobold dépassée » |
| `TC_P212_04` | Dépassement de seuil persisté, Reset maintenu vs Reset front | pas de réarmement auto ; Reset front seul réarme |
| `TC_P212_05` (garde-fou) | Tenter de réintroduire un bypass direct du contacteur hors interlock | test **ROUGE** avant fix, VERT après (régression détectée) |

### 3.2 TC existants à surveiller (non-régression obligatoire)

- `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_divesearch.st` : `TC-P04-010..016` (dont coupure contacteur sur contact fond).
- `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cycle.st` : `TC-P04-020/021` (cycle nominal SEMI_AUTO — **intouché**).
- `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/tests/test_prg_03_modes_cycle.st`.
- `MAIN_EndToEnd` (chaîne machine globale).

### 3.3 Plan CI — gates à chaque étape, palier A/B/C

| Étape | Gate / commande | Palier |
|---|---|---|
| P2 (fin) | `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_DiveSearch --fb PRG_03` → TC_P212_0x **ROUGE** attendu (avant-fix) | A |
| P3 (fin) | mêmes commandes → TC_P212_0x **VERT** ; TC-P04-01x inchangés | B |
| P4 | `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` puis `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` (BLOQUANT) | B |
| P4 | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` | C |
| P4 | `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb MAIN_EndToEnd --fb FB_Cycle` (non-régression nominale) | C |
| P5 | `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix` puis re-run gates | C |
| P6 | `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T212.yaml` (gate contrat) | C |

> 🔒 La CI ne qualifie **pas** le terrain : le recettage machine réelle (échauffement moteur,
> comportement d'usage épisodique) reste un point de signature humain (P6, `ARRET VALIDATION C0`).

---

## 🤖 4 · Assignation AGENT

| Rôle | Agent | Phase | Périmètre |
|---|---|---|---|
| **Challenger design** | Subagent A (analyse indépendante) | P1 | Challenger le point d'insertion et le discriminateur « hors cycle » avant toute écriture de code |
| **Rédaction tests ROUGES** | Subagent dev (impl. agent) | P2 | Écrire TC_P212_0x + garde-fou, prouver ROUGE avant fix |
| **Implémentation ST** | Subagent dev (impl. agent) | P3 | Config `ST_CommunCfg` + logique interlock + message IHM, patch minimal |
| **Revue indépendante** | Subagent B (revue / challenge) | P4.5 | Relecture du `git diff` réel, chronogrammes, non-régression nominale ; **ne code pas** |
| **Vérification mécanique** | Orchestrateur (DSH) | P4 | Bundle, G200, gates palier C, run_tests |
| **Ordonnancement & visa** | Orchestrateur + humain | P0/P6 | Validation seuils (C4), recettage et visa (C0) |

> Règle `fix:` + `guard:` : tout bug de la chaîne pilotée découvert pendant P2/P4 donne l'interlock **et**
> le garde-fou CI correspondant, jamais une réponse purement documentaire.

---

## 📚 5 · Modifications DOC à prévoir

| Fichier | Nature du changement |
|---|---|
| `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` | Étendre l'invariant **H1 anti-chauffe** au pilotage **hors cycle** : nouveaux seuils (durée/repos/fenêtre), coupure + message, chronogramme d'interlock, table des seuils config |
| `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` | Section arbitrage/sortie Kobold (`KoboldContactorCmdArbitrated`) : interlock anti-surchauffe en aval de la demande hors cycle |
| `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md` | Mentionner l'interlock anti-surchauffe Kobold en MAINT_N1/N2 (usage épisodique raisonné) |
| `DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md` | Message/alarme opérateur « Repos Kobold requis » / « Fenêtre Kobold dépassée » |
| `DOC/VERSION_HISTORY.md` | Nouveau jalon T212 (une ligne) |
| `DOC/WFLOW/REGISTRES/` | Consigner la décision des seuils (+ registre de décision de conception) |
| `DOC/WFLOW/AUDITS/DESIGN/` | Doc design (P1) + REX de lot (P5) |
| `DOC/STDS/NAMING_CONVENTION.md` | **Modification NON autorisée** (forbidden) — on s'y conforme (nouveaux champs PascalCase, préfixes, unités `T#..s`) |
| Note d'application (`CODE/.../*`) | Commentaire ST d'application au niveau de l'interlock |

---

## 🛑 6 · Arrêts de validation humaine (C0/C4)

- **`ARRET VALIDATION C4` — P0** : les seuils anti-surchauffe (20 s / 60 s / 40 s / 300 s) doivent être
  acceptés (ou ajustés) **avant** tout écriture. La valeur d'un seuil trop permissif n'est pas une
  décision d'agent.
- **`ARRET VALIDATION C4` — P1** : choix final du point d'insertion l'interlock (sink `FB_BucketCmdArbitration`
  vs gate `PRG_03` vs `FB_DiveSearch`) et du discriminateur « hors cycle », validé sur chronogrammes.
- **`ARRET VALIDATION C0` — P6** : recettage machine réelle (comportement d'usage épisodique, non-échauffement,
  non-interférence avec Dive/Extraction) signé par l'humain avant clôture/commit.

> ⚠️ Aucun `Device.export` n'est une référence de contrôle (toujours considéré périmé). La source de
> vérité reste `CODE/*.st` + interfaces déclarées. Aucun `git reset/checkout` destructif, aucun commit
> sans visa humain, aucun push direct vers `origin/main`.
