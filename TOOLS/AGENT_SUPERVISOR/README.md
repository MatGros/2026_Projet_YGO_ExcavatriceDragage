# Agent Supervisor

Agent Supervisor observe en lecture seule des conversations Claude Code, Codex, Antigravity ou DSH
explicitement affectées et propose des alertes à vérifier. Il ne pilote pas les agents,
ne modifie ni conversations ni tâches, et ne valide ni un essai ni la sécurité machine.
OpenCode n'est pas pris en charge.

## Démarrer

Depuis la racine du projet :

```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py
```

Ouvrir `http://127.0.0.1:8082/`. Le port est modifiable avec `--port 8092`.
Task Manager détecte ou démarre le service sur 8082 ; définir `VEILLEUR_PORT=8092`
avant son lancement pour utiliser le même autre port. Un verrou associé au fichier
d'état interdit à deux serveurs d'utiliser simultanément ce stockage. Un port occupé
ou un verrou déjà pris empêche le démarrage, sans écraser la configuration.
Task Manager affiche l'adresse du Veilleur, son origine (détecté ou démarré) et sa
version au lancement. L'interface indique aussi si le code sur disque a changé depuis
le lancement ; si une mise à jour est signalée, le processus Veilleur doit être redémarré
pour la charger. Redémarrer uniquement Task Manager ne redémarre pas le Veilleur autonome.

Pour isoler une installation ou un essai, le serveur accepte `--state <chemin>`.
Le chemin historique par défaut est `%LOCALAPPDATA%/ExcavatriceDragage/agent-supervision.json`
sur Windows ; les notes sont dans `supervision-exchanges` à côté de ce fichier.
Une configuration illisible est signalée et protégée contre l'écrasement.
La configuration, la mission initiale, le cadrage actif et les alertes sont conservés.
Au redémarrage, les affectations sont en pause et doivent être reprises explicitement.
Dans chaque carte de session, le bouton **Reprendre** relance le suivi. Si l'ID initial
est incorrect et qu'aucune alerte n'y est rattachée, le champ **Corriger l'ID local**
permet de le remplacer sans perdre la mission ; une source unique est exigée.

## Affecter une conversation

Dans Claude Code, Antigravity ou DSH, la skill utilisateur `/connect-session-supervisor` lance l'affectation
depuis le chat courant. Elle exige une tâche formelle identifiable, ou une confirmation
explicite avant un suivi sans tâche. Elle demande un alias s'il manque, n'utilise jamais
la session la plus récente et n'envoie aucun message à l'agent observé. Le script
`scripts/connect_session.py` vérifie l'ID, l'unicité de la source et la réponse du service.
Dans DSH, elle apparaît dans le menu des skills `/` et s'exécute comme prompt utilisateur ;
aucune commande native de profil ni configuration DSH globale n'est installée par ce lot.
Après l'ajout ou le renommage de la skill, recharge ou relance chaque CLI concerné pour
rafraîchir son catalogue de commandes. Task Manager et Windows n'ont pas besoin de redémarrer.
Codex ne fournit pas encore ici de commande de chat équivalente ; utiliser l'affectation
manuelle depuis Task Viewer.

Pour DSH, le collecteur lit le transcript local `.jsonl.zstd` avec Node.js 22 ou ultérieur.
Lors du premier rattachement, le suivi commence à la fin du transcript ; aucun historique antérieur
n'est importé. Une réécriture ou troncature suspend le suivi comme pour les autres sources.

1. Saisir la plateforme et l'ID natif complet, ou demander la liste de candidates et
   sélectionner explicitement une ligne non ambiguë. La recherche ne lit que les noms
   et dates des fichiers et ne démarre pas le suivi.
