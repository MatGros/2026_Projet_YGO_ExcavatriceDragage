# 🗺️ PLAN T192 — Corrections safety cycles — défaut latché et reprise consciente (reste doc/validation)

**Tâche** : `T192` · **Criticité** : `C1` (SÉCURITÉ) · **Stratégie** : `patch` · **Lot non-code**
**Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T192.yaml` (AC1–AC7)
**Cible** : clôturer la correction S1+S2 **déjà implémentée** (commit `877f48ac`) — travail restant **purement documentaire/validation**.

> 🎯 **Principe** : le code est déjà fait. Ce plan n'édite **aucun** fichier `CODE/`.
> La revue R1–R7 lit le code en **lecture seule** et produit un acte documentaire.
> ARRET : toute envie de modifier un `CODE/*.st` = sortie de scope → devoir d'alerte.

---

## ✅ Objectifs testables (repris du contrat, AC1–AC7)

| # | Objectif observable | Preuve (commande) |
|---|---|---|
| O1 | Revue indépendante `REVUE_T192_<date>.md` avec verdict par point R1–R7 | `grep -E '^\| *R[1-7]' REVUE_T192_*.md` → 7 lignes VALIDÉ/ÉCART |
| O2 | Gate S1 X0→X1 confirmé sur `NOT Fault.Latched` | `grep -n 'Fault.Latched' FB_Cycle.st` → ligne `AND NOT Fault.Latched THEN` (X0→X1) + `Ready := Enable AND NOT Fault.Latched` |
| O3 | Reprise consciente S2 = `StartEdge.Q` seul | `grep -n 'StartEdge.Q' FB_Cycle.st` → sortie de `WaitingResume` (FB_Cycle:282, bloc 278-303, gate 338) |
| O4 | AF-04 §4.1 = décision « BtnStart seul » | `grep -n 'BtnStart\|geste conscient\|homme-mort' AF_Partie-04_*` → §4.1 conforme (ou diff documenté) |
| O5 | Renommage `Ascending→Ascent` acté (R7) | `grep -ni 'Ascending' FB_Cycle.st` → 0 hors commentaire ; `ProcessPermitM1_Ascent` cohérent |
| O6 | Aucun contenu `CODE/` modifié | `git diff --name-only -- CODE/G_CYCLE/FB_Cycle.st` → vide |
| O7 | Clôture T192 (`✅` + `completed_at`), T192-A déjà `✅` | `grep -n 'id: T192$' TASKS.yaml` + lecture statut ; `grep -A6 'id: T192-A'` |

---

## 🧩 Découpage en phases

| Phase | Contenu | Dépend de (`bloque_par`) |
|---|---|---|
| **P0 · Cadrage** | Relire contrat + AF-04 §4.1 + code `FB_Cycle.st` (lecture seule), fixer la base de référence git (HEAD `877f48ac`). | — |
| **P1 · Revue S1** | Points **R1** (gate X0→X1 sur `NOT Fault.Latched`, pas de bypass Abort+Start), **R2** (Reset front → STABILIZING→X0 + acquitte le socle), **R3** (Abort → X0 **sans** acquitter le latch → départ bloqué). | P0 |
| **P2 · Revue S2** | Points **R4** (sortie `WaitingResume` sur `StartEdge.Q` seul), **R5** (hold actionneurs neutralisés + `WaitingForOperator` pendant la reprise), **R6** (défaut `ErrorEdge` → `STABILIZING` et abroge la reprise, `WaitingResume:=FALSE`), **R7** (conformité AF-04 §4.1 + cohérence renommage `Ascent`). | P0 |
| **P3 · Revue finale & doc** | Consolidation verdicts R1–R7 dans `REVUE_T192_<date>.md` ; mise à jour/confirmation AF-04 §4.1 (décision BtnStart seul) ; acte du renommage `Ascending→Ascent`. | P1 **∥** P2 |
| **P4 · Tests & CI** | Exécution des TCs `FB_Cycle` (9 de `test_fb_cycle.st` + 6 de `test_fb_cycle_full.st`) + TC S1 (T192-A, déjà ajouté) ; gates mécaniques de non-régression. | P3 |
| **P5 · Clôture** | Mise à jour `TASKS.yaml` (T192 → `✅`, `completed_at`) puis restitution. | P4 |

> P1 et P2 sont **parallélisables** (revues S1 et S2 disjointes). P3 les consolide.

---

## 🧪 Plan de TEST

### Cas à couvrir (oracles)
- **S1 / TC S1 (T192-A, close)** : `Abort+Start` **avec** `Fault.Latched` actif (défaut non acquitté) → le cycle **reste en X0**, aucun redémarrage. Le gate X0→X1 sur `NOT Fault.Latched` (FB_Cycle:360) est prouvé.
- **S1 / TC-P04-004** : reprise après `STABILIZING` (Reset front) → X0 → départ OK après acquittement. Non-régression.
- **S2 / TC-P04-102** : reprise consciente après bascule de mode → `WaitingResume` actif, gel en pause, sortie **sur `StartCycle` uniquement** (l'armement homme-mort seul ne reprend pas).
- **Régression transitions** : Reset→X0, Abort→X0 (latch conservé), Error→STABILIZING (+ `CycleStepAtError` avant bascule), X3/benne déjà ouverte, X9 écart minime.

### Fichiers / TCs existants
| Source | Fichiers | Couverture |
|---|---|---|
| Harnais FB_Cycle | `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cycle.st` (9 TC) + `test_fb_cycle_full.st` (6 TC) | grafcet X0→X13, repli, reprise (TC-P04-001..021 + TC S1/T192-A, TC-P04-102) |

### Plan CI — gates par étape (paliers A/B/C)
| Étape | Palier | Commande | Attente |
|---|---|---|---|
| Avant revue (P0) | A | `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T192.yaml` | **PASS** |
| Après P3 | B | `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix` | **PASS / liens MAJ** |
| Après P4 | B | `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` puis `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` | Bundle EXPORT **PASS** · liaison **0 erreur** |
| Fin P4 | B | Lancement harnais STruCpp FB_Cycle (TC S1 + 9 + 6) | **tout PASS** (0 assert échoué) |
| Fin P5 | C | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` | **tout PASS** |
| Fin P5 | C | `git diff --name-only -- CODE/` → aucun nouveau diff de contenu hors renommage pré-existant | vide (check O6) |

> ℹ️ **Palier C** = fin de lot : `run_all_gates.py --palier C`. Voir `GUIDE_GATES_ET_TESTS §2`.

---

## 👤 Prévision d'assignation AGENT

| Rôle | Qui | Responsabilité |
|---|---|---|
| **Rédacteur contrat & plan** | DSH (subagent, ce lot) | `TASK_CONTRACT_T192.yaml` + ce `PLAN_*` + PASS du check (T1–T8). |
| **Revue indépendante R1–R7** | **Orchestrateur ou agent tiers (≠ celui qui a implémenté S1/S2)** | Lecture seule `FB_Cycle.st`, verdicts VALIDÉ/ÉCART, écrit `REVUE_T192_<date>.md`. La revue **ne doit pas** être faite par l'auteur de `877f48ac` (sécurité de l'indépendance). |
| **Mise à jour AF-04 §4.1** | Agent doc (DSH) | Confirmer/écrire « reprise BtnStart seul » cohérent avec le code. |
| **Acte renommage Ascending→Ascent** | Agent doc (DSH) | Vérifier cohérence `Ascent` dans `FB_Cycle.st`, noter dans R7. |
| **Clôture TASKS.yaml** | Orchestrateur (règle `task-planner` : 🔒 + 🚩 + `date` ISO) | T192 → `✅`, `completed_at` ; vérif enfants T192 ouverts (T192-A déjà ✅). |

---

## 📚 Modifications DOC à prévoir

| Document | Changement | Statut attendu |
|---|---|---|
| `DOC/WFLOW/AUDITS/REVUE_T192_<date>.md` | **Création** — verdicts R1–R7 + synthèse sécurité S1/S2 | nouveau |
| `DOC/WFLOW/AUDITS/DESIGN/PLAN_T192corrections_safety_cycles_reste.md` | **Création** — ce plan | nouveau |
| `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T192.yaml` | **Création** — ce contrat (AC1–AC7) | nouveau |
| `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` | **§4.1** — confirmer/écrire la reprise « BtnStart seul » (décision utilisateur) ; maj `VERSION_HISTORY` si diff réel | édité (si écart) |
| `DOC/VERSION_HISTORY.md` | entrée pour la revue T192 + clôture | édité (si diff réel) |
| `DOC/WFLOW/TASKS.yaml` | T192 → `✅` + `completed_at` ISO (clôture) | édité |

> **Registres** : respecter `NAMING_CONVENTION` (PascalCase) et NC-100 (fail-safe) dans toute relecture. Aucune règle `DOC/STDS/NAMING_CONVENTION.md` n'est modifiée.

---

## 🚦 Arrêts de validation humaine

- **ARRÊT VALIDATION 1** (après P3) : **human/orchestrator** — lecture de `REVUE_T192` + confirmation du choix « BtnStart seul » dans AF-04 §4.1 avant toute clôture.
- **ARRÊT VALIDATION 2** (après P4) : **human/integrateur CODESYS** — si un TC échoue ou si la liaison G200 est rouge, le lot s'arrête (aucune clôture).
- **ARRÊT VALIDATION 3** (P5) : **orchestrator** — visa du diff réel `git diff` avant tout commit de clôture (jamais de push direct).

> Criticité C1 · tâche de sécurité : tout ÉCART de revue = **devoir d'alerte immédiat**, pas de complaisance. La validation finale reste à l'orchestrateur/humain.
