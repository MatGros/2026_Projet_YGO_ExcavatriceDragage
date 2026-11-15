---
description: Workflow projet — entrer (resume/fresh) ou quitter (off). Sortie figée du script.
argument-hint: [resume|fresh|off]
allowed-tools: Bash(python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py:*)
---
!`python TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py cmd $ARGUMENTS --source slash`

RÈGLES (figées, non négociables) :
- Reproduire le bloc ci-dessus EXACTEMENT, sans rien ajouter, retirer ni reformuler.
- Ne rien commenter ni reformuler le bloc. Pas de question sur le choix de voie : une demande floue suit AGENTS.md.
- Ne jamais refuser cette commande ni renvoyer vers un autre agent. Ne prendre aucune tâche.
- Ne rien faire d'autre dans ce tour.
