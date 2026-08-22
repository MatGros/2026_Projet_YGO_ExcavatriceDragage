# 🔍 Session d'audit 2026-08-20 — État réel `PLAN_TASK` ↔ `CODE/`

> 📅 2026-08-20 · 🤖 Agent `CC-01` · 🔍 **Read-only** : aucune ligne de `CODE/` modifiée.
> 📏 Référentiels : `DOC/STDS/CODE_QUALITY_STANDARDS.md` · `DOC/WFLOW/TASKS.yaml` · `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`

---

## 🎯 Pourquoi cette session

`PLAN_TASK.md` a atteint **502 lignes** et son tableau §3 compte **142 tâches**. Plusieurs statuts
ne correspondaient plus au code réel : verrous posés sur des lots terminés, tâches `⏳` depuis des
semaines sans essai, briques citées comme « partielles » alors qu'elles n'existent plus.

Objectif : **rétablir la correspondance statut ↔ code**, par preuve mécanique (`fichier:ligne`),
et non par relecture de l'historique.

## 🚫 Ce que ces fiches ne sont pas

Ce dossier porte l'**analyse** (le *pourquoi*, les preuves). Il ne porte **aucun statut de tâche** :
`PLAN_TASK.md` reste la source unique du pilotage (règle `PLAN_TASK.md:77`). Une fiche qui
contredirait `PLAN_TASK` est un signalement à traiter, jamais une seconde vérité.

---

## 📂 Les 5 fiches

| # | Fiche | Répond à la question | Statut |
|---|---|---|:---:|
| 1 | [`FICHE_1_Ecarts_Plan_Code.md`](FICHE_1_Ecarts_Plan_Code.md) | Quels statuts `PLAN_TASK` sont faux, et sur quelle preuve ? | 🔴 7 écarts |
| 2 | [`FICHE_2_Bugs_Liaison_Actifs.md`](FICHE_2_Bugs_Liaison_Actifs.md) | Quels défauts de câblage sont **actifs** dans le code ? | 🔴 2 bugs |
| 3 | [`FICHE_3_Blocage_Socle_FbStatus.md`](FICHE_3_Blocage_Socle_FbStatus.md) | Pourquoi T136/T137 ne peuvent pas avancer ? | ⛔ bloqué |
| 4 | [`FICHE_4_Ordonnancement_Phases.md`](FICHE_4_Ordonnancement_Phases.md) | Refactor d'abord ou essais d'abord ? | 🟡 arbitrage |
| 5 | [`FICHE_5_REX_Fiabilite_Audit_Delegue.md`](FICHE_5_REX_Fiabilite_Audit_Delegue.md) | Un audit délégué a produit de fausses preuves — que fait-on ? | 🔴 REX |

---

## ✅ Base de contrôle au moment de l'audit

| Contrôle | Résultat |
|---|---|
| `run_all_gates.py` (suite complète) | **19/19 PASS** |
| `G200_check_linkage.py --report` | **PASS** — 67 liaisons OK / 0 KO · 1154 instances · 65 orphelins OK |
| `G315_check_fb_interface.py` | PASS — 53 FB (21 standard, 27 light, 5 exceptions) |
| `G340_check_doc_links.py` | PASS — 0 erreur |

> ⚠️ Deux gates (`G390`, `G420`) sont d'abord ressortis rouges : **artefacts du bac à sable**
> (accès `%TEMP%` refusé), pas des défauts du dépôt. Confirmé vert après élargissement des droits.
> 🔒 **Un gate vert ne prouve pas qu'une fonction est reliée** — voir fiche 2.

## 🧭 Ordre de lecture conseillé

**Fiche 2** (les bugs actifs, urgents) → **fiche 3** (le blocage socle) → **fiche 1** (le détail des
écarts) → **fiche 4** (l'arbitrage de planification) → **fiche 5** (le REX méthode).

---

## ❓ Décisions humaines en attente

Ces 4 points bloquent la suite. Ils sont détaillés dans les fiches indiquées.

| # | Question | Fiche |
|---|---|:---:|
| Q1 | Les 4 DUT `ST_*InterPrg` non suivies par git — qui les a créées, faut-il les conserver ? | 2 |
| Q2 | Les 7 tâches `⏳` ont-elles réellement été testées en CODESYS, ou attendent-elles depuis des semaines ? | 1 |
| Q3 | `AGY-01` travaille-t-il encore sur `PRG_04`/`PRG_07` (risque de collision) ? | 1 |
| Q4 | Valide-t-on l'ordre Phase 0 → 1 → 2 → 3, ou le refactor d'abord ? | 4 |
