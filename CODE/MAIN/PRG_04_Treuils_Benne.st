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
    WinchM1StateHMI : ST_WinchState;
    WinchM2StateHMI : ST_WinchState;
    WinchM1SafetyHMI : ST_SafetyWinch;
    WinchM2SafetyHMI : ST_SafetyWinch;
    SyncStateHMI : ST_SyncState;
    BucketStateHMI : ST_BucketHMIState;
END_VAR

VAR
    StubMachineEnableN1 : BOOL := TRUE;

    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instSafetyWinchM1 : FB_Safety_Winch;   // 🆕 2026-08-05 : audit sécurité M3 — M1/M2 avaient 0 mécanisme actif
    instSafetyWinchM2 : FB_Safety_Winch;
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
                                     AND (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0);
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
    M1Position_M := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue),
    M2Position_M := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD2_PosValue),
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
    M1Position_M := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue),
    M2Position_M := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD2_PosValue),
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
    CablePosM1          := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue),
    CablePosM2          := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD2_PosValue),
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

IF _CommunCfgPersist.WinchMaxStepAscent <= 0 THEN
    EffectiveMaxStepAscent := 5;
ELSE
    EffectiveMaxStepAscent := _CommunCfgPersist.WinchMaxStepAscent;
END_IF;

IF _CommunCfgPersist.WinchMaxStepDescente <= 0 THEN
    EffectiveMaxStepDescente := 3;
ELSE
    EffectiveMaxStepDescente := _CommunCfgPersist.WinchMaxStepDescente;
END_IF;


// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    M1_Direction_Active := 0;
    M1_StartStop_Active := FALSE;
    M1_SpeedRef_Active  := 0.0;
