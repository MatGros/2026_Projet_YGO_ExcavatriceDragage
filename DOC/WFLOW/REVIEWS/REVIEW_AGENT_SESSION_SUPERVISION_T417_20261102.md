# Revue contradictoire — supervision d’instances CLI et risques de faux verdict

**Date :** 2026-11-02  
**Objet :** cadrer une supervision en lecture seule des conversations Claude Code, Codex CLI et Antigravity, et challenger sa pertinence au regard des essais CI de simulation M3/T417.  
**État de preuve :** rapport préparé pour deux revues indépendantes. Ce rapport n’implémente pas de superviseur, n’active aucun hook, ne change pas le Task Manager et ne lance aucun CLI agent surveillé.

## 1. Décision à éclairer

L’utilisateur veut pouvoir affecter explicitement une ou plusieurs instances CLI à un superviseur maître, qui lit les échanges, conserve un contexte isolé par session et signale rapidement les écarts sérieux. Le maître peut utiliser un juge Ollama ponctuel. Claude Code, Codex et AGY sont dans le périmètre ; DSH et OpenCode sont exclus. La supervision doit rester consultative : elle n’est ni preuve de test, ni autorité de tâche, ni contrôle de sécurité machine.

La revue doit répondre à trois questions :

1. Quelle voie d’intégration peut observer de façon attribuable une **nouvelle instance** et une **instance TUI déjà ouverte**, sans confusion entre sessions ?
2. Quels garde-fous minimaux préviennent les fausses alertes, les pertes de messages, les faux états « active » et les affirmations non étayées ?
3. Est-ce que cette supervision améliore réellement la confiance sur les essais de simulation M3, ou risque-t-elle de donner une seconde illusion de validation ?

## 2. État vérifié à la préparation de la revue

### POC de supervision

Le dépôt contient cinq fichiers non suivis dans le checkout principal au moment de la préparation :

- `TOOLS/AGENT_WORKFLOW/scripts/agent_data_source_poc.py`
- `TOOLS/AGENT_WORKFLOW/scripts/agent_session_watch_poc.py`
- `TOOLS/AGENT_WORKFLOW/tests/test_agent_data_source_poc.py`
- `TOOLS/AGENT_WORKFLOW/tests/test_agent_session_watch_poc.py`
- `TOOLS/AGENT_WORKFLOW/docs/AGENT_SESSION_OBSERVATION_POC.md`

Le dernier résultat rapporté pour les tests ciblés est **14/14 PASS**. Ces tests utilisent des sources synthétiques. Ils valident l’inventaire de métadonnées et certaines propriétés de lecture incrémentale JSONL ; ils ne démontrent pas un service permanent, une interface d’affectation, un juge Ollama, une qualité d’alerte ni le suivi fiable d’un terminal TUI déjà ouvert.

### Résultats runtime consignés dans le POC

| Plateforme / chemin | Preuve consignée | Limite / verdict actuel |
|---|---|---|
| Claude — `claude agents --json` | 4 candidats ; 3 `sessionId` complets associent un transcript exact ; 1 sans transcript. Tous les états rapportés étaient `blocked`. | Liste exploitable avec ambiguïtés d’état/source ; l’attachement TUI n’est pas établi. |
| Claude — nouveau lancement non interactif | Session avec ID explicite, `--tools ""`, mode plan et `stream-json --verbose`, code 0 ; transcript associé à l’ID et événements user/assistant lus. | Preuve limitée à cette nouvelle exécution contrôlée ; pas d’attachement à un TUI existant. |
| Codex — `codex exec --json --sandbox read-only` | Nouveau run code 0 ; `thread_id` associé à un seul fichier rollout et événements JSONL lus. | Nouvelle exécution uniquement. |
| Codex — app-server / TUI existant | `initialize` + `thread/list` terminés code 0, mais aucune réponse JSON reçue. | **Non prouvé** : ne pas déclarer la session TUI suivie. |
| AGY — nouveau lancement | Syntaxe corrigée `agy ... -p="<prompt>"` ; code 0 ; 5 lignes JSON ; ID relié au transcript modifié pendant l’essai. | Association post-exécution seulement ; flux live et schéma d’événements non validés. |
| AGY — instance préexistante | Aucune liste de sessions actives obtenue depuis l’aide locale ; inventaire de transcripts uniquement. | Une archive n’identifie pas une instance active. Attachement non prouvé. |

