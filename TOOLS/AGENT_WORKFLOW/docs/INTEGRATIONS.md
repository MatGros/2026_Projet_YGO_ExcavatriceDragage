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

Tout rapport Herdr est `advisory-only` par défaut. `human-validated` nécessite une validation
explicite de l'automaticien et ne peut pas être attribué automatiquement.

## Flux standard

```text
herdr status
   ↓
agent unique
   ↓
handshake court : READY
   ↓
mission découpée en petites consignes
   ↓
herdr_wait_agent
   ↓
herdr_read_agent + marqueur de fin
   ↓
contrôle Git/gates Python
   ↓
validation Pi/utilisateur
   ↓
herdr_stop_agent
```

### Protocole obligatoire de transmission

Les prompts longs ou multilignes peuvent être tronqués dans un pane interactif.
Pi ne doit donc jamais envoyer une mission complexe en une seule consigne.

1. Démarrer **un seul agent** pour une mission.
2. Envoyer une consigne courte de handshake : `Réponds READY uniquement.`
3. Attendre et lire la réponse avant toute mission.
4. Envoyer des étapes courtes, une par une, avec un marqueur attendu : `ETAPE_TERMINEE`.
5. Après chaque étape : lire le rapport, vérifier le périmètre et le diff.
6. Si `READY` n'est pas reçu, ou si le prompt est mal compris : arrêter l'agent et recommencer.
7. Aucun agent Herdr ne commit. En safety, aucun agent ne modifie `CODE/`.

Utiliser `herdr_delegate` pour une tâche ponctuelle courte. Utiliser
`herdr_start_agent` + `herdr_send_prompt` uniquement pour une mission interactive
pilotée étape par étape. Ne pas lancer plusieurs agents complexes en parallèle
avant validation de leur handshake.

Outils disponibles : `herdr_delegate`, `herdr_start_agent`, `herdr_send_prompt`,
`herdr_wait_agent`, `herdr_read_agent`, `herdr_stop_agent`.

## Agents recommandés

- `pi` : analyse générale ciblée ;
- `claude` ou `codex` : review code complexe ;
- `omp` : revue OpenCode si disponible.

Le choix du modèle reste consultatif. Les preuves doivent venir des scripts, de CODESYS
et des essais requis.
