# Reprise des urgences CLI — 2026-11-18

Demande active : mêmes données de statut sous Claude, Codex et Antigravity ; commandes
de lancement des rôles projet ; veille et événements proactifs du coordinateur.

Le contrat T432 v1.1 exclut les workflows depuis le 16 novembre. Cette note conserve
la nouvelle demande et ses dépendances T427 sans réécrire ce contrat ni le catalogue.
Les fichiers partagés AGENTS.md, plan T427 et skill workflow-project ont déjà des
modifications tierces au démarrage de cette reprise : ne pas les écraser.

## Jalons et preuves attendues

1. Collecte commune : titre court, alias, liaison et état Superviseur, compteurs
   d'alertes, fraîcheur des données, voie/étape workflow et Git. Les données inconnues
   restent inconnues. Une session ne reprend jamais les données d'une autre.
2. Affichage : raccorder les trois CLI au même collecteur et observer réellement les
   trois rendus. Codex local 0.169.0 : configuration actuelle composée d'identifiants
   natifs (thread-name, model-with-reasoning, run-state, context-remaining).
   Vérifier la capacité locale avant d'appliquer une option trouvée dans la branche
   main d'OpenAI : les versions peuvent différer. Pas de titre de chat détourné en
   statut dynamique ni de résultat annoncé depuis une seule sortie Python.
3. Commandes : adapter les entrées orchestrateur/coordinateur aux surfaces réellement
   supportées en réutilisant workflow_state.py et les fiches de rôle. Vérifier la
   découverte et l'invocation sur sessions isolées, puis sur les trois CLI réels.
4. Veille : attentes explicites par session, échéance, détection d'événement,
   déduplication, reprise après redémarrage, arrêt et escalade. Un événement informe
   le coordinateur ; il ne donne aucune permission supplémentaire. Prouver le réveil
   réel d'une session inactive avant d'annoncer une veille proactive opérationnelle.

## Travail de cette reprise

- Ajout de session_status_snapshot.py : collecte JSON/texte, réutilisation des lecteurs
  existants, un seul appel Superviseur, aucune écriture du titre terminal.
- Sortie réelle de cette session : alias absent, Supervisor Not Linked, workflow
  non démarré. Le rattachement rapporté le 16 n'est pas une preuve de l'état du 18.
- Tests dédiés : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_session_status_snapshot.py
  -q -p no:cacheprovider` : code 0, `3 passed in 0.20s`.
- Tests existants : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py
  TOOLS/AGENT_WORKFLOW/tests/test_statusline_workflow_git.py -x -q -p no:cacheprovider` :
  code 1, `1 failed, 18 passed in 0.71s`. Premier écart : test_workflow_badge_is_plain_when_workflow_is_off
  attend un ancien emoji absent du rendu actuel. Décider le rendu attendu avant de
  changer ce test ; cet échec ne prouve pas un défaut de connexion au Superviseur.
- Ajout de workflow_role.py et ROLE_COMMANDS.md : résolution d'identité commune,
  transitions via workflow_state.py, adaptateurs `.agents/skills` et `.dsh/skills`
  des deux rôles, commandes Claude reliées à la procédure commune.
- Un essai en subprocess a révélé que `workflow_state.py cmd 2 --session ID` absorbe
  l'option comme texte et renvoie code 2. Le lanceur utilise maintenant `voie 2
  --session ID` ; un garde teste la transition réelle dans un état isolé.
- Ajout de coordinator_events.py : surveillances de fichiers explicitement désignés,
  échéances, boîte durable SQLite par session, acquittement et attente bornée. Aucun
  envoi à un autre agent ni exécution arbitraire de commande.
- Contrôles : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_coordinator_events.py
  TOOLS/AGENT_WORKFLOW/tests/test_workflow_role.py TOOLS/AGENT_WORKFLOW/tests/test_session_status_snapshot.py
  -q -p no:cacheprovider` : code 0, `12 passed in 0.46s`.
- Codex installé : 0.169.0. Source officielle au tag rust-v0.169.0 :
  `codex-rs/tui/src/bottom_pane/status_line_setup.rs`, WorkspaceHeadline réservé à
  Enterprise. Le code de la branche main contient des mécanismes absents du tag :
  ne pas les configurer comme s'ils étaient disponibles sur le poste.
- Intégration UI des trois statuslines, observation des menus et réveil autonome
  d'un chat inactif : toujours non livrés. Les nouveaux adaptateurs sur disque ne
  prouvent pas leur découverte par des CLI déjà ouverts.

## Suite : collecte native et vérification du poste

- `session_statusline.py` expose désormais `build_status_snapshot`, utilisé à la
  fois par son rendu natif et par `session_status_snapshot.py` : les données ne sont
  plus assemblées séparément dans les deux entrées.
- Configurations lues, sans modification : Antigravity appelle directement ce script.
  Claude appelle EchoMemory, qui relaie sa commande précédente via
  `~/.echomemory/statusline/chain.json` ; cette commande est le même script projet.
  Le relais EchoMemory est conservé.
- Les deux skills de rôle figurent maintenant dans le catalogue de skills injecté
  dans cette session Codex : découverte par ce chat constatée, pas encore preuve
  visuelle de leur affichage dans le menu d'une autre session.
- Test subprocess de veille ajouté : enregistrement d'une échéance, attente réelle,
  sortie de l'événement, persistance jusqu'à acquittement, puis boîte vide.
- `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_coordinator_events.py
  TOOLS/AGENT_WORKFLOW/tests/test_workflow_role.py TOOLS/AGENT_WORKFLOW/tests/test_session_status_snapshot.py
  TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py -q -p no:cacheprovider` :
  code 0, `30 passed in 1.62s`.
- Question envoyée à l'exploitant : accepter une barre compagnon commune près du
  terminal ou exiger le footer natif Codex. Ne pas substituer une surface à l'autre
  sans réponse. La version locale n'expose pas la commande de footer recherchée ;
  aucun binaire ni configuration globale Codex n'a été remplacé.

Question envoyée à l'exploitant : confirmer les deux rôles (le message cite deux fois
coordinateur). En attendant, les données communes de statut restent indépendantes.
