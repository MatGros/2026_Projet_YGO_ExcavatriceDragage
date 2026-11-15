---
plan_project:
  schema: 1
  task_id: T429
  updated_at: 2026-11-14
  milestones:
    - id: M0
      title: "F0 — Référence et socle de tests verts"
      done_when: "Tests unitaires du Superviseur verts sur l'arbre courant"
      execution: DONE
      execution_by: CC01
      evidence: "DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/PREUVES/ (pytest TOOLS/AGENT_SUPERVISOR/tests : 200 passed)"
      execution_comment: ""
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M1
      title: "F1 — Continuité pause / reprise / source déplacée"
      done_when: "Recette réelle F1 sans perte d'événement ni de constat"
      execution: DONE
      execution_by: CC01
      evidence: "PREUVES/20261109_SESSION_QUALIF_INITIALE/T429_PREUVE_RECETTE_F1_REEL_20261109_v1.0.json (6/6)"
      execution_comment: "Fix _resume_session (événements post-affectation) + 2 tests le 2026-11-13"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M2
      title: "F2 — Cycle des constats, cadrage versionné, réévaluation"
      done_when: "Cycle complet sur session réelle + campagne A/B comparée"
      execution: DONE
      execution_by: CC01
      evidence: "PREUVES/…/T429_PREUVE_CAMPAGNE_FR_AB_FINAL_20261109_v1.0.json (B 10/10, A 9/10) + cycle modèle réel 4/4"
      execution_comment: "Réévaluation à la demande en pause (verdict ~2 s) + 3 tests"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M3
      title: "F3 — IHM, plugin VS Code, « Send to chat »"
      done_when: "Layout PASS aux 3 largeurs, plugin vert, deep link PASS"
      execution: DONE
      execution_by: CC01
      evidence: "ui_layout_check.mjs 1440/390/360 px PASS · plugin 16/16 · deep link PASS"
      execution_comment: "Restent 2 AC observation humaine (AC-F3.5, AC-F3.9 — jalons M7/M8)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M4
      title: "F4 — Recette comparée, parcours réels multi-CLI"
      done_when: "Corpus multi-CLI vert sur parcours réels"
      execution: DONE
      execution_by: CC01
      evidence: "PREUVES/<session>/ (Codex / Claude Code / Antigravity PASS)"
      execution_comment: "DSH limité (clé API absente du profil headless) — documenté, pas contourné"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M5
      title: "Lot dérive — résumé À JOUR + prédicat + garde + métrique (R7→R10)"
      done_when: "generate_tasks_summary --check=0, prédicat testé, hook refus motivé, métrique affichée et citable"
      execution: DONE
      execution_by: CC01
      evidence: "TOOLS/AGENT_WORKFLOW/scripts/task_scope.py + hook_scope_guard.py + tests (13+10+8) + badge 🎯 k/n en statusline"
      execution_comment: "Réparti T427 (mécanique générique) / T429 (affichage + constat citable)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M6
      title: "Visibilité mémoire — panneau lisible + constat autoportant (R11→R12)"
      done_when: "4 groupes mémoire avec extraits dans l'IHM ; chaque constat porte l'inventaire mémoire du verdict"
      execution: DONE
      execution_by: CC01
      evidence: "test_t429_regressions.py (62 tests incl. R11/R12) · snapshot complet exposé"
      execution_comment: ""
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M7
      title: "AC-F3.5 — notification bureau, son, toast, clic"
      done_when: "1 notification + 1 bip + 1 toast ; le clic ouvre la session et la carte visées — observation humaine consignée dans tracking.experiments"
      execution: BLOCKED
      execution_by: ""
      evidence: ""
      execution_comment: "Attente exploitant (observation humaine, non automatisable)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M8
      title: "AC-F3.9 — retour exploitant sur la simplicité d'usage"
      done_when: "Verdict « simple / à corriger » consigné ; correctifs appliqués si « à corriger »"
      execution: BLOCKED
      execution_by: ""
      evidence: ""
      execution_comment: "Attente exploitant + CC01"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M9
      title: "R13+R14 — dossier de lecture déclaré ≠ lecture du dépôt"
      done_when: "Juge reçoit un dossier borné en lecture seule et déclare la liste exacte dans l'argumentaire ; distinction affichée"
      execution: DONE
      execution_by: CC01
      evidence: "reading_dossier() + notice juge + lecture_declaree sur le constat + dossier_lecture dans memory_state + bloc IHM ; tests : test_t429_regressions 65/65 (3 nouveaux), test_dossier_ui.mjs 8 asserts, suite 214 passed, layout 0 failed (2026-11-14)"
      execution_comment: "Budget 6 fichiers / 12 000 car., troncature marquée ; illisible signalé jamais deviné ; corrigé au passage : champ preuves affiché undefined (clé prouves_acquises) ; v1 sans boucle d'agent"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M10
      title: "R15 — personas journalisées et visibles"
      done_when: "Chaque invocation de specialist_runner est journalisée (rôle, cible, session) et affichée"
      execution: DONE
      execution_by: CC01
      evidence: "Défaut réel prouvé (probe traceback : NameError Path → except muet, 0 jamais journalisé) ; fix runner + stderr non muet + role=args.role or args.show_prompt ; test persistant subprocess → persona_usage ; suite AG 215 passed ; runs réels 2 entrées seq=1/2 (2026-11-14)"
      execution_comment: "Reste à l'exploitant : KINDS += \"persona\" dans trace_log.py (deny-list, garde a refusé l'écriture) pour la lecture CLI --kind persona ; affichage IHM déjà posé (fold mémoire)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M11
      title: "R3+R4 — famille d'acteur MMX et test rouge renommage"
      done_when: "Une seule règle d'alias tracée des deux côtés ; test_supervisor_summary_exposes_only_rename_title vert"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: "Fait nouveau 2026-11-14 : R4 vert (test_session_statusline 8 passed, était 1 failed) — prérequis de R5 levé ; R3 (décision MMX) reste chez l'agent T000 (lot T000_SESSION_NAMING)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M12
      title: "R5 — alignement du service 8082 sur HEAD"
      done_when: "GET /health → update_available: false, sauvegarde vérifiée, 7 affectations conservées, 0 constat perdu"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: "Coordination 2026-11-15 (T000-CC10) : son lot 2 (supervisor_server.py, request_queue_size 5→128, cause racine du faux « Offline », prouvé : file 5 → plafond 0,51 s sous 12 appels, file 128 → 0/300) attend la même dérogation et exige un redémarrage — accord : appliquer le lot 2 AVANT le restart R5, UN seul redémarrage. En attente de la dérogation + GO exploitant. Cible mise à jour : un redémarrage, deux vérifications (R5 + lot 2)"
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M13
      title: "R6 — push des commits locaux"
      done_when: "git rev-list --left-right --count origin/main...HEAD → 0 0"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: "Accord humain explicite requis (jamais déduit d'un accord de commit)"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M14
      title: "R16 — Menu de gauche : couleur d'état sur l'indicateur, texte neutre, identifiant d'agent coloré"
      done_when: "Titre de session neutre même en alarme ; état sur marqueur/fond/étiquette ; badge d'agent coloré par standard (claude/codex/agy/dsh/opc)"
      execution: DONE
      execution_by: CC01
      evidence: "CSS : titre neutre var(--text) + has-* color var(--text) + marker par état (vert/orange/rouge/gris) + .model-tag standard 5 acteurs ; JS : badge model-tag + metaRow ; test_dossier_ui.mjs 16 asserts, test_ui.mjs PASS, layout 0 fail (2026-11-14)"
      execution_comment: "2 amendements exploitant le jour même (checkpoint 5f895090) : texte colore SEUL (badge encadre illisible supprime) + couleur portee par la FAMILLE detectee dans l alias (T429-MMX01 -> MMX jaune), la couleur suivra l acteur meme en changeant de terminal"
    - id: M15
      title: "R17 — Le Superviseur reconnaît une session orchestrateur et adapte sa vigilance"
      done_when: "Détection mécanique du rôle coordination (alias/tâche T000-CCxx) ; notice dédiée au juge avec les critères de gestion (verrou, écriture hors contrat, clôture de constat par l'agent interdite) ; alerte mécanique si DEUX orchestrateurs actifs simultanés"
      execution: DONE
      execution_by: CC01
      evidence: "commit 9ad9e447 : is_coordination_session + notice COORDINATION_JUDGE_NOTICE + _detect_coordination_conflicts idempotent ; tests 217 py verts (test_coordination_session_judge_notice_only_for_t000, test_two_active_coordination_sessions_raise_one_finding) ; handoff T427-CC02 transmis + accusé (d2878f46/b5ed67ec)"
      execution_comment: "Fait prouvé 2026-11-15 : zéro notion orchestrateur dans service + vigilance (grep) — le juge l'évalue comme toute session ; demande exploitant 2026-11-14"
    - id: M16
      title: "R18 — le système dit une session qui travaille sans objectif ni critères"
      done_when: "Constat mécanique mission_non_cadree aux coordinations à fiche vide ; état cadrage_state pour les autres ; corrigé observé quand rempli ; clôture humaine"
      execution: DONE
      execution_by: CC01
      evidence: "mission_cadrage_missing + _detect_mission_cadrage au cycle de poll ; 2 tests verts (ciblage coordination + révision partielle) ; suite 0 failed au dernier run ; design scopré après 17 échecs de v1 (constat global = bruit), robustesse M1 (la détection ne tue jamais le cycle de collecte)"
      execution_comment: "Écart exploitant 2026-11-15 (cas T000-CDX02) ; 3 champs minimum = note T427 ; flakiness intermittente notée sur 2 tests (solo toujours verts) à surveiller"
    - id: M17
      title: "R19 — recette de dérive réelle avec agents Ollama"
      done_when: "Refus du garde + métrique k/n comptée + constat scope_drift citable du Superviseur, consignés dans PREUVES"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: "GO conditionnel exploitant 2026-11-15 (agents Ollama) ; l'écriture hors périmètre volontaire attend un GO explicite ; protocole en 3 pas au plan §3 (R19)"
    - id: M18
      title: "R20 — reprise CC10 : robustesse upgrade_legacy (journal horodaté, délais 15/30, kill ciblé)"
      done_when: "Journal horodaté des étapes, timeouts 15 s (GET) / 30 s (POST), arrêt refusé de tout processus qui n'est pas supervisor_server.py ; test_upgrade 5/5"
      execution: DONE
      execution_by: T000-CC10 (relu et vérifié par CC01)
      evidence: "diff WT 29/6 relu par CC01 ; test_upgrade.py 5 passed (réexécuté 2026-11-15) ; le kill refuse tout processus non-Superviseur sur 8082"
      execution_comment: "Reprise demandée par l'exploitant via CC10 ; le COMMIT attend la décision CC01 + le GO exploitant (CC10 n'écrit plus dans le Superviseur)"
    - id: M19
      title: "R21 — statut de migration visible dans l'IHM (proposition T000-CC10 acceptée)"
      done_when: "AC-1→AC-6 de la proposition : bandeau IHM (en cours/étape/cause/backup), aucun changement de format d'état, migration jamais lancée sans GO"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: "Proposition DOC/WFLOW/TASKS/T000-CC10_PROPOSITION_STATUT_MIGRATION_IHM/ acceptée par CC01 — constat réel, AC testables ; à trancher §6 (canal HTTP avec jeton vs fichier d'état, statut expiré 24 h) ; lot 1 déjà fait par M18 ; implémentation après le restart M12"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
