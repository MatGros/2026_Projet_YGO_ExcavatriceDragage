# Commandes de rôle communes aux CLI

Entrées : workflow-project-orchestrator et workflow-project-coordinator.
Une invocation choisit un rôle dans la conversation courante ; elle ne prend aucune
tâche, ne modifie aucun verrou et n'autorise aucun travail supplémentaire.

1. Depuis la racine du projet, exécuter `python TOOLS/AGENT_WORKFLOW/scripts/workflow_role.py orchestrator`
   ou `python TOOLS/AGENT_WORKFLOW/scripts/workflow_role.py coordinator`, selon l'entrée invoquée.
   Le lanceur utilise l'identifiant natif du runtime, exige une source unique et
   refuse l'ambiguïté. Si le runtime ne le fournit pas, utiliser `--session <ID exact>`
   uniquement sur métadonnée fiable ; ne jamais rechercher la session la plus récente.
2. Restituer la sortie réelle du script. Une erreur n'est pas une activation.
3. Après succès, lire la fiche du rôle :
   - orchestrateur : `TOOLS/AGENT_WORKFLOW/skills/orchestrator/ROLE.md` ;
   - coordinateur : `TOOLS/AGENT_WORKFLOW/skills/task-planner/COORDINATOR.md`.
4. Appliquer les lectures de démarrage et limites de cette fiche. Si une tâche est
   connue, lire son contrat et son plan. Le rôle actif ne donne pas le droit de
   changer l'affectation Superviseur ni de démarrer une tâche sans consigne.

Claude/Antigravity/DSH peuvent présenter ces entrées dans leur menu slash selon leur
version. Dans Codex, sélectionner la skill via `/skills` ou `$workflow-project-coordinator`
et `$workflow-project-orchestrator` ; ne pas annoncer un slash personnalisé non observé.

## Veille du coordinateur pendant l'exécution autorisée

Pour une attente réelle (résultat de sous-agent, preuve attendue, échéance de revue),
utiliser `TOOLS/AGENT_WORKFLOW/scripts/coordinator_events.py` avec l'ID exact déjà
résolu. Enregistrer uniquement les fichiers explicitement concernés par la tâche :

```text
python TOOLS/AGENT_WORKFLOW/scripts/coordinator_events.py --session <ID> add <fichier> --deadline-seconds 1500
python TOOLS/AGENT_WORKFLOW/scripts/coordinator_events.py --session <ID> wait --duration 30 --interval 5
python TOOLS/AGENT_WORKFLOW/scripts/coordinator_events.py --session <ID> ack <numéro-événement>
```

Quand le runtime propose une attente native de sous-agent ou de processus, la préférer
pour ces objets ; le watcher de fichiers sert aux livrables et échéances. À réception,
lire le résultat, agir dans le GO existant ou signaler le besoin de décision, puis
acquitter l'événement traité. Un fichier modifié est un signal à examiner, jamais une
preuve de réussite. Une erreur ou disparition de source doit rester visible.

La boîte conserve les événements non traités et les échéances hors dépôt. L'attente
est bornée à 60 secondes par appel, sans sollicitation automatique d'autres sessions.
Elle peut alimenter un tour actif via une tâche d'arrière-plan suivie par le runtime.
Le réveil autonome d'un chat inactif exige un raccordement au mécanisme du CLI : ne
pas le déclarer opérationnel sur la seule présence de cette boîte.
