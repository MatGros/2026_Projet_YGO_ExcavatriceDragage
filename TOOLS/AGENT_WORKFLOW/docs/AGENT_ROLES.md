# Rôles des agents

| Rôle | Responsabilité |
|---|---|
| Pi | orchestration et décision de workflow |
| Modèle fort | architecture, code métier critique, safety assistée |
| Modèle économique/OSS | résumé, documentation, contrôle simple |
| Herdr | délégation/review optionnelle, un agent à la fois par défaut |
| Python/pytest | preuves déterministes |
| Automaticien | validation finale, safety, CODESYS, essais |

Un agent secondaire ne commit pas et ne modifie pas le code en review.

## Source de vérité CODESYS

Pour toute modification `CODE/`, la skill `.claude/skills/codesys-workflow.md` reste la porte
institutionnelle obligatoire définie par `AGENTS.md`. Les skills `TOOLS/AGENT_WORKFLOW/skills/`
sont les procédures spécialisées et ne la remplacent pas. En cas de conflit, les guardrails
`AGENTS.md` et la documentation `DOC/` prévalent.
