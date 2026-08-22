(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ PRG_TROUBLESHOOTING_CFC — Programme Espion de Recherche de Pannes (ORIENTÉ FONCTIONS & CONTEXTE)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté en toute fin de MainTask (Position 11).
   🔒 ZERO ÉCRITURE SUR LA MACHINE : 100% lecture seule.
   🎨 Alimente la GVL_Troubleshooting par CONTEXTE GLOBAL ET FONCTIONS MACHINE.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_TROUBLESHOOTING_CFC
VAR
    instPreflight : FB_Acquisition_Preflight;
    instWinchSymmetry : FB_Winch_Symmetry;
    TonMachineStill : TON;
    MachineIsStillRaw : BOOL;
    // 🛡️ Lot 3A — lecture seule, visibles Watch / générateur Ladder.
    M1BrakeCommandOpenConfirmedDiag : BOOL;
    M2BrakeCommandOpenConfirmedDiag : BOOL;
    M3BrakeCommandOpenConfirmedDiag : BOOL;
    M1FinalInterlockErrorDiag       : BOOL;
    M2FinalInterlockErrorDiag       : BOOL;
    M3FinalInterlockErrorDiag       : BOOL;
    M1FinalRestartInhibitDiag       : BOOL;
    M2FinalRestartInhibitDiag       : BOOL;
    M1FinalInterlockStateDiag       : E_WinchFinalInterlockState;
    M1FinalInterlockReasonDiag      : E_WinchFinalInterlockReason;
    M1FinalBrakeTimeoutElapsedDiag  : TIME;
    M1FinalRestartDelayElapsedDiag  : TIME;
    M1FinalStepDelayElapsedDiag     : TIME;
    M3FinalInterlockStateDiag       : E_State;
    M3FinalInterlockReasonDiag      : E_TranslationFinalInterlockReason;
    M3FinalBrakeTimeoutElapsedDiag  : TIME;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_TROUBLESHOOTING_CFC) ===

// 🛡️ ─── 0. DIAGNOSTIC BARRIÈRES FINALES (lecture seule) ─────────────────
M1BrakeCommandOpenConfirmedDiag := PRG_TREUILS_CFC.instWinchM1.BrakeCommandOpenConfirmed;
M2BrakeCommandOpenConfirmedDiag := PRG_TREUILS_CFC.instWinchM2.BrakeCommandOpenConfirmed;
M3BrakeCommandOpenConfirmedDiag := PRG_TRANSLATION_CFC.instTranslationM3.BrakeCommandOpenConfirmed;
M1FinalInterlockErrorDiag := GVL_Global.instWinchOutputInterlockM1_LD.Error;
M2FinalInterlockErrorDiag := GVL_Global.instWinchOutputInterlockM2_LD.Error;
M3FinalInterlockErrorDiag := GVL_Global.instTranslationOutputInterlock_LD.Error;
M1FinalRestartInhibitDiag := GVL_Global.instWinchOutputInterlockM1_LD.RestartInhibit;
M2FinalRestartInhibitDiag := GVL_Global.instWinchOutputInterlockM2_LD.RestartInhibit;
M1FinalInterlockStateDiag := GVL_Global.instWinchOutputInterlockM1_LD.State;
M1FinalInterlockReasonDiag := GVL_Global.instWinchOutputInterlockM1_LD.Reason;
M1FinalBrakeTimeoutElapsedDiag := GVL_Global.instWinchOutputInterlockM1_LD.BrakeTimeoutElapsed;
M1FinalRestartDelayElapsedDiag := GVL_Global.instWinchOutputInterlockM1_LD.RestartDelayElapsed;
M1FinalStepDelayElapsedDiag := GVL_Global.instWinchOutputInterlockM1_LD.StepDelayElapsed;
M3FinalInterlockStateDiag := GVL_Global.instTranslationOutputInterlock_LD.State;
M3FinalInterlockReasonDiag := GVL_Global.instTranslationOutputInterlock_LD.Reason;
M3FinalBrakeTimeoutElapsedDiag := GVL_Global.instTranslationOutputInterlock_LD.BrakeTimeoutElapsed;

