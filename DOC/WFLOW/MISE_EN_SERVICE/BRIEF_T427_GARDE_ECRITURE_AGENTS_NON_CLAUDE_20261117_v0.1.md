→ NOUVEL AGENT : T427-CC02 « PROJECT WORKFLOW AGENT » (désigné par l'exploitant, **pas encore lancé** au 2026-11-17 18:20). Le catalogue attribue encore T427 à « CC01 » (verrou périmé, aucune session CC01 n'existe) : catalogue non à jour.

# Brief pour T427 — garde d'écriture hors Claude Code, et faux positif du garde (v0.1, 2026-11-17 18:05)

> Rédigé par TORC-CC10 (orchestrateur hors catalogue). **Transmission par l'exploitant ou l'orchestrateur du catalogue** : TORC-CC10 ne sollicite aucune autre session de sa propre initiative et n'écrit pas dans `TASKS.yaml`. Statut : proposition, rien n'est appliqué.

## OBJECTIF
Que la règle « aucune écriture dans `CODE/` sans contrat de tâche à périmètre épinglé » (`HARD_DENY`, GO exploitant 2026-11-15) vaille **pour tout agent**, pas seulement pour les sessions Claude Code. Et que le garde cesse de refuser à tort des chemins légitimes.

## FAITS (vérifiés par TORC-CC10)
1. **Claude Code** : le hook `hook_scope_guard.py` est branché dans `.claude/settings.json` (`:48`). Tentative de TORC-CC10 d'écrire `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` à ~17:45 : refusée (`ECRITURE INTERDITE PAR LA REGLE DU PROJET`). Comportement conforme à la règle.
2. **Antigravity (Gemini)** : la session T417-C-AGY02 a modifié `CODE/M_MAIN/PRG_03_Modes_Cycle.st` à 14:28 puis page 8 vers 16:35 (rapporté par T417-C), et régénéré `CODE_XML/CODE_DiffBundle.xml`. Barre d'état de sa session (capture exploitant) : « Gemini 4 Hydrogen », étape workflow « **non démarré** ». **[HYPOTHÈSE, non prouvée]** : aucun hook équivalent n'est branché côté Antigravity (je n'en ai trouvé aucun dans le dépôt : seul `.agents/skills` existe). Le verrou de T417-C dans le catalogue est AGY02 : à vérifier si un contrat à périmètre épinglé couvre `CODE/M_MAIN/PRG_03_Modes_Cycle.st`.
3. **Codex** : le plan T427 note déjà « Codex sans clé de session ; hook automatique non configuré » (`T427_WORKFLOW_AGENTS_PLAN_20261110_v1.0.md:279`).
4. **Conséquence** : la protection de `CODE/` dépend de l'agent utilisé, pas de la règle. Un agent hors Claude Code peut modifier le code de la machine sans trace de périmètre.

## FAUX POSITIF DU GARDE (annexe)
`_matches_anywhere` (`task_scope.py:223-250`) teste une sous-chaîne `"/" + motif` : tout chemin contenant `/code…` est refusé (`codesys_console/`, `codex_notes.md`, `code_review/`). Un correctif par composants entiers canonisés (minuscules, flux `:…`, points/espaces finaux, alias 8.3 refusés par préfixe) est testé en mémoire sur 44 cas : 0 échec, 0 régression de sécurité.
Pièce jointe : `PROPOSITION_CORRECTIF_GARDE_ECRITURE_20261117_v0.1.md` (même dossier). Le correctif **n'est pas appliqué** : `task_scope.py` est dans la deny-list.
À vérifier aussi : `hook_shell_scope_guard.py` applique probablement la même fonction aux commandes shell (non vérifié).

## DEMANDE COMPLÉMENTAIRE DE L'EXPLOITANT — rôles du workflow (17:5x)
Observation de l'exploitant, à traiter dans T427 : « entre les hooks et le fait que l'orchestrateur ne soit pas responsable de la base task manager », le workflow doit être ajusté. Faits relevés par TORC-CC10 (à vérifier par T427) :
1. **Qui écrit le catalogue n'est pas clair.** `AGENTS.md` (§ Gestion du Task Manager) : seul le coordinateur désigné écrit dans `TASKS.yaml`, les agents délégués rendent leur état au coordinateur. Dans la pratique de cette journée : le catalogue est attribué à une session « T000-CC10 » (trois homonymes hors ligne), alors que TORC-CC10 est une session hors catalogue qui pilote la mise en service. L'exploitant a indiqué à 17:5x que l'orchestrateur du catalogue serait TORC ; **aucun GO tracé n'existe encore** (cas « autorité ambiguë » : arrêt des écritures).
2. **Les hooks s'appliquent par agent, pas par rôle.** Un orchestrateur Claude Code est bloqué sur `CODE/` et sur les fichiers de garde, y compris pour des corrections de messages sans enjeu de sécurité ; un agent Antigravity ne l'est pas (hypothèse du §FAITS). Le rôle « responsable du catalogue » et le rôle « autorisé à écrire dans `CODE/` » ne coïncident dans aucune session : chaque modification de `CODE/` exige un relais manuel par l'exploitant.
3. **Conséquence observée aujourd'hui :** un patch de 5 modifications (messages capteur haut et mou de câble) est prêt depuis ~17:50 mais ne peut être appliqué que par T417-C ou l'exploitant ; le brief lui-même (T427) ne peut être inscrit au catalogue que par une session désignée sans GO tracé.

À trancher par T427 (proposition, pas décision) :
- **Matrice rôle → droits** écrite : qui écrit `TASKS.yaml`, qui peut écrire `CODE/` (contrat à périmètre épinglé), qui valide ; une seule session désignée par rôle, avec GO tracé et copie datée.
- **Procédure de désignation et de relève** du responsable du catalogue (fin des homonymes hors ligne) et de l'orchestrateur de mise en service.
- **Voie courte** pour un correctif d'IHM sans impact safety (messages opérateur) : contrat léger à périmètre épinglé sur un seul fichier, au lieu d'un relais manuel.
- **C5** (critère testable) : pour chaque rôle, un test qui prouve ce qu'il peut et ne peut pas écrire (catalogue, `CODE/`, fichiers de garde).

## PÉRIMÈTRE / INTERDITS
- Dans le périmètre : garde équivalent ou exigence pour Antigravity et Codex ; test « écriture dans `CODE/` par un agent non Claude » ; correctif `_matches_anywhere` + test dans `TOOLS/AGENT_WORKFLOW/tests/` (règle `fix:` + `guard:`).
- Hors périmètre : toute modification de `CODE/`, le contenu des lots de T417-C, le catalogue.
- Interdits : désarmer un garde pour faire passer un test ; supprimer des fichiers de traces.

## PHASES ET POINTS D'ARRÊT
1. Lire `task_scope.py`, `hook_scope_guard.py`, `hook_shell_scope_guard.py` et le plan T427 §P1.
2. Vérifier, avec la configuration réelle d'Antigravity et de Codex, **si et comment** un garde peut s'y brancher. Si ce n'est pas possible : le dire, et proposer une barrière côté dépôt (hook git `pre-commit` : refus d'un diff sur `CODE/` sans contrat à périmètre épinglé).
3. **Arrêt humain** : GO de l'exploitant avant toute écriture dans les fichiers de garde.
4. Implémenter, tester, relire le diff par un agent indépendant.

