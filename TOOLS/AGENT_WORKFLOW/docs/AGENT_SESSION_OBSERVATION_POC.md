# POC — sources de conversations et supervision des agents

**État :** inventaire des sources validé localement le 2026-11-02 ; capture continue et juge non implémentés.  
**But :** savoir où lire les conversations, comment démarrer une session capturable et comment affecter explicitement les sessions à surveiller, sans prétendre observer toutes les fenêtres ouvertes.

**Périmètre décidé :** surveillance de Claude Code, Codex CLI et Antigravity (`agy`). **DSH et OpenCode sont exclus** de l’intégration ; ils apparaissent uniquement dans l’inventaire initial.

## Résumé opérationnel

- `agent_data_source_poc.py` découvre les emplacements de données et leurs métadonnées. Il ne lit pas les conversations et ne lance aucun agent.
- Les modes JSON/stream des CLI s’appliquent à une **nouvelle exécution lancée avec ces options**. Ils ne transforment pas rétroactivement un terminal TUI déjà ouvert en flux structuré.
- Pour les sessions existantes, il faut identifier et suivre leur fichier, leur base ou leur serveur précis. Un nom de processus ou le texte visible dans un terminal ne suffit pas à associer sûrement une session.
- Le futur superviseur doit surveiller uniquement les sessions que l’utilisateur lui affecte. L’écran doit montrer clairement ce qui est suivi, par quelle source et depuis quand.
- Le POC ne change ni les hooks, ni Task Manager, ni Terminal Keeper, et ne démarre aucun processus durable.

## Lancer l’inventaire

