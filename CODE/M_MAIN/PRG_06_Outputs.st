(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs — Barrière finale des sorties physiques (ST pur)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §5
   ⚙️ Exécuté en position 6 (après PRG_05_Translation).
   🛡️ Interlocks finaux M1/M2/M3 + agrégation PowerCutOff + chaîne AU.
   🎨 Organisation FONCTIONNELLE : chaque bloc regroupe la chaîne complète d'une
       fonction — conditions qui activent/désactivent la sortie (SafeStop / PowerCutOff /
       interlocks) → FB interlock → ordres → sorties physiques → bus inter-PRG. Lisible
       d'un coup d'œil.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA GVL_IHM & PRG_02 À 05) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data : ST_OutputsInterPrg; // <-- [BUS] Ordres actionneurs finaux (rebouclés FB_SimBench)

    // === 🚨 ÉTATS CHAÎNE AU & COUPURE ===
    EmergencyArmingPulseActive   : BOOL; // <-- [STAT] Impulsion rearmement AU active
    EmergencyArmingLockoutActive : BOOL; // <-- [STAT] Verrouillage rearmement AU actif
    ArmingSeqStep                : INT;  // <-- [STAT] Etape sequence rearmement AU
    RedundancyTestFailed         : BOOL; // <-- [DIAG] Test redondance AU echoue
    EmergencyArmingFailed        : BOOL; // <-- [DIAG] Echec rearmement AU
    EmergencyState               : ST_Safety_Emergency_State; // <-- [STAT] Etat chaine AU
    EmergencyDiag                : ST_Safety_Emergency_Diag;  // <-- [DIAG] Diagnostic chaine AU
    EmergencyReady               : BOOL; // <-- [STAT] FB AU pret a fonctionner (Enable + pas de StartupFail)
    EmergencyDone                : BOOL; // <-- [STAT] Cycle rearmement AU termine (contacteur confirme engage)
    EmergencyFault               : ST_Fault; // <-- [DIAG] Defaut latte chaine AU (socle FB_FaultCore)
    EmergencyOperatorMessage     : STRING(120); // <-- [DIAG] Message operateur par etat / probleme chaine AU
    PowerCutOffActive            : BOOL; // <-- [SAFE] Demande de coupure finale active

    M1InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M1 (Enable AND NOT PowerCutOff)
    M2InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M2 (Enable AND NOT PowerCutOff)
    M3InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M3 (Enable AND NOT PowerCutOff)
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
    M3_DriveControlWord          : WORD; // <-- [ACT] Mot commande variateur M3 (0x3101) — cible mapping E/S
    M3_DriveFreqCmdWord          : WORD; // <-- [ACT] Consigne frequence M3 (0x3100, x100) — cible mapping E/S
    KoboldContactorCmd           : BOOL; // <-- [ACT] Ordre alimentation contacteur capteur fond Kobold
END_VAR

