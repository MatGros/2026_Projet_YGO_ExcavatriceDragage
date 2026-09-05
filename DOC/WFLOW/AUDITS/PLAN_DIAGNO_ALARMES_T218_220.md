# 📋 PLAN T218-T220 — Diagnostic & enrichissement IHM (blocage de mode, alarmes)

> Plan de travail NON-CODE (préparation) : phases, contrats, tests CI, modifications DOC,
> prévision agents. L'implémentation est déclenchée par décision humaine par phase.

---

## 🎯 Contexte

L'opérateur est **bloqué dans un mode** quand le retour contacteur `M1/M2_ContactorsReleased_DI`
n'est pas câblé (=0) : `ModeChangeAllowed` reste 0 → bascule refusée. Le **diagnostic** est fait
(motif + 6 sous-conditions exposés à l'IHM), mais la **cause** n'est pas résolue. On enrichit
aussi le bandeau + un historique d'alarmes.

---

## 🗂️ Phases & tâches

| Phase | Tâche | Titre | Criticité | Contrat |
|---|---|---|---|---|
| **1** (PRIO) | T218 | Résoudre le blocage de mode | C4 | `TASK_CONTRACT_T218_BLOCAGE_MODE.yaml` |
| 2 | T219 | Historique d'alarmes (histo) | C2 | `TASK_CONTRACT_T219_HISTORIQUE_ALARMES.yaml` |
| 3 | T220 | Enrichir le bandeau IHM | C2 | `TASK_CONTRACT_T220_ENRICHIR_BANDEAU.yaml` |

---

## 🔵 Phase 1 — T218 : Résoudre le blocage de mode (C4, PRIORITAIRE)

### Décision de conception requise AVANT code (options)
| Option | Description | Effet | Risque |
|---|---|---|---|
| **A** | Retirer le gate `ModeChangeAllowed` → le mode suit `SelMode` | Débloque total, aligné T207 | Contredit AF-05 §4bis |
| **B** | Garder vitesse + frein seul (sans contacteur) | Débloque si treuils arrêtés | Perd confirmation contacteurs |
| **C** | Câbler `M1/M2_ContactorsReleased_DI` | Fix matériel propre | Nécessite le câblage |

### Tests / CI
- CI `FB_Modes` (table de bascule sous AU, avec/sans retour contacteur).
- CI mouvement/safety : `FB_Winch`/`FB_Safety_Winch` `PowerContactorEngaged=FALSE` → aucun mouvement.
- Gates : bundle, G200, G406 (longueur STRING), G430, G483.

### Modification DOC
- `AF_Partie-05` §4bis : reformuler la condition de bascule selon l'option retenue.

---

## 🟢 Phase 2 — T219 : Historique d'alarmes (C2)

### Préalable — note de design
- Buffer FIFO borné (taille à fixer, ex. 50).
- Source d'horodatage (T#temps cycle vs RTC) à valider.
- Interaction avec le bandeau d'alarmes actives (coexistence, pas d'écrasement).

### POU ajouté
- `FB_AlarmHistory` (ou équivalent) + `ST_AlarmHistoryEntry` + buffer.

### Tests / CI
- Test CI `FB_AlarmHistory` : ajout, dépassement FIFO, horodatage.
- CI intégration : bandeau d'alarmes actives inchangé.

### Modification DOC
- Note de design alarmes + `AF_Partie-07` si applicable.

---

## 🟠 Phase 3 — T220 : Enrichir le bandeau (C2)

### Contenu envisagé
- État AU/urgence (`EmergencyChainClosed`, `PowerContactorEngaged`, `PowerCutOff`).
- Défauts actifs (codeur, synchro, benne, translation) en texte court.
- Motif du blocage + 6 sous-conditions (déjà exposés — binding à compléter).
- Priorité : sécurité d'abord, lisibilité conservée.

### Tests / CI
- CI `FB_Hmi_BannerFormatter` (chaque info affichée, priorité).
- G406 longueur STRING PASS.

### Modification DOC
- `AF_Partie-07` (bandeau) : documenter les nouveaux champs.

---

## 🧪 Règles communes à chaque phase (non-code)

1. Rédiger/valider le contrat (`check_task_contract.py` PASS) — ✅ fait pour T218/219/220.
2. Verrouiller la tâche dans `TASKS.yaml` (statut ⏳, agent, horodatage) avant implémentation.
3. Prévoir un **agent de challenge** par phase (revue des effets de bord à chaque étape).
4. Restitution : bundle frais + G200 PASS + gates PASS + bandeau de conformité.

---

## 🤖 Prévision agents (par phase)

| Phase | Agent proposé | Rôle |
|---|---|---|
| 1 (T218) | 1 implémentation + 1 challenge | Déblocage + revue sécurité |
| 2 (T219) | 1 implémentation + 1 challenge | Buffer alarmes + revue |
| 3 (T220) | 1 implémentation | Bandeau + validation |

Max 2-3 agents en parallèle (contrainte utilisateur).

---

## 📌 Statut

- ✅ Contrats T218/T219/T220 créés et validés (PASS).
- ✅ Tâches ajoutées à `TASKS.yaml`.
- ⏳ **Décision humaine requise** pour la Phase 1 (option A/B/C) avant implémentation.
