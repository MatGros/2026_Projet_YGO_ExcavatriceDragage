# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : Historique factuel des séances banc/terrain (actions, mesures, constats, décisions).
> 📌 **Reliquats & Actions** : `DOC/PLAN_TASK_v1.0.md` §3 (registre maître `Txx`).

---

## 1. ⚡ Règles & Statuts

| Élément | Emplacement |
|---|---|
| Test prévu & verdict Pass/Fail | Checklist métier / `PLAN_TASK` §4 |
| Mesure, anomalie, réglage terrain | 📍 Ce registre |
| Code, câblage, action différée | 📌 Ligne `Txx` dans `PLAN_TASK` §3 |
| Évolution CODE/DOC majeure | 📦 `VERSION_HISTORY.md` |

### 🚦 Statuts
- 🟢 **Validé** : Conforme + preuve
- 🟡 **À surveiller** : Fonctionne, seuil à confirmer
- 🟠 **Action ouverte** : Référencé par un `Txx`
- 🔴 **Bloquant** : Interdit le mouvement / la suite
- ⚪ **Non testé** : En attente

---

## 2. 📝 Entrées de Séances

### 🎯 Objectif de séance — 2026-08-07
- **Cible** : réaliser un **cycle complet** (descente → contact Kobold → remontée → vidage trémie) **sans sécurité particulière, ou à sécurité limitée** — validation mécanique/mouvement avant la mise en place des protections finales.
- ⚠️ **Risque noté (devoir d'alerte)** : cycle réel sur machine sans les sécurités complètes → **uniquement avec bypass explicites** (`Bypass.Global`/ciblés), **homme-mort** maintenu, vigilance opérateur, **aucun redémarrage auto après défaut**, personnes écartées de la zone.
- 📌 **Point à clarifier** : la barrière `SafetyStructureNotValidated := TRUE` (`PRG_06_Outputs_LD.st:50`) coupe toutes les sorties → confirmer le moyen d'autoriser le mouvement pour cet essai (retrait ponctuel vs bypass).

---

### MES-020 — 🔧 Simplification : commande **frein directe** avec les contacteurs de sens
- 🟦 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Treuils M1/M2 — commande frein vs contacteurs de sens
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/06)**
- 🔍 **Constat / Décision** : Simplification : le frein est commandé **directement** par la commande des **contacteurs de sens** (`BrakeCmd := RelayFwd OR RelayRev`). Aucun écart frein/mouvement possible.
- 🛠️ **Preuve code** : `CODE/TREUILS/FB_WinchOutputInterlock_LD.st:244` (`BrakeCmd := RelayFwd OR RelayRev`), `FB_WinchOutputInterlock_LD.st:13-15`, `FB_Winch.st:9` (+ câblage `PRG_06_Outputs_LD`).
- 📌 **Action** : À tester au chargement `v0.5.9_IOTest` (séquence frein+sens).

---

### MES-021 — 🏗️ Ajout mode « au-dessus de la trémie » : joystick → commande ouverture benne
- 🟢 **Date** : 2026-08-07 | 🟧 **Lieu** : Terrain | 🏷️ **Version** : `v0.5.9_IOTest` (nouvelle architecture)
- 🎯 **Périmètre** : Benne M2 / translation M3 — mode vidage à la trémie, pilotage joystick
- 🚦 **Statut** : 🟢 **Implémenté (déjà dans le repo, daté 08/07)**
- 🔍 **Constat** : Ajout d'un **mode « au-dessus de la trémie »** où le **joystick commande l'ouverture** (de la benne).
- 🛠️ **Preuve code** : `CODE/MAIN/PRG_04_Treuils_Benne.st:221-234` (`DumpAtTremieAssistActive` + `M3_AtTremieStable` → `DumpAtTremieBucketOpenArmed` → `CmdOpen_IHM`). Le mouvement réel reste gouverné par la demande joystick (`MotionRequestActive`/`MotionDirection`).
- 📌 **À valider** : comportement armement ouverture sur site au chargement `v0.5.9_IOTest`.

---

## 3. 📄 Modèle à Dupliquer

```md
### MES-XXX — Titre court
- 📅 **Date** : YYYY-MM-DD | 📍 **Lieu** : Simulation / Banc / Terrain | 🏷️ **Version** : Commit/Export
- 🎯 **Périmètre** : Axe / Fonction / Composant
- 🚦 **Statut** : 🟢 / 🟡 / 🟠 / 🔴 / ⚪
- 🔍 **Constat / Essai** : Mesures, observations, faits
- 🛠️ **Solution / Décision** : Réglage, fix, validation
- 📌 **Action différée** : Réf `Txx` dans PLAN_TASK §3
```

---

## 4. ✅ Procédure de Clôture `Txx`
1. Ajouter l'entrée `MES-XXX` avec preuve.
2. Mettre `✅` + références MES dans `PLAN_TASK` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.