RED TEAM — modes d'échec pratique de la V2 (§E), du plus probable au moins probable.

1. **Asymétrie d'application** — Codex/Antigravity n'ont aucun hook (§D) : l'Étape 1 « blocage fail-closed des écritures sous Claude » (§E) ne contraint donc qu'un seul outil ; les agents sans hook démarrent sans socle et rien ne le signale, ce qui viole §F « un seul workflow commun à tous les agents ». Parade : porter le verrou dans le pre-commit commun `check_workflow.py` (§E), pas dans le transcript. [FAIT §D/§E/§F] [HYPOTHÈSE]

2. **Mensonge sur la lecture** — le verrou juge un Read dans le transcript, or les écritures/lectures par Bash ne passent pas par le hook (§D) et l'exemption « sous-agent délégué ou reviewer pur » n'a aucun marqueur permettant de la reconnaître (§E). Un agent s'auto-déclare reviewer et écrit. Parade : preuve = hash du contenu lu + une citation factuelle obligatoire par fichier, jamais une déclaration. [FAIT §D/§E]

3. **Faux blocage auto-infligé → contournement** — `CLAUDE.md` importe `@AGENTS.md` sans apparaître comme un Read (§D/§E) : Claude est bloqué alors qu'il a déjà les règles, et la sortie la moins coûteuse est Bash write ou `git commit --no-verify` (§D). Parade : l'import vaut lecture satisfaite ; sinon fail-open + alerte sur `CODE/`, blocage dur seulement au pre-commit. [FAIT §D/§E] [HYPOTHÈSE]

4. **Compaction** — la V2 se rejoue « après compaction » (§E) : 51 Ko de socle relus à chaque cycle (§E), et « le hook ne connaît pas le TASK_ID » (§E) donc l'état de tâche est reconstruit de zéro. Deux compactions = deux fois le coût, sans mémoire de la tâche. Parade : `.agent/sessions/<ID>.json` porte TASK_ID + hashes + horodatage, relecture différentielle uniquement. [FAIT §E] [HYPOTHÈSE]

5. **Sessions parallèles** — le pointeur par ID natif remplace `/rename-session`, mais le superviseur a déjà perdu T427 et créé une session T000-CC10 non voulue (§D) ; deux agents peuvent donc lire le même résumé et verrouiller la même tâche. Parade : verrou par TASK_ID, ID pris de l'environnement, jamais d'un renommage. [FAIT §D] [HYPOTHÈSE]

6. **Résumé périmé** — `TASKS_ACTIVE_SUMMARY.md` est généré par script mais « fraîcheur du résumé non déclenchée » (§E) ; l'agent travaille sur une tâche déjà close. Parade : en-tête git-sha dans le résumé, refus d'écriture si sha ≠ HEAD. [FAIT §E] [HYPOTHÈSE]

7. **Fatigue opérateur / contradiction** — Étape 2 « flou → questionner » (§E) contredit e06047d1 « action locale réversible : la faire sans question » (§C) ; l'agent alterne et l'opérateur arbitre chaque session, d'autant que le menu d'options a disparu (§A vs §B). Parade : critère de voie en 1 ligne + défaut écrit = Réponse directe, zéro écriture `CODE/`. [FAIT §C/§E]

8. **« Réponse directe » comme porte dérobée** — « action locale réversible » n'est pas défini (§E) ; sous Codex aucun hook n'arrête une modification de séquenceur ST classée « réversible » (§D), sur machine de dragage réelle. Parade : voie Réponse directe = lecture seule stricte sur `CODE/`, liste blanche de chemins. [FAIT §D/§E] [HYPOTHÈSE]

9. **Survol non détectable** — le verrou valide un Read, pas une compréhension ; or l'utilisateur constate déjà que « les agents ne lisent plus les documents au démarrage » (§F), et 51 Ko de socle rendent le Read mécanique (§E). Parade : 3 faits à citer (règle NC, ID tâche, gate) plutôt qu'un compteur de lecture. [FAIT §F/§E] [HYPOTHÈSE]

DÉCISION : le point de rupture n'est pas le principe mais l'application asymétrique — seule une barrière commune (pre-commit) couvre Codex/Antigravity, le hook Claude étant contournable par Bash.
Remplacer le verrou transcript par preuve hashée + citation factuelle, et livrer fail-open plutôt que fail-closed tant que `@import` et Bash ne sont pas traités.
Tant que ces deux contournements existent, le fail-closed fabrique lui-même le comportement qu'il prétend interdire.