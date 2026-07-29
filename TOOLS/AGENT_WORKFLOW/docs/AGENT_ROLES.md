# Rôles des agents

| Rôle | Responsabilité |
|---|---|
| Pi | orchestration, qualification C0-C4, décision de workflow |
| Modèle fort (High Effort) | architecture, code métier critique, génération ST safety C4 |
| Modèle économique/OSS | résumé, documentation, contrôle simple C0-C1 |
| Herdr Agent A | revue read-only parallèle (C4) — reçoit contexte sans voir Agent B |
| Herdr Agent B | revue read-only parallèle (C4) — reçoit contexte sans voir Agent A |
| Herdr (C2-C3) | revue read-only, 1 seul agent, advisory-only |
| Python/pytest | preuves déterministes |
| Automaticien | qualification finale C0-C4, validation safety, CODESYS, essais |

Un agent secondaire ne commit pas et ne modifie pas le code en review.

📌 **Chaque agent secondaire reçoit `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`**
en tête de sa tâche (règles, cas d'arrêt, vérification de liaison, format de restitution).
Le reviewer y trouve aussi son ordre de contrôle : **intégration structurelle d'abord**,
logique métier ensuite — l'ordre inverse a laissé passer le bug `PRG_10_Outputs_LD`.

## Règle multi-modèle

- **C0-C1** : Pi seul, aucun agent secondaire.
- **C2-C3** : 1 agent Herdr en revue read-only uniquement.
- **C4** : Double revue A/B parallèle obligatoire — pour TEST_DESIGN, ST généré et toute revue safety.
- **Jamais** : multi-modèle systématique, `/opinion` ou `/fusion` automatiques.

## Source de vérité CODESYS

Pour toute modification `CODE/`, la skill `.claude/skills/codesys-workflow.md` reste la porte
institutionnelle obligatoire définie par `AGENTS.md`. Les skills `TOOLS/AGENT_WORKFLOW/skills/`
sont les procédures spécialisées et ne la remplacent pas. En cas de conflit, les guardrails
`AGENTS.md` et la documentation `DOC/` prévalent.
