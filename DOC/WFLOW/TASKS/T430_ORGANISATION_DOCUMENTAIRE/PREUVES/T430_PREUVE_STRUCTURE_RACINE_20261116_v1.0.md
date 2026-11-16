# T430 — Preuve de rangement des documents principaux

**Date :** 2026-11-16 · **Contrôle :** structure racine et lien Task Manager

## Résultat

- Racine active : `T430_TASK_20261116_v1.1.md`, `T430_TASK_PLAN_20261116_v1.2.md`, `T430_TASK_STUDY_DOCUMENT_20261115_v1.0.md`.
- Versions remplacées archivées : `ARCHIVES/T430_TASK_20261115_v1.0.md`, `ARCHIVES/T430_TASK_PLAN_20261115_v1.1.md`.
- Contrats sous `CONTRACTS/` : v1.1 actif et v1.0 historique.
- `TASKS.yaml` pour T430, propriétaire CDX04, référence `DOC/WFLOW/TASKS/T430_ORGANISATION_DOCUMENTAIRE/CONTRACTS/T430_CONTRACT_ORGANISATION_DOCUMENTAIRE_20261115_v1.1.yaml` ; la cible existe.
- Tous les liens Markdown locaux des trois documents principaux pointent vers une cible existante après correction du lien d’étude vers le plan courant.

## Reproduction

Depuis la racine du dépôt, le contrôle Python ci-dessous lit le catalogue sans le modifier et vérifie la présence de la cible référencée :

```powershell
$env:PYTHONIOENCODING='utf-8'
@'
from pathlib import Path
import yaml
tasks = yaml.safe_load(Path('DOC/WFLOW/TASKS.yaml').read_text(encoding='utf-8'))['tasks']
task = next(item for item in tasks if item.get('id') == 'T430')
contract = task['contrat']
print(task['id'], task['agent'], contract, Path(contract).is_file())
'@ | python -
```

Sortie observée : `T430 CDX04 DOC/WFLOW/TASKS/T430_ORGANISATION_DOCUMENTAIRE/CONTRACTS/T430_CONTRACT_ORGANISATION_DOCUMENTAIRE_20261115_v1.1.yaml True`.

Le serveur Task Manager local ne répondait pas lors de la revue Superviseur ; la preuve du lien repose donc sur le catalogue YAML courant et l’existence effective du fichier, pas sur un contrôle visuel de l’IHM.
