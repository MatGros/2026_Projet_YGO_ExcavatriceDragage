# MISSION AGENT 4 — ASSOUPLISSEMENT `AX1_INIT` (F3) & CONTRÔLE CODE `MAINT_N2` INCONDITIONNEL (`T395`)

## Partie 1 : `AX1_INIT` (`PRG_03_Modes_Cycle.st:174-182` & `FB_CycleSemiAuto.st:915-960`)
Actuellement :
```iecst
CycleWinchesAtTopOk :=
    (PRG_04_Treuils_Benne.Data.WinchM1Safety.CableLimitAscent
     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.CableLimitAscent
     OR (ABS(PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM - _CommunCfgPersist.CfgCableLimitAscent_M) <= CST_CycleInitWindowM))
    AND (PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed OR PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen);
CycleInitPositionOk := NOT PRG_05_Translation.Data.M3_AtMaintenanceStable AND CycleWinchesAtTopOk;
```
Et dans `FB_CycleSemiAuto.st:952` :
`OperatorAction := 'AX1 - Posture depart incorrecte (M3, FDC haut M1 ou benne).';`
**Objectif Partie 1 :**
1. Remplacer ce message opaque par 3 messages distincts (< 70 caractères chacun pour le gate `G408`) indiquant exactement quelle condition bloque (`M3 en Maintenance`, `M1/M2 hors zone haute`, `Benne non qualifiée ouverte/fermée`).
2. Ajouter un bit IHM `TglRelaxSemiAutoStart : BOOL := FALSE` qui, lorsqu'il est à `TRUE`, assouplit le départ `AX1_INIT` (fenêtre haute élargie et/ou dispense de qualification stricte `IsOpen/IsClosed` si les treuils sont en zone haute).

## Partie 2 : Contrôle Code `MAINT_N2` — Commande Inconditionnelle Contacteurs & Treuils Ensemble ou Séparément
Exigence exploitant : *"Il faut qu'en MAINT_N2 on puisse commander les contacteurs et les treuils ensemble (`WinchSel=0`) ou séparément (`WinchSel=1` ou `2`) de façon inconditionnelle."*
Or voici 3 verrous trouvés dans le code actuel :
1. `FB_Modes.st:364-396` :
   ```iecst
   IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
       IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
           Auth.JoystickWinchSelectArbitrated := 2;
           BucketSeqSatisfied := FALSE;
       ELSIF CoupledBucketSeqEnable AND (JoystickWinchSelectRequest = 0) AND (JoystickPull XOR JoystickPush) THEN
           ...
           Auth.JoystickWinchSelectArbitrated := 2;
   ```
   -> En `MAINT_N2`, `M3AtTremie` et `CoupledBucketSeqEnable` écrasent `JoystickWinchSelectRequest` et forcent `2` (M2 seul) !
2. `PRG_03_Modes_Cycle.st:511-516` :
   `WinchDescentAuth_M3` bloque la descente M1 (et M1+M2 couplés) si M3 n'est pas à P1/Maintenance, même en `MAINT_N2` !
3. `PRG_04_Treuils_Benne.st:771-799` :
   `ProcessPermitM1_Descend` / `ProcessPermitM2_Descend` peuvent être bloqués par `KoboldBottomTouchLatched` ou `ManualBucketLimitsActive` même en `MAINT_N2` !
**Objectif Partie 2 :**
Vérifier ces 3 points (et tout autre verrou dans `PRG_04` / `PRG_06`) et donner les patchs ST exacts pour qu'en `MAINT_N2`, les treuils (ensemble `0` ou séparément `1`/`2`) et leurs contacteurs soient commandables sans blocage process.
