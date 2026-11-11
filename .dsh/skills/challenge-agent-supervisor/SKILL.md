---
name: challenge-agent-supervisor
description: Lance un challenge contradictoire (Étape 0 cadrage prompt, puis A vs B, puis arbitrage) certifié en préservant le contexte du Superviseur.
user-invocable: true
disable-model-invocation: true
---

# Lancer un Challenge (Préservation du Contexte Superviseur)

La commande `/challenge-agent-supervisor` soumet une idée, une architecture ou un choix technique à l'arène contradictoire sans saturer le contexte du Superviseur.

### 1. Processus en 3 Phases

1. **Étape 0 (Anti-Garbage-In)** : Cadrage et challenge préalable du prompt (détection des postulats non vérifiés, objectif mesurable, Non-Goals).
2. **Étape 1 (Dialectique A/B)** : Agent A (Innovation & Opportunité) vs Agent B (Red Team & Risques indirects cachés).
3. **Étape 2 (Synthèse Arbitrée)** : Pépites retenues, pièges éliminés, décision recommandée.

---

### 2. Exécution

#### A. Étape 0 seule : Cadrer et vérifier le prompt d'abord
```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/challenge_supervisor.py --prompt "<question ou idée>" --check-prompt
```

#### B. Challenge complet
```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/challenge_supervisor.py --prompt "<sujet>" --target <fichier1> <fichier2>
```

Pour rattacher à une tâche avec auto-archivage sous `DOC/WFLOW/TASKS/T<ID>/PREUVES/` :
```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/challenge_supervisor.py --prompt "<sujet>" --task T429
```
