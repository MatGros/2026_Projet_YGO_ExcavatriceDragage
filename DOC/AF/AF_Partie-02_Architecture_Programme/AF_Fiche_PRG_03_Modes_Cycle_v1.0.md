# Fiche PRG‑03 — Modes & Cycle (v1.0)

> 🎯 Arbitrage des droits et séquencement. AF‑02 porte l'ordre `MainTask` global.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| `PRG_02.HwIn/Data`, `GVL_IHM`, retours procédé N‑1 | `Auth`, demandes cycle | Écrire une sortie physique ou porter une interdiction métier M1/M2/M3 |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 🎚️ Modes | Calculer mode, permissions, inhibitions et autorisations. | 🟢 acquisition/IHM | `PRG_02`, `GVL_IHM.Modes` et commandes associées | Résultat modes local courant. |
| 2. 🔄 Cycle | Évaluer la séquence semi‑automatique. | 🟡 `Auth` N‑1 dans le code actuel ; retours procédé N‑1 admis | Autorisations, IHM cycle, retours publics M1/M2/M3 | Demandes cycle cohérentes avec les entrées lues. |
| 3. 📤 Publication | Exposer les droits et demandes. | 🟢 résultat modes courant | Résultats des phases 1‑2 | `Auth` courant pour PRG‑04/05. |

## ⚠️ Décision ouverte

Le cycle consomme actuellement `Auth` avant sa publication depuis le calcul des modes : retard N‑1
(10 ms typiques). Tolérable uniquement après preuve d'absence d'effet safety/pilotage ; sinon publier
`Auth` avant l'appel cycle. Aucun code ne doit être changé sur cette base sans lot dédié.

## 📚 Documents liés

- [AF‑02](../AF_Partie-02_Architecture_Programme_v3.2.md), AF‑04 Cycle, AF‑05 Modes, AF‑03 contrats.
