# CHALLENGE D'EXPERTISE : ISOLATION STRICTE DES PÉRIMÈTRES DE TRAVAIL CONCURRENT SUR LA MÊME BRANCHE GIT

## 1. Contexte et Problématique
Deux intervenants (l'Orchestrateur Antigravity et l'Utilisateur assisté d'un agent Claude Code / Codex / DSH) souhaitent collaborer en parallèle sur la même branche de travail Git (`work/carte-flux-troubleshooting` ou branche locale non poussée) sur le sous-système **Agent Supervisor (Veilleur)** (`TOOLS/AGENT_SUPERVISOR/`).

Les lots envisagés pour découpage sont :
- **Lot B1 (IHM & Trajet des messages)** : `ui/index.html`, `tests/test_ui.mjs`, `tests/ui_layout_check.mjs`.
- **Lot B2 (Backend Télémétrie & Traces)** : Endpoints API `GET /api/collector/trace` et `GET /api/judge/telemetry` dans `scripts/supervisor_server.py` et `scripts/supervisor_service.py`.
- **Lot B3 (Contexte & Dimensionnement)** : Remplacement du seuil rigide de 6 000 car. dans `scripts/supervisor_service.py` et `tests/test_recovery.py`.
- **Lot C1 (Prompts & Matrice Alarme)** : Modification de `OMNI_JUDGE_SYSTEM` dans `scripts/supervisor_service.py` et tests associés.
- **Lot C2 (Constructeur Mission State Packet)** : Pré-filtrage déterministe avant juge.

## 2. Risques Identifiés
1. **Collision sur `supervisor_service.py`** : Les lots B2, B3 et C1 touchent tous le même fichier monolithique de 2 100 lignes (`supervisor_service.py`). Travailler en même temps sur ce fichier garantit des conflits de merge Git (`<<<<<<< HEAD`), des écrasements silencieux ou des régressions d'état en mémoire.
2. **Couplage Front/Back** : Le Lot B1 (IHM) a besoin des endpoints du Lot B2 (API) pour afficher les vraies données. Si B1 avance avant B2, il risque de coder des mocks ou de casser l'intégration.
3. **Collision de tests** : Plusieurs tests partagent le port 8082 ou des sauvegardes dans `%TEMP%`/`supervision-backups`.
4. **Discipline Git** : Pas de commit automatique sans accord humain explicite (`AGENTS.md`).

## 3. Mission du Challengeur
En tant qu'Architecte Logiciel Senior et Expert Git / Intégration Continue :
1. **Auditer les collisions de fichiers** entre les lots proposés.
2. **Proposer une stratégie d'Isolation Absolue (Zéro-Conflit)** :
   - Faut-il scinder `supervisor_service.py` ou isoler les lots dans des modules neufs (ex: `collector_telemetry.py`, `judge_prompt.py`) ?
   - Comment séquencer ou paralléliser sans aucun risque d'écrasement ?
   - Quelle interface de contrat (API mockée / stub stable ou contrat JSON) doit être définie en premier ?
3. **Définir les règles d'or opérationnelles** pour le travail à deux sur la même branche sans risque de perte de données.
4. **Restituer une matrice d'affectation claire** : Qui fait quoi, sur quels fichiers exclusifs, et dans quel ordre strict.