Le détail et les limites sont dans `TOOLS/AGENT_WORKFLOW/docs/AGENT_SESSION_OBSERVATION_POC.md`, section « Résultats des cas de fiabilité — 2026-11-02 ».

### Contexte simulation M3 / T417

Le worktree `.claude/worktrees/t417-cd` est sur `work/t417-cd-poc-prg`, commit observé `d798de72` (« trace CI réelle + revue autonome… »), mais **n’est pas propre** : modifications locales du POC et beaucoup de nouveaux artefacts/scratchs associés à P6 sont présents. Ils n’ont pas été modifiés par cette revue et ne doivent pas être nettoyés par les reviewers.

Le rapport `DOC/WFLOW/ETUDES/ANALYSES_T417/T417C_POC_CI_PRG_20261101.md` qualifie P6 ainsi : PRG_02 à PRG_06 réels (219 objets ; PRG_04 réel exécuté après correction du macro-runner), PRG_07 coquille, physique treuil simulée et substitutions déclarées. H-LOCK treuils a des cas conformes, avec un cas W3 initialement partiel puis W3b conforme après relâchement 600 ms. Le rapport mentionne aussi un défaut du runner : horloge remise à zéro entre TEST alors que l’état global persistait ; correction T8 rejouée, sans changement des verdicts antérieurs revendiqués. L’intégration complète PRG02–07 et l’équivalence CODESYS restent explicitement **non validées**. Le retour variateur réel (StatusWord/fréquence) reste une suite possible.

Les paliers T417-C/D déjà présentés précédemment prouvaient des morceaux de chaîne CI avec substitutions et limites déclarées. Même une supervision de chat parfaite ne prouverait pas la fidélité des transformations, l’identité du binaire/test exécuté, les sorties terrain ni l’équivalence au runtime CODESYS. Elle peut aider à repérer une affirmation disproportionnée ; la preuve technique reste le manifeste des sources, les entrées/sorties capturées, les mutations discriminantes et le résultat des bancs identifiés.

## 3. Audit technique ciblé du watcher

Fichier : `TOOLS/AGENT_WORKFLOW/scripts/agent_session_watch_poc.py`.

| Lignes | Fait observé | Portée |
|---|---|---|
| 22–38 | Résolution d’un nom `<session_id>.jsonl` par `root.rglob(f"{session_id}.jsonl")`; rejette les séparateurs de chemin et les résultats multiples. | Le pattern glob reçoit directement l’ID. L’API ne valide pas que l’ID est un UUID/nom littéral sans métacaractères. Un test adversarial doit vérifier qu’un `?`/`*` ne peut jamais sélectionner un autre fichier. |
| 48–56 | Le watcher démarre à la fin si le fichier existe ; si le fichier n’existe pas au constructeur, son curseur initial est zéro. | Le comportement « attacher avant création » et la reprise après redémarrage ne sont pas couverts par les résultats résumés. Risque de replay d’historique ou d’état de curseur perdu à mesurer. |
| 58–80 | Détecte source manquante, changement d’identité via `st_dev/st_ino`, troncature ; renvoie `source_reset`. | Bonne base de signalement, mais robustesse de rotation/recréation Windows et truncate-regrow entre deux polls à évaluer. |
| 82–115 | Lit les ajouts, garde les lignes partielles, parse les objets JSON ; conserve l’erreur de parsing à l’offset de la ligne fautive. | Couverture synthétique utile. Il faut encore mesurer pertes/doublons et le traitement d’un fichier écrit simultanément par le CLI réel. |

**Défaut P2 déjà reproduit par l’orchestrateur :** un ID n’est pas un motif glob. Avec un fichier `conversation1.jsonl`, l’appel `resolve_jsonl_source(root, "conversation?")` retourne `ready` et sélectionne ce fichier. La validation ne rejette que les séparateurs de chemin ; `Path.rglob` interprète `?` et `*`. Exiger du reviewer une analyse de l’impact réel (IDs natifs attendus, frontière de confiance, gravité), et une expérience de correction/acceptation, sans modifier le code pendant la revue. Une sélection non littérale ne doit jamais choisir une conversation.

