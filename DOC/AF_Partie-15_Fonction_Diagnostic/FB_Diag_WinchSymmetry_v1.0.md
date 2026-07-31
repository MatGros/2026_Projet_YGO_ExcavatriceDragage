# Fiche FB_Diag_WinchSymmetry v1.0

> Mesure passive de symétrie M1/M2 (MES-008).
> Profil AF03 : brique métier non-mouvement, observateur pur.
> Source : `CODE/DIAG/FB_Diag_WinchSymmetry.st` · instance : `PRG_11_Troubleshooting.instWinchSymmetry`.

## 🎯 Rôle

Mesure les écarts de comportement entre les treuils M1 et M2 lors d'un mouvement synchrone :
délai de démarrage, temps de desserrage/serrage de frein, distance et temps d'arrêt.
Aucune écriture de commande, sécurité ou mouvement. Observateur pur.

## 📥 Entrées

| Port | Type | Producteur |
|---|---|---|
| `Reset` | BOOL | `GVL_IHM.Commun.WinchSymmetry.BtnReset` |
| `M1/M2CommandActive` | BOOL | `PRG_06_WinchControl` |
| `M1/M2Direction` | INT | `PRG_06_WinchControl` |
| `M1/M2BrakeCmd` / `M1/M2BrakeApplied` | BOOL | `PRG_06` / `PRG_INPUTS_LD` |
| `M1/M2Position_M` / `M1/M2Speed_Mps` | REAL | `FB_Encoder_Scale` / `FB_Encoder_SpeedMeasure` |
| `SyncDeviation_M` | REAL | `FB_WinchSync` |
| `Config` | ST_Diag_Winch_SymmetryCfg | `_WinchSymmetryCfgPersist` (RETAIN) |

## 📥 VAR_IN_OUT

| Port | Type | Rôle |
|---|---|---|
| `Data` | ST_Diag_Winch_SymmetryData | Mesures persistées (RETAIN via GVL_PERSISTENT) |

## 📤 Sorties

| Port | Type | Consommateur |
|---|---|---|
| `SymmetryOk` | BOOL | IHM (`GVL_IHM.Commun.WinchSymmetry.SymmetryOk`) |
| `SymmetryValid` | BOOL | IHM |

## 🔒 Impact machine

- **Aucun**. Mesure passive : informe l'opérateur, ne coupe rien.

## 📊 Mesures (ST_Diag_Winch_SymmetryData)

| Champ | Unité | Rôle |
|---|---|---|
| `DeltaStartDelay_Ms` | ms | Écart de délai de démarrage M1↔M2 |
| `DeltaBrakeReleaseTime_Ms` | ms | Écart temps desserrage frein |
| `DeltaBrakeApplyTime_Ms` | ms | Écart temps serrage frein |
| `DeltaStopDistance_Mm` | mm | Écart distance d'arrêt |
| `DeltaStopTime_Ms` | ms | Écart temps d'arrêt |
| `MaxSyncDeviation_M` | m | Déviation sync max pendant le mouvement |

## 📄 Docs liées

- `AF_Partie-15` §4 (flux) · `AF_Partie-14` (Troubleshooting) · `AF_Partie-10` (Winch)