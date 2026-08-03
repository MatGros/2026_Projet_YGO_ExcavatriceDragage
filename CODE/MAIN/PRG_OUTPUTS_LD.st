(* ═══════════════════════════════════════════════════════════════
   📤 PRG_10_Outputs_LD — Écriture des SORTIES physiques (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §5
   ⚙️ Exécuté par la tâche PLC en position 10.
   ✅ Reçoit ses commandes en VAR_INPUT (écrites par le reste du code).
   📄 Converti automatiquement en Ladder Diagram (<LD>) dans CODESYS.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_10_Outputs_LD
VAR_OUTPUT
    // ── [COMMANDES FINALES LECTURE SEULE] ─────────────────────────────────────────────────
    M1RelayFwd        : BOOL;
    M1RelayRev        : BOOL;
    M1SpeedContactor1 : BOOL;
    M1SpeedContactor2 : BOOL;
    M1SpeedContactor3 : BOOL;
    M1SpeedContactor4 : BOOL;
    M1BrakeCmd        : BOOL;
    M2RelayFwd        : BOOL;
    M2RelayRev        : BOOL;
    M2SpeedContactor1 : BOOL;
    M2SpeedContactor2 : BOOL;
    M2SpeedContactor3 : BOOL;
    M2SpeedContactor4 : BOOL;
    M2BrakeCmd        : BOOL;
    TranslationBrakeCmd : BOOL;
    PowerKeepAlive_A_RQ : BOOL;
    PowerKeepAlive_B_RQ : BOOL;
    EmergencyArming_RQ  : BOOL;
    EmergencyArmingPulseActive   : BOOL;
    EmergencyArmingLockoutActive: BOOL;
    ArmingSeqStep                : INT;
    RedundancyTestFailed         : BOOL;
    EmergencyArmingFailed        : BOOL;
END_VAR
VAR
    // 🛡️ Frontières finales stateful, appelées UNE fois par scan au plus près
    // des Q/PDO. PRG_06/PRG_07 publient les demandes brutes typées en VAR_OUTPUT;
    // l'ordre MainTask PRG_06 → PRG_07 → PRG_10 est obligatoire.
    instWinchOutputInterlockM1_LD : FB_WinchOutputInterlock_LD;
    instWinchOutputInterlockM2_LD : FB_WinchOutputInterlock_LD;
    instTranslationOutputInterlock_LD : FB_TranslationOutputInterlock_LD;
    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
    PowerCutOffReq : BOOL;
END_VAR

// === IMPLEMENTATION ===

// === [BARRIÈRES FINALES M1 / M2 / M3] ===
// PRG_06/PRG_07 produisent uniquement les demandes brutes publiques ci-dessous.
// Les trois instances sont les uniques producteurs des commandes autorisées.
// Aucun mapping C1..C4 n'est reconstruit : FB_Winch / SpeedStepTable demeure propriétaire.
instWinchOutputInterlockM1_LD(
    Enable := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.Enable,
    Reset := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1 := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2 := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3 := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4 := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep := PRG_TREUILS_CFC.WinchM1FinalInterlockRequest.RequestedStep
);
instWinchOutputInterlockM2_LD(
    Enable := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.Enable,
    Reset := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1 := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2 := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3 := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4 := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep := PRG_TREUILS_CFC.WinchM2FinalInterlockRequest.RequestedStep
);
instTranslationOutputInterlock_LD(
    Enable := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.Enable,
    Reset := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.Reset,
    PowerContactorEngaged := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.SafeStop,
    BrakeReleaseRequest := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz := PRG_TRANSLATION_CFC.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);

// === [Q M1 / M2] ===
M1RelayFwd := instWinchOutputInterlockM1_LD.RelayFwd;
M1RelayRev := instWinchOutputInterlockM1_LD.RelayRev;
M1SpeedContactor1 := instWinchOutputInterlockM1_LD.Contactor1;
M1SpeedContactor2 := instWinchOutputInterlockM1_LD.Contactor2;
M1SpeedContactor3 := instWinchOutputInterlockM1_LD.Contactor3;
M1SpeedContactor4 := instWinchOutputInterlockM1_LD.Contactor4;
M1BrakeCmd := instWinchOutputInterlockM1_LD.BrakeCmd;
M1_RelayFwd_Up_DQ := M1RelayFwd;
M1_RelayRev_Down_DQ := M1RelayRev;
M1_SpeedContactor_1_DQ := M1SpeedContactor1;
M1_SpeedContactor_2_DQ := M1SpeedContactor2;
M1_SpeedContactor_3_DQ := M1SpeedContactor3;
M1_SpeedContactor_4_DQ := M1SpeedContactor4;
M1_BrakeRelease_RQ := M1BrakeCmd;

M2RelayFwd := instWinchOutputInterlockM2_LD.RelayFwd;
M2RelayRev := instWinchOutputInterlockM2_LD.RelayRev;
M2SpeedContactor1 := instWinchOutputInterlockM2_LD.Contactor1;
M2SpeedContactor2 := instWinchOutputInterlockM2_LD.Contactor2;
M2SpeedContactor3 := instWinchOutputInterlockM2_LD.Contactor3;
M2SpeedContactor4 := instWinchOutputInterlockM2_LD.Contactor4;
M2BrakeCmd := instWinchOutputInterlockM2_LD.BrakeCmd;
M2_RelayFwd_Up_Close_DQ := M2RelayFwd;
M2_RelayRev_Down_Open_DQ := M2RelayRev;
M2_SpeedContactor_1_DQ := M2SpeedContactor1;
M2_SpeedContactor_2_DQ := M2SpeedContactor2;
M2_SpeedContactor_3_DQ := M2SpeedContactor3;
M2_SpeedContactor_4_DQ := M2SpeedContactor4;
M2_BrakeRelease_RQ := M2BrakeCmd;

// === [PDO M3 + KOBOLD] ===
TranslationBrakeCmd := instTranslationOutputInterlock_LD.BrakeCmd;
M3_BrakeRelease_RQ := TranslationBrakeCmd;
M3_CommandWord := instTranslationOutputInterlock_LD.DriveControlWord;
M3_SetpointFrequencyHz := REAL_TO_UINT(instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0);
M1_M2_KoboldMeasureEnable_DQ := PRG_TREUILS_CFC.KoboldContactorCmdArbitrated
                                AND PRG_01_Inputs_LD.PowerContactorEngaged
                                AND PRG_01_Inputs_LD.EmergencyChainClosed;

// === [SÉCURITÉ & COUPURE PUISSANCE AMONT] ===
// Boucle de sécurité et séquencement d'armement général.

// Demande de coupure de puissance
PowerCutOffReq := PRG_SAFETY_CFC.instSafetyWinchM1.PowerCutOff OR PRG_SAFETY_CFC.instSafetyWinchM2.PowerCutOff OR PRG_SAFETY_CFC.instSafetyTranslationM3.PowerCutOff;

// Gestionnaire d'arrêt d'urgence et de réarmement
instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_SUPERVISION_CFC.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_01_Inputs_LD.EmergencyChainClosed,
    PowerContactorEngaged := PRG_01_Inputs_LD.PowerContactorEngaged,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
);

// Affectation des sorties de réarmement et maintien puissance
PowerKeepAlive_A_RQ := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ := instSafetyEmergencyManagement.ArmPulse_RQ;

EmergencyArmingPulseActive := instSafetyEmergencyManagement.ArmPulse_RQ;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.Diag.LockoutActive;
ArmingSeqStep := instSafetyEmergencyManagement.State.Step;
RedundancyTestFailed := instSafetyEmergencyManagement.Diag.RedundancyTestFailed;
EmergencyArmingFailed := instSafetyEmergencyManagement.Diag.ArmFailed;

// ── [PUBLICATION DANS GVL_GLOBAL POUR LECTURE PAR LES AUTRES POU] ─────────────────
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
GVL_Global.EmergencyArmingPulseActive   := EmergencyArmingPulseActive;
GVL_Global.EmergencyArmingLockoutActive := EmergencyArmingLockoutActive;
GVL_Global.ArmingSeqStep                := ArmingSeqStep;

GVL_Global.instWinchOutputInterlockM1_LD     := instWinchOutputInterlockM1_LD;
GVL_Global.instWinchOutputInterlockM2_LD     := instWinchOutputInterlockM2_LD;
GVL_Global.instTranslationOutputInterlock_LD := instTranslationOutputInterlock_LD;
