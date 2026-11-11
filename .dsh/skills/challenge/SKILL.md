---
name: challenge
description: Lance un challenge contradictoire (Étape 0 Cadrage prompt, puis Agent A Innovation vs Agent B Red Team/Risques indirects, puis Arbitrage C).
user-invocable: true
disable-model-invocation: true
---

# 🥊 Lancer un Challenge Contradictoire & Devil's Advocate

La commande `/challenge` soumet une idée, un choix technique ou une question d'ingénierie à une arène contradictoire structurée en 3 phases :
1. **Étape 0 (Anti-Garbage-In)** : Challenge et recadrage préalable du prompt (détection des postulats implicites, objectif mesurable, non-goals).
2. **Étape 1 (Dialectique A/B)** : Agent A (Innovation & Opportunité) vs Agent B (Red Team & Risques indirects non évidents).
3. **Étape 2 (Synthèse Arbitrée)** : Extraction des pépites émergentes validées, élimination des pièges, et plan d'action TDAH-friendly.

---

### 1. Syntaxe d'Usage

#### A. Étape 0 seule : Cadrer et vérifier le prompt d'abord
À exécuter avant de s'engager sur un sujet complexe :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "<question ou idée>" --check-prompt
```

#### B. Challenge complet autonome (stdout)
Confrontation immédiate A vs B avec arbitrage :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "<sujet>" --target "<fichier_spec_ou_code>"
```

#### C. Challenge formel rattaché à une tâche (Archivage T279)
Consigne automatiquement le rapport sous `DOC/WFLOW/TASKS/T<ID>/PREUVES/` :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/challenge_runner.py --prompt "<sujet>" --task T429 --target CODE/M_MAIN/PRG_05_Translation.st
```

---

### 2. Restitution Standardisée

Le résultat s'affiche selon la norme TDAH-friendly :
- 🎯 **Bannière de Décision & Verdict**
- 🌟 **Pépites Émergentes Retenues**
- 🛑 **Pièges & Risques Indirects Éliminés**
- 🔧 **Plan d'Action Immédiat**