ELSE
    IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        // Mode Boutons IHM
        IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M1TreuilRetenue.Cmd.BtnUp THEN
            M1_Direction_Active := 1;
            M1_SpeedRef_Active  := 100.0;
        ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M1TreuilRetenue.Cmd.BtnDown THEN
            M1_Direction_Active := -1;
            M1_SpeedRef_Active  := 100.0;
        ELSE
            M1_Direction_Active := 0;
            M1_SpeedRef_Active  := 0.0;
        END_IF;
    ELSE
        // Mode Joystick Maître
        IF (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 1) THEN
            M1_Direction_Active := PRG_02_Acquisition.instJoystick.AxisCmdY.Direction;
            M1_SpeedRef_Active  := ABS(PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedRef);
        ELSE
            M1_Direction_Active := 0;
            M1_SpeedRef_Active  := 0.0;
        END_IF;
    END_IF;

    M1_StartStop_Active := (M1_Direction_Active <> 0) AND NOT instBucket.Busy
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1_Direction_Active = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1_Direction_Active = -1)))
                            AND PRG_02_Acquisition.JoystickDeadmanArmed;   // 🆕 2026-08-05 : audit sécurité M3
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
        IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
            // Mode Boutons IHM
            IF GVL_IHM.Commun.BtnWinchBothUp OR GVL_IHM.M2TreuilBenne.Cmd.BtnUp THEN
                M2_Direction_Active := 1;
                M2_SpeedRef_Active  := 100.0;
            ELSIF GVL_IHM.Commun.BtnWinchBothDown OR GVL_IHM.M2TreuilBenne.Cmd.BtnDown THEN
                M2_Direction_Active := -1;
                M2_SpeedRef_Active  := 100.0;
            ELSE
                M2_Direction_Active := 0;
                M2_SpeedRef_Active  := 0.0;
            END_IF;
        ELSE
            // Mode Joystick Maître
            IF (PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 0 OR PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated = 2) THEN
                M2_Direction_Active := PRG_02_Acquisition.instJoystick.AxisCmdY.Direction;
                M2_SpeedRef_Active  := ABS(PRG_02_Acquisition.instJoystick.AxisCmdY.SpeedRef);
            ELSE
                M2_Direction_Active := 0;
                M2_SpeedRef_Active  := 0.0;
            END_IF;
        END_IF;

        M2_StartStop_Active := (M2_Direction_Active <> 0)
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2_Direction_Active = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2_Direction_Active = 1)))
                                AND PRG_02_Acquisition.JoystickDeadmanArmed;   // 🆕 2026-08-05 : audit sécurité M3
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
    CablePosM1      := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue),
    CablePosM2      := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD2_PosValue),
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

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/contacteurs/fin de course des DEUX treuils (VH_0800END,
// Local_Digital_IO) — pas de granularité par treuil possible, donc SafeStop des DEUX.
SafeStopM1_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000) OR instBucket.M1SlipDetected OR PRG_02_Acquisition.InputModuleFault;
SafeStopM2_Raw      := ((instWinchSync.ErrorId AND 16#0002) <> 16#0000) OR PRG_02_Acquisition.InputModuleFault;

ForbidDescentM1_Raw := FALSE;
ForbidDescentM2_Raw := FALSE;

M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq, 0.0, _BucketCfgPersist.Config.OffsetCloseM);

// 🆕 2026-08-05 (audit sécurité M3) : FB_Safety_Winch M1/M2 — 0 mécanisme actif avant ce lot.
// Instancié avant instWinchM1/M2 : MovementCommanded lit RelayFwd/RelayRev du scan précédent
// (même lag 1 scan accepté que M4/Translation, jamais sur Reset/SafeStop/PowerCutOff/sortie finale).
instSafetyWinchM1(
    Enable                 := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM1,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Auth.SyncEnable,
    JoystickOnline         := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational    := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.instEncoderAbsM1.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.instHomingM1.Busy,
    CablePosM              := PRG_02_Acquisition.CablePosM1,
    CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    Direction              := M1_Direction_Active,
    MovementCommanded      := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    Homed                  := PRG_02_Acquisition.instHomingM1.Homed,
    HomingSuspect          := PRG_02_Acquisition.instHomingM1.HomingSuspect,
    TopLimitM              := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.JoystickYNeutral,
    BenneHoldStillActive   := instBucket.Busy,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.CablePosM2 - instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Auth.InhibitM2,
    MeasuredSpeedMps       := PRG_02_Acquisition.M1_Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.M1_SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.M1_SpeedValid,
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := GVL_IHM.M1TreuilRetenue.Bypass.Process,
    BypassTopLimitSwitch   := GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch,
    BypassCableLimitSwitch := GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch,
    BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal,
    BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M1TreuilRetenue.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.MecaE
);

instSafetyWinchM2(
    Enable                 := StubMachineEnableN1 AND (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Auth.InhibitM2,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Auth.SyncEnable,
    JoystickOnline         := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational    := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.instEncoderAbsM2.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.instHomingM2.Busy,
    CablePosM              := PRG_02_Acquisition.CablePosM2,
    CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    Direction              := M2_Direction_Active,
    MovementCommanded      := instWinchM2.RelayFwd OR instWinchM2.RelayRev,
    Homed                  := PRG_02_Acquisition.instHomingM2.Homed,
    HomingSuspect          := PRG_02_Acquisition.instHomingM2.HomingSuspect,
    TopLimitM              := _WinchM2CfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    JoystickYNeutral       := PRG_02_Acquisition.JoystickYNeutral,
    BenneHoldStillActive   := FALSE,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.CablePosM1 + instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Auth.InhibitM1,
    MeasuredSpeedMps       := PRG_02_Acquisition.M2_Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.M2_SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.M2_SpeedValid,
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassSafety           := GVL_IHM.M2TreuilBenne.Bypass.Safety,
    BypassProcess          := GVL_IHM.M2TreuilBenne.Bypass.Process,
    BypassTopLimitSwitch   := GVL_IHM.M2TreuilBenne.Bypass.TopLimitSwitch,
    BypassCableLimitSwitch := GVL_IHM.M2TreuilBenne.Bypass.CableLimitSwitch,
    BypassOperatorComm     := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M2TreuilBenne.Bypass.BrakeThermal,
    BypassMecaA            := GVL_IHM.M2TreuilBenne.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M2TreuilBenne.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M2TreuilBenne.Bypass.MecaC,
    BypassMecaD            := GVL_IHM.M2TreuilBenne.Bypass.MecaD,
    BypassMecaE            := GVL_IHM.M2TreuilBenne.Bypass.MecaE
);

SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;
SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;
ForbidDescentM1_Raw := ForbidDescentM1_Raw OR instSafetyWinchM1.ForbidDescent;
ForbidDescentM2_Raw := ForbidDescentM2_Raw OR instSafetyWinchM2.ForbidDescent;
ForbidAscentM1_Raw  := instSafetyWinchM1.ForbidAscent;
ForbidAscentM2_Raw  := instSafetyWinchM2.ForbidAscent;

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
    BypassContactorCheck    := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback,
    CfgRampAccelRate        := _WinchM1CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate  := _WinchM1CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate    := _WinchM1CfgPersist.CfgRampDecelFastRate,
    Homed                   := TRUE,
    HomingSuspect           := FALSE,
    CablePosM               := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue),
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
    BypassContactorCheck    := GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback,
    CfgRampAccelRate        := _WinchM2CfgPersist.CfgRampAccelRate,
    CfgRampDecelNormalRate  := _WinchM2CfgPersist.CfgRampDecelNormalRate,
    CfgRampDecelFastRate    := _WinchM2CfgPersist.CfgRampDecelFastRate,
    Homed                   := TRUE,
    HomingSuspect           := FALSE,
    CablePosM               := UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD2_PosValue),
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
WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;

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
WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;

// === 📤 §8 PUBLICATION ÉTATS IHM (faits publics, lecture seule) ===
WinchM1StateHMI.Position_M := PRG_02_Acquisition.CablePosM1;
WinchM1StateHMI.SpeedRef_Pct := M1_SpeedRef_Active;
WinchM1StateHMI.StepNumber := instWinchM1.StepNumber;
WinchM1StateHMI.FBState := instWinchM1.State;
WinchM1StateHMI.Ready := instWinchM1.Ready;
WinchM1StateHMI.Busy := instWinchM1.Busy;
WinchM1StateHMI.Done := instWinchM1.Done;
WinchM1StateHMI.Error := instWinchM1.Error;
WinchM1StateHMI.ErrorId := instWinchM1.ErrorId;
WinchM1StateHMI.RelayFwd := instWinchM1.RelayFwd;
WinchM1StateHMI.RelayRev := instWinchM1.RelayRev;
WinchM1StateHMI.Contactor1 := instWinchM1.Contactor1;
WinchM1StateHMI.Contactor2 := instWinchM1.Contactor2;
WinchM1StateHMI.Contactor3 := instWinchM1.Contactor3;
WinchM1StateHMI.Contactor4 := instWinchM1.Contactor4;
WinchM1StateHMI.BrakeCmd := instWinchM1.BrakeCmd;
WinchM1StateHMI.BrakeCommandOpenConfirmed := instWinchM1.BrakeCommandOpenConfirmed;
WinchM1StateHMI.FinalAuthorizedStep := instWinchM1.RequestedStep;
WinchM1StateHMI.ContactorsCheck := instWinchM1.ContactorsCheck;
WinchM1StateHMI.FinalInterlockState := PRG_06_Outputs_LD.instWinchOutputInterlockM1.State;
WinchM1StateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instWinchOutputInterlockM1.Reason;
WinchM1StateHMI.FinalInterlockError := PRG_06_Outputs_LD.instWinchOutputInterlockM1.Error;
WinchM1StateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instWinchOutputInterlockM1.ErrorId;
WinchM1StateHMI.FinalRestartInhibit := PRG_06_Outputs_LD.instWinchOutputInterlockM1.RestartInhibit;
WinchM1StateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.BrakeTimeoutElapsed;
WinchM1StateHMI.FinalRestartDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.RestartDelayElapsed;
WinchM1StateHMI.FinalStepDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM1.StepDelayElapsed;
WinchM1StateHMI.Encoder.RawPos := PRG_02_Acquisition.instEncoderAbsM1.RawPos;
WinchM1StateHMI.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD1_Alarms;
WinchM1StateHMI.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD1_Warnings;
WinchM1StateHMI.Encoder.SlaveOperational := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM1.Operational;
WinchM1StateHMI.Encoder.PresetTriggerCmd := PRG_02_Acquisition.instEncoderAbsM1.PresetTriggerCmd;
WinchM1StateHMI.Encoder.PresetValueOut := PRG_02_Acquisition.instEncoderAbsM1.PresetValueOut;
WinchM1StateHMI.Encoder.Error := PRG_02_Acquisition.instEncoderAbsM1.Error;
WinchM1StateHMI.Encoder.ErrorId := PRG_02_Acquisition.instEncoderAbsM1.ErrorId;
WinchM1StateHMI.Encoder.Homed := PRG_02_Acquisition.instHomingM1.Homed;
WinchM1StateHMI.Encoder.HomingBusy := PRG_02_Acquisition.instHomingM1.Busy;
WinchM1StateHMI.Encoder.HomingDone := PRG_02_Acquisition.instHomingM1.Done;
WinchM1StateHMI.Encoder.HomingError := PRG_02_Acquisition.instHomingM1.Error;
WinchM1StateHMI.Encoder.HomingErrorId := PRG_02_Acquisition.instHomingM1.ErrorId;
WinchM1StateHMI.Encoder.HomingState := PRG_02_Acquisition.instHomingM1.State;
WinchM1StateHMI.Encoder.HomingStateAtError := PRG_02_Acquisition.instHomingM1.StateAtError;
WinchM1StateHMI.Encoder.HomingSuspect := PRG_02_Acquisition.instHomingM1.HomingSuspect;
WinchM1StateHMI.Encoder.HomingRefRaw := PRG_02_Acquisition.instHomingM1.HomingRefRaw;
WinchM1StateHMI.InhibitActive := PRG_03_Modes_Cycle.Auth.InhibitM1;

