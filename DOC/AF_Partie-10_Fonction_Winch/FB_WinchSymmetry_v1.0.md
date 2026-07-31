# Fiche Composant : FB_WinchSymmetry (v1.0)

> **Rôle** : Observateur passif de symétrie et de synchronisme M1/M2 (MES-008).  
> **Catégorie** : Brique de diagnostic passive (aucun effet direct sur les sorties de commande ni la chaîne de sécurité).  
> **Code Source** : `CODE/DIAG/FB_WinchSymmetry.st`  
> **Consommateur** : `PRG_11_Troubleshooting`  

---

## 📐 1. Description Fonctionnelle

`FB_WinchSymmetry` compare en continu le comportement des deux treuils principaux (**M1 Retenue** et **M2 Benne**) lorsqu'ils reçoivent des ordres de marche simultanés et dans le même sens.

Il mesure et enregistre les écarts temporels et cinématiques suivants pour qualifier le comportement dynamique de la machine :
1. **`DeltaStartDelay_Ms`** : Écart de réactivité au démarrage (temps écoulé entre la commande de marche et l'atteinte d'un seuil de vitesse minimale).
2. **`DeltaBrakeReleaseTime_Ms`** : Écart de durée de desserrage effectif des freins physiques.
3. **`DeltaBrakeApplyTime_Ms`** : Écart de durée de retombée/serrage des freins lors de l'arrêt.
4. **`DeltaStopTime_Ms`** : Écart de temps pour atteindre la vitesse nulle après relâchement de la commande.
5. **`DeltaStopDistance_Mm`** : Écart de glissement ou de distance parcourue pendant la phase d'arrêt.
6. **`MaxSyncDeviation_M`** : Dérive maximale de synchronisme enregistrée pendant la course.

---

## 🔌 2. Contrat d'Interface ST

```pascal
FUNCTION_BLOCK PUBLIC FB_WinchSymmetry
VAR_INPUT
    Reset : BOOL;                             // Remise à zéro des deltas mesurés
    M1CommandActive : BOOL;                   // Commande marche active M1
    M2CommandActive : BOOL;                   // Commande marche active M2
    M1Direction : INT;                        // Sens de commande M1 (-1, 0, 1)
    M2Direction : INT;                        // Sens de commande M2 (-1, 0, 1)
    M1BrakeCmd, M2BrakeCmd : BOOL;            // Ordres de commande frein
    M1BrakeApplied, M2BrakeApplied : BOOL;    // Retours d'état physiques freins
    M1Position_M, M2Position_M : REAL;        // Positions mesurées codeurs (m)
    M1Speed_Mps, M2Speed_Mps : REAL;          // Vitesses mesurées codeurs (m/s)
    SyncDeviation_M : REAL;                   // Écart instantané de synchronisme (m)
    Config : ST_WinchSymmetryCfg;             // Configuration seuils et temps de qualification
END_VAR
VAR_IN_OUT
    Data : ST_WinchSymmetryData;              // Structure de données de mesure (RETAIN/IHM)
END_VAR
VAR_OUTPUT
    SymmetryOk : BOOL;                        // TRUE si tous les deltas < seuils Config
    SymmetryValid : BOOL;                     // TRUE dès qu'une mesure comparative complète a été validée
END_VAR
```

---

## 🧱 3. Structures de Données (`DUT`)

### A. `ST_WinchSymmetryCfg` (Configuration)
- `MinimumCommandTime_Ms : UDINT` : Durée minimale de maintien de commande active pour qualifier la mesure.
- `MinimumSpeed_Mps : REAL` : Seuil de vitesse à partir duquel le mouvement est considéré comme actif.
- `DeltaStartDelay_Ms : UDINT` : Tolérance maximale de retard au démarrage.
- `DeltaBrakeReleaseTime_Ms : UDINT` : Tolérance maximale d'écart d'ouverture frein.
- `DeltaBrakeApplyTime_Ms : UDINT` : Tolérance maximale d'écart de fermeture frein.
- `DeltaStopDistance_Mm : UDINT` : Tolérance maximale de différence de distance à l'arrêt.
- `DeltaStopTime_Ms : UDINT` : Tolérance maximale d'écart de temps d'arrêt.

### B. `ST_WinchSymmetryData` (Mesures publiées IHM)
- `DeltaStartDelay_Ms : UDINT`
- `DeltaBrakeReleaseTime_Ms : UDINT`
- `DeltaBrakeApplyTime_Ms : UDINT`
- `DeltaStopDistance_Mm : UDINT`
- `DeltaStopTime_Ms : UDINT`
- `MaxSyncDeviation_M : REAL`

---

## 🛡️ 4. Règles & Sécurité

- **Non bloquant** : Ce composant est un observateur pur (`hide_all_locals`). Une invalidité (`SymmetryOk = FALSE`) génère une information pour la maintenance dans `PRG_11_Troubleshooting` mais ne déclenche pas d'arrêt d'urgence de la machine.