## CRITÈRES TESTABLES
- C1 : une écriture simulée dans `CODE/` par une session non Claude Code est refusée ou **signalée dans la trace** (preuve : test avec sortie brute).
- C2 : les 44 cas de la matrice de la proposition passent ; aucun chemin protégé précédemment refusé ne devient accepté.
- C3 : `codesys_console/x.py`, `codex_notes.md`, `DOC/AF/code_review/x.md` ne sont plus refusés.
- C4 : un diff sur `CODE/` hors périmètre épinglé est détecté avant commit.

## SOUS-AGENTS AUTORISÉS
Challenger et reviewer en lecture seule ; un seul écrivain. Modèles Ollama possibles pour la revue (contenu fourni dans le prompt).

## PREUVES ATTENDUES
Sorties de test brutes avec code retour, diff réel, `run_all_gates.py --palier C`.

## RESPONSABILITÉ DU PRINCIPAL
Il vérifie à la source les affirmations de ce brief ; les points marqués **[HYPOTHÈSE]** ne sont pas des preuves.

## CHANTIERS CONCURRENTS
- **T417-C (AGY02)** : modifie `PRG_03` et le DiffBundle en ce moment ; ne pas bloquer son lot sans décision de l'exploitant.
- **T377 (CC03)** : sous-tâche « défauts au démarrage » (C4) sur `CODE/` ; même règle de périmètre.
- **T429** (verrou catalogue « CC01 », probablement périmé) : Superviseur, observation seulement.
- **Verrous périmés ?** Le résumé du catalogue attribue à « CC01 » les tâches T426, T427, T428 et T429, alors que l'exploitant indique qu'aucune session CC01 n'existe : à vérifier et à purger par le responsable du catalogue désigné.
- **T386, T387, T395** : touchent `CODE/` selon le brief T377 ; ne pas casser leur chemin d'écriture contractuel.
