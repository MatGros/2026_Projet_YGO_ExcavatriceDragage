(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs_LD — Écriture des SORTIES physiques (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §5
   ⚙️ Exécuté par la tâche PLC en position 6 (après PRG_05_Translation).
   📄 Converti automatiquement en Ladder Diagram (<LD>) dans CODESYS.
   🛡️ LOT_STRUCTURE_INTERLOCKS_LD (2026-08) : barrières finales M1/M2/M3
      rendues visibles — FB_WinchOutputInterlock_LD (×2) et
      FB_TranslationOutputInterlock_LD (×1) câblés en amont des coils,
      contacts nommés sur variables qualifiées (visibilité maintenance :
      interlocks/safety qui coupent chaque actionneur lisibles directement
      dans le réseau Ladder, sans ouvrir un autre POU).
   🔒 SafetyStructureNotValidated reste TRUE : AUCUNE sortie physique
      moteur/frein n'est autorisée tant que ce garde-fou n'est pas retiré
      dans un lot safety validé séparément (voir alerte ci-dessous).
   ⚠️ Écart connu, HORS PÉRIMÈTRE de ce lot (signalé, pas corrigé ici) :
      FB_Safety_Winch / FB_Safety_Translation (7 mécanismes Méca A→E,
      PowerCutOff métier) ne sont appelés nulle part dans CODE/ à ce jour.
      ST_WinchFinalInterlockRequest / ST_TranslationFinalInterlockRequest
      ne portent donc que SafeStop (partiel) — voir PLAN_TASK lot "5
      Reliquats safety" (T72-T74). Ce lot ne câble que ce qui existe déjà
      en amont ; ne pas déduire que la safety métier complète est active.
   🗑️ FB_Output retiré (2026-08) : inverseur pur (State := Command XOR
      InvertLogic) jamais utilisé avec InvertLogic <> FALSE (REX
      2026-08-04, feedback déjà retiré). Coils câblées directement sur
      les sorties des interlocks finaux — élimine 15 blocs sans valeur
      ajoutée et simplifie la lecture maintenance.
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
    EmergencyState               : ST_Safety_Emergency_State;
    EmergencyDiag                : ST_Safety_Emergency_Diag;
    PowerCutOffActive            : BOOL; (* TRUE = demande de coupure finale active *)

    SafetyStructureNotValidated  : BOOL := TRUE; (* 🔒 Garde-fou lot : tant que TRUE, AUCUNE sortie
                                                      moteur/frein M1/M2/M3 n'est autorisée. Retrait
                                                      réservé à un lot safety validé séparément. *)
    M1InterlockEnable            : BOOL; (* Gate finale M1 : structure validée AND WinchM1...Enable *)
    M2InterlockEnable            : BOOL; (* Gate finale M2 : structure validée AND WinchM2...Enable *)
    M3InterlockEnable            : BOOL; (* Gate finale M3 : structure validée AND TranslationRequest.Enable *)
END_VAR

VAR
    instWinchOutputInterlockM1       : FB_WinchOutputInterlock_LD;
    instWinchOutputInterlockM2       : FB_WinchOutputInterlock_LD;
    instTranslationOutputInterlockM3 : FB_TranslationOutputInterlock_LD;

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

    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === 🛡️ §1 BARRIÈRES FINALES M1 / M2 / M3 — INTERLOCKS VISIBLES ===
// Chaque bloc reçoit la demande brute publique du procédé propriétaire
// (ST_WinchFinalInterlockRequest / ST_TranslationFinalInterlockRequest) :
// tous les interlocks/safety qui peuvent couper cet actionneur sont donc
// lisibles directement sur ce réseau, sans ouvrir un autre POU.

// ── Interlock final M1 (Treuil Retenue) ──────────────────────────────────
M1InterlockEnable := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Enable
                      AND NOT SafetyStructureNotValidated;

instWinchOutputInterlockM1(
    Enable                     := M1InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest        := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed  := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.RequestedStep
);

M1RelayFwd        := instWinchOutputInterlockM1.RelayFwd;
M1RelayRev        := instWinchOutputInterlockM1.RelayRev;
M1SpeedContactor1 := instWinchOutputInterlockM1.Contactor1;
M1SpeedContactor2 := instWinchOutputInterlockM1.Contactor2;
M1SpeedContactor3 := instWinchOutputInterlockM1.Contactor3;
M1SpeedContactor4 := instWinchOutputInterlockM1.Contactor4;
M1BrakeCmd        := instWinchOutputInterlockM1.BrakeCmd;

// ── Interlock final M2 (Treuil Benne) ────────────────────────────────────
M2InterlockEnable := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Enable
                      AND NOT SafetyStructureNotValidated;

instWinchOutputInterlockM2(
    Enable                     := M2InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.SafeStop,
    BrakeReleaseRequest        := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed  := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.BrakeCommandOpenConfirmed,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.RequestedStep
);

M2RelayFwd        := instWinchOutputInterlockM2.RelayFwd;
M2RelayRev        := instWinchOutputInterlockM2.RelayRev;
M2SpeedContactor1 := instWinchOutputInterlockM2.Contactor1;
M2SpeedContactor2 := instWinchOutputInterlockM2.Contactor2;
M2SpeedContactor3 := instWinchOutputInterlockM2.Contactor3;
M2SpeedContactor4 := instWinchOutputInterlockM2.Contactor4;
M2BrakeCmd        := instWinchOutputInterlockM2.BrakeCmd;

// ── Interlock final M3 (Translation, variateur AC600) ────────────────────
M3InterlockEnable := PRG_05_Translation.TranslationFinalInterlockRequest.Enable
                      AND NOT SafetyStructureNotValidated;

instTranslationOutputInterlockM3(
    Enable                     := M3InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_05_Translation.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_05_Translation.TranslationFinalInterlockRequest.SafeStop,
    BrakeReleaseRequest        := PRG_05_Translation.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed  := PRG_05_Translation.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord  := PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz       := PRG_05_Translation.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);

TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;

// === ⚡ §2 ÉCRITURE DES SORTIES PHYSIQUES Q (M1 / M2 / M3) ===
// Coils câblées directement sur la sortie de l'interlock : plus aucune
// commande moteur/frein n'atteint la carte de sortie sans être passée
// par sa barrière finale (voir §1).
// ⚠️ Source ST (référence documentaire) : ces affectations expriment le contrat
// fonctionnel. Le LD réellement importé dans CODESYS (généré par
// gen_prg06_oracle.py) ne câble PAS de coil direct sur ces noms *_DQ/*_RQ :
// ce sont des variables auto-créées par le mapping E/S de Device.export,
// absentes du bundle isolé — un coil dessus fait planter l'import CODESYS
// (REX 2026-08-04, ArgumentNullException). Le raccordement physique reste au
// mapping E/S CODESYS (Device.export, jamais modifié par ce lot) pointé sur
// la variable locale (M1RelayFwd...), déjà pilotée par la barrière finale.
M1_RelayFwd_Up_DQ         := M1RelayFwd;
M1_RelayRev_Down_DQ       := M1RelayRev;
M1_SpeedContactor_1_DQ    := M1SpeedContactor1;
M1_SpeedContactor_2_DQ    := M1SpeedContactor2;
M1_SpeedContactor_3_DQ    := M1SpeedContactor3;
M1_SpeedContactor_4_DQ    := M1SpeedContactor4;
M1_BrakeRelease_RQ        := M1BrakeCmd;

M2_RelayFwd_Up_Close_DQ   := M2RelayFwd;
M2_RelayRev_Down_Open_DQ  := M2RelayRev;
M2_SpeedContactor_1_DQ    := M2SpeedContactor1;
M2_SpeedContactor_2_DQ    := M2SpeedContactor2;
M2_SpeedContactor_3_DQ    := M2SpeedContactor3;
M2_SpeedContactor_4_DQ    := M2SpeedContactor4;
M2_BrakeRelease_RQ        := M2BrakeCmd;

M3_BrakeRelease_RQ        := TranslationBrakeCmd;

// === 🌐 Recopie GVL_Global (lecture publique diagnostic/simulation) ===
// GVL_Global.M1RelayFwd..TranslationBrakeCmd sont consommés par FB_SimBench
// (PRG_02_Acquisition) pour rejouer les commandes finales en simulation banc.
GVL_Global.M1RelayFwd        := M1RelayFwd;
GVL_Global.M1RelayRev        := M1RelayRev;
GVL_Global.M1SpeedContactor1 := M1SpeedContactor1;
GVL_Global.M1SpeedContactor2 := M1SpeedContactor2;
GVL_Global.M1SpeedContactor3 := M1SpeedContactor3;
GVL_Global.M1SpeedContactor4 := M1SpeedContactor4;
GVL_Global.M1BrakeCmd        := M1BrakeCmd;
GVL_Global.M2RelayFwd        := M2RelayFwd;
GVL_Global.M2RelayRev        := M2RelayRev;
GVL_Global.M2SpeedContactor1 := M2SpeedContactor1;
GVL_Global.M2SpeedContactor2 := M2SpeedContactor2;
GVL_Global.M2SpeedContactor3 := M2SpeedContactor3;
GVL_Global.M2SpeedContactor4 := M2SpeedContactor4;
GVL_Global.M2BrakeCmd        := M2BrakeCmd;
GVL_Global.TranslationBrakeCmd := TranslationBrakeCmd;

// === 🛡️ §3 SÉCURITÉ & COUPURE PUISSANCE AMONT ===

PowerCutOffReq := FALSE;

instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
);

PowerKeepAlive_A_RQ := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ := instSafetyEmergencyManagement.ArmPulse_RQ;

EmergencyArmingPulseActive := instSafetyEmergencyManagement.ArmPulse_RQ;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.EmergencyArmingLockoutActive;
ArmingSeqStep := instSafetyEmergencyManagement.ArmingSeqStep;
RedundancyTestFailed := instSafetyEmergencyManagement.RedundancyTestFailed;
EmergencyArmingFailed := instSafetyEmergencyManagement.EmergencyArmingFailed;
EmergencyState := instSafetyEmergencyManagement.State;
EmergencyDiag := instSafetyEmergencyManagement.Diag;
PowerCutOffActive := PowerCutOffReq;

END_PROGRAM
