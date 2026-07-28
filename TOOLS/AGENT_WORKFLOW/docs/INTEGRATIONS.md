# Intégrations agents

## Pi Subagents — voie par défaut

Plugin utilisateur installé :

```text
pi-subagents
```

Il lance des agents enfants Pi avec contexte isolé et restitue leurs avis directement dans la
conversation. C'est la voie normale pour une analyse, un contre-avis ou une revue : **pas de
pane Herdr, pas de SDK projet, pas de worktree**.

### Usage sobre

| Besoin | Agents | Écriture |
|---|---:|---|
| C0-C1 | aucun | Pi principal après validation du scope si nécessaire |
| C2 | 0 ou 1 avis ciblé | Pi principal seul |
| C3 | 1 reviewer/oracle read-only | Pi principal seul |
| C4 safety | 2 avis A/B read-only parallèles | Pi principal seul, après validation humaine |

- Les avis utilisent `scout`, `planner`, `reviewer` ou `oracle` intégrés au plugin.
- Un avis est **read-only** : `read`, `grep`, `find`, `ls` uniquement ; pas de modification, pas
  de commit, pas de sous-délégation.
- Les deux avis A/B reçoivent le même objectif et les mêmes sources, sans voir le résultat de
  l'autre.
- Pi principal compare les rapports, ne fusionne jamais automatiquement leurs propositions et
  présente : `✅ accords`, `⚠️ divergences`, `🎯 recommandation`, `❓ décision`.
- Les sous-agents héritent du modèle Pi courant. Le modèle voulu pour les revues est
  `omni/cc/claude-sonnet-5` lorsqu'il est disponible ; le modèle réellement utilisé est annoncé
  dans le rapport.
- Ne pas lancer d'agent de fond : l'avis est attendu, lu et synthétisé avant de poursuivre.

### Point d'arrêt humain obligatoire

Après les avis et **avant toute écriture**, Pi présente un plan court (scope, fichiers, flux,
risques, gates et tests). L'automaticien répond explicitement `valider le plan` ou formule les
corrections. Sans cette validation, aucune modification `CODE/` ou `DOC/` n'est faite.

## Herdr — secours explicite

Herdr est une dépendance externe optionnelle, utilisée via le package Pi
`@andrewjacop/pi-herdr`. Elle orchestre des agents visibles dans des panes séparés.

Prérequis :

```text
pi list             → pi-herdr installé
herdr --version     → CLI disponible
herdr status        → serveur running
```

### Préflight obligatoire

1. Exécuter `herdr status` avant tout lancement.
2. Si le serveur est arrêté, lancer `herdr` ou `herdr server`, puis revérifier son état.
3. Sous PowerShell, utiliser la commande complète `herdr` : `rdr` est un alias de
   `Remove-PSDrive`, pas une abréviation Herdr.
4. `herdr integration status` peut ne pas afficher Pi sur certaines versions preview : ce n’est
   pas une preuve d’indisponibilité. Le test décisif est le lancement d’un agent `pi` suivi d’un
   handshake.
5. Une erreur Windows `Os code 2 / fichier introuvable` avant ouverture du pane indique d’abord
   un problème de serveur/processus/PATH, pas un refus du modèle ou un manque de crédits.

Chemin validé sur Windows pour utiliser les modèles configurés dans Pi :

```text
Herdr → agent pi → fournisseur actif de Pi (ex. OmniRoute)
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
herdr status (serveur running)
   ↓
herdr_start_agent
   ↓
handshake court : READY
   ↓
herdr_wait_agent → herdr_read_agent
   ↓
mission découpée en petites consignes
   ↓
herdr_wait_agent(status=idle, délai adapté)
   ↓
herdr_read_agent immédiatement
   ↓
contrôle orchestrateur + Git/gates Python
   ↓
information et validation utilisateur
   ↓
herdr_stop_agent
```

⚠️ **Herdr ne déclenche pas un nouveau tour de conversation quand l’agent termine.** Après chaque
`herdr_send_prompt`, l’orchestrateur doit attendre puis lire explicitement le résultat dans la
même séquence. Il ne doit pas rendre la main avec le seul message « agent lancé ».

Si l’attente expire :

```text
herdr_get_agent / herdr_list_agents
→ si working : nouvelle attente
→ si idle/done : lecture immédiate
→ si blocked : lire, traiter le blocage ou arrêter proprement
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

- Exécution/revue projet par défaut : Pi via OmniRoute avec
  `--model omni/cc/claude-sonnet-5`, sauf demande utilisateur contraire ou indisponibilité.
- `pi` avec un autre modèle : fallback explicite, modèle annoncé à l’utilisateur.
- `claude` ou `codex` : review code complexe si demandé.
- `omp` : revue OpenCode si disponible.

Lancement Herdr correspondant :

```text
herdr agent start <nom> --cwd <projet> -- pi --model omni/cc/claude-sonnet-5
```

Le modèle réellement lancé doit être vérifié dans le pane (`PI_PROVIDER`/`PI_MODEL`) et annoncé.
Le choix du modèle reste consultatif. Les preuves doivent venir des scripts, de CODESYS et des
essais requis.