Depuis la racine du dépôt :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/agent_data_source_poc.py
python TOOLS/AGENT_WORKFLOW/scripts/agent_data_source_poc.py --scan
python TOOLS/AGENT_WORKFLOW/scripts/agent_data_source_poc.py --json
```

Le mode par défaut affiche les chemins. `--scan` compte récursivement les noms de fichiers et relève leurs dates de modification ; `--json` produit la même inventaire en JSON. Le script ne lit aucun corps JSONL ni aucune ligne SQLite. Pour OpenCode, il peut exécuter `opencode db path` afin de demander au CLI son chemin de base de données.

Chemin du script : [agent_data_source_poc.py](../scripts/agent_data_source_poc.py). Les tests unitaires associés sont dans `TOOLS/AGENT_WORKFLOW/tests/test_agent_data_source_poc.py`.

## Emplacements observés sur ce poste

Les valeurs ci-dessous sont les chemins par défaut observés le 2026-11-02, sans variables de redirection configurées. Le POC résout les chemins à nouveau à chaque exécution ; les comptes sont un instantané et évoluent.

| Outil | Source locale | Format / association | Lancement structuré d’une nouvelle session | Limite importante |
|---|---|---|---|---|
| Claude Code | `%USERPROFILE%\.claude\projects` (`CLAUDE_CONFIG_DIR` peut déplacer la racine) | Transcripts `**/*.jsonl`, y compris sous-agents | `claude -p --output-format stream-json --include-partial-messages --verbose "<prompt>"` | `--verbose` est requis avec `--output-format=stream-json` par le CLI installé. `-p` lance une exécution non interactive distincte ; ce n’est pas la capture garantie d’un TUI existant. |
| Codex CLI | `%USERPROFILE%\.codex\sessions` (`CODEX_HOME` peut déplacer la racine) | Rollouts `**/*.jsonl` | `codex exec --json --sandbox read-only "<prompt>"` | `exec --json` concerne cette nouvelle exécution. Il ne s’attache pas au TUI déjà lancé. |
| Antigravity (`agy`) | `%USERPROFILE%\.gemini\antigravity\brain`, `antigravity-ide\brain`, `antigravity-cli\brain` | `**/transcript.jsonl` ; utiliser l’identifiant de conversation et le chemin transmis par l’outil | `agy --output-format stream-json --mode plan --sandbox -p="<prompt>"` | Le prompt doit être attaché à `-p=` avant les autres arguments selon le CLI installé. Le mode structuré concerne une nouvelle session print-mode. Vérifier le mode et les permissions souhaités avant de lancer une tâche. |
| DSH — inventaire seulement, exclu | `%USERPROFILE%\.dsh\sessions` (`DSH_HOME` peut déplacer la racine) | `**/session.jsonl.zstd`, potentiellement plusieurs instances/harness | Non retenu | La correspondance instance ↔ session ↔ fichier n’est pas prouvée. Pas d’intégration prévue. |
| OpenCode — inventaire seulement, exclu | `%USERPROFILE%\.local\share\opencode\opencode.db` (résolu de préférence par `opencode db path`; `OPENCODE_DB`/`XDG_DATA_HOME` peuvent influer) | Base SQLite ; identifier la session par son ID | Non retenu | Pas d’intégration prévue ; l’information sur `run --format json`/SSE reste un constat du POC, pas une proposition de support. |

### Comptes du scan initial

Au scan du 2026-11-02 : Claude 60 fichiers JSONL, Codex 43, AGY 332 transcripts, DSH 920 sessions dans l’espace de travail courant (926 au total sous la racine DSH), OpenCode une base de 1 178 095 616 octets. Ces nombres décrivent la machine au moment du scan ; ils ne signifient pas que toutes ces sessions sont actives ou autorisées à être lues.

## Quand une session est-elle réellement capturable ?

### Intégration d’une instance — mécanisme retenu pour le POC suivant

L’interface ne doit pas demander seulement « quel outil ? ». Elle doit ajouter une **instance précise** et enregistrer un lien stable : `instance_key`, plateforme, ID natif de conversation, chemin de session (si applicable), répertoire de travail, mode de capture, heure de rattachement et état. L’utilisateur donne un alias lisible, par exemple `Claude — T417-C`.

Deux parcours simples dans Task Viewer :

1. **Ajouter une instance ouverte** : l’adaptateur énumère les sessions de l’outil ; l’utilisateur choisit la ligne qui correspond au terminal/conversation voulu et confirme `Ajouter en lecture seule`.
2. **Lancer une instance suivie** : le bouton lance le CLI dans un terminal visible, conserve son PID et son répertoire, récupère son ID natif puis l’enregistre automatiquement. L’instance reste utilisable normalement ; retirer la surveillance ne ferme jamais son terminal.

| CLI | Ajouter une instance ouverte | Lancer une instance suivie | État de la solution |
|---|---|---|---|
| Claude Code | `claude agents --json --cwd <répertoire>` fournit une liste d’instances et des IDs. Vérifié localement : 4 entrées du dépôt courant. Résoudre ensuite le transcript correspondant à l’ID et surveiller ses ajouts. | Démarrer dans le terminal géré avec un `--session-id <UUID>` créé par le lanceur ; l’ID relie sans ambiguïté la ligne Task Viewer au transcript. `claude attach <id>` reste la voie de réouverture documentée pour les sessions d’arrière-plan. | **Meilleur premier POC** : énumération native vérifiée ; la lecture live du transcript reste à tester. |
| Codex CLI | Le daemon app-server local est présent (version CLI/serveur 0.166.0). Le protocole officiel fournit `thread/list` filtrable par `cwd` et source, `thread/read` avec statut, et `thread/turns/list` sans reprendre le fil. L’utilisateur choisit le fil précis dans les résultats. | Lancer le TUI Codex normal ; le daemon partagé enregistre le thread. Le maître l’associe ensuite par ID retourné par `thread/list`. Pour une nouvelle UI applicative, `codex app-server` sait créer/reprendre un thread et diffuser les événements. | **Voie officielle plausible**, mais la requête locale via `codex app-server proxy` n’a pas encore produit de réponse JSON ; ne pas marquer intégrée avant un POC réussi. |
| AGY | Aucun sous-ordre de liste de conversations n’est exposé par le CLI installé. Afficher les `transcript.jsonl` récents trouvés sous `brain`, avec ID de répertoire et activité ; exiger une sélection/confirmation de l’utilisateur. Ne pas choisir automatiquement « le plus récent ». | Pour une capture déterministe headless : `agy --output-format stream-json --mode plan --sandbox -p="<prompt>"`; le Task Viewer fournit alors le canal de dialogue. Pour garder le TUI normal, lancer visiblement `agy`, puis associer le transcript créé ; associations concurrentes à tester. `--conversation <id>` reprend un ID existant. | **Attach manuel possible par transcript**, mais le lien TUI ↔ ID natif n’est pas encore prouvé. |

Le superviseur n’envoie aucune commande dans le CLI surveillé. `Ajouter` lit ; `Pause` arrête la lecture ; `Retirer` supprime le lien de surveillance. Il ne reprend pas (`resume`), ne relance pas, ne ferme pas et ne répond pas à la place de l’utilisateur.

#### Vérifications locales déjà faites

- `claude agents --json --cwd <repo>` a retourné 4 sessions pour ce dépôt ; seuls ID/nom/statut/répertoire ont été affichés, pas le corps des échanges.
- `codex app-server daemon version` indique un daemon local actif. `codex app-server proxy --sock <socket>` a été interrogé avec `initialize` puis `thread/list` filtré sur le dépôt ; le proxy a quitté avec succès mais n’a renvoyé aucun JSON. Cette tentative est donc **non concluante**, pas un PASS.
- `agy --help` confirme `--conversation`, `--input-format stream-json` et `--output-format stream-json`; ces flux ne valent que pour une exécution CLI lancée avec ces options.

### Session démarrée par une commande contrôlée

Le lanceur doit conserver ensemble au minimum :

1. la plateforme et le chemin de l’exécutable réellement lancé ;
2. les arguments de sortie structurée utilisés ;
3. le répertoire de travail ;
4. l’identifiant de session renvoyé ou extrait de la source locale ;
5. le chemin/endpoint de données associé et l’heure de démarrage ;
6. le consentement et le périmètre de surveillance choisis par l’utilisateur.

La sortie structurée de la commande est le canal de capture privilégié quand elle existe. L’agent superviseur ne doit pas lancer une seconde session pour tenter d’observer la première. Pour garder un TUI interactif visible, capturer le terminal n’est pas le premier choix : utiliser l’ID natif et la source de session du CLI.

### Session déjà ouverte

L’utilisateur ou le lanceur doit sélectionner l’instance précise. L’affectation repose sur un identifiant de session ou un chemin confirmé, pas seulement sur « Claude », « Codex » ou un PID susceptible de changer. Si plusieurs sessions correspondent, l’interface demande un choix ; elle ne les active pas toutes par défaut.

Les fichiers existants permettent parfois un suivi en lecture seule, mais chaque format doit être validé pour l’append/rotation/verrouillage avant d’en faire un flux live. Pour le périmètre retenu, il reste à valider le suivi du bon JSONL Claude/Codex et du transcript AGY. DSH et OpenCode ne seront pas intégrés.

## Contrat proposé pour l’observateur

Un seul **agent maître de supervision** (processus de contrôle) suit les sessions sélectionnées parmi Claude Code, Codex et AGY. Il garde un état et un contexte borné distincts par session. À l’arrivée d’un message pertinent, il peut appeler Ollama comme **juge ponctuel** pour cette session, puis consolider les alertes. L’utilisateur s’adresse au maître ; les juges ne pilotent pas les terminaux et ne modifient rien.

Ne pas présumer qu’un processus LLM permanent par terminal est nécessaire. Le superviseur doit assurer l’isolation des contextes. Un juge/worker distinct par session ne sera envisagé que si un essai mesuré montre un gain de cohérence ou de latence, après évaluation de la mémoire, de la concurrence et du contexte consommé. Le premier POC cible un maître unique capable de suivre deux sessions simultanées avec contextes séparés.

Chaque affectation est indépendante : l’utilisateur peut ajouter, mettre en pause ou retirer une session sans démarrer ou arrêter les autres.

Pour chaque affectation, conserver un état minimal :

| Champ visible | Sens |
|---|---|
| Alias / plateforme | Ex. « Claude — tâche T417-C » |
| Session | ID ou chemin abrégé, avec possibilité de confirmer l’instance |
| Capture | `stream CLI`, `transcript`, `DSH zstd`, `OpenCode SSE` ou `indisponible` |
| Surveillance | `arrêtée`, `en attente`, `active`, `retard`, `erreur` |
| Dernière activité | Heure du dernier événement effectivement lu |
| Juge | Modèle/configuration et heure de dernière analyse ; `non configuré` si absent |
| Alertes | Faits détectés, extrait minimal et raison ; jamais un verdict automatique de réussite |

Le superviseur LLM est un **détecteur consultatif** : il reçoit les nouveaux messages pertinents, garde un contexte borné par session et émet une alerte explicable. Le maître identifie toujours l’instance source. Il ne modifie ni les fichiers, ni les sessions, ni le catalogue de tâches, ni les réponses des agents. Les preuves de tests restent déterministes et consultables à part.

## Intégration d’interface envisagée — à ne pas confondre avec le POC

Le point d’accès naturel à évaluer est le [Task Viewer](../../../DOC/WFLOW/TASK_VIEWER.html), déjà utilisé par l’utilisateur. Ajouter éventuellement un bouton compact « Supervision » près des commandes de l’orchestrateur, sur le modèle du bouton OmniDiag, ouvrant un panneau unique : sessions disponibles, sessions suivies, dernier événement et alertes, plus commandes `Ajouter`, `Pause`, `Retirer`.

Cette proposition ne justifie pas encore de modifier Task Viewer : il faut d’abord démontrer les flux live pour au moins une nouvelle session et une session existante, la sélection non ambiguë, l’arrêt propre, et les erreurs de source absente. Le chat direct avec le superviseur est une étape séparée ; le panneau doit déjà permettre de savoir ce qui est surveillé sans ouvrir une page de rapports supplémentaire.

Terminal Keeper n’a pas besoin d’être remplacé. Un lanceur supervisé peut, ultérieurement, ouvrir les CLI avec les bons arguments et enregistrer leur identité ; l’utilisateur doit pouvoir continuer à les voir/utiliser comme terminaux normaux. Cette interaction avec Terminal Keeper et le comportement de fenêtres visibles/invisibles restent à vérifier avant toute intégration.

## Critères avant d’activer une surveillance continue

1. Démontrer la capture d’un message utilisateur et d’une réponse sur une nouvelle exécution par CLI.
2. Démontrer la sélection puis la capture d’une session déjà ouverte, sans observer une autre session.
3. Démontrer les états `active`, `retard`, `erreur`, puis arrêt/reprise ; une source absente ne doit pas apparaître comme active.
4. Afficher clairement la plateforme, l’ID, la source et la dernière activité de chaque affectation.
5. Garder les sessions non sélectionnées hors surveillance et pouvoir retirer une affectation immédiatement.
6. En cas de juge indisponible ou de réponse mal formée, afficher `analyse indisponible` ; ne pas fabriquer une alerte, un PASS ou un blocage.
7. Commencer par un outil, un maître et un modèle local ; puis tester deux sessions simultanées avec contextes isolés. Étendre à Claude, Codex et AGY après validation séparée. DSH et OpenCode restent exclus.

## Ce que le POC ne prouve pas

- que les chemins restent les mêmes sur une autre machine ou après configuration d’un profil ;
- qu’un fichier de transcript peut être lu pendant qu’il est écrit sans perte ni doublon ;
- que les IDs de session sont visibles et sélectionnables dans chaque UI ;
- que les trois CLI du périmètre peuvent être lancés/attachés via un terminal géré ;
- que le superviseur Ollama peut fonctionner de façon persistante, à faible coût ou avec une latence donnée ;
- qu’un hook est nécessaire ou souhaitable. Aucun hook global n’est activé par ce POC.

## Résultats des cas de fiabilité — 2026-11-02

### Tests unitaires des deux POC

Commande : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_agent_data_source_poc.py TOOLS/AGENT_WORKFLOW/tests/test_agent_session_watch_poc.py -q -p no:cacheprovider`  
Résultat au dernier run : **14/14 PASS** (6 inventaire + 8 association/lecture JSONL).

