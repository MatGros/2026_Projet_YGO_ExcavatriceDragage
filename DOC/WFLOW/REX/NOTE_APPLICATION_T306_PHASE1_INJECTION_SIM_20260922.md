# 📝 Note d'application — T306 Phase 1 : rendre le défaut de rotation de phase injectable

- **Tâche** : T306-PHASE1-INJECTION-SIM-ROTATION-PHASE · criticité C2 (phase 0) / C2 (phase 1 simu)
- **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T306_PHASE1_INJECTION_SIM.yaml` (amendé `ac9aaea2`)
- **Date** : 2026-09-22 · **Agent** : DSH01
- **Objet** : Remplacer le `TRUE` codé en dur de `FB_SimBench.st:690` par un stimulus simulable.

---

## 1. Modifications (strictement dans le périmètre autorisé)

| Fichier | Nature | Preuve |
|---|---|---|
| `CODE/L_SIMULATION/GVL_Simulation.st` | +4 lignes : stimulus `SimPhaseRotationOk : BOOL := TRUE` | après `SimSafetyActive` |
| `CODE/L_SIMULATION/FB_Sim_Safety.st` | +7 : entrée `SimPhaseRotationOkBit` + sortie `SimPhaseRotationOk` (propagation) | interface + gate + corps |
| `CODE/L_SIMULATION/FB_SimBench.st` | +3/-1 : entrée, passage `instSimSafety`, et **`Machine.PhaseRotationOk_DI := instSimSafety.SimPhaseRotationOk`** (remplace `TRUE`) | `:690` |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | +2 : **une seule ligne** `SimPhaseRotationOkBit := GVL_Simulation.SimPhaseRotationOk,` | ~`:334` |
| `TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_sim_safety.st` | +21 (additif pur) : `TC-T306-SAF-003` | autorisation étroite `ac9aaea2` |

## 2. Nom canonique figé

`GVL_Simulation.SimPhaseRotationOk` — TRUE = phases saines, FALSE = défaut injecté.
Aucune variante (`SimPhaseRotationFault`) introduite (2 noms = 2 implémentations — refusé).

## 3. Preuves

### 3.1 G200 — Auto-vérification liaison (collé)
```text
Auto-verification liaison (G200_check_linkage.py) ? PASS
  Linkage check: PASS (0 erreur(s), 1682 avertissement(s), 2052 instance(s) verifiee(s))
```

### 3.2 ROUGE avant / VERT après (par mutation, exigence contractuelle AC5 + garde-fou (c))
- **VERT (injection câblée)** : `TC-T306-SAF-003` PASS + préexistants 2/2 PASS → 3/3.
- **ROUGE (mutation : propagation neutralisée)** : `TC-T306-SAF-003` **FAIL** (`expected FALSE, got TRUE`), préexistants restent PASS → 2/3.
- Restauré → VERT 3/3.

### 3.3 AC8 — additivité du test
`git diff --numstat` sur le test = `21 0` (zéro suppression) ; diff purement additif ; cas préexistants `TC-P13-SAF-001/002` PASS identiques.

### 3.4 Gates Palier C
- G500 Compilation CODESYS : **21/21 PASS**.
- G200 : PASS 0 erreur.
- 4 échecs `G300/G340/G430/G483` = **baseline préexistante** (vérifié, aucune contribution de mes fichiers ; G430 ne liste plus mes commentaires après suppression des références `(T306)`).

### 3.5 Périmètre interdit
`git status --short` sur `CODE/B_AU_SECURITE`, `DOC/AF`, `DOC/STDS`, `PRJ_CODESYS` = **VIDE**.

## 4. Diff bundle
`CODE_XML/CODE_DiffBundle.xml` — 4 objets : `FB_SimBench` · `FB_Sim_Safety` · `GVL_Simulation` · `PRG_02_Acquisition`.
Bundle complet `CODE_XML/CODE_Bundle.xml` frais.

## 5. Collision résolue
La modification AX15D/T383 de `PRG_02` (précédemment non committée) a été **committée dans `0358c631`**. Le diff restant de `PRG_02` = uniquement mon ajout T306 (2 lignes). Aucun écrasement, édition chirurgicale.

## 6. Devoir d'alerte / restants
- Les 2 correctifs de sécurité (SafeStop M3 inerte + gate MAINT_N2 bypass) restent **hors phase 1** — lot C4 séparé à arbitrer.
- G483 (matrice MAINT_N2) rappelle l'écart bypass non gaté **confirmé** en phase 0.
- Essai machine (phase 3, action HUM non délégable) : coupure/inversion phase sur armoire → vérifier arrêt 3 axes, acquittement front, pas de redémarrage auto.
- Aucun commit/push effectué — validation humaine requise.
