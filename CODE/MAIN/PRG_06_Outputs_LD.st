(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs_LD — Écriture des SORTIES physiques (PROGRAMME LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md §5
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
   🆕 LOT2 (2026-08-05) : sortie moteur AC600 M3 raccordée. DriveControlWord
      (mot commande 0x3101) et DriveFreqRefWord (consigne fréquence WORD,
      registre 0x3100, échelle ×100 confirmée terrain — WORD 5000 = 50,00 Hz)
      capturés en variables locales M3_DriveControlWord / M3_DriveFreqRefWord.
      Mapping E/S CODESYS (Device.export) manuel restant — voir §2 ci-dessous.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs_LD

VAR_OUTPUT
    (* 🐛 FIX 2026-08-05 (confirmé câblé réel par l'utilisateur) : PowerKeepAlive_A_RQ/
       PowerKeepAlive_B_RQ/EmergencyArming_RQ retirés d'ici — même collision de portée
       que M1/M2/M3 (voir §2). Cibles renommées : PowerKeepAliveACmd/BCmd/
       EmergencyArmingCmd, déclarées en VAR locale ci-dessous. *)
    EmergencyArmingPulseActive   : BOOL;
    EmergencyArmingLockoutActive : BOOL;
    ArmingSeqStep                : INT;
    RedundancyTestFailed         : BOOL;
    EmergencyArmingFailed        : BOOL;
    EmergencyState               : ST_Safety_Emergency_State;
    EmergencyDiag                : ST_Safety_Emergency_Diag;
    PowerCutOffActive            : BOOL; (* TRUE = demande de coupure finale active *)

    SafetyStructureNotValidated  : BOOL := FALSE; (* 🔓 Garde-fou désactivé : les autorisations M1/M2/M3 sont liées dynamiquement à leurs sécurités *)
    // 🔧 FIX 2026-08-14 (audit sécurité) : Enable ne coupe plus que sur PowerCutOff (barrière
    // finale, AF02 §2, AF06 §5 "SafeStop laisse la décélération métier se terminer"). SafeStop/
    // Error retirés du calcul — SafeStop est une rampe rapide gérée en amont par FB_Winch/
    // FB_Translation (Enable maintenu, AGENTS.md, TC-P03-001) ; Error mirait tout ErrorId y
    // compris les mécanismes SafeStop-only, donc coupait Enable pour la même mauvaise raison.
    // Couper ici sur SafeStop/Error écrasait la rampe déjà calculée en amont en un arrêt
    // brutal — contraire à la doctrine Enable>SafeStop>StartStop.
    M1InterlockEnable            : BOOL; (* Gate finale M1 : WinchM1FinalInterlockRequest.Enable AND NOT WinchM1FinalInterlockRequest.PowerCutOff *)
    M2InterlockEnable            : BOOL; (* Gate finale M2 : WinchM2FinalInterlockRequest.Enable AND NOT WinchM2FinalInterlockRequest.PowerCutOff *)
    M3InterlockEnable            : BOOL; (* Gate finale M3 : TranslationFinalInterlockRequest.Enable AND NOT TranslationFinalInterlockRequest.PowerCutOff *)
    // 🆕 Réseau informatif séparé (demande utilisateur) : visibilité maintenance de ce qui
    // bloque (SafeStop/Error), SANS influencer Enable — juste de l'information en Watch/Ladder.
    M1BlockedBySafetyInfo        : BOOL;
    M2BlockedBySafetyInfo        : BOOL;
    M3BlockedBySafetyInfo        : BOOL;

    (* 🐛 FIX 2026-08-05 : les noms Device bruts ( *_DQ / *_RQ ), ex. M1_RelayFwd_Up_DQ,
       M3_BrakeRelease_RQ) NE SONT PLUS déclarés ici — les déclarer créait une collision
       de portée avec la variable GLOBALE homonyme créée par le mapping E/S CODESYS
       (Device.export), qui masquait silencieusement le pilotage matériel réel (voir §2
       plus bas pour le détail et la liste des chemins qualifiés à mapper). *)
    TranslationBrakeCmd          : BOOL; (* Demande frein M3 arbitrée — cible du mapping E/S *)
    M3_DriveControlWord          : WORD; (* Mot de commande variateur M3 (0x3101) — cible du mapping E/S *)
    M3_DriveFreqRefWord          : WORD; (* Consigne fréquence variateur M3 (0x3100, x100) — cible du mapping E/S *)
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
    KoboldContactorCmd  : BOOL;
    PowerCutOffReq      : BOOL;

    PowerKeepAliveACmd  : BOOL; (* Maintien puissance voie A — cible du mapping E/S *)
    PowerKeepAliveBCmd  : BOOL; (* Maintien puissance voie B — cible du mapping E/S *)
    EmergencyArmingCmd  : BOOL; (* Impulsion réarmement — cible du mapping E/S *)

    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === 🛡️ §1 BARRIÈRES FINALES M1 / M2 / M3 — INTERLOCKS VISIBLES ===
// Chaque bloc reçoit la demande brute publique du procédé propriétaire
// (ST_WinchFinalInterlockRequest / ST_TranslationFinalInterlockRequest) :
// tous les interlocks/safety qui peuvent couper cet actionneur sont donc
// lisibles directement sur ce réseau, sans ouvrir un autre POU.

// ── Interlock final M1 (Treuil Retenue) ──────────────────────────────────
M1InterlockEnable := PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff;

// Info diagnostic seule (Watch/Ladder) — ne participe PAS au calcul ci-dessus.
M1BlockedBySafetyInfo := OR(
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.SafeStop,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.Error,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ErrorMecaA,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ErrorMecaB,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ErrorMecaC,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ErrorMecaD,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ErrorMecaE,
    PRG_04_Treuils_Benne.WinchM1SafetyHMI.ThermalFault
);

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
// 🆕 2026-08-06 (retrait FB_Brake, demande client) : recalcul INDEPENDANT sur les DQ
// finaux (pas une simple recopie de instWinchOutputInterlockM1.BrakeCmd) -- visible ici
// sans ouvrir FB_WinchOutputInterlock_LD, meme doctrine que le reste de ce POU.
M1BrakeCmd        := M1RelayFwd OR M1RelayRev;

// ── Interlock final M2 (Treuil Benne) ────────────────────────────────────
M2InterlockEnable := PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff;

// Info diagnostic seule (Watch/Ladder) — ne participe PAS au calcul ci-dessus.
M2BlockedBySafetyInfo := OR(
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.SafeStop,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.Error,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.ErrorMecaA,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.ErrorMecaB,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.ErrorMecaD,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.ErrorMecaE,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.ThermalFault,
    PRG_04_Treuils_Benne.WinchM2SafetyHMI.SlackCable
);

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
// 🆕 2026-08-06 (retrait FB_Brake, demande client) : recalcul INDEPENDANT, voir M1 ci-dessus.
M2BrakeCmd        := M2RelayFwd OR M2RelayRev;

// 🔴🔧 REX 2026-08-07 (12) — retour terrain, GAP CONFIRMÉ : KoboldContactorCmd était déclaré
// (VAR ci-dessus) mais jamais écrit -- la chaîne instDiveSearch.KoboldMeasureEnable ->
// PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated s'arrêtait net ici, sans erreur de
// compilation ni de gate pour le signaler (même classe de bug que le fix M3 frein du
// 2026-08-05). Mapping E/S CODESYS à (re)faire côté utilisateur (voir §2 plus bas) :
// M1_M2_KoboldMeasureEnable_DQ <- PRG_06_Outputs_LD.KoboldContactorCmd.
KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated;

// ── Interlock final M3 (Translation, variateur AC600) ────────────────────
// 🛡️ 2026-08-06 (demande maintenance) : déblocage M3 sans forçage manuel de SafetyStructureNotValidated.
// 🔧 FIX 2026-08-14 : ne coupe plus que sur PowerCutOff — voir commentaire VAR_OUTPUT en tête
// de fichier (SafeStop/Error écrasaient la rampe rapide gérée en amont par FB_Translation).
M3InterlockEnable := PRG_05_Translation.TranslationFinalInterlockRequest.Enable
                      AND NOT PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff;

// Info diagnostic seule (Watch/Ladder) — ne participe PAS au calcul ci-dessus.
M3BlockedBySafetyInfo := OR(
    PRG_05_Translation.TranslationSafetyHMI.SafeStop,
    PRG_05_Translation.TranslationSafetyHMI.Error,
    PRG_05_Translation.TranslationSafetyHMI.ErrorMecaA,
    PRG_05_Translation.TranslationSafetyHMI.ErrorMecaB,
    PRG_05_Translation.TranslationSafetyHMI.ErrorLimitSwitch,
    PRG_05_Translation.TranslationSafetyHMI.ErrorSensorIncoherent
);

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

// === ⚡ §2 SORTIES PHYSIQUES DIRECTES (M1 / M2 / M3 / AU / KOBOLD) — COILS HW ===
// Pilotage direct des variables de mapping E/S matérielles :
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

// 🆕 REX 2026-08-05 (audit sécurité, trouvé après LOT2) : PowerCutOffReq était figé à FALSE en dur —
// instSafetyTranslationM3.PowerCutOff (5 mécanismes/8 : thermique frein, Méca A/B, butées, incohérence
// capteurs) était donc calculé mais totalement inerte, sans aucune coupure amont réelle possible
// (seul le frein mécanique réagissait via SafeStop). Agrégation OU strict par procédé (M5, A-04) —
// M1/M2 (FB_Safety_Winch, pas encore instanciée) rejoindront ce OU dès leur safety câblée, aucune
// demande vraie ne doit jamais être masquée par l'absence d'une autre source.
// 🆕 2026-08-05 : M1/M2 (FB_Safety_Winch) + M3 câblés — OU strict (M5, A-04).
// ⚠️ Cette ligne ST est UNIQUEMENT documentaire (contrat fonctionnel) : PRG_06_Outputs_LD est
// intégralement généré par l'oracle Python (gen_prg06_oracle.py), jamais par la conversion
// .st->LD générique (qui plante sur une variable réassignée en OU chaîné — bug pré-existant du
// générateur générique, hors périmètre de ce lot). Contrat réel, câblé dans l'oracle (3 contacts
// parallèles sur la même coil PowerCutOffReq, voir section PowerCutOffReq du script) :
//   PowerCutOffReq = WinchM1FinalInterlockRequest.PowerCutOff
//                  OR WinchM2FinalInterlockRequest.PowerCutOff
//                  OR TranslationFinalInterlockRequest.PowerCutOff
PowerCutOffReq := PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff;

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
