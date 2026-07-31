# FB_WinchSymmetry — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-10_Fonction_Winch_v2.0.md`](../AF_Partie-10_Fonction_Winch_v2.0.md) §6.3bis.  
> Rôle de **ce** document : observateur passif de symétrie et de synchronisme M1/M2 (MES-008).  
> Source code : `CODE/DIAG/FB_WinchSymmetry.st` · instance unique dans `PRG_11_Troubleshooting`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Traitement et métriques mesurées
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P10-035` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P10-035 | Calcul passif des deltas (démarrage, freins, arrêt, glissement) sans affecter la sécurité ni le mouvement | `💻 AUTO` |

---

## 1. Rôle et profil

Brique de **diagnostic passif** (Partie3 §2) : aucun effet direct sur les sorties de commande ni la chaîne de sécurité.

`FB_WinchSymmetry` compare en continu le comportement des deux treuils principaux (**M1 Retenue** et **M2 Benne**) lorsqu'ils reçoivent des ordres de marche simultanés et dans le même sens.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Reset` | BOOL | Remise à zéro des deltas mesurés |
| `M1CommandActive/M2CommandActive` | BOOL | Ordres de marche treuils |
| `M1Direction/M2Direction` | INT | Sens des commandes (doivent être identiques) |
| `M1BrakeCmd/M2BrakeCmd` | BOOL | Commandes de frein |
| `M1BrakeApplied/M2BrakeApplied` | BOOL | Retours d'état physiques freins |
| `M1Position_M/M2Position_M` | REAL | Positions mesurées codeurs (m) |
| `M1Speed_Mps/M2Speed_Mps` | REAL | Vitesses mesurées codeurs (m/s) |
| `SyncDeviation_M` | REAL | Écart instantané de synchronisme (m) |
| `Config` | ST_WinchSymmetryCfg | Seuils de tolérance et durées de qualification |

**Structure de données / InOut** : `Data : ST_WinchSymmetryData` (résultats mesurés).  
**Sorties** : `SymmetryOk` (BOOL, TRUE si tous deltas < seuils), `SymmetryValid` (BOOL, TRUE si mesure qualifiée).

---

## 3. Traitement et métriques mesurées

Le bloc mesure et enregistre les écarts temporels et cinématiques suivants :
1. **`DeltaStartDelay_Ms`** : Écart de réactivité au démarrage entre M1 et M2.
2. **`DeltaBrakeReleaseTime_Ms`** : Écart de durée de desserrage effectif des freins physiques.
3. **`DeltaBrakeApplyTime_Ms`** : Écart de durée de retombée/serrage des freins lors de l'arrêt.
4. **`DeltaStopTime_Ms`** : Écart de temps pour atteindre la vitesse nulle après relâchement.
5. **`DeltaStopDistance_Mm`** : Écart de glissement ou de distance parcourue pendant l'arrêt.
6. **`MaxSyncDeviation_M`** : Dérive maximale de synchronisme enregistrée pendant la course.

---

## 4. Alertes et écarts

- **Observateur pur** : `hide_all_locals` — aucune écriture vers `GVL_OUT`, `FB_Safety_Winch` ou `FB_Winch`.

---

## 5. Documents liés

- [`AF_Partie-10_Fonction_Winch_v2.0.md`](../AF_Partie-10_Fonction_Winch_v2.0.md)

