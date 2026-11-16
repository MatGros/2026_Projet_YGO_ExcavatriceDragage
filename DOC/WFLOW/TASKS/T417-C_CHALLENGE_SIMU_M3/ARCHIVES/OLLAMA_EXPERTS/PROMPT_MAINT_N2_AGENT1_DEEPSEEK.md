# AUDIT EXHAUSTIF SÉCURITÉ & DÉPANNAGE `MAINT_N2` — COMMANDE INCONDITIONNELLE DES CONTACTEURS ET TREUILS M1/M2 (ENSEMBLE OU SÉPARÉMENT)

## Exigence Formelle de l'Exploitant
> "Il faut absolument qu'en maintenance N2 (`E_Mode.MAINT_N2`) on puisse piloter directement les contacteurs sans condition et qu'on puisse les bouger / travailler séparément (`WinchSel=1` M1 seul, `WinchSel=2` M2 seul, ou boutons IHM M1/M2) ou en même temps (`WinchSel=0` ou boutons Both), et dans n'importe quel défaut ou quoi, il faut que ça marche (sous réserve de la chaîne AU physique fermée `PowerContactorEngaged_DI` et de l'homme-mort en joystick)."

## Code Réel Actuel (Extraits Verbatim de la Chaîne Complète)

### Étape A — `CODE/F_MODES/FB_Modes.st` (lignes 364-400)
```iecst
IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
    IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
        Auth.JoystickWinchSelectArbitrated := 2;
        BucketSeqSatisfied := FALSE;
    ELSIF CoupledBucketSeqEnable
       AND (JoystickWinchSelectRequest = 0)
       AND (JoystickPull XOR JoystickPush) THEN
        Auth.CoupledBucketPhaseLocked := TRUE;
        IF (JoystickPull AND BucketIsClosed) OR (JoystickPush AND BucketIsOpen) THEN
            BucketSeqSatisfied := TRUE;
        END_IF;
        IF BucketSeqSatisfied THEN
            Auth.JoystickWinchSelectArbitrated := 0;
        ELSE
            Auth.JoystickWinchSelectArbitrated := 2;
        END_IF;
    ELSE
        Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
    END_IF;
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;
    BucketSeqSatisfied := FALSE;
END_IF;
```

### Étape B — `CODE/M_MAIN/PRG_03_Modes_Cycle.st` (lignes 511-516)
```iecst
    Data.SequenceState.WinchDescentAuth_M3     :=
        NOT GVL_IHM.Commun.Cfg.TglEnableWinchDescentLock_M3
        OR GVL_IHM.M3Translation.State.AtP1
        OR GVL_IHM.M3Translation.State.AtMaintenance
        OR GVL_IHM.M3Translation.Bypass.LimitSwitch
        OR GVL_IHM.M3Translation.Bypass.Global;
```

### Étape C — `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` & `M2.st`
```iecst
        RequestConflict := ReqAscent AND ReqDescend;
        BothDirectionAuthorized := (NOT BothIntent.Active)
            OR ((ReqAscent AND NOT ReqDescend) AND Context.M1AscentAllowed AND Context.M2AscentAllowed)
            OR ((ReqDescend AND NOT ReqAscent) AND Context.M1DescendAllowed AND Context.M2DescendAllowed);
        RunRequest := (ReqAscent OR ReqDescend) AND NOT RequestConflict
                  AND NOT Context.BucketBusy
                  AND NOT Context.WinchBothMotionBlockedByBucket
                  AND NOT ((Context.SyncBlocksAscent   AND ReqAscent)
                        OR (Context.SyncBlocksDescent AND ReqDescend))
                  AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed)
                  AND (NOT TglJoystickMaster OR (Joystick.AxisX.Direction = 0))
                  AND BothDirectionAuthorized;
```

