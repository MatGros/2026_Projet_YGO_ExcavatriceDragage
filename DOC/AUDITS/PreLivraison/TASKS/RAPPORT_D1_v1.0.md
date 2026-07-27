# 🩺 Rapport D1 — Preflight & symétrie M1/M2

## Interfaces

- `FB_Preflight` : front `Execute`, arrêt stabilisé `MachineIsStill`, verdict `PreflightOk`, `PreflightDone`, bitfield `PreflightErrorId`.
- `FB_WinchSymmetry` : commandes/retours/positions/vitesses M1-M2, configuration persistante, sorties `SymmetryOk` et `SymmetryValid`.

## Bits Preflight

| Bits | Contrôle attendu | Cause probable |
|---|---|---|
| 0..2 | Freins M1/M2/M3 serrés | desserrage ou polarité retour |
| 3..4 | Contacteurs M1/M2 retombés | contacteur collé |
| 5..7 | Thermiques M1/M2/frein OK | thermique ou fil coupé |
| 8..9 | Phases OK, câble M2 tendu | phases/câble mou |
| 10 | Mot M3 cohérent | câblage positions |
| 11 | pas de contacteur sans chaîne AU | collage/câblage AU |
| 12..13 | Codeurs M1/M2 opérationnels | bus codeur |
| 14..15 | M1/M2 homés et en bornes | référencement/position |

## Mesures MES-008

Mouvement valide : mêmes sens, deux commandes actives ≥ 1 s, vitesses M1/M2 ≥ 0,05 m/s.
Seuils initiaux PERSISTENT : délais 100 ms, distance 0,10 m, arrêt 200 ms. À confirmer sur site.

⚠️ `MeasuredSpeedMps` est une dérivée brute 10 ms sans filtre (~0,02 m/s de bruit); le seuil
0,05 m/s l'écarte. Constat C5 / filtrage hors D1.

## Preuve observateur

Les deux FB n'écrivent que leurs sorties et `ST_WinchSymmetryData` PERSISTENT. `PRG_11` lit
`PRG_00`, `PRG_02`, `PRG_03`, `PRG_06`, `PRG_10`; `PRG_09` publie vers `GVL_IHM.Commun`.
Ils ne sont reliés à aucun `SafeStop`, `PowerCutOff` ou ordre mouvement.

## Correctif C1 diagnostic

`Idx104/108_BrakeIsOpen_DI` devient `Idx104/108_BrakeApplied`; les trois publications PRG_11
reflètent désormais explicitement `TRUE = frein serré normalisé`.
