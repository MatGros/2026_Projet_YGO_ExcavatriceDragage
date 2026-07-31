# 🗂️ Registre de traçabilité Fonction ↔ Test critique

> Source unique de vérité : **quelle fonction métier a quels tests de non-régression, et où.**
> Contrôlé automatiquement par `check_test_registry.py` (gate, voir §Vérification).
> Ne pas dupliquer cette table ailleurs — un lien mort ou périmé casse le gate.

## Comment lire cette table

| Colonne | Sens |
|---|---|
| **Fonction** | Nom du POU/domaine métier réel (`CODE/...`) |
| **TC** | Identifiant test critique (référence AF, ex. `TC-P01-003`) — `AUTO` si test outillage sans TC métier |
| **Test Python** | Fichier + fonction exacte dans `TOOLS/OUTILS_ST2PY/RESULTS/<DOMAINE>/tests/` |
| **Statut** | 🟢 actif · 🟡 en migration · ⚫ retiré (historique, ne pas supprimer la ligne) |

---

## AU — FB_Safety_EmergencyManagement (P01)

| Fonction | TC | Test Python | Statut |
|---|---|---|---|
| Séquence d'armement nominale | TC-P01-003 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_003_arming_sequence_nominal` | actif |
| Reset jamais conditionné (REX 2026-08) | TC-P01-004 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_004_reset_never_conditioned` | actif |
| Échec auto-test redondance A/B | TC-P01-006 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_006_redundancy_test_failure` | actif |
| Timeout confirmation + lockout 5s | TC-P01-007 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_007_lockout_after_confirmation_timeout` | actif |
| Coupure sécurité métier | TC-P01-008 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_008_safety_power_cutoff_request` | actif |
| Re-latch après acquittement prématuré | TC-P01-009 | `RESULTS/AU/tests/test_emergency_behavior.py::test_tc_p01_009_relatch_after_premature_ack` | actif |

## TRANSLATION — FB_Translation / FB_Safety_Translation (P12)

| Fonction | TC | Test Python | Statut |
|---|---|---|---|
| Translation atteint la cible (Done) | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_translation_moves_to_done_when_target_is_reached` | actif |
| SafeStop lève le défaut | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_translation_safe_stop_sets_fault` | actif |
| Contrat runtime validé (module généré) | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_validation_accepts_generated_translation_module` | actif |
| Décodeur position — payload cohérent | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_position_decoder_contract_validates_coherent_payloads` | actif |
| Module généré expose contrat + validateur | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_generated_translation_module_exposes_contract_and_validator` | actif |
| Rejet module non encapsulé | AUTO | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_validation_rejects_non_encapsulated_module` | actif |
| Ralentissement avant la cible (état SLOWDOWN traversé) | AF-TR-02 | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_translation_passes_through_slowdown_before_target` | actif |
| Reset n'acquitte que si la cause a disparu | AF-TR-04 | `RESULTS/TRANSLATION/tests/test_translation_behavior.py::test_translation_reset_requires_cause_to_disappear_first` | actif |

> AF-TR-01 et AF-TR-03 ne sont pas listés séparément : ils sont déjà couverts à l'identique
> par `test_translation_moves_to_done_when_target_is_reached` et
> `test_translation_safe_stop_sets_fault` ci-dessus.

## _OUTIL — Générateur (`fb_gen.py`) — pas un test métier

| Fonction | TC | Test Python | Statut |
|---|---|---|---|
| Détection fichier changé → régénération ciblée | AUTO | `RESULTS/_OUTIL/tests/test_fb_gen_changed.py::test_changed_single_st_file_triggers_generation` | actif |
| Détection bundle changé → régénération globale | AUTO | `RESULTS/_OUTIL/tests/test_fb_gen_changed.py::test_changed_bundle_triggers_all_pous_generation` | actif |
| Extraction interface POU (inputs/outputs) | AUTO | `RESULTS/_OUTIL/tests/test_fb_gen_interface.py::test_extract_pou_interface_reads_inputs_and_outputs` | actif |
| Garde-fou safety : blocage par défaut | AUTO | `RESULTS/_OUTIL/tests/test_fb_gen_safety.py::test_safety_blocks_generation_by_default` | actif |
| Garde-fou safety : `--allow-safety` débloque | AUTO | `RESULTS/_OUTIL/tests/test_fb_gen_safety.py::test_allow_safety_overrides_block` | actif |
| Banc simulation : défaut → reset | AUTO | `RESULTS/_OUTIL/tests/test_simulation_bench.py::test_safety_translation_bench_reports_fault_then_reset` | actif |
| Export CSV du banc | AUTO | `RESULTS/_OUTIL/tests/test_simulation_bench.py::test_export_bench_writes_semicolon_separated_csv` | actif |

---

## ⚫ Historique / retiré

*(vide pour l'instant — une fonction migrée/supprimée reste listée ici avec la date et le commit)*

---

## Vérification (gate)

```powershell
python TOOLS/OUTILS_ST2PY/scripts/check_test_registry.py
```

Vérifie mécaniquement :
1. Chaque test listé ici existe réellement (`pytest --collect-only`).
2. Chaque test `def test_*` présent dans `RESULTS/<DOMAINE>/tests/` est référencé dans cette table
   (aucun test orphelin non tracé).
3. Aucun doublon de `TC` actif pointant vers deux tests différents sans justification.

Un test ajouté sans ligne dans ce registre fait échouer le gate — c'est la règle `fix:`+`guard:`
du projet (`AGENTS.md`) appliquée à la dette de traçabilité identifiée le 2026-08.