// 🌐 ─── 1. CONTEXTE MACHINE GLOBAL ───────────────────────────────────────────
MachineIsStillRaw := NOT (GVL_Global.M1RelayFwd OR GVL_Global.M1RelayRev OR GVL_Global.M1SpeedContactor1 OR GVL_Global.M1SpeedContactor2 OR GVL_Global.M1SpeedContactor3 OR GVL_Global.M1SpeedContactor4)
                 AND NOT (GVL_Global.M2RelayFwd OR GVL_Global.M2RelayRev OR GVL_Global.M2SpeedContactor1 OR GVL_Global.M2SpeedContactor2 OR GVL_Global.M2SpeedContactor3 OR GVL_Global.M2SpeedContactor4)
                 AND (M3_CommandWord = 0) AND NOT GVL_Global.M1BrakeCmd AND NOT GVL_Global.M2BrakeCmd AND NOT GVL_Global.TranslationBrakeCmd;
TonMachineStill(IN := MachineIsStillRaw, PT := T#2s);
instPreflight(Execute := GVL_IHM.Commun.Preflight.BtnRun, MachineIsStill := TonMachineStill.Q,
    M1BrakeApplied := NOT PRG_01_Inputs_LD.M1BrakeFeedback, M2BrakeApplied := NOT PRG_01_Inputs_LD.M2BrakeFeedback, M3BrakeApplied := NOT PRG_01_Inputs_LD.M3BrakeFeedback,
    M1ContactorsReleased := PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff, M2ContactorsReleased := PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff, M1ThermalOk := PRG_01_Inputs_LD.M1ThermalFeedback, M2ThermalOk := PRG_01_Inputs_LD.M2ThermalFeedback,
    BrakeThermalOk := PRG_01_Inputs_LD.BrakeThermalFeedback, PhaseRotationOk := PRG_01_Inputs_LD.PhaseRotationOk, SlackCableTensioned := PRG_01_Inputs_LD.SlackCableSwitch, M3SensorWordIncoherent := PRG_02_Acquisition_CFC.M3_SensorWordIncoherent,
    EmergencyChainClosed := PRG_01_Inputs_LD.EmergencyChainClosed, PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged, EncoderM1Operational := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1.Operational, EncoderM2Operational := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2.Operational,
    HomedM1 := PRG_02_Encoders.instHomingM1.Homed, HomedM2 := PRG_02_Encoders.instHomingM2.Homed,
    M1PositionInBounds := (PRG_02_Encoders.instEncoderScaleM1.CablePosM >= -99.0) AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= 99.0), M2PositionInBounds := (PRG_02_Encoders.instEncoderScaleM2.CablePosM >= -99.0) AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= 99.0));
instWinchSymmetry(Reset := GVL_IHM.Commun.WinchSymmetry.BtnReset,
    M1CommandActive := GVL_Global.M1RelayFwd OR GVL_Global.M1RelayRev, M2CommandActive := GVL_Global.M2RelayFwd OR GVL_Global.M2RelayRev,
    M1Direction := PRG_TREUILS_CFC.M1_Direction_Active, M2Direction := PRG_TREUILS_CFC.M2_Direction_Active,
    M1BrakeCmd := GVL_Global.M1BrakeCmd, M2BrakeCmd := GVL_Global.M2BrakeCmd, M1BrakeApplied := NOT PRG_01_Inputs_LD.M1BrakeFeedback, M2BrakeApplied := NOT PRG_01_Inputs_LD.M2BrakeFeedback,
    M1Position_M := PRG_02_Encoders.instEncoderScaleM1.CablePosM, M2Position_M := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    M1Speed_Mps := PRG_02_Encoders.M1MeasuredSpeed_Mps, M2Speed_Mps := PRG_02_Encoders.M2MeasuredSpeed_Mps, SyncDeviation_M := PRG_TREUILS_CFC.instWinchSync.DeltaPosM,
    Config := _WinchSymmetryCfgPersist, Data := _WinchSymmetryDataPersist);
GVL_Troubleshooting.ContexteMachineGlobal.Idx101_ModeActive             := PRG_MODES_CFC.Auth.Mode;
GVL_Troubleshooting.ContexteMachineGlobal.Idx102_SimulationEnabled      := GVL_Simulation.SimulationModeActive;
GVL_Troubleshooting.ContexteMachineGlobal.Idx103_JoystickCommOk         := PRG_01_Diagnostics.instJoystick.Ready;

GVL_Troubleshooting.ContexteMachineGlobal.Idx201_JoystickSelected       := (PRG_MODES_CFC.Auth.Mode <> E_Mode.MAINT_N1 AND PRG_MODES_CFC.Auth.Mode <> E_Mode.MAINT_N2);
GVL_Troubleshooting.ContexteMachineGlobal.Idx202_BypassNetworkGlobal    := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm OR GVL_IHM.M2TreuilBenne.Bypass.OperatorComm OR GVL_IHM.TranslationM3.Bypass.Global;
GVL_Troubleshooting.ContexteMachineGlobal.Idx203_BypassSensorsGlobal    := GVL_IHM.Commun.Bypass.TopPositionSensor OR GVL_IHM.Commun.Bypass.SlackCable OR GVL_IHM.TranslationM3.Bypass.LimitSwitch;

