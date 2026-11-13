# Challenge A/B — contrat de `/connect-session-supervisor`

Date : 2026-11-13  
Périmètre : rattachement Superviseur, alias agent, titre de tâche et résultat affiché.  
Mode : lecture seule pour les reviewers ; aucune écriture ni API Superviseur réelle pendant le challenge.

## Étape 0 — cadrage

Verdict : GO conditionnel pour un audit et une matrice de décision. Le titre officiel de tâche doit être séparé de la mission libre. `T000` et « sans tâche formelle » sont deux scénarios distincts. Aucun ID ou titre ne doit être inventé.

## Revue indépendante A — architecture

- L’ID agent de session est porté par le suffixe canonique de l’alias ; il est distinct du propriétaire de tâche indiqué dans `TASKS.yaml`.
- Le code acceptait une tâche inconnue ou sans titre et ne vérifiait pas que l’ID de l’alias correspondait à l’ID tâche fourni.
- Une affectation existante était déclarée `already_assigned` sans comparer les champs de rattachement.
- Recommandation : titre officiel unique pour une tâche formelle ; refus si absent ou ambigu ; titre explicite pour T000 ; mission conservée séparément.

## Revue indépendante B — Red Team

- Le code permettait un alias d’une tâche différente de `--task`.
- Un titre de mission libre pouvait remplacer un titre officiel absent.
- `--confirm-without-task` contournait la validation stricte de l’alias.
- Le second cycle a détecté un cas catalogue réel `T417-C` non pris en charge par le parseur initial, et une preuve de test manquante pour la divergence de titre sur un alias identique.

## Arbitrage C

- Tâche formelle : ID présent une seule fois dans `TASKS.yaml`, titre officiel non vide et unique.
- Agent de session : suffixe canonique de l’alias ; la partie tâche de l’alias doit correspondre à l’ID fourni. Le propriétaire de tâche reste un champ distinct.
- T000 : titre explicite requis.
- Suivi sans tâche formelle : seulement après confirmation ; il est stocké comme `T000` avec alias agent et titre explicite.
- `--mission` reste distinct du titre.
- Une session native déjà reliée avec alias/tâche/titre différents est refusée sans écrasement silencieux.

## Corrections et preuves

- `connect_session.py` résout le titre officiel, valide l’ID tâche et l’alias, renvoie `task_id`, `agent_id` et `task_title`, et refuse les titres absents/ambigus.
- `supervisor_service.py` expose le titre de la première ligne lisible dans `/api/supervision/summary` après connexion et renommage.
- Les skills de connexion et `AGENTS.md` décrivent désormais les champs et le parcours Codex.
- Parcours intégrés contre le vrai serveur local isolé : `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_connect_session.py TOOLS/AGENT_WORKFLOW/tests/test_rename_session.py TOOLS/AGENT_SUPERVISOR/tests/test_standalone.py -q` → **31 passed**.
- Contrat : `check_task_contract.py DOC/WFLOW/TASKS/T000_SESSION_NAMING/T000_SESSION_NAMING_CONTRAT_20261113_v1.0.yaml` → **PASS, 0 erreur, 0 avertissement**.
- `git diff --check` sur les fichiers du périmètre → **PASS**.

## Limites restantes

- Aucun rattachement réel de la session Codex active n’a été exécuté ; son prévol précédent indiquait qu’elle n’était pas liée.
- Codex charge les skills du projet depuis `.agents/skills/` ; la documentation officielle décrit l’invocation via `$<skill>` ou `/skills`, pas un alias slash personnalisé direct. Un rechargement du CLI est nécessaire pour rafraîchir le catalogue.
- Le titre d’onglet terminal VS Code n’a pas été observé visuellement. Le jalon de renommage global reste donc ouvert.
