# Rôles des agents

| Rôle | Responsabilité |
|---|---|
| Pi | orchestration et décision de workflow |
| Modèle fort | architecture, code métier critique, safety assistée |
| Modèle économique/OSS | résumé, documentation, contrôle simple |
| Herdr | délégation/review optionnelle |
| Python/pytest | preuves déterministes |
| Automaticien | validation finale, safety, CODESYS, essais |

Un agent secondaire ne commit pas et ne modifie pas le code en review.
