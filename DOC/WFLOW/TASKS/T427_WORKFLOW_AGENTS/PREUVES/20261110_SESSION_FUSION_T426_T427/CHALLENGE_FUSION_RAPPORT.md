# Challenge indépendant — fusion T426 dans T427 (2026-11-10)

Agent natif en lecture seule, deux passes. Rapport relayé par l'orchestrateur `CC01` ; les points marqués ✅ ont été relus par `CC01` dans les contrats d'origine, les autres sont **déclarés par l'agent**.

## Verdict
**Fusion partielle** : T427 survit, T426 devient un jalon M0, sans suppression de fichier ni de fiche.

## Chevauchement
| Sujet | Relation |
|---|---|
| `templates/task_contract.yaml` | même fichier, complémentaires (T426 a ajouté `tracking`, T427 veut `execution_plan`, `test_feedback`, budget, `companion_doc`) |
| `check_task_contract.py` | même zone, à coordonner |
| Fiche unique par tâche | dupliqué en partie (T426 « aucun journal dupliqué » vs note MD de T427) |
| Hooks | ✅ contradictoire : T426 interdit tout hook actif modifié sans plan d'activation validé (`forbidden`, AC7) ; T427-AC4 modifie `Stop` et `PostToolUse` |
| Skills | ✅ contradictoire : T426 `local_decision` « aucune nouvelle skill parallèle » ; T427-AC1 crée `project-workflow` |
| Revue A/B, stagnation, matrice de contrôles | propres à T426 |

Sur 8 AC T426 et 5 AC T427, aucun n'est identique (déclaré par l'agent).

## Risques relevés
- Perte du travail CDX01 : faible, prototype commité (`2a5bf86d`, indépendant du catalogue).
- 13 AC en un contrat C2 : garder les identifiants d'origine (appliqué : `T426-AC1…8`, `AC1…5`).
- Les 43 tests prouvent les AC T426, pas ceux de T427.
- Trou de périmètre dans le contrat T427 d'origine : ni hooks, ni skills, ni `.claude/settings.json` dans `scope.allowed` alors que AC1 et AC4 les touchent ✅ (corrigé : ces cibles sont maintenant en `forbidden` tant que D2/D3 ne sont pas tranchées).
- Verrous distincts (CDX01/T426, AGY01/T427) : transfert sur décision de l'exploitant.

## Limites de ce challenge
- `task-planner/SKILL.md` non lu par l'agent : statuts autorisés pour une tâche « fusionnée » non vérifiés.
- Les 43 tests et `check_task_contract.py` non rejoués par l'agent.
- Copie de T426 dans `.claude/worktrees/carte-flux/` non lue.
