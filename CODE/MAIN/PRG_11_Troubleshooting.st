(* ═══════════════════════════════════════════════════════════════
   🕵️‍♂️ PRG_11_Troubleshooting — Programme Espion de Recherche de Pannes (CORRIGÉ 100%)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté en toute fin de MainTask (Position 11).
   🔒 ZERO ÉCRITURE SUR LA MACHINE : 100% lecture seule.
   🎨 Alimente la GVL_Troubleshooting pour le diagnostic rapide et la maintenance.
   Indexation chronologique par HUNDREDS (100, 200, 300, 400, 500).
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_11_Troubleshooting
VAR
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_11_Troubleshooting) ===

// 🪝 ─── TREUIL M1 (RETENUE) ──────────────────────────────────────────────────
// 100_INPUTS (Acquisition Terrain Physique & Codeur M1)
GVL_Troubleshooting.WinchM1.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM1.RawPos);
GVL_Troubleshooting.WinchM1.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_Troubleshooting.WinchM1.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.WinchM1.Inputs_100.Idx104_BrakeIsOpen_DI         := PRG_00_Inputs.M1BrakeFeedback;
GVL_Troubleshooting.WinchM1.Inputs_100.Idx105_ThermalOk_DI           := PRG_00_Inputs.M1ThermalFeedback;

// 200_DEMANDES_ET_BYPASS (Consignes, Sources & Bypass Comm M1)
GVL_Troubleshooting.WinchM1.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M1TreuilRetenue.Cmd.BtnUp;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M1TreuilRetenue.Cmd.BtnDown;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.CmdWinchM1_SpeedPct;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx206_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_06_WinchControl.M1_SpeedRef_Active;
GVL_Troubleshooting.WinchM1.Demandes_200.Idx209_ArbitratedDirection  := PRG_06_WinchControl.M1_Direction_Active;

// 300_SAFETY (Sécurités Métier, Garde-fous, Capteurs & Defauts M1)
GVL_Troubleshooting.WinchM1.Safety_300.Idx301_EmergencyChainClosed   := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.WinchM1.Safety_300.Idx302_SafeStopActive         := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_Troubleshooting.WinchM1.Safety_300.Idx303_PowerCutOffActive      := PRG_03_Safety.instSafetyWinchM1.PowerCutOff;
GVL_Troubleshooting.WinchM1.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_00_Inputs.TopPositionSensor;
GVL_Troubleshooting.WinchM1.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.WinchM1.Safety_300.Idx306_ForbidAscentEffective  := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_Troubleshooting.WinchM1.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_00_Inputs.SlackCableSwitch;
GVL_Troubleshooting.WinchM1.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.WinchM1.Safety_300.Idx309_ForbidDescentEffective := PRG_03_Safety.instSafetyWinchM1.ForbidDescent;
GVL_Troubleshooting.WinchM1.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_03_Safety.instSafetyWinchM1.State);

// 400_CONTROL (Logique Métier, Rampes & Paliers M1)
GVL_Troubleshooting.WinchM1.Control_400.Idx401_MotionAllowed        := PRG_06_WinchControl.instWinchM1.Ready;
GVL_Troubleshooting.WinchM1.Control_400.Idx402_SpeedStepCalculated  := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_Troubleshooting.WinchM1.Control_400.Idx403_SpeedRamp_Pct        := PRG_06_WinchControl.M1_SpeedRef_Active;
GVL_Troubleshooting.WinchM1.Control_400.Idx404_BrakeReleaseAuthorized:= PRG_06_WinchControl.instWinchM1.BrakeCmd;

// 500_OUTPUTS (Commandes Physiques Sorties M1)
GVL_Troubleshooting.WinchM1.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := PRG_10_Outputs.M1RelayFwd;
GVL_Troubleshooting.WinchM1.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := PRG_10_Outputs.M1RelayRev;
GVL_Troubleshooting.WinchM1.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= PRG_10_Outputs.M1SpeedContactor1;
GVL_Troubleshooting.WinchM1.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= PRG_10_Outputs.M1SpeedContactor4;
GVL_Troubleshooting.WinchM1.Outputs_500.Idx505_CmdBrakeRelease_RQ   := PRG_10_Outputs.M1BrakeCmd;


