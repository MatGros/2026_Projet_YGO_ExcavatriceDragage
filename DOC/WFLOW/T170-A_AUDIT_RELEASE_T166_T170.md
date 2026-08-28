# T170-A — Audit de release & bilan de cohérence (lot T166 → T170)

> Audit orchestrateur au commit `65effcf4`. **La release n'est PAS gelée** — blocages listés §4.

---

## 1. État réel des familles

| Famille | Objet | État vérifié |
|---|---|---|
| **T166** (A/B/C/DOC/CR) | Centralisation cycles & assistants dans PRG_03, décharge PRG_04 | ✅ committé. Relecture diff `7e65e566`/`0a94ff56`/`cc960fbd` faite : architecture producteur-unique correcte (PRG_03 → `Data.SequenceState` → PRG_07 → `GVL_IHM`). 1 écart mineur (`SpeedMismatchConfirmed` non neutralisé en DISABLE) → **corrigé** `65effcf4`. |
| **T166-FIX / R1..R3ter** | Compilabilité PRG_04, `ErrorId` conditionnel, `OperatorCoupledIntent` (producteur unique) | ✅ committé, relu ligne à ligne, CODESYS 3.5 compile OK (confirmé humain). |
| **T167-A** | Spec AF-04 §3bis : dérivations timeout runtime, matrice état sûr, gel bypass Kobold | ✅ figé (itéré 4×). Watchdog benne corrigé (60 s réel, pas 6 s). |
| **T167-B** | `FB_DiveSearch` : timers de garde runtime, `StepAtFault`, latch survivant Enable, garde-fou non-redémarrage | ✅ code + 7/7 tests + CODESYS OK. **Contrat `IN_REVIEW`** — visa humain final non posé. |
| **T167-C** | `FB_ExtractionSequence` : backstop fermeture benne verrouillé > `BucketMoveTimeout`, timeout décollage runtime, `StepAtFault` | ✅ code + 6/6 tests + CODESYS OK. **Contrat `IN_REVIEW`**. |
| **T167-CR** | Revue indépendante Ollama, par brique | ⏳ **DiveSearch fait** (MAJEUR = faux positif prouvé + garde-fou défense en profondeur). **Extraction : serveur Ollama en timeout ×4 → revue orchestrateur substituée, à rejouer.** |
| **T168-A** | DumpAtTremie : décision PRG_03 / muscle PRG_04 | ✅ relu, correct (gate mode devient structurel via la branche). |
| **T168-B** | Projection diagnostic unique PRG_07 + `StepAtFault` assistants jusqu'à `FB_TroubleshootingView` (`Idx208`/`Idx307`) | ✅ complété `75ceba26`. |
| **T168-CR** | Revue Ollama diagnostic | ⚠️ marquée ✅ par agent précédent — **non re-vérifiée** après ajout `StepAtFault` assistants. |
| **T169-A** | Campagne CI scénarios dragage (nominal / limites / dégradés) | ⏳ **partielle**. Couverts par les TC ajoutés en T167-B/C : perte Kobold → timeout, benne bloquée → backstop, homme-mort → latch, non-redémarrage. **Non couverts** : changement de mode en cours de cycle, coupure puissance en cours, rupture synchro M1/M2 (scénarios end-to-end). |

## 2. Mécaniques (commit `65effcf4`)

| Contrôle | Résultat |
|---|---|
| `G200_check_linkage` | **PASS** (0 erreur, 1367 instances) |
| `run_all_gates` (TOUT) | **PASS** (tous paliers) |
| Tests STruCpp par FB (séquentiel) | FB_DiveSearch 7/7 · FB_ExtractionSequence 6/6 · FB_Cycle 7/7 · PRG_03 5/5 · PRG_07 3/3 · FB_Winch 3/3 · FB_Bucket 2/2 · FB_Translation 3/3 |
| CODESYS 3.5 | Compilation OK (confirmé humain) |

## 3. Guard-fou identifié (fix + guard)

**`run_tests.py --all` non déterministe sous Windows** : `WinError 193` / `WinError 32` (verrou binaire g++ en exécution parallèle) — 5 FB « FAIL » en mode `--all`, tous **PASS en séquentiel**. La « 27/27 PASS » du contrat T169-A n'est donc **pas fiable** telle quelle.
- **fix** : lancer le harnais en séquentiel (`--fb` un par un) pour toute validation de release.
- **guard** : à ajouter dans `TOOLS/TEST_AUTO_CI/` — sérialiser la compilation g++ (`--jobs 1` par défaut) ou retry sur `WinError 193/32`. **Tâche outillage dédiée à ouvrir**.

## 4. Blocages avant gel de release

1. **T167-CR Extraction** : revue Ollama indépendante non aboutie (serveur). À rejouer.
2. **T167-B / T167-C** : contrats `IN_REVIEW` — visa humain final à poser (CODESYS OK acquis).
3. **T168-CR** : re-vérifier après ajout `StepAtFault` assistants.
4. **T169-A** : compléter les 3 scénarios end-to-end manquants (mode / puissance / synchro).
5. **Guard-fou CI `--all`** : ouvrir la tâche outillage.

**T170 reste `⏳`.** Gel possible une fois 1–4 levés (5 en parallèle, non bloquant fonctionnel).
