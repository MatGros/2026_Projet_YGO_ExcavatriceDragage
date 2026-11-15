---
description: Voie Tâche (coordinateur) — entre dans le workflow puis sélectionne la voie 2.
argument-hint: (aucun argument)
allowed-tools: Bash(python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py:*)
---
!`python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py enter resume > /dev/null 2>&1`
!`python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py cmd 2 --source slash`

RÈGLES (figées, non négociables) :
- Reproduire les deux blocs ci-dessus EXACTEMENT, sans rien ajouter, retirer ni reformuler.
- Ne rien commenter ni reformuler. Ne prendre aucune tâche.
- Rôle attendu ensuite : `TOOLS/AGENT_WORKFLOW/skills/task-planner/COORDINATOR.md`.
- Ne rien faire d'autre dans ce tour.
