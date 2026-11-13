# T429 — Plan complet, détaillé et vérifié

> **Contrat mesurable** : `T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml` (AC-F0 → AC-F4, AC-X, `tracking` avec preuves datées)
> **Pilotage initial (historique)** : `DOC/WFLOW/TASKS/T_TEMP (A TRIER)/T429_AGENT_SUPERVISOR_PLAN_REPRISE_TRANSCRIPT_ET_PLUGIN_20261108_v1.0.md`
> **Preuves** : `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/PREUVES/<session>/`
> **Acteur** : CC01 (session `T429-MMX01`, 🔒 de travail CC01 depuis le 2026-11-13) · **Criticité** C2 · **Stratégie** patch

---

## 1. 🧭 Cadrage

**Objectif** : rendre le suivi d'une session surveillée fiable (continuité, cycle des constats, ergonomie IHM, envoi au chat), prouvé sur parcours réels.

**Périmètre** : `TOOLS/AGENT_SUPERVISOR/**`, le workflow projet (`TOOLS/AGENT_WORKFLOW/scripts|skills/**`), le statut de session.

**Hors périmètre (interdit)** : `CODE/**`, `CODE_XML/**`, `PRJ_CODESYS/**`, `.claude/settings*.json` hors ajout de hook justifié, configurations des CLI, transcript T428 (lecture seule).

**Règle de mesure** : un AC n'est `PASS` que si sa vérification nommée a été **exécutée** et sa sortie **consignée** dans `tracking.experiments` du contrat. Une preuve absente = `NOT_TESTED`, jamais `PASS`.

---

## 2. 📊 État des jalons au 2026-11-13

| Jalon | Objet | État | Preuve |
|---|---|---|---|
| F0 | Référence, tests verts | ✅ | 200/200 (`pytest TOOLS/AGENT_SUPERVISOR/tests`) |
| F1 | Continuité pause / reprise / source déplacée | ✅ | `PREUVES/20261109_SESSION_QUALIF_INITIALE/T429_PREUVE_RECETTE_F1_REEL_20261109_v1.0.json` (6/6) |
| F2 | Cycle des constats, cadrage versionné, réévaluation | ✅ | `T429_PREUVE_CAMPAGNE_FR_AB_FINAL_20261109_v1.0.json` (B 10/10, A 9/10) + cycle modèle réel 4/4 |
| F3 | IHM, plugin, « Send to chat » | ✅ auto · ⏳ **2 AC exploitant** | `ui_layout_check.mjs` 1440/390/360 px PASS · plugin 16/16 · deep link PASS |
| F4 | Recette comparée, parcours réels multi-CLI | ✅ corpus · ⚠️ DSH | Codex / Claude / Antigravity PASS ; DSH limité (clé API absente, documenté) |

**Acquis non encore soldés** : `AC-F3.5` (notification bureau, son, toast VS Code, clic vers la bonne carte) et `AC-F3.9` (retour exploitant sur la simplicité) — **observation humaine**, non automatisable.

**Défauts corrigés le 2026-11-13** (chacun avec son garde-fou) :
- perte silencieuse des événements écrits après l'affectation (`_resume_session` + 2 tests)
- réévaluation à la demande sur session en pause (verdict visible en ~2 s + 3 tests)
- résolution proposée rétrogradée en « incertain » sans nouvelle preuve (`apply_reviews`)
- IHM écran étroit : 1ᵉʳ constat hors du premier écran à 360 px (navigation au pictogramme)

---

## 3. 🔧 Reste à faire — chaque ligne a un critère de fin vérifiable

| # | Reste | Critère de fin (`done_when`) | Vérification | Propriétaire |
|---|---|---|---|---|
| **R1** | **AC-F3.5** — notification bureau, son, toast VS Code, clic vers la bonne carte | 1 seule notification + 1 bip + 1 toast ; le clic ouvre la session et la carte visées | observation exploitant consignée dans le contrat (`tracking.experiments`) | **exploitant** |
| **R2** | **AC-F3.9** — retour final sur la simplicité d'usage | verdict « simple / à corriger » + points précis ; correctifs appliqués si « à corriger » | retour consigné ; si correctif : nouveau `ui_layout_check` + `test_ui.mjs` verts | **exploitant + CC01** |
| **R3** | **Famille d'acteur MMX** — l'alias `T429-MMX01` est accepté par le Superviseur (`ALIAS_PATTERN`), le champ catalogue `agent` impose `CC/AGY/CDX/DSH/OPC` | une seule règle : soit la regex catalogue accepte MMX, soit l'alias porte un acteur de la regex — décision tracée et appliquée des deux côtés | `check_task_contract` + tests `connect_session` verts | **agent T000** (lot `T000_SESSION_NAMING` en cours) |
| **R4** | **Test rouge `test_supervisor_summary_exposes_only_rename_title`** | le test passe, soit la sémantique de `session_display_title` est confirmée, soit elle est corrigée | `pytest TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py` → 0 failed | **agent T000** (le changement vient de son lot) |
| **R5** | **Alignement du service 8082** — l'arbre HEAD est en avance du build en service (`71e9a47c851d`, `update_available: true`) | le build servi = HEAD, sauvegarde vérifiée, 7 affectations conservées, 0 constat perdu | `GET /health` → `update_available: false` + diff de l'état avant/après | CC01 (après R4) |
| **R6** | **Push** — 5 commits locaux non poussés (`7f487148`, `cf14f135`, `22535a09`, + à venir) | branche distante à jour, aucun commit perdu | `git rev-list --left-right --count origin/main...HEAD` → `0 0` | **exploitant** (accord explicite requis) |
| **R7** | **Bruit de fond catalogue** — le résumé était figé (PÉRIMÉ) | générateur mécanique en place, résumé À JOUR, contrôle en CI | `python TOOLS/AGENT_WORKFLOW/scripts/generate_tasks_summary.py --check` → 0 | CC01 ✅ **fait le 2026-11-13** |

