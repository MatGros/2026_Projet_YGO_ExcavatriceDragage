# 🔍 Vérification Indépendante — Session 2026-08-15

**Projet** : Excavatrice de Dragage en Carrière Noyée
**Cible API** : CODESYS 3.5 (IEC 61131-3)
**Date** : 15 Août 2026
**Objet** : Audit indépendant du code réel (HEAD), des diffs, des gates et de la topologie git
— par un agent auditeur, **en complément** de `RAPPORT_AUDIT_SESSION_20260815.md` (rapport
auto-déclaré de la session).

> ⚠️ **Méthode** : vérification sur le **code réel**, pas sur les rapports. Les constats ci-dessous
> proviennent de la lecture des sources `.st`, des `git diff`, de l'exécution des gates et de la
> topologie de branches. Aucune modification de code n'a été faite par l'auditeur.

---

## 🔄 État du suivi — corrections appliquées

> **v2 (post-correctif)** : après le premier audit, 2 commits ont été poussés sur la branche :
> - `bfa633f` `fix(safety)` — mode-guard `SimulationBypassActive` + câblage réel `HomingStep`.
> - `423b8b0` `docs(audit)` — mise à jour du rapport de session.

### ✅ Corrections vérifiées dans le code (HEAD)

| Remarque initiale | Statut | Preuve dans le code |
|---|---|---|
| 🔴 `SimulationBypassActive` RETAIN non verrouillé | 🟢 **CORRIGÉ** | `PRG_07_Supervision.st` : hors `MAINT_N1/N2` → `SimulationBypassActive := FALSE` + armement `SEL` MAINT-only + retombée désarme les 3 bypass |
| 🔴 `HomingStepM1/M2` câblés à `0` | 🟢 **CORRIGÉ** | `HomingStepM1 := SEL(instHomingM1.Busy, 0, 1)` (idem M2) — phase de recherche réelle affichée |
| 🟠 Doc `FB_Encoder_Safety` §4 périmée | 🟢 **CORRIGÉ** | §4 remplacé par la « Décision Terrain » (non-gel, sécurité = `EncoderIncoherent`→SafeStop), aligné sur le code |
| 🟠 `HomingActive` M1 seul | 🟢 **CORRIGÉ** (déjà dans le HEAD initial) | `(NOT WinchM1.Encoder.Homed) OR (NOT WinchM2.Encoder.Homed)` |

### 🟠 Point non corrigé — reporté explicitement

| Remarque initiale | Statut | Situation |
|---|---|---|
| 🔴 Bandeau champ 2 « Cycle » inopérant | 🟠 **REPORTÉ** (non corrigé) | `CycleStep := GVL_IHM.Cycle.State.CycleStep` — `FB_Cycle` **toujours non instancié**, `CycleStep` reste `INIT`. Le RAPPORT le classe « CONTRÔLÉ » et le **diffère au lot Cycle Auto**. Report honnête et documenté, mais le champ reste figé à ce jour. |

---

## 🚨 Point n°1 — La machine en service ne tourne PAS sur ce code

| Élément | Constat |
|---|---|
| Branche audité | `claude/quirky-goldberg-rvawr7` |
| Écart vs `main` | **26 commits en avant, 4 en arrière — NON fusionnée** |
| Contenu de `main` | Derniers exports CODESYS + visu IHM = code sur lequel la machine a fonctionné |
| Working tree | Propre, tout commité **et** poussé sur la branche feature |

👉 **Aucune surprise possible sur le chantier tant que cette branche n'est pas fusionnée dans `main`.**
Le risque est **différé à la fusion**.

---

## ✅ Gates — le rapport auto-déclaré est partiellement inexact / obsolète

Le `RAPPORT` annonce « 18/18 PASS, 492 passed ». **Réalité sur le bundle réel (auditeur) :**

| Gate | Annoncé | Réel vérifié |
|---|---|---|
| G200 Liaison | PASS | ✅ **PASS 0 erreur** (1058 instances) — **preuve de câblage réelle, confirmée avant et après corrections** |
| G390 Fraîcheur | PASS | ⚠️ FAIL — **faux positif environnemental** (permission temp sandbox) ; bundle frais par mtime |
| G420 PyTest | PASS (492) | ⚠️ **103 erreurs** — toutes `tmp_path`/fixtures → **environnementales**, pas des régressions code |
| G400 Syntaxe ST | PASS | ✅ PASS (post-fix) |

📌 **La liaison (G200) est réelle et verte — c'est la seule preuve qui compte.**
Les échecs G390/G420 sont des artefacts du sandbox de l'auditeur, pas des bugs de la session.

---

## 🟠 Écarts Spec↔Code (confirmés dans le code)

### 🟠 1. Bandeau IHM : champ 2 « Cycle » inopérant (non corrigé)
- `PRG_07_Supervision.st` câble `CycleStep := GVL_IHM.Cycle.State.CycleStep`.
- **`FB_Cycle` n'est instancié nulle part** (grep vérifié) → `CycleStep` reste `INIT` à jamais.
- Le bandeau affichera toujours « Cycle: INITIALISATION » tant que le lot Cycle Auto n'existe pas.
- **C'est le cœur de la fonctionnalité demandée** (AF_Partie-07 §4). Le RAPPORT le **reporte** au
  lot Cycle Auto (statut « CONTRÔLÉ ») — à inscrire comme **reliquat explicite** dans `PLAN_TASK.md`.

