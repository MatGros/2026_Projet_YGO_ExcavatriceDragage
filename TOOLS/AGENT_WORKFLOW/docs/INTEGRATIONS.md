# Intégrations agents

## Herdr

Herdr est une dépendance externe optionnelle, utilisée via le package Pi
`@andrewjacop/pi-herdr`. Elle orchestre des agents visibles dans des panes séparés.

Prérequis :

```text
pi list              → pi-herdr installé
herdr --version     → CLI disponible
herdr status        → serveur running
```

## Règle d'utilisation

| Situation | Herdr |
|---|---|
| C0 | inutile |
| C1 | optionnel |
| C2 | review ciblée possible |
| C3 | review read-only recommandée |
| C4 | avis consultatif uniquement, humain obligatoire |

Herdr ne modifie pas le dépôt pendant une review et ne fait jamais de commit.

## Flux standard

```text
TASK_CONTEXT
   ↓
herdr_delegate (agent secondaire)
   ↓
rapport read-only
   ↓
comparaison avec les gates Python
   ↓
validation Pi/utilisateur
```

Outils disponibles : `herdr_delegate`, `herdr_start_agent`, `herdr_send_prompt`,
`herdr_wait_agent`, `herdr_read_agent`, `herdr_stop_agent`.

## Agents recommandés

- `pi` : analyse générale ciblée ;
- `claude` ou `codex` : review code complexe ;
- `omp` : revue OpenCode si disponible.

Le choix du modèle reste consultatif. Les preuves doivent venir des scripts, de CODESYS
et des essais requis.
