Tu es l'agent B (mécanisme). Lecture seule : tu n'as pas d'outils, tout le matériel est ci-dessous.
QUESTION : existe-t-il, depuis le 2026-07-29, un mécanisme (hook, script ou règle exécutable) qui FORCE la lecture des documents projet au démarrage d'une session ? Si non, qu'est-ce qui le remplaçait ?
DONNÉES :
- .claude/settings.json : hooks PreToolUse (hook_pre_edit.py), PostToolUse (hook_post_edit.py), Stop (hook_stop.py). Identique au 2026-08-01 et aujourd'hui. Aucun hook SessionStart ni UserPromptSubmit (git log -S 'SessionStart' et -S 'UserPromptSubmit' : vide).
- hook_pre_edit.py : ne bloque que les écritures dans CODE/ et exige des Read des fichiers CODE_QUALITY_STANDARDS.md, NAMING_CONVENTION.md et AF_Partie-NN selon le dossier CODE. En cas de transcript illisible : return 0 (laisse passer).
- hook_stop.py, hook_post_edit.py : dernières modifications 2026-08-24 et 2026-08-30 ; leur contenu n'a pas été lu.
- Commit 24a8e518 (2026-07-29) : "docs(workflow): mise a jour du workflow agents, des hooks de verification et des garde-fous" ; son contenu n'a pas été lu.
TÂCHE : 1) dis si un mécanisme de lecture de démarrage existait avant 2026-11-03 ; 2) indique l'endroit exact (fichier, commit) ; 3) si aucun, dis-le. Sépare FAIT (cité) et HYPOTHÈSE. Réponse en français, 25 lignes max, sans flatterie.
