# T432 — Patch proposé : index de routage borné dans `AGENTS.md` §3

Date : 2026-11-16 · Auteur : T432-CDX02 · Statut : **proposition, non appliquée**
Origine : challenge `/challenge` du 2026-11-16, verdict ADVISORY — option retenue « index borné ».

## 1. Ce qui est remplacé

`AGENTS.md`, section `### 3. Tri & aiguillage sur 4 voies`, lignes 44 à 48.

## 2. Avant

```markdown
- **Intention claire — charger uniquement la référence requise :**
  - Réponse directe : question simple ou action locale réversible (lecture seule stricte sur CODE/).
  - Orchestrator : TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md (pilotage de lot, validation humaine pré-code ; modèles selon MODEL_ROUTING.md).
  - Task : TOOLS/AGENT_WORKFLOW/skills/task-planner/SKILL.md (protocole avant toute écriture dans TASKS.yaml, contrats C2+, verrous).
  - Troubleshooting : TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md + méthode TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md (snapshot, test CI ad hoc, Device.export interdit).
```

## 3. Après

```markdown
- **Intention claire — index de routage** (les procédures vivent dans les fiches ; **la fiche fait foi**) :
  - **Réponse directe** — question simple ou action locale réversible (lecture seule stricte sur `CODE/`).
  - **Orchestrateur** — pilote un lot, seul écrivain du catalogue : `TOOLS/AGENT_WORKFLOW/skills/orchestrator/ROLE.md`.
  - **Coordinateur** — une seule tâche de bout en bout, écrit dans son dossier : `TOOLS/AGENT_WORKFLOW/skills/task-planner/COORDINATOR.md`.
  - **Dépannage** — incident ou comportement inexpliqué : `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md`.
- **Choix en une ligne :** plusieurs tâches ou un lot -> orchestrateur · une seule tâche -> coordinateur · question ou lecture -> réponse directe · incident -> dépannage.
- **Jetons de commande (verbatim) :** `/workflow-project-orchestrator` · `/workflow-project-coordinator` · dépannage `3`.
- Changement CODESYS/ST : standards (`DOC/STDS/`), architecture et spec métier (`DOC/AF/`) chargés à la demande (§ Avant de coder).
```

Delta : 5 lignes remplacées par 8. **+3 lignes nettes**, sous le budget ferme de +15.

## 4. Ce que le patch fait, et ne fait pas

Fait :
- Nomme les deux rôles et la règle de choix en une ligne.
- Cite le **jeton de commande exact** — c'est ce qui manquait à la session Haiku, qui annonçait une commande sans savoir la lancer.
- Ajoute une clause de préséance : **la fiche de rôle fait foi**. L'index ne devient donc pas une seconde source de vérité.
- Pointe vers les fiches de rôle (`ROLE.md`, `COORDINATOR.md`), pas vers les `SKILL.md` de protocole.

Ne fait pas, volontairement (décisions du challenge) :
- Pas d'arborescence racine : jugée volatile, risque HIGH, elle dérive à chaque session.
- Pas de recopie des procédures de rôle.
- Pas de modification des skills, du catalogue ou de `CODE/`.

## 5. Garde associé (à écrire après validation)

`TOOLS/AGENT_WORKFLOW/scripts/check_routing_index.py` :
- échoue si un chemin cité dans l'index n'existe pas ;
- échoue si la ligne `Choix en une ligne` diverge de la règle attendue ;
- sortie 0 en état stable, non nulle dès qu'un chemin est renommé.

## 6. Ce que ce patch ne prouve pas

La baseline d'échec reste faible : deux sessions, dont une Haiku. Le challenge a demandé 5 sessions
neuves, au moins deux modèles, critère « fichiers ouverts avant routage correct <= 1 ». Ce patch
est une hypothèse raisonnée, pas un résultat mesuré.