WinchM2StateHMI.Position_M := PRG_02_Acquisition.CablePosM2;
WinchM2StateHMI.SpeedRef_Pct := M2_SpeedRef_Active;
WinchM2StateHMI.StepNumber := instWinchM2.StepNumber;
WinchM2StateHMI.FBState := instWinchM2.State;
WinchM2StateHMI.Ready := instWinchM2.Ready;
WinchM2StateHMI.Busy := instWinchM2.Busy;
WinchM2StateHMI.Done := instWinchM2.Done;
WinchM2StateHMI.Error := instWinchM2.Error;
WinchM2StateHMI.ErrorId := instWinchM2.ErrorId;
WinchM2StateHMI.RelayFwd := instWinchM2.RelayFwd;
WinchM2StateHMI.RelayRev := instWinchM2.RelayRev;
WinchM2StateHMI.Contactor1 := instWinchM2.Contactor1;
WinchM2StateHMI.Contactor2 := instWinchM2.Contactor2;
WinchM2StateHMI.Contactor3 := instWinchM2.Contactor3;
WinchM2StateHMI.Contactor4 := instWinchM2.Contactor4;
WinchM2StateHMI.BrakeCmd := instWinchM2.BrakeCmd;
WinchM2StateHMI.BrakeCommandOpenConfirmed := instWinchM2.BrakeCommandOpenConfirmed;
WinchM2StateHMI.FinalAuthorizedStep := instWinchM2.RequestedStep;
WinchM2StateHMI.ContactorsCheck := instWinchM2.ContactorsCheck;
WinchM2StateHMI.BrakeContactorCheck := instWinchM2.BrakeContactorCheck;
WinchM2StateHMI.FinalInterlockState := PRG_06_Outputs_LD.instWinchOutputInterlockM2.State;
WinchM2StateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instWinchOutputInterlockM2.Reason;
WinchM2StateHMI.FinalInterlockError := PRG_06_Outputs_LD.instWinchOutputInterlockM2.Error;
WinchM2StateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instWinchOutputInterlockM2.ErrorId;
WinchM2StateHMI.FinalRestartInhibit := PRG_06_Outputs_LD.instWinchOutputInterlockM2.RestartInhibit;
WinchM2StateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.BrakeTimeoutElapsed;
WinchM2StateHMI.FinalRestartDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.RestartDelayElapsed;
WinchM2StateHMI.FinalStepDelayElapsed := PRG_06_Outputs_LD.instWinchOutputInterlockM2.StepDelayElapsed;
WinchM2StateHMI.Encoder.RawPos := PRG_02_Acquisition.instEncoderAbsM2.RawPos;
WinchM2StateHMI.Encoder.Alarms := PRG_02_Acquisition.HwReal.Winch.COD2_Alarms;
WinchM2StateHMI.Encoder.Warnings := PRG_02_Acquisition.HwReal.Winch.COD2_Warnings;
WinchM2StateHMI.Encoder.SlaveOperational := PRG_07_Supervision.instDiagEthercat.DeviceEncoderM2.Operational;
WinchM2StateHMI.Encoder.PresetTriggerCmd := PRG_02_Acquisition.instEncoderAbsM2.PresetTriggerCmd;
WinchM2StateHMI.Encoder.PresetValueOut := PRG_02_Acquisition.instEncoderAbsM2.PresetValueOut;
WinchM2StateHMI.Encoder.Error := PRG_02_Acquisition.instEncoderAbsM2.Error;
WinchM2StateHMI.Encoder.ErrorId := PRG_02_Acquisition.instEncoderAbsM2.ErrorId;
WinchM2StateHMI.Encoder.Homed := PRG_02_Acquisition.instHomingM2.Homed;
WinchM2StateHMI.Encoder.HomingBusy := PRG_02_Acquisition.instHomingM2.Busy;
WinchM2StateHMI.Encoder.HomingDone := PRG_02_Acquisition.instHomingM2.Done;
WinchM2StateHMI.Encoder.HomingError := PRG_02_Acquisition.instHomingM2.Error;
WinchM2StateHMI.Encoder.HomingErrorId := PRG_02_Acquisition.instHomingM2.ErrorId;
WinchM2StateHMI.Encoder.HomingState := PRG_02_Acquisition.instHomingM2.State;
WinchM2StateHMI.Encoder.HomingStateAtError := PRG_02_Acquisition.instHomingM2.StateAtError;
WinchM2StateHMI.Encoder.HomingSuspect := PRG_02_Acquisition.instHomingM2.HomingSuspect;
WinchM2StateHMI.Encoder.HomingRefRaw := PRG_02_Acquisition.instHomingM2.HomingRefRaw;
WinchM2StateHMI.InhibitActive := PRG_03_Modes_Cycle.Auth.InhibitM2;