| Cas | Résultat | Portée réelle |
|---|---|---|
| Racines synthétiques Claude/Codex/AGY/DSH/OpenCode | PASS | Le scanner compte les emplacements/fichiers ; le contenu de conversation synthétique n’est pas affiché. |
| Variables `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `OPENCODE_DB` | PASS | Les chemins personnalisés sont pris en compte. |
| `OPENCODE_DB` relatif | PASS | Résolution sous le répertoire de données prévu. |
| Racines/CLI absents avec `--scan` | PASS | L’inventaire renvoie zéro et ne plante pas. |
| Interdiction d’ouvrir un transcript pendant le scan | PASS | Le test fait échouer tout appel `open`; le scanner n’utilise que noms et métadonnées. |
| `opencode db path` en timeout | PASS | Retour au chemin par défaut, marqué comme fallback et absent. |

Ces cas valident le **repérage de sources**, pas l’association sûre à une instance ni l’observation d’échanges live.

| Cas association/lecture JSONL | Résultat | Portée réelle |
|---|---|---|
| ID natif exact : absent, unique, préfixe seulement ou doublonné | PASS | Aucun choix par nom partiel ni par récence ; absence et ambiguïté sont des états distincts. |
| Attachement au milieu d’un transcript | PASS | L’historique avant l’attachement n’est pas rejoué. |
| Un ajout et plusieurs polls | PASS | Enregistrement ajouté émis une seule fois dans le test. |
| Ligne JSON fragmentée sur deux polls | PASS | Aucun événement prématuré ; ligne émise complète à réception du saut de ligne. |
| Deux instances choisies, événements intercalés, une source supprimée | PASS | Aucun croisement d’événements ; perte de A n’affecte pas l’état de B. |
| Troncature / remplacement du fichier | PASS | `source_reset` visible, nouveau contenu ignoré au premier poll de resynchronisation. |
| Suppression de la source | PASS | État `source_missing`, jamais `active`. |
| JSON mal formé | PASS | État `parse_error`, curseur conservé avant l’enregistrement fautif ; l’erreur ne disparaît pas au poll suivant. |

Ces tests portent sur des fichiers temporaires synthétiques ; ils ne prouvent pas à eux seuls le comportement du writer Claude en situation réelle.

### Vérifications runtime des CLI

| Cas | Observation | Verdict |
|---|---|---|
| Claude — énumération par `claude agents --json --cwd <repo>` | 4 candidats distincts ; l’ID court diffère du `sessionId` complet. Le `sessionId` complet associe 3 transcripts ; 1 candidat n’a pas de fichier correspondant. Les 4 états rapportés sont `blocked`. | 🟠 Liste native exploitable, mais l’UI doit utiliser `sessionId`, distinguer état bloqué et actif, et déclarer une source manquante au lieu de simuler une surveillance active. |
| Claude — nouvelle instance supervisée | Une session neuve lancée avec ID explicite, `--tools ""`, mode plan et sortie `stream-json --verbose` a terminé code 0 en 17 s. L’ID du flux correspond au transcript exact ; le watcher a lu les événements `user`/`assistant` sans parse error ni affichage du texte. | ✅ Capture fichier d’une nouvelle session Claude prouvée pour ce chemin CLI ; le premier essai sans `--verbose` a été rejeté par le CLI et a permis de corriger la commande. Session non interactive, donc pas encore preuve d’attachement à un TUI ouvert. |
| Codex — nouvelle instance `codex exec --json --sandbox read-only` | Code 0 ; événements `thread.started`, `turn.started`, `item.completed`, `turn.completed`. Le `thread_id` a résolu exactement un fichier rollout ; le watcher l’a parsé sans erreur. | ✅ Lancement structuré et correspondance ID → fichier prouvés pour une exécution non interactive. |
| Codex — daemon/app-server pour les sessions du TUI | Daemon `0.166.0` annoncé actif. Une requête `initialize` + `thread/list` via `codex app-server proxy` s’est terminée avec code 0 mais sans réponse JSON. | 🔴 Rattachement à une session TUI non prouvé ; ne pas l’afficher comme surveillée. |
| AGY — nouvelle instance | Après correction de la syntaxe `-p="<prompt>"`, code 0 en ~67 s ; 5 lignes JSON parseables. Un ID de conversation correspond à l’unique transcript modifié pendant l’essai. L’essai a capturé le processus après sa fin, sans vérifier le flux en direct ni classifier les événements (pas de champ `type`). | 🟠 Lancement et association post-run prouvés ; schéma de message et capture live non validés. Le premier essai, avec `-p` séparé des options, a été rejeté avant exécution. |
| AGY — inventaire existant | Le scan trouve 332 `transcript.jsonl`. Le CLI n’expose pas de commande de liste de conversations dans son aide locale. | 🟠 Une instance interactive active n’est pas distinguée des anciennes ; sélection et suivi live non testés. |

### Verdict actuel

Les tests synthétiques prouvent l’association exacte, l’isolation entre deux sessions et la lecture incrémentale du watcher. Les lancements contrôlés Claude et Codex émettent des événements structurés associés exactement à un ID natif ; pour AGY, seule l’association post-run a été prouvée. **Verdict : le POC de sources/watcher est partiellement fiable ; le système complet de supervision n’est pas encore fiable/validé.** Le rattachement à des TUI déjà ouverts reste non démontré (Codex proxy sans réponse ; AGY sans index d’instances actives ; Claude sans source transcript pour 1 candidat). Restent à vérifier la capture live AGY, l’interface d’affectation, le maître Ollama, les alertes, plusieurs sessions simultanées runtime, et l’arrêt/reprise.



## Impl?mentation de continuit? ? lot en cours

Le r?solveur rejette les m?tacaract?res et compare les noms litt?ralement. Le watcher v?rifie une empreinte SHA-256 du pr?fixe consomm? (lecture par blocs, co?t proportionnel ? l?historique). Une modification d?tect?e produit `source_reset` persistant : appeler explicitement `reattach(start_at_end=True)` pour ignorer l?historique ou `reattach(start_at_end=False)` pour le rejouer. Ce choix doit ?tre affich? par le futur appelant.

Si la source manque ? la construction en mode fin, son apparition ne rejoue pas l?historique. Une erreur d?acc?s retourne `source_error` sans avancer le curseur ; le prochain poll peut r?essayer. Pas de service permanent ni d?interface d?affectation livr? ? ce stade. Les courses entre lecture et ?criture restent soumises ? la revue ind?pendante et aux essais runtime.

Validation cibl?e interm?diaire : 17 tests PASS. Cela couvre les nouveaux contre-exemples statiques ; capture live et rattachement TUI restent non valid?s.


## ?tat apr?s impl?mentation et essais contr?l?s ? 2026-11-02

### Utilisation du collecteur

Pour une conversation d?j? ouverte et dont l?ID natif est connu :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_watch_poc.py --platform claude --root "$env:USERPROFILE/.claude/projects" --session-id <ID> --duration 60
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_watch_poc.py --platform codex --root "$env:USERPROFILE/.codex/sessions" --session-id <ID> --duration 60
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_watch_poc.py --platform agy --root "$env:USERPROFILE/.gemini/antigravity-cli/brain" --session-id <ID> --duration 60
```

