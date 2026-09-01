# 🧪 Fiche de test — Réduction BrakeDelayMagnetise M3 (300ms → 100ms)

> **Réf** : Réglage brake M3 · **Date** : 2026-09-01 · **Fichier** : `ST_fbTranslation_Cfg.st` L33
> **Type** : validation machine
> **Statut** : ⏳ À exécuter

---

## 🧪 Test 1 — Timing de décollage du frein

**Objectif** : vérifier que le frein se relâche ~200ms après la commande moteur.

| # | Action | Attendu |
|---|---|---|
| 1 | M3 à l'arrêt, frein collé (`BrakeCmd`=FALSE) | — |
| 2 | Commande un mouvement M3 (joystick X / bouton) | — |
| 3 | Mesure écart commande moteur → relâchement frein (`BrakeCmd`=TRUE) | **≈ 200ms** (100 mag + 100 contact) |

**Critère de validation** : ✅ ~200ms (au lieu de 400ms) · ⚠️ >300ms = modif non appliquée · ⚠️ <100ms = décollage trop précoce.

---

## 🧪 Test 2 — Non-régression sécurité (le frein tient)

**Objectif** : vérifier que la réduction n'a pas introduit de mouvement non commandé.

| # | Action | Attendu |
|---|---|---|
| 1 | M3 à l'arrêt, aucune commande | `BrakeCmd` reste FALSE (aucun relâchement parasite) |
| 2 | Commande un mouvement puis relâche immédiatement | Frein recollé immédiatement, M3 s'arrête sans dérive |
| 3 | Vérifie aucun `ContactorIncoherentError` | Retour contacteur cohérent avec commande |

**Critère de validation** : ✅ aucun mouvement non commandé · ✅ frein recollé immédiatement · ✅ pas de défaut contacteur.

---

## ✅ Résultat

| Test | Résultat | Commentaire |
|---|---|---|
| Test 1 (timing) | ☐ | |
| Test 2 (sécurité) | ☐ | |
