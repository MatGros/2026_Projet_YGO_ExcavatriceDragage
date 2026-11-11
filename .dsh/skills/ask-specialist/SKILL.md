---
name: ask-specialist
description: Invoque un agent spécialisé (Safety, PLC, HMI, Testing, Standards) avec un contrat orienté objet strict.
user-invocable: true
disable-model-invocation: true
---

# Invoquer un Agent Spécialisé (Function Block Persona)

La commande `/ask-specialist` permet de consulter un persona spécialisé avec des invariants métier stricts et un contrat d'évaluation déterministe (`[PASS | ADVISORY | BLOCK]`).

### 1. Panel des Spécialistes

| Rôle | Persona FB | Spécialité & Invariants |
|---|---|---|
| `safety` | `FB_Agent_Safety` | Sécurité Machine ISO 13849, AU matériel indépendant, anti-chute, mou de câble |
| `plc` | `FB_Agent_PLC` | Automatisme CODESYS, preuve de couple frein, ordonnancement MainTask, bus EtherCAT |
| `hmi` | `FB_Agent_HMI` | Ergonomie cabine, bannières max 42 cars `[SYSTEME] : [CAUSE] -> [ACTION]`, zéro défaut silencieux |
| `testing` | `FB_Agent_Testing` | Validation & SAT, dualité tests +/- et hystérésis, syntaxe native STruCpp |
| `standards` | `FB_Agent_Standards` | Norme T279 (1 tâche = 1 dossier), nomenclature, PascalCase, conformité outillage projet |
| `challenger` | `FB_Agent_Challenger` | Cadrage du prompt préalable, dialectique A/B, idées émergentes & traqueur de risques indirects |

---

### 2. Deux Modes d'Invocation

#### A. Mode Consultation Rapide (stdout uniquement, zéro écriture disque)
Idéal pour un avis instantané sans polluer le dépôt :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --role safety --prompt "Le réarmement sur niveau haut est-il acceptable ici ?" --target CODE/M_MAIN/PRG_04_Treuils_Benne.st
```

#### B. Mode Audit Formel de Tâche (Archivage automatique Norme T279)
Inclus dans le cycle de vie d'une tâche C2/C3/C4 :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --role safety --task T429 --target CODE/M_MAIN/PRG_04_Treuils_Benne.st
# -> Génère et classe automatiquement dans DOC/WFLOW/TASKS/T429_.../PREUVES/<session>/T429_REVUE_SAFETY_<date>_v1.0.yaml
```

Multi-cibles supporté :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/specialist_runner.py --role plc --target CODE/M_MAIN/PRG_04_Treuils_Benne.st CODE/M_MAIN/PRG_06_Outputs.st --prompt "Vérifier l'unicité de l'écrivain de consigne M1"
```

---

### 3. Codes de Sortie & Intégration CI

- `0` : **PASS** ou **ADVISORY** (Conforme ou remarques non bloquantes)
- `1` : **ERREUR** (Syntaxe YAML invalide, fichier introuvable, réseau Ollama)
- `2` : **BLOCK** (Objection bloquante : au moins un invariant critique a échoué)
