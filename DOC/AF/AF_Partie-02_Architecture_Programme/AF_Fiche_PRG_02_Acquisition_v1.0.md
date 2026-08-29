# Fiche PRG‑02 — Acquisition (v1.0)

> 🎯 Détail d'implémentation de `PRG_02_Acquisition`. AF‑02 reste propriétaire de l'ordre global
> `MainTask` à 10 ms et des contrats inter‑PRG.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| Terrain/PDO, `GVL_Simulation`, `GVL_IHM`, `GVL_PERSISTENT`, états `PRG_03/04/05/06` explicitement N‑1 | `HwReal`, `HwSim`, `HwIn`, données acquisition | Décider le mouvement translation ou choisir une source hors `HwIn` |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | 🎯 But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. 🧪 Politique simulation | Activer/désactiver les domaines simulés et calculer la sélection par domaine. | 🟢 `GVL_Simulation` courant | `SimulationModeActive`, `SimWinchActive`, `SimTranslationActive`, `SimOperatorActive`, `SimSafetyActive` | Les quatre `*InputSourceSimulated` locaux sont les seuls gardiens réel/simulé. |
| 2. 📥 Image réelle | Acquérir tout le terrain avant toute qualification. | 🟢 courant | PDO/E/S terrain et états device | `HwReal.Winch`, `.Translation`, `.Operator`, `.Machine` complets. |
| 3. 🩺 Diagnostics | Qualifier DI, CANopen et EtherCAT. | 🟢 `HwReal` ; 🟡 reset `PRG_07` N‑1 | `HwReal`, bypass IHM autorisés | Disponibilités et défauts cohérents avec l'image réelle du scan. |
| 4. 🧪 Banc simulé | Construire les retours banc. | 🟢 stimuli/HwReal ; 🟡 ordres `PRG_04/05/06` N‑1 = 10 ms typiques | `GVL_Simulation.*`, `PRG_06_Outputs.Data.*`, demandes `PRG_04/05.Data.*`, `GVL_PERSISTENT._SimEncoderRawPosM1/M2` en `VAR_IN_OUT` | `HwSim.Winch/.Translation/.Operator/.Machine`; positions simulées persistantes. |
| 5. 🔀 Aiguillage unique | Construire l'image métier. | 🟢 images du scan | `HwReal.<domaine>`, `HwSim.<domaine>`, `*InputSourceSimulated` | Pour chaque domaine : `HwIn.<domaine> := SEL(<domaine>InputSourceSimulated, HwReal.<domaine>, HwSim.<domaine>)`. |
| 6. 🕹️ Joystick | Qualifier intention, neutre et homme‑mort. | 🟢 `HwIn`/diagnostic ; 🟡 reset `PRG_07` N‑1 | `HwIn.Operator`, CANopen, `GVL_IHM.JOY1Joystick.Cmd`, mémoire neutre persistante | Intention opérateur sûre dans `Data`. |
| 7. 🎯 Codeurs/homing M1‑M2 | Mesurer, référencer et publier les deux treuils. | 🟢 `HwIn`/diagnostic ; 🟡 `PRG_03.Auth` et états `PRG_04` N‑1 | `HwIn.Winch.COD1/2_*`, EtherCAT, `GVL_IHM.M1TreuilRetenue/.M2TreuilBenne`, config/calibration persistantes | `Data.CablePosM1/M2`, vitesses, défauts et homing. |

## 🛡️ Invariants

- `HwIn` est l'unique image d'entrée des fonctions métier : ne pas raccorder un consommateur métier
  directement à `HwReal` ou `HwSim`.
- Le retard des commandes du banc est volontaire : un scan à 10 ms, sans boucle inter‑PRG.
- `HwIn.Translation` est produit ici, mais le décodage des capteurs M3 est propriété cible de
  `PRG_05_Translation` (migration code C3 à réaliser ; le code actuel le fait encore ici).
- Les mémoires `_CalibM1/_CalibM2/_SimEncoderRawPosM1/_SimEncoderRawPosM2` sont `PERSISTENT RETAIN`.
  La GVL est `qualified_only` ; avant refactor, valider l'accès cible `GVL_PERSISTENT.<variable>` ou
  un alias explicite. Ne jamais créer une seconde mémoire.

## ⚠️ Exceptions et dettes connues

- `COD1/2_PresettTrigCmd`, `CodeSeqTrigCmd` et `PresetValue` sont des commandes de protocole codeur
  produites par le homing : exception à PRG‑06, jamais une commande moteur/frein.
- Le référencement M2 lit `PRG_04.instWinchM1/M2.Status.Busy` au scan N‑1. Cible :
  `PRG_04.Data.WinchM1/2State.Busy` ; voir registre AF‑02.
- `ArmingPermit := TRUE` est un stub 🔴 C4. Son unique TBD est AF‑08 §10 Q1 ; ne pas le considérer
  comme une permission système réelle.

## 🧪 Tests associés

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé,
> non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

| ID | Vérifie | Preuve | Etat |
|---|---|---|---|
| <nobr><code>TC-P02-001</code></nobr> | Producteur unique d'images et données | Revue des contrats + gate de liaison | `NV` |
| <nobr><code>TC-P02-004</code></nobr> | Ordre `MainTask` et retards N‑1 explicités | Revue manuelle de l'ordre CODESYS | `NV` |

## 📚 Documents liés

- [AF‑02 Architecture programme](../AF_Partie-02_Architecture_Programme_v3.2.md)
- AF‑03 : contrats FB/DUT.
- AF‑06, AF‑08, AF‑09, AF‑12, AF‑13 : E/S, joystick, codeurs, diagnostics, simulation.