GVL_Troubleshooting.ContexteMachineGlobal.Idx301_EmergencyChainClosed   := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.ContexteMachineGlobal.Idx302_PowerContactorEngaged  := PRG_01_Inputs_LD.PowerContactorEngaged;
GVL_Troubleshooting.ContexteMachineGlobal.Idx303_SafeStopActiveAny       := PRG_SAFETY_CFC.instSafetyWinchM1.SafeStop OR PRG_SAFETY_CFC.instSafetyWinchM2.SafeStop OR PRG_SAFETY_CFC.instSafetyTranslationM3.SafeStop;
GVL_Troubleshooting.ContexteMachineGlobal.Idx304_PowerCutOffActiveAny   := PRG_SAFETY_CFC.instSafetyWinchM1.PowerCutOff OR PRG_SAFETY_CFC.instSafetyWinchM2.PowerCutOff OR PRG_SAFETY_CFC.instSafetyTranslationM3.PowerCutOff;

GVL_Troubleshooting.ContexteMachineGlobal.Idx401_HmiHeartbeatOk         := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk;
GVL_Troubleshooting.ContexteMachineGlobal.Idx402_CycleAutoBusy          := PRG_05_Cycle.instCycle.Busy;


// 🛗 ─── 1. LEVAGE SYNCHRONISÉ M1 + M2 (MODE COUPLÉ NOMINAL) ───────────────────
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx101_M1_CablePos_M         := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx102_M2_CablePos_M         := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx103_SyncDelta_M           := PRG_TREUILS_CFC.instWinchSync.DeltaPosM;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx201_JoyYRaw_Pct           := PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM       := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx203_ArbitratedSpeed_Pct   := PRG_TREUILS_CFC.M1_SpeedRef_Active;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx301_EmergencyChainClosed  := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx302_SyncFaultActive       := PRG_TREUILS_CFC.instWinchSync.Error;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx303_M1_ForbidAscent       := PRG_SAFETY_CFC.instSafetyWinchM1.ForbidAscent;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx304_M2_ForbidAscent       := PRG_SAFETY_CFC.instSafetyWinchM2.ForbidAscent;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx401_SyncMotionAllowed     := PRG_TREUILS_CFC.instWinchM1.Ready AND PRG_TREUILS_CFC.instWinchM2.Ready;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx402_M1_SetpointSpeed_Pct  := PRG_TREUILS_CFC.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx403_M2_SetpointSpeed_Pct  := PRG_TREUILS_CFC.M2_SpeedRef_Active;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx501_M1_CmdRelayFwd_DQ     := GVL_Global.M1RelayFwd;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx502_M2_CmdRelayFwd_DQ     := GVL_Global.M2RelayFwd;



// 🛗 ─── 2. LEVAGE UNITAIRE M1 (TREUIL RETENUE) ────────────────────────────────
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM1.RawPos);
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_01_Inputs_LD.M1FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx104_BrakeApplied           := NOT PRG_01_Inputs_LD.M1BrakeFeedback;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx105_ThermalOk_DI           := PRG_01_Inputs_LD.M1ThermalFeedback;

GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.instJoystick.RawY;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M1TreuilRetenue.Cmd.BtnUp;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M1TreuilRetenue.Cmd.BtnDown;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.WinchM1Cmd.SpeedPct;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx206_ModeActive           := PRG_MODES_CFC.Auth.Mode;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_TREUILS_CFC.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx209_ArbitratedDirection  := PRG_TREUILS_CFC.M1_Direction_Active;

GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx301_EmergencyChainClosed   := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx302_SafeStopActive         := PRG_SAFETY_CFC.instSafetyWinchM1.SafeStop;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx303_PowerCutOffActive      := PRG_SAFETY_CFC.instSafetyWinchM1.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_01_Inputs_LD.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx306_ForbidAscentEffective  := PRG_SAFETY_CFC.instSafetyWinchM1.ForbidAscent;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_01_Inputs_LD.SlackCableSwitch;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx309_ForbidDescentEffective := PRG_SAFETY_CFC.instSafetyWinchM1.ForbidDescent;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_SAFETY_CFC.instSafetyWinchM1.State);

GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx401_MotionAllowed        := PRG_TREUILS_CFC.instWinchM1.Ready;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx402_SpeedStepCalculated  := PRG_TREUILS_CFC.instWinchM1.StepNumber;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx403_SpeedRamp_Pct        := PRG_TREUILS_CFC.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx404_BrakeReleaseAuthorized:= GVL_Global.instWinchOutputInterlockM1_LD.BrakeCmd;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx405_FinalInterlockState := GVL_Global.instWinchOutputInterlockM1_LD.State;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx406_FinalInterlockReason := GVL_Global.instWinchOutputInterlockM1_LD.Reason;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx407_FinalAuthorizedStep := GVL_Global.instWinchOutputInterlockM1_LD.AuthorizedStep;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx408_BrakeCommandOpenConfirmed := PRG_TREUILS_CFC.instWinchM1.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx409_BrakeTimeoutElapsed := GVL_Global.instWinchOutputInterlockM1_LD.BrakeTimeoutElapsed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx410_RestartDelayElapsed := GVL_Global.instWinchOutputInterlockM1_LD.RestartDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx411_StepDelayElapsed := GVL_Global.instWinchOutputInterlockM1_LD.StepDelayElapsed;

GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := GVL_Global.M1RelayFwd;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := GVL_Global.M1RelayRev;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= GVL_Global.M1SpeedContactor1;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= GVL_Global.M1SpeedContactor4;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx505_CmdBrakeRelease_RQ   := GVL_Global.M1BrakeCmd;


// 🛗 ─── 3. LEVAGE UNITAIRE M2 (TREUIL BENNE) ──────────────────────────────────
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM2.RawPos);
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_01_Inputs_LD.M2FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx104_BrakeApplied           := NOT PRG_01_Inputs_LD.M2BrakeFeedback;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx105_ThermalOk_DI           := PRG_01_Inputs_LD.M2ThermalFeedback;

GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.instJoystick.RawY;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.instJoystick.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M2TreuilBenne.Cmd.BtnUp;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M2TreuilBenne.Cmd.BtnDown;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.WinchM2Cmd.SpeedPct;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx206_ModeActive           := PRG_MODES_CFC.Auth.Mode;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_TREUILS_CFC.M2_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx209_ArbitratedDirection  := PRG_TREUILS_CFC.M2_Direction_Active;

GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx301_EmergencyChainClosed   := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx302_SafeStopActive         := PRG_SAFETY_CFC.instSafetyWinchM2.SafeStop;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx303_PowerCutOffActive      := PRG_SAFETY_CFC.instSafetyWinchM2.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_01_Inputs_LD.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx306_ForbidAscentEffective  := PRG_SAFETY_CFC.instSafetyWinchM2.ForbidAscent;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_01_Inputs_LD.SlackCableSwitch;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx309_ForbidDescentEffective := PRG_SAFETY_CFC.instSafetyWinchM2.ForbidDescent;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_SAFETY_CFC.instSafetyWinchM2.State);

GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx401_MotionAllowed        := PRG_TREUILS_CFC.instWinchM2.Ready;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx402_SpeedStepCalculated  := PRG_TREUILS_CFC.instWinchM2.StepNumber;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx403_SpeedRamp_Pct        := PRG_TREUILS_CFC.M2_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx404_BrakeReleaseAuthorized:= GVL_Global.instWinchOutputInterlockM2_LD.BrakeCmd;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx405_FinalInterlockState := GVL_Global.instWinchOutputInterlockM2_LD.State;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx406_FinalInterlockReason := GVL_Global.instWinchOutputInterlockM2_LD.Reason;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx407_FinalAuthorizedStep := GVL_Global.instWinchOutputInterlockM2_LD.AuthorizedStep;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx408_BrakeCommandOpenConfirmed := PRG_TREUILS_CFC.instWinchM2.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx409_BrakeTimeoutElapsed := GVL_Global.instWinchOutputInterlockM2_LD.BrakeTimeoutElapsed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx410_RestartDelayElapsed := GVL_Global.instWinchOutputInterlockM2_LD.RestartDelayElapsed;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx411_StepDelayElapsed := GVL_Global.instWinchOutputInterlockM2_LD.StepDelayElapsed;

GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := GVL_Global.M2RelayFwd;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := GVL_Global.M2RelayRev;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= GVL_Global.M2SpeedContactor1;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= GVL_Global.M2SpeedContactor4;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx505_CmdBrakeRelease_RQ   := GVL_Global.M2BrakeCmd;


