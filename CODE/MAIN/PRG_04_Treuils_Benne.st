(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_04_Treuils_Benne — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4 (après PRG_03_Modes_Cycle).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF_Partie-10_Fonction_Winch_v2.0.md ; DOC/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Treuils_Benne

VAR_OUTPUT
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    KoboldContactorCmdArbitrated : BOOL;
END_VAR

VAR
    StubMachineEnableN1 : BOOL := TRUE;

    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;
    instDiveSearch : FB_DiveSearch;
    instExtractionSequence : FB_ExtractionSequence;

    MaintenanceMotionRequestActive : BOOL;
    MaintenanceMotionDirection     : INT;
    MaintenanceMotionSpeed_Pct     : REAL;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;

    M1_StartStop_Active     : BOOL;
    M1_Direction_Active     : INT;
    M1_SpeedRef_Active      : REAL;

    M2_StartStop_Active     : BOOL;
    M2_Direction_Active     : INT;
    M2_SpeedRef_Active      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    SpeedGuardEnableM1 : BOOL := FALSE;
    SpeedGuardEnableM2 : BOOL := FALSE;

    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;

    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    ForbidDescentM1_Raw     : BOOL;
    ForbidDescentM2_Raw     : BOOL;
    ForbidAscentM1_Raw      : BOOL;
    ForbidAscentM2_Raw      : BOOL;
    ForbidAscentM1_Active   : BOOL;
    ForbidAscentM2_Active   : BOOL;

    BenneBusyFallEdge     : F_TRIG;

    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M2_LimitShift                : REAL;

    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescente  : INT;
END_VAR

// === 🪨 §1 INTENTION MAINTENANCE & ASSISTANTS ===

IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    MaintenanceMotionDirection := PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2;
    MaintenanceMotionRequestActive := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw
                                     AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 3);
    MaintenanceMotionSpeed_Pct := 100.0;
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        MaintenanceMotionDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        MaintenanceMotionDirection := -1;
    ELSE
        MaintenanceMotionDirection := 0;
    END_IF;
    MaintenanceMotionRequestActive := (MaintenanceMotionDirection <> 0);
    MaintenanceMotionSpeed_Pct := 100.0;
END_IF;

IF NOT (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (MaintenanceMotionRequestActive AND (MaintenanceMotionDirection = -1))
   OR _BucketState.IsOpen THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

instDiveSearch(
    Enable := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BucketIsOpen := _BucketState.IsOpen,
    KoboldImmersed := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldContactFond_DI,
    M1Position_M := PRG_02_Acquisition.HwReal.Winch.COD1_PosValue,
    M2Position_M := PRG_02_Acquisition.HwReal.Winch.COD2_PosValue,
    PositionsValid := TRUE,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M
);

BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed;
instExtractionSequence(
    Enable := (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := PRG_03_Modes_Cycle.Auth.Mode,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection := MaintenanceMotionDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := _BucketState.IsClosed,
    BucketBusy := instBucket.Busy,
    BucketError := instBucket.Error,
    WinchSyncError := instWinchSync.Error,
    M1Position_M := PRG_02_Acquisition.HwReal.Winch.COD1_PosValue,
    M2Position_M := PRG_02_Acquisition.HwReal.Winch.COD2_PosValue,
    M1MeasuredSpeedValid := TRUE,
    M2MeasuredSpeedValid := TRUE,
    PositionsValid := TRUE,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);
IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    CmdBucketCloseArbitrated := FALSE;
ELSIF instExtractionSequence.BucketCloseRequest THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
END_IF;

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    KoboldContactorCmdArbitrated := FALSE;
ELSE
    KoboldContactorCmdArbitrated := instDiveSearch.KoboldMeasureEnable;
END_IF;


// === 🏗️ §2 COMMANDE DU BENNE (FB_Bucket) ===

instBucket(
    Enable              := NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Auth.Mode,
    CmdOpen_IHM         := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen,
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    MotionRequestActive := MaintenanceMotionRequestActive,
    MotionDirection     := MaintenanceMotionDirection,
    CablePosM1          := PRG_02_Acquisition.HwReal.Winch.COD1_PosValue,
    CablePosM2          := PRG_02_Acquisition.HwReal.Winch.COD2_PosValue,
    HomedM1             := TRUE,
    HomedM2             := TRUE,
    M1_Busy             := instWinchM1.Busy,
    M2_Busy             := instWinchM2.Busy,
    ConfirmOpenPosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
    ConfirmClosePosition:= GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
    Config              := _BucketCfgPersist.Config,
    CfgTimeoutDuration     := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_03_Modes_Cycle.Auth.InhibitM1,
    InhibitM2           := PRG_03_Modes_Cycle.Auth.InhibitM2,
    BypassGlobal        := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global
);

SyncMinorDeviation := (instWinchSync.ErrorId AND 16#0001) <> 16#0000;
SyncMinorDeviationBlocksUp   := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0);
SyncMinorDeviationBlocksDown := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0);

EffectiveMaxStepAscent   := _CommunCfgPersist.WinchMaxStepAscent;
EffectiveMaxStepDescente := _CommunCfgPersist.WinchMaxStepDescente;


// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    M1_Direction_Active := 0;
    M1_StartStop_Active := FALSE;
    M1_SpeedRef_Active  := 0.0;
ELSE
    IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        M1_Direction_Active := 0;
        M1_StartStop_Active := FALSE;
        M1_SpeedRef_Active  := 0.0;
    ELSE
        IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M1TreuilRetenue.Cmd.BtnUp THEN
            M1_Direction_Active := 1;
        ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M1TreuilRetenue.Cmd.BtnDown THEN
            M1_Direction_Active := -1;
        ELSE
            M1_Direction_Active := 0;
        END_IF;
        M1_StartStop_Active := (M1_Direction_Active <> 0) AND NOT instBucket.Busy
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)));
        M1_SpeedRef_Active  := 100.0;
    END_IF;
