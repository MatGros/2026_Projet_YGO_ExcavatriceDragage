# T427 — Matrice rôles / droits et procédure de désignation (v0.1, 2026-11-17)

> Document de travail T427-CC02. **Proposition, rien n'est appliqué.**
> Aucune écriture dans `CODE/`, `TASKS.yaml` ni un fichier de garde sans GO exploitant par fichier.
> Demande : brief TORC-CC10 du 2026-11-17, point 2 (rôles et responsable du catalogue).

## 1. Objet

Répondre à trois questions, aujourd'hui sans réponse écrite :
1. Qui écrit dans le catalogue `TASKS.yaml` ?
2. Qui peut écrire dans `CODE/` ?
3. Qui valide, et comment une relève est tracée ?

## 2. Faits vérifiés (2026-11-17)

- `AGENTS.md` § Gestion du Task Manager : « le coordinateur désigné gère le catalogue et ses verrous ; les agents délégués rendent leur état au coordinateur ». Règle canonique : `TOOLS/AGENT_WORKFLOW/skills/task-planner/SKILL.md`.
- Agents déclarés dans `DOC/WFLOW/TASKS.yaml` (comptage par champ `agent`) : CDX01 17, AGY01 16, CC01 10, HUM 8, DSH01/02/03 2 chacun, puis 9 agents à 1 tâche.
- Statuts du catalogue : ⬜ 144, ✅ 73, ❌ 8, ⏸️ 6, ⏳ 4.
- `CC01` porte 10 tâches et **aucune session CC01 n'existe** : l'attribution est périmée.
- Gardes d'écriture, état réel :
  - `.claude/settings.json` : hooks `PreToolUse` (Edit/Write/MultiEdit, Bash/PowerShell, EnterWorktree/Agent). Ces hooks ne s'appliquent **qu'aux sessions Claude Code**.
  - `.agents/` (Codex, Antigravity) : 4 skills, **aucun hook**. `grep` sur `.agents` et `.dsh` : aucun `PreToolUse`, aucun `pre-commit`.
  - `git config core.hooksPath` = `TOOLS/AGENT_WORKFLOW/hooks` : `pre-commit` (bloquant sur fichier partagé) et `pre-push` (informatif). Ces deux hooks s'appliquent à **tout agent qui commite**, quel que soit son CLI.
- Limite du hook git : il empêche un commit, pas une écriture sur disque.

## 3. Rôles du workflow

- **Orchestrateur projet** : vue d'ensemble, priorise, délègue, suit, revoit. Ne valide jamais son propre travail.
- **Coordinateur de tâche** : responsable d'une tâche, de son plan et de son suivi ; écrit l'état de sa tâche dans le catalogue.
- **Exécutant** (agent ou sous-agent) : réalise, rend résultat et preuve. N'élit pas lui-même son périmètre.
- **Exploitant** : seul à clore, accepter, et autoriser une écriture à risque.
- **Superviseur** : observe, signale, ne modifie aucun état.

## 4. Matrice proposée

| Action | Orchestrateur | Coordinateur | Exécutant | Superviseur | Exploitant |
|---|---|---|---|---|---|
| Lire catalogue, plans, contrats | oui | oui | oui | oui | oui |
| Écrire `TASKS.yaml` | non (délègue) | oui, sa tâche | non | non | sur GO |
| Écrire le plan de sa tâche | oui | oui | sur délégation | non | oui |
| Écrire `CODE/` | sur GO par fichier | sur GO par fichier | non | non | oui |
| Modifier un fichier de garde | non | non | non | non | sur GO par fichier |
| Valider / accepter une tâche | non | non | non | non | oui |
| Ouvrir / fermer un constat | non | non | non | propose | oui |

Règle de lecture : « non » veut dire « refuse par un garde automatique quand c'est possible, et signalé sinon ».

## 5. Problème constaté

Les gardes s'appliquent **par agent**, pas **par rôle**. Conséquence observée le 2026-11-17 :
- un orchestrateur Claude Code est bloqué sur `CODE/`, même pour un message opérateur sans enjeu de sécurité ;
- un agent hors Claude Code n'a aucun garde équivalent côté CLI ;
- le patch « messages capteur haut et mou de câble » attend un relais manuel depuis 17:50 alors qu'il n'a pas d'impact safety.

## 6. Mécanisme proposé

1. **Barrière commune** : étendre `pre_commit_scope.py` (hook git partagé) au cas `CODE/` — refus d'un commit touchant `CODE/` sans contrat à périmètre épinglé. Couvre tous les CLI d'un coup. Fichier de garde : GO par fichier requis.
2. **Limite assumée** : ce mécanisme empêche le commit, pas l'écriture. Si l'exigence est « aucune écriture », il faut un garde par CLI, donc un par outil — coût et couverture à trancher par l'exploitant.
3. **Voie courte sans impact safety** : contrat léger à périmètre épinglé sur un seul fichier, validé par l'exploitant, qui autorise l'écriture sans relais manuel.

## 7. Procédure de désignation et de relève (proposée)

1. Une session = un alias `T###-ACTEUR`, jamais réutilisé par deux sessions vivantes.
2. Toute désignation produit un GO tracé : fichier daté dans le dossier de la tâche, contenant émetteur, périmètre, date. **Un GO verbal non copié n'autorise rien** (règle déjà écrite dans `AGENTS.md`).
3. Le champ `agent` du catalogue suit la session vivante. Une session disparue laisse une trace de relève, pas une attribution muette.
4. Relève : nouveau GO, même format, mention « remplace l'alias X du <date> ».
5. Autorité ambiguë (deux sessions se croyant responsables) : arrêt des écritures, escalade à l'exploitant.

## 8. Critères testables proposés

- C1 : un commit touchant `CODE/` sans contrat à périmètre épinglé est refusé par `pre-commit` (sortie brute + code retour 1).
- C2 : le même commit avec contrat épinglé passe.
- C3 : deux sessions ne peuvent pas porter le même alias vivant (test sur l'outil de rattachement).
- C4 : un GO non tracé ne modifie pas le catalogue.
- C5 : la matrice est vérifiée par un test qui, pour chaque rôle, tente une écriture et attend le résultat de la ligne.

## 9. Points d'arrêt humain

- Toute écriture dans `CODE/`, `CODE_XML/`, `TASKS.yaml`, `task_scope.py` ou un fichier de garde : GO exploitant par fichier.
- Toute activation d'un garde bloquant : GO explicite, après période en avertissement.

## 10. Non tranché

- « Pas de commit sur `CODE/` » ou « pas d'écriture du tout » : la réponse change le mécanisme.
- Qui porte le rôle de responsable du catalogue (TORC-CC10 est hors catalogue ; aucun GO tracé).
- Sort des 10 tâches attribuées à `CC01`.
