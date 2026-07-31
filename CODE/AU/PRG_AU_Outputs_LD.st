(* ═══════════════════════════════════════════════════════════════
   📤 PRG_AU_Outputs_LD — Écriture des sorties AU (dernière couche, LADDER)
   ───────────────────────────────────────────────────────────────
   📄 Appelle FB_Safety_EmergencyManagement et écrit les variables
      Q physiques (PowerKeepAlive_A/B_RQ, EmergencyArming_RQ).
   🧩 Structure identique à PRG_10_Outputs_LD (projet réel) pour le
      domaine AU isolé : converti automatiquement en Ladder Diagram
      (<LD>) dans CODESYS, comme la frontière finale réelle.
   ⚠️ Pattern LD imposé (REX import) : VAR_OUTPUT strictement scalaires
      (BOOL/INT/WORD), jamais de structure ST_* en sortie — même règle
      que PRG_10_Outputs_LD (aucun ST_* dans ses VAR_OUTPUT). Les bus
      structurés State/Diag restent lisibles via l'instance (Watch),
      pas via une sortie VAR_OUTPUT du programme.
   🎯 Ordre d'appel obligatoire : PRG_AU_Acquisition → PRG_AU_Outputs_LD
      (même cycle, même tâche).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-02_Architecture_Programme_v3.0.md §2 (PRG_OUTPUTS_LD)
*)

PROGRAM PRG_AU_Outputs_LD
VAR_OUTPUT
    // ⚡ Sorties physiques terminales (mêmes noms que le projet réel)
    PowerKeepAlive_A_RQ : BOOL;   // Relais maintien canal A (TRUE = voie maintenue)
    PowerKeepAlive_B_RQ : BOOL;   // Relais maintien canal B (TRUE = voie maintenue)
    EmergencyArming_RQ  : BOOL;   // Impulsion réarmement contacteur (1s)

    // 🩺 Diagnostics scalaires pour observation Watch (même pattern que PRG_10_Outputs_LD)
    ChainOk                      : BOOL;
    ContactorOk                  : BOOL;
    Armable                      : BOOL;
    ArmingBusy                   : BOOL;
    ArmingSeqStep                : INT;
    Error                        : BOOL;
    ErrorId                      : WORD;
    RedundancyTestFailed         : BOOL;
    EmergencyArmingFailed        : BOOL;
    EmergencyArmingLockoutActive : BOOL;
END_VAR
VAR
    // Instance unique du composite AU — barrière finale, seul écrivain des Q AU
    instSafetyEmergencyManagement : FB_Safety_EmergencyManagement;
END_VAR

// === IMPLEMENTATION ===

// 🛡️ Gestionnaire d'arrêt d'urgence et de réarmement
instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := GVL_IHM_AU.Cmd.BtnFaultReset,
    ArmRequest := GVL_IHM_AU.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_AU_Acquisition.EmergencyChainClosed,
    PowerContactorEngaged := PRG_AU_Acquisition.PowerContactorEngaged,
    PowerCutOffRequest := PRG_AU_Acquisition.PowerCutOffRequest,
    BtnEmergencyCutOff := GVL_IHM_AU.Cmd.BtnEmergencyCutOff
);

// ⚡ Affectation des sorties de réarmement et maintien puissance
PowerKeepAlive_A_RQ := instSafetyEmergencyManagement.MaintainA_RQ;
PowerKeepAlive_B_RQ := instSafetyEmergencyManagement.MaintainB_RQ;
EmergencyArming_RQ  := instSafetyEmergencyManagement.ArmPulse_RQ;

// 🩺 Observation scalaire (dépliage manuel des bus State/Diag)
ChainOk                      := instSafetyEmergencyManagement.State.ChainOk;
ContactorOk                  := instSafetyEmergencyManagement.State.ContactorOk;
Armable                      := instSafetyEmergencyManagement.State.Armable;
ArmingBusy                   := instSafetyEmergencyManagement.State.ArmingBusy;
ArmingSeqStep                := instSafetyEmergencyManagement.State.Step;
Error                        := instSafetyEmergencyManagement.Diag.Error;
ErrorId                      := instSafetyEmergencyManagement.Diag.ErrorId;
RedundancyTestFailed         := instSafetyEmergencyManagement.Diag.RedundancyTestFailed;
EmergencyArmingFailed        := instSafetyEmergencyManagement.Diag.ArmFailed;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.Diag.LockoutActive;