2. Variante : générer le prompt, le transmettre soi-même à l'agent et coller le bloc
   `VEILLEUR_ASSIGN_V1` pour préremplir les champs. Le format attendu est un objet JSON ;
   l'ancien format `clé: valeur` reste accepté. Un ID déclaré `inconnu` efface l'ancien ID :
   il faut saisir ou sélectionner le bon. Le résumé humain peut précéder le bloc.
   L'absence de référence de tâche formelle affiche un avertissement ; suivre une session
   sans tâche ne crée pas de tâche et ne donne aucune autorisation à l'agent.
3. Vérifier la plateforme, l'ID et la mission, puis cliquer sur **Ajouter la session au suivi**.
   L'API autonome refuse les ID absents ou ambigus. Aucun rattachement n'est fait par
   simple recherche, sélection ou collage.

Le premier rattachement commence **à la fin** du transcript ; l'historique antérieur n'est pas
importé. Le service conserve ensuite un curseur vérifiable (identité, chemin, position et empreinte
du préfixe) pour détecter les messages apparus pendant une pause ou un arrêt. À la reprise, s'il
trouve un intervalle vérifiable, il affiche son volume et propose **Reprise normale** (ignorer
explicitement cet intervalle) ou **Reprise avec historique** (le soumettre au juge par lots).
Sans intervalle vérifiable, il n'invente pas de rattrapage et demande une reprise normale explicite.
Les affectations créées avant l'installation du checkpoint durable affichent aussi une continuité
non vérifiée : leur ancien intervalle ne peut pas être reconstruit ; la reprise normale établit
un nouveau point de départ après confirmation.
Une réécriture, troncature ou perte de source suspend le suivi ; les lots déjà enregistrés restent
disponibles pour terminer ou réessayer leur analyse avant un rattachement normal.
L'historique du chat Veilleur est conservé localement, séparément pour chaque session.
Le bouton **Voir / actualiser l'historique** lit sur demande les derniers messages du
transcript de cette affectation, avec une limite de taille ; il n'envoie rien à l'agent.
Le chat associé à une session parle au Veilleur au sujet de cette session ; Entrée envoie
et Maj+Entrée insère une ligne. Les messages de ce chat peuvent être confidentiels.

Le stockage local persiste le checkpoint, les 12 derniers messages observés (plafond de
6 000 caractères), jusqu'à 20 éléments de mémoire utilisateur et, temporairement, les lots
de reprise historique (plafond de 5 Mio). Les lots sont retirés après analyse terminée ; ils
ne sont pas envoyés à l'agent observé. Le juge reçoit seulement le lot en cours, avec le
consentement cloud requis pour un modèle distant. Les alertes et citations sont persistées ;
les retirer du suivi ne supprime pas les notes déjà créées. Ces données locales peuvent
contenir des informations confidentielles.

## Modèle et limites

Le juge Ollama est consultatif et expérimental. Le choix d'un modèle distant ne vaut
pas consentement : tant que la case cloud n'est pas cochée, la métadonnée Ollama est
vérifiée avant envoi et un modèle distant ou inconnu est bloqué. Le texte transmis au
modèle est borné et peut être partiel. Une citation d'alerte doit être un extrait exact
d'un message assistant effectivement présenté au juge ; une citation exacte ne prouve
pas que l'interprétation ou le motif sont corrects. Vérifier les sources avant action.
Une réponse invalide, une erreur, une absence de consentement ou un délai dépassé sont
affichés comme indisponibilité, pas comme absence d'anomalie.

## Vérifier

Les essais ci-dessous utilisent uniquement des données synthétiques ; ils ne suivent
aucune conversation réelle et ne transmettent aucun extrait réel à un modèle.

```powershell
py -3.13 -m pytest TOOLS/AGENT_SUPERVISOR/tests -q
node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs
py -3.13 TOOLS/AGENT_SUPERVISOR/tests/run_scenarios.py --model qwen3:8b
py -3.13 TOOLS/AGENT_SUPERVISOR/tests/benchmark_integrity.py TOOLS/AGENT_WORKFLOW/.tmp/veilleur_benchmark_<identifiant_unique>
```

