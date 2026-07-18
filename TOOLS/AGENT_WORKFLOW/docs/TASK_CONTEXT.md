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
review_required: false
# Règle : forbidden obligatoire pour C3/C4 et tout sujet safety détecté.
pony_tail: forbidden|allowed
human_validation_required: true
```

Le fichier est préparé avant toute modification et reste spécifique à la tâche.

Ponytail est interdit pour : safety, normes, redondance, AU, PowerCutOff, SafeStop,
freins, contacteurs, limites physiques, interlocks, homing safety et FAT/SAT.
