# Brief de délégation — Challenge C (DeepSeek V4) : Intégrité Transverse et Sanctuarisation (AC-X.1 / AC-X.2)

## Mission

- **Utilisateur / besoin d'origine :** S'assurer que le refactoring et les évolutions de T429 n'ont causé aucune régression transverse, aucune fuite mémoire, et respectent la sanctuarisation stricte des sessions conservées.
- **Objectif de cette sous-tâche :** Examiner les invariants transverses AC-X.1 et AC-X.2 :
  - Session T428 (`d4f1bcd5…`) : maintenue en pause, 6 alertes intactes.
  - Session CC-T217 (`4819768b…`) : maintenue en pause, 0 alerte.
  - Sauvegardes dans `%LOCALAPPDATA%/ExcavatriceDragage/supervision-backups/` vérifiables.
  - Couverture pytest (133 tests) et absence d'effets de bord sur le Task Manager (`TASKS.yaml`).
- **Historique utile et preuves disponibles :**
  - Contrat T429 : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T429_AGENT_SUPERVISOR_FIABILISATION.yaml`.
  - Suivi d'exécution : `DOC/WFLOW/ETUDES/PLAN_AGENT_SUPERVISOR_REPRISE_TRANSCRIPT_ET_PLUGIN.md`.
  - Suite de tests : 133 tests passés avec succès le 2026-11-09.
- **Décision que le résultat doit permettre :** Statuer sur la sécurité globale du service, la conformité de l'état persisté et l'absence totale de dérive.
- **Critères d'acceptation de la review :**
  1. Vérification que l'état local ne mute pas involontairement les sessions en pause.
  2. Audit des scripts de sauvegarde et de restauration (`upgrade_legacy.py`, `supervisor_server.py`).
  3. Vérification de la conformité du contrat de tâche via `check_task_contract.py`.
  4. Verdict motivé (PASS / FAIL / PARTIEL).

## Rôle et autorisations

- **Rôle :** Reviewer technique indépendant (Lecture seule).
- **Périmètre autorisé :** `TOOLS/AGENT_SUPERVISOR/`, `DOC/WFLOW/CONTRACTS/`, `DOC/WFLOW/ETUDES/`.
- **Actions interdites :** Aucune écriture, aucun commit.
- **Responsable :** Orchestrateur Antigravity AGY01.
