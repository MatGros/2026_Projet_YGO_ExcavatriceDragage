# Veilleur

Veilleur observe en lecture seule des conversations Claude Code, Codex ou Antigravity
explicitement affectées et propose des alertes à vérifier. Il ne pilote pas les agents,
ne modifie ni conversations ni tâches, et ne valide ni un essai ni la sécurité machine.
DSH et OpenCode ne sont pas pris en charge.

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

Le rattachement commence **à la fin** du transcript. Les messages antérieurs, les
interruptions et les périodes en pause ne sont pas rejoués ; l'historique est donc
explicitement signalé comme partiel. Une troncature, réécriture ou erreur de lecture
suspend le suivi : examiner la source, puis pause/reprise pour confirmer le rattachement.
L'historique du chat Veilleur est conservé localement, séparément pour chaque session.
Le bouton **Voir / actualiser l'historique** lit sur demande les derniers messages du
transcript de cette affectation, avec une limite de taille ; il n'envoie rien à l'agent.
Le chat associé à une session parle au Veilleur au sujet de cette session ; Entrée envoie
et Maj+Entrée insère une ligne. Les messages de ce chat peuvent être confidentiels.

Les messages utilisateur observés sont gardés en mémoire pour le suivi en cours, mais
ne sont pas persistés et sont perdus à la reprise ou au redémarrage. Les alertes et
leurs citations sont persistées ; les retirer du suivi ne supprime pas les notes déjà
créées. Les extraits et notes peuvent donc contenir des informations confidentielles.

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