---

## 4. 🧪 Plan de vérification (état au 2026-11-13)

```powershell
py -3.13 -m pytest TOOLS/AGENT_SUPERVISOR/tests -q                                  # 200 passed
py -3.13 -m pytest TOOLS/AGENT_WORKFLOW/tests/test_rename_session.py `
  TOOLS/AGENT_WORKFLOW/tests/test_statusline_workflow_git.py `
  TOOLS/AGENT_WORKFLOW/tests/test_workflow_state.py `
  TOOLS/AGENT_WORKFLOW/tests/test_tasks_summary_generator.py `
  TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py -q                          # 51 passed / 1 failed (R4)
node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs                                        # PASS
VEILLEUR_UI_DEEP_LINK=1 node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs               # PASS
node TOOLS/AGENT_SUPERVISOR/tests/ui_layout_check.mjs                               # 3 largeurs, 0 échec
cd TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier; npm test                            # 16/16
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/generate_tasks_summary.py --check            # À JOUR
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml
git diff --check && git status --short
```

**Règle** : un lot n'est soldé que si **toutes** ces commandes sont vertes dans le même état de l'arbre ; le cas échéant, la sortie brute est consignée dans le contrat.

---

## 5. 🔒 Décisions figées (ne pas rouvrir sans fait nouveau)

1. **Canal de livraison** : le « Send to chat » passe par le canal natif inter-sessions (relay + vérification post-hoc du transcript), pas par un second processus invisible.
2. **Badge de workflow** : variable binaire — `●` (1, dans le workflow) / `○` (0, sorti). Le hook Stop **constate** (bandeau + pied `➡️ Choix`) mais **ne bloque ni ne commande** (REX 2026-08-23 : pas de blocage pendant le WIP).
3. **Niveau de preuve** : une affirmation sur un test s'accompagne de la **ligne brute** (`1 failed, 29 passed in 8.22s`), jamais d'un résumé chiffré.
4. **Titre de session** : `<alias> · <titre officiel de la tâche> (<désignation>)` — une seule ligne, résolu dans `TASKS.yaml` au renommage.
5. **Règle de conduite** (`AGENTS.md`, Discipline de session ligne 7) : une remarque de l'exploitant ne remplace ni une règle, ni une validation, ni une preuve — elle s'y ajoute.
6. **Écriture catalogue** : uniquement via l'API Task Manager (🔒 de travail + 🚩 d'édition + relecture), jamais par édition directe du YAML.
7. **Commits** : aucun commit ni push sans accord humain explicite ; un push n'est jamais déduit d'un accord de commit.

---

## 6. ⚠️ Limites et risques connus

- **DSH** : collecte réelle bloquée (clé API absente du profil headless) — documenté, pas contourné.
- **Consentement cloud** : le juge utilise `deepseek-v4.1-flash:cloud` avec consentement actif ; le réglage est dans le service, pas dans le dépôt.
- **Concurrence d'agents** : d'autres agents travaillent dans le même checkout (lot T000) — chaque lot ne commite que ses fichiers, et le diff est relu avant commit.
- **Réversibilité** : tout redémarrage du service passe par `upgrade_legacy.py` (sauvegarde vérifiée, jamais supprimée).

---

## 7. 🔗 Index

| Besoin | Emplacement |
|---|---|
| Contrat + preuves + revues A/B | `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml` |
| Rapports de lot | `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/T429_AGENT_SUPERVISOR_RAPPORT_LOT2_CODEX_20261110_v1.0.md` · `..._DOSSIER_PREUVES_AUDIT_20261109_v1.0.md` |
| Preuves JSON | `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/PREUVES/<session>/` |
| Pilotage initial | `DOC/WFLOW/TASKS/T_TEMP (A TRIER)/T429_AGENT_SUPERVISOR_PLAN_REPRISE_TRANSCRIPT_ET_PLUGIN_20261108_v1.0.md` (à trier vers ce dossier) |
| Usage du service | `TOOLS/AGENT_SUPERVISOR/README.md` |
| Catalogue | `DOC/WFLOW/TASKS.yaml` (fiche T429 — 🔒 CC01, ⏳) |
