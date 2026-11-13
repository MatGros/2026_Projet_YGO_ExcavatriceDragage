1. [FAIT §A] Oui, §A est structurellement lourd : 7 blocs numérotés 0–6 (bannière, tableau 2 skills, snapshot TASKS, 3 piliers, diagramme 6 étapes, cas pratique, menu 4 options).
2. [FAIT §A] Le dossier ne chiffre pas §A en Ko ; le poids prouvé est celui du contenu, pas une mesure de tokens.
3. [HYPOTHÈSE] Bannière, tableau, diagramme et menu sont du décor avant la demande : ils ne changent ni le rôle, ni le périmètre, ni la prochaine action.
4. [FAIT §D] Aucun hook de démarrage n’a jamais existé ; les gardes réelles sont pre-edit (lecture standards/CODE), post-edit G200/G340 et Stop liaison rouge.
5. [FAIT §D] À ce jour, la preuve mécanique disponible est au point d’écriture : un briefing plus riche ne garantit pas la lecture.
6. [FAIT §D] Volumes : AGENTS.md 26,5 Ko/364 lignes, TASKS.yaml 725 Ko/231 tâches, résumé ouvertes 17,7 Ko, Read tronqué à 2000 lignes.
7. [FAIT §F] Le symptôme utilisateur est « les agents ne lisent plus les documents au démarrage » : le coût à réduire est la lecture imposée, pas l’affichage seul.
8. [FAIT §E] V2 lit intégralement AGENTS + TASKS_ACTIVE_SUMMARY + README (≈51 Ko selon la revue) et ajoute un verrou fail-closed : trop cher et risqué.
9. [FAIT §E] V2 cumule des défauts connus : @import non vu comme Read, Bash contourne, résumé non rafraîchi, hook sans TASK_ID, .agent interdit, contradiction DOC/WFLOW, pas de marqueur sous-agent.
10. [HYPOTHÈSE] Minimum utile : 8–12 lignes affichées, ≤1,5 Ko, sans tableau ni diagramme ; rôle/périmètre, 3 chiffres TASKS, 3 routes de chargement, 1 question si flou.
11. [HYPOTHÈSE] La garantie de lecture doit rester le hook pre-edit existant + une ligne « lus : … » seulement avant édition CODE ; pas de fail-closed général au démarrage.
12. [HYPOTHÈSE] Couper de l’ancien : bannière, tableau skills, énumération 3 piliers, diagramme 6 étapes, cas pratique anti-récitation, menu 4 options.
13. [HYPOTHÈSE] Couper de V2 : lecture intégrale des 3 fichiers, fail-closed, pointeur .agent, check_workflow pré-commit avant preuve ; garder tri flou/clair, SKILL.md unique, pointeur par ID natif si fiable.
14. [FAIT §B] Le §B actuel est déjà plus léger (consignes selon demande, références à charger selon besoin) : le conserver en réduisant le tableau à 3 lignes.

DÉCISION : démarrer en 10 lignes max / ≤1,5 Ko, sans bannière, tableau, menu ni diagramme.
DÉCISION : charger les docs à la demande ; prouver la lecture par le hook pre-edit, pas par un fail-closed de session.
DÉCISION : couper les 6 blocs décoratifs de §A et la lecture intégrale/fail-closed de V2 ; garder tri d’intention, 3 chiffres TASKS, routes SKILL.md.