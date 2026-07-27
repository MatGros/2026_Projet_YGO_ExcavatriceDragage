(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ PRG_11_Troubleshooting — Programme Espion de Recherche de Pannes (ORIENTÉ FONCTIONS & CONTEXTE)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté en toute fin de MainTask (Position 11).
   🔒 ZERO ÉCRITURE SUR LA MACHINE : 100% lecture seule.
   🎨 Alimente la GVL_Troubleshooting par CONTEXTE GLOBAL ET FONCTIONS MACHINE.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_11_Troubleshooting
VAR
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_11_Troubleshooting) ===

// 🌐 ─── 0. CONTEXTE MACHINE GLOBAL ───────────────────────────────────────────
GVL_Troubleshooting.ContexteMachineGlobal.Idx101_ModeActive             := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.ContexteMachineGlobal.Idx102_SimulationEnabled      := GVL_Simulation.SimulationModeActive;
GVL_Troubleshooting.ContexteMachineGlobal.Idx103_JoystickCommOk         := PRG_01_Diagnostics.FB_Joystick_0.Ready;

GVL_Troubleshooting.ContexteMachineGlobal.Idx201_JoystickSelected       := (PRG_04_Modes.instModes.Mode <> E_Mode.MAINT_N1 AND PRG_04_Modes.instModes.Mode <> E_Mode.MAINT_N2);
GVL_Troubleshooting.ContexteMachineGlobal.Idx202_BypassNetworkGlobal    := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm OR GVL_IHM.M2TreuilBenne.Bypass.OperatorComm OR GVL_IHM.TranslationM3.Bypass.Global;
GVL_Troubleshooting.ContexteMachineGlobal.Idx203_BypassSensorsGlobal    := GVL_IHM.Commun.Bypass.TopPositionSensor OR GVL_IHM.Commun.Bypass.SlackCable OR GVL_IHM.TranslationM3.Bypass.LimitSwitch;

GVL_Troubleshooting.ContexteMachineGlobal.Idx301_EmergencyChainClosed   := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.ContexteMachineGlobal.Idx302_EmergencyStopOk        := PRG_00_Inputs.EmergencyStopOk;
GVL_Troubleshooting.ContexteMachineGlobal.Idx303_SafeStopActiveAny       := PRG_03_Safety.instSafetyWinchM1.SafeStop OR PRG_03_Safety.instSafetyWinchM2.SafeStop OR PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_Troubleshooting.ContexteMachineGlobal.Idx304_PowerCutOffActiveAny   := PRG_03_Safety.instSafetyWinchM1.PowerCutOff OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff OR PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;

GVL_Troubleshooting.ContexteMachineGlobal.Idx401_HmiHeartbeatOk         := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk;
GVL_Troubleshooting.ContexteMachineGlobal.Idx402_CycleAutoBusy          := PRG_05_Cycle.instCycle.Busy;


// 🛗 ─── 1. LEVAGE SYNCHRONISÉ M1 + M2 (MODE COUPLÉ NOMINAL) ───────────────────
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx101_M1_CablePos_M         := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx102_M2_CablePos_M         := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx103_SyncDelta_M           := PRG_06_WinchControl.instWinchSync.DeltaPosM;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx201_JoyYRaw_Pct           := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM       := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx203_ArbitratedSpeed_Pct   := PRG_06_WinchControl.M1_SpeedRef_Active;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx301_EmergencyChainClosed  := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx302_SyncFaultActive       := PRG_06_WinchControl.instWinchSync.Error;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx303_M1_ForbidAscent       := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx304_M2_ForbidAscent       := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx401_SyncMotionAllowed     := PRG_06_WinchControl.instWinchM1.Ready AND PRG_06_WinchControl.instWinchM2.Ready;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx402_M1_SetpointSpeed_Pct  := PRG_06_WinchControl.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx403_M2_SetpointSpeed_Pct  := PRG_06_WinchControl.M2_SpeedRef_Active;

