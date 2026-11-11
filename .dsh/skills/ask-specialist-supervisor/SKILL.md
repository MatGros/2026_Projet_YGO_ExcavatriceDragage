---
name: ask-specialist-supervisor
description: Invoque un persona spécialisé certifié (Safety, PLC, HMI, Testing, Standards, Challenger) en préservant le contexte du Superviseur.
user-invocable: true
disable-model-invocation: true
---

# Invoquer un Spécialiste (Préservation du Contexte Superviseur)

La commande `/ask-specialist-supervisor` permet au Superviseur ou à l'opérateur de solliciter une expertise pointue sans polluer ni saturer la fenêtre glissante des messages du Superviseur (`context_messages` et `context_chars`).

### 1. Rôles Disponibles

| Rôle | Persona FB | Périmètre d'Audit |
|---|---|---|
| `safety` | `FB_Agent_Safety` | Sécurité Machine ISO 13849, AU matériel indépendant, anti-chute, mou de câble |
| `plc` | `FB_Agent_PLC` | Automatisme CODESYS, preuve couple frein, ordonnancement séquentiel, bus EtherCAT |
| `hmi` | `FB_Agent_HMI` | Ergonomie cabine, bannières max 42 cars, zéro refus muet, double codage |
| `testing` | `FB_Agent_Testing` | Validation & SAT, dualité tests +/- et hystérésis, syntaxe native STruCpp |
| `standards` | `FB_Agent_Standards` | Norme T279, nomenclature, conventions nommage, conformité outillage projet |
| `challenger` | `FB_Agent_Challenger` | Cadrage prompt préalable, dialectique A/B, traqueur de risques indirects |

---

### 2. Exécution

Depuis la racine du projet :

```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --role <role> --prompt "<question>" --target <fichier1> <fichier2>
```

Pour rattacher à une tâche avec auto-archivage sous `DOC/WFLOW/TASKS/T<ID>/PREUVES/` :
```powershell
py -3.13 TOOLS/AGENT_SUPERVISOR/scripts/specialist_supervisor.py --role <role> --task T429 --target <fichiers>
```

---

### 3. Restitution Standardisée TDAH

- Niveau 0 : 🛑/🟡/🟢 **Bannière Visuelle de Verdict & Impact**
- Niveau 1 : 📋 **Grille d'Invariants Factuelle**
- 💬 **Argumentaire Technique Cadré (Max 3-4 lignes — Prose libre interdite)**
- Niveau 2 : 🎯 **Plan d'Action Chirurgical**
