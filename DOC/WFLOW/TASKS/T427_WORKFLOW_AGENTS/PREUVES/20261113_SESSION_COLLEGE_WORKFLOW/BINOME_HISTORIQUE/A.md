Tu es l'agent A (archéologie des règles de démarrage). Lecture seule : tu n'as pas d'outils, tout le matériel est ci-dessous.
QUESTION : quelles consignes lues au démarrage d'une session ont été ajoutées, retirées ou affaiblies entre 2026-09-01 et 2026-11-13 ?
DONNÉES (git) :
- CLAUDE.md : contient "@AGENTS.md" en 2026-11-04 comme aujourd'hui (import inchangé).
- AGENTS.md, section "Démarrage" au 2026-11-02 : "Lire ce fichier comme source commune des règles... Ne pas dérouler un briefing complet...". Au 2026-11-13 : même paragraphe, tableau "Références à charger selon le besoin" inchangé.
- Commit b671a890 (2026-11-03) : retire "l'agent DOIT interpeller et poser des questions" (devoir d'alerte) ; ajoute "4 | Inhibition procédurale | ... la faire, sans question pour gagner du temps".
- Commit 4b8038f3 (2026-11-03) : reformule la même règle 4, ajoute la portée "ne modifie jamais CODE/".
- AGENTS.md 2026-11-04 -> 2026-11-13 (diff) : ajoute les sections superviseur, arène dialectique, règle des 2 écarts ; réécrit la délégation Ollama de "uniquement sur demande explicite" à "utilisable par défaut" ; retire la liste des modèles locaux.
- Commits CLAUDE.md/AGENTS.md depuis 2026-09-01 : 14 commits (liste : 0ae6aaaf, d5c5ba3f, 2a6814e3, f11d8de7, f4c2b237, 5da5721a, 0f9a3fd4, 4b8038f3, b671a890, 3c052204, 2f4dc174, 208c5d47, 4e833051, 447c8e46).
TÂCHE : identifie CE QUI a été affaibli concernant la LECTURE OBLIGATOIRE des documents au démarrage. Pour chaque constat : hash de commit, fichier, citation exacte. Sépare FAIT (cité) et HYPOTHÈSE (non cité). Si une information manque, écris "NON VÉRIFIÉ". Réponse en français, 25 lignes max, aucune flatterie.
