(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs — Barrière finale des sorties physiques (ST pur)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md §5
   ⚙️ Exécuté en position 6 (après PRG_05_Translation).
   🛡️ Interlocks finaux M1/M2/M3 + agrégation PowerCutOff + chaîne AU.
   🔒 SafetyStructureNotValidated reste TRUE : aucune sortie moteur/frein
       autorisée tant que ce garde-fou n'est pas retiré.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs

VAR_OUTPUT
    // === 🚨 ÉTATS CHAÎNE AU & COUPURE ===
    EmergencyArmingPulseActive   : BOOL; // <-- [STAT] Impulsion rearmement AU active
    EmergencyArmingLockoutActive : BOOL; // <-- [STAT] Verrouillage rearmement AU actif
    ArmingSeqStep                : INT;  // <-- [STAT] Etape sequence rearmement AU
    RedundancyTestFailed         : BOOL; // <-- [DIAG] Test redondance AU echoue
    EmergencyArmingFailed        : BOOL; // <-- [DIAG] Echec rearmement AU
    EmergencyState               : ST_Safety_Emergency_State; // <-- [STAT] Etat chaine AU
    EmergencyDiag                : ST_Safety_Emergency_Diag;  // <-- [DIAG] Diagnostic chaine AU
    PowerCutOffActive            : BOOL; // <-- [SAFE] Demande de coupure finale active

    SafetyStructureNotValidated  : BOOL := FALSE; // 🔓 Garde-fou : autorisations M1/M2/M3 liees a leurs securites
    // Enable ne coupe que sur PowerCutOff (barriere finale, AF02 §2, AF06 §5).
    // SafeStop = rampe rapide geree en amont par FB_Winch/FB_Translation (Enable maintenu).
    M1InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M1 (Enable AND NOT PowerCutOff)
    M2InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M2 (Enable AND NOT PowerCutOff)
    M3InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M3 (Enable AND NOT PowerCutOff)
    // Info diagnostic (Watch) — ne participe pas au calcul Enable.
    M1PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M1 coupant la puissance
    M1SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M1 SafeStop
    M1BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M1 bloque par securite (PowerCutOff OU SafeStop)

    M2PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M2 coupant la puissance
    M2SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M2 SafeStop
    M2BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M2 bloque par securite (PowerCutOff OU SafeStop)

    M3PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M3 coupant la puissance
    M3SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M3 SafeStop
    M3BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M3 bloque par securite (PowerCutOff OU SafeStop)

    // Les noms Device bruts (*_DQ / *_RQ) ne sont pas declares ici : les declarer
    // creerait une collision avec la globale homonyme du mapping E/S.
    TranslationBrakeCmd          : BOOL; // <-- [ACT] Demande frein M3 arbitree — cible mapping E/S
    M3_DriveControlWord          : WORD; // <-- [ACT] Mot commande variateur M3 (0x3101) — cible mapping E/S
    M3_DriveFreqRefWord          : WORD; // <-- [ACT] Consigne frequence M3 (0x3100, x100) — cible mapping E/S

    // === ⚡ ORDRES ACTIONNEURS ===
    M1RelayFwd                   : BOOL; // <-- [ACT] Ordre contacteur montee treuil M1
    M1RelayRev                   : BOOL; // <-- [ACT] Ordre contacteur descente treuil M1
    M1SpeedContactor1            : BOOL; // <-- [ACT] Ordre contacteur palier 1 treuil M1
    M1SpeedContactor2            : BOOL; // <-- [ACT] Ordre contacteur palier 2 treuil M1
    M1SpeedContactor3            : BOOL; // <-- [ACT] Ordre contacteur palier 3 treuil M1
    M1SpeedContactor4            : BOOL; // <-- [ACT] Ordre contacteur palier 4 treuil M1
    M1BrakeCmd                   : BOOL; // <-- [ACT] Ordre desserrage frein M1 (1=Desserrer)
    M2RelayFwd                   : BOOL; // <-- [ACT] Ordre contacteur montee/fermeture treuil M2
    M2RelayRev                   : BOOL; // <-- [ACT] Ordre contacteur descente/ouverture treuil M2
    M2SpeedContactor1            : BOOL; // <-- [ACT] Ordre contacteur palier 1 treuil M2
    M2SpeedContactor2            : BOOL; // <-- [ACT] Ordre contacteur palier 2 treuil M2
    M2SpeedContactor3            : BOOL; // <-- [ACT] Ordre contacteur palier 3 treuil M2
    M2SpeedContactor4            : BOOL; // <-- [ACT] Ordre contacteur palier 4 treuil M2
    M2BrakeCmd                   : BOOL; // <-- [ACT] Ordre desserrage frein M2 (1=Desserrer)
    KoboldContactorCmd           : BOOL; // <-- [ACT] Ordre alimentation contacteur capteur fond Kobold
    PowerKeepAliveACmd           : BOOL; // <-- [SAFE] Maintien puissance voie A (1=Maintenu)
    PowerKeepAliveBCmd           : BOOL; // <-- [SAFE] Maintien puissance voie B (1=Maintenu)
    EmergencyArmingCmd           : BOOL; // <-- [CMD] Impulsion rearmement puissance AU
END_VAR

VAR
    // === 🛡️ SOUS-INSTANCES FB INTERLOCKS SORTIES ===
    instWinchOutputInterlockM1       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M1
    instWinchOutputInterlockM2       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M2
    instTranslationOutputInterlockM3 : FB_TranslationOutputInterlock; // * [INST] Barriere finale translation M3
    instSafetyEmergencyManagement    : FB_Safety_EmergencyManagement;    // * [INST] Gestionnaire de rearmement AU

    // === ⚙️ VARIABLES LOCALES INTERNES ===
    PowerCutOffReq                   : BOOL; // . [LOC] Demande agregative coupure puissance
END_VAR

// === 🛡️ §1 BARRIÈRES FINALES M1 / M2 / M3 ===
// Chaque bloc reçoit la demande brute publique du procédé propriétaire
// (ST_WinchFinalInterlockRequest / ST_TranslationFinalInterlockRequest).

// ── Interlock final M1 (Treuil Retenue) ──────────────────────────────────
M1InterlockEnable := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff;

M1PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.WinchM1Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.WinchM1Safety.ThermalFault;

M1SafeStopSafetyInfo := PRG_04_Treuils_Benne.WinchM1Safety.SafeStop
                     OR PRG_04_Treuils_Benne.WinchM1Safety.Error
                     OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.WinchM1Safety.ErrorNoMovement;

M1BlockedBySafetyInfo := M1PowerCutOffSafetyInfo OR M1SafeStopSafetyInfo;

instWinchOutputInterlockM1(
    Enable                     := M1InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.SafeStop,
    BrakeFeedback              := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.BrakeFeedback,
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
// Recalcul independant sur les DQ finaux (pas une recopie de BrakeCmd).
M1BrakeCmd        := M1RelayFwd OR M1RelayRev;

// ── Interlock final M2 (Treuil Benne) ────────────────────────────────────
M2InterlockEnable := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff;

M2PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.WinchM2Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.WinchM2Safety.ThermalFault;

M2SafeStopSafetyInfo := PRG_04_Treuils_Benne.WinchM2Safety.SafeStop
                     OR PRG_04_Treuils_Benne.WinchM2Safety.Error
                     OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.WinchM2Safety.ErrorNoMovement
                     OR PRG_04_Treuils_Benne.WinchM2Safety.SlackCable
                     OR PRG_04_Treuils_Benne.BucketState.Error
                     OR PRG_04_Treuils_Benne.BucketState.CoupledMotionBlockedByBucket;

M2BlockedBySafetyInfo := M2PowerCutOffSafetyInfo OR M2SafeStopSafetyInfo;

instWinchOutputInterlockM2(
    Enable                     := M2InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.SafeStop,
    BrakeFeedback              := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.BrakeFeedback,
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
// Recalcul independant, voir M1.
M2BrakeCmd        := M2RelayFwd OR M2RelayRev;

// KoboldContactorCmd depuis la commande arbitree PRG_04.
// Mapping E/S : M1_M2_KoboldMeasureEnable_DQ <- PRG_06_Outputs.KoboldContactorCmd.
KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated;

// ── Interlock final M3 (Translation, variateur AC600) ────────────────────
M3InterlockEnable := PRG_05_Translation.TranslationFinalInterlockRequest.Enable
                      AND NOT PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff;

M3PowerCutOffSafetyInfo := PRG_05_Translation.TranslationSafety.PowerCutOff
                        OR PRG_05_Translation.TranslationSafety.ErrorMecaA
                        OR PRG_05_Translation.TranslationSafety.ErrorMecaB
                        OR PRG_05_Translation.TranslationSafety.ErrorBrakeThermal;

M3SafeStopSafetyInfo := PRG_05_Translation.TranslationSafety.SafeStop
                     OR PRG_05_Translation.TranslationSafety.Error
                     OR PRG_05_Translation.TranslationSafety.ErrorOperatorComm
                     OR PRG_05_Translation.TranslationSafety.ErrorDriveComm
                     OR PRG_05_Translation.TranslationSafety.ErrorPhaseRotation
                     OR PRG_05_Translation.TranslationSafety.ErrorLimitSwitch
                     OR PRG_05_Translation.TranslationSafety.ErrorSensorIncoherent;

M3BlockedBySafetyInfo := M3PowerCutOffSafetyInfo OR M3SafeStopSafetyInfo;

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
M3_CommandWord := instTranslationOutputInterlockM3.DriveControlWord;
M3_SetpointFrequencyHz := instTranslationOutputInterlockM3.DriveFreqRefWord;

// === ⚡ §2 SORTIES PHYSIQUES DIRECTES (M1 / M2 / M3 / AU / KOBOLD) ===
M1_RelayFwd_Up_DQ            := M1RelayFwd;
M1_RelayRev_Down_DQ          := M1RelayRev;
M1_SpeedContactor_1_DQ       := M1SpeedContactor1;
M1_SpeedContactor_2_DQ       := M1SpeedContactor2;
M1_SpeedContactor_3_DQ       := M1SpeedContactor3;
M1_SpeedContactor_4_DQ       := M1SpeedContactor4;
M1_BrakeRelease_RQ           := M1BrakeCmd;

M2_RelayFwd_Up_Close_DQ      := M2RelayFwd;
M2_RelayRev_Down_Open_DQ     := M2RelayRev;
M2_SpeedContactor_1_DQ       := M2SpeedContactor1;
M2_SpeedContactor_2_DQ       := M2SpeedContactor2;
M2_SpeedContactor_3_DQ       := M2SpeedContactor3;
M2_SpeedContactor_4_DQ       := M2SpeedContactor4;
M2_BrakeRelease_RQ           := M2BrakeCmd;

M3_BrakeRelease_RQ           := TranslationBrakeCmd;

M1_M2_KoboldMeasureEnable_DQ := KoboldContactorCmd;

PowerKeepAlive_A_RQ          := PowerKeepAliveACmd;
PowerKeepAlive_B_RQ          := PowerKeepAliveBCmd;
EmergencyArming_RQ           := EmergencyArmingCmd;


// === 🛡️ §3 SÉCURITÉ & COUPURE PUISSANCE AMONT ===
// PowerCutOffReq = agrégation OU strict des demandes de coupure des trois procédés (M5, A-04).
PowerCutOffReq := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff
               OR PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff
               OR PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff;

instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
);

PowerKeepAliveACmd := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAliveBCmd := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArmingCmd := instSafetyEmergencyManagement.ArmPulse_RQ;

EmergencyArmingLockoutActive := instSafetyEmergencyManagement.EmergencyArmingLockoutActive;
ArmingSeqStep := instSafetyEmergencyManagement.ArmingSeqStep;
RedundancyTestFailed := instSafetyEmergencyManagement.RedundancyTestFailed;
EmergencyArmingFailed := instSafetyEmergencyManagement.EmergencyArmingFailed;
EmergencyState := instSafetyEmergencyManagement.State;
EmergencyDiag := instSafetyEmergencyManagement.Diag;
PowerCutOffActive := PowerCutOffReq;

END_PROGRAM