**Contradiction documentaire à challenger :** dans `AGENT_SESSION_OBSERVATION_POC.md:61`, la commande AGY headless est écrite avec `agy -p --input-format ...`, alors que le résultat runtime documenté en `:178` indique que cette syntaxe a été rejetée et que `-p="<prompt>"` a été nécessaire. Ne pas propager la commande obsolète sans la qualifier.

## 4. Évaluation indépendante demandée (même contrat pour A et B)

Les deux reviewers reçoivent ce même rapport et le même périmètre, sans accès au résultat de l’autre. Ils travaillent en lecture seule, ne lancent pas de CLI/IDE ni d’essai payant, ne modifient aucun fichier et ne créent pas de branche, tâche ou commit.

Chaque reviewer doit produire :

1. **Verdict** : GO limité / NO-GO / GO sous conditions, avec une phrase expliquant si l’observation des TUI existants est démontrée.
2. **Score sur 100**, justifié par rubrique : traçabilité des preuves 20 ; identité/attribution de session 15 ; couverture des erreurs/reprise 20 ; utilité pour le cycle de simulation M3 20 ; risque de faux verdict et limites de sécurité 15 ; simplicité d’exploitation et effort 10.
3. Au plus **8 constats classés P0/P1/P2**. Pour chacun : affirmation vérifiable, fichier et lignes, contre-exemple ou preuve, test discriminant mesurable, décision affectée. Séparer les faits des hypothèses.
4. Un plan de validation priorisé, limité à **3 étapes**, avec critère chiffré d’acceptation et estimation S/M/L. Inclure explicitement : nouvelles sessions vs sessions déjà ouvertes, deux sessions simultanées, perte/rotation/reprise de source, erreur Ollama, et frontière entre alerte conversationnelle et preuve de test.
5. **Challenge “au-delà du watcher”** : identifier au moins deux façons dont un superviseur pourrait rassurer à tort sur un essai M3/T417 ; proposer comment ses messages devraient référencer la preuve déterministe réelle (commande/run, commit/source manifest, scénario, sorties, résultat) sans devenir un second Task Manager.
6. Auto-revue : signaler toute hypothèse métier manquante, toute limite de leur propre examen et toute affirmation du présent rapport qu’ils n’ont pas pu vérifier.

Barème : un point sans preuve ou sans expérience falsifiable ne compte pas comme finding confirmé. Un accord entre modèles n’est pas une preuve. Ne pas recommander un hook global bloquant sans cas de blocage requis, cas valide admis et modes d’erreur/timeout testés. Ne pas réintroduire DSH/OpenCode, un Task Manager parallèle ou un agent LLM par terminal sans mesure démontrant le besoin.

## 5. Décisions provisoires de l’orchestrateur avant challenge

- **Pas de lancement de superviseur permanent ni de hook bloquant** à ce stade.
- Traiter les lancements structurés de nouvelles sessions comme la piste la plus vérifiable ; traiter l’attachement aux TUI existants comme une fonction non prouvée, à afficher explicitement « indisponible » jusqu’à preuve positive.
- Prototype initial plus simple à évaluer : un orchestrateur local unique, sources explicitement affectées par l’utilisateur, un curseur/context par session, flux capturé directement quand le CLI offre une sortie structurée. Pour les sessions existantes, n’activer qu’un adaptateur propre à la plateforme si l’identité et la complétude du flux sont démontrées.
- Juge Ollama consultatif et borné ; un timeout, une sortie mal formée ou une source perdue produit un état visible « analyse indisponible », jamais une validation ou un blocage implicite.
- L’alerte doit pointer vers les preuves techniques existantes. Elle ne valide jamais les tests à leur place.

## 6. Résultats du challenge indépendant

### Méthode et limites