Le collecteur ne lance ni ne reprend le CLI observ?. Sortie JSONL de m?tadonn?es par d?faut ; `--include-content` autorise explicitement l?impression des messages. `--from-beginning` rejoue volontairement l?historique ; sinon le rattachement commence ? la fin. Toute rupture de source suspend la lecture (code retour 3) ; relancer explicitement le collecteur apr?s avoir choisi la politique de replay. Une source absente/ambigu? ?choue (code 2). Un refus d?acc?s transitoire garde le curseur et est r?essay? au poll suivant. La p?riode par d?faut est 250 ms, param?trable ; ce n?est pas une garantie de latence du writer CLI.

Chemins associ?s litt?ralement : Claude `**/<ID>.jsonl` ; Codex `**/rollout-?-<ID>.jsonl` ; AGY `<ID>/.system_generated/logs/transcript.jsonl` (format observ?) ou `<ID>/transcript.jsonl` (ancien format). Deux candidats restent une ambigu?t?. Les pr?fixes hash?s sont relus par blocs pour d?tecter les r??critures ; le co?t augmente avec la taille de la conversation et doit ?tre mesur? avant service permanent.

### Reproduction du lancement contr?l?

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_runtime_probe.py claude --output <preuve.json>
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_runtime_probe.py codex --output <preuve.json>
python TOOLS/AGENT_WORKFLOW/scripts/agent_session_runtime_probe.py agy --output <preuve.json>
```

Chaque commande lance une nouvelle session de test dans un dossier temporaire syst?me avec un marqueur unique et une demande sans outil. Claude d?sactive les outils ; Codex utilise le sandbox lecture seule ; AGY utilise les options plan/sandbox du CLI install?. Le script conserve PID, ex?cutable, ID, chemin, ?tats et ?v?nements horodat?s dans la preuve ; les sorties brutes restent dans le dossier temporaire. Il lit en parall?le le flux stdout et le transcript de cette seule session. Les flags structur?s sont n?cessaires pour ce parcours ; le rattachement par fichier ? un TUI existant ne n?cessite pas de relancer ce TUI avec ces flags.

### R?sultats et limites

| Parcours contr?l? | Claude | Codex | AGY |
|---|---|---|---|
| R?ponse marqu?e sur stdout pendant ex?cution | 8,75 s | 4,59 s | 41,97 s |
| R?ponse marqu?e dans le transcript pendant ex?cution | 9,03 s | 4,60 s | 41,98 s |
| TUI d?j? ouvert, rattachement EOF puis nouveau message et r?ponse | PASS | PASS | PASS |
| Fermeture du TUI de test | code 0 | code 0 | code 0 |

Preuves : `DOC/WFLOW/REVIEWS/AGENT_CAPTURE_LIVE_<PLATEFORME>_20261102.json` et `AGENT_CAPTURE_TUI_<PLATEFORME>_20261102.json`. Les essais TUI ont utilis? des sessions cr??es par le banc, puis observ?es une fois ouvertes/au repos ; aucune conversation utilisateur inconnue n?a ?t? lue. Les d?lais ci-dessus sont des temps depuis le lancement, incluant g?n?ration et initialisation, pas une latence garantie du collecteur.

Claude et Codex ont aussi ?t? lanc?s simultan?ment : aucun marqueur de A dans le flux de B, ni inversement. Le proxy daemon Codex reste non valid? (aucune r?ponse `initialize` re?ue, m?me entr?e standard ouverte) ; le parcours par fichier avec ID exact fonctionne ind?pendamment de ce proxy. L??num?ration et l?affectation graphique d?un terminal arbitraire, la reprise persistante apr?s red?marrage, les conversations volumineuses et le juge s?mantique restent hors validation.


R?ception cibl?e : **27/27 tests PASS** ; deux reviews finales sans bloqueur restant apr?s correction du rejet des suffixes d?UUID Codex. Le lanceur de probe refuse d??craser un fichier de preuve existant et expose la limite d?arr?t au timeout (PID direct seulement). Les hooks/configurations utilisateur restent applicables ; la consigne sans outils n?est une d?sactivation m?canique compl?te que pour Claude. Manifestes et p?rim?tre exact : `DOC/WFLOW/REVIEWS/AGENT_CAPTURE_VALIDATION_20261102.json`.
