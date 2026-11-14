---
name: plan-project
description: Crée ou restitue le plan détaillé et l'état vérifiable de la tâche projet courante.
user-invocable: true
---

# `/plan-project` — plan et avancement

1. Résoudre la tâche formelle du chat depuis son contexte vérifiable ou le rattachement Superviseur courant. Ne jamais deviner ni prendre/créer une tâche. Si aucune tâche unique n'est identifiable, demander l'ID `T###`.
2. Exécuter `py -3.13 TOOLS/AGENT_WORKFLOW/scripts/plan_project.py <T###>` depuis la racine.
3. Si le script crée un plan, lire l'entrée précise de `TASKS.yaml`, le contrat référencé et les documents de tâche cités. Compléter ce plan unique avec le but, le périmètre, les dépendances et des jalons mesurables issus de ces sources. Ne pas marquer de validation sans visa humain/jugement enregistré, auteur et date. Ne modifier ni le catalogue ni le contrat par cette commande.
4. Si le plan existe, lire le plan, l'entrée ciblée du Task Manager, le contrat et les références nécessaires ; restituer le rapport du script puis les détails utiles manquants. Conserver les états explicites. `DONE` n'implique jamais `ACCEPTED`.
5. En cas de plusieurs plans, absence de tâche ou donnée incohérente, ne rien créer/modifier et expliquer le blocage précisément.

Le script est la source du comptage mécanique. La lecture de l'agent ajoute le contexte détaillé ; elle ne change pas les états enregistrés.