// 🪣 ─── 4. OUVERTURE / FERMETURE BENNE ─────────────────────────────────────────
GVL_Troubleshooting.BenneOuvertureFermeture.Idx101_BucketIsOpen               := GVL_IHM.M2TreuilBenne.Bucket.State.MechState.IsOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx102_BucketIsClosed             := GVL_IHM.M2TreuilBenne.Bucket.State.MechState.IsClosed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx103_OffsetPos_M                := PRG_TREUILS_CFC.instBucket.ActiveOffsetM;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx201_HmiCmd_BtnOpen             := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx202_HmiCmd_BtnClose            := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx203_CycleCmd_Open              := PRG_05_Cycle.instCycle.BucketCmd.Open;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx301_EmergencyChainClosed       := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx302_BucketFaultActive          := PRG_TREUILS_CFC.instBucket.Error;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx401_BucketBusy                 := PRG_TREUILS_CFC.instBucket.Busy;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx402_BucketDone                 := PRG_TREUILS_CFC.instBucket.Done;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx501_M2_CmdRev_DQ               := GVL_Global.M2RelayRev;


// ↔️ ─── 5. TRANSLATION PONT M3 (VARIATEUR AC600) ─────────────────────────────
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx101_PosTremie_DI         := PRG_02_Acquisition_CFC.TranslationPosTremie;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx102_PosPV_DI             := PRG_02_Acquisition_CFC.TranslationPosPV;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx103_PosP2_DI             := PRG_02_Acquisition_CFC.TranslationPosP2;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx104_PosP1_DI             := PRG_02_Acquisition_CFC.TranslationPosP1;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI    := PRG_02_Acquisition_CFC.TranslationPosMaintenance;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz   := UINT_TO_REAL(PRG_02_Acquisition_CFC.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx107_DriveStatusWord      := PRG_02_Acquisition_CFC.M3_StatusWord_Filtered;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx108_BrakeApplied         := NOT PRG_01_Inputs_LD.M3BrakeFeedback;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx109_DriveThermalOk       := PRG_02_Acquisition_CFC.HwIn.Translation.M3_ThermalFeedback_DI; // 🆕 T96

GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx201_JoyXRaw_ANA          := PRG_01_Diagnostics.instJoystick.RawX;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx202_JoyXScaled_Pct       := PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx203_HmiCmd_BtnFwd        := GVL_IHM.TranslationM3.Cmd.BtnFwd;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx204_HmiCmd_BtnRev        := GVL_IHM.TranslationM3.Cmd.BtnRev;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx205_HmiTargetPosition    := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx206_CycleTargetPosition  := GVL_IHM.Cycle.State.SelTarget;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx207_ModeActive           := PRG_MODES_CFC.Auth.Mode;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx208_BypassNetworkActive  := GVL_IHM.TranslationM3.Bypass.Global;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx209_ArbitratedSpeed_Pct := PRG_TRANSLATION_CFC.M3_SpeedRef_Active;

GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx301_EmergencyChainClosed  := PRG_01_Inputs_LD.EmergencyChainClosed;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx302_SafeStopActive        := PRG_SAFETY_CFC.instSafetyTranslationM3.SafeStop;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx303_PowerCutOffActive     := PRG_SAFETY_CFC.instSafetyTranslationM3.PowerCutOff;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx304_LimitSwitchFwdActive := PRG_SAFETY_CFC.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx306_BypassLimitSwitch    := GVL_IHM.TranslationM3.Bypass.LimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx307_PositionDecoderIncoherent := PRG_SAFETY_CFC.instSafetyTranslationM3.ErrorSensorIncoherent;

GVL_Troubleshooting.TranslationPontM3.Control_400.Idx401_MotionAllowed        := GVL_Global.instTranslationOutputInterlock_LD.Ready;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz      := GVL_Global.instTranslationOutputInterlock_LD.DriveFreqRefHz;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx403_DriveControlWord     := GVL_Global.instTranslationOutputInterlock_LD.DriveControlWord;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx404_FinalInterlockState := GVL_Global.instTranslationOutputInterlock_LD.State;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx405_FinalInterlockReason := GVL_Global.instTranslationOutputInterlock_LD.Reason;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx406_BrakeCommandOpenConfirmed := PRG_TRANSLATION_CFC.instTranslationM3.BrakeCommandOpenConfirmed;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx407_BrakeTimeoutElapsed := GVL_Global.instTranslationOutputInterlock_LD.BrakeTimeoutElapsed;

GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx501_CmdDriveControlWord  := GVL_Global.instTranslationOutputInterlock_LD.DriveControlWord;
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz      := REAL_TO_UINT(GVL_Global.instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0);
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ   := GVL_Global.TranslationBrakeCmd;
