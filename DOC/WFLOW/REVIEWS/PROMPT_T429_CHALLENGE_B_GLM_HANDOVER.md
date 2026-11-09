# Brief de délégation — Challenge B (GLM 5.3) : Handover, Collision de tâche et Validation canonique (AC-F1.7)

## Mission

- **Utilisateur / besoin d'origine :** Formaliser et fiabiliser la reprise d'une session surveillée par un nouvel agent sans créer de doublon de carte dans l'IHM et avec préservation des alertes.
- **Objectif de cette sous-tâche :** Auditer la logique de handover dans `connect_session.py` et `supervisor_service.py` pour valider que le critère AC-F1.7 est robuste et sans faille.
- **Historique utile et preuves disponibles :**
  - Ajout de l'option `--reassign` dans `connect_session.py`.
  - Format canonique strict d'alias : `ALIAS_PATTERN = r"^T\d+(-[0-9A-Z]+)?-(CC|AGY|CDX|DSH|OPC)\d{2}\s+.+$"`.
  - Extension de l'action `reassign` dans `supervisor_service.py` avec le paramètre `handover: True` pour lever la garde historique empêchant le changement de plateforme si des alertes existent.
  - Sauvegarde d'un événement `session_handover` dans le journal.
  - Tests unitaires `test_connect_session.py` et `test_t429_regressions.py` (42 tests).
- **Décision que le résultat doit permettre :** Valider formellement la conformité de AC-F1.7 ou identifier des cas limites non couverts (ex: formats de tâche exotiques, sessions multiples sur la même tâche, caractères spéciaux dans l'alias).
- **Critères d'acceptation de la review :**
  1. Audit du regex `ALIAS_PATTERN` : couvre-t-il bien tous les agents autorisés (CC, AGY, CDX, DSH, OPC) et toutes les variantes de tâches (ex: `T428-1`, `T429`) ?
  2. Audit de l'action `reassign` : y a-t-il un risque d'écrasement ou d'incohérence sur `transcript_path`, `checkpoint`, `alerts`, `comments` ou `decisions` ?
  3. Comportement en cas d'erreur réseau ou de timeout lors du handover.
  4. Verdict motivé (PASS / FAIL / PARTIEL).

## Rôle et autorisations

- **Rôle :** Reviewer technique indépendant (Lecture seule).
- **Périmètre autorisé :** `TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py`, `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py`, `TOOLS/AGENT_SUPERVISOR/tests/test_connect_session.py`, `test_t429_regressions.py`.
- **Actions interdites :** Aucune écriture, aucun commit.
- **Responsable :** Orchestrateur Antigravity AGY01.

## Méthode et restitution

Rendre un rapport markdown structuré avec verdict par sous-critère, preuves de code et recommandations.