---

<!-- markdownlint-disable MD025 -->
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
| **R8** | **Prédicat de périmètre** — le périmètre d'une tâche devient une donnée (ensemble de chemins autorisés, déduit du contrat `scope.allowed`), pas une phrase dans un prompt | un prédicat booléen, testable, sans LLM : `chemin ∈ périmètre` ; T429 sert de cas d'école | tests unitaires du prédicat (inclus / exclu / chemin voisin) | CC01 (T427) |
| **R9** | **Garde de dérive** — hook `PreToolUse` sur `Edit\|Write\|MultiEdit` : écriture hors périmètre → refus motivé + question à l'exploitant ; une dérogation confirmée est **enregistrée** (durable) | aucune écriture hors périmètre sans dérogation tracée ; le refus force la confirmation au lieu de la recommending | hook testé (chemin autorisé → passe ; hors périmètre → refus ; dérogation → passe) | CC01 (T427) |
| **R10** | **Métrique de dérive** — part des N derniers fichiers touchés qui sont hors périmètre, recalculée depuis le transcript (les chemins y sont dans la trace) | la métrique est **comptée**, pas estimée : aucun avis involved ; elle alimente le constat du Superviseur (preuve citable) et la 2ᵉ ligne de la statusline | métrique recalculée et affichée ; le constat `scope_drift` cite le décompte | CC01 (T427 pour la mesure, T429 pour l'affichage et le constat) |
| **R11** | **Panneau Mémoire lisible** — les 4 groupes (fenêtre / longue / journal / preuves) avec leur contenu, pas seulement leurs compteurs | l'exploitant voit d'un coup d'œil ce que le juge voit et ce qu'il ne voit plus | test DOM (4 groupes + extraits) · layout 0 échec | CC01 (T429) |
| **R12** | **Constat autoportant** — chaque constat porte l'inventaire mémoire du moment du verdict + la provenance de sa preuve | un constat relu plus tard donne son contexte sans rouvrir le transcript | test (inventaire cohérent avec la fenêtre) · affichage | CC01 (T429) |
| **R13** | **Lectures déclarées** — dossier de lecture borné, lecture seule, la liste est déclarée dans l'argumentaire | aucune lecture non déclarée ; fichier illisible signalé, jamais deviné | test (dossier joint, déclaration exacte) | CC01 (T429) |
| **R14** | **Dossier de lecture ≠ lecture du dépôt** — les deux notions sont distinguées partout | aucune confusion dans l'affichage ni dans le journal | test DOM | CC01 (T429) |
| **R15** | **Personas tracées** — chaque invocation de spécialiste est journalisée et visible | l'usage des 6 personas devient un fait | test (entrée journalisée) · affichage | CC01 (T429) |

---

## 3bis. 🛡️ Garde de dérive — conception retenue (R8 → R10)

**Pourquoi ce lot existe** : le 2026-11-13, en phase CADRAGE sur T429, l'agent a dérivé vers le statut de session, une règle de conduite et un générateur de résumé — **sans que le Superviseur ne signale quoi que ce soit**. Diagnostic : le Superviseur **ne peut pas** voir une dérive de longue durée (fenêtre de 12 messages, cap sans périmètre, jugement probabiliste). Une dérive se prouve par des **chemins de fichiers**, pas par une impression.

**Principe : remplacer les promesses par des preuves.** Une consigne (prompt, skill) est probabiliste ; un prédicat calculé sur la trace est **infaillible**.

| Brique | Mécanisme | Dépend de ma bonne volonté ? | Effet |
|---|---|---|---|
| **Prédicat** (R8) | ensemble de chemins autorisés, déduit du contrat `scope.allowed` ; test booléen `chemin ∈ périmètre` | non | le périmètre devient une donnée |
| **Garde** (R9) | hook `PreToolUse` sur `Edit\|Write\|MultiEdit` : hors périmètre → refus motivé ; la confirmation de l'exploitant est enregistrée (dérogation durable) | non (exécuté par le harnais) | rend la règle « une remarque n'est pas un ordre » **opposable** |
| **Métrique** (R10) | part des N derniers fichiers touchés hors périmètre, **comptée** depuis le transcript | non | rend la dérive visible et citable ; alimente le constat du Superviseur |
| **Visibilité** (R10) | 2ᵉ ligne de la statusline : `🎯 k/N sur périmètre` | — | tu vois la dérive avant qu'elle ne coûte une demi-journée |
| **Juge LLM** | `scope_drift` sémantique (dérive *dans* le périmètre) | partiellement | complément qualitatif, jamais la preuve |

**Règle de phase, rendue mesurable** : « la phase CADRAGE est dédiée à 90 % à la tâche attribuée » devient `part des tours sur périmètre / tours totaux` — chiffrée, donc discutable, et non un slogan.

**Répartition en 3 lots** (aucun lot supplémentaire) :
- **T427** (workflow) : prédicat + hook + dérogations + métrique → générique
- **T429** (Superviseur) : affichage de la métrique + constat de dérive **citable** (« 7 des 9 derniers fichiers touchés sont hors périmètre ») au lieu d'un avis
- **T431** (collège d'experts) : le collège mixte (Claude Code + DeepSeek + GLM + spécialistes) consomme les **motifs déjà extraits** par la métrique — pas des logs bruts → classification des dérives récurrentes → contre-mesures

**Limites assumées** : `Bash` peut écrire hors périmètre sans que le hook voie le chemin (la commande est analysée, pas les fichiers) → c'est la **métrique** qui prend le relais, elle voit la commande. Une dérive *à l'intérieur* du périmètre (mauvaise sous-tâche) reste au ressort du juge sémantique.

**Décisions à prendre avant l'écriture** : seuil d'alerte (part hors périmètre) · comportement face à une écriture hors périmètre (refus net, ou refus + proposition) · portée du périmètre (strict `scope.allowed`, ou élargi `DOC/WFLOW/**` pour la doc de tâche) · lot porteur (T427 seul, ou T427 + T429 + T431).

---

## 3ter. 🔎 Analyse des manquements du Superviseur (échange T427-CC02 du 2026-11-13)

**Constat tête** : pendant cette session, le Superviseur était en `source_error` → **il n'observait plus rien**, et la dérive (sortie de workflow, arrêt inutile, rôle inventé, attribution inventée) est passée sans que personne ne la voie. **Un observateur muet est le pire mode de défaillance** : il donne l'illusion d'une surveillance.

| # | Signature observée | Détecteur | Contre-mesure |
|---|---|---|---|
| M1 | 🔇 Superviseur en `source_error`/arrêt alors que la session est active | mécanique : état du service | impossible de clore un tour avec le Superviseur en erreur ; la barre l'annonce en clair (pas de « ? ») |
| M2 | 🧭 « WORKFLOW ACTIF » alors que le *début* du workflow n'a pas eu lieu (ni socle, ni ligne d'étape, ni voie) | mécanique : attestation d'**entrée** (bandeau + voie + phrase de rôle) | la barre affiche « déclaré, non entré » ; aucun auto-attribution de rôle |
| M3 | ⛔ Arrêt inutile : validation demandée pour un élément *dans* le périmètre | le bloc d'entrée porte périmètre + « GO seulement pour CODE/, catalogue, hors périmètre » | rôle et périmètre connus **dès l'entrée** |
| M4 | 🎭 Rôle inventé (« je suis responsable de T427 ») alors que le workflow n'était pas démarré | juge : cohérence des affirmations de rôle avec l'état | l'assertion de rôle est **ancrée** dans l'état, pas dans le catalogue |
| M5 | 🗣️ Attente annoncée puis action (« je ne modifie rien tant que tu ne dis pas fais » → il modifie) | mécanique : message précédent contient une attente + le tour suivant écrit | refus de clore le tour (Stop) si l'attente est violée |
| M6 | 📌 Attribution inventée (« je n'ai rien à annuler » — l'exploitant ne l'a pas dit) | juge : contradiction avec le transcript | constat `contradiction` ancré |
| M7 | 🔄 Cause affirmée sans preuve (« état mis en cache / lecture échouée ») | la cause se vérifie (taille du transcript, dernière écriture) | cause **prouvée** ou étiquetée hypothèse |
| M8 | 🗂️ Handoff orphelin : point écrit « transmis à T429 » dans le plan de T427 → invisible pour T429 | scan des plans | le point apparaît dans la **fiche T429** |
| M9 | 🔒 Pas de chemin de transfert de verrou (« je ne peux pas écrire là-dessus ») | procédure manquante | transfert de verrou = opération de 1ʳᵉ classe (API release + acquire) |

**Cas similaires à ne pas louper** : Superviseur arrêté mais session active · watchdog cassé puis reprise · double affectation sur une même session · dérogation de périmètre non tracée · point écrit dans le mauvais dossier de tâche · affirmation de rôle après une reprise de session · correction faite sans rejouer la preuve.

### 🧠 Le journal de manquements (« remise en question »)

À chaque tour, les mécanismes de surveillance consignent **ce qu'ils auraient dû dire** : signature, preuve, moment, session. Ce journal est un **corpus machine**, pas un rapport rédigé : il alimente la revue périodique et donc la mise à jour des règles (prompts, `AGENTS.md`, détecteurs). Il s'appuie sur :
- l'**attestation** du hook Stop (bandeau, pied, entrée du workflow) ;
- le **journal des écritures** du hook de périmètre (ce qui a été touché, et où) ;
- l'**état du Superviseur** (muet / en erreur / actif).

Production : hooks (mécanique, déterministe). Consommation : revue périodique + **T431** (« audits asynchrones, mémoire sourcée ») qui transforme les manquements récurrents en contre-mesures.

---

> 📌 **Les écarts du point d'entrée `/workflow-project`** (socle non proposé, lecture non prouvée, voie effacée, 3 champs non remplis…) sont consignés dans la note dédiée : `T429_AGENT_SUPERVISOR_NOTE_WORKFLOW_POINT_ENTREE_20261113_v1.0.md` → à traiter par la tâche qui porte le workflow (T427).

## 3quater. 👁️ Ce que le Superviseur montre, ce qu'il lit, ce qu'il déclare

**Constat de l'exploitant (2026-11-13)** : la mémoire du Superviseur n'était pas lisible (fenêtre = **6 messages sur 3 000+ observés**, mémoire longue / journal / preuves invisibles), l'argumentaire d'un constat ne disait pas **quelles données venaient de quelle mémoire**, le Superviseur ne pouvait **lire aucun fichier du dépôt**, et les **agents spécialisés n'étaient pas tracés** — donc inexploitables en surveillance.

**Principe retenu** : *ce que le Superviseur utilise est montré ; ce qu'il lit est déclaré ; ce qu'il ne fait pas est écrit.*

| # | Reste | Contenu | Critère de fin vérifiable | Propriétaire |
|---|---|---|---|---|
| **R11** | **Panneau Mémoire lisible d'un coup d'œil** | 4 groupes séparés dans l'IHM : **Fenêtre** (ce que le juge voit maintenant) · **Mémoire longue** (hors fenêtre) · **Journal d'état** · **Preuves acquises** ; chaque groupe avec son compteur et ses **extraits** (rôle, index d'événement, horodatage, texte). Ligne de tête : fenêtre tronquée oui/non, règle du juge (N messages), événements écartés | à l'ouverture d'une session, l'exploitant voit les 4 groupes **et** le contenu de la fenêtre sans clic supplémentaire | test DOM (4 groupes + extraits présents) · `ui_layout_check` 0 échec |
| **R12** | **Constat autoportant : ce que le juge avait sous les yeux** | chaque constat porte `memory_usage` : inventaire **au moment du verdict** (fenêtre n, longue n, journal n, preuves n, cadrage n, tronquée oui/non) + les identifiants des éléments disponibles + la provenance de **sa** preuve | un constat relu des mois plus tard indique son contexte exact sans rouvrir le transcript | test : `memory_usage` non vide et cohérent avec la fenêtre du moment · affichage DOM sous le constat |
| **R13** | **Le Superviseur ne lit rien sans le dire** | v1 : le juge reçoit un **dossier de lecture** borné (contrat + plan de la tâche + fichiers cités par les constats ouverts), **lecture seule**, et **déclare** la liste dans l'argumentaire (`lecture_declaree`). Pas de boucle d'agent en v1 ; budget ≤ 6 fichiers et ≤ 12 000 caractères | chaque constat porte la liste exacte des fichiers lus ; un fichier illisible est **signalé**, jamais deviné | test : dossier joint, déclaration exacte, fichier illisible signalé · journal interne : la lecture est consignée |
| **R14** | **Dossier de lecture ≠ lecture du dépôt** | distinction explicite dans l'IHM et dans l'argumentaire : « dossier de lecture (fourni au juge) » vs « accès direct au dépôt (interdit en v1) » | aucune confusion possible dans l'affichage ni dans le journal | test DOM (les deux libellés distincts) |
| **R15** | **Les agents deviennent tracables** | chaque invocation de `specialist_runner.py` est journalisée (rôle, cible, session) → l'IHM affiche « spécialistes invoquées : HMI 2 · tests 1 » ou « aucune invocation ». Le Superviseur pourra **réclamer** un avis de spécialiste (v2), déclaré comme les lectures | l'usage réel des 6 personas devient un fait ; la question « pourquoi on les a faits » a une réponse factuelle | test : une invocation produit une entrée journalisée · affichage IHM |
| **R16** | **Menu de gauche — la couleur porte l'état, pas le texte** (demande exploitant 2026-11-14) | le titre de session reste neutre (blanc) même en alarme ; l'état vit sur le marqueur + fond discret + étiquette (info active/défaut/alarme) ; l'identifiant d'agent = badge coloré selon un standard par acteur (claude/codex/agy/dsh/opc) | test DOM (badge model-tag + neutralisation texte) · layout 0 échec | CC01 (T429) |
| **R18** | **Le système doit DIRE une session qui travaille sans objectif ni critères** (écart exploitant 2026-11-15, cas T000-CDX02) | constat mécanique `mission_non_cadree` posé aux sessions de coordination à fiche vide (3 champs minimum : objectif/critères/périmètre) ; pour toute autre session active, état lisible `cadrage_state` sans envahir les constats ; corrigé observé quand rempli, clôture humaine | tests cadrage (ciblage coordination, idempotent, révision partielle, pausé) · suite 219 verts | CC01 (T429) |
| **R19** | **Recette de dérive RÉELLE avec agents Ollama** (GO conditionnel exploitant 2026-11-15 ; lesson PRG_10 : tests verts ≠ câblé) | l'agent Ollama rédige une écriture hors périmètre (contenu fourni dans son prompt, il ne lit jamais le code) ; l'écriture volontaire déclenche le garde (refus + journal + métrique `k/n`) ; le Superviseur publie le constat `scope_drift` citable sur la session surveillée ; le tout consigné dans PREUVES/ | preuve brute : refus du garde + métrique comptée + constat cité dans PREUVES | CC01 (T429), GO explicite de l'écriture volontaire requis |
| **R20** | **upgrade_legacy robuste** (reprise CC10 demandée par l'exploitant) | journal horodaté par étape, délais 15 s (GET) / 30 s (POST), **kill ciblé** : un processus sur 8082 n'est arrêté que s'il est `supervisor_server.py`, sinon refus | `test_upgrade.py` 5 passed (réexécuté CC01 2026-11-15) | T000-CC10 → repris CC01 (T429) |
| **R21** | **Statut de migration visible dans l'IHM** (proposition T000-CC10 acceptée, cas « Migration interrompue : timed out » invisible) | bandeau IHM : état `en cours/réussie/échec`, étape courante, cause, chemin de sauvegarde — sans changement de format d'état, migration jamais lancée sans GO (AC-1→AC-6 de la proposition) | tests upgrade + bandeau DOM ; à trancher §6 : canal HTTP avec jeton vs fichier d'état, statut expiré 24 h | CC01 (T429), implémentation après le restart M12 |

### Décisions figées sur ce lot

- **v1 = lecture seule, bornée, sans boucle d'agent.** Le dossier de lecture est fourni en une passe ; la boucle « le juge demande un fichier, le service le lit, le juge re-juge » est **hors v1** (à chiffrer avant).
- Les **personas restent déclenchés** par l'agent ou l'exploitant — mais **tracés** (R15) avant d'être **branchés** sur le Superviseur.
- La **mémoire longue reste exposée et invalidable, pas signée** (signature = T431).

---

## 3quints. 🧭 Handoff → 🐋 T427-CC02 (2026-11-15, GO exploitant)

> Transmission réelle faite le 2026-11-15 par le canal inter-sessions (désignation explicite de
> l'exploitant) ; M15/R17 livré côté service (commit `9ad9e447`, 217 tests verts). La canonique
> orchestrateur revient au lot T427. Piège M8 évité : le texte exact est consigné **ici**, dans
> le dossier T429, et T427-CC02 a été informé de son emplacement.

**Accusé T427-CC02 (2026-11-15)** : section prévue dans `skills/orchestrator/SKILL.md`, placée
**après leur sous-section « Échange avec les autres sessions », avant « Rôle & Objectifs »** ;
lot orchestrateur : secours 1bis/3 + veille 5bis intégrés (non commité), dérogation enregistrée
pour le fichier ; **en attente du GO de l'exploitant ou de T000-CC10**, puis relecture du texte
au diff. Le GO de pose n'appartient PAS à T429 : il revient à l'exploitant.

**Ce que T429 a posé (service Superviseur)** : détection mécanique (alias `T000-*` ou tâche T000) ·
notice au juge avec les 5 critères de gestion · constat mécanique idempotent `coordination_conflict`
si deux sessions coordination actives.

**Texte exact à poser dans `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md`**
(deny-list agent → pose humaine ou via T000-CC10, puis relecture au diff par T427) :

```markdown
## 🧭 Identité de coordination & surveillance du Superviseur

> Finalisée le 2026-11-15 (T429 M15/R17, GO exploitant le jour même). La détection mécanique du
> Superviseur et les critères passés à son juge s'ancrent sur cette section — le rôle coordination
> ne se devine pas depuis une mission.

- **Un seul coordinateur désigné à la fois** : la session de coordination porte un alias `T000-CCxx`
  (ex. `T000-CC10`). Deux sessions `T000-*` **actives** simultanément = conflit de coordination : le
  Superviseur lève un constat mécanique (`coordination_conflict`) sur chacune, jusqu'à remise explicite
  d'un périmètre.
- **Détection mécanique** : alias commençant par `T000-` (ou tâche liée `T000`) → la session est
  marquée coordination ; le juge du Superviseur reçoit explicitement les critères de gestion.
- **Critères passés au juge** (cités du canonique, pas recopiés) : règle d'or (validation avant
  implémentation) · verrou d'écriture / 🚩 d'un autre acteur jamais contournés · une fiche de tâche
  modifiée uniquement par le coordinateur désigné via l'API Task Manager · clôture de constat ou
  tâche jamais par l'agent (règle 10 `AGENTS.md`) · `git diff` réel lu par le coordinateur, un
  rapport d'agent n'est jamais une preuve · aucun commit ni push sans accord humain explicite.
- **Limite assumée** : le Superviseur juge, il ne remplace ni le Task Manager ni la désignation
  humaine ; une session `T000-*` en pause ou arrêtée ne compte pas dans le conflit (seules les
  sessions enabled + active).
```

**À l'exploitant, même geste** : ajouter `"persona"` à `KINDS` dans `TOOLS/AGENT_WORKFLOW/scripts/trace_log.py`
(lecture CLI du journal personas ; refus deny-list tracé au tour 2026-11-14).

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
8. **Dérive** : elle se **prouve** par les chemins touchés (comptés depuis la trace), elle ne se discute pas au jugé. Une consigne ne remplace pas une preuve ; le périmètre est une donnée, pas une phrase.

---

## 6. ⚠️ Limites et risques connus

- **DSH** : collecte réelle bloquée (clé API absente du profil headless) — documenté, pas contourné.
- **Consentement cloud** : le juge utilise `deepseek-v4.1-flash:cloud` avec consentement actif ; le réglage est dans le service, pas dans le dépôt.
- **Concurrence d'agents** : d'autres agents travaillent dans le même checkout (lot T000) — chaque lot ne commite que ses fichiers, et le diff est relu avant commit.
- **Dérive non détectable par le hook** : une écriture faite par `Bash` échappe au refus `PreToolUse` ; seule la métrique (qui lit la trace) la voit. La garantie est donc « quasi » sur l'action et « exacte » sur la détection.
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
