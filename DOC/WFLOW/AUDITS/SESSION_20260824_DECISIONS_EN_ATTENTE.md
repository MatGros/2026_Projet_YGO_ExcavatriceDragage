# ❓ T150+ — Handoff final : décisions & questions en attente utilisateur (session 2026-08-24)

> 📄 **Handoff définitif** produit à l'issue de l'avancement autonome (16 tâches, 4 challenges
> d'experts intégrés). 🔗 Tâches : [`../TASKS.yaml`](../TASKS.yaml).
> Objectif : vous permettre de **répondre en un seul endroit** ; à chaque réponse, on avance.

---

## 1. Tâches traitées en autonomie (16)

### ✅ Clôturées (4)
| Tâche | Livrable |
|---|---|
| T150 (C1) | Skills stub+canonique + gate G440 + gabarit bannière + README AGENT_WORKFLOW + config fraîcheur + archive project_tracking + DOC/WFLOW/TEMPLATE |
| T109 (C1) | Polarité positive arbitrages + NC-100 (corrigé après revue) |
| T128 (C2) | Commentaires GVL_IHM vérifiés conformes |
| T98 (C2) | BrakeThermal/PhaseRotation déjà câblés (PRG_07:338-339) |

### ⏳ Études / design / revues livrées (12)
| Tâche | Livrable (doc dans `DOC/WFLOW/AUDITS/`) |
|---|---|
| T55 (C2) | Design synchro 4 niveaux v0.2 + spec `FB_WinchSync_v1.1` |
| T11 (C2) | Design `EmergencyStopOk` v0.2 |
| T88 (C2) | Design `FB_CycleTime` garde-fou wrap 49,7 j |
| T129 (C2) | Design raquette Translation |
| T126 (C2) | Design message descente interdite |
| T108 (C2) | Design interlock Trémie |
| T144 (C2) | Design assainir PRG_06 |
| T125 (C4) | Revue modes dragage v0.2 |
| T132 (C4) | AF P09 §5 corrigée (benne fermée) |
| T110 (C4) | Clarification DriveStatusWord.0 AC600 |
| T91 (C4) | Étude séquence frein/puissance asymétrique |
| T54 (C4) | Étude latence boucle (~10 ms) |

### 🧠 Challenges d'experts indépendants intégrés (4)
T55 · T109 · T11 · T125 — tous « À CORRIGER » → **corrections intégrées** (v0.2 etc.), liens morts
G340 vérifiés.

---

## 2. ❓ Questions bloquantes (à répondre pour avancer)

### Q1 — T11 : spec « AUDIT D93 » absente du dépôt
T11 (EmergencyStopOk) se base sur « AUDIT D93 » **inexistant dans le repo** (réf externe/client).
→ **Fournir la spec D93** (fenêtre de confirmation, cas limites) ?

### Q2 — T145 : « en réserve » confirmé ?
→ Confirmer que T145 (source unique YAML) reste en réserve, ou la retraiter ?

### Q3 — Étendre le pattern stub+canonique ?
Pilote `troubleshooting` fait. → Étendre à `task-planner` et `codesys-workflow` ?

### Q4 — Priorités C4 restantes ?
Les tâches C4 restantes (code, spec + validation requises) : quelle(s) prioriser en premier
(T130 intention · T135 · T143 DriftGuard · T147/T148 FB_FbStatus · …) ?

### Q5 — Points code/AF à corriger (si vous validez)
- **Variables mortes** `ProcessM1/M2_Ascent` (PRG_04:101-102, NC-090) : supprimer ?
- **(fait)** spec `FB_WinchSync_v1.0`→`v1.1` corrigée ; **AF P09 §5** « benne fermée » corrigée (T132).

## 3. Décisions T55 (échelle synchro 4 niveaux)
D1 majeur 2-sous-états · D2 diag-only · D3 critique→Méca E · D4 variables mortes · D5 généralisable ?

## 4. Décisions T11 (EmergencyStopOk)
E1 fenêtre · E2 emplacement FB · E3 base PowerContactorEngaged ✓ · E4 verrou vs diag · E5 spec D93 · E6 nom `*Allowed`.

## 5. Décisions T88 (FB_CycleTime) · T108 (interlock) · T91 (frein) · T54 (latence)
- T88 : seuil 1000ms CST_ · diag silencieux
- T108 : injection A (directionnel) vs B (global) · impact cycle · câblage électrique réel
- T91 : FB_Brake sens en entrée · descente immédiate ✓ conforme MES-006 ?
- T54 : où injecter CST_ScanLatencyMs · tâche référence · impact seuils Méca

## 6. État non-régression
- Gate G440 : PASS · tests 5/5 · G340 : seul lien mort pré-existant (`test_fb_joystick.st`, fichier non touché)
- **T151 intact** (🔒 AGY-01) · YAML `TASKS.yaml` valide

> **Réponse attendue** : cochez / renseignez les questions Q1-Q5 et décisions §3-5 — je reprends
> immédiatement sur les C4 prioritaires ou les corrections validées.