VAR
    // === 🛡️ SOUS-INSTANCES FB INTERLOCKS SORTIES ===
    instWinchOutputInterlockM1       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M1
    instWinchOutputInterlockM2       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M2
    instTranslationOutputInterlockM3 : FB_TranslationOutputInterlock; // * [INST] Barriere finale translation M3
    instSafetyEmergencyManagement    : FB_Safety_EmergencyManagement;    // * [INST] Gestionnaire de rearmement AU

    // === ⚡ ORDRES ACTIONNEURS (publiés via Data) ===
    M1RelayFwd                   : BOOL; // . [LOC] Ordre contacteur montee treuil M1
    M1RelayRev                   : BOOL; // . [LOC] Ordre contacteur descente treuil M1
    M1SpeedContactor1            : BOOL; // . [LOC] Ordre contacteur palier 1 treuil M1
    M1SpeedContactor2            : BOOL; // . [LOC] Ordre contacteur palier 2 treuil M1
    M1SpeedContactor3            : BOOL; // . [LOC] Ordre contacteur palier 3 treuil M1
    M1SpeedContactor4            : BOOL; // . [LOC] Ordre contacteur palier 4 treuil M1
    M1BrakeCmd                   : BOOL; // . [LOC] Ordre desserrage frein M1
    M2RelayFwd                   : BOOL; // . [LOC] Ordre contacteur montee/fermeture treuil M2
    M2RelayRev                   : BOOL; // . [LOC] Ordre contacteur descente/ouverture treuil M2
    M2SpeedContactor1            : BOOL; // . [LOC] Ordre contacteur palier 1 treuil M2
    M2SpeedContactor2            : BOOL; // . [LOC] Ordre contacteur palier 2 treuil M2
    M2SpeedContactor3            : BOOL; // . [LOC] Ordre contacteur palier 3 treuil M2
    M2SpeedContactor4            : BOOL; // . [LOC] Ordre contacteur palier 4 treuil M2
    M2BrakeCmd                   : BOOL; // . [LOC] Ordre desserrage frein M2
    TranslationBrakeCmd          : BOOL; // . [LOC] Demande frein M3 arbitree
    PowerKeepAliveACmd           : BOOL; // . [LOC] Maintien puissance voie A
    PowerKeepAliveBCmd           : BOOL; // . [LOC] Maintien puissance voie B
    EmergencyArmingCmd           : BOOL; // . [LOC] Impulsion rearmement puissance AU

    // === ⚙️ VARIABLES LOCALES INTERNES ===
    PowerCutOffReq                   : BOOL; // . [LOC] Demande agregative coupure puissance
END_VAR

// ═══════════════════════════════════════════════════════════════
// 🛗 §1 TREUIL M1 (Retenue) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ D'un coup d'œil : ce qui active/désactive la sortie M1.
//   - M1InterlockEnable      : gate finale (Enable ET pas de PowerCutOff)
//   - M1PowerCutOffSafetyInfo: défauts qui COUPENT la puissance
//   - M1SafeStopSafetyInfo   : défauts qui font SafeStop (rampe rapide)
//   - M1BlockedBySafetyInfo  : synthèse (PowerCutOff OU SafeStop)
// Sources : PRG_04 (WinchM1FinalInterlockRequest / WinchM1Safety).

M1InterlockEnable := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff;

M1PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM1Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ThermalFault;

M1SafeStopSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM1Safety.SafeStop
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.Error
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorNoMovement;

M1BlockedBySafetyInfo := M1PowerCutOffSafetyInfo OR M1SafeStopSafetyInfo;

instWinchOutputInterlockM1(
    Enable                     := M1InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop,
    BrakeFeedback              := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedStep
);

M1RelayFwd        := instWinchOutputInterlockM1.RelayFwd;
M1RelayRev        := instWinchOutputInterlockM1.RelayRev;
M1SpeedContactor1 := instWinchOutputInterlockM1.Contactor1;
M1SpeedContactor2 := instWinchOutputInterlockM1.Contactor2;
M1SpeedContactor3 := instWinchOutputInterlockM1.Contactor3;
M1SpeedContactor4 := instWinchOutputInterlockM1.Contactor4;
// Recalcul independant sur les DQ finaux (pas une recopie de BrakeCmd).
M1BrakeCmd        := M1RelayFwd OR M1RelayRev;

// ── Sorties physiques M1 ──
M1_RelayAscent_DQ            := M1RelayFwd;
M1_RelayDescent_DQ           := M1RelayRev;
M1_SpeedContactor_1_DQ       := M1SpeedContactor1;
M1_SpeedContactor_2_DQ       := M1SpeedContactor2;
M1_SpeedContactor_3_DQ       := M1SpeedContactor3;
M1_SpeedContactor_4_DQ       := M1SpeedContactor4;
M1_BrakeRelease_RQ           := M1BrakeCmd;