- Deux appels indépendants, DeepSeek V4.1 Flash puis GLM 5.3 Flash ; même paquet de faits et même demande de challenge, sans résultat A communiqué à B.
- Les modèles n’avaient pas d’accès au dépôt dans ces appels. Le paquet collait les éléments déterminants, le code du résolveur, les résultats runtime et le contexte T417. Leur mission était une revue critique du dossier, pas un audit source autonome.
- Le runner `ollama_subagent.py` a rendu une réponse finale vide lors de trois tentatives DeepSeek. Pour obtenir une réponse exploitable, l’appel a été relancé directement via l’API Ollama avec le préambule projet et le même paquet. Cette voie de repli est documentée ; elle n’a modifié aucune configuration.
- Les résultats ci-dessous sont donc des **avis de challenge**, pas des preuves. Les fichiers de réponses brutes sont restés dans le répertoire temporaire système ; seul le résumé évalué est conservé ici.

| Revue | Modèle | Verdict / score | Constats retenus après vérification |
|---|---|---|---|
| A | DeepSeek V4.1 Flash | GO limité aux nouveaux runs Claude/Codex ; attachement TUI : non prouvé ; **score pondéré omis** | Identité glob, absence de preuve live pour TUI/AGY, limites de preuve simulation. Avis incomplet sur le barème demandé. |
| B | GLM 5.3 Flash | GO limité conditionnel ; TUI : non prouvé ; **55/100** | Identité glob, TUI Codex, AGY/doc contradictoire, liste Claude incomplète, portée des résultats P6. |

### Synthèse indépendante et arbitrage de l’orchestrateur

| Sujet | Accord A/B | Vérification / décision |
|---|---|---|
| `session_id` utilisé comme motif glob | A et B voient un risque d’identité ; B le classe P0. L’agent AGY reproduit `*` et `session-?`. | **Reproductible et confirmé** par deux contre-exemples. Je révise : **P0 comme bloqueur de toute intégration d’affectation/alerte**, car l’identité de session est le contrat central et un ID accepté peut sélectionner un autre transcript. Ce n’est pas un incident opérationnel ni un danger machine démontré : le POC n’est pas branché comme service et les essais ont employé des IDs exacts. |
| Réécriture du JSONL sur place, même inode, taille finale ≥ ancien offset | AGY prédit un `parse_error` persistant, non couvert par les tests. | **Reproduit localement** : fichier initial 72 octets, watcher attaché à l’EOF ; réécriture en place même inode à 111 octets ; deux polls successifs donnent `parse_error/JSONDecodeError`, curseur figé à 72. **P1** : le watcher ne détecte pas cette forme de remplacement et ne récupère pas seul. La fréquence de ce comportement dans les writers CLI reste inconnue. |
| Verrou Windows / WinError 32 | AGY l’affirme comme comportement probable des writers ; aucun essai runtime de verrouillage exclusif fourni. | **Partiellement confirmé** : le code convertit un `OSError` à l’ouverture en `source_error` (`:89–92`), sans retry dans le même appel. Une injection contrôlée `PermissionError(32)` produit bien cet état ; après retrait du verrou simulé, un poll suivant reprend. **Non confirmé** : que Claude/Codex/AGY verrouillent réellement leurs journaux en mode refusant le partage de lecture. Ce n’est donc ni un crash démontré, ni un échec silencieux si l’appelant expose l’état. **P2** : tester le comportement Windows réel et spécifier retry/backoff/état « indisponible transitoire ». |
| Attachement à un TUI déjà ouvert | Les deux concluent qu’il n’est pas prouvé. | **Retenu.** Codex code 0 sans réponse JSON et AGY seulement associé après la fin ne satisfont pas le critère. L’UI devra afficher l’état non prouvé/indisponible. |
| AGY | Les deux relèvent association live non démontrée et commande documentaire contradictoire. | **Retenu comme défaut documentaire + couverture incomplète.** La commande erronée ne prouve pas une panne de l’adaptateur ; le flux live reste à démontrer. |
| Frontière avec la simulation | A et B rappellent qu’un transcript ne prouve pas le comportement machine ; AGY demande de prioriser T417. | **Retenu avec nuance.** Aucun niveau PLr/SIL ne peut être attribué à un observateur de chat, et il ne démontre pas la sécurité mécanique. La supervision vise la qualité du travail agent et les fausses affirmations ; elle peut rester consultative. L’allégation de « machine de 30 tonnes » n’est pas étayée par le dossier. La priorité relative avec T417 est une décision de pilotage, pas une conclusion technique démontrée par cette revue. |
| Signification des 600 ms H-LOCK | AGY parle de « relâchement de frein de 600 ms » comme élément de preuve mécanique. | **Réfuté par le dossier T417** : W3b décrit un relâchement opérateur de 600 ms avant un deuxième geste ; le rapport l’explique par l’interlock de redémarrage et un délai sans demande de 500 ms (`FB_WinchOutputInterlock.st:224`, rapport P6 `:237–240`). Ce n’est pas une mesure du délai mécanique du frein, ni une validation de la tenue du câble. |
| Score et critères numériques | DeepSeek n’a pas fourni le score exigé ; GLM propose 55/100 et plusieurs seuils. | **Avis A incomplet.** Les seuils proposés par B (5 s, ±1 %, 5/6 scénarios, fenêtres 550/600/650 ms) ne sont pas adoptés : ils ne sont pas dérivés d’une période de polling, d’une exigence métier ni d’une tolérance de mesure. Les critères doivent être établis à partir de la cadence observée et des décisions du cycle, sans seuil arbitraire. |