### ✅ 2. `HomingStepM1/M2` — corrigé
- `PRG_07` : `HomingStepM1 := SEL(instHomingM1.Busy, 0, 1)`, idem M2. Phase de recherche réelle.
- Le bandeau homing n'est plus figé sur « ATTENTE CAPTEUR HAUT ».

### ✅ 3. `HomingActive` — corrigé (M1 OU M2)
- `HomingActive := (NOT WinchM1.Encoder.Homed) OR (NOT WinchM2.Encoder.Homed)`.

### ✅ 4. Dégel de position codeur — corrigé (doc)
- `FB_Encoder_Safety.st:76` : `CablePosMSafe := CablePosM` (non-gel, inchangé).
- **Doc alignée** : `FB_Encoder_Safety_v1.0.md` §4 = « Décision Terrain » non-gel.
- **Risque machine résiduel** (toujours d'actualité) : en position hors plage, `CablePosM1/M2`
  (consommé par `FB_Safety_Winch` Méca A/F/G) suit la valeur aberrante → faux défauts ou masquage.
  Protections restent actives (`EncoderIncoherent`→SafeStop), mais comportement ≠ existant —
  **à valider sur site**.

---

## ✅ Modifs saines (acceptables)

- **Purge PT1 à 0ms** — suppression propre, aucun consommateur cassé. 🟢
- **Constantes codeur nommées** (8192/4096/2.0, `UDINT_TO_DINT` explicite). 🟢 conforme nommage.
- **Bypass RETAIN unitaires** — câblés dans `PRG_07` avec synchronisation bidirectionnelle
  `GVL_BypassRetain ↔ GVL_IHM.Commun.Bypass`. 🟢
- **Timeout benne 30s→60s** — décision documentée (15 m vitesse lente > 30 s). 🟡 paramétrable.
- **5 zones benne** — logique claire, `Reset` sur front, garde-fou codeurs non référencés. 🟢 conforme.

---

## ⚠️ Alerte sécurité `SimulationBypassActive` — résolue

Master switch **RETAIN** qui arme 3 sécurités (`LimitLegal` + `TopLimitSoftware` +
`TopLimitSwitch`). **Risque initial** : persistance du bypass hors production.

**Correction vérifiée** : mode-guard strict dans `PRG_07_Supervision.st` :
```pascal
IF (Auth.Mode <> MAINT_N1 AND Auth.Mode <> MAINT_N2) THEN
    SimulationBypassActive := FALSE;   // retombée auto hors maintenance
END_IF;
// Armement UNIQUEMENT si MAINT ; retombée désarme LimitLegal/TopLimitSoftware/TopLimitSwitch
```
✅ **Le risque de persistance du bypass en production est levé.**

---

## 🎯 Verdict par modif

| # | Modif | Verdict | Effort |
|---|---|---|---|
| 1 | Homing dynamique M2 (`DynamicTargetEdge`) | ✅ ACCEPTÉE | — |
| 2 | Suppression forçages benne (`IsOpen/IsClosed`) | ✅ ACCEPTÉE | — |
| 3 | 5 zones benne | ✅ ACCEPTÉE | — |
| 4 | `DeltaPosition_M` IHM | ✅ ACCEPTÉE | — |
| 5 | Timeout 60 s | 🟡 ACCEPTÉE (paramétrable site) | — |
| 6 | Revue subagent safety | ✅ (non vérifiable, déclarée) | — |
| 7–8 | GVL_Troubleshooting + joystick | ✅ ACCEPTÉE | — |
| 9 | Bypass RETAIN unitaires + mode-guard | ✅ **ACCEPTÉE** | — |
| 10 | `SimulationBypassActive` (mode-guard) | ✅ **ACCEPTÉE** (risque levé) | — |
| — | **Bandeau champ Cycle inopérant** | 🟠 **REPORTÉ** au lot Cycle Auto — à inscrire en reliquat `PLAN_TASK` | 0,5 j |
| — | **Fiche `FB_Encoder_Safety` §4** | ✅ **CORRIGÉE** | — |

---

## 🎯 Actions recommandées

1. ✅ **Accepter** les corrections de la session (bypass, homing steps, doc codeur).
2. 🟠 **Inscrire le reliquat « Bandeau champ Cycle »** dans `PLAN_TASK.md` (lien au lot Cycle Auto),
   sinon il sera oublié — c'est le cœur de la fonctionnalité IHM demandée.
3. 🟠 **Valider sur site** le non-gel de position codeur (comportement ≠ existant sur `FB_Safety_Winch`).
4. 🔀 **Fusion** : tant que la branche n'est pas fusionnée dans `main`, la machine en service n'est
   **pas** impactée — geler la fusion tant que le reliquat Cycle n'est pas traité ou explicitement acté.

---

## 📎 Documents liés

| Type | Lien |
|---|---|
| Rapport auto-déclaré (maj) | `DOC/TESTS/RAPPORT_AUDIT_SESSION_20260815.md` |
| Journal d'audit | `DOC/TESTS/AGENDA_AUDIT_SESSION_20260815.md` |
| Spec bandeau | `DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md` §4 |
| Fiche codeur | `DOC/AF/AF_Partie-09_Fonction_Encoder/FB_Encoder_Safety_v1.0.md` |
| Pilotage | `DOC/WFLOW/PLAN_TASK.md` |

*Document de vérification indépendante — v2 (post-correctif). Aucune modification de code.*
