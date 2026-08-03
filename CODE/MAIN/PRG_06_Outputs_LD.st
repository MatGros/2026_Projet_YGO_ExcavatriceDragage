(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs_LD — Écriture des SORTIES physiques (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §5
   ⚙️ Exécuté par la tâche PLC en position 6 (après PRG_05_Translation).
   ✅ Reçoit ses commandes en VAR_INPUT (écrites par le reste du code).
   📄 Converti automatiquement en Ladder Diagram (<LD>) dans CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs_LD

VAR_INPUT
    M1RelayFwd          : BOOL;
    M1RelayRev          : BOOL;
    M1SpeedContactor1   : BOOL;
    M1SpeedContactor2   : BOOL;
    M1SpeedContactor3   : BOOL;
    M1SpeedContactor4   : BOOL;
    M1BrakeCmd          : BOOL;
    M2RelayFwd          : BOOL;
    M2RelayRev          : BOOL;
    M2SpeedContactor1   : BOOL;
    M2SpeedContactor2   : BOOL;
    M2SpeedContactor3   : BOOL;
    M2SpeedContactor4   : BOOL;
    M2BrakeCmd          : BOOL;
    TranslationBrakeCmd : BOOL;
    KoboldContactorCmd  : BOOL;
END_VAR

VAR_OUTPUT
    PowerKeepAlive_A_RQ          : BOOL;
    PowerKeepAlive_B_RQ          : BOOL;
    EmergencyArming_RQ           : BOOL;
    EmergencyArmingPulseActive   : BOOL;
    EmergencyArmingLockoutActive : BOOL;
    ArmingSeqStep                : INT;
    RedundancyTestFailed         : BOOL;
    EmergencyArmingFailed        : BOOL;
END_VAR

VAR
    instWinchOutputInterlockM1_LD     : FB_WinchOutputInterlock_LD;
    instWinchOutputInterlockM2_LD     : FB_WinchOutputInterlock_LD;
    instTranslationOutputInterlock_LD : FB_TranslationOutputInterlock_LD;
    instSafetyEmergencyManagement     : FB_Safety_EmergencyManagement;
    PowerCutOffReq                    : BOOL;

    instM1RelayFwd          : FB_Output;
    instM1RelayRev          : FB_Output;
    instM1SpeedContactor1   : FB_Output;
    instM1SpeedContactor2   : FB_Output;
    instM1SpeedContactor3   : FB_Output;
    instM1SpeedContactor4   : FB_Output;
    instM1BrakeCmd          : FB_Output;
    instM2RelayFwd          : FB_Output;
    instM2RelayRev          : FB_Output;
    instM2SpeedContactor1   : FB_Output;
    instM2SpeedContactor2   : FB_Output;
    instM2SpeedContactor3   : FB_Output;
    instM2SpeedContactor4   : FB_Output;
    instM2BrakeCmd          : FB_Output;
    instTranslationBrakeCmd : FB_Output;
END_VAR

// === 🪝 §1 BARRIÈRES FINALES ET INTERLOCKS (M1 / M2 / M3) ===

instWinchOutputInterlockM1_LD(
    Enable := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Enable,
    Reset := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1 := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2 := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3 := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4 := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedStep
);
M1RelayFwd := instWinchOutputInterlockM1_LD.RelayFwd;
M1RelayRev := instWinchOutputInterlockM1_LD.RelayRev;
M1SpeedContactor1 := instWinchOutputInterlockM1_LD.Contactor1;
M1SpeedContactor2 := instWinchOutputInterlockM1_LD.Contactor2;
M1SpeedContactor3 := instWinchOutputInterlockM1_LD.Contactor3;
M1SpeedContactor4 := instWinchOutputInterlockM1_LD.Contactor4;
M1BrakeCmd := instWinchOutputInterlockM1_LD.BrakeCmd;

instWinchOutputInterlockM2_LD(
    Enable := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Enable,
    Reset := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1 := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2 := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3 := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4 := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedStep
);
M2RelayFwd := instWinchOutputInterlockM2_LD.RelayFwd;
M2RelayRev := instWinchOutputInterlockM2_LD.RelayRev;
M2SpeedContactor1 := instWinchOutputInterlockM2_LD.Contactor1;
M2SpeedContactor2 := instWinchOutputInterlockM2_LD.Contactor2;
M2SpeedContactor3 := instWinchOutputInterlockM2_LD.Contactor3;
M2SpeedContactor4 := instWinchOutputInterlockM2_LD.Contactor4;
M2BrakeCmd := instWinchOutputInterlockM2_LD.BrakeCmd;

instTranslationOutputInterlock_LD(
    Enable := PRG_05_Translation.TranslationFinalInterlockRequest.Enable,
    Reset := PRG_05_Translation.TranslationFinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_05_Translation.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_05_Translation.TranslationFinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_05_Translation.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_05_Translation.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord := PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz := PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);
TranslationBrakeCmd := instTranslationOutputInterlock_LD.BrakeCmd;
M3_BrakeRelease_RQ := TranslationBrakeCmd;
M3_CommandWord := instTranslationOutputInterlock_LD.DriveControlWord;
M3_SetpointFrequencyHz := REAL_TO_UINT(instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0);
KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated;


// === ⚡ §2 ÉCRITURE SORTIES PHYSIQUES Q (M1 / M2 / M3 / KOBOLD via FB_Output) ===

instM1RelayFwd(Command := M1RelayFwd);
M1_RelayFwd_Up_DQ := instM1RelayFwd.State;

instM1RelayRev(Command := M1RelayRev);
M1_RelayRev_Down_DQ := instM1RelayRev.State;

instM1SpeedContactor1(Command := M1SpeedContactor1);
M1_SpeedContactor_1_DQ := instM1SpeedContactor1.State;

instM1SpeedContactor2(Command := M1SpeedContactor2);
M1_SpeedContactor_2_DQ := instM1SpeedContactor2.State;

instM1SpeedContactor3(Command := M1SpeedContactor3);
M1_SpeedContactor_3_DQ := instM1SpeedContactor3.State;

instM1SpeedContactor4(Command := M1SpeedContactor4);
M1_SpeedContactor_4_DQ := instM1SpeedContactor4.State;

instM1BrakeCmd(Command := M1BrakeCmd);
M1_BrakeRelease_RQ := instM1BrakeCmd.State;

instM2RelayFwd(Command := M2RelayFwd);
M2_RelayFwd_Up_Close_DQ := instM2RelayFwd.State;

instM2RelayRev(Command := M2RelayRev);
M2_RelayRev_Down_Open_DQ := instM2RelayRev.State;

instM2SpeedContactor1(Command := M2SpeedContactor1);
M2_SpeedContactor_1_DQ := instM2SpeedContactor1.State;

instM2SpeedContactor2(Command := M2SpeedContactor2);
M2_SpeedContactor_2_DQ := instM2SpeedContactor2.State;

instM2SpeedContactor3(Command := M2SpeedContactor3);
M2_SpeedContactor_3_DQ := instM2SpeedContactor3.State;

instM2SpeedContactor4(Command := M2SpeedContactor4);
M2_SpeedContactor_4_DQ := instM2SpeedContactor4.State;

instM2BrakeCmd(Command := M2BrakeCmd);
M2_BrakeRelease_RQ := instM2BrakeCmd.State;

instTranslationBrakeCmd(Command := TranslationBrakeCmd);
M3_BrakeRelease_RQ := instTranslationBrakeCmd.State;

M1_M2_KoboldMeasureEnable_DQ := KoboldContactorCmd
                                AND PRG_01_Inputs_LD.PowerContactorEngaged
                                AND PRG_01_Inputs_LD.EmergencyChainClosed;


// === 🛡️ §3 SÉCURITÉ & COUPURE PUISSANCE AMONT ===

PowerCutOffReq := FALSE;

instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_01_Inputs_LD.EmergencyChainClosed,
    PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
);

PowerKeepAlive_A_RQ := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ := instSafetyEmergencyManagement.ArmPulse_RQ;

EmergencyArmingPulseActive := instSafetyEmergencyManagement.ArmPulse_RQ;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.Diag.LockoutActive;
ArmingSeqStep := instSafetyEmergencyManagement.State.Step;
RedundancyTestFailed := instSafetyEmergencyManagement.Diag.RedundancyTestFailed;
EmergencyArmingFailed := instSafetyEmergencyManagement.Diag.ArmFailed;

GVL_Global.M1RelayFwd                    := M1RelayFwd;
GVL_Global.M1RelayRev                    := M1RelayRev;
GVL_Global.M1SpeedContactor1             := M1SpeedContactor1;
GVL_Global.M1SpeedContactor2             := M1SpeedContactor2;
GVL_Global.M1SpeedContactor3             := M1SpeedContactor3;
GVL_Global.M1SpeedContactor4             := M1SpeedContactor4;
GVL_Global.M1BrakeCmd                    := M1BrakeCmd;
GVL_Global.M2RelayFwd                    := M2RelayFwd;
GVL_Global.M2RelayRev                    := M2RelayRev;
GVL_Global.M2SpeedContactor1             := M2SpeedContactor1;
GVL_Global.M2SpeedContactor2             := M2SpeedContactor2;
GVL_Global.M2SpeedContactor3             := M2SpeedContactor3;
GVL_Global.M2SpeedContactor4             := M2SpeedContactor4;
GVL_Global.M2BrakeCmd                    := M2BrakeCmd;
GVL_Global.TranslationBrakeCmd           := TranslationBrakeCmd;

END_PROGRAM