### Décision après challenge

**NO-GO pour toute supervision opérationnelle, toute affectation multi-session et tout usage comme preuve. GO limité à l’investigation POC en lecture seule.** Avant de brancher l’affectation, traiter la résolution par glob et la réécriture sur place. L’attachement des TUI et le comportement de lecture concurrente restent non démontrés. Un maître sémantique Ollama peut rester une hypothèse consultative pour signaler des contradictions conversationnelles ; il ne devient ni juge de sécurité, ni gate, ni preuve. Geler l’interface, les hooks et tout service permanent jusqu’aux preuves de base.

Prochaine décision proposée : avant service/UI, fermer trois écarts mesurables dans cet ordre :

1. **Résolution exacte** : traiter l’ID comme nom littéral ou valider un format natif strict ; tests pour `* ? [ ]`, séparateurs, ID valide, collision et source absente. Critère : aucun ID invalide ne sélectionne un transcript ; un ID valide ne sélectionne que son chemin unique.
2. **Intégrité et indisponibilité de source** : tester réécriture même inode avec tailles plus petite, égale et supérieure au curseur ; rotation/remplacement ; source créée après l’attachement ; `PermissionError` Windows temporaire. Critère : aucune perte/désynchronisation ne reste masquée ; chaque état transitoire et chaque réinitialisation est signalé, puis reprise explicitement définie. Ne pas utiliser seulement `mtime_ns` ou un hash d’en-tête sans démontrer que cela détecte la réécriture au curseur.
3. **Capture live par plateforme et valeur d’usage** : démontrer message entrant + réponse attribués pour nouvelles instances, puis TUI existants et deux sessions simultanées. Le délai maximal sera calculé depuis la cadence de polling et l’exigence d’alerte. Une alerte M3 doit pointer vers run déterministe, hash des sources, scénario, substitutions, sorties et verdict ; elle ne doit jamais produire elle-même un PASS sécurité.

Les essais T417 de complétude PRG02–07, retour variateur simulé et comparaison CODESYS gardent leurs propres critères et preuves. Ils ne sont pas déplacés sous la responsabilité du superviseur conversationnel.

### Vérifications complémentaires après réception de la revue AGY