END_IF;

IF instBucket.Busy THEN
    M2_StartStop_Active := instBucket.M2_StartStop;
    M2_Direction_Active := instBucket.M2_Direction;
    M2_SpeedRef_Active  := 15.0;
ELSE
    IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
        M2_Direction_Active := 0;
        M2_StartStop_Active := FALSE;
        M2_SpeedRef_Active  := 0.0;
    ELSE
        IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
            M2_Direction_Active := 0;
            M2_StartStop_Active := FALSE;
            M2_SpeedRef_Active := 0.0;
        ELSE
            IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M2TreuilBenne.Cmd.BtnUp THEN
                M2_Direction_Active := 1;
            ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M2TreuilBenne.Cmd.BtnDown THEN
                M2_Direction_Active := -1;
            ELSE
                M2_Direction_Active := 0;
            END_IF;
            M2_StartStop_Active := (M2_Direction_Active <> 0)
                                    AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                         OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)));
            M2_SpeedRef_Active := 100.0;
        END_IF;
    END_IF;
END_IF;

BenneBusyFallEdge(CLK := instBucket.Busy);
IF BenneBusyFallEdge.Q THEN
    M1_StartStop_Active := FALSE;
    M2_StartStop_Active := FALSE;
END_IF;


// === 🔄 §4 SYNCHRONISATION M1 / M2 ===

instWinchSync(
    Enable          := PRG_03_Modes_Cycle.Auth.SyncEnable AND NOT instBucket.Busy
                        AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1 AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset           := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode            := PRG_03_Modes_Cycle.Auth.Mode,
    CablePosM1      := PRG_02_Acquisition.HwReal.Winch.COD1_PosValue,
    CablePosM2      := PRG_02_Acquisition.HwReal.Winch.COD2_PosValue,
    HomedM1         := TRUE,
    HomedM2         := TRUE,
    SyncEnable      := PRG_03_Modes_Cycle.Auth.SyncEnable,
    CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
    ActiveOffsetM   := instBucket.ActiveOffsetM,
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4,
    BypassGlobal    := GVL_IHM.M1M2Sync.Bypass.Global
);

IF instBucket.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P1R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P1R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P1R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P2R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P2R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P2R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P2R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P3R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P3R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P3R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P3R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P4R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P4R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P4R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P4R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P5R1 := _WinchSpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P5R2 := _WinchSpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P5R3 := _WinchSpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P5R4 := _WinchSpeedStepTable.P1R4;
    M2_SpeedStepTableActive.StepThreshold_Pct := _WinchSpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := _WinchSpeedStepTable;
END_IF;


// === 🛑 §5 COUPLAGE CROISÉ & SÉCURITÉS ===

BottomLimitM1_Active := _WinchM1CfgPersist.CfgCableLimitDescent_M;
BottomLimitM2_Active := _WinchM2CfgPersist.CfgCableLimitDescent_M;

