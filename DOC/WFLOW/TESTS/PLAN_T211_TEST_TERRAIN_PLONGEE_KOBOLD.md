# 🗓️ Plan T211 — Test terrain séquence de plongée (Dive) avec le Kobold

> **Réf** : T211 · **Date** : 2026-09-01 · **Criticité** : C2 · **Domaine** : TERRAIN
> **Objectif** : valider sur machine réelle la séquence de plongée avec le Kobold, suite aux essais de la dernière mise en service.
> **Statut** : ⏳ À planifier (programmation site)

---

## 🎯 Périmètre

| # | Point validé | Comment |
|---|---|---|
| 1 | **Lancement du cycle diving en MAINT** | Toggles, préconditions, benne ouverte, position |
| 2 | **Détection de fond Kobold** | Immersion validée + contact fond |
| 3 | **Bridage Palier ≤ 4** | Palier 5 interdit en plongée |
| 4 | **Transition Dive → Extraction** | Fermeture + remontée |

## 📋 Prérequis

- [ ] Machine réelle accessible (carrière noyée)
- [ ] Code compilé + téléchargé (refactor T215 + brake M3 appliqués)
- [ ] Capteur Kobold opérationnel
- [ ] Treuils M1/M2 référencés (homing)

## 🧪 Scénarios de test

### Scénario 1 — Plongée nominale
1. MAINT_N1, active `TglEnableDiveSearch`.
2. Benne ouverte, treuils ≥ 1m, Kobold au repos.
3. Descends (joystick Y vers le bas, homme-mort armé).
4. **Attendu** : `DiveState` progresse WAIT_PRECONDITIONS → READY_TO_DESCEND → SEARCHING_IMMERSION → SEARCHING_BOTTOM → BOTTOM_CONFIRMED.

### Scénario 2 — Détection fond + transition extraction
1. Après le contact fond, tirage vers l'arrière (Y > 0).
2. **Attendu** : fermeture benne, remontée contrôle, remontée nominale.

### Scénario 3 — Palier 5 bloqué en plongée
1. Pendant la plongée, tente Palier 5.
2. **Attendu** : refus, `Palier5ForbiddenFault`, pas de mouvement au-delà de palier 4.

### Scénario 4 — Relâchement / arrêt
1. Relâche le manche en cours de plongée.
2. **Attendu** : descente stoppée sans perte d'étape, reprise sur geste conscient.

## 📅 Planning

| Étape | Contenu | Responsable |
|---|---|---|
| 1 | Programmation site | Utilisateur / Chef de site |
| 2 | Exécution tests 1-4 | Utilisateur / opérateur |
| 3 | Remplir la fiche de résultat | Utilisateur |
| 4 | Analyse des écarts | DSH (orchestrateur) |

## ✅ Résultat

| Scénario | Résultat | Commentaire |
|---|---|---|
| 1 — Plongée nominale | ☐ | |
| 2 — Fond + extraction | ☐ | |
| 3 — Palier 5 bloqué | ☐ | |
| 4 — Relâchement | ☐ | |