WinchM1SafetyHMI.SafeStop := SafeStopM1_Active;
WinchM1SafetyHMI.ForbidAscent := ForbidAscentM1_Active;
WinchM1SafetyHMI.ForbidDescent := ForbidDescentM1_Active;
WinchM1SafetyHMI.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI;
WinchM1SafetyHMI.Error := instWinchM1.Error;
WinchM1SafetyHMI.ErrorId := instWinchM1.ErrorId;
WinchM2SafetyHMI.SafeStop := SafeStopM2_Active;
WinchM2SafetyHMI.ForbidAscent := ForbidAscentM2_Active;
WinchM2SafetyHMI.ForbidDescent := ForbidDescentM2_Active;
WinchM2SafetyHMI.SlackCable := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI;
WinchM2SafetyHMI.ThermalFault := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI;
WinchM2SafetyHMI.Error := instWinchM2.Error;
WinchM2SafetyHMI.ErrorId := instWinchM2.ErrorId;

SyncStateHMI.DeltaPos_M := instWinchSync.SignedDeltaPosM;
SyncStateHMI.SyncActive := instWinchSync.SyncActive;
SyncStateHMI.SyncWarn := instWinchSync.SyncWarn;
SyncStateHMI.Ready := instWinchSync.Ready;
SyncStateHMI.Error := instWinchSync.Error;
SyncStateHMI.ErrorId := instWinchSync.ErrorId;
SyncStateHMI.FBState := instWinchSync.State;

BucketStateHMI.MechState := _BucketState;
BucketStateHMI.FBState := instBucket.State;
BucketStateHMI.ActiveOffset_M := instBucket.ActiveOffsetM;
BucketStateHMI.M2StartStop := instBucket.M2_StartStop;
BucketStateHMI.M2Direction := instBucket.M2_Direction;
BucketStateHMI.M2ForceSlowSpeed := instBucket.M2_ForceSlowSpeed;
BucketStateHMI.M2PositionCorrected := PRG_02_Acquisition.CablePosM2 - instBucket.ActiveOffsetM;
BucketStateHMI.Ready := instBucket.Ready;
BucketStateHMI.Busy := instBucket.Busy;
BucketStateHMI.Done := instBucket.Done;
BucketStateHMI.Error := instBucket.Error;
BucketStateHMI.ErrorId := instBucket.ErrorId;
BucketStateHMI.RemainingTravel_M := instBucket.RemainingTravelM;
BucketStateHMI.CloseActive := instBucket.CloseReq;
BucketStateHMI.OpenActive := instBucket.OpenReq;

END_PROGRAM
