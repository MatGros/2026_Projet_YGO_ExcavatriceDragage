# 📋 RAPPORT DE LOT — Famille T171 (Animation pilotée par le code compilé)

> **Destinataire** : agent vérificateur externe
> **Auteur** : DSH (agent d'implémentation)
> **Worktree** : `WT3_TEST_AUTO_CI` · Base : `main` @ `19eb9e3a`
> **Périmètre de modification** : `TOOLS/TEST_AUTO_CI/**` uniquement — `CODE/` et `registry.yaml` **intacts**
> **Date** : 2026-08-28

---

## 1 · Ce qui était attendu (cadrage)

La famille **T171** devait produire une **trace scan-par-scan** et une **animation** à partir d'un
**binaire ST compilé réellement exécuté** (`FB_Cycle` via STruCpp), en éradiquant la simulation JS
fictive de l'animation existante.

**Cadrage validé par l'utilisateur (Option 2) :**
- Copier `FB_Cycle.st` dans `TOOLS/TEST_AUTO_CI/WORKING_COPY/`, l'adapter, compiler **cette copie**
  avec un runner isolé. **Aucune modification de `CODE/` ni de `registry.yaml`.**
- **Traçabilité** : la trace/HTML/rapport indiquent `SOURCE_TESTÉE = WORKING_COPY/FB_Cycle.st` + SHA-256.
- **TC-P04-100** prouve le cycle nominal de la copie corrigée (suite verte).
- **T8/F2/F6** prouvent que l'original `CODE/G_CYCLE/FB_Cycle.st` **échoue** (tests négatifs, exclus de la suite verte).
- Correctifs F1/F2/F6 **remontés à l'orchestrateur** comme écarts à réintégrer dans `CODE/`.
- **Aucun résultat T171 ne doit affirmer** que le programme de production est corrigé/sécurisé.
- Séquence `[X0…X11, X13]` (pas de X12) · trace « binaire sous stimuli de harnais » · JSON+HTML versionnés avec SHA-256 croisé · garde-fou JS mécanique.

**3 défauts CODE identifiés (hors périmètre T171, prérequis) :**
- **F1** : X11 — `BucketCmd.Open` évalué avec `Direction=-1` après forçage à `1` (read-before-write) → ouverture jamais commandée.
- **F2** : `SampleCount` incrémenté à CHAQUE scan en X13 (pas de front) → compteur falsifié.
- **F6** : reprise après bascule de mode **automatique** (`WaitingResume` posé mais jamais lu pour couper les commandes) → faille sécurité.

---

## 2 · Ce qui a été fait

### 2.1 Copie de travail + correctifs
- Créé `TOOLS/TEST_AUTO_CI/WORKING_COPY/` avec la fermeture de types complète de `FB_Cycle` (13 sources).
- Corrigé **F1** (X11 : ouverture commandée quand manche défléchi, sortie sur `Benne_Done AND Benne_IsOpen`),
  **F2** (SampleCount cadré par front via `SampleCountDone`, réarmé en X0 et X13),
  **F6** (gate `WaitingResume` réel placé après la détection défaut/abort, reprise sur `StartCycle` uniquement).
- **Audit des correctifs par sous-agent : APPROUVÉ** (après correction d'un défaut F2 : réarmement de `SampleCountDone` en X0).

### 2.2 Harnais étendu
- `WORKING_COPY/tests/test_fb_cycle_full.st` : **TC-P04-100** (cycle complet X0→X13) + **TC-P04-101..104** (robustesse : défaut synchro, bascule mode, relâchement manche, abort).
- **5/5 PASS** sur la copie corrigée (avant ajout des preuves F1/F2).

### 2.3 Trace JSON
- `scripts/generate_trace_cycle.py` → `RESULTS/G_CYCLE/reports/trace_semi_auto_cycle.json`.
- **14 scans**, séquence `CycleStep` X0→X13 ordonnée (sans X12), `SampleCount=1` au scan 13.
- **Provenance** par champ : `COMPILED` / `HARNESS_STIMULUS` / `CONFIG` / `DERIVED`.
- `meta.source = WORKING_COPY/FB_Cycle.st` + `source_sha256` + `sha256` (croisé).
- Contrôle de cohérence commande↔position à la génération.

### 2.4 Animation
- `RESULTS/G_CYCLE/reports/FICHE_SEMI_AUTO_ANIMATION.html` réécrite en **pur lecteur** de la trace.
- Suppression du moteur JS fictif (`STATE`, `simStep`, `executeAutoSequence`, `updatePhysics`).
- `window.__traceScan` exposé · Play/Pause/Vitesse/Scrub · **provenance affichée** (🟢 compilé / 🟡 simulé).

### 2.5 Garde-fou AST
- `scripts/guard_animation_no_business_logic.py` : analyse AST-lite + taint sur les sinks de position.
- **PASS** sur l'animation (0 pattern bloquant, positions dérivées de la trace).

### 2.6 Tests négatifs (en cours)
- `scripts/run_negative_tests.py` + `WORKING_COPY/tests/test_fb_cycle_negative.st` (NEG-F1/F2/F6).
- **NEG-F1 et NEG-F6 échouent** sur l'original (défauts prouvés). **NEG-F2 à corriger** (passe sur l'original — problème de test).

---

## 3 · Ce qui a été proposé (décisions & recommandations)

| # | Point | Proposition |
|---|---|---|
| D1 | F1 (X11) | Corrigé dans la copie ; sémantique « descente ouvre » perdue (ouverture sur toute déflexion) — **à trancher** par l'orchestrateur |
| D2 | F2 (SampleCount) | Corrigé dans la copie (front) ; test d'inflation ajouté |
| D3 | F3 (pas d'analogique pont/benne/mou) | Animation **Phase 1 simple** : états discrets captés ; AC1 réécrit |
| D4 | Déterminisme trace | SHA-256 croisé + comparaison à l'octet |
| D5 | t_ns fictif | Animation indexée par `scan`, ignore `t_ns` |
| D6 | Versionnage JSON+HTML | **Versionné** (décision utilisateur) — conflit de merge visible |
| D7 | Certification zéro-logique-JS | Garde-fou AST + audit Ollama complémentaire |

---

## 4 · Écarts restants (à traiter)

1. **F1/F2 non prouvés** par les tests livrés (TC-P04-100 passerait sur l'original) — preuves en cours d'ajout.
2. **Tests négatifs** sur l'original : NEG-F1/F6 OK, **NEG-F2 à corriger**.
3. **Garde-fou non branché en gate CI** (script manuel uniquement).
4. **Harnais TC-P04-100..104 non intégré au runner standard** (`registry.yaml` pointe toujours vers l'ancien test + `CODE/`).

---

## 5 · Fichiers livrés

| Fichier | Rôle |
|---|---|
| `TOOLS/TEST_AUTO_CI/PLAN_T171_FAMILLE.md` | Plan technique v6 (cadrage + décisions) |
| `TOOLS/TEST_AUTO_CI/WORKING_COPY/CODE/G_CYCLE/FB_Cycle.st` | Copie corrigée F1/F2/F6 |
| `TOOLS/TEST_AUTO_CI/WORKING_COPY/tests/test_fb_cycle_full.st` | Harnais étendu (TC-P04-100..105) |
| `TOOLS/TEST_AUTO_CI/WORKING_COPY/tests/test_fb_cycle_negative.st` | Harnais tests négatifs (NEG-F1/F2/F6) |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/reports/trace_semi_auto_cycle.json` | Trace scan-par-scan (14 scans) |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/reports/FICHE_SEMI_AUTO_ANIMATION.html` | Animation pur lecteur |
| `TOOLS/TEST_AUTO_CI/scripts/generate_trace_cycle.py` | Génération trace + provenance + SHA-256 |
| `TOOLS/TEST_AUTO_CI/scripts/guard_animation_no_business_logic.py` | Garde-fou AST |
| `TOOLS/TEST_AUTO_CI/scripts/run_negative_tests.py` | Runner tests négatifs sur l'original |

---

## 6 · Points d'attention pour le vérificateur

- **`CODE/` et `registry.yaml` intacts** (vérifiable par `git diff --stat -- CODE/`).
- **`.vscode/settings.json` modifié** dans le worktree par un autre acteur (thème VS Code) — **hors périmètre T171**, non touché par l'agent.
- **F1 sémantique** : l'ouverture X11 se fait sur toute déflexion (pas « descente ouvre ») — écart de conception à trancher.
- **F6** : cas limite défaut pendant pause (affichage `PausedState` masquant `STABILIZING`) — cosmétique, sans impact sécurité.
- **`strucpp --test`** échoue dans l'environnement d'exécution (problème d'invocation g++ interne) ; les runners utilisent une **compilation manuelle g++** équivalente.
