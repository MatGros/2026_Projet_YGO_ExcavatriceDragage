# 📖 Guide de Remplissage — Fiche de Troubleshooting

> Annexe au gabarit `TEMPLATE_Troubleshooting.md`. Aide celui qui renseigne la fiche.
> 📌 **Méthode de diagnostic** (arbre des causes, traçage inverse, critère d'arrêt, cas limites CODESYS, règles) :
> `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` — **ne pas recopier ici** (une règle écrite deux fois dérive).

---

## 🧭 Vue d'ensemble

| Section | Obligatoire ? | Rôle |
|---|---|---|
| 1. Contexte figé | ✅ | Snapshot horodaté de l'état machine |
| 2. Symptôme | ✅ | La panne à dépanner |
| 3. Indices / historique | ✅ | Suite du contexte |
| 4. Arbre des causes | ✅ | Liste EXHAUSTIVE des hypothèses |
| 5. Arbre vertical | ✅ | Visualisation du flux (obligatoire pour l'humain) |
| 6. Données & chronogramme | 🟡 | Lectures + séquences observées |
| 7. Conclusion | ✅ | Cause racine |
| 8. Proposition de correction | ✅ (plus tard) | Options + validation |
| 9. Vérification / non-régression | ✅ (après correction) | Le symptôme est-il résolu ? |
| 10. Journal | ✅ | Chronologie |

---

## 1. 🧊 Contexte figé (horodaté)

**Pourquoi** : l'agent ne re-pose pas les questions. Mais l'état machine **change** (mode, homing, redémarrage, opérateur).

**Règle** : c'est un **snapshot horodaté**, pas un invariant. Si > X min ou un événement (redémarrage, changement de mode) → **re-figer avant de conclure**.

**Variables usuelles** :
| Élément | Variable complète |
|---|---|
| Simulation active | `GVL_Simulation.SimulationModeActive` |
| Bypass actif | `GVL_Simulation.SimulationBypassActive` |
| Référencement axes | `PRG_02_Acquisition.instHomingM1.Homed` |
| Mode machine | `PRG_03_Modes_Cycle.Auth.Mode` |
| Redémarrage | chaud / froid / download |

⚠️ **Toute valeur non listée = à vérifier** (ne pas supposer). En redémarrage **chaud**, les RETAIN survivent → l'état n'est pas « par défaut ».

---

## 2. 🎯 Symptôme

1 phrase : quoi, où, depuis quand, **permanent ou intermittent**.
- **Permanent** → logique / config / câblage.
- **Intermittent** → timing / race / comm / mécanique.

---

## 3. 🧩 Indices / historique

- Derniers changements (code, config, câblage, HMI) → cause n°1 = régression récente.
- Déjà essayé (et résultat) → ne pas re-tester.
- Conditions d'apparition (mode, charge, position) → révèle le gating.
- Alarmes → la cause est souvent déjà nommée.

**Force des preuves** : 🟢 lecture de variable = forte · 🟡 rapport opérateur = faible (à confirmer) · 🔴 inférence = la plus faible (jamais seule).

---

## 4. 🌳 Arbre des causes & hypothèses

**Exhaustif** : ne rien oublier. Partir de la variable fautive, **remonter** (traçage inverse) jusqu'à la source (ou les sources multiples).

**Règle** : chaque « valeur attendue » doit avoir une **SOURCE** (spec `AF_Partie-XX`, code `.st`, logique). Sinon « attente non justifiée » → ne pas conclure dessus.

**Exhaustivité & vitesse** : déléguer l'exploration de branches **indépendantes** à des **sous-agents** (2-3 max, re-synchronisés par l'orchestrateur). Chaque sous-agent rend : variable + valeur + **horodatage** + force de preuve.

> 📌 Les **6 catégories** de causes et le **traçage inverse** : voir `troubleshooting.md` §4-5.

---

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

**Pourquoi** : visualisation pour l'humain. Chaque branche = hypothèse, parcourue verticalement.

**Format** : nœud = `[nom:type=valeur]`. Émojis : ✅ attendu · ❌ blocage · ❓ ambigu (investigation obligatoire).

**Exemple** (contacteur sens avant M1 — toute la chaîne) :
```text
Symptôme : le contacteur sens avant M1 ne s'active pas
│
├─ H1 Demande (joystick / simu)
│   ├─ [StimFwd:BOOL=TRUE] ✅
│   └─ [JoyYRaw:INT=10000] ✅
├─ H2 Acquisition
│   └─ [HwIn.Operator.JoyYRaw_ANA2:INT=10000] ✅
├─ H3 Joystick FB
│   ├─ [DeadmanArmed:BOOL=TRUE] ✅
│   └─ [AxisCmdY.Direction:INT=+1] ✅
├─ H4 Modes
│   ├─ [Auth.Mode:INT=MAINT_N1] ✅
│   └─ [Auth.InhibitM1:BOOL=FALSE] ✅
├─ H5 Treuils
│   ├─ [M1_Direction_Active:INT=+1] ✅
│   └─ [M1_StartStop_Active:BOOL=TRUE] ✅
├─ H6 Safety
│   ├─ [SafeStop:BOOL=FALSE] ✅
│   └─ [ForbidAscent:BOOL=FALSE] ✅
└─ H7 Sortie
    ├─ [M1_RelayFwd:BOOL=TRUE] ✅
    └─ [M1_RelayFwd_DQ:BOOL=FALSE] ❌ blocage
```

**IF / CASE** dans le flux :
```text
├─ H3 Joystick FB
│   └─ IF [AtNeutral:BOOL=TRUE] THEN → [Disarm:BOOL=TRUE] ❌ ELSE → [KeepArmed:BOOL=FALSE]
├─ H4 Modes
│   └─ CASE [Auth.Mode:INT=2] OF 1→[Maint1] 2→[Maint2] ✅ 3→[SemiAuto]
```

**Résumé une ligne** (en bas) : `[A:BOOL=1] → [B:INT=0] → [C:BOOL=1] ❌`

---

## 6. 📊 Données / interactions & chronogramme (🟡)

**Lectures & essais** : chaque lecture = variable + valeur + horodatage.

**Chronogramme** : séquences **observées/rapportées** (🟡), jamais présenté comme acquisition. Tableau vertical (événements × signaux), ligne `→ tempo` entre événements, cases █=1 / vide=0 / valeur numérique.

| <nobr>Événement</nobr> | <nobr>StimRevDown</nobr> | <nobr>DeadmanArmed</nobr> | <nobr>PosM</nobr> |
|:---:|:---:|:---:|:---:|
| T1 | █ | █ | 12.5 |
| → 100 ms | | | |
| T2 | █ | █ | 12.0 |
| → 3 s | | | |
| T3 | █ |   | 11.5 |

---

## 7. 🏁 Conclusion

- **Cause racine** : prouvée par lecture (🟢), jamais par inférence seule.
- **Statut** : RÉSOLUE / à valider.

---

## 8. 🛠️ Proposition de correction

À remplir **plus tard**, une fois la cause confirmée.
- **Option 1 (immédiat, sans code)** : contournement — impact/risque.
- **Option 2 (définitif)** : correction durable — impact/risque.
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

---

## 9. ✅ Vérification de la correction / non-régression

Après correction, vérifier :
- Le **symptôme est-il résolu** ?
- **Rien d'autre cassé** (non-régression) ?
- Aligné `fix:` + `guard:` (AGENTS.md) : correction + garde-fou.

---

## 10. 📝 Journal (chronologique)

Chaque action/observation datée. Permet l'audit et l'historique.

---

## 🛠️ Lecture matériel / fieldbus (hors-PLC)

Les vrais dépannages sont souvent **matériel** : câblage, contacteur collé, fusible, variateur en défaut, bus CANopen down, alimentation.

| À vérifier | Où |
|---|---|
| Statut bus CANopen | `GVL_Troubleshooting.ContexteMachineGlobal.Idx103_JoystickCommOk` |
| Statut device (OP/erreur) | `GVL_Troubleshooting.Inputs` / diag device |
| Validité d'image | statut I/O, `Valid` |
| Défauts variateur | `GVL_Troubleshooting.TranslationPontM3` |
| Alimentation / AU | `ContexteMachineGlobal.Idx301_EmergencyChainClosed` |

---

> 📌 **Critère d'arrêt, cas limites CODESYS, règles d'or** : voir `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` §6-9.
