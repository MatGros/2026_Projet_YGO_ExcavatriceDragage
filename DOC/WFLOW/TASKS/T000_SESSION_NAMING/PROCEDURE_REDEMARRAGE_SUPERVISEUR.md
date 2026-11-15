# Procédure de redémarrage du Superviseur (8082) — à exécuter UNIQUEMENT sur GO de l'exploitant

Statut : procédure à relire. Rien n'est exécuté par ce document.

## 0. Conditions avant tout

- Visa de l'exploitant sur le diff consolidé des poses T429 (11 poses).
- Lot 2 de `supervisor_server.py` : attribution tranchée par l'exploitant.
- Accord explicite de l'exploitant pour l'arrêt du service.
- Aucun commit ni push pendant la procédure.

## 1. Sauvegarde de l'état (lecture + copie)

- Copier le fichier d'état `%LOCALAPPDATA%/ExcavatriceDragage/agent-supervision.json` vers un fichier daté, dans le dossier de tâche T000.
- Noter les sessions suivies : alias, identifiant natif, état.
- Noter le `build_id` et la version actuels (`GET http://127.0.0.1:8082/api/supervision`, champs `build_id`, `service_version`).

## 2. Arrêt du service (action, sur GO uniquement)

- Identifier le processus qui écoute sur le port 8082 (lecture seule d'abord).
- Arrêter ce seul processus, sans toucher aux autres services (Task Manager sur 8081 notamment).
- Vérifier que le port 8082 ne répond plus.

## 3. Démarrage (action, sur GO uniquement)

- Depuis la racine du projet : `py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py`
- Vérifier que le service répond sur 8082.

## 4. Vérification

- `GET /api/supervision` : `running: true`, `build_id` nouveau, `update_available: false`.
- `load_error` et `storage_error` : `None`.
- Chaque session suivie apparaît, en pause (règle du redémarrage).

## 5. Reprise des sessions

- Reprendre chaque affectation une par une, dans l'interface (bouton « Reprendre »).
- Ne pas reprendre une session dont l'identifiant natif est en doute (collision d'alias).

## 6. Retour arrière si échec

- Si le service ne démarre pas : restaurer le fichier d'état sauvegardé en §1 et relancer l'ancien code.
- Noter l'échec dans le dossier T000 avec la sortie brute.

## 7. Trace

- Consigner dans le dossier T000 : date, heure, build_id avant et après, sessions reprises, résultat de chaque vérification.