### Étape D — `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (Permis, Safety, Arbitrage, Exécution)
```iecst
// Lignes 771-799 :
ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
ProcessPermitM2_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched)
    AND (DescendPermitDiveBucketOpen OR ManualBucketJogActive)
    AND NOT (ManualBucketLimitsActive AND ...)
    AND NOT (T248BucketJogActive AND ...);
ProcessPermitM1_Ascent := NOT ExtractionAssistActive OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit;
ProcessPermitM2_Ascent := (NOT ExtractionAssistActive OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit)
    AND NOT (ManualBucketLimitsActive AND ...)
    AND NOT (T248BucketJogActive AND ...);

// Lignes 941 & 972-991 (instSafetyWinchM1 / M2) :
    EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := (GVL_IHM.M1TreuilRetenue.Bypass.Process OR GVL_IHM.Commun.Bypass.SlackCable),
    BypassTopLimitSwitch   := BypassM1TopLimitSwitchEff,
    BypassTopLimitSoftware := BypassM1TopLimitSoftwareEff,
    BypassCableLimitSwitch := BypassM1CableLimitSwitchEff,
    BypassLimitLegal       := BypassM1LimitLegalEff,
    BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal,
    BypassMotorThermal     := GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal,
    BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.MecaC,
    BypassMecaD            := BypassM1MecaDEff,
    BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.MecaE,

// Lignes 1083-1090 :
IF NOT PRG_03_Modes_Cycle.Data.SequenceState.WinchDescentAuth_M3 THEN
    ProcessAndSafetyPermitM1_Descend := FALSE;
    IF NOT (ManualBucketJogActive
            OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen
            OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose) THEN
        ProcessAndSafetyPermitM2_Descend := FALSE;
    END_IF;
END_IF;

// Lignes 1103-1114 :
CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive;
SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw);
SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw);
EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM2_Descend);
EffectivePermitM2_Descend := ProcessAndSafetyPermitM2_Descend AND NOT SafeStopM2_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM1_Descend);
EffectivePermitM1_Ascent  := ProcessAndSafetyPermitM1_Ascent  AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM2_Ascent);
EffectivePermitM2_Ascent  := ProcessAndSafetyPermitM2_Ascent  AND NOT SafeStopM2_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM1_Ascent);
```

### Étape E — `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` (lignes 516-585)
- `CausesSafeStopActive` inclut : `CauseOperatorCommActive`, `CauseEncoderActive`, `CauseMotorThermalActive`, `CausePhaseRotationActive`, `CauseMecaAActive..E`, `CauseBrakeThermalActive`, `CauseOppositeDirActive`, `CauseNoMovementActive`.
- `CausesPowerCutOffActive` inclut : `CauseMotorThermalActive`, `CauseMecaAActive`, `CauseMecaBActive`, `CauseMecaCActive`, `CauseBrakeThermalActive`, `CauseMecaDActive`, `CauseMecaEEscaladeActive`.
- `AscentPermit` vérifie `TopPositionSensor` (`NOT BypassTopLimitSwitch`) et `TopLimitM` (`NOT (BypassGlobal OR BypassTopLimitSoftware)`).
- `DescendPermit` vérifie `CauseCableLimitActive` (`NOT (BypassGlobal OR BypassCableLimitSwitch)`), `LimitLegalReached` (`NOT BypassLimitLegal`), `CauseSlackCableActive` (`NOT (BypassProcess OR BypassGlobal)`).

### Étape F — `CODE/M_MAIN/PRG_06_Outputs.st` (lignes 153-244, 345-366)
- `instWinchOutputInterlockM1` et `M2` : coupent si `NOT Enable` (`PowerCutOff`), `SafeStop`, `PermitFinalBlocked`, `Error` (timeout frein 500 ms), `RestartInhibit`, `ContactorStuckLatched`.
- `instSyncContactorFinal` : surveille la concordance des contacteurs M1/M2 quand `WinchOutputCoupled` est actif, sauf si `BypassGlobal` est vrai.

## Objectifs Évaluables de l'Audit
1. Lister exhaustivement **tous les verrous** (Étapes A à F) qui peuvent empêcher l'opérateur en `MAINT_N2` de commander les contacteurs et de bouger M1 seul (`WinchSel=1`), M2 seul (`WinchSel=2`), ou M1+M2 ensemble (`WinchSel=0`), y compris en présence d'un défaut (codeur HS, mou de câble, écart synchro, MecaA/B/C/E, chariot à la trémie, etc.).
2. Distinguer clairement :
   - Ce qui DOIT être levé automatiquement dès qu'on est en `MAINT_N2` (`MaintN2 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)`),
   - Ce qui reste la barrière ultime matérielle (AU physique `PowerContactorEngaged_DI`, Homme-mort en joystick, et Capteur mécanique haut `TopPositionSensor` / `MecaD` sauf bypass explicite si capteur cassé).
3. Écrire les patchs ST exacts par fichier (`FB_Modes.st`, `PRG_03_Modes_Cycle.st`, `PRG_04_Treuils_Benne.st`, `PRG_06_Outputs.st`) pour garantir ce fonctionnement en `MAINT_N2`.