// 🪝 ─── TREUIL M2 (BENNE) ────────────────────────────────────────────────────
// 100_INPUTS (Acquisition Terrain Physique & Codeur M2)
GVL_Troubleshooting.WinchM2.Inputs_100.Idx101_EncoderRawPos          := TO_DINT(PRG_02_Encoders.instEncoderAbsM2.RawPos);
GVL_Troubleshooting.WinchM2.Inputs_100.Idx102_CablePos_M             := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_Troubleshooting.WinchM2.Inputs_100.Idx103_ContactorsReleased_DI  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff;
GVL_Troubleshooting.WinchM2.Inputs_100.Idx104_BrakeIsOpen_DI         := PRG_00_Inputs.M2BrakeFeedback;
GVL_Troubleshooting.WinchM2.Inputs_100.Idx105_ThermalOk_DI           := PRG_00_Inputs.M2ThermalFeedback;

// 200_DEMANDES_ET_BYPASS (Consignes, Sources & Bypass Comm M2)
GVL_Troubleshooting.WinchM2.Demandes_200.Idx201_JoyRawPhysical_ANA   := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx202_JoyScaledPhysical_Pct:= PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx203_HmiManualCmd_BtnUp   := GVL_IHM.M2TreuilBenne.Cmd.BtnUp;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx204_HmiManualCmd_BtnDown := GVL_IHM.M2TreuilBenne.Cmd.BtnDown;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx205_CycleAutoCmd_Pct      := PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx206_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx207_BypassOperatorComm   := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx208_ArbitratedSpeed_Pct  := PRG_06_WinchControl.M2_SpeedRef_Active;
GVL_Troubleshooting.WinchM2.Demandes_200.Idx209_ArbitratedDirection  := PRG_06_WinchControl.M2_Direction_Active;

// 300_SAFETY (Sécurités Métier, Garde-fous, Capteurs & Defauts M2)
GVL_Troubleshooting.WinchM2.Safety_300.Idx301_EmergencyChainClosed   := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.WinchM2.Safety_300.Idx302_SafeStopActive         := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_Troubleshooting.WinchM2.Safety_300.Idx303_PowerCutOffActive      := PRG_03_Safety.instSafetyWinchM2.PowerCutOff;
GVL_Troubleshooting.WinchM2.Safety_300.Idx304_TopSensorPhysical_DI   := PRG_00_Inputs.TopPositionSensor;
GVL_Troubleshooting.WinchM2.Safety_300.Idx305_TopSensorBypassActive  := GVL_IHM.Commun.Bypass.TopPositionSensor;
GVL_Troubleshooting.WinchM2.Safety_300.Idx306_ForbidAscentEffective  := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_Troubleshooting.WinchM2.Safety_300.Idx307_SlackCablePhysical_DI  := PRG_00_Inputs.SlackCableSwitch;
GVL_Troubleshooting.WinchM2.Safety_300.Idx308_SlackCableBypassActive := GVL_IHM.Commun.Bypass.SlackCable;
GVL_Troubleshooting.WinchM2.Safety_300.Idx309_ForbidDescentEffective := PRG_03_Safety.instSafetyWinchM2.ForbidDescent;
GVL_Troubleshooting.WinchM2.Safety_300.Idx310_MecaFaultMask           := INT_TO_WORD(PRG_03_Safety.instSafetyWinchM2.State);

// 400_CONTROL (Logique Métier, Rampes & Paliers M2)
GVL_Troubleshooting.WinchM2.Control_400.Idx401_MotionAllowed        := PRG_06_WinchControl.instWinchM2.Ready;
GVL_Troubleshooting.WinchM2.Control_400.Idx402_SpeedStepCalculated  := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_Troubleshooting.WinchM2.Control_400.Idx403_SpeedRamp_Pct        := PRG_06_WinchControl.M2_SpeedRef_Active;
GVL_Troubleshooting.WinchM2.Control_400.Idx404_BrakeReleaseAuthorized:= PRG_06_WinchControl.instWinchM2.BrakeCmd;

