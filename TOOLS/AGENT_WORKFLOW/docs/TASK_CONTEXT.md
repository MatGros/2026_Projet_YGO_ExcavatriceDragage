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
review_required: false
# Règle : forbidden obligatoire pour C3/C4 et tout sujet safety détecté.
pony_tail: forbidden|allowed
human_validation_required: true
```

Le fichier est préparé avant toute modification et reste spécifique à la tâche.

Ponytail est interdit pour : safety, normes, redondance, AU, PowerCutOff, SafeStop,
freins, contacteurs, limites physiques, interlocks, homing safety et FAT/SAT.

## Gate tests C3/C4

Avant code : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_test_contract.py <TASK_CONTEXT>`.
Avant restitution/release : même commande avec `--release`.

Pour C3/C4 ou safety, une simulation manuelle seule ne suffit pas : le scope doit contenir
un artefact PLC de test, et le lot reste bloqué tant que `tests_status` n'est pas
`implemented` avec une preuve d'exécution.
