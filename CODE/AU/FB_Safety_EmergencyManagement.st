(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyManagement — Bloc Safety Composite (Parent)
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Bloc de sécurité principal de la boucle d'arrêt d'urgence.
   🧩 Encapsule la Logique (FB_Safety_EmergencyManagementLogic) et le
      Pilote Physique (FB_Safety_EmergencyManagementOutput) par composition.
   📤 Produit les bus publics ST_State_Emergency et ST_Diag_Emergency
      en sortie, consommés par Supervision et Troubleshooting.
   🏷️ Renommé PowerCutOff_A/B_RQ → MaintainA/B_RQ (polarité maintien),
      EmergencyArming_RQ → ArmPulse_RQ (cohérence nommage).
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-03_Contrats_Composants_v2.0.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagement
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)
    EmergencyChainClosed      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    PowerContactorEngaged     : BOOL;        // Confirmation contacteur de puissance principal
    PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers
    BtnEmergencyCutOff  : BOOL;        // Commande d'ouverture d'urgence depuis l'IHM
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: RedundancyTestFailed, bit1: EmergencyArmingFailed, bit3: StartupFail

    // ⚡ Sorties physiques — renommées (polarité maintien explicite)
    MaintainA_RQ        : BOOL;        // Sortie de pilotage canal A (TRUE = voie maintenue, FALSE = coupure)
    MaintainB_RQ        : BOOL;        // Sortie de pilotage canal B (TRUE = voie maintenue, FALSE = coupure)
    ArmPulse_RQ         : BOOL;        // Impulsion réarmement physique (1s)

    // 🚦 Bus d'état public (AF §8.2)
    State               : ST_State_Emergency; // ChainOk, ContactorOk, Step, Armable, ArmingBusy
    Diag                : ST_Diag_Emergency;  // Error, ErrorId, Redundancy, ArmFailed, Lockout

    // 🩺 Diagnostics scalaires (rétrocompatibilité PRG_10/GVL_Global)
    ArmingSeqStep                : INT;
    RedundancyTestFailed         : BOOL;
    EmergencyArmingFailed        : BOOL;
    EmergencyArmingLockoutActive : BOOL;
END_VAR
VAR
    // 🧱 Composition interne des sous-blocs
    Logic               : FB_Safety_EmergencyManagementLogic;
    Output              : FB_Safety_EmergencyManagementOutput;
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. Appels des instances internes
Logic(
    Enable := Enable,
    Reset := Reset,
    ArmRequest := ArmRequest,
    EmergencyChainClosed := EmergencyChainClosed,
    PowerContactorEngaged := PowerContactorEngaged,
    PowerCutOffRequest := PowerCutOffRequest,
    BtnEmergencyCutOff := BtnEmergencyCutOff
);

Output(
    Enable := Enable,
    Cmd := Logic.Cmd,
    ChainOk := EmergencyChainClosed,
    ContactorOk := PowerContactorEngaged,
    ArmingStep := Logic.ArmingSeqStep,
    Armable := Logic.Armable,
    ArmingBusy := Logic.ArmingBusy,
    Error := Logic.Error,
    ErrorId := Logic.ErrorId,
    RedundancyTestFailed := Logic.RedundancyTestFailed,
    ArmFailed := Logic.EmergencyArmingFailed,
    LockoutActive := Logic.EmergencyArmingLockoutActive
);

// 📤 2. Propagation des signaux vers les sorties du bloc parent
Ready := Enable AND NOT Logic.StartupFail;
Busy  := (Logic.ArmingSeqStep <> 0) OR Logic.EmergencyArmingLockoutActive;
Done  := PowerContactorEngaged;
Error := Logic.Error;
ErrorId := Logic.ErrorId;

// ⚡ Sorties physiques
MaintainA_RQ   := Output.MaintainA_RQ;
MaintainB_RQ   := Output.MaintainB_RQ;
ArmPulse_RQ    := Output.ArmPulse_RQ;

// 🚦 Bus publics
State := Output.State;
Diag  := Output.Diag;

// 🩺 Diagnostics scalaires (rétrocompatibilité)
ArmingSeqStep                := Logic.ArmingSeqStep;
RedundancyTestFailed         := Logic.RedundancyTestFailed;
EmergencyArmingFailed        := Logic.EmergencyArmingFailed;
EmergencyArmingLockoutActive := Logic.EmergencyArmingLockoutActive;
