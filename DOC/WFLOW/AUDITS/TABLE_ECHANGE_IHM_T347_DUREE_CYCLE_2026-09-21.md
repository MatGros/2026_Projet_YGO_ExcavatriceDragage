# 📋 Table d'échange IHM — Durées de cycle en minutes/secondes (T347)

> **État source** : implémenté, testé (CI FB_CycleSemiAuto : nouveau test `T347-001` PASS, aucun
> échec nouveau), gates mécaniques PASS — **pas encore committé** et **pas encore essayé sur le
> panel physique**. Les chemins ci-dessous sont stables (figés par `NAMING_CONVENTION.md` /
> contrat T347), mais un renommage éventuel imposé par la relecture orchestrateur doit être
> reconfirmé avant mise en service.
>
> 🎯 **Structure de référence unique côté IHM : `GVL_IHM`.** Aucun autre chemin n'est exposé.

## ⏱️ Durée écoulée du cycle en cours

| Champ | Valeur |
|---|---|
| **Adresse GVL_IHM — minutes** | `GVL_IHM.CycleSemiAuto.State.CurrentCycleElapsed_Min` |
| **Adresse GVL_IHM — secondes** | `GVL_IHM.CycleSemiAuto.State.CurrentCycleElapsed_S` |
| Types | `INT` / `INT` |
| Sens | Lecture seule côté IHM (aucune commande d'écriture) |
| Rôle | Durée écoulée du cycle SEMI_AUTO en cours (chrono armé sur `Lifecycle.Busy`) |
| Plages | minutes : entières, illimitées en pratique (chrono borné à 12 h, soit 720 min) · secondes : **0..59** |
| Remise à zéro | Automatique dès que le cycle n'est plus actif (`Lifecycle.Busy = FALSE`), et sur les branches de repos du mode (PRG_03) |

## 🧊 Durée du dernier cycle achevé (figée)

| Champ | Valeur |
|---|---|
| **Adresse GVL_IHM — minutes** | `GVL_IHM.CycleSemiAuto.State.LastCycleDuration_Min` |
| **Adresse GVL_IHM — secondes** | `GVL_IHM.CycleSemiAuto.State.LastCycleDuration_S` |
| Types | `INT` / `INT` |
| Sens | Lecture seule côté IHM (aucune commande d'écriture) |
| Rôle | Durée du dernier cycle SEMI_AUTO achevé, **figée à l'achèvement (X13 / AX18)** et conservée jusqu'au cycle suivant |
| Plages | minutes : entières · secondes : **0..59** |
| Remise à zéro | Non remise à zéro par le cycle suivant (elle est écrasée au prochain achèvement) ; remise à 0/0 uniquement sur les branches de repos du mode |

## 🖥️ Affichage recommandé (panel opérateur)

```text
Cycle en cours   : MM min SS s
Dernier cycle    : MM min SS s
```

- Formater chaque champ en entier **sans décimale** (demande explicite de l'utilisateur).
- Ne jamais additionner les deux champs en une valeur unique : ils sont complémentaires.
- Un cycle de 65 s doit s'afficher `1 min 5 s` (couvert par le test CI `T347-001`).

## ⚙️ Événement de figeage

Identique à celui du compteur de prélèvements : l'étape **AX18** de fin de cycle (ex-X13) fige
`LastCycleDuration_Min/_S` depuis `CurrentCycleElapsed_Min/_S`, **une seule fois par cycle**
(même garde de front que `SampleCount`, cf. `TABLE_ECHANGE_IHM_T299_COMPTEURS_2026-09-20.md`).

## 🔁 Non-régression

Le comportement du chronomètre est **strictement inchangé** par ce lot : démarre sur
`Lifecycle.Busy`, se fige à l'achèvement, repart de zéro hors cycle. Seul le **type d'exposition**
passe de `TIME` à 2 entiers (min + s).

## ⚠️ Points d'attention

1. **Anciens tags supprimés** : `GVL_IHM.CycleSemiAuto.State.CurrentCycleElapsed` et
   `.LastCycleDuration` (type `TIME`) **n'existent plus**. Tout tag graphique IHM qui les
   référençait doit être remappé sur les 4 nouvelles adresses.
2. Les 9 autres champs `TIME` de `GVL_IHM` (watchdogs 500 ms / 900 ms / 1 s 250, heartbeat IHM,
   timeout benne) sont **hors périmètre** et restent en `TIME`.
3. `GVL_IHM.CycleSemiAuto.State.DrainTimeElapsed_S` (temps restant d'égouttage, `INT` secondes)
   est **inchangé** par ce lot.

---
*Généré par DSH14 le 2026-09-21 pour le lot T347 — à réémettre si la relecture orchestrateur fait
bouger une adresse.*