SafeStopM1_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000) OR instBucket.M1SlipDetected;
SafeStopM2_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000);

ForbidDescentM1_Raw := GVL_IHM.M1TreuilRetenue.Bypass.Global;
ForbidDescentM2_Raw := GVL_IHM.M2TreuilBenne.Bypass.Global;

M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketCfgPersist.Config.OffsetCloseM);

SafeStopM1_Active      := SafeStopM1_Raw      OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active      := SafeStopM2_Raw      OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
ForbidDescentM1_Active := ForbidDescentM1_Raw OR (instWinchSync.SyncActive AND ForbidDescentM2_Raw);
ForbidDescentM2_Active := ForbidDescentM2_Raw OR (instWinchSync.SyncActive AND ForbidDescentM1_Raw);
ForbidAscentM1_Active  := ForbidAscentM1_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM2_Raw);
ForbidAscentM2_Active  := ForbidAscentM2_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM1_Raw);


// === ⚙️ §6 EXÉCUTION FB_Winch (M1 & M2) ===

instWinchM1(
    Enable                  := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M1_StartStop_Active,
    SafeStop                := SafeStopM1_Active,
    ForbidDescent           := ForbidDescentM1_Active,
    ForbidAscent            := ForbidAscentM1_Active,
    Direction               := M1_Direction_Active,
    SpeedRefPct             := M1_SpeedRef_Active,
    SpeedStepTable          := _WinchSpeedStepTable,
    CfgMaxStepDescente      := EffectiveMaxStepDescente,
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := NOT instWinchSync.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback           := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    CfgRampAccelRate        := _WinchM1CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate  := _WinchM1CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate    := _WinchM1CfgPersist.CfgRampDecelFastRate,
    Homed                   := TRUE,
    HomingSuspect           := FALSE,
    CablePosM               := PRG_02_Acquisition.HwReal.Winch.COD1_PosValue,
    TopLimitM               := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowSpeedPct         := _CommunCfgPersist.WinchSlowSpeed_Pct,
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

instWinchM2(
    Enable                  := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M2_StartStop_Active,
    SafeStop                := SafeStopM2_Active,
    ForbidDescent           := ForbidDescentM2_Active,
    ForbidAscent            := ForbidAscentM2_Active,
    Direction               := M2_Direction_Active,
    SpeedRefPct             := M2_SpeedRef_Active,
    SpeedStepTable          := M2_SpeedStepTableActive,
    CfgMaxStepDescente      := EffectiveMaxStepDescente,
    MaxStepAscent           := SEL(instExtractionSequence.ForceMinSpeedStep, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := NOT instWinchSync.Error,
    HomingApproachActive    := PRG_03_Modes_Cycle.Auth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback           := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global,
    CfgRampAccelRate        := _WinchM2CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate  := _WinchM2CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate    := _WinchM2CfgPersist.CfgRampDecelFastRate,
    Homed                   := TRUE,
    HomingSuspect           := FALSE,
    CablePosM               := PRG_02_Acquisition.HwReal.Winch.COD2_PosValue,
    TopLimitM               := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM    := _CommunCfgPersist.WinchSlowdownDistance_M,
    CfgSlowSpeedPct         := _CommunCfgPersist.WinchSlowSpeed_Pct,
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
);


// === 📤 §7 PUBLICATION DEMANDES BRUTES (WinchM1/M2FinalInterlockRequest) ===

WinchM1FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM1FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
WinchM1FinalInterlockRequest.BrakeReleaseRequest := instWinchM1.BrakeCmd;
WinchM1FinalInterlockRequest.BrakeCommandOpenConfirmed := instWinchM1.BrakeCommandOpenConfirmed;
WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI;
WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd;
WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev;
WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;

WinchM2FinalInterlockRequest.Enable := StubMachineEnableN1;
WinchM2FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM2FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM2FinalInterlockRequest.SafeStop := SafeStopM2_Active;
WinchM2FinalInterlockRequest.BrakeReleaseRequest := instWinchM2.BrakeCmd;
WinchM2FinalInterlockRequest.BrakeCommandOpenConfirmed := instWinchM2.BrakeCommandOpenConfirmed;
WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI;
WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;
WinchM2FinalInterlockRequest.RequestedRelayRev := instWinchM2.RelayRev;
WinchM2FinalInterlockRequest.RequestedContactor1 := instWinchM2.Contactor1;
WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;

END_PROGRAM
