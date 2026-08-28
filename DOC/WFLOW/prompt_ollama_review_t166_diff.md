# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# AUDIT INDÉPENDANT DU DIFF RÉEL — LOT T166 (MIGRATION DIVE & EXTRACTION DANS PRG_03)

## 1. Objectif de la mission
Tu dois mener une revue critique et rigoureuse du `git diff` réel sur le lot T166 :
- Migration de `FB_DiveSearch` et `FB_ExtractionSequence` depuis `PRG_04_Treuils_Benne` vers `PRG_03_Modes_Cycle`.
- Calcul de l'intention opérateur couplée `CoupledUserRequest` dans `PRG_03`.
- Gestion des gardes-clears fond et du write-back de `TglBucketAtBottomConfirmed` dans `PRG_03`.
- Consommation des demandes benne/Kobold dans `PRG_04` via `PRG_03.Data.ReqProgram.ReqBucket`.
- Remappage des accès résiduels dans `PRG_07_Supervision` vers `PRG_04.Data`.

## 2. Code ST dans PRG_03_Modes_Cycle.st (Section 1, 2, 4)
```pascal
// §1 MODES & INTENTION
instModes(...);
IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    CoupledUserRequestDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
    CoupledUserRequestActive := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw
                                     AND (instModes.Auth.JoystickWinchSelectArbitrated = 0);
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        CoupledUserRequestDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        CoupledUserRequestDirection := -1;
    ELSE
        CoupledUserRequestDirection := 0;
    END_IF;
    CoupledUserRequestActive := (CoupledUserRequestDirection <> 0);
END_IF;

// §2 ASSISTANTS DRAGAGE
IF NOT (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)) THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
    BypassKoboldBottomTouched := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

BypassKoboldFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
IF GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
   AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)
   AND BypassKoboldFallEdge.Q THEN
    BypassKoboldBottomTouched := TRUE;
END_IF;
GVL_IHM.DredgingAssist.State.BypassDiveActive          := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
GVL_IHM.DredgingAssist.State.BypassKoboldBottomTouched := BypassKoboldBottomTouched;

instDiveSearch(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := instModes.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BucketIsOpen := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    KoboldImmersed := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M,
    BypassPreconditions := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
);

BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed OR BypassKoboldBottomTouched;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed := BottomPositionConfirmed;
...

instExtractionSequence(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := instModes.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    BucketBusy := PRG_04_Treuils_Benne.Data.BucketBusy,
    BucketError := PRG_04_Treuils_Benne.Data.BucketError,
    WinchSyncError := PRG_04_Treuils_Benne.Data.WinchSyncError,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    M1MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M1.SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M2.SpeedValid,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);

IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

// §4 PUBLICATION
ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2) THEN
    ...
    Data.ReqProgram.ReqBucket.ReqClose := instExtractionSequence.BucketCloseRequest;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable := instDiveSearch.KoboldMeasureEnable
                                                        OR (GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
                                                            AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1));
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := NOT (instDiveSearch.Enable AND CoupledUserRequestActive
                                                            AND (CoupledUserRequestDirection = -1)
                                                            AND NOT PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen);
    Data.ReqProgram.ReqBucket.ForceMinSpeedStep := instExtractionSequence.ForceMinSpeedStep;
    ...
    Data.SequenceState.DiveState := instDiveSearch.DiveState;
    Data.SequenceState.BottomTouchConfirmed := BottomPositionConfirmed;
    Data.SequenceState.ExtractionState := instExtractionSequence.ExtractionState;
```

## 3. Code dans PRG_04_Treuils_Benne.st
```pascal
BottomPositionConfirmed := PRG_03_Modes_Cycle.Data.SequenceState.BottomTouchConfirmed;

// Arbitrage de fermeture benne
IF PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose THEN
    CmdBucketCloseArbitrated := TRUE;
ELSIF CoupledAscentBucketCloseArmed THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
END_IF;

// Arbitrage contacteur Kobold
KoboldContactorCmdArbitrated := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable;

// Autorisation directe et explicite
DescendPermitDiveBucketOpen := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen;
```

## 4. Questions d'évaluation
1. **L'inversion de dépendance est-elle totalement évitée ?** (Vérifie la séquence PRG_02 -> PRG_03 -> PRG_04).
2. **Le calcul de `CoupledUserRequest` dans PRG_03 est-il exempt de décalage de scan ?**
3. **Le bus `ST_SequencePublicState` est-il maintenant 100% cohérent et productif ?**
4. **Y a-t-il la moindre régression sur la sécurité physique ou le comportement des treuils ?**
5. **Donne ton verdict formel : PASS / CONDITIONAL / FAIL.**