// 500_OUTPUTS (Commandes Physiques Sorties M2)
GVL_Troubleshooting.WinchM2.Outputs_500.Idx501_CmdRelayFwd_Up_DQ    := PRG_10_Outputs.M2RelayFwd;
GVL_Troubleshooting.WinchM2.Outputs_500.Idx502_CmdRelayRev_Down_DQ  := PRG_10_Outputs.M2RelayRev;
GVL_Troubleshooting.WinchM2.Outputs_500.Idx503_CmdSpeedContactor1_DQ:= PRG_10_Outputs.M2SpeedContactor1;
GVL_Troubleshooting.WinchM2.Outputs_500.Idx504_CmdSpeedContactor4_DQ:= PRG_10_Outputs.M2SpeedContactor4;
GVL_Troubleshooting.WinchM2.Outputs_500.Idx505_CmdBrakeRelease_RQ   := PRG_10_Outputs.M2BrakeCmd;


// ↔️ ─── TRANSLATION M3 (VARIATEUR AC600) ────────────────────────────────────
// 100_INPUTS (Capteurs Position Terrain & Variateur M3)
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx101_PosTremie_DI         := PRG_00_Inputs.TranslationPosTremie;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx102_PosPV_DI             := PRG_00_Inputs.TranslationPosPV;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx103_PosP2_DI             := PRG_00_Inputs.TranslationPosP2;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx104_PosP1_DI             := PRG_00_Inputs.TranslationPosP1;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx105_PosMaintenance_DI    := PRG_00_Inputs.TranslationPosMaintenance;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx106_DriveActualFreq_Hz   := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx107_DriveStatusWord      := PRG_00_Inputs.M3_StatusWord_Filtered;
GVL_Troubleshooting.TranslationM3.Inputs_100.Idx108_BrakeIsOpen_DI       := PRG_00_Inputs.M3BrakeFeedback;

// 200_DEMANDES_ET_BYPASS (Consignes Joystick/IHM/Cycle & Bypass Network M3)
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx201_JoyXRaw_ANA          := PRG_01_Diagnostics.FB_Joystick_0.RawX;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx202_JoyXScaled_Pct       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx203_HmiCmd_BtnFwd        := GVL_IHM.TranslationM3.Cmd.BtnFwd;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx204_HmiCmd_BtnRev        := GVL_IHM.TranslationM3.Cmd.BtnRev;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx205_HmiTargetPosition    := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx206_CycleTargetPosition  := GVL_IHM.Cycle.State.SelTarget;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx207_ModeActive           := PRG_04_Modes.instModes.Mode;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx208_BypassNetworkActive  := GVL_IHM.TranslationM3.Bypass.Global;
GVL_Troubleshooting.TranslationM3.Demandes_200.Idx209_ArbitratedSpeed_Pct := PRG_07_TranslationControl.M3_SpeedRef_Active;

// 300_SAFETY (Sécurités Variateur, SafeStop & Defauts Position M3)
GVL_Troubleshooting.TranslationM3.Safety_300.Idx301_EmergencyChainClosed  := PRG_00_Inputs.EmergencyChain;
GVL_Troubleshooting.TranslationM3.Safety_300.Idx302_SafeStopActive        := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_Troubleshooting.TranslationM3.Safety_300.Idx303_PowerCutOffActive     := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
GVL_Troubleshooting.TranslationM3.Safety_300.Idx304_LimitSwitchFwdActive := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_Troubleshooting.TranslationM3.Safety_300.Idx306_BypassLimitSwitch    := GVL_IHM.TranslationM3.Bypass.LimitSwitch;
GVL_Troubleshooting.TranslationM3.Safety_300.Idx307_PositionDecoderIncoherent := PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;

// 400_CONTROL (Calcul Consignes Variateur & Autorisations M3)
GVL_Troubleshooting.TranslationM3.Control_400.Idx401_MotionAllowed        := PRG_07_TranslationControl.instTranslationM3.Ready;
GVL_Troubleshooting.TranslationM3.Control_400.Idx402_SetpointFreq_Hz      := PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz;
GVL_Troubleshooting.TranslationM3.Control_400.Idx403_DriveControlWord     := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;

// 500_OUTPUTS (Commandes Réelles Transmises EtherCAT AC600 & Frein M3)
GVL_Troubleshooting.TranslationM3.Outputs_500.Idx501_CmdDriveControlWord  := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;
GVL_Troubleshooting.TranslationM3.Outputs_500.Idx502_CmdDriveFreq_Hz      := REAL_TO_UINT(PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz * 100.0);
GVL_Troubleshooting.TranslationM3.Outputs_500.Idx503_CmdBrakeRelease_RQ   := PRG_10_Outputs.TranslationBrakeCmd;
