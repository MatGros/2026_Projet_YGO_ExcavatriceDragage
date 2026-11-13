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
| **R9** | **Garde de dérive** — hook `PreToolUse` sur `Edit|Write|MultiEdit` : écriture hors périmètre → refus motivé + question à l'exploitant ; une dérogation confirmée est **enregistrée** (durable) | aucune écriture hors périmètre sans dérogation tracée ; le refus force la confirmation au lieu de la recommending | hook testé (chemin autorisé → passe ; hors périmètre → refus ; dérogation → passe) | CC01 (T427) |
| **R10** | **Métrique de dérive** — part des N derniers fichiers touchés qui sont hors périmètre, recalculée depuis le transcript (les chemins y sont dans la trace) | la métrique est **comptée**, pas estimée : aucun avis involved ; elle alimente le constat du Superviseur (preuve citable) et la 2ᵉ ligne de la statusline | métrique recalculée et affichée ; le constat `scope_drift` cite le décompte | CC01 (T427 pour la mesure, T429 pour l'affichage et le constat) |

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
