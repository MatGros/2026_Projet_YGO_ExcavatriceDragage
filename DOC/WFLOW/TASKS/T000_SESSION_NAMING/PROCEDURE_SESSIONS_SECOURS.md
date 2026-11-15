# Procédure : sessions de secours et communication entre sessions

Objet : relier rapidement un agent orchestrateur à une session locale, pour discuter ou reprendre le suivi si le cloud est indisponible ou si les tokens sont épuisés.

## 1. Ce qui est prouvé (test du 2026-11-14)

- Envoi et accusé entre sessions Claude Code locales, dans les deux sens.
- Testé : T000-CC10 [27b657] vers T427-CC02 [f79542] (accusé reçu, horodaté).
- Testé : T000-CC10 [27b657] vers [db4cd4] (accusé reçu, identifiant de session déclaré).
- Non prouvé : Antigravity (AGY), Codex, Ollama, et toute reprise de travail réel.

## 1bis. Première annonce de l'orchestrateur

Au premier message de la session, l'orchestrateur :
1. Se présente : rôle (orchestrateur projet), session, humain qui le pilote.
2. Explique en 5 lignes au maximum la procédure d'échange (section 3 et « Comment la session cible répond »).
3. Précise qu'il peut être l'émetteur des messages vers les sessions que l'humain a désignées, et que seules ces sessions sont contactées.
4. Ne contacte aucune session sans désignation explicite de l'humain.

## 2. Trouver les sessions joignables

1. `ListAgents` : liste les sessions Claude jointes. Copier le nom exact, emoji et référence compris.
2. Superviseur (lecture seule) : `GET http://127.0.0.1:8082/api/supervision` donne les identifiants natifs, la plateforme et l'état des sessions suivies.
3. Une session absente de `ListAgents` n'est pas forcément inexistante : vérifier dans le Superviseur.

## 3. Relier un agent

1. Choisir la session cible (décision humaine).
2. Envoyer une consigne courte : rôle, objectif, interdits, et une demande d'accusé sur une ligne.
3. Attendre l'accusé. Sans accusé, relancer une seule fois avec le nom exact, puis signaler.

### Comment la session cible répond

- Elle répond avec `SendMessage`, en mettant dans `to` la valeur de l'attribut `from` du message reçu (le nom exact de l'émetteur, référence comprise).
- La réponse tient en une ligne si la consigne le demande, avec l'identifiant de session de la session qui répond.
- Elle ne doit jamais répondre à un message qui n'est pas le sien, ni renvoyer vers une troisième session.

## 4. Interdits (valables pour toute session jointe)

- Aucune écriture dans le dépôt sans GO humain.
- Aucun commit ni push sans accord.
- Un message par test. Pas d'échanges en boucle entre sessions.
- Arrêt immédiat sur demande de l'humain.

## 5. Fermer

- L'humain ferme les terminaux de test.
- L'orchestrateur note dans le dossier de tâche quelles sessions ont été contactées, et avec quel résultat.

## 5bis. Veille proactive (proposition, non figée)

Proposition à adapter selon la tâche, pas une règle rigide.

- Au lancement d'une tâche ou d'une attente, l'agent note : ce qu'il attend, de qui, et quand il revérifie (par exemple 25 minutes).
- Au réveil, il vérifie une seule fois :
  - rien de nouveau : il se rendort, sans rien écrire ;
  - quelque chose a changé : il agit, ou il remonte la question à l'humain.
- Il peut demander un point de situation à la session concernée : avancement, blocage, répétition, question. Une demande par cycle.
- Le coordinateur, qui a des sous-agents, applique la même veille à chacun d'eux, sans multiplier les demandes.
- Les points d'arrêt humains restent prioritaires : la veille n'autorise aucune action qu'un GO n'aurait pas permise.

## 6. Limites

- Un accusé prouve le canal, pas l'identité ni le travail réel. Les identifiants déclarés sont à croiser avec le Superviseur.
- Les sessions Claude de secours ne contiennent pas le contexte des autres : le brief doit être complet.