Le script `run_scenarios.py` ne permet que des modèles locaux et présente sept cas
contrastés. Son verdict concerne uniquement ces exemples. Le benchmark crée et conserve
des fichiers JSONL synthétiques de 1, 10 et 50 Mo dans le scratch indiqué ; utiliser un
nouveau chemin à chaque exécution. Aucun nettoyage automatique n'est effectué.


## Extension VS Code (POC)

Une extension locale indépendante des CLI affiche les compteurs et signale les nouveaux constats
dans VS Code. Elle lit le résumé local, n’envoie aucun message et ne déclenche aucun appel LLM.
L’utilisateur confirme la voir dans son VS Code ; l’usage courant reste à évaluer. Plan, preuves
et limites : [document de tâche](../../DOC/WFLOW/ETUDES/PLAN_AGENT_SUPERVISOR_REPRISE_TRANSCRIPT_ET_PLUGIN.md).
Code, scénarios de test et commande de lancement isolé :
[`poc/vscode-notifier/README.md`](poc/vscode-notifier/README.md).

## Alertes dans la conversation surveillée

### Consultation interactive : Commande `/review-session-supervisor` (Modèle Pull)

Pour éviter toute injection asynchrone concurrente ou invisible dans les interfaces CLI, l'intégration repose sur le modèle **Pull** initié par l'utilisateur ou l'agent dans sa propre fenêtre :

Dans Claude Code, Antigravity ou DSH, lancer dans le chat actif :
```text
❯ /review-session-supervisor
```

Options disponibles :
- `/review-session-supervisor` : examine le constat prioritaire (**Alarm > Warning**, FIFO) pour focaliser l'agent sur un seul point critique.
- `/review-session-supervisor help` : affiche l'aide et les options.
- `/review-session-supervisor all` : examine tous les constats ouverts de la session.
- `/review-session-supervisor alarm` : cible la première alerte critique (Alarm).
- `/review-session-supervisor warning` : cible le premier avertissement (Warning).
- `/review-session-supervisor <num>` : cible un constat par son index (ex. `1`, `2`).
- `/review-session-supervisor <id_court>` : cible un constat par son préfixe hexadécimal (ex. `26fcd4`).
- `/review-session-supervisor --session <UUID>` : force la session cible si ambiguïté.

Cette commande interroge le service Veilleur local (`127.0.0.1:8082`) et insère le constat et sa consigne d'ingénierie directement dans le tour courant de l'agent. La commande est strictement **consultative** et n'auto-clôture aucun constat.

### Interface Web et Décisions

L'interface distingue la lecture d'un constat, son état de suivi et l'avis du superviseur :
- **Seen** : marque le constat comme lu par l'exploitant.
- **Close** : enregistre une décision humaine de clôture.
- **Defer** : reporte temporairement le suivi.
- **📋 Copier pour le chat** : copie le texte de cadrage dans le presse-papier pour transmission manuelle éventuelle.
- Le bouton d'envoi automatique CLI (`Confirm send`) a été retiré de l'IHM au profit du pull déterministe via `/review-session-supervisor`.

Un commentaire saisi dans le constat s'adresse au superviseur. Il reste associé au constat et peut demander une réévaluation ; il n'est pas envoyé automatiquement à l'agent surveillé. Une correction observée peut conduire le modèle à proposer une résolution, avec citation ; la clôture humaine reste distincte. Une analyse indisponible ne signifie pas « aucun problème ».

### Ancien cycle 1/2/3

Le cycle historique 1/2/3 reste disponible pour les anciens constats. La création d'un nouveau constat ne lance plus automatiquement un tour dans la conversation surveillée.

L'utilisateur choisit `1` (ignorer avec motif), `2` (examiner maintenant) ou `3` (reporter avec condition). Pour `2`, le Veilleur demande une courte contre-analyse sans outils ni modification. La réponse de l'agent est affichée comme proposition ; elle ne vaut pas décision utilisateur.

Le marqueur coloré des cartes est repris dans la liste latérale ; les cartes non sélectionnées sont repliées. L'état d'ouverture reste local au navigateur.
