---
name: codesys-workflow
description: Workflow obligatoire pour toute modification du programme automate CODESYS 3.5 (Device.export). Impose lecture des règles DOC, analyse architecture, plan groupé par concept, génération ST commentée FR, note d'application manuelle, et retour d'expérience versionné. Déclencher dès que l'utilisateur demande de modifier/créer/analyser FB, PRG, variables, ou "le programme automate".
---

# 🏗️ Workflow CODESYS — Excavatrice de Dragage

Procédure **stricte et itérative** pour modifier le programme automate.
L'utilisateur applique **manuellement** chaque modif dans CODESYS 3.5 (copie du code ST).

---

## ⛔ RÈGLE D'OR

**NE JAMAIS faire ce qui n'est pas spécifié.**
Spec incomplète ou ambiguë → **STOP + demander clarification.** Jamais d'approximation, jamais de refactor caché.

---

## 📚 Étape 0 — Charger les règles (OBLIGATOIRE avant tout)

Lire et appliquer **systématiquement** :
- `DOC/NAMING_CONVENTION.md` → PascalCase, préfixes, pas de hongrois
- `DOC/AF_Partie3_Template_FB_Commun_v1.2.md` → contrat FB (Enable/Reset/EmergencyStopOk/Mode/Ready/Error… ; profils d'interface §1bis : FB standard vs FB de mouvement `StartStop`/`SafeStop` vs briques réduites ; précédence Enable > SafeStop > StartStop) + réutilisation libs
- `DOC/AF_Partie2_Architecture_Programme_v2.5.md` → architecture, tâches, flux
- `DOC/AF_Partie1_Analyse_Fonctionnelle_v1.2.md` → équipements & fonctions

⚠️ Toujours utiliser la **version la plus récente** (suffixe `_vX.X` le plus élevé). Anciennes versions dans `DOC/Archives/`.

✋ Si une règle DOC contredit la demande → signaler avant de coder.

🚫 **`DOC/Archives/` = versions PÉRIMÉES** : ne jamais lire ni prendre en compte ce dossier (gitignoré). Toujours la version active (suffixe `_vX.Y` le plus élevé à la racine de `DOC/`).

---

## 🔍 Étape 1 — Comprendre l'architecture

Lire `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` (⚠️ ~89k lignes → **analyse ciblée par grep**, jamais en entier).

Objectif : architecture générale + **devices de communication** (EtherCAT, CANopen…).
Repérer : tâches, mapping E/S, devices bus.

---

## 🔬 Étape 2 — Analyser l'existant

Avant toute modif, cartographier :
- **Variables** concernées (GVL, déclarations FB/PRG)
- **Programmes** (PRG_*) et **Function Blocks** (FB_*) impactés
- Dépendances / appelants

But : se préparer à une modif **chirurgicale**, sans casser le reste.

---

## 🧩 Étape 3 — Plan groupé par concept

- Regrouper les modifs **par concept fonctionnel** (pas fichier par fichier)
- ❌ **Pas de refactor global** sauf si réellement utile **ET validé par l'utilisateur**
- Présenter le plan → **attendre validation explicite** avant de coder

---

## 💻 Étape 4 — Génération code ST + note d'application

Après validation du plan :

1. **Code ST** respectant le contrat FB et le nommage
2. **Commentaires superbien détaillés, en français, avec emoji** 🎯
   - Bloc d'en-tête : rôle, entrées, sorties, sécurité
   - Commentaire sur chaque section logique
3. **Note d'application CODESYS 3.5 détaillée** : où coller, quel POU, quelles déclarations, ordre des étapes — car l'utilisateur applique **tout à la main**.

📁 **Double sortie obligatoire** :

1. 📂 **Code ST à copier → dossier `CODE/`** (jamais ailleurs).
   - Tout code que l'utilisateur doit copier/créer dans CODESYS est écrit comme **fichier `.st` brut** dans `CODE/`.
   - Nom = nom du POU, ex. `CODE/PRG_JOY1.st`, `CODE/FB_Winch.st`.
   - C'est ce fichier que l'utilisateur copie-colle dans CODESYS.

2. 📄 **Doc métier + note d'application → dossier `DOC/`** (série AF).
   - `AF_PartieN_Fonction_<Metier>_vX.Y.md`, **N ≥ 8** (ex. `AF_Partie8_Fonction_Joystick_v1.1.md`, `AF_Partie9_Fonction_Winch_v1.0.md`).
   - Structure : rôle métier → pipeline/blocs → interface → sécurité → mapping E/S → **référence au(x) fichier(s) `CODE/*.st`** → note d'application CODESYS 3.5 → REX.
   - Versionner `vX.Y`, anciens dans `DOC/Archives/`.

🧭 **Règle anti-doublon (STRICTE)** : le **corps/implémentation** ST n'existe **qu'une seule fois**, dans `CODE/*.st`.
- ✅ `DOC/` PEUT contenir : l'**interface IN/OUT** (tableaux des entrées/sorties, types, rôles), le mapping E/S, le pipeline.
- ❌ `DOC/` ne recopie **JAMAIS** le **corps** du POU (logique, appels, calculs) — il **référence** `CODE/xxx.st`.
`CODE/` = source unique exécutable à copier ; `DOC/` = métier + interface IN/OUT + mode d'emploi qui pointe vers `CODE/`.

Style commentaires :
```
(* ═══════════════════════════════════════════════
   🎮 FB_Joystick — Acquisition + traitement Hall
   ───────────────────────────────────────────────
   📥 Enable          : autorisation traitement ; FALSE = neutralisation (sorties coupées)
   📤 Ready            : valeurs valides disponibles
   🛡️ EmergencyStopOk  : conditions globales OK (chaîne AU réarmée)
   ⚠️ FB de mouvement uniquement (pas FB_Joystick) : StartStop (rampe normale),
      SafeStop en entrée (sortie du bloc safety métier concerné → rampe rapide, Enable maintenu)
   ═══════════════════════════════════════════════ *)
```

---

## 🔁 Étape 5 — Retour d'expérience (si validé fonctionnel)

Quand l'utilisateur confirme que ça marche :
- **Review** : capitaliser la connaissance acquise
- Proposer mise à jour des specs `DOC/` pour accumuler le savoir
- ⚠️ **Versionning obligatoire** : nouveau nom de fichier `vX.X` (ne jamais écraser, ex. `_v2.2` → `_v2.3`)

---

## 🔄 Étape 6 — Rebouclage

Attendre le **nouvel export** utilisateur (Device.export régénéré depuis CODESYS) → reprendre à l'étape 1.

---

## ✅ Checklist rapide

- [ ] Règles DOC lues + appliquées
- [ ] Spec complète ? (sinon STOP)
- [ ] Architecture + devices compris
- [ ] Existant analysé (variables/PRG/FB)
- [ ] Plan groupé par concept **validé**
- [ ] Code ST à copier commenté FR + emoji **écrit dans `CODE/*.st`**
- [ ] Doc métier + note d'application CODESYS 3.5 **dans `DOC/AF_PartieN_Fonction_*`**
- [ ] REX + specs versionnées `vX.X`