// ── Bus inter-PRG M1 ──
Data.M1RelayFwd            := M1RelayFwd;
Data.M1RelayRev            := M1RelayRev;
Data.M1SpeedContactor1     := M1SpeedContactor1;
Data.M1SpeedContactor2     := M1SpeedContactor2;
Data.M1SpeedContactor3     := M1SpeedContactor3;
Data.M1SpeedContactor4     := M1SpeedContactor4;
Data.M1BrakeCmd            := M1BrakeCmd;

// ═══════════════════════════════════════════════════════════════
// 🛗 §2 TREUIL M2 (Benne) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ Même lecture que M1 : gate finale, défauts PowerCutOff / SafeStop, synthèse.
// Sources : PRG_04 (WinchM2FinalInterlockRequest / WinchM2Safety / BucketState).

M2InterlockEnable := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff;

M2PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM2Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ThermalFault;

M2SafeStopSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM2Safety.SafeStop
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.Error
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorNoMovement
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.SlackCable
                     OR PRG_04_Treuils_Benne.Data.BucketState.Error
                     OR PRG_04_Treuils_Benne.Data.BucketState.CoupledMotionBlockedByBucket;

M2BlockedBySafetyInfo := M2PowerCutOffSafetyInfo OR M2SafeStopSafetyInfo;

instWinchOutputInterlockM2(
    Enable                     := M2InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.SafeStop,
    BrakeFeedback              := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedStep
);

M2RelayFwd        := instWinchOutputInterlockM2.RelayFwd;
M2RelayRev        := instWinchOutputInterlockM2.RelayRev;
M2SpeedContactor1 := instWinchOutputInterlockM2.Contactor1;
M2SpeedContactor2 := instWinchOutputInterlockM2.Contactor2;
M2SpeedContactor3 := instWinchOutputInterlockM2.Contactor3;
M2SpeedContactor4 := instWinchOutputInterlockM2.Contactor4;
// Recalcul independant, voir M1.
M2BrakeCmd        := M2RelayFwd OR M2RelayRev;

// ── Sorties physiques M2 ──
M2_RelayAscent_Close_DQ      := M2RelayFwd;
M2_RelayDescent_Open_DQ      := M2RelayRev;
M2_SpeedContactor_1_DQ       := M2SpeedContactor1;
M2_SpeedContactor_2_DQ       := M2SpeedContactor2;
M2_SpeedContactor_3_DQ       := M2SpeedContactor3;
M2_SpeedContactor_4_DQ       := M2SpeedContactor4;
M2_BrakeRelease_RQ           := M2BrakeCmd;

// ── Bus inter-PRG M2 ──
Data.M2RelayFwd            := M2RelayFwd;
Data.M2RelayRev            := M2RelayRev;
Data.M2SpeedContactor1     := M2SpeedContactor1;
Data.M2SpeedContactor2     := M2SpeedContactor2;
Data.M2SpeedContactor3     := M2SpeedContactor3;
Data.M2SpeedContactor4     := M2SpeedContactor4;
Data.M2BrakeCmd            := M2BrakeCmd;

// ═══════════════════════════════════════════════════════════════
// ↔️ §3 TRANSLATION M3 (variateur AC600) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ Même lecture : gate finale, défauts PowerCutOff / SafeStop, synthèse.
// Sources : PRG_05 (TranslationFinalInterlockRequest / TranslationSafety).

M3InterlockEnable := PRG_05_Translation.Data.TranslationFinalInterlockRequest.Enable
                      AND NOT PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff;

M3PowerCutOffSafetyInfo := PRG_05_Translation.Data.TranslationSafety.PowerCutOff
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaA
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaB
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorBrakeThermal;

M3SafeStopSafetyInfo := PRG_05_Translation.Data.TranslationSafety.SafeStop
                     OR PRG_05_Translation.Data.TranslationSafety.Error
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorOperatorComm
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorDriveComm
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorPhaseRotation
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorLimitSwitch
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorSensorIncoherent;

M3BlockedBySafetyInfo := M3PowerCutOffSafetyInfo OR M3SafeStopSafetyInfo;

