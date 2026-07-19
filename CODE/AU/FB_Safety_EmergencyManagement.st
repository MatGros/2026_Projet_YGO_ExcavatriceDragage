(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyManagement — Bloc Safety Composite (Parent)
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Bloc de sécurité principal de la boucle d'arrêt d'urgence.
   🧩 Encapsule la Logique (FB_Safety_EmergencyManagementLogic) et le 
      Pilote Physique (FB_Safety_EmergencyManagementOutput) par composition.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md ; DOC/AF_Partie-03_Template_FB_Commun_v1.3.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagement
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (CmdEmergencyArming)
    EmergencyChain      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    EmergencyStopOk     : BOOL;        // Confirmation contacteur de puissance principal
    PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers
    CmdEmergencyCutOff  : BOOL;        // Commande d'ouverture d'urgence depuis l'IHM
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: RedundancyTestFailed, bit1: EmergencyArmingFailed
    
    PowerCutOff_A_RQ    : BOOL;        // Sortie de pilotage canal A (maintenu à TRUE, fail-safe)
    PowerCutOff_B_RQ    : BOOL;        // Sortie de pilotage canal B (maintenu à TRUE, fail-safe)
    EmergencyArming_RQ  : BOOL;        // Impulsion réarmement physique (1s)
    
    ArmingSeqStep       : INT;         // Étape de diagnostic : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    RedundancyTestFailed: BOOL;        // Canal A ou B resté collé/shunté détecté à l'auto-test
    EmergencyArmingFailed: BOOL;       // Contacteur de puissance n'a pas confirmé l'armement
    EmergencyArmingLockoutActive : BOOL; // Verrouillage temporel de 5s entre les essais
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
    EmergencyChain := EmergencyChain,
    EmergencyStopOk := EmergencyStopOk,
    PowerCutOffRequest := PowerCutOffRequest,
    CmdEmergencyCutOff := CmdEmergencyCutOff
);

Output(
    Enable := Enable,
    Cmd := Logic.Cmd
);

// 📤 2. Propagation des signaux vers les sorties du bloc parent
Ready := Enable;
Busy  := (Logic.ArmingSeqStep <> 0);
Done  := EmergencyStopOk;
Error := Logic.Error;
ErrorId := Logic.ErrorId;

PowerCutOff_A_RQ   := Output.PowerCutOff_A_RQ;
PowerCutOff_B_RQ   := Output.PowerCutOff_B_RQ;
EmergencyArming_RQ := Output.EmergencyArming_RQ;

ArmingSeqStep                := Logic.ArmingSeqStep;
RedundancyTestFailed         := Logic.RedundancyTestFailed;
EmergencyArmingFailed        := Logic.EmergencyArmingFailed;
EmergencyArmingLockoutActive := Logic.EmergencyArmingLockoutActive;
