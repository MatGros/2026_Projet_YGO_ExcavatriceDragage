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

### MES-012 — 🖥️ Présentation Machine & Manipulation Programme (Séance 2026-08-05)
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite` (chargée machine, avant modification)
- 🎯 **Périmètre** : Matin = présentation de la machine · manipulation du programme (config persistance, supervision, translation)
- 🚦 **Statut** : ⚪ **Non testé — en attente de données**
- 🔍 **Constat / Essai** : *(à renseigner pendant la séance)*
- 🛠️ **Solution / Décision** : *(à renseigner pendant la séance)*
- 📌 **Plan annoncé** : Après cette séance → charger **`v0.5.9_IOTest`** (nouvelle architecture) : test des **entrées/sorties de tous les devices** pour valider le câblage (NO/NC, sens, polarité)
- 📌 **Action différée** : *(réf `Txx` si nécessaire)*

---

### MES-013 — 🔌 `M3_BrakeRelease_RQ` : Sorties HW non mappées / GVL sans lien
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Sorties automate HW (`PRG_06_Outputs_LD`, `M3_BrakeRelease_RQ`), mapping E/S devices
- 🚦 **Statut** : 🟢 **Problème traité — noté** (revoir au chargement `v0.5.9_IOTest`)
- 🔍 **Constat** : Sorties HW **non mappées** physiquement dans le programme chargé ; **GVL utilisés sans lien** vers le matériel (pas d'adresse device).
- 🛠️ **Traitement** : Raccordement via **mapping E/S manuel CODESYS** (`Device.export`) — geste documenté `CODE/MAIN/PRG_06_Outputs_LD.st` §2 (l. 190-201, 221-225) : les `*_DQ/*_RQ` sont auto-créées par le mapping, absentes du bundle isolé.
- 📌 **Action** : Réauditer le mapping de **toutes** les sorties HW (M1/M2/M3) pendant `v0.5.9_IOTest`.

---

### MES-014 — ⛓️ Fdc traité comme « Fdc extrême » → défaut + blocage ; corrigé en Fdc normal
- 📅 **Date** : 2026-08-05 | 📍 **Lieu** : Terrain | 🏷️ **Version** : `v0.4.27_ConfigPersistence_TranslationSupervisionSuite`
- 🎯 **Périmètre** : Fins de course (Fdc) — traitement extrême vs normal (`FB_Translation` / `FB_Safety_Translation` M3)
- 🚦 **Statut** : 🟢 **Modification faite — OK**
- 🔍 **Constat** : Un Fdc était traité comme **Fdc extrême** → générait un **défaut avec blocage** (`ErrorId` bit6 / `ErrorLimitSwitch`, escalade `TonLimitSwitchOverrun` dans `FB_Safety_Translation.st`).
- 🛠️ **Modification** : Traitement passé en **Fdc normal** (simple butée/arrêt, sans défaut bloquant) — **fait, OK**.
- ⚠️ **À confirmer** : le code repo (`CODE/TRANSLATION/FB_Translation.st:23-24`, `FB_Safety_Translation.st:30-31,63`) garde la sémantique « extrême ». Vérifier que la modif « Fdc normal » est bien répercutée dans `v0.5.9` (nouvelle archi).

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
2. Mettre `✅` + réf MES dans `PLAN_TASK` §3.
3. Logger dans `VERSION_HISTORY.md` si maj CODE/DOC.