instTranslationOutputInterlockM3(
    Enable                     := M3InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_05_Translation.Data.TranslationFinalInterlockRequest.SafeStop,
    BrakeReleaseRequest        := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz       := PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);

TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;
M3_DriveControlWord := instTranslationOutputInterlockM3.DriveControlWord;
M3_DriveFreqCmdWord := instTranslationOutputInterlockM3.DriveFreqCmdWord;

// ── Sorties physiques M3 ──
M3_BrakeRelease_RQ           := TranslationBrakeCmd;

// ── Bus inter-PRG M3 ──
Data.TranslationBrakeCmd   := TranslationBrakeCmd;

// ═══════════════════════════════════════════════════════════════
// 🪝 §4 KOBOLD (capteur fond) — commande + sortie
// ═══════════════════════════════════════════════════════════════
// Source : PRG_04 (KoboldContactorCmdArbitrated).
KoboldContactorCmd := PRG_04_Treuils_Benne.Data.KoboldContactorCmdArbitrated;
M1_M2_KoboldMeasureEnable_DQ := KoboldContactorCmd;

// ═══════════════════════════════════════════════════════════════
// 🛡️ §5 AU / MAINTIEN PUISSANCE — coupure + réarmement + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ D'un coup d'œil : ce qui coupe la puissance (PowerCutOffReq) et ce qui
//    maintient/réarme (instSafetyEmergencyManagement) → sorties physiques.
// Sources : PRG_04/05 (PowerCutOff), GVL_IHM (ArmRequest / BtnEmergencyCutOff),
//           PRG_02 (EmergencyChainClosed / PowerContactorEngaged).

// PowerCutOffReq = agrégation OU strict des demandes de coupure des trois procédés (M5, A-04).
PowerCutOffReq := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff
               OR PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff
               OR PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff;

instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Emergency.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff
);

// ── Ordres AU (logique) — sorties structurées Status : ST_Safety_Emergency_Status + Cmd : ST_Safety_Emergency_Cmd ──
PowerKeepAliveACmd := instSafetyEmergencyManagement.Cmd.MaintainA_Cmd;
PowerKeepAliveBCmd := instSafetyEmergencyManagement.Cmd.MaintainB_Cmd;
EmergencyArmingCmd := instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd;

// ── Sorties physiques AU ──
PowerKeepAlive_A_RQ          := PowerKeepAliveACmd;
PowerKeepAlive_B_RQ          := PowerKeepAliveBCmd;
EmergencyArming_RQ           := EmergencyArmingCmd;

// ── Bus inter-PRG AU ──
Data.PowerKeepAliveACmd    := PowerKeepAliveACmd;
Data.PowerKeepAliveBCmd    := PowerKeepAliveBCmd;
Data.EmergencyArmingCmd    := EmergencyArmingCmd;

// ── Diagnostics chaîne AU (scalaires → State/Diag du DUT structuré) ──
// ⚡ Impulsion de réarmement AU (miroir de l'ordre physique EmergencyArmingCmd) — l'IHM
// affiche ainsi la fenêtre 1s du réarmement, pas seulement l'état "lockout"/"failed".
EmergencyArmingPulseActive := instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.Status.Diag.LockoutActive;
ArmingSeqStep := instSafetyEmergencyManagement.Status.State.Step;
RedundancyTestFailed := instSafetyEmergencyManagement.Status.Diag.RedundancyTestFailed;
EmergencyArmingFailed := instSafetyEmergencyManagement.Status.Diag.ArmFailed;
EmergencyState := instSafetyEmergencyManagement.Status.State;
EmergencyDiag := instSafetyEmergencyManagement.Status.Diag;
EmergencyReady := instSafetyEmergencyManagement.Status.Ready;
EmergencyDone := instSafetyEmergencyManagement.Status.Done;
EmergencyFault := instSafetyEmergencyManagement.Status.Fault;
EmergencyOperatorMessage := instSafetyEmergencyManagement.Status.OperatorMessage;
PowerCutOffActive := PowerCutOffReq;

END_PROGRAM