GVL_Troubleshooting.LevageSynchroniseM1M2.Idx501_M1_CmdRelayFwd_DQ     := PRG_10_Outputs.M1RelayFwd;
GVL_Troubleshooting.LevageSynchroniseM1M2.Idx502_M2_CmdRelayFwd_DQ     := PRG_10_Outputs.M2RelayFwd;


// 🛗 ─── 2. LEVAGE UNITAIRE M1 (TREUIL RETENUE) ────────────────────────────────
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM1.RawPos);
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx104_BrakeIsOpen_DI         := PRG_00_Inputs.M1BrakeFeedback;
GVL_Troubleshooting.LevageUnitaireM1.Inputs_100.Idx105_ThermalOk_DI           := PRG_00_Inputs.M1ThermalFeedback;

GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M1TreuilRetenue.Cmd.BtnUp;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M1TreuilRetenue.Cmd.BtnDown;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.CmdWinchM1_SpeedPct;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx206_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_06_WinchControl.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM1.Demandes_200.Idx209_ArbitratedDirection  := PRG_06_WinchControl.M1_Direction_Active;

GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx301_EmergencyChainClosed   := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx302_SafeStopActive         := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx303_PowerCutOffActive      := PRG_03_Safety.instSafetyWinchM1.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_00_Inputs.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx306_ForbidAscentEffective  := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_00_Inputs.SlackCableSwitch;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx309_ForbidDescentEffective := PRG_03_Safety.instSafetyWinchM1.ForbidDescent;
GVL_Troubleshooting.LevageUnitaireM1.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_03_Safety.instSafetyWinchM1.State);

GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx401_MotionAllowed        := PRG_06_WinchControl.instWinchM1.Ready;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx402_SpeedStepCalculated  := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx403_SpeedRamp_Pct        := PRG_06_WinchControl.M1_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM1.Control_400.Idx404_BrakeReleaseAuthorized:= PRG_06_WinchControl.instWinchM1.BrakeCmd;

GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := PRG_10_Outputs.M1RelayFwd;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := PRG_10_Outputs.M1RelayRev;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= PRG_10_Outputs.M1SpeedContactor1;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= PRG_10_Outputs.M1SpeedContactor4;
GVL_Troubleshooting.LevageUnitaireM1.Outputs_500.Idx505_CmdBrakeRelease_RQ   := PRG_10_Outputs.M1BrakeCmd;


// 🛗 ─── 3. LEVAGE UNITAIRE M2 (TREUIL BENNE) ──────────────────────────────────
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM2.RawPos);
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx104_BrakeIsOpen_DI         := PRG_00_Inputs.M2BrakeFeedback;
GVL_Troubleshooting.LevageUnitaireM2.Inputs_100.Idx105_ThermalOk_DI           := PRG_00_Inputs.M2ThermalFeedback;

GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M2TreuilBenne.Cmd.BtnUp;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M2TreuilBenne.Cmd.BtnDown;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx206_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_06_WinchControl.M2_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM2.Demandes_200.Idx209_ArbitratedDirection  := PRG_06_WinchControl.M2_Direction_Active;

GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx301_EmergencyChainClosed   := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx302_SafeStopActive         := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx303_PowerCutOffActive      := PRG_03_Safety.instSafetyWinchM2.PowerCutOff;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_00_Inputs.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx306_ForbidAscentEffective  := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_00_Inputs.SlackCableSwitch;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx309_ForbidDescentEffective := PRG_03_Safety.instSafetyWinchM2.ForbidDescent;
GVL_Troubleshooting.LevageUnitaireM2.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_03_Safety.instSafetyWinchM2.State);

GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx401_MotionAllowed        := PRG_06_WinchControl.instWinchM2.Ready;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx402_SpeedStepCalculated  := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx403_SpeedRamp_Pct        := PRG_06_WinchControl.M2_SpeedRef_Active;
GVL_Troubleshooting.LevageUnitaireM2.Control_400.Idx404_BrakeReleaseAuthorized:= PRG_06_WinchControl.instWinchM2.BrakeCmd;

GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := PRG_10_Outputs.M2RelayFwd;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := PRG_10_Outputs.M2RelayRev;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= PRG_10_Outputs.M2SpeedContactor1;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= PRG_10_Outputs.M2SpeedContactor4;
GVL_Troubleshooting.LevageUnitaireM2.Outputs_500.Idx505_CmdBrakeRelease_RQ   := PRG_10_Outputs.M2BrakeCmd;


// 🪣 ─── 4. OUVERTURE / FERMETURE BENNE ─────────────────────────────────────────
GVL_Troubleshooting.BenneOuvertureFermeture.Idx101_BucketIsOpen               := GVL_IHM.M2TreuilBenne.Bucket.State.MechState.IsOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx102_BucketIsClosed             := GVL_IHM.M2TreuilBenne.Bucket.State.MechState.IsClosed;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx103_OffsetPos_M                := PRG_06_WinchControl.instBucket.ActiveOffsetM;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx201_HmiCmd_BtnOpen             := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx202_HmiCmd_BtnClose            := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx203_CycleCmd_Open              := PRG_05_Cycle.instCycle.CmdBucket_Open;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx301_EmergencyChainClosed       := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx302_BucketFaultActive          := PRG_06_WinchControl.instBucket.Error;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx401_BucketBusy                 := PRG_06_WinchControl.instBucket.Busy;
GVL_Troubleshooting.BenneOuvertureFermeture.Idx402_BucketDone                 := PRG_06_WinchControl.instBucket.Done;

GVL_Troubleshooting.BenneOuvertureFermeture.Idx501_M2_CmdRev_DQ               := PRG_10_Outputs.M2RelayRev;


// ↔️ ─── 5. TRANSLATION PONT M3 (VARIATEUR AC600) ─────────────────────────────
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx101_PosTremie_DI         := PRG_00_Inputs.TranslationPosTremie;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx102_PosPV_DI             := PRG_00_Inputs.TranslationPosPV;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx103_PosP2_DI             := PRG_00_Inputs.TranslationPosP2;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx104_PosP1_DI             := PRG_00_Inputs.TranslationPosP1;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI    := PRG_00_Inputs.TranslationPosMaintenance;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz   := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx107_DriveStatusWord      := PRG_00_Inputs.M3_StatusWord_Filtered;
GVL_Troubleshooting.TranslationPontM3.Inputs_100.Idx108_BrakeIsOpen_DI       := PRG_00_Inputs.M3BrakeFeedback;

GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx201_JoyXRaw_ANA          := PRG_01_Diagnostics.FB_Joystick_0.RawX;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx202_JoyXScaled_Pct       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx203_HmiCmd_BtnFwd        := GVL_IHM.TranslationM3.Cmd.BtnFwd;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx204_HmiCmd_BtnRev        := GVL_IHM.TranslationM3.Cmd.BtnRev;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx205_HmiTargetPosition    := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx206_CycleTargetPosition  := GVL_IHM.Cycle.State.SelTarget;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx207_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx208_BypassNetworkActive  := GVL_IHM.TranslationM3.Bypass.Global;
GVL_Troubleshooting.TranslationPontM3.Demandes_200.Idx209_ArbitratedSpeed_Pct := PRG_07_TranslationControl.M3_SpeedRef_Active;

GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx301_EmergencyChainClosed  := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx302_SafeStopActive        := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx303_PowerCutOffActive     := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx304_LimitSwitchFwdActive := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx306_BypassLimitSwitch    := GVL_IHM.TranslationM3.Bypass.LimitSwitch;
GVL_Troubleshooting.TranslationPontM3.Safety_300.Idx307_PositionDecoderIncoherent := PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;

GVL_Troubleshooting.TranslationPontM3.Control_400.Idx401_MotionAllowed        := PRG_07_TranslationControl.instTranslationM3.Ready;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx402_SetpointFreq_Hz      := PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz;
GVL_Troubleshooting.TranslationPontM3.Control_400.Idx403_DriveControlWord     := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;

GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx501_CmdDriveControlWord  := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx502_CmdDriveFreq_Hz      := REAL_TO_UINT(PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz * 100.0);
GVL_Troubleshooting.TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ   := PRG_10_Outputs.TranslationBrakeCmd;
