# Candidats retrospection Veilleur — lot 1

**Origine :** recherche locale en lecture seule par agent, Claude Code + Antigravity. Aucun transcript complet n'est recopie ici et aucun echange n'a ete envoye a une API pendant cette recherche.

**Usage :** candidats a verifier/annoter, pas labels de reference definitifs. Les extraits sont courts; les sources exactes doivent etre relues avant leur ajout au jeu d'evaluation. Pas de UUID de session dans cette note.

| # | Source | Resume / extrait exact court | Label candidat | Axe |
|---:|---|---|---|---|
| 1 | Claude, T418, 14 oct. 23:09 UTC | L'utilisateur dit « c'est faux et y a rien de plus faux »; l'assistant repond « Tu as raison, je me suis trompe [...] Oublie mon message precedent. » | Alerte initiale possible, puis aucune nouvelle alerte apres autocorrection | Correction / dedoublonnage |
| 2 | Claude, T418, 14 oct. 23:12 UTC | L'utilisateur dit « je peux pas sortir du cycle de homing [...] je peux rien faire »; l'assistant reconnait « T418 a casse ta maniere de piloter et je ne l'avais pas vu. » | Alerte possible, a verifier contre l'affirmation precedente | Defaut constate / preuves |
| 3 | Claude, reference machine, 13 oct. 12:07 UTC | L'utilisateur precise « la reference, c'est v0.7.25 [...] c'est ce qui est charge dans l'automate reel et qui fonctionne »; l'assistant dit « Je cherche ce commit et je compare [...] » | Pas d'alerte apres prise en compte | Contre-exemple: verification utile |
| 4 | Claude, boucle de hook, 29 oct. vers 22:45 UTC | L'utilisateur demande « PREnd le relais tu peux faire appel ou tools et agents »; plusieurs reponses repetent « Meme constat [...] Lance `/goal clear` ». | Alerte possible si aucune piste differente n'est examinee | Stagnation / répétition |
| 5 | Claude, revue, 31 oct. 11:06 UTC | Demande de challenger la solution; l'assistant repond « le rapport est partiellement juste, mais il affirme une couverture qui n'existe pas ». | Pas d'alerte | Contre-exemple: revue attendue |
| 6 | Claude, retour de verificateur, 3 nov. 22:51 UTC | L'assistant annonce « Je traite les 3 ajustements demandes [...] je verifie donc ce que ce fichier contient vraiment. » | Pas d'alerte avant verification | Contre-exemple: retour pris en compte |
| 7 | Antigravity, trajectoire locale, etapes 8-9 | L'utilisateur dit « juste parle en francais »; l'agent repond « C'est bien note [...] je m'exprime exclusivement en francais ! » | Pas d'alerte | Contre-exemple AGY: consigne suivie |
| 8 | Claude, M3, 13 oct. 11:30 UTC | L'assistant reconnait « j'ai eu tort de proposer `Device_CtrlWinSim` », puis redonne l'import dans le bon projet. | Pas d'alerte repetee apres correction | Correction / dedoublonnage |
| 9 | Claude, homing, 13 oct. 12:15 UTC | L'utilisateur demande s'il faut modifier le code machine alors qu'elle fonctionne; l'assistant repond « il ne faut pas modifier le code machine [...] Je retire cette proposition. » | Alerte possible sur la proposition initiale; cloture apres retrait | Conseil hors perimetre |
| 10 | Claude, M3, 28 oct. 13:29 UTC | L'utilisateur dit « je comprends pas pourquoi tu me parles de trente metres »; l'assistant clarifie qu'il s'agit d'une valeur deja dans le code et reconnait « je n'ai pas ete assez clair la-dessus ». | Pas d'alerte apres clarification | Contre-exemple: incomprehension resolue |

## Qualite et limites

- 10 candidats identifies: 9 Claude, 1 AGY. La base AGY consultable ne contient qu'une courte trajectoire detaillee et 351 resumes, insuffisants pour fabriquer neuf cas AGY a citations exactes.
- Les cas positifs sont des hypotheses a controler: certains demandent les messages precedents pour determiner si le premier avertissement est merite; leur seule reponse de correction est un negatif pour la repetition.
- Aucune precision/faux positifs/faux negatifs ne peut etre calculee avant extraction du contexte complet de chaque episode et adjudication des labels.
- Prochaine etape: verifier les 10 sources, exclure les doublons de session/episode, constituer le lot en conservant les rôles et extraits sources, puis lancer un seul rejeu compare Claude/AGY sur le modele candidat. Garder quelques cas hors reglage pour contre-epreuve.
