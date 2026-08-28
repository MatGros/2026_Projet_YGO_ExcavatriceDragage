# 🔬 REX — Harnais STruCpp : VAR_IN_OUT copy-in seul & timeout/num_predict Ollama

> 📌 **Convention de nommage** : `REX_<SujetCourt>_AAAAMMJJ.md`.

**Date** : 2026-08-28
**Auteur / Réf** : DeepSeek (DSH) — tâche T171-A/B, worktree `WT3_TEST_AUTO_CI`
**Statut** : ✅ Résolu & Guarded
**Criticité** : C1 (Diag / outillage CI)

---

## 📋 1. Problème & Symptômes observés

### Incident A — TC-P04-105 échoue alors que le correctif FB est juste
- **Symptôme** : `TC-P04-105 : SampleCount +1 strict sur X13 multi-scan` échoue avec
  `FB.SAMPLECOUNT expected 1, got 0` sur l'assertion du **2e scan** en X13 — alors que
  l'incrément F2 (front `SampleCountDone`) est correct et que le 1er scan passe.
- **Contexte** : harnais WORKING_COPY compilé via STruCpp, exécuté manuellement par g++.
- **Preuve dynamique** (fprintf injecté après chaque `s.FB()`) :
  ```text
  [DBG] SampleCount=0 Done=0   ← call 13 (X11 → transition X13)
  [DBG] SampleCount=1 Done=1   ← call 14 (X13 scan 1 : incrément OK)
  [DBG] SampleCount=0 Done=1   ← call 15 (scan 2 : copy-in ré-écrase à 0 !)
  ASSERT_EQ failed … test_fb_cycle_full.st:827 (assert du 2e scan)
  ```

### Incident B — Audit Ollama qwen3.8:27b : timeout puis réponse tronquée
- **Symptôme 1** : `ollama_subagent.py` échoue `Exécution Ollama : timed out` (2 fois),
  y compris modèle pré-chargé (warm-up OK).
- **Symptôme 2** : après contournement du timeout, réponse coupée en pleine phrase
  (648 chars) — verdict inexploitable.

---

## 🎯 2. Causes racines (Root Causes)

| # | Cause racine | Pourquoi | Détectable comment |
|---|--------------|----------|-------------------|
| A1 | Codegen STruCpp : `VAR_IN_OUT` généré en **copy-in seul** (`s.FB.X = s.X;` avant appel, **pas de copy-out**) alors que CODESYS 3.5 passe le IN_OUT **par référence** | Le harnais passe `SampleCount := SampleCount` (locale jamais mise à jour) → le copy-in du scan suivant ré-écrase l'incrément du FB avec la locale périmée | Générer le C++ et chercher l'absence de copy-out ; tracer la variable après chaque appel |
| A2 | Le même artefact **masque** le défaut F2 sur CODE/ original (NEG-F2 passait à tort) : chaque copy-in ramène 0 → l'original incrémentant à chaque scan repasse à 1 | Symétrie du copy-in : défaut multi-incrément invisible sans copy-out | Test négatif exécuté SANS émulation copy-out → faux PASS |
| B1 | `ollama_subagent.py` : `urlopen(req, timeout=180)` **codé en dur** | 27b local : génération d'un audit structuré > 180 s même à chaud | Compter les tokens/s : ~2-5 tok/s pour 27b |
| B2 | `/api/generate` sans `options.num_predict` → défaut Ollama ~**128 tokens** | Réponse d'audit tronquée silencieusement | Longueur de réponse < longueur attendue, phrase inachevée |
| B3 | `/api/generate` sans `options.num_ctx` → fenêtre ~**4k tokens** : le **prompt** est tronqué en entrée | Prompt d'audit 11.7 KB ≈ 3.5-4.5k tokens → le modèle « ne voit pas » le cahier des charges (il le dit explicitement) | L'auditeur déclare l'absence de spécification fournie alors qu'elle est dans le prompt |

### ❌ Fausses pistes écartées
- *« Le correctif F2 du FB est faux »* — faux : la trace dynamique montre `SampleCount=1 Done=1`
  après le 1er scan X13.
- *« WAITINGRESUME/STARTCYCLE faux dans la trace »* — faux : les valeurs brutes `'1'/'0'`
  étaient correctes ; c'était un cast PowerShell `[bool]"0"` = True dans le script de check.
- *« Ollama est en panne / modèle absent »* — faux : `--list-models` OK, warm-up OK.

---

## 🛠️ 3. Résolution & Correctif appliqué

- **Incident A** (zone `TOOLS/TEST_AUTO_CI/**`) :
  - `WORKING_COPY/tests/test_fb_cycle_full.st` : émulation copy-out après chaque appel
    susceptible de modifier un IN_OUT lu multi-scans :
    ```diff
        SampleCount := SampleCount);
    +   (* Émulation copy-out VAR_IN_OUT : codegen STruCpp = copy-in seul *)
    +   SampleCount := FB.SampleCount;
        ASSERT_TRUE(FB.CycleStep = E_CycleStep.X13_DONE_SYNC, 'X13 atteint');
    ```
  - Même émulation dans `test_fb_cycle_negative.st` (NEG-F2) → le défaut F2 redevient
    **détectable** sur l'original (3/3 ÉCHEC ATTENDU).
- **Incident B** : nouveau wrapper zone TEST_AUTO_CI
  `TOOLS/TEST_AUTO_CI/anim_bench/ollama_query_long.py` — `--timeout` (défaut 900 s),
  `--num-predict` (défaut 2048), `--num-ctx` (défaut 8192), même injection
  `subagent_preamble.md`, zéro quota cloud.

---

## 🛡️ 4. Règle `fix:` + `guard:` (Garde-fou automatique)

- **G-CI-1/G-CI-2** (`run_cycle_tests.py` / `run_negative_tests.py`) : le runner **parse le
  JSON de résultats** et échoue si une assertion échoue — convention copy-out documentée en
  tête du runner (REX 2026-08-28, TC-P04-105).
- **G-CI-3** (`guard_animation_no_business_logic.py`) : étendu avec contrôle de **fraîcheur
  SHA** — HTML == trace JSON **== hash réel de WORKING_COPY/FB_Cycle.st** (chaîne complète
  JSON↔HTML↔sources). Prouvé par négatif (sha falsifié → RC=1).
- **G460** (branchement dans `run_all_gates.py`, palier C) : exécute la chaîne CI complète
  TEST_AUTO_CI (harnais + négatifs + garde). `run_all_gates.py --palier C` → 17/17 PASS.
- **Limitation runner standard documentée** (hors zone, non modifié) :
  `ollama_subagent.py` mériterait `--timeout`/`--num-predict` — à traiter par l'orchestrateur.

---

## 📚 5. Leçons apprises & Bonnes pratiques

1. **IN_OUT multi-scans en harnais STruCpp ⇒ resynchronisation `X := FB.X;` obligatoire**
   après chaque appel modifiant la variable — sinon le copy-in du scan suivant fabrique un
   faux PASS (négatifs) ou un faux FAIL (positifs).
2. **Toujours lire les valeurs BRUTES** avant de conclure sur une trace JSON
   (`'1'/'0'` ≠ booléens PowerShell).
3. **Ollama local lourd** : prévoir warm-up + `num_predict` explicite + timeout long pour
   tout audit structuré ; sinon réponse tronquée = audit invalide.
4. La chaîne de fraîcheur doit couvrir **les trois maillons** : embed HTML, trace JSON,
   source ST — un seul maillon périmé falsifie la représentation.