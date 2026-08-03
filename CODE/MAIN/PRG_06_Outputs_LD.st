(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs_LD — Écriture des SORTIES physiques (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §5
   ⚙️ Exécuté par la tâche PLC en position 6 (après PRG_05_Translation).
   📄 Converti automatiquement en Ladder Diagram (<LD>) dans CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs_LD

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
    PowerCutOffReq      : BOOL;

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
    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === ⚡ ÉCRITURE SORTIES PHYSIQUES Q (M1 / M2 / M3 via FB_Output) ===

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

// === 🛡️ §2 SÉCURITÉ & COUPURE PUISSANCE AMONT ===

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

END_PROGRAM
