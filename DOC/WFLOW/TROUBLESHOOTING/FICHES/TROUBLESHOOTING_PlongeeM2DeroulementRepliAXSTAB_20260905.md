# 🕵️ Session de Troubleshooting — Plongée semi-auto · M2 déroule trop / repli silencieux AX_STAB

> 📅 Date : 2026-09-05 · 🧊 Situation : [SITE] · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé

Trace `Suivi_Cycleplongee_20260905_35.trace` (36 648 ms, 366 échantillons, ~100 ms). Mode SEMI_AUTO.
`Fault.Error=0` sur toute la trace (socle `instFault` **commenté** dans l'arbre de travail → repli « silencieux »).

| Élément | Variable (trace) | Valeur |
|---|---|---|
| Étape descente | `instCycleSemiAuto.CycleStep` | `4` = `AX4_DESCEND_DIVING` (t 48→13 872) |
| Saut | idem | `4 → 19` = `AX_STAB` à t≈13 872 |
| Repli figé | idem | `19` = `AX_STAB` (t 13 872 → 36 648) |
| Joystick | `AxisY.Deflection` | `-100` maintenu ; retombe à 0 à t=17 065 |
| M1 position | `EncoderM1.CablePosM` | 8 → **4,272** (saut) → 2,555 (butée) |
| M2 position | `EncoderM2.CablePosM` | 7,82 → **4,78** (saut) |
| Écart au saut | — | \|Δ\| = **0,508 m** |
| Busy | `Lifecycle.Busy` | 1 → 0 (dès AX_STAB) |
| Défaut | `Fault.Error` | **0** (silencieux) |
| Kobold (DI/Enable) | `M1_M2_KoboldBottomTouch_DI` / `_DQ` | 0 / 0 |

## 2. 🎯 Symptôme

En semi-auto, à la transition ouverture-benne → plongée, en maintenant le joystick défléchi,
**M2 diverge de M1** pendant la descente couplée ; le cycle tombe en `AX_STAB` sans défaut visible
(« silencieux »), et il faut relâcher/utiliser le manche pour reprendre.

## 3. 🧩 Indices / historique

- Descente en `AX4` couplée, joystick maintenu −100 %, homme-mort armé.
- Au repli : `M1=4,272`, `M2=4,78` → |Δ| ≈ 0,51 m.
- Traces associées : `Suivi_PlongeeError_36`, `Suivi_BugCycle_34` (50 var. treuils/sync) — non exploitées ici.
- Changements récents : repli AX_STAB ; `instFault`/gate Abort-Reset désactivés (essai) ;
  `FB_Safety_Winch` : seuils vitesse 0,02→0,10, `OppositeDirectionTimeout` 500 ms→1 s, signe vitesse confirmé (MES 2026-09-05).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Attendu (source) | Lu | Verdict |
|---|---|---|---|---|---|
| 1 | Anti-télescopage (écart M1/M2 > `CST_CoupledPosBacklashM`) en AX4 | `instCauses[6].Active`, `WinchSyncDeltaM` | TRUE si \|Δ\|>0,5 m (code FB_CycleSemiAuto §4, cause 6) | \|M2−M1\|=0,508 m | ✅ fortement probable |
| 2 | Désynchronisme treuils (`WinchSyncError`) | `instCauses[1].Active`, `M1M2Sync.State.Error` | - | traces 34/36 (non lues) | ⏳ à vérifier |
| 3 | Palier vitesse ≠ 4 en plongée | `instCauses[8/9].Active`, `M1/M2_SpeedStepApplied` | - | non tracé | ⏳ à vérifier |
| 4 | Repli AX_STAB déclenché par `ErrorEdge` (build avec `instFault` actif au moment de la trace) | diff build PLC | - | `Fault.Error=0` | ❓ build en cause |

## 5. 📊 Arbre vertical

```text
Joystick −100 % (maintenu) en AX4_DESCEND_DIVING
  → M1 descend 8 → 4,272 ; M2 7,82 → 4,78
  → |ΔM1−M2| = 0,508 m > 0,5 m   ✅ seuil anti-télescopage franchi
    → instCauses[6] → repli AX_STAB (19)
      → Busy=0, commandes coupées, Fault silencieux (instFault désactivé)
```

**Résumé une ligne** : `[AX4] → [|M2−M1|=0,508>0,5] → [AX_STAB] → [Fault=0]`.

## 7. 🏁 Conclusion

- **Cause racine (hypothèse principale, à confirmer)** : divergence de position M1/M2 > 0,5 m en
  descente couplée `AX4` → backstop anti-télescopage → `AX_STAB`.
- Repli « silencieux » car `instFault` est désactivé dans l'arbre de travail.
- **Statut : à valider** (cause exacte à confirmer par acquisition des causes / état du build PLC).

## 8. 🛠️ Proposition de correction
(*à compléter après confirmation de la cause racine — non modifié sans validation humaine*)

## 10. 📝 Journal

- 2026-09-05 : lecture trace 35 → identification du repli AX_STAB à 0,51 m d'écart M1/M2 en AX4.
