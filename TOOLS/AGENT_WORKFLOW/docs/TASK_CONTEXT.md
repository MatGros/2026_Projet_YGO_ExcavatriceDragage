# Contrat TASK_CONTEXT

```yaml
task_id: ""
request: ""
criticality: C0|C1|C2|C3|C4
scope_code: []
scope_doc: []
out_of_scope: []
acceptance_criteria: []
tests_required: []
# Optionnel, tout niveau (décision 2026-08-01 : plus d'obligation C3/C4 — voir
# note ci-dessous). true seulement si la tâche choisit d'écrire un test PLC.
tests_automated_required: false
tests_implementation_paths: [] # fichiers ST du test/extension de suite
tests_status: planned|implemented|executed
test_execution_evidence: [] # résultat simulation/CODESYS, ajouté après exécution
# ⛔ Jamais rempli par déduction depuis un bundle généré ou des tests du générateur :
# uniquement après un log réel d'import/compilation CODESYS fourni par l'utilisateur.
review_required: false
# double_review_required : true obligatoire pour C4 et tout sujet safety.
# Déclenche la procédure A/B parallèle (TEST_DESIGN + ST généré + revue safety).
dual_review_required: false
# Ponytail : forbidden obligatoire pour C3/C4 et tout sujet safety détecté.
pony_tail: forbidden|allowed
human_validation_required: true
```

Le fichier est préparé avant toute modification et reste spécifique à la tâche.

Ponytail est interdit pour : safety, normes, redondance, AU, PowerCutOff, SafeStop,
freins, contacteurs, limites physiques, interlocks, homing safety et FAT/SAT.

## Valeurs obligatoires par criticité

| Champ | C0-C1 | C2-C3 | C4 |
|---|---|---|---|
| `tests_automated_required` | false | false | false (option libre) |
| `dual_review_required` | false | false | **true** |
| `pony_tail` | allowed | allowed / forbidden | **forbidden** |
| `human_validation_required` | true | true | **true** |

## Gate tests (optionnel)

📌 **Décision 2026-08-01** : le test PLC automatique embarqué n'est plus obligatoire pour
C3/C4, quel que soit le sujet safety. Motif : même coût que le framework `PLC_TESTS`
abandonné le 2026-07-26 (RAM, resynchronisation à chaque évolution métier) pour des
artefacts jamais réellement exécutés en CODESYS (`CODE/TESTS/` archivé dans
`ARCHIVES/Code/TESTS/`). La garantie C3/C4 repose désormais sur `human_validation_required`
seul : vérification manuelle exhaustive (Watch/forçage CODESYS) **avant tout chargement**,
sans artefact structuré obligatoire.

Si une tâche choisit quand même d'écrire un test PLC (`tests_automated_required: true`) :
`python TOOLS/AGENT_WORKFLOW/scripts/check_task_test_contract.py <TASK_CONTEXT>` avant code,
même commande `--release` avant restitution — le gate vérifie alors que l'artefact déclaré
existe et, en release, qu'il est `implemented` avec preuve d'exécution.
