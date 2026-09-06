# 🕵️ Session de Troubleshooting — WinchSel M2 / offset — 20260906

> 📅 Date : 2026-09-06 · 🧪 Situation : banc/simulation (d'après snapshots PLC) · 📄 Statut : ANALYSE À VALIDER

## 1. 🧪 Contexte figé

Passage signalé de `WinchSel=0` à `WinchSel=2`, sans commande Y. L'attendu exprimé est : aucun déplacement de la position M2.

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---:|---|
| Sélecteur avant | `GVL_Troubleshooting.D_Joystick.SelJoystickWinch` | `INT#0` | 2026-09-06 22:23:34 |
| Position câble M2 avant | `...H_LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | `21.6428223 m` | 2026-09-06 22:23:34 |
| Sélecteur après | `GVL_Troubleshooting.D_Joystick.SelJoystickWinch` | `INT#2` | 2026-09-06 22:24:01 |
| Position câble M2 après | `...H_LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | `21.6428223 m` | 2026-09-06 22:24:01 |
| Offset benne avant | `...K_BenneOuvertureFermeture.Idx103_OffsetPos_M` | `15 m` | 2026-09-06 22:23:34 |
| Offset benne après | `...K_BenneOuvertureFermeture.Idx103_OffsetPos_M` | `14.2907715 m` | 2026-09-06 22:24:01 |

## 2. 🎯 Symptôme

Le changement de sélection M2 semble déplacer la position M2 ; la position câble brute ne bouge pas, mais l'offset de correction change de `-0.7092285 m`.

## 3. 🧩 Indices / historique

- 🟢 Snapshots 22:23:34 et 22:24:01 : position câble M1/M2, commandes relais M2, frein et demande mouvement M2 inchangés/inactifs au basculement.
- 🟢 `OffsetPos_M` après basculement = `CablePosM2 - CablePosM1` = `21.6428223 - 7.352051` = `14.2907713 m` (écart d'arrondi CSV).
- 🟢 `FB_Bucket` : `ManualBucketJogActive` devient vrai avec `WinchSel=2` en MAINT, puis impose `OffsetTargetM := CablePosM2 - CablePosM1` et `ActiveOffsetM := OffsetTargetM`.
- 🟡 Le comportement a été introduit par les commits du 2026-09-04 (`0cef16f96` pour le suivi immédiat d'offset en jog ; `5c9404c19` pour le vrai sélecteur `WinchSel`).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Attendu | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | M2 a reçu une commande physique au passage de sélection | M2 câble, relais, `MotionRequested`, frein | changement / actif | câble inchangé ; relais/frein inactifs ; demande false après basculement | ❌ écartée |
| 2 | Une action benne `Busy` restée active a commandé M2 | `BucketBusy`, open/close requests | true | false aux deux captures | ❌ écartée pour cet instant |
| 3 | La valeur vue est la position corrigée, affectée par l'offset | `OffsetPos_M`, M1/M2 câble | offset stable si seulement sélection | 15 → 14.2907715 = M2−M1 | ✅ confirmée |
| 4 | Une modification des 5–6 septembre a réintroduit ce recalage | `git blame` `FB_Bucket` §5 | pas de suivi direct à la seule sélection | `BucketJogActive` inclus dans suivi immédiat | ✅ régression de contrat d'affichage/offset à traiter |

## 5. 📊 Arbre vertical

```text
[WinchSel=0 → 2]
  ├─ [CablePosM2 = 21.6428223 m → 21.6428223 m] ✅ aucun mouvement physique dans la fenêtre
  ├─ [Relais M2 / BrakeCmd = FALSE] ✅ aucun ordre final observé
  └─ [ManualBucketJogActive = TRUE]
       → [OffsetTargetM = CablePosM2 - CablePosM1 = 14.2907715 m]
       → [ActiveOffsetM = OffsetTargetM]
       → [position M2 corrigée change de 0.7092285 m] ✅ cause du symptôme IHM
```

**Résumé une ligne** : `[WinchSel 0→2] → [jog M2 actif] → [offset 15→14.2907715] → [position corrigée apparente −0.7092285 m]`.

## 6. 📊 Données / chronogramme

| Événement | WinchSel | CablePosM2 | OffsetPos_M | Commande M2 |
|:---:|:---:|:---:|:---:|:---:|
| 22:23:34 | 0 | 21.6428223 m | 15 m | inactive |
| basculement | 0 → 2 | — | recalage offset | aucune commande observée |
| 22:24:01 | 2 | 21.6428223 m | 14.2907715 m | inactive |

## 7. 🏁 Conclusion

- **Cause racine** : le mode `WinchSel=2` active le chemin jog benne ; `FB_Bucket` recale l'offset actif sur l'écart instantané M2−M1. Les consommateurs IHM utilisant la position corrigée voient donc un saut, alors qu'aucune position câble M2 n'a changé pendant le passage observé.
- **Statut** : cause logicielle de l'écart d'affichage confirmée ; correction non appliquée.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : distinguer en IHM la position câble brute et la position corrigée ; considérer le saut de correction comme une référence, pas un déplacement.
- **Option 2 (définitif)** : exiger un mouvement Y réellement autorisé (homme-mort + direction) avant le recalage immédiat `BucketJogActive`, ou conserver l'offset à l'entrée de `WinchSel=2` jusqu'au premier mouvement. Étudier les impacts MecaE, SyncDeviation et limite haute M2 avant modification.
- **⚠️ Validation requise** : humaine ; aucune modification de code / variable forcée.

## 9. ✅ Vérification de la correction / non-régression

- À définir après décision humaine : snapshot avant/après `0→2` au neutre, puis premier mouvement M2 contrôlé ; vérifier câble brut stable au basculement, absence de relais, et comportement MecaE/synchro/limite haute.

## 10. 📝 Journal

- 2026-09-06 : comparaison des snapshots `222334` et `222401`, analyse statique et historique Git des 4–6 septembre ; aucune écriture dans `CODE/`.
