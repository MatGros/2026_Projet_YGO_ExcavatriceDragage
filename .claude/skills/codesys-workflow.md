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
- `DOC/AF_Partie3_Template_FB_Commun_v1.1.md` → contrat FB (Enable/Reset/SafeStop/Ready/Error…) + réutilisation libs
- `DOC/AF_Partie2_Architecture_Programme_v2.3.md` → architecture, tâches, flux
- `DOC/AF_Partie1_Analyse_Fonctionnelle_v1.1.md` → équipements & fonctions

⚠️ Toujours utiliser la **version la plus récente** (suffixe `_vX.X` le plus élevé). Anciennes versions dans `DOC/Archives/`.

✋ Si une règle DOC contredit la demande → signaler avant de coder.

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

📁 **Sortie obligatoire dans `DOC/`** : le code ST généré **et** la note d'application sont écrits comme fichier(s) dans `DOC/` (jamais ailleurs).

📐 **Format livrable = suite de la série AF, orienté métier** :
`AF_PartieN_Fonction_<Metier>_vX.Y.md` (ex. `AF_Partie4_Fonction_Joystick_v1.0.md`, `AF_Partie5_Fonction_Winch_v1.0.md`).
Structure attendue : rôle métier → pipeline/blocs → interface → sécurité → mapping E/S → **implémentation ST commentée** → note d'application CODESYS 3.5 → REX.
Un fichier = une fonction métier (code ST + note d'application ensemble). Versionner `vX.Y`, anciens dans `DOC/Archives/`.

Style commentaires :
```
(* ═══════════════════════════════════════════════
   🎮 FB_Joystick — Acquisition + traitement Hall
   ───────────────────────────────────────────────
   📥 Enable    : autorisation traitement
   📤 Ready     : valeurs valides disponibles
   🛡️ SafeStop  : arrêt sûr prioritaire
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
- [ ] Code ST commenté FR + emoji **écrit dans `DOC/` (fichier versionné)**
- [ ] Note d'application manuelle CODESYS 3.5 **dans `DOC/`**
- [ ] REX + specs versionnées `vX.X`
