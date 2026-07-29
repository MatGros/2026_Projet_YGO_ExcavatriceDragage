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
# Obligatoire C3/C4 et tout sujet safety : test PLC automatique traçable.
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
| `tests_automated_required` | false | false / true | **true** |
| `dual_review_required` | false | false | **true** |
| `pony_tail` | allowed | allowed / forbidden | **forbidden** |
| `human_validation_required` | true | true | **true** |

## Gate tests C3/C4

Avant code : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_test_contract.py <TASK_CONTEXT>`.
Avant restitution/release : même commande avec `--release`.

Pour C3/C4 ou safety, une simulation manuelle seule ne suffit pas : le scope doit contenir
un artefact PLC de test, et le lot reste bloqué tant que `tests_status` n'est pas
`implemented` avec une preuve d'exécution.