- Rejoué le paquet unitaire actuel : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_agent_data_source_poc.py TOOLS/AGENT_WORKFLOW/tests/test_agent_session_watch_poc.py -q -p no:cacheprovider` → **14/14 PASS**. Ce vert ne couvre ni les nouveaux contre-exemples glob, ni la réécriture en place, ni les locks runtime.
- Reproduit `resolve_jsonl_source(root, "*")` et `resolve_jsonl_source(root, "session-?")` avec un seul faux fichier correspondant : les deux renvoient `ready` sur `session-1.jsonl`. Le garde-fou actuel ne garantit donc pas une résolution littérale.
- Reproduit aussi ces motifs avec deux fichiers correspondants : le résolveur retourne alors `ambiguous` sans chemin. Donc l’affirmation AGY « choisit arbitrairement le premier parmi plusieurs » est fausse pour l’implémentation actuelle ; le défaut est le cas où un motif erroné ne rencontre qu’un seul candidat. `rglob` parcourt le `root` fourni, pas l’ensemble du disque.
- Reproduit la réécriture sur place : ancien offset 72, même inode, nouvelle taille 111 ; `poll()` renvoie deux fois `parse_error` et garde le curseur à 72. C’est une faiblesse réelle du watcher, distincte d’une simple rotation atomique déjà couverte.
- Vérifié le cas d’attachement avant création : un watcher construit sur un chemin absent démarre à l’offset 0 ; si ce chemin apparaît ensuite avec une ancienne conversation, le premier poll l’émet intégralement. Ce comportement est observable et doit être choisi/documenté explicitement (nouvelle session vs rattachement à une session existante).
- Injecté un `PermissionError(32)` sur l’ouverture : l’appel renvoie `source_error/PermissionError` ; au poll suivant sans erreur, l’état redevient `active`. Cela confirme l’absence de retry interne, mais **ne prouve pas** que les writers des trois CLI provoquent effectivement WinError 32.
- Relu `FB_WinchOutputInterlock.st:224` et le rapport T417 `:237–240` : PT 500 ms concerne le redémarrage/interlock ; les 600 ms de W3b sont un intervalle de relâchement avant second geste, pas une caractérisation du frein mécanique.

### Arbitrage complémentaire du challenge AGY

| Affirmation AGY | Verdict après contre-vérification |
|---|---|
| Glob = « capture arbitraire du premier fichier », risque P0 | **Partiellement juste, gravité révisée.** Un identifiant contenant `*`/`?` peut capturer un mauvais fichier si un seul candidat correspond. Si plusieurs correspondent, le code renvoie `ambiguous`, pas le premier. Le parcours est limité au dossier `root`, non à tout le disque. Je maintiens **P0 comme condition préalable à l’intégration** (aucun usage d’affectation/alerte avant résolution littérale stricte), sans qualifier cela d’incident machine. |
| Réécriture in-place bloque le watcher | **Confirmé au niveau du code et reproduit**, mais aucun élément fourni ne démontre qu’un des writers CLI réécrit ainsi ses transcripts en exploitation. Garder P1 conditionnel jusqu’à vérification du comportement des sources réelles. Ajouter un contrôle de `mtime_ns` ou d’en-tête seul ne suffit pas sans preuve : il faut détecter une modification du contenu déjà parcouru et définir la politique de reprise/replay. |
| Verrous Windows rendent `Path.open` en échec | **Mécanisme possible, occurrence non établie.** Une `PermissionError` devient `source_error`, pas un crash ; l’appelant peut réessayer au poll suivant. Pas de preuve qu’un CLI ouvre son fichier avec un partage refusant la lecture. Le risque concerne l’indisponibilité transitoire et l’UX de reprise, pas une perte silencieuse démontrée. |
| Le superviseur LLM détourne dangereusement l’effort de T417 | **Alerte de priorité utile, conclusion non démontrée.** Le superviseur n’a aucun lien machine ni crédit PLr/SIL ; il ne doit jamais agir sur l’automate ou autoriser un test. Mais un juge consultatif de conversation n’est pas en soi une fonction de sécurité. Le dossier ne mesure pas le temps consommé ni ne démontre un retard causé à T417. Garder cette piste strictement bornée et ne pas construire UI/service tant que les preuves de capture ne sont pas acquises.
| « Les 600 ms protègent le frein/câble » | **Inexact.** P6 W3b attend 600 ms entre gestes pour satisfaire l’interlock anti-redémarrage (délai de code 500 ms). Ce test ne mesure ni le délai mécanique du frein ni la tenue du câble. « Automate réel » doit ici être compris comme des PRG sources réelles dans un banc CI, pas comme essai sur automate ou machine réelle. |

**Décision de priorité :** le retour AGY améliore le challenge en faisant émerger deux défauts de synchronisation importants. Je retiens leurs preuves et leur devoir d’alerte, mais pas les extrapolations sur les writers Windows, le niveau de sécurité machine, la recherche sur tout le disque ou la signification mécanique des 600 ms. Aucun changement de code n’a été fait sur la base de ce retour ; la suite doit d’abord fermer les contre-exemples d’identité et de curseur, puis mesurer le rattachement live. T417 reste un banc CI sur des sources ST réelles avec substitutions déclarées — ni validation CODESYS complète, ni preuve terrain.



## Bilan d?impl?mentation ? 2026-11-02

Les d?fauts glob et r??criture sur place sont corrig?s et couverts par des tests. L?attachement et le polling utilisent un handle stable avec v?rification avant/apr?s lecture ; le curseur est engag? apr?s r?ussite I/O. Une source modifi?e suspend la lecture jusqu?au rattachement explicite. Les erreurs JSON sont verrouill?es sans r?ouvrir le fichier fautif. Le refus Windows exclusif a ?t? exerc? via CreateFileW : erreur visible puis livraison de l??v?nement une seule fois apr?s lib?ration.

La seconde revue A/B a trouv? une course entre hash et lecture et des chemins d?erreur d?acc?s ; ces observations ont ?t? corrig?es. La revue finale porte sur le code courant et les preuves runtime. Les anciens NO-GO de ce rapport d?crivent l??tat ant?rieur et ne sont pas supprim?s.

Les lancements structur?s Claude/Codex/AGY ont tous livr? leur r?ponse marqu?e pendant que le processus ?tait vivant, sur stdout et dans le transcript assign?. Pour chacun, un TUI contr?l? d?j? ouvert/au repos a ensuite ?t? suivi depuis EOF : nouveau message utilisateur et r?ponse observ?s, puis fermeture propre code 0. Preuves durables : `AGENT_CAPTURE_LIVE_*_20261102.json` et `AGENT_CAPTURE_TUI_*_20261102.json` dans ce m?me dossier. Claude/Codex simultan?s : aucun croisement des marqueurs dans leurs flux stdout.

D?cision actuelle : **GO limit? pour le collecteur born?, lecture seule, session explicitement d?sign?e par ID**. Service permanent, interface de s?lection, hooks bloquants et juge LLM restent non livr?s. Aucune conclusion suppl?mentaire sur la simulation M3 ou la s?curit? machine ne d?coule de ces essais.


### R?ception finale du lot POC

**27/27 tests cibl?s PASS**, dont r??criture en place ?gale/sup?rieure au curseur, mutation pendant snapshot/lecture, I/O interrompue avec conservation du curseur, verrou exclusif Windows r?el, contenu CLI masqu? par d?faut et rejet des IDs Codex tronqu?s. La revue finale A/B a identifi? un dernier d?faut : le suffixe seul d?un UUID Codex ?tait accept?. Le r?solveur exige d?sormais un UUID complet ; cinq variantes tronqu?es sont rejet?es. A confirme par lecture ; B a rejou? le contre-exemple avec succ?s. Aucun bloqueur restant identifi? dans leur p?rim?tre.

Manifestes de fichiers et r?sultat cibl? : `AGENT_CAPTURE_VALIDATION_20261102.json`. Les preuves runtime sont ant?rieures aux derniers changements de validation d?ID/CLI ; les IDs complets utilis?s restent accept?s et les nouvelles r?gles sont couvertes par la suite cibl?e. La premi?re preuve d?association AGY n?gative est conserv?e ; le chemin imbriqu? observ? et corrig? est d?montr? par `AGENT_CAPTURE_LIVE_AGY_20261102.json`.

Le launcher de test demande une r?ponse sans outils ; seul Claude re?oit une d?sactivation explicite de tous les outils. Codex/AGY utilisent leurs flags sandbox/plan et la consigne de test ; les hooks/configurations utilisateur peuvent s?ex?cuter. Il n?est pas permis de pr?senter ces essais comme une absence m?canique de tout effet secondaire. Le timeout du probe arr?te uniquement son PID direct ; l?arr?t des descendants et t?ches backend n?est pas d?montr?, donc ce lanceur ne doit pas ?tre promu comme gestionnaire g?n?ral de t?ches longues.

Livraison born?e : biblioth?que de r?solution/lecture, CLI de rattachement explicite, probe reproductible, tests, documentation et preuves. Aucun nouveau hook, aucune modification du PLC/CODESYS, aucun commit/push. Le catalogue T426 parent reste en cours : ce lot ne valide pas l?ensemble du chantier workflow.
