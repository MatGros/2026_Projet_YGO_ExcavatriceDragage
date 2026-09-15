# 🕵️ Session de Troubleshooting — Kobold IHM

> 📅 Date : 2026-09-15 · 🧪 Situation : SIMULATION BANC · 📄 Statut : CONCLU — évolution IHM à valider

## 1. 🧪 Contexte figé

Snapshot : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260915_000306.csv`.

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---:|---|
| Mode | `GVL_Troubleshooting.A_ContexteMachineGlobal.Idx101_ModeActive` | `SEMI_AUTO` | 2026-09-15 00:03:06 |
| Simulation | `...Idx102_SimulationEnabled` | `TRUE` | idem |
| DI brut Kobold | `GVL_Troubleshooting.B_Inputs.Machine.M1_M2_KoboldBottomTouch_DI` | `FALSE` | idem |
| Étape cycle | `GVL_Troubleshooting.G_CycleSemiAuto.Idx206_Step` | `AX_STAB` | idem |
| Étape au repli | `...Idx208_StepAtError` | `AX7_SEARCH_BOTTOM` | idem |
| Défaut cycle mémorisé | `...Idx217_FaultLatched` | `TRUE` | idem |
| Fond Kobold IHM | `...Idx303_KoboldBottomTouch` | `FALSE` | idem |
| M1 | `GVL_Troubleshooting.H_LevageSynchroniseM1M2.Idx101_M1_CablePos_M` | `-5,98535156 m` | idem |
| M2 | `...Idx102_M2_CablePos_M` | `-3,48339844 m` | idem |
| Écart synchro | `...Idx103_SyncDelta_M` | `-2,50195313 m` | idem |

## 2. 🎯 Symptôme

Le DI `PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI` a été vu à `TRUE`, mais
l'indication IHM de contact fond reste à `FALSE`.

## 3. 🧩 Arbre des causes et preuves

| Hypothèse | Preuve | Verdict |
|---|---|---|
| Acquisition DI non routée au cycle | `PRG_03_Modes_Cycle` transmet le DI à `KoboldImmersed`; `PRG_07` le transmet à la vue troubleshooting. | ❌ écart de routage éliminé |
| IHM affiche le DI brut | `PRG_07_Supervision` affecte `CycleSemiAuto.State.KoboldContactFond := SequenceState.BottomStopByKobold`. | ❌ faux : c'est un état de fond confirmé |
| DI actif pendant l'immersion | Contrat de simulation : DI haut après alimentation, puis bas au fond. Le DI haut est le signal d'immersion, pas le contact fond. | ✅ comportement attendu |
| Snapshot pris au bon moment | Snapshot en `AX_STAB`, défaut mémorisé, DI brut déjà bas. | ❌ pas représentatif de l'immersion active |

## 4. 📊 Flux réel

```text
DI brut Kobold = 1 (immersion)
  → FB_CycleSemiAuto.KoboldImmersed
  → qualification immersion AX6
  → DI brut = 0 au fond, confirmé 100 ms en AX7
  → SequenceState.BottomStopByKobold = 1
  → IHM.CycleSemiAuto.State.KoboldContactFond = 1
```

## 5. 🏁 Conclusion

- **Cause racine** : confusion entre le **retour brut Kobold** (haut sous l'eau) et l'état
  **fond Kobold confirmé** (haut seulement après retombée du DI au fond).
- L'IHM actuelle ne publie pas le DI brut comme état opérateur distinct ; elle publie uniquement
  le résultat validé du séquenceur.
- Le snapshot montre aussi un repli `AX_STAB` depuis `AX7_SEARCH_BOTTOM`; son défaut doit être
  diagnostiqué séparément avant de valider une plongée complète.
- **Cause du repli confirmée** : Méca E M1 et M2 déclenchée à `2,50195313 m`, juste au-dessus
  du seuil `_WinchCriticalSyncTolerance_M = 2,5 m`. Le défaut synchro cycle (`ErrorID 02`) est
  la conséquence. La simulation exerce donc bien une protection, conformément au besoin, mais
  elle interdit dans cette configuration la validation Kobold jusqu'à `-15 m`.

## 6. 🛠️ Proposition de correction — à valider humainement

- **Option 1, sans code** : pendant l'essai, lire dans le snapshot `B_Inputs...KoboldBottomTouch_DI`
  pour le DI brut, et `G_CycleSemiAuto.Idx303_KoboldBottomTouch` pour le fond confirmé.
- **Option 2, évolution IHM** : ajouter un témoin lecture seule explicitement nommé
  `KoboldImmersed_DI` / « Kobold immergé (DI brut) », sans remplacer `KoboldContactFond`.
- **Essai Kobold à dissocier** : partir de M1/M2 effectivement synchronisés, puis choisir soit un
  facteur de dérive compatible avec `2,5 m` jusqu'au fond, soit le bypass Méca E explicitement
  autorisé pour un essai de séquence (jamais pour valider la protection).

## 7. 📝 Journal

- 2026-09-15 : snapshot 528/528 fourni par l'utilisateur ; analyse statique du flux PRG_02 → PRG_03 → PRG_07.
- 2026-09-15 : défaut rapporté par l'utilisateur : cycle `02` synchro, M1/M2 Méca E `13` ; seuil
  et écart validés par snapshot.
- 2026-09-15 : après intégration du seuil 7,0 m, l'utilisateur observe encore 2,5 m ; hypothèse
  prioritaire : valeur RETAIN `_WinchCriticalSyncTolerance_M` conservée en ligne à 2,5 m malgré
  la copie du source GVL. Une initialisation de déclaration ne réécrit pas automatiquement une
  valeur persistante déjà mémorisée.
- 2026-09-15 : le DI brut ne peut être TRUE que si `MachineInputSourceSimulated=TRUE`, le
  contacteur Kobold est effectivement arbitré (`KoboldMeasureEnable=TRUE`) et le front montant
  d'alimentation a été capturé. Sinon `FB_SimBench` retombe sur `SimKoboldContactValue` (FALSE).
- 2026-09-15 : le défaut Méca E est latché ; un déclenchement effectué à 2,5 m reste actif après
  modification du seuil et exige un front `FaultMachineReset_IHM` lorsque l'écart est revenu sous
  le seuil. La valeur en ligne de l'entrée FB doit néanmoins être vérifiée avant reset.
