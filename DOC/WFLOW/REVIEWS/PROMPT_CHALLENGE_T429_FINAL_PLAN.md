# Challenge & Revue d'Optimisation du Plan de Clôture T429 (Agent Supervisor)

Tu interviens en tant qu'Auditeur Senior en Architecture Logicielle et Robustesse Système.
La tâche T429 (criticité C2) vise à fiabiliser l'Agent Supervisor (Veilleur local sur port 8082).

## État des Lieux et Travaux Réalisés
1. **F0 Référence** : Suite globale de tests à 143/143 tests PASS (`pytest TOOLS/AGENT_SUPERVISOR/tests`).
2. **F1 Continuité** :
   - Reprise normale et avec historique fiabilisées.
   - Guardrails en place : conservation des checkpoints, rupture de source signalée sans saut silencieux.
   - **AC-F1.7** : Titre canonique `TXXX[-X]-AGENT` validé par regex stricte + Handover (passage de relais sans doublon).
   - **AC-F1.8** : Horodatage ISO `created_at` et format local `JJ/MM/AAAA HH:MM:SS` dans le journal.
3. **F2 Cycle des Constats** :
   - Déduplication prouvée sur modèle réel (DeepSeek V4.1) : un constat révisé garde son ID, version + 1.
   - Résolution proposée soumise à preuve brute vérifiable (une affirmation "c'est corrigé" ne clôture rien).
   - Fiche mission structurée compacte avec pré-remplissage confirmé.
4. **F3 IHM, Plugin et Commande Interactive (Pivot Récent)** :
   - Layout responsive testé sans débordement sur 1440, 390 et 360 px (`ui_layout_check.mjs`).
   - Plugin VS Code (POC 0.2.0) : 15/15 tests PASS.
   - **Pivot d'ergonomie 2026-11-09** :
     - Retrait du bouton `Confirm send` dans l'IHM (qui tentait une injection aveugle via workers CLI).
     - Remplacement par le modèle **PULL** déterministe `❯ /review-session-supervisor` intégré dans les 3 CLI (Antigravity, Claude Code, DSH).
     - Priorisation `Alarm > Warning` (FIFO) : 1 seul constat critique par tour par défaut.
     - Correction du support d'encodage Windows (`cp1252` -> `utf-8` reconfigure) avec test dédié.
5. **F4 Recette et Plateformes Réelles** :
   - Campagne A/B FR terminée et publiée (10/10 verdicts).
   - Collecte vérifiée sur Claude, Codex et Antigravity. Limite DSH documentée (absence de clé API locale pour le profil headless).

## Points Récents Remontés par l'Exploitant
1. **Incident Rattrapage Historique** :
   Lors d'un essai de reprise avec historique, l'utilisateur a rencontré l'erreur :
   `Analyse indisponible : recovery_batch_exceeds_judge_budget`
   `Rattrapage interrompu : recovery_batch_exceeds_judge_budget. Les messages non traités sont conservés.`
   (Dans `supervisor_service.py`, le lot global excède `context_chars + 4800` et provoque un abandon brutal au lieu d'un redécoupage adaptatif plus fin).
2. **Validation finale** :
   - AC-F3.5 : Observation par l'exploitant du toast / son / notification VS Code.
   - AC-F3.9 : Validation ergonomique finale de l'exploitant.

## Ta Mission d'Audit
Analyse cette situation et réponds de façon synthétique, rigoureuse et structurée (style ingénierie direct) :
1. **Audit des risques et angles morts** : Quels sont les derniers risques résiduels qui pourraient bloquer la clôture de T429 ?
2. **Solution optimale pour le budget de rattrapage (`recovery_batch_exceeds_judge_budget`)** : Faut-il sous-découper dynamiquement le lot (bisection ou sous-lots de N messages) pour que le rattrapage aille au bout sans bloquer ?
3. **Recommandations sur le plan de clôture** : Quelles étapes précises et ordonnées proposer à l'exploitant pour finaliser et valider formellement T429 ?
